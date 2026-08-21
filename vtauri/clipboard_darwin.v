// clipboard_darwin.v — 系统剪贴板的 macOS 实现（NSPasteboard）
// 仅当编译目标为 macOS 时由 V 自动编译（文件后缀 _darwin.v）。
//
// 通过 native/vtauri_webview.h 声明的 C 桥接函数读写系统剪贴板纯文本。
// 链接信息（webview_bridge.o、Cocoa/WebKit framework 等）已由 webview_darwin.v 提供，
// #flag 为模块级合并，这里只引入头文件与函数声明，重复链接 webview_bridge.o 会报 duplicate。

module vtauri

#flag darwin -I @VMODROOT/native
#include "vtauri_webview.h"

fn C.vtauri_mac_clipboard_write_text(text &char)
fn C.vtauri_mac_clipboard_read_text() &char

// clipboard_write_text_darwin 把纯文本写入系统剪贴板。
fn clipboard_write_text_darwin(text string) {
	C.vtauri_mac_clipboard_write_text(&char(text.str))
}

// clipboard_read_text_darwin 读取系统剪贴板纯文本（空串表示无文本）。
// C 返回的 &char 是 malloc 分配的，cstring_to_vstring 拷贝后必须释放。
fn clipboard_read_text_darwin() string {
	p := C.vtauri_mac_clipboard_read_text()
	if isnil(p) {
		return ''
	}
	defer {
		unsafe { free(voidptr(p)) }
	}
	return unsafe { cstring_to_vstring(p) }
}
