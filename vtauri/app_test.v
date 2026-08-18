// app_test.v — 应用主类测试
module vtauri

import json

fn test_new_app_has_emit_command() {
	cfg := default_config()
	app := new_app(cfg)
	assert app.config.product_name == 'vtauri-app'
	// new_app 应内置注册 __emit 命令
	assert app.commands.has('__emit')
}

fn test_app_register_command() {
	mut app := new_app(default_config())
	app.register_command('ping', fn (args string) !string {
		return encode('pong')
	})
	assert app.commands.has('ping')
}

fn test_app_handle_ipc_success() {
	mut app := new_app(default_config())
	app.register_command('double', fn (args string) !string {
		n := decode[int](args) or { return error('bad num') }
		return encode(n * 2)
	})

	req := IpcRequest{
		id:      'abc'
		command: 'double'
		args:    '21'
	}
	resp_json := app.handle_ipc(encode_request(req))
	resp := json.decode(IpcResponse, resp_json) or { panic(err) }
	assert resp.id == 'abc'
	assert resp.ok == true
	assert decode[int](resp.result)! == 42
}

fn test_app_handle_ipc_missing_command() {
	mut app := new_app(default_config())
	req := IpcRequest{
		id:      'def'
		command: 'nope'
		args:    ''
	}
	resp_json := app.handle_ipc(encode_request(req))
	resp := json.decode(IpcResponse, resp_json) or { panic(err) }
	assert resp.id == 'def'
	assert resp.ok == false
	assert resp.error.contains('not found')
}

fn test_app_handle_ipc_bad_request() {
	mut app := new_app(default_config())
	// 传入非法的 JSON 请求串，应返回错误响应
	resp_json := app.handle_ipc('not-json{')
	resp := json.decode(IpcResponse, resp_json) or { panic(err) }
	assert resp.ok == false
	assert resp.error.contains('bad request')
}

fn test_app_emit_before_webview_ready() {
	mut app := new_app(default_config())
	// 骨架阶段 webview 未初始化，emit 应明确报错
	if _ := app.emit('event', '{}') {
		assert false
	} else {
		assert err.msg().contains('webview not initialized')
	}
}

fn test_app_build_non_windows() {
	mut app := new_app(default_config())
	// 非 Windows 平台 build 应创建桩窗口并标记 started
	app.build() or { panic(err) }
	assert app.started == true
	assert app.window.title == 'vtauri'
}
