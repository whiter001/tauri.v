// dialog.v — 原生系统对话框（消息框 / 文件打开 / 文件保存）
// 对应 Tauri 的 tauri-plugin-dialog。
// 平台实现：macOS 见 dialog_darwin.v；其他平台为桩（返回空串/打印）。

module vtauri

// message_box 弹出模态消息框。
pub fn message_box(title string, message string) {
	$if macos {
		message_box_darwin(title, message)
	} $else {
		eprintln('message_box: ${title} ${message}')
	}
}

// open_file_dialog 弹出打开文件对话框，返回所选文件路径；用户取消返回空串。
// filters 为扩展名列表（如 ['png', 'jpg']），空数组表示不过滤。
pub fn open_file_dialog(title string, filters []string) string {
	$if macos {
		return open_file_dialog_darwin(title, filters)
	} $else {
		eprintln('open_file_dialog: ${title}')
		return ''
	}
}

// save_file_dialog 弹出保存文件对话框，返回目标路径；用户取消返回空串。
pub fn save_file_dialog(title string, default_name string) string {
	$if macos {
		return save_file_dialog_darwin(title, default_name)
	} $else {
		eprintln('save_file_dialog: ${title}')
		return ''
	}
}
