// main.v — vtauri 远程 URL 加载示例
//
// 演示 app.load_url：把 WebView 导航到远程页面，默认嵌套 https://vlang.io。
// 可用于验证「远程加载方案」——WebView 不渲染内嵌 HTML，而是直接加载一个 URL。
//
// 说明：
//   - 默认加载 https://vlang.io（vtauri 的 V 语言官网）。
//   - 可通过环境变量 VTAURI_REMOTE_URL 覆盖为任意 URL（如本地 dev server）。
//   - __vtauriInvoke 由原生桥在每次文档加载时注入，因此远程页面上只要引入了
//     js/vtauri.js（window.__VTauri），依然可以调用这里注册的后端命令。
//
// 构建与运行：
//   powershell -ExecutionPolicy Bypass -File ../../scripts/build_examples_msvc.ps1 -Example remote -Run
//   # 自定义 URL：set VTAURI_REMOTE_URL=https://example.com && remote.exe
//
// 目标机需安装 WebView2 Runtime。

module main

import vtauri
import os

// 默认加载的远程页面（vlang.io —— V 语言官网）。
const default_url = 'https://vlang.io'

fn main() {
	// 1. 读取配置
	cfg := vtauri.load_config('vtauri.conf.json') or {
		eprintln('config error: ${err}')
		vtauri.default_config()
	}

	// 2. 创建并装配 App
	mut app := vtauri.new_app(cfg)

	// 3. 注册命令：greet（远程页面接入 vtauri.js 后可通过 __VTauri.invoke 调用）
	app.register_command('greet', vtauri.make_string_command(fn (name string) string {
		return 'Hello, ${name}! Greetings from the V backend.'
	}))

	// 4. 构建窗口 + WebView
	app.build() or {
		eprintln('build failed: ${err}')
		return
	}

	// 5. 确定要加载的 URL：默认 vlang.io，可用 VTAURI_REMOTE_URL 覆盖
	mut url := default_url
	override_url := os.getenv('VTAURI_REMOTE_URL')
	if override_url != '' {
		url = override_url
	}

	// 6. 远程加载：WebView 直接导航到 URL
	app.load_url(url) or {
		eprintln('load_url failed: ${err}')
		return
	}

	println('vtauri remote example loading "${url}" ...')

	// 7. 进入消息循环（阻塞）
	app.run()
}
