// dialog_darwin.v — 原生系统对话框的 macOS 实现
// 仅当编译目标为 macOS 时由 V 自动编译（文件后缀 _darwin.v）。
//
// 通过 native/vtauri_webview.h 声明的 C 桥接函数调用 AppKit 原生对话框
// （NSAlert / NSOpenPanel / NSSavePanel）。链接信息（webview_bridge.o、
// Cocoa/WebKit framework 等）已由 webview_darwin.v 提供，#flag 为模块级合并，
// 这里只引入头文件与函数声明，重复链接 webview_bridge.o 会报 duplicate。

module vtauri

#flag darwin -I @VMODROOT/native
#include "vtauri_webview.h"

fn C.vtauri_mac_message_box(title &char, message &char)
fn C.vtauri_mac_open_file(title &char, filters_csv &char) &char
fn C.vtauri_mac_save_file(title &char, default_name &char) &char

// message_box_darwin 弹出模态消息框（NSAlert，阻塞至用户点击）。
fn message_box_darwin(title string, message string) {
	C.vtauri_mac_message_box(&char(title.str), &char(message.str))
}

// open_file_dialog_darwin 弹出打开文件对话框，返回所选文件路径（空串表示取消）。
// C 返回的 &char 是 malloc 分配的，cstring_to_vstring 拷贝后必须释放。
fn open_file_dialog_darwin(title string, filters []string) string {
	csv := filters.join(',')
	p := C.vtauri_mac_open_file(&char(title.str), &char(csv.str))
	if isnil(p) {
		return ''
	}
	defer {
		unsafe { free(voidptr(p)) }
	}
	return unsafe { cstring_to_vstring(p) }
}

// save_file_dialog_darwin 弹出保存文件对话框，返回目标路径（空串表示取消）。
fn save_file_dialog_darwin(title string, default_name string) string {
	p := C.vtauri_mac_save_file(&char(title.str), &char(default_name.str))
	if isnil(p) {
		return ''
	}
	defer {
		unsafe { free(voidptr(p)) }
	}
	return unsafe { cstring_to_vstring(p) }
}
