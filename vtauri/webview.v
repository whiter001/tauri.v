// webview.v — WebView 渲染核心（跨平台抽象接口）
// 对应 Tauri 依赖的 wry（Windows 上为 WebView2 / Chromium Edge）。
//
// 平台实现：
//   - Windows: webview_windows.v —— 集成 webview/webview 库（其内部封装 WebView2）。
//   - macOS: webview_darwin.v —— 集成同一 webview/webview 库（其 macOS 后端为 WKWebView + Cocoa）。
//   - 其他平台：由本文件提供桩实现，保证在 Linux 上可编译测试。
//
// 说明：在 Windows/macOS 上，本模块通过 `native/webview_bridge.cc`（C++ 桥）调用
// webview/webview 的单头文件 C++ 库。该库负责 WebView2/WKWebView 的初始化、嵌入、
// resize、DPI、消息循环与 JS<->native 的绑定 IPC。

module vtauri

import json2

// WebView 抽象渲染接口。
pub struct WebView {
mut:
	window_handle voidptr // 承载 WebView 的父窗口 HWND
	native        voidptr // 平台 WebView 实例句柄（Windows/macOS 上为 vtauri_wv_t）
	initialized   bool
	bind_ctx      voidptr // 绑定回调上下文（Windows/macOS：WvBindCtx）
}

// new_webview 创建一个 WebView 实例并附着到指定父窗口。
// 尚未调用 attach() 前，initialized=false。
pub fn new_webview(parent_hwnd voidptr) WebView {
	return WebView{
		window_handle: parent_hwnd
		initialized:   false
	}
}

// attach 创建平台 WebView 并嵌入到父窗口。
// Windows 上会初始化 WebView2；成功后 initialized=true。
pub fn (mut wv WebView) attach() ! {
	$if windows {
		wv.attach_windows()!
	} $else $if macos {
		wv.attach_darwin()!
	} $else {
		// 非 Windows/macOS：标记为已初始化，便于核心逻辑（IPC/命令）在 Linux 上测试。
		wv.initialized = true
	}
}

// load_html 让 WebView 直接渲染一段 HTML 字符串。
pub fn (mut wv WebView) load_html(html string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	$if windows {
		wv.load_html_windows(html)!
	} $else $if macos {
		wv.load_html_darwin(html)!
	} $else {
		eprintln('load_html: (${html.len} bytes)')
	}
}

// load_url 让 WebView 加载一个 URL。
pub fn (mut wv WebView) load_url(url string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	$if windows {
		wv.load_url_windows(url)!
	} $else $if macos {
		wv.load_url_darwin(url)!
	} $else {
		eprintln('load_url: ${url}')
	}
}

// execute_js 在 WebView 中执行一段 JavaScript。
pub fn (mut wv WebView) execute_js(js string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	$if windows {
		wv.execute_js_windows(js)!
	} $else $if macos {
		wv.execute_js_darwin(js)!
	} $else {
		eprintln('execute_js: ${js}')
	}
}

// post_message 将后端消息推送给前端。
// 在 Windows/macOS 上通过注入 window.__vtauriOnEvent(...) 的 JS 调用实现。
pub fn (mut wv WebView) post_message(payload string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	$if windows {
		wv.post_message_windows(payload)!
	} $else $if macos {
		wv.post_message_darwin(payload)!
	} $else {
		eprintln('post_message: ${payload}')
	}
}

// bind_invoke 将前端 invoke 桥接到后端命令处理（App.handle_ipc）。
// 在 Windows/macOS 上会把 __vtauriInvoke / __vtauriEmit 暴露为页面全局函数。
pub fn (mut wv WebView) bind_invoke(app &App) ! {
	$if windows {
		wv.bind_invoke_windows(app)!
	} $else $if macos {
		wv.bind_invoke_darwin(app)!
	} $else {
		// 非 Windows/macOS：无实际绑定，保证可编译。
	}
}

// run 进入平台消息循环（阻塞，直到窗口关闭）。
pub fn (mut wv WebView) run() {
	$if windows {
		wv.run_windows()
	} $else $if macos {
		wv.run_darwin()
	}
}

// destroy 关闭并销毁 WebView。
pub fn (mut wv WebView) destroy() {
	$if windows {
		wv.destroy_windows()
	} $else $if macos {
		wv.destroy_darwin()
	}
	wv.initialized = false
}

// set_window_props 设置窗口标题、尺寸与可否调整大小（仅 macOS 有效：macOS 上窗口由 webview 库自建）。
// resizable=false 时窗口不可调整大小（WEBVIEW_HINT_FIXED）。
pub fn (mut wv WebView) set_window_props(title string, width int, height int, center bool, resizable bool) {
	$if macos {
		wv.set_window_props_darwin(title, width, height, center, resizable)
	}
}

// terminate 终止平台事件循环（Windows/macOS 有效，其余平台 no-op）。
pub fn (mut wv WebView) terminate() {
	$if windows {
		wv.terminate_windows()
	} $else $if macos {
		wv.terminate_darwin()
	}
}

// install_app_menu 安装应用菜单栏（仅 macOS 有效）。
pub fn (mut wv WebView) install_app_menu(app_name string) {
	$if macos {
		wv.install_app_menu_darwin(app_name)
	}
}

// 绑定回调上下文：同时持有 webview 句柄与 App 指针，作为 userdata 传给 webview_bind。
struct WvBindCtx {
mut:
	webview voidptr
	app     &App
}

// vtauri_on_invoke 是页面调用 __vtauriInvoke(...) 时触发的 C 回调。
// req 是 JS 实参的 JSON 数组字符串（形如 ["<ipcRequestJson>"]）。
fn vtauri_on_invoke(id &char, req &char, userdata voidptr) {
	$if windows || macos {
		ctx := unsafe { &WvBindCtx(userdata) }
		id_str := unsafe { cstring_to_vstring(id) }
		req_str := unsafe { cstring_to_vstring(req) }

		// 取出 IpcRequest JSON（webview 会把实参包装成 JSON 数组）
		req_json := bind_extract_arg0(req_str)

		mut app := ctx.app
		resp_json := app.handle_ipc(req_json)

		// 用 webview 内部生成的 seq(id) 兑现前端 Promise
		C.vtauri_wv_return(ctx.webview, &char(id_str.str), 0, &char(resp_json.str))
	} $else {
		// 非 Windows/macOS：无 C 桥接声明，函数体为空桩以保证可编译。
	}
}

// bind_extract_arg0 从 JS 实参的 JSON 数组字符串中取出第 0 个元素。
fn bind_extract_arg0(arr string) string {
	items := json2.decode[[]string](arr) or { return '' }
	if items.len > 0 {
		return items[0]
	}
	return ''
}
