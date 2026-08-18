// window_windows.v — Windows Win32 窗口实现
// 仅当编译目标为 Windows 时由 V 自动编译（文件后缀 _windows.v）。
// 对应 tauri/tao 在 Windows 上的窗口层，使用原生 Win32 API。
//
// 说明：这里不包含 <windows.h>，而是手动声明所需的 Win32 类型、函数与常量，
// 以便 V 能精确控制结构体布局与链接。

module vtauri

#flag windows -luser32

// --- 类型 ---

// WNDPROC 窗口过程回调类型。
pub type WNDPROC = fn (voidptr, u32, usize, isize) isize

// WNDCLASSEXW 窗口类结构（与 Win32 定义的内存布局一致）。
struct C.WNDCLASSEXW {
	cb_size         u32
	style           u32
	lpfn_wnd_proc   WNDPROC
	cb_cls_extra    int
	cb_wnd_extra    int
	h_instance      voidptr
	h_icon          voidptr
	h_cursor        voidptr
	hbr_background  voidptr
	lpsz_menu_name  &u16
	lpsz_class_name &u16
	h_icon_sm       voidptr
}

// MSG 消息结构。
struct C.MSG {
	hwnd    voidptr
	message u32
	w_param usize
	l_param isize
	time    u32
	pt_x    int
	pt_y    int
}

// --- 常量 ---
const wnd_class_name = 'vtauri_window'
// 窗口样式
const ws_overlappedwindow = u32(0x00CF0000) // WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX

const cs_hredraw = u32(0x0002)
const cs_vredraw = u32(0x0001)
// 系统指标
const sm_cxscreen = 0
const sm_cyscreen = 1
// 消息
const wm_destroy = u32(0x0002)
const wm_close = u32(0x0010)
// 光标
const idc_arrow = usize(32512) // MAKEINTRESOURCE(IDC_ARROW)

// 显示方式
const sw_show = 5

// --- 函数声明 ---
fn C.GetModuleHandleW(lp_module_name &u16) voidptr
fn C.RegisterClassExW(cls &C.WNDCLASSEXW) u16
fn C.CreateWindowExW(dw_ex_style u32, lp_class_name &u16, lp_window_name &u16, dw_style u32,
	x i32, y i32, n_width i32, n_height i32, h_wnd_parent voidptr, h_menu voidptr,
	h_instance voidptr, lp_param voidptr) voidptr
fn C.DefWindowProcW(h_wnd voidptr, msg u32, w_param usize, l_param isize) isize
fn C.ShowWindow(h_wnd voidptr, n_cmd_show i32)
fn C.UpdateWindow(h_wnd voidptr)
fn C.DestroyWindow(h_wnd voidptr)
fn C.GetMessageW(lp_msg &C.MSG, h_wnd voidptr, w_msg_filter_min u32, w_msg_filter_max u32) i32
fn C.TranslateMessage(lp_msg &C.MSG) i32
fn C.DispatchMessageW(lp_msg &C.MSG) isize
fn C.PostQuitMessage(n_exit_code i32)
fn C.GetSystemMetrics(n_index i32) i32
fn C.LoadCursorW(h_instance voidptr, lp_cursor_name usize) voidptr

// --- 实现 ---

// new_window_windows 创建并显示一个原生 Win32 窗口。
fn new_window_windows(title string, width int, height int, center bool) !Window {
	hinstance := C.GetModuleHandleW(0)
	// to_wide() 返回临时数组，直接取地址会随语句结束被释放（悬垂指针）。
	// 必须在函数作用域内持有该数组，使其生命周期覆盖到 RegisterClassExW 调用之后。
	class_name_wide := wnd_class_name.to_wide()
	wndclass := C.WNDCLASSEXW{
		cb_size:         u32(sizeof(C.WNDCLASSEXW))
		style:           cs_hredraw | cs_vredraw
		lpfn_wnd_proc:   wnd_proc_windows
		h_instance:      hinstance
		h_cursor:        C.LoadCursorW(unsafe { nil }, idc_arrow)
		lpsz_class_name: &u16(class_name_wide[0])
	}
	C.RegisterClassExW(&wndclass)

	mut x := 0
	mut y := 0
	if center {
		sw := C.GetSystemMetrics(sm_cxscreen)
		sh := C.GetSystemMetrics(sm_cyscreen)
		x = (sw - width) / 2
		y = (sh - height) / 2
	}

	hwnd := C.CreateWindowExW(0, wnd_class_name.to_wide(), title.to_wide(), ws_overlappedwindow, x,
		y, width, height, unsafe { nil }, unsafe { nil }, hinstance, unsafe { nil })
	if isnil(hwnd) {
		return error('CreateWindowExW failed')
	}
	C.ShowWindow(hwnd, sw_show)
	C.UpdateWindow(hwnd)
	return Window{
		handle:   hwnd
		title:    title
		width:    width
		height:   height
		is_alive: true
	}
}

// run_message_loop_windows 启动 Windows 消息循环。
fn (mut w Window) run_message_loop_windows() {
	msg := C.MSG{}
	for C.GetMessageW(&msg, unsafe { nil }, 0, 0) > 0 {
		C.TranslateMessage(&msg)
		C.DispatchMessageW(&msg)
	}
	w.is_alive = false
}

// destroy_windows 销毁窗口。
fn (mut w Window) destroy_windows() {
	if !isnil(w.handle) {
		C.DestroyWindow(w.handle)
		w.handle = unsafe { nil }
	}
}

// wnd_proc_windows 是 Win32 窗口过程。
fn wnd_proc_windows(hwnd voidptr, msg u32, w_param usize, l_param isize) isize {
	if msg == wm_destroy {
		C.PostQuitMessage(0)
		return 0
	}
	if msg == wm_close {
		C.DestroyWindow(hwnd)
		return 0
	}
	return C.DefWindowProcW(hwnd, msg, w_param, l_param)
}
