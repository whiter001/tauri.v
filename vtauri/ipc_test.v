// ipc_test.v — IPC 协议测试
module vtauri


fn test_ipc_roundtrip() {
	req := IpcRequest{
		id:      'r1'
		command: 'greet'
		args:    '"whiter"'
	}
	encoded := encode_request(req)
	decoded := decode_request(encoded) or { panic(err) }
	assert decoded.id == 'r1'
	assert decoded.command == 'greet'
	assert decoded.args == '"whiter"'
}

fn test_handle_request_ok() {
	mut reg := new_command_registry()
	reg.register('add', fn (args string) !string {
		return 'res'
	})
	req := IpcRequest{
		id:      'x'
		command: 'add'
		args:    ''
	}
	resp := handle_request(&reg, req)
	assert resp.ok == true
	assert resp.result == 'res'
	assert resp.id == 'x'
}

fn test_handle_request_err() {
	reg := new_command_registry()
	req := IpcRequest{
		id:      'y'
		command: 'missing'
		args:    ''
	}
	resp := handle_request(&reg, req)
	assert resp.ok == false
	assert resp.error.contains('not found')
}

fn test_event_encode() {
	ev := IpcEvent{
		event:   'update'
		payload: '{"n":1}'
	}
	encoded := encode_event(ev)
	assert encoded.contains('update')
	assert encoded.contains('n')
	// payload 中的引号会被 JSON 转义为 \"
	assert encoded.contains('\\"n\\":1')
}
