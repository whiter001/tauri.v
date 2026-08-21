// notify.v — 系统通知（对应 Tauri 的 tauri-plugin-notification）
// 平台实现：macOS 见 notify_darwin.v（UNUserNotificationCenter）；其他平台为桩（打印提示）。

module vtauri

// notify 发送一条系统通知。macOS 上未打包 .app（UNUserNotificationCenter
// 要求 bundle）或用户拒绝授权时返回错误。
pub fn notify(title string, body string) ! {
	$if macos {
		notify_darwin(title, body)!
	} $else {
		eprintln('notify: ${title} ${body}')
	}
}
