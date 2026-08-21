// menu_darwin.v — 自定义应用菜单栏的 macOS 实现（NSMenu 主菜单栏）
// 仅当编译目标为 macOS 时由 V 自动编译（文件后缀 _darwin.v）。
//
// 通过 native/vtauri_webview.h 声明的 C 桥接函数构建 NSMenu 主菜单栏并安装为
// NSApp 主菜单（setMainMenu:，完全替换 build() 里安装的默认菜单栏）。
//
// 回调链路复用托盘（见 tray.v / tray_darwin.v）：vcalloc 分配 TrayCbCtx（进程生命周期，
// 不释放；Tray 是值类型会被拷贝，回调上下文必须指向稳定内存），以 ctx 指针为 userdata
// 传给桥侧 vtauri_mac_menubar_on_click；自定义项被点击时桥侧从菜单项 representedObject
// 读 id，经 C 回调 vtauri_on_tray_click 触发 V 侧 handler（action 项走 responder chain，不回传）。
// 链接信息（webview_bridge.o、Cocoa/WebKit framework 等）已由 webview_darwin.v 提供，
// #flag 为模块级合并，这里只引入头文件与函数声明，重复链接 webview_bridge.o 会报 duplicate。

module vtauri

#flag darwin -I @VMODROOT/native
#include "vtauri_webview.h"

fn C.vtauri_mac_menubar_create() voidptr
fn C.vtauri_mac_menubar_add_menu(mb voidptr, title &char) voidptr
fn C.vtauri_mac_menu_add_item(mb voidptr, menu voidptr, id &char, action &char, label &char, key &char, mods int)
fn C.vtauri_mac_menu_add_separator(menu voidptr)
fn C.vtauri_mac_menubar_on_click(mb voidptr, cb fn (&char, voidptr), userdata voidptr)
fn C.vtauri_mac_menubar_install(mb voidptr)

// set_menus_darwin 用一份 MenuDef 列表整体替换应用菜单栏。
// 菜单栏句柄与回调上下文均为进程生命周期分配、有意不释放（仿托盘做法）：
// 菜单由 NSApplication 强持有，句柄地址须在回调存续期间稳定。
fn (mut app App) set_menus_darwin(menus []MenuDef, cb fn (id string)) {
	mb := C.vtauri_mac_menubar_create()
	if isnil(mb) {
		eprintln('set_menus: vtauri_mac_menubar_create failed')
		return
	}
	for menu_def in menus {
		menu := C.vtauri_mac_menubar_add_menu(mb, &char(menu_def.title.str))
		if isnil(menu) {
			continue
		}
		for item_def in menu_def.items {
			if item_def.separator {
				C.vtauri_mac_menu_add_separator(menu)
			} else {
				C.vtauri_mac_menu_add_item(mb, menu, &char(item_def.id.str),
					&char(item_def.action.str), &char(item_def.label.str),
					&char(item_def.key.str), item_def.mods)
			}
		}
	}
	// 回调上下文：直接复用托盘的 TrayCbCtx 与 vtauri_on_tray_click（纯 V 回调，
	// 只认 userdata 里的 handler），用 vcalloc 手工分配、进程生命周期不释放。
	ctx := unsafe { &TrayCbCtx(vcalloc(sizeof(TrayCbCtx))) }
	unsafe {
		ctx.handler = cb
	}
	C.vtauri_mac_menubar_on_click(mb, vtauri_on_tray_click, voidptr(ctx))
	// 最后安装：替换 build() 时装的默认菜单栏。
	C.vtauri_mac_menubar_install(mb)
}
