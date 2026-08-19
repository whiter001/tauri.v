/*
 * vtauri_webview.h — vtauri 到 webview/webview (WebView2) 的 C 桥接接口
 *
 * 该头文件是纯 C 接口，供 vtauri 的 V 代码通过 `#include` 与链接使用。
 * 真正的实现位于 webview_bridge.cc（C++），它内部调用 webview/webview 库的 C API。
 *
 * 通过这一层，V 侧无需处理 C++ 头文件与 vtable，只需链接到稳定的 C 符号。
 *
 * License: MIT
 */

#ifndef VTAURI_WEBVIEW_H
#define VTAURI_WEBVIEW_H

#ifdef __cplusplus
extern "C" {
#endif

/* 不透明的 webview 实例句柄。 */
typedef void *vtauri_wv_t;

/* webview_bind 注入的 JS 全局函数被调用时，native 侧的回调类型。
 * id   —— 本次调用的序列标识（webview 内部生成），必须原样传回 vtauri_wv_return。
 * req  —— JS 实参的 JSON 数组字符串，例如 ["<arg0>", "<arg1>"]。
 * userdata —— webview_bind 时传入的用户指针。 */
typedef void (*vtauri_wv_bind_cb)(const char *id, const char *req, void *userdata);

/* 在指定父窗口上创建并附着 WebView2。window 为现有 HWND（非空），
 * 库会把 WebView 嵌入其中。成功返回非 NULL，失败（如缺 WebView2 运行时）返回 NULL。 */
vtauri_wv_t vtauri_wv_create(int debug, void *window);

/* 销毁 webview 实例并关闭其窗口。返回错误码（0 表示成功）。 */
int vtauri_wv_destroy(vtauri_wv_t w);

/* 进入主事件循环，直到窗口关闭或调用 vtauri_wv_terminate。 */
int vtauri_wv_run(vtauri_wv_t w);

/* 终止主事件循环（可从其他线程调用）。 */
int vtauri_wv_terminate(vtauri_wv_t w);

/* 用一段 HTML 字符串渲染页面。 */
int vtauri_wv_set_html(vtauri_wv_t w, const char *html);

/* 导航到指定 URL。 */
int vtauri_wv_navigate(vtauri_wv_t w, const char *url);

/* 在页面中执行一段 JavaScript。 */
int vtauri_wv_eval(vtauri_wv_t w, const char *js);

/* 将一个 C 回调绑定为页面中的全局 JS 函数 name(...)，
 * 调用该函数返回一个 Promise，最终通过 vtauri_wv_return 兑现。 */
int vtauri_wv_bind(vtauri_wv_t w, const char *name, vtauri_wv_bind_cb cb, void *userdata);

/* 兑现一个绑定调用：status=0 成功（result 需为合法 JSON 或空串），否则失败。 */
int vtauri_wv_return(vtauri_wv_t w, const char *id, int status, const char *result);

/* 设置窗口标题（仅对库自建窗口的平台有意义，如 macOS）。 */
int vtauri_wv_set_title(vtauri_wv_t w, const char *title);

/* 设置窗口尺寸；hints 为 webview_hint_t（0 = WEBVIEW_HINT_NONE）。 */
int vtauri_wv_set_size(vtauri_wv_t w, int width, int height, int hints);

/* 安装标准 macOS 应用菜单栏（App 菜单：About/Quit；Edit 菜单：Undo/Redo/Cut/Copy/Paste/Select All）。
 * 仅 macOS 实现；webview 库不自建菜单，缺菜单会导致 Cmd+Q 与复制粘贴快捷键失效。
 * 应在 vtauri_wv_create 之后、vtauri_wv_run 之前调用。 */
void vtauri_mac_install_app_menu(const char *app_name);

#ifdef __cplusplus
}
#endif

#endif /* VTAURI_WEBVIEW_H */
