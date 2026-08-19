// webview_windows.v — WebView 的 Windows 实现
// 仅当编译目标为 Windows 时由 V 自动编译（文件后缀 _windows.v）。
//
// 实现方式：集成 webview/webview（单头文件 C++ 库，内部封装 WebView2）。
// V 本身不直接 include 该 C++ 头文件，而是通过 native/webview_bridge.cpp（C++ 桥，
// 内部 include webview_bridge.cc 的实现）暴露的稳定 C 接口（见 native/vtauri_webview.h）
// 来调用。该桥由 V 的 thirdparty object builder 在 `v -cc msvc` 时自动用 cl 编译为
// webview_bridge.obj 并链接。
//
// 构建要求：Windows 本机需安装 MSVC（Visual Studio / Build Tools），用 `v -cc msvc` 编译。

module vtauri

#flag windows -I @VMODROOT/native
#flag windows -lole32 -lshell32 -lshlwapi -luser32 -lversion
#flag windows @VMODROOT/native/webview_bridge.obj
#include "vtauri_webview.h"

// --- 桥接层 C 函数声明 ---
fn C.vtauri_wv_create(debug int, window voidptr) voidptr
fn C.vtauri_wv_destroy(w voidptr) int
fn C.vtauri_wv_run(w voidptr) int
fn C.vtauri_wv_terminate(w voidptr) int
fn C.vtauri_wv_set_html(w voidptr, html &char) int
fn C.vtauri_wv_navigate(w voidptr, url &char) int
fn C.vtauri_wv_eval(w voidptr, js &char) int
fn C.vtauri_wv_bind(w voidptr, name &char, cb fn (&char, &char, voidptr), userdata voidptr) int
fn C.vtauri_wv_return(w voidptr, id &char, status int, result &char) int

// COM 初始化（WebView2 要求在创建前以 apartment-threaded 模式初始化 COM）
@[c_extern]
fn C.CoInitializeEx(pv_reserved voidptr, dw_co_init u32) int

const coinit_apartmentthreaded = u32(0x2) // COINIT_APARTMENTTHREADED

// attach_windows 创建并嵌入 WebView2。
fn (mut wv WebView) attach_windows() ! {
	hwnd := wv.window_handle
	if isnil(hwnd) {
		return error('attach_windows: parent HWND is nil')
	}
	// WebView2 要求先以 COINIT_APARTMENTTHREADED 初始化 COM
	C.CoInitializeEx(unsafe { nil }, coinit_apartmentthreaded)
	w := C.vtauri_wv_create(0, hwnd)
	if isnil(w) {
		return error('vtauri_wv_create failed: WebView2 runtime missing?')
	}
	wv.native = w
	wv.initialized = true
	resize_webview_widget_windows(hwnd)
}

// load_html_windows 渲染一段 HTML 字符串。
fn (mut wv WebView) load_html_windows(html string) ! {
	err := C.vtauri_wv_set_html(wv.native, &char(html.str))
	if err != 0 {
		return error('vtauri_wv_set_html failed: ${err}')
	}
}

// load_url_windows 导航到指定 URL。
fn (mut wv WebView) load_url_windows(url string) ! {
	err := C.vtauri_wv_navigate(wv.native, &char(url.str))
	if err != 0 {
		return error('vtauri_wv_navigate failed: ${err}')
	}
}

// execute_js_windows 在页面中执行一段 JavaScript。
fn (mut wv WebView) execute_js_windows(js string) ! {
	err := C.vtauri_wv_eval(wv.native, &char(js.str))
	if err != 0 {
		return error('vtauri_wv_eval failed: ${err}')
	}
}

// post_message_windows 将后端消息推送给前端。
// 通过向页面注入 `window.__vtauriOnEvent(<payload>)` 调用实现。
fn (mut wv WebView) post_message_windows(payload string) ! {
	js := 'window.__vtauriOnEvent(${payload});'
	err := C.vtauri_wv_eval(wv.native, &char(js.str))
	if err != 0 {
		return error('vtauri_wv_eval failed: ${err}')
	}
}

// bind_invoke_windows 将 __vtauriInvoke 暴露为页面全局函数，
// 前端调用它时路由到 App.handle_ipc 并把响应通过 vtauri_wv_return 回传。
fn (mut wv WebView) bind_invoke_windows(app &App) ! {
	if isnil(wv.native) {
		return error('bind_invoke_windows: webview not created')
	}
	// 手工分配绑定上下文（生命周期由 destroy_windows 显式释放，避免 autofree 提前回收）
	ctx := unsafe { &WvBindCtx(vcalloc(sizeof(WvBindCtx))) }
	unsafe {
		ctx.webview = wv.native
		ctx.app = app
	}
	wv.bind_ctx = ctx
	err := C.vtauri_wv_bind(wv.native, &char(c'__vtauriInvoke'), vtauri_on_invoke, voidptr(ctx))
	if err != 0 {
		unsafe { free(wv.bind_ctx) }
		wv.bind_ctx = unsafe { nil }
		return error('vtauri_wv_bind failed: ${err}')
	}
}

// run_windows 进入 webview 的消息循环（阻塞，直到窗口关闭）。
fn (mut wv WebView) run_windows() {
	C.vtauri_wv_run(wv.native)
}

// terminate_windows 终止 Windows 上的 webview 消息循环（webview 库支持 webview_terminate）。
fn (mut wv WebView) terminate_windows() {
	C.vtauri_wv_terminate(wv.native)
}

// destroy_windows 销毁 webview 实例并释放绑定上下文。
fn (mut wv WebView) destroy_windows() {
	if !isnil(wv.bind_ctx) {
		unsafe { free(wv.bind_ctx) }
		wv.bind_ctx = unsafe { nil }
	}
	if !isnil(wv.native) {
		C.vtauri_wv_destroy(wv.native)
		wv.native = unsafe { nil }
	}
}
