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

	// 4b. 注册命令：dialog_msg / dialog_open / dialog_save 原生系统对话框
	app.register_command('dialog_msg', vtauri.make_string_command(fn (args string) string {
		vtauri.message_box('提示', '来自 V 后端的消息框')
		return '已显示'
	}))

	app.register_command('dialog_open', vtauri.make_string_command(fn (args string) string {
		path := vtauri.open_file_dialog('选择文件', ['png', 'jpg', 'txt'])
		if path == '' {
			return '已取消'
		}
		return path
	}))

	app.register_command('dialog_save', vtauri.make_string_command(fn (args string) string {
		path := vtauri.save_file_dialog('保存文件', 'untitled.txt')
		if path == '' {
			return '已取消'
		}
		return path
	}))

	// 4c. 注册命令：notify_demo / clip_write / clip_read / open_url 系统能力。
	// 命令 handler 返回的是 JSON 字符串（vtauri.encode），前端 JSON.parse 后直接显示。
	// 错误按提示字符串返回（而非 IPC 错误），前端无需特殊处理即可展示 err 文本。
	app.register_command('notify_demo', fn (args string) !string {
		vtauri.notify('vtauri hello', '来自 V 后端的通知') or {
			return vtauri.encode('通知失败：${err}')
		}
		return vtauri.encode('已发送通知')
	})

	app.register_command('clip_write', fn (args string) !string {
		vtauri.clipboard_write_text('Hello from vtauri!')
		return vtauri.encode('已写入剪贴板')
	})

	app.register_command('clip_read', fn (args string) !string {
		text := vtauri.clipboard_read_text()
		if text == '' {
			return vtauri.encode('（剪贴板无文本）')
		}
		return vtauri.encode(text)
	})

	app.register_command('open_url', fn (args string) !string {
		vtauri.shell_open('https://vlang.io') or { return vtauri.encode('打开失败：${err}') }
		return vtauri.encode('已打开')
	})

	// 5. 构建窗口 + WebView
	app.build() or {
		eprintln('build failed: ${err}')
		return
	}

	// 5b. 自定义应用菜单栏：完全替换 build() 安装的默认菜单栏。
	// 第一个菜单（App）的标题会被系统强制显示为应用名；动作项（action）走系统
	// responder chain（撤销/剪切/复制…），自定义项（id）经回调回传。
	app.set_menus([
		vtauri.MenuDef{
			title: 'App'
			items: [
				vtauri.MenuItemDef{ action: 'orderFrontStandardAboutPanel:', label: '关于 vtauri' }
				vtauri.MenuItemDef{ separator: true }
				vtauri.MenuItemDef{ id: 'quit', label: '退出 vtauri', key: 'q', mods: vtauri.mod_cmd }
			]
		}
		vtauri.MenuDef{
			title: '编辑'
			items: [
				vtauri.MenuItemDef{ action: 'undo:', label: '撤销', key: 'z', mods: vtauri.mod_cmd }
				vtauri.MenuItemDef{ action: 'redo:', label: '重做', key: 'z', mods: vtauri.mod_cmd | vtauri.mod_shift }
				vtauri.MenuItemDef{ separator: true }
				vtauri.MenuItemDef{ action: 'cut:', label: '剪切', key: 'x', mods: vtauri.mod_cmd }
				vtauri.MenuItemDef{ action: 'copy:', label: '拷贝', key: 'c', mods: vtauri.mod_cmd }
				vtauri.MenuItemDef{ action: 'paste:', label: '粘贴', key: 'v', mods: vtauri.mod_cmd }
				vtauri.MenuItemDef{ action: 'selectAll:', label: '全选', key: 'a', mods: vtauri.mod_cmd }
			]
		}
		vtauri.MenuDef{
			title: '工具'
			items: [
				vtauri.MenuItemDef{ id: 'demo.notify', label: '发送通知' }
				vtauri.MenuItemDef{ id: 'demo.open', label: '打开 vlang.io' }
			]
		}
	], fn [mut app] (id string) {
		match id {
			'quit' { app.quit() }
			'demo.notify' { vtauri.notify('vtauri hello', '来自应用菜单') or { eprintln('notify failed: ${err}') } }
			'demo.open' { vtauri.shell_open('https://vlang.io') or { eprintln('open failed: ${err}') } }
			else {}
		}
	})

	// 5c. 系统托盘：菜单栏右侧文本图标 + 菜单项。
	// 回调闭包用 [mut app] 捕获 app 的可变拷贝（V 闭包捕获按值拷贝，
	// app.quit() 通过拷贝里的 webview 原生句柄同样能终止事件循环）。
	mut tray := vtauri.new_tray('VT') or { panic(err) }
	// 图片图标：36x36 PNG（examples/hello/tray_icon.png，template 渲染）。
	// 直接跑二进制时 cwd 为项目根，相对路径可解析；打包后 cwd 不确定，
	// 加载失败时 or {} 容忍（托盘回退为文本图标）。
	tray.set_icon('examples/hello/tray_icon.png') or {
		eprintln('tray.set_icon failed: ${err}')
	}
	tray.add_item('about', '关于 vtauri')
	tray.add_item('quit', '退出')
	tray.on_menu_click(fn [mut app] (id string) {
		match id {
			'about' { vtauri.message_box('vtauri hello', '由 V 语言实现的 Tauri 风格框架') }
			'quit' { app.quit() }
			else {}
		}
	})

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
