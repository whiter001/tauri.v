// command_test.v — 命令系统测试
module vtauri

fn test_register_and_invoke() {
	mut reg := new_command_registry()
	reg.register('double', fn (args string) !string {
		n := decode[int](args) or { return error('bad num') }
		return encode(n * 2)
	})

	assert reg.has('double')
	assert !reg.has('missing')

	res := reg.invoke('double', '21') or { panic(err) }
	assert decode[int](res)! == 42
}

fn test_invoke_missing() {
	reg := new_command_registry()
	if _ := reg.invoke('nope', '') {
		assert false
	} else {
		assert err.msg().contains('not found')
	}
}

fn test_make_string_command() {
	h := make_string_command(fn (s string) string {
		return 'hi:' + s
	})
	res := h('v') or { panic(err) }
	assert decode[string](res)! == 'hi:v'
}
