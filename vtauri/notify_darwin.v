// notify_darwin.v — 系统通知的 macOS 实现（UNUserNotificationCenter）
// 仅当编译目标为 macOS 时由 V 自动编译（文件后缀 _darwin.v）。
//
// 通过 native/vtauri_webview.h 声明的 C 桥接函数发送系统通知。
// 链接信息（webview_bridge.o、Cocoa/WebKit framework 等）已由 webview_darwin.v 提供，
// #flag 为模块级合并，这里只引入头文件与函数声明，重复链接 webview_bridge.o 会报 duplicate。
//
// 注意：桥侧在 webview_bridge.cc 中使用了 clang 的 block 字面量（^{...}，UNUserNotificationCenter
// 的授权/回调要求真正的 Objective-C block，C 函数指针无法替代），需要 -fblocks 编译；
// 该标志经 #flag 模块级合并后同样作用于 webview_bridge.o 的编译，故在此声明。

module vtauri

#flag darwin -I @VMODROOT/native
#flag darwin -fblocks
#include "vtauri_webview.h"

fn C.vtauri_mac_notify(title &char, body &char) int

// notify_darwin 发送系统通知。桥返回码：0=已提交；1=未打包 .app；2=用户拒绝授权。
fn notify_darwin(title string, body string) ! {
	code := C.vtauri_mac_notify(&char(title.str), &char(body.str))
	match code {
		1 { return error('notify requires .app bundle (see scripts/bundle_macos.sh)') }
		2 { return error('notification permission denied') }
		else {}
	}
}
