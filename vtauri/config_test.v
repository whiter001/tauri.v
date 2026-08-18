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
}
