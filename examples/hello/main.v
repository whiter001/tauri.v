// main.v — vtauri 最小示例应用
// 运行入口：读取配置 -> 构建 App -> 注册命令 -> 嵌入前端资源 -> 启动窗口。
//
// Windows 本机编译（MSVC）：
//   powershell -ExecutionPolicy Bypass -File ../../scripts/build_hello_msvc.ps1 -Run
// macOS 打包：scripts/bundle_macos.sh --exe hello --config vtauri.conf.json --out "vtauri hello.app"

module main

import vtauri
import json2

// 内嵌前端资源：入口 HTML 与 vtauri.js（编译期嵌入到可执行文件）。
const index_html = $embed_file('index.html')
const vtauri_js = $embed_file('../../js/vtauri.js')

fn main() {
	// 1. 读取配置
	cfg := vtauri.load_config(vtauri.bundled_config_path('vtauri.conf.json')) or {
		eprintln('config error: ${err}')
		vtauri.default_config()
	}

	// 2. 创建并装配 App
	mut app := vtauri.new_app(cfg)

	// 3. 注册命令：greet
	app.register_command('greet', vtauri.make_string_command(fn (name string) string {
		return 'Hello, ${name}! Greetings from the V backend.'
	}))

	// 4. 注册命令：add 两数相加（返回字符串结果，与 greet 的字符串语义保持一致）
	app.register_command('add', fn (args string) !string {
		nums := vtauri_decode_add(args)!
		return vtauri_encode_sum(nums)
	})

	// 5. 构建窗口 + WebView
	app.build() or {
		eprintln('build failed: ${err}')
		return
	}

	// 6. 渲染入口页面：把 vtauri.js 内联进 index.html，避免 set_html 时外部脚本 404
	html := vtauri.inline_asset(index_html.to_string(), vtauri_js.to_string())
	app.load_html(html) or {
		eprintln('load_html failed: ${err}')
		return
	}

	println('vtauri example "${cfg.product_name}" v${cfg.version} starting...')

	// 7. 进入消息循环（阻塞）
	app.run()
}

// --- add 命令的辅助 ---
struct AddArgs {
	a int
	b int
}

fn vtauri_decode_add(args string) ![]int {
	a := json2.decode[AddArgs](args) or { return err }
	return [a.a, a.b]
}

fn vtauri_encode_sum(nums []int) string {
	// 返回纯文本数字（而非 JSON 编码），保证前端 invoke 直接 resolve 得到可用的结果字符串
	return '${nums[0] + nums[1]}'
}
