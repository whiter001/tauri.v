// app.v — vtauri 应用主类
// 对应 Tauri 的 tauri core：整合配置、窗口、webview、命令注册表与 IPC。

module vtauri

// App 是 vtauri 应用的核心聚合体。
pub struct App {
pub:
	config AppConfig
mut:
	window   Window
	webview  WebView
	commands CommandRegistry
	started  bool
}

// new_app 根据一份配置创建一个 App（尚未启动窗口）。
pub fn new_app(cfg AppConfig) App {
	return App{
		config:   cfg
		commands: new_command_registry()
	}
}

// build 使用配置创建主窗口，附着 WebView 并接通 IPC，完成应用装配。
// 完成后：
//   - 创建并显示原生窗口（Windows 上为 Win32 窗口；macOS 上由 webview 库自建 NSWindow）；
//   - 在 Windows 上创建 WebView2 并嵌入窗口，把 __vtauriInvoke 暴露为页面全局函数；
//     在 macOS 上由 webview 库自建 NSWindow，应用配置的标题/尺寸/可调性，并自动安装
//     标准应用菜单栏（About/Quit + Edit 全套，提供 Cmd+Q 与复制粘贴快捷键）；
//   - 之后由调用方通过 load_html / load_url 加载入口页面。
pub fn (mut app App) build() ! {
	c := app.config.main_window
	w := new_window(c.title, int(c.width), int(c.height), c.center)!
	app.window = w

	mut wv := new_webview(w.handle)
	wv.attach()!
	$if macos {
		wv.set_window_props(c.title, int(c.width), int(c.height), c.center, c.resizable)
		wv.install_app_menu(app.config.product_name)
	}
	wv.bind_invoke(&app)!
	app.webview = wv
	app.started = true
}

// quit 退出应用（终止平台事件循环）。
pub fn (mut app App) quit() {
	app.webview.terminate()
}

// load_html 将一段 HTML 字符串渲染到主窗口的 WebView 中。
pub fn (mut app App) load_html(html string) ! {
	app.webview.load_html(html)!
}

// load_url 让主窗口的 WebView 加载一个 URL。
pub fn (mut app App) load_url(url string) ! {
	app.webview.load_url(url)!
}

// run 进入应用主循环（阻塞，直到窗口关闭）。
pub fn (mut app App) run() {
	app.webview.run()
}

// register_command 注册一个命令到命令注册表。
pub fn (mut app App) register_command(name string, h CommandHandler) {
	app.commands.register(name, h)
}

// handle_ipc 处理一条来自前端的 IPC 消息，返回响应 JSON。
pub fn (mut app App) handle_ipc(request_json string) string {
	req := decode_request(request_json) or {
		return encode_response(IpcResponse{
			id:    ''
			ok:    false
			error: 'bad request: ${err}'
		})
	}
	resp := handle_request(&app.commands, req)
	return encode_response(resp)
}

// emit 向后端向前端广播一个事件。
// 在 Windows 上通过向页面注入 window.__vtauriOnEvent(...) 实现（需页面已加载 vtauri.js）。
pub fn (mut app App) emit(event_name string, payload string) ! {
	if !app.webview.initialized {
		return error('emit failed: webview not initialized')
	}
	ev := IpcEvent{
		event:   event_name
		payload: payload
	}
	app.webview.post_message(encode_event(ev))!
}

// inline_asset 把一段 JavaScript 内联进 HTML，用于解决 `set_html` 渲染时
// `<script src="...">` 无法加载外部文件（无 file:// 基址）的问题。
// 它优先替换形如 `<script src="vtauri.js"></script>` 的占位标签；
// 找不到时则把脚本插入到 `</head>` 之前，仍找不到则插入到文档开头。
pub fn inline_asset(html string, js string) string {
	marker := '<script src="vtauri.js"></script>'
	if html.contains(marker) {
		return html.replace(marker, '<script>\n${js}\n</script>')
	}
	head_end := '</head>'
	if html.contains(head_end) {
		return html.replace(head_end, '<script>\n${js}\n</script>\n${head_end}')
	}
	return '<script>\n${js}\n</script>\n${html}'
}
