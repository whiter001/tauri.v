/*
 * webview_bridge.cc — vtauri 与 webview/webview 库的 C++ 桥接实现
 *
 * 本文件是 vtauri 中唯一需要 C++ 编译器的源文件，由 webview_bridge.cpp
 * `#include`（V 的 thirdparty object builder 在 `v -cc msvc` 时自动用 cl 编译
 * 为 webview_bridge.obj 并链接）。
 * 它 #include webview/webview.h（header-only 的 C++ 实现），
 * 并将 C API（见 vtauri_webview.h）转发给 webview 库。
 *
 * License: MIT
 */

#define WEBVIEW_STATIC

#include "webview/webview.h"
#include "vtauri_webview.h"

#include <cstring>
#include <string>

#if defined(WEBVIEW_PLATFORM_DARWIN)
// Block.h 提供 Block_copy/Block_release（blocks runtime，macOS 上随 libSystem）。
// 授权 completionHandler 与通知中心回调都要求真正的 Objective-C block（`^{...}`），
// 不能用 C 函数指针替代，故本文件使用 clang 的 -fblocks 扩展（见 notify_darwin.v
// 的 `#flag darwin -fblocks`，模块级合并后同样作用于本 .o 的编译）。
#include <Block.h>
#include <objc/runtime.h>
#endif

#if defined(WEBVIEW_PLATFORM_DARWIN)
namespace objc = webview::detail::objc;
namespace cocoa = webview::detail::cocoa;
#endif

// --- 系统托盘（macOS NSStatusItem）支持 ---
// 托盘句柄与回调上下文均为进程生命周期分配（new），有意不释放：
// NSStatusItem/NSMenu/target 实例由系统强持有，存活到进程退出，
// 过早释放（或依赖 V 侧 GC）会留下野指针。

// 回调上下文：cb 为 V 侧回调函数，userdata 为其用户指针。
struct VtauriTrayCtx {
  vtauri_mac_tray_cb cb = nullptr;
  void *userdata = nullptr;
};

// 托盘句柄结构体：直接作为 vtauri_mac_tray_create 的返回值（tray 句柄）。
// cbctx 是句柄的成员，地址在托盘生命周期内稳定，target 的 ivar 指向它。
struct VtauriTrayHandle {
  void *item = nullptr;   // NSStatusItem *（系统强持有）
  void *menu = nullptr;   // NSMenu *（系统强持有）
  void *target = nullptr; // VtauriTrayTarget 实例（动态类，被菜单项强持有）
  VtauriTrayCtx cbctx;
};

#if defined(WEBVIEW_PLATFORM_DARWIN)
// 动态类 VtauriTrayTarget 的 action 方法 IMP：菜单项被点击时，
// 从 ivar 读回调上下文，从 sender（NSMenuItem）的 representedObject 读菜单项 id，
// 经注册的回调转回 V。
static void vtauri_tray_action_imp(id self, SEL _cmd, id sender) {
  objc::autoreleasepool arp;
  Ivar iv = class_getInstanceVariable(object_getClass(self), "vtauri_ctx");
  auto *ctx = iv ? *reinterpret_cast<VtauriTrayCtx **>(
                       reinterpret_cast<char *>(self) + ivar_getOffset(iv))
                 : nullptr;
  id repr = objc::msg_send<id>(sender, objc::selector("representedObject"));
  if (ctx && ctx->cb && repr) {
    const char *idstr = cocoa::NSString_get_UTF8String(repr);
    ctx->cb(idstr ? idstr : "", ctx->userdata);
  }
}
#endif

// --- 系统通知（macOS UNUserNotificationCenter）支持 ---
// 通知文本暂存在进程级 static std::string：requestAuthorization 的 completionHandler
// 是异步回调（用户点完授权框才执行），届时 notify 调用早已返回，只能用全局暂存
// 而非捕获调用栈局部量。非可重入：需要串行调用（通知本身是低频操作，可接受）。
// vtauri_notify_authorized：0=未知/已提交；2=用户拒绝授权（由异步 block 写入，
// 后续 notify 调用直接返回 2，使 V 侧能同步映射出“权限被拒”错误）。
static std::string vtauri_notify_title;
static std::string vtauri_notify_body;
static int vtauri_notify_authorized = 0;

#if defined(WEBVIEW_PLATFORM_DARWIN)
// 动态类 VtauriNotifyDelegate 的 willPresentNotification IMP：让应用在前台时
// 通知也能以横幅 + 声音形式呈现（不设 delegate 时前台只进通知中心，不弹横幅）。
// completionHandler 是 block：void (^)(UNNotificationPresentationOptions)，
// UNNotificationPresentationOptions 为 NSUInteger（64 位 unsigned long）。
// 参数是 id，直接 cast 成 block 指针类型调用（clang -fblocks 支持；非 ARC C++
// 下不能用 __bridge，用 C 风格 cast 即可）。Banner(1<<4=16) | Sound(1<<0=1) = 17。
static void vtauri_notify_present_imp(id self, SEL _cmd, id center,
                                      id notification, id handler_id) {
  objc::autoreleasepool arp;
  void (^completion)(unsigned long) = (void (^)(unsigned long))handler_id;
  completion(17);
}
#endif

extern "C" {

vtauri_wv_t vtauri_wv_create(int debug, void *window) {
  return reinterpret_cast<vtauri_wv_t>(webview_create(debug, window));
}

int vtauri_wv_destroy(vtauri_wv_t w) {
  return static_cast<int>(webview_destroy(reinterpret_cast<webview_t>(w)));
}

int vtauri_wv_run(vtauri_wv_t w) {
  return static_cast<int>(webview_run(reinterpret_cast<webview_t>(w)));
}

int vtauri_wv_terminate(vtauri_wv_t w) {
  return static_cast<int>(webview_terminate(reinterpret_cast<webview_t>(w)));
}

int vtauri_wv_set_html(vtauri_wv_t w, const char *html) {
  return static_cast<int>(webview_set_html(reinterpret_cast<webview_t>(w), html));
}

int vtauri_wv_eval(vtauri_wv_t w, const char *js) {
  return static_cast<int>(webview_eval(reinterpret_cast<webview_t>(w), js));
}

int vtauri_wv_navigate(vtauri_wv_t w, const char *url) {
  return static_cast<int>(webview_navigate(reinterpret_cast<webview_t>(w), url));
}

int vtauri_wv_bind(vtauri_wv_t w, const char *name, vtauri_wv_bind_cb cb,
                   void *userdata) {
  return static_cast<int>(webview_bind(reinterpret_cast<webview_t>(w), name, cb,
                                       userdata));
}

int vtauri_wv_return(vtauri_wv_t w, const char *id, int status,
                     const char *result) {
  return static_cast<int>(webview_return(reinterpret_cast<webview_t>(w), id,
                                         status, result));
}

int vtauri_wv_set_title(vtauri_wv_t w, const char *title) {
  return static_cast<int>(webview_set_title(reinterpret_cast<webview_t>(w), title));
}

int vtauri_wv_set_size(vtauri_wv_t w, int width, int height, int hints) {
  return static_cast<int>(webview_set_size(reinterpret_cast<webview_t>(w), width,
                                           height, static_cast<webview_hint_t>(hints)));
}

void vtauri_mac_install_app_menu(const char *app_name) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  // 复用 webview 库自带的 objc 封装（native/webview/detail/platform/darwin/objc 与 cocoa）：
  // msg_send / selector / get_class / autoreleasepool / NSString_stringWithUTF8String 等。
  // 菜单项全部用 +new / alloc-init 一次性创建并挂到 NSApplication 主菜单，不手动 release：
  // 菜单由 NSApplication 强持有，存活整个进程生命周期，无需（也不应）释放。
  objc::autoreleasepool arp;

  id menubar =
      objc::msg_send<id>(objc::get_class("NSMenu"), objc::selector("new"));

  // --- App 菜单：About / Quit（Cmd+Q） ---
  id app_item =
      objc::msg_send<id>(objc::get_class("NSMenuItem"), objc::selector("new"));
  objc::msg_send<void>(menubar, objc::selector("addItem:"), app_item);
  id app_menu =
      objc::msg_send<id>(objc::get_class("NSMenu"), objc::selector("new"));
  objc::msg_send<void>(app_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String(std::string("About ") + app_name),
                       objc::selector("orderFrontStandardAboutPanel:"),
                       cocoa::NSString_stringWithUTF8String(""));
  objc::msg_send<void>(app_menu, objc::selector("addItem:"),
                       objc::msg_send<id>(objc::get_class("NSMenuItem"),
                                          objc::selector("separatorItem")));
  objc::msg_send<void>(app_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String(std::string("Quit ") + app_name),
                       objc::selector("terminate:"),
                       cocoa::NSString_stringWithUTF8String("q"));
  objc::msg_send<void>(app_item, objc::selector("setSubmenu:"), app_menu);

  // --- Edit 菜单：Undo / Redo / Cut / Copy / Paste / Select All ---
  id edit_item =
      objc::msg_send<id>(objc::get_class("NSMenuItem"), objc::selector("new"));
  objc::msg_send<void>(menubar, objc::selector("addItem:"), edit_item);
  id edit_menu = objc::msg_send<id>(
      objc::msg_send<id>(objc::get_class("NSMenu"), objc::selector("alloc")),
      objc::selector("initWithTitle:"), cocoa::NSString_stringWithUTF8String("Edit"));
  objc::msg_send<void>(edit_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String("Undo"),
                       objc::selector("undo:"), cocoa::NSString_stringWithUTF8String("z"));
  // 大写 "Z" 表示 Cmd+Shift+Z（keyEquivalent 大小写决定是否带 Shift）。
  objc::msg_send<void>(edit_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String("Redo"),
                       objc::selector("redo:"), cocoa::NSString_stringWithUTF8String("Z"));
  objc::msg_send<void>(edit_menu, objc::selector("addItem:"),
                       objc::msg_send<id>(objc::get_class("NSMenuItem"),
                                          objc::selector("separatorItem")));
  objc::msg_send<void>(edit_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String("Cut"),
                       objc::selector("cut:"), cocoa::NSString_stringWithUTF8String("x"));
  objc::msg_send<void>(edit_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String("Copy"),
                       objc::selector("copy:"), cocoa::NSString_stringWithUTF8String("c"));
  objc::msg_send<void>(edit_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String("Paste"),
                       objc::selector("paste:"), cocoa::NSString_stringWithUTF8String("v"));
  objc::msg_send<void>(edit_menu, objc::selector("addItemWithTitle:action:keyEquivalent:"),
                       cocoa::NSString_stringWithUTF8String("Select All"),
                       objc::selector("selectAll:"), cocoa::NSString_stringWithUTF8String("a"));
  objc::msg_send<void>(edit_item, objc::selector("setSubmenu:"), edit_menu);

  // 挂到应用主菜单
  objc::msg_send<void>(cocoa::NSApplication_get_sharedApplication(),
                       objc::selector("setMainMenu:"), menubar);
#endif
}

void vtauri_mac_message_box(const char *title, const char *message) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  // 防御性确保 NSApp 存在：vtauri 流程里 NSApp 已由 webview 库创建，
  // 这里保险处理，使独立 V 程序直接调用对话框也能工作。
  cocoa::NSApplication_setActivationPolicy(
      cocoa::NSApplication_get_sharedApplication(),
      cocoa::NSApplicationActivationPolicyRegular);

  // NSAlert 模态消息框：alloc/init 创建后直接 runModal 阻塞至用户点击。
  id alert = objc::msg_send<id>(
      objc::msg_send<id>(objc::get_class("NSAlert"), objc::selector("alloc")),
      objc::selector("init"));
  objc::msg_send<void>(alert, objc::selector("setMessageText:"),
                       cocoa::NSString_stringWithUTF8String(title));
  objc::msg_send<void>(alert, objc::selector("setInformativeText:"),
                       cocoa::NSString_stringWithUTF8String(message));
  objc::msg_send<void>(alert, objc::selector("addButtonWithTitle:"),
                       cocoa::NSString_stringWithUTF8String("OK"));
  // runModal 返回 NSModalResponse（NSInteger=long），这里只需阻塞到点击，忽略返回值。
  objc::msg_send<long>(alert, objc::selector("runModal"));
#endif
}

char *vtauri_mac_open_file(const char *title, const char *filters_csv) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  // 防御性确保 NSApp 存在（同 vtauri_mac_message_box）。
  cocoa::NSApplication_setActivationPolicy(
      cocoa::NSApplication_get_sharedApplication(),
      cocoa::NSApplicationActivationPolicyRegular);

  id panel = cocoa::NSOpenPanel_openPanel();
  objc::msg_send<void>(panel, objc::selector("setTitle:"),
                       cocoa::NSString_stringWithUTF8String(title));
  cocoa::NSOpenPanel_set_canChooseFiles(panel, true);
  cocoa::NSOpenPanel_set_canChooseDirectories(panel, false);
  cocoa::NSOpenPanel_set_allowsMultipleSelection(panel, false);

  // filters_csv（如 "png,jpg,txt"）切成扩展名数组；空串/空扩展名跳过。
  if (filters_csv != nullptr && filters_csv[0] != '\0') {
    id types = objc::msg_send<id>(
        objc::msg_send<id>(objc::get_class("NSMutableArray"),
                           objc::selector("alloc")),
        objc::selector("init"));
    std::string csv(filters_csv);
    std::string::size_type start = 0;
    while (true) {
      std::string::size_type comma = csv.find(',', start);
      std::string ext = (comma == std::string::npos)
                            ? csv.substr(start)
                            : csv.substr(start, comma - start);
      if (!ext.empty()) {
        objc::msg_send<void>(types, objc::selector("addObject:"),
                             cocoa::NSString_stringWithUTF8String(ext));
      }
      if (comma == std::string::npos) {
        break;
      }
      start = comma + 1;
    }
    objc::msg_send<void>(panel, objc::selector("setAllowedFileTypes:"), types);
  }

  // runModal 返回 NSModalResponse：1 表示 NSModalResponseOK。
  long result = objc::msg_send<long>(panel, objc::selector("runModal"));
  if (result == cocoa::NSModalResponseOK) {
    id url = objc::msg_send<id>(panel, objc::selector("URL"));
    id path = objc::msg_send<id>(url, objc::selector("path"));
    const char *utf8 = cocoa::NSString_get_UTF8String(path);
    if (utf8 != nullptr) {
      return strdup(utf8); // malloc 分配，调用方负责 free
    }
  }
  return nullptr;
#else
  return nullptr;
#endif
}

char *vtauri_mac_save_file(const char *title, const char *default_name) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  // 防御性确保 NSApp 存在（同 vtauri_mac_message_box）。
  cocoa::NSApplication_setActivationPolicy(
      cocoa::NSApplication_get_sharedApplication(),
      cocoa::NSApplicationActivationPolicyRegular);

  id panel = objc::msg_send<id>(objc::get_class("NSSavePanel"),
                                objc::selector("savePanel"));
  objc::msg_send<void>(panel, objc::selector("setTitle:"),
                       cocoa::NSString_stringWithUTF8String(title));
  if (default_name != nullptr && default_name[0] != '\0') {
    objc::msg_send<void>(panel, objc::selector("setNameFieldStringValue:"),
                         cocoa::NSString_stringWithUTF8String(default_name));
  }

  long result = objc::msg_send<long>(panel, objc::selector("runModal"));
  if (result == cocoa::NSModalResponseOK) {
    id url = objc::msg_send<id>(panel, objc::selector("URL"));
    id path = objc::msg_send<id>(url, objc::selector("path"));
    const char *utf8 = cocoa::NSString_get_UTF8String(path);
    if (utf8 != nullptr) {
      return strdup(utf8); // malloc 分配，调用方负责 free
    }
  }
  return nullptr;
#else
  return nullptr;
#endif
}

void *vtauri_mac_tray_create(const char *title) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  // 防御性确保 NSApp 存在（与对话框同款保险）。
  cocoa::NSApplication_setActivationPolicy(
      cocoa::NSApplication_get_sharedApplication(),
      cocoa::NSApplicationActivationPolicyRegular);

  // 动态类 VtauriTrayTarget 进程内只建一次（static 标志位守卫；
  // 重复 objc_registerClassPair 同名类会崩溃）。
  static bool class_ready = false;
  if (!class_ready) {
    Class cls =
        objc_allocateClassPair(objc::get_class("NSObject"), "VtauriTrayTarget", 0);
    // ivar 存 VtauriTrayCtx*；alignment 传 log2(sizeof(void*))。
    class_addIvar(cls, "vtauri_ctx", sizeof(void *), 3 /* log2(8) */, "^v");
    class_addMethod(cls, objc::selector("vtauriTrayAction:"),
                    reinterpret_cast<IMP>(vtauri_tray_action_imp), "v@:@");
    objc_registerClassPair(cls);
    class_ready = true;
  }
  id target =
      objc::msg_send<id>(objc::get_class("VtauriTrayTarget"), objc::selector("new"));

  // NSStatusItem：可变宽度文本图标（NSVariableStatusItemLength = -1）。
  // 注意：statusItemWithLength: 返回 autoreleased 对象，且 NSStatusBar 并不持有
  // status item——必须显式 retain，否则本函数退出时 autoreleasepool 排空会把它
  // 释放，托盘图标立刻从菜单栏消失。
  id status_item = objc::msg_send<id>(
      objc::msg_send<id>(objc::get_class("NSStatusBar"),
                         objc::selector("systemStatusBar")),
      objc::selector("statusItemWithLength:"), -1.0);
  status_item = objc::msg_send<id>(status_item, objc::selector("retain"));
  id button = objc::msg_send<id>(status_item, objc::selector("button"));
  objc::msg_send<void>(button, objc::selector("setTitle:"),
                       cocoa::NSString_stringWithUTF8String(title));

  // 托盘菜单：点击图标时弹出。
  id menu = objc::msg_send<id>(objc::get_class("NSMenu"), objc::selector("new"));
  objc::msg_send<void>(status_item, objc::selector("setMenu:"), menu);

  // 进程生命周期句柄：item 已显式 retain（见上）；menu 被 status item 持有，
  // target 被菜单项持有。整条对象图随 item 存活，不释放。
  auto *handle = new VtauriTrayHandle;
  handle->item = status_item;
  handle->menu = menu;
  handle->target = target;
  // 把指向 handle->cbctx 的指针写进 target 的 vtauri_ctx ivar
  //（cbctx 是 handle 的成员，地址在托盘生命周期内稳定）。
  Ivar iv = class_getInstanceVariable(object_getClass(target), "vtauri_ctx");
  if (iv) {
    void **slot = reinterpret_cast<void **>(reinterpret_cast<char *>(target) +
                                            ivar_getOffset(iv));
    *slot = &handle->cbctx;
  }
  return handle;
#else
  return nullptr;
#endif
}

void vtauri_mac_tray_add_item(void *tray, const char *item_id,
                              const char *label) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  if (tray == nullptr) {
    return;
  }
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  auto *handle = static_cast<VtauriTrayHandle *>(tray);
  id menu = static_cast<id>(handle->menu);
  id target = static_cast<id>(handle->target);

  // alloc/initWithTitle:action:keyEquivalent: 一步设置标题与 action，
  // 再单独 setTarget / setRepresentedObject，最后 addItem 进托盘菜单。
  id item = objc::msg_send<id>(
      objc::msg_send<id>(objc::get_class("NSMenuItem"), objc::selector("alloc")),
      objc::selector("initWithTitle:action:keyEquivalent:"),
      cocoa::NSString_stringWithUTF8String(label),
      objc::selector("vtauriTrayAction:"),
      cocoa::NSString_stringWithUTF8String(""));
  objc::msg_send<void>(item, objc::selector("setTarget:"), target);
  objc::msg_send<void>(item, objc::selector("setRepresentedObject:"),
                       cocoa::NSString_stringWithUTF8String(item_id));
  objc::msg_send<void>(menu, objc::selector("addItem:"), item);
#endif
}

void vtauri_mac_tray_on_click(void *tray, vtauri_mac_tray_cb cb, void *userdata) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  if (tray == nullptr) {
    return;
  }
  auto *handle = static_cast<VtauriTrayHandle *>(tray);
  handle->cbctx.cb = cb;
  handle->cbctx.userdata = userdata;
#endif
}

void vtauri_mac_clipboard_write_text(const char *text) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  // [[NSPasteboard generalPasteboard] clearContents] + setString:forType:
  // NSPasteboardTypeString 是 extern NSString 常量，避免引入符号依赖，
  // 直接用等价字面量 "public.utf8-plain-text"（经 NSString_stringWithUTF8String）。
  id pasteboard = objc::msg_send<id>(objc::get_class("NSPasteboard"),
                                     objc::selector("generalPasteboard"));
  objc::msg_send<void>(pasteboard, objc::selector("clearContents"));
  objc::msg_send<BOOL>(pasteboard, objc::selector("setString:forType:"),
                       cocoa::NSString_stringWithUTF8String(text ? text : ""),
                       cocoa::NSString_stringWithUTF8String("public.utf8-plain-text"));
#endif
}

char *vtauri_mac_clipboard_read_text() {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  id pasteboard = objc::msg_send<id>(objc::get_class("NSPasteboard"),
                                     objc::selector("generalPasteboard"));
  id str = objc::msg_send<id>(pasteboard, objc::selector("stringForType:"),
                              cocoa::NSString_stringWithUTF8String("public.utf8-plain-text"));
  if (str == nullptr) {
    return nullptr;
  }
  const char *utf8 = cocoa::NSString_get_UTF8String(str);
  if (utf8 == nullptr) {
    return nullptr;
  }
  return strdup(utf8); // malloc 分配，调用方负责 free
#else
  return nullptr;
#endif
}

int vtauri_mac_open_url(const char *url) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  objc::autoreleasepool arp;

  // [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:...]]；
  // openURL: 返回 BOOL。URL 非法时 URLWithString: 返回 nil，openURL: 也返回 NO。
  id nsurl = objc::msg_send<id>(objc::get_class("NSURL"),
                                objc::selector("URLWithString:"),
                                cocoa::NSString_stringWithUTF8String(url ? url : ""));
  if (nsurl == nullptr) {
    return 0;
  }
  id workspace = objc::msg_send<id>(objc::get_class("NSWorkspace"),
                                    objc::selector("sharedWorkspace"));
  BOOL ok = objc::msg_send<BOOL>(workspace, objc::selector("openURL:"), nsurl);
  return ok ? 1 : 0;
#else
  return 0;
#endif
}

int vtauri_mac_notify(const char *title, const char *body) {
#if defined(WEBVIEW_PLATFORM_DARWIN)
  namespace objc = webview::detail::objc;
  namespace cocoa = webview::detail::cocoa;

  // 1) UNUserNotificationCenter 要求进程处于 .app bundle（有 CFBundleIdentifier）；
  //    裸二进制（直接运行 hello 而未经 scripts/bundle_macos.sh 打包）在此调用会
  //    抛异常崩溃，必须先拦截。bundleIdentifier 为 nil 即视为未打包。
  id bundle = cocoa::NSBundle_get_mainBundle();
  if (bundle == nullptr) {
    return 1;
  }
  id bundle_id = objc::msg_send<id>(bundle, objc::selector("bundleIdentifier"));
  if (bundle_id == nullptr) {
    return 1;
  }

  objc::autoreleasepool arp;

  id center = objc::msg_send<id>(objc::get_class("UNUserNotificationCenter"),
                                 objc::selector("currentNotificationCenter"));
  if (center == nullptr) {
    return 0;
  }

  // 2) delegate：让应用在前台时也能弹出横幅。UNUserNotificationCenter 的 delegate
  //    是弱引用，单例实例必须进程生命周期存活——new 一次存 static，不释放
  //    （与托盘 target 同策略）。
  static bool delegate_class_ready = false;
  if (!delegate_class_ready) {
    Class cls =
        objc_allocateClassPair(objc::get_class("NSObject"), "VtauriNotifyDelegate", 0);
    class_addMethod(cls,
                    objc::selector("userNotificationCenter:willPresentNotification:"
                                   "withCompletionHandler:"),
                    reinterpret_cast<IMP>(vtauri_notify_present_imp), "v@:@@@");
    objc_registerClassPair(cls);
    delegate_class_ready = true;
  }
  static id notify_delegate = nullptr;
  if (notify_delegate == nullptr) {
    notify_delegate = objc::msg_send<id>(objc::get_class("VtauriNotifyDelegate"),
                                         objc::selector("new"));
  }
  objc::msg_send<void>(center, objc::selector("setDelegate:"), notify_delegate);

  // 3) 授权 + 发送。首次调用触发系统授权弹窗；授权 completionHandler 是异步回调，
  //    回调里「授权成功则立即构造并提交通知」这一完整链路，外层同步返回 0（已提交）。
  //    用户先前拒绝过授权时，直接返回 2（V 侧映射为「权限被拒」错误）。
  if (vtauri_notify_authorized == 2) {
    return 2;
  }

  vtauri_notify_title = title != nullptr ? title : "";
  vtauri_notify_body = body != nullptr ? body : "";

  // UNAuthorizationOptions：alert(1<<2=4) | sound(1<<0=1) = 5，NSUInteger 传 64 位值。
  // completionHandler 用 C++ block 字面量（-fblocks），Block_copy 后作为 id 传入 msg_send。
  // 框架会自行再拷贝一份用于异步调用；我们持有的一份进程生命周期内不再释放
  // （通知是低频操作，与托盘结构体同策略）。
  void (^auth_block)(BOOL, id) = ^(BOOL granted, id error) {
    // completionHandler 可能在任何队列执行，block 内自建 autoreleasepool。
    objc::autoreleasepool arp;
    if (!granted) {
      vtauri_notify_authorized = 2; // 用户拒绝授权：置结果码，供后续调用直接返回
      return;
    }
    // UNMutableNotificationContent + setTitle:/setBody:
    id content = objc::msg_send<id>(
        objc::msg_send<id>(objc::get_class("UNMutableNotificationContent"),
                           objc::selector("alloc")),
        objc::selector("init"));
    objc::msg_send<void>(content, objc::selector("setTitle:"),
                         cocoa::NSString_stringWithUTF8String(vtauri_notify_title));
    objc::msg_send<void>(content, objc::selector("setBody:"),
                         cocoa::NSString_stringWithUTF8String(vtauri_notify_body));
    // 0.1 秒后触发（立即呈现），repeats:NO。
    // 注意：必须用类工厂 triggerWithTimeInterval:repeats:；当前 macOS 上
    // alloc + initWithTimeInterval:repeats: 会抛 unrecognized selector
    // （实例 init 已改名 _initWithTimeInterval:repeats:，不再公开）。
    // 工厂方法返回 autoreleased 对象，request 构造时会 retain。
    id trigger = objc::msg_send<id>(
        objc::get_class("UNTimeIntervalNotificationTrigger"),
        objc::selector("triggerWithTimeInterval:repeats:"), 0.1,
        static_cast<BOOL>(false));
    // identifier 自增计数，保证每次通知唯一
    static unsigned long serial = 0;
    std::string ident = "vtauri-notify-" + std::to_string(++serial);
    id request = objc::msg_send<id>(
        objc::get_class("UNNotificationRequest"),
        objc::selector("requestWithIdentifier:content:trigger:"),
        cocoa::NSString_stringWithUTF8String(ident), content, trigger);
    objc::msg_send<void>(center,
                         objc::selector("addNotificationRequest:withCompletionHandler:"),
                         request, static_cast<id>(nullptr));
  };
  id auth_block_copy = (id)Block_copy(auth_block);
  objc::msg_send<void>(center,
                       objc::selector("requestAuthorizationWithOptions:completionHandler:"),
                       static_cast<NSUInteger>(5), auth_block_copy);
  return 0;
#else
  return 0;
#endif
}

} // extern "C"
