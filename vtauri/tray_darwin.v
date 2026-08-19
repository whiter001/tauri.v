// tray_darwin.v — 系统托盘的 macOS 实现（NSStatusItem）
// 仅当编译目标为 macOS 时由 V 自动编译（文件后缀 _darwin.v）。
//
// 通过 native/vtauri_webview.h 声明的 C 桥接函数创建菜单栏托盘图标并添加菜单项。
// 链接信息（webview_bridge.o、Cocoa/WebKit framework 等）已由 webview_darwin.v 提供，
// #flag 为模块级合并，这里只引入头文件与函数声明，重复链接 webview_bridge.o 会报 duplicate。

module vtauri

#flag darwin -I @VMODROOT/native
#include "vtauri_webview.h"

fn C.vtauri_mac_tray_create(title &char) voidptr
fn C.vtauri_mac_tray_add_item(tray voidptr, id &char, label &char)
fn C.vtauri_mac_tray_on_click(tray voidptr, cb fn (&char, voidptr), userdata voidptr)

// new_tray_darwin 创建系统托盘图标（菜单栏右侧文本）。
// 桥侧返回 NULL 表示失败（如 NSApp 尚未创建），此处转为错误。
fn new_tray_darwin(title string) !Tray {
	native := C.vtauri_mac_tray_create(&char(title.str))
	if isnil(native) {
		return error('vtauri_mac_tray_create failed')
	}
	return Tray{
		native: native
	}
}

// add_item_darwin 往托盘菜单添加一个菜单项。
fn (mut t Tray) add_item_darwin(id string, label string) {
	C.vtauri_mac_tray_add_item(t.native, &char(id.str), &char(label.str))
}

// on_menu_click_darwin 注册托盘菜单项点击回调。
// 手工分配 TrayCbCtx（vcalloc，进程生命周期不释放），把 handler 存进去，
// 以 ctx 指针为 userdata 传给桥侧；点击时桥侧从菜单项 representedObject 读 id，
// 经 C 回调 vtauri_on_tray_click 触发 V 侧 handler。
fn (mut t Tray) on_menu_click_darwin(cb fn (id string)) {
	ctx := unsafe { &TrayCbCtx(vcalloc(sizeof(TrayCbCtx))) }
	unsafe {
		ctx.handler = cb
	}
	t.ctx = ctx
	C.vtauri_mac_tray_on_click(t.native, vtauri_on_tray_click, voidptr(ctx))
}
