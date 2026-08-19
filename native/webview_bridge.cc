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

} // extern "C"
