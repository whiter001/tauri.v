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

} // extern "C"
