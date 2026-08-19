// main.v — vtauri + Vue 3 示例应用
//
// 前端：examples/vue/frontend（Vite + Vue3），构建为单个 index.html 后在此嵌入。
//
// 两种加载模式：
//   A. 打包模式（默认）：加载编译期内嵌的 frontend/dist/index.html。
//   B. 开发模式（start 模式）：设置环境变量 VTAURI_DEV_URL 后，改为加载本地
//      Vite dev server（如 http://localhost:5173），支持前端热更新。
//
// 构建与运行：
//   1. 构建前端（生成 frontend/dist/index.html）：
//      bash ../../scripts/build_example_frontends.sh vue
//   2. Windows 编译（MSVC，V 自动编译 native/webview_bridge.cpp 为 .obj 并链接）：
//      powershell -ExecutionPolicy Bypass -File ../../scripts/build_examples_msvc.ps1 -Example vue
//   3. 运行 vue.exe（目标机需安装 WebView2 Runtime）
//
// 开发模式（前端热更新）：
//   # 终端 1：启动 Vite dev server
//   cd examples/vue/frontend && npm run dev
//   # 终端 2：指定 dev URL 再启动应用（Linux/macOS 用 VTAURI_DEV_URL=...）
//   set VTAURI_DEV_URL=http://localhost:5173
//   vue.exe
//
// 注意：单 HTML 构建产物里已内联 js/vtauri.js（window.__VTauri），
// 因此打包模式直接 load_html，无需像 examples/hello 那样再调用 inline_asset。

module main

import vtauri
import json2
import os

// 内嵌前端构建产物：Vite 单文件构建后的 dist/index.html（编译期嵌入可执行文件）。
const index_html = $embed_file('frontend/dist/index.html')

fn main() {
	// 1. 读取配置
	cfg := vtauri.load_config('vtauri.conf.json') or {
		eprintln('config error: ${err}')
		vtauri.default_config()
	}

	// 2. 创建并装配 App
	mut app := vtauri.new_app(cfg)

	// 3. 注册命令：greet（字符串参数 / 字符串返回）
	app.register_command('greet', vtauri.make_string_command(fn (name string) string {
		return 'Hello, ${name}! Greetings from the V backend.'
	}))

	// 4. 注册命令：add（JSON 对象参数 / 数字返回）
	app.register_command('add', fn (args string) !string {
		nums := vtauri_decode_add(args)!
		return vtauri_encode_sum(nums)
	})

	// 5. 注册命令：info（无参数 / JSON 对象返回，测试复杂数据往返）
	app.register_command('info', fn (args string) !string {
		return '{"app":"vtauri-vue","version":"0.1.0","backend":"V 0.5.2","commands":["greet","add","info"]}'
	})

	// 6. 构建窗口 + WebView
	app.build() or {
		eprintln('build failed: ${err}')
		return
	}

	// 7. 加载前端：开发模式走 load_url(localhost dev server)，否则加载内嵌单 HTML
	dev_url := os.getenv('VTAURI_DEV_URL')
	if dev_url != '' {
		// start 模式：加载本地 Vite dev server，前端改动即时生效
		println('dev mode: loading ${dev_url}')
		app.load_url(dev_url) or {
			eprintln('load_url failed: ${err}')
			return
		}
	} else {
		// 打包模式：渲染编译期内嵌的前端构建产物
		app.load_html(index_html.to_string()) or {
			eprintln('load_html failed: ${err}')
			return
		}
	}

	println('vtauri example "${cfg.product_name}" v${cfg.version} starting...')

	// 8. 进入消息循环（阻塞）
	app.run()
}

// --- add 命令的辅助（与 examples/hello 保持一致）---
struct AddArgs {
	a int
	b int
}

fn vtauri_decode_add(args string) ![]int {
	a := json2.decode[AddArgs](args) or { return err }
	return [a.a, a.b]
}

fn vtauri_encode_sum(nums []int) string {
	// 返回纯文本数字（而非 JSON 编码），保证前端 invoke 直接 resolve 得到可用的结果
	return '${nums[0] + nums[1]}'
}
