// config.v — 应用配置系统
// 对应 Tauri 的 tauri.conf.json 编译期配置解析。
// 在 vtauri 中我们于运行时解析一份 JSON 配置文件。

module vtauri

import os

// AppConfig 描述一个 vtauri 应用的整体配置，对应 tauri.conf.json。
pub struct AppConfig {
pub:
	product_name string       // 应用名（productName）
	identifier   string       // 应用标识（bundle.identifier）
	version      string       // 应用版本
	main_window  WindowConfig // 主窗口配置
}

// WindowConfig 描述主窗口的几何与标题等。
pub struct WindowConfig {
pub:
	title     string // 窗口标题
	width     f64    // 窗口宽度（像素）
	height    f64    // 窗口高度（像素）
	center    bool   // 是否在屏幕居中
	resizable bool   // 是否可调整大小
}

// --- JSON 中间层（保持与 tauri.conf.json 字段命名一致） ---

struct RawWindow {
	title     string
	width     f64
	height    f64
	center    bool
	resizable bool
}

struct RawAppWindows {
	windows []RawWindow
}

struct RawConfig {
	product_name string @[json: 'productName']
	identifier   string
	version      string
	app          RawAppWindows
}

// load_config 从指定路径读取并解析 vtauri.conf.json。
// 返回 AppConfig 或错误信息。
pub fn load_config(path string) !AppConfig {
	data := os.read_file(path) or { return error('cannot read config file: ${path}') }
	raw := decode[RawConfig](data) or { return error('invalid config JSON: ${err}') }

	// 取第一个窗口作为主窗口；缺省时给默认值（与 default_config 保持一致）
	mut wt := ''
	mut ww := f64(0)
	mut wh := f64(0)
	mut wc := true // 默认居中，与 default_config 一致
	mut wr := true // 默认可调整大小，与 default_config 一致
	if raw.app.windows.len > 0 {
		w := raw.app.windows[0]
		wt = w.title
		ww = w.width
		wh = w.height
		wc = w.center
		wr = w.resizable
	}

	cfg := AppConfig{
		product_name: if raw.product_name != '' { raw.product_name } else { 'vtauri-app' }
		identifier:   raw.identifier
		version:      if raw.version != '' { raw.version } else { '0.1.0' }
		main_window:  WindowConfig{
			title:     if wt != '' { wt } else { 'vtauri' }
			width:     if ww > 0 { ww } else { 800 }
			height:    if wh > 0 { wh } else { 600 }
			center:    wc
			resizable: wr
		}
	}
	return cfg
}

// default_config 返回一份默认配置，便于快速起步。
pub fn default_config() AppConfig {
	return AppConfig{
		product_name: 'vtauri-app'
		identifier:   'com.vlang.vtauri'
		version:      '0.1.0'
		main_window:  WindowConfig{
			title:     'vtauri'
			width:     800
			height:    600
			center:    true
			resizable: true
		}
	}
}

// bundled_config_path 若可执行文件位于 .app 包内且 Resources 下存在同名配置文件，
// 返回包内路径；否则原样返回传入路径（保持现有 cwd 相对路径行为）。
pub fn bundled_config_path(path string) string {
	exe := os.executable()
	res := os.join_path(os.dir(exe), '..', 'Resources', os.file_name(path))
	if os.exists(res) {
		return res
	}
	return path
}
