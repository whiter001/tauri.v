// config_test.v — 配置系统测试
module vtauri

import os

fn test_load_config() {
	dir := os.temp_dir()
	cfg_path := os.join_path(dir, 'vtauri_test.conf.json')
	os.write_file(cfg_path,
		'{"productName":"t","identifier":"com.t","version":"1.2.3","app":{"windows":[{"title":"w","width":640,"height":480,"center":true}]}}') or {
		panic(err)
	}

	cfg := load_config(cfg_path) or { panic(err) }
	assert cfg.product_name == 't'
	assert cfg.identifier == 'com.t'
	assert cfg.version == '1.2.3'
	assert cfg.main_window.title == 'w'
	assert cfg.main_window.width == 640
	assert cfg.main_window.height == 480
	assert cfg.main_window.center == true

	os.rm(cfg_path) or {}
}

fn test_load_config_missing_file() {
	if _ := load_config('/nonexistent/path.json') {
		assert false
	} else {
		assert err.msg().contains('cannot read config')
	}
}

fn test_default_config() {
	cfg := default_config()
	assert cfg.product_name == 'vtauri-app'
	assert cfg.main_window.width == 800
	assert cfg.main_window.height == 600
	assert cfg.main_window.center == true
	assert cfg.main_window.resizable == true
}

fn test_load_config_defaults_match() {
	// 窗口缺失时，load_config 的默认值应与 default_config 保持一致
	dir := os.temp_dir()
	cfg_path := os.join_path(dir, 'vtauri_test_defaults.conf.json')
	os.write_file(cfg_path, '{"productName":"d","identifier":"com.d","version":"0.0.1","app":{}}') or {
		panic(err)
	}

	cfg := load_config(cfg_path) or { panic(err) }
	default := default_config()
	assert cfg.main_window.center == default.main_window.center
	assert cfg.main_window.resizable == default.main_window.resizable

	os.rm(cfg_path) or {}
}

fn test_bundled_config_path_fallback() {
	// 非 .app 环境下应原样返回传入路径
	assert bundled_config_path('vtauri.conf.json') == 'vtauri.conf.json'
}
