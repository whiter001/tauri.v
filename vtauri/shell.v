// shell.v — 系统 shell 操作（对应 Tauri 的 tauri-plugin-shell）
// 平台实现：macOS 见 shell_darwin.v（NSWorkspace）；其他平台为桩（打印提示）。

module vtauri

// shell_open 用系统默认应用打开 URL（http/https/file 等）。失败返回错误。
pub fn shell_open(url string) ! {
	$if macos {
		shell_open_darwin(url)!
	} $else {
		eprintln('shell_open: ${url}')
	}
}
