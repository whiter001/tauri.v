// clipboard.v — 系统剪贴板（对应 Tauri 的 tauri-plugin-clipboard-manager）
// 平台实现：macOS 见 clipboard_darwin.v（NSPasteboard）；其他平台为桩（打印提示）。

module vtauri

// clipboard_write_text 把纯文本写入系统剪贴板。
pub fn clipboard_write_text(text string) {
	$if macos {
		clipboard_write_text_darwin(text)
	} $else {
		eprintln('clipboard_write_text: ${text}')
	}
}

// clipboard_read_text 读取系统剪贴板纯文本；剪贴板无文本时返回空串。
pub fn clipboard_read_text() string {
	$if macos {
		return clipboard_read_text_darwin()
	} $else {
		eprintln('clipboard_read_text')
		return ''
	}
}
