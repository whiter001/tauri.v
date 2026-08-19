// tray.v — 系统托盘（对应 Tauri 的 tray icon / SystemTray）
// 平台实现：macOS 见 tray_darwin.v（NSStatusItem 菜单栏文本图标）；其他平台为桩（打印提示）。
// 回调链路：on_menu_click 把 V 回调 fn(id) 存入 vcalloc 分配的 TrayCbCtx（进程生命周期，不释放），
// 以 ctx 指针为 userdata 传给桥侧；菜单项被点击时桥侧触发 vtauri_on_tray_click，
// 从 userdata 读回 TrayCbCtx 并调用 handler。

module vtauri

// Tray 是系统托盘图标（macOS：菜单栏右侧的文本图标）。
pub struct Tray {
mut:
	native voidptr // 平台托盘句柄（macOS 为桥侧托盘结构体）
	ctx    voidptr // 回调上下文（V 侧 TrayCbCtx，生命周期同进程）
}

// TrayCbCtx 保存 V 侧托盘点击回调。用 vcalloc 手工分配、进程生命周期不释放：
// Tray 是值类型会被拷贝，回调上下文必须指向稳定内存（仿 webview.v 的 WvBindCtx 模式）。
struct TrayCbCtx {
mut:
	handler fn (id string) = fn (_ string) {}
}

// vtauri_on_tray_click 是托盘菜单项被点击时桥侧触发的 C 回调。
// 纯 V 函数（不直接调用 C 桥），故放平台中立文件无守卫，非 macOS 也参与编译。
fn vtauri_on_tray_click(id &char, userdata voidptr) {
	ctx := unsafe { &TrayCbCtx(userdata) }
	id_str := unsafe { cstring_to_vstring(id) }
	ctx.handler(id_str)
}

// new_tray 创建系统托盘图标（macOS：菜单栏右侧文本图标）。失败返回错误。
// 非 macOS 返回 native=nil 的 Tray 并打印提示（保证跨平台编译，hello 示例在 Linux 桩可跑）。
pub fn new_tray(title string) !Tray {
	$if macos {
		return new_tray_darwin(title)!
	} $else {
		eprintln('new_tray: ${title} (tray not supported on this platform)')
		return Tray{}
	}
}

// add_item 添加托盘菜单项，id 在点击回调中原样回传。
pub fn (mut t Tray) add_item(id string, label string) {
	if isnil(t.native) {
		eprintln('tray.add_item: ${label} (tray not supported)')
		return
	}
	$if macos {
		t.add_item_darwin(id, label)
	}
}

// on_menu_click 注册菜单项点击回调（在 run 之前调用）。
pub fn (mut t Tray) on_menu_click(cb fn (id string)) {
	if isnil(t.native) {
		eprintln('tray.on_menu_click: tray not supported')
		return
	}
	$if macos {
		t.on_menu_click_darwin(cb)
	}
}
