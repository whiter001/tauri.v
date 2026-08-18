// webview.v — WebView 渲染核心（跨平台抽象接口）
// 对应 Tauri 依赖的 wry（Windows 上为 WebView2 / Chromium Edge）。
//
// 平台实现：
//   - Windows: webview_windows.v —— 集成 webview/webview 库（其内部封装 WebView2）。
//   - 其他平台：由本文件提供桩实现，保证在 Linux 上可编译测试。
//
// 说明：在 Windows 上，本模块通过 `native/webview_bridge.cc`（C++ 桥）调用
// webview/webview 的单头文件 C++ 库。该库负责 WebView2 的初始化、嵌入、
// resize、DPI、消息循环与 JS<->native 的绑定 IPC。

module vtauri

// WebView 抽象渲染接口。
pub struct WebView {
mut:
	window_handle voidptr // 承载 WebView 的父窗口 HWND
	native        voidptr // 平台 WebView 实例句柄（Windows 上为 vtauri_wv_t）
	initialized   bool
	bind_ctx      voidptr // 绑定回调上下文（Windows：WvBindCtx）
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
	} $else {
		// 非 Windows：标记为已初始化，便于核心逻辑（IPC/命令）在 Linux 上测试。
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
	} $else {
		eprintln('execute_js: ${js}')
	}
}

// post_message 将后端消息推送给前端。
// 在 Windows 上通过注入 window.__vtauriOnEvent(...) 的 JS 调用实现。
pub fn (mut wv WebView) post_message(payload string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	$if windows {
		wv.post_message_windows(payload)!
	} $else {
		eprintln('post_message: ${payload}')
	}
}

// bind_invoke 将前端 invoke 桥接到后端命令处理（App.handle_ipc）。
// 在 Windows 上会把 __vtauriInvoke / __vtauriEmit 暴露为页面全局函数。
pub fn (mut wv WebView) bind_invoke(app &App) ! {
	$if windows {
		wv.bind_invoke_windows(app)!
	} $else {
		// 非 Windows：无实际绑定，保证可编译。
	}
}

// run 进入平台消息循环（阻塞，直到窗口关闭）。
pub fn (mut wv WebView) run() {
	$if windows {
		wv.run_windows()
	}
}

// destroy 关闭并销毁 WebView。
pub fn (mut wv WebView) destroy() {
	$if windows {
		wv.destroy_windows()
	}
	wv.initialized = false
}
