// shell_darwin.v — shell 打开的 macOS 实现（NSWorkspace openURL:）
// 仅当编译目标为 macOS 时由 V 自动编译（文件后缀 _darwin.v）。
//
// 通过 native/vtauri_webview.h 声明的 C 桥接函数用系统默认应用打开 URL。
// 链接信息（webview_bridge.o、Cocoa/WebKit framework 等）已由 webview_darwin.v 提供，
// #flag 为模块级合并，这里只引入头文件与函数声明，重复链接 webview_bridge.o 会报 duplicate。

module vtauri

#flag darwin -I @VMODROOT/native
#include "vtauri_webview.h"

fn C.vtauri_mac_open_url(url &char) int

// shell_open_darwin 用系统默认应用打开 URL；桥侧返回 0 表示失败，转为错误。
fn shell_open_darwin(url string) ! {
	ok := C.vtauri_mac_open_url(&char(url.str))
	if ok == 0 {
		return error('open failed: ${url}')
	}
}
