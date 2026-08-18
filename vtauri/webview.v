// webview.v — WebView2 渲染核心（Windows）
// 对应 Tauri 依赖的 wry（Windows 上为 WebView2 / Chromium Edge）。
//
// 说明：WebView2 通过 COM 接口与进程交互。其完整的 COM 绑定（ICoreWebView2Environment、
// ICoreWebView2Controller 等）需要在 Windows 运行时加载 WebView2Loader 并解析 vtable 才能
// 真正渲染。本文件先给出可编译、可扩展的骨架与调用约定，真正的渲染验证需在 Windows 主机上
// 结合 WebView2 运行时完成。

module vtauri

// WebView 抽象渲染接口。
pub struct WebView {
mut:
	window_handle voidptr // 承载 WebView 的父窗口 HWND
	initialized   bool
}

// new_webview 创建一个 WebView 实例并附着到指定父窗口。
// 返回的 WebView 默认未初始化（initialized=false），交由平台层完成初始化。
pub fn new_webview(parent_hwnd voidptr) WebView {
	return WebView{
		window_handle: parent_hwnd
		initialized:   false
	}
}

// load_url 让 WebView 加载一个 URL。
// 骨架实现：记录目标 URL，待 WebView2 初始化后执行。
pub fn (mut wv WebView) load_url(url string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	// TODO(windows): 调用 ICoreWebView2::Navigate
	eprintln('load_url: ${url}')
}

// load_html 让 WebView 直接渲染一段 HTML 字符串。
pub fn (mut wv WebView) load_html(html string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	// TODO(windows): 调用 ICoreWebView2::NavigateToString
	eprintln('load_html: (${html.len} bytes)')
}

// execute_js 在 WebView 中执行一段 JavaScript。
pub fn (mut wv WebView) execute_js(js string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	// TODO(windows): 调用 ICoreWebView2::ExecuteScript
	eprintln('execute_js: ${js}')
}

// post_message 将后端消息推送给前端（用于事件 emit）。
pub fn (mut wv WebView) post_message(payload string) ! {
	if !wv.initialized {
		return error('webview not initialized')
	}
	// TODO(windows): 通过 window.chrome.webview.postMessage 注入
	eprintln('post_message: ${payload}')
}
