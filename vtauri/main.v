// main.v — vtauri 可执行入口（示例应用）
// 让 `v run .` / `v .` 能在本目录直接编译运行。
//
// 说明：
//   - 该文件提供 `main` 模块，作为 vtauri 库的一个可运行示例，
//     解决“project must include a main module”的编译报错。
//   - 库本身的单元测试仍用 `v test .` 执行，不受本文件影响。

module main

import vtauri

fn main() {
	// 1. 读取配置并构建 App
	mut app := vtauri.new_app(vtauri.default_config())

	// 2. 注册一个示例命令，前端可 invoke('ping')
	app.register_command('ping', fn (args string) !string {
		return '{"pong":"${args}"}'
	})

	// 3. 装配主窗口与 WebView
	app.build() or {
		eprintln('build failed: ${err}')
		return
	}

	// 4. 演示 IPC：直接调用一个命令
	resp := app.handle_ipc('{"id":"1","command":"ping","args":"hi"}')
	println('ipc response: ${resp}')

	// 5. 进入消息循环（Windows 上阻塞直到窗口关闭；其他平台桩实现立即返回）
	app.run()
}
