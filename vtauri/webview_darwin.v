// webview_darwin.v — WebView 的 macOS 实现
// 仅当编译目标为 macOS 时由 V 自动编译（文件后缀 _darwin.v）。
//
// 实现方式：与 Windows 一样集成 webview/webview（其 macOS 后端为 WKWebView + Cocoa）。
// macOS 上窗口由 webview 库自建（vtauri_wv_create 传 nil），并自管 NSApplication 事件循环。

module vtauri

#flag darwin -I @VMODROOT/native
#flag darwin -framework Cocoa -framework WebKit -lc++
#flag darwin @VMODROOT/native/webview_bridge.o
#include "vtauri_webview.h"

// --- 桥接层 C 函数声明：与 webview_windows.v 相同的一组 + vtauri_wv_set_title / vtauri_wv_set_size ---
fn C.vtauri_wv_create(debug int, window voidptr) voidptr
fn C.vtauri_wv_destroy(w voidptr) int
fn C.vtauri_wv_run(w voidptr) int
fn C.vtauri_wv_terminate(w voidptr) int
fn C.vtauri_wv_set_html(w voidptr, html &char) int
fn C.vtauri_wv_navigate(w voidptr, url &char) int
fn C.vtauri_wv_eval(w voidptr, js &char) int
fn C.vtauri_wv_bind(w voidptr, name &char, cb fn (&char, &char, voidptr), userdata voidptr) int
fn C.vtauri_wv_return(w voidptr, id &char, status int, result &char) int
fn C.vtauri_wv_set_title(w voidptr, title &char) int
fn C.vtauri_wv_set_size(w voidptr, width int, height int, hints int) int
fn C.vtauri_mac_install_app_menu(app_name &char)

// attach_darwin 创建由 webview 库自建的 macOS 窗口。
// macOS 上窗口句柄为 nil（窗口由库自建），也无需初始化 COM。
fn (mut wv WebView) attach_darwin() ! {
	w := C.vtauri_wv_create(0, unsafe { nil })
	if isnil(w) {
		return error('vtauri_wv_create failed')
	}
	wv.native = w
	wv.initialized = true
}

// set_window_props_darwin 设置窗口标题与尺寸。
// resizable=false 时以 WEBVIEW_HINT_FIXED(=3) 设置尺寸：库的 cocoa 后端会去掉
// NSWindowStyleMaskResizable 并设 contentMinSize=contentMaxSize，即不可调整大小。
// 库的 cocoa 后端在 set_size 时会居中窗口，center 参数目前由库行为覆盖，故不额外处理。
fn (mut wv WebView) set_window_props_darwin(title string, width int, height int, center bool, resizable bool) {
	C.vtauri_wv_set_title(wv.native, &char(title.str))
	hints := if resizable { 0 } else { 3 } // 0=WEBVIEW_HINT_NONE, 3=WEBVIEW_HINT_FIXED
	C.vtauri_wv_set_size(wv.native, width, height, hints)
	_ = center // 居中由库的 set_size 行为覆盖，显式标记避免未使用告警
}

// terminate_darwin 终止应用事件循环（窗口关闭后进程退出）。
fn (mut wv WebView) terminate_darwin() {
	C.vtauri_wv_terminate(wv.native)
}

// install_app_menu_darwin 安装标准 macOS 应用菜单栏（About/Quit + Edit 全套）。
fn (mut wv WebView) install_app_menu_darwin(app_name string) {
	C.vtauri_mac_install_app_menu(&char(app_name.str))
}

// load_html_darwin 渲染一段 HTML 字符串。
fn (mut wv WebView) load_html_darwin(html string) ! {
	err := C.vtauri_wv_set_html(wv.native, &char(html.str))
	if err != 0 {
		return error('vtauri_wv_set_html failed: ${err}')
	}
}

// load_url_darwin 导航到指定 URL。
fn (mut wv WebView) load_url_darwin(url string) ! {
	err := C.vtauri_wv_navigate(wv.native, &char(url.str))
	if err != 0 {
		return error('vtauri_wv_navigate failed: ${err}')
	}
}

// execute_js_darwin 在页面中执行一段 JavaScript。
fn (mut wv WebView) execute_js_darwin(js string) ! {
	err := C.vtauri_wv_eval(wv.native, &char(js.str))
	if err != 0 {
		return error('vtauri_wv_eval failed: ${err}')
	}
}

// post_message_darwin 将后端消息推送给前端。
// 通过向页面注入 `window.__vtauriOnEvent(<payload>)` 调用实现。
fn (mut wv WebView) post_message_darwin(payload string) ! {
	js := 'window.__vtauriOnEvent(${payload});'
	err := C.vtauri_wv_eval(wv.native, &char(js.str))
	if err != 0 {
		return error('vtauri_wv_eval failed: ${err}')
	}
}

// bind_invoke_darwin 将 __vtauriInvoke 暴露为页面全局函数，
// 前端调用它时路由到 App.handle_ipc 并把响应通过 vtauri_wv_return 回传。
fn (mut wv WebView) bind_invoke_darwin(app &App) ! {
	if isnil(wv.native) {
		return error('bind_invoke_darwin: webview not created')
	}
	// 手工分配绑定上下文（生命周期由 destroy_darwin 显式释放，避免 autofree 提前回收）
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

// run_darwin 进入 webview 的消息循环（阻塞，直到窗口关闭）。
fn (mut wv WebView) run_darwin() {
	C.vtauri_wv_run(wv.native)
}

// destroy_darwin 销毁 webview 实例并释放绑定上下文。
fn (mut wv WebView) destroy_darwin() {
	if !isnil(wv.bind_ctx) {
		unsafe { free(wv.bind_ctx) }
		wv.bind_ctx = unsafe { nil }
	}
	if !isnil(wv.native) {
		C.vtauri_wv_destroy(wv.native)
		wv.native = unsafe { nil }
	}
}
