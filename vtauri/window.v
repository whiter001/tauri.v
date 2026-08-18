// window.v — 跨平台窗口抽象接口
// 对应 Tauri 依赖的 tao/winit 窗口层。
//
// 平台实现：
//   - Windows: window_windows.v（Win32 API）
//   - 其他平台：由本文件提供桩实现，保证在 Linux 上可编译测试。

module vtauri

// Window 代表一个原生窗口（平台无关的描述结构）。
pub struct Window {
pub mut:
	handle   voidptr // 平台窗口句柄（HWND 等），无窗口时为 0
	title    string
	width    int
	height   int
	is_alive bool
}

// new_window 创建并显示一个窗口。在非 Windows 平台仅返回桩对象。
pub fn new_window(title string, width int, height int, center bool) !Window {
	// 平台实现见 window_windows.v（Windows）与下方桩（其他平台）
	return new_window_impl(title, width, height, center)
}

// new_window_impl 由各平台文件实现。
fn new_window_impl(title string, width int, height int, center bool) !Window {
	$if windows {
		return new_window_windows(title, width, height, center)
	} $else {
		return Window{
			handle:   0
			title:    title
			width:    width
			height:   height
			is_alive: false
		}
	}
}

// run_message_loop 启动平台消息循环，直到窗口关闭。
pub fn (mut w Window) run_message_loop() {
	$if windows {
		w.run_message_loop_windows()
	} $else {
		// 非 Windows：不阻塞，供跨平台测试
		w.is_alive = false
	}
}

// destroy 关闭并销毁窗口。
pub fn (mut w Window) destroy() {
	$if windows {
		w.destroy_windows()
	} $else {
		// no-op
	}
	w.is_alive = false
}
