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

} // extern "C"
