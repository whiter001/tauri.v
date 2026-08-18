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

// build 使用配置创建主窗口并附着 WebView，完成应用装配。
pub fn (mut app App) build() ! {
	c := app.config.main_window
	w := new_window(c.title, int(c.width), int(c.height), c.center)!
	app.window = w
	app.webview = new_webview(w.handle)
	app.started = true
}

// run 进入应用主循环（阻塞，直到窗口关闭）。
pub fn (mut app App) run() {
	app.window.run_message_loop()
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
// 注意：WebView 尚未完成初始化时（骨架阶段 WebView2 未就绪），emit 无法投递事件，
// 这里显式返回错误提示，避免在 post_message 内部产生模糊的“webview not initialized”。
pub fn (mut app App) emit(event_name string, payload string) ! {
	if !app.webview.initialized {
		return error('emit failed: webview not initialized (WebView2 尚未就绪，事件广播待实现)')
	}
	ev := IpcEvent{
		event:   event_name
		payload: payload
	}
	app.webview.post_message(encode_event(ev))!
}
