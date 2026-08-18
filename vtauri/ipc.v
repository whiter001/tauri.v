// ipc.v — 前端 <-> 后端消息传递协议
// 对应 Tauri 中 WebView 与 Rust 后端之间的 IPC。
// 在 WebView2 集成到位后，以下协议通过 window.chrome.webview.postMessage 与
// window.chrome.webview.addEventListener('message', ...) 承载。
//
// 本模块先定义协议结构与编解码逻辑，便于独立测试。

module vtauri

// IpcRequest 是前端发给后端的一个调用请求（invoke）。
pub struct IpcRequest {
pub:
	id      string // 请求唯一 id，用于关联结果
	command string // 命令名
	args    string // 命令参数（JSON 字符串）
}

// IpcResponse 是后端返回给前端的结果。
pub struct IpcResponse {
pub:
	id     string // 与请求对应
	ok     bool   // 是否成功
	result string // 成功时的结果（JSON 字符串）
	error  string // 失败时的错误信息
}

// IpcEvent 是后端主动推送给前端的事件（对应 Tauri 的 listen/emit）。
pub struct IpcEvent {
pub:
	event   string // 事件名
	payload string // 事件载荷（JSON 字符串）
}

// encode_request 将 IpcRequest 编码为 JSON 字符串。
pub fn encode_request(req IpcRequest) string {
	return encode(req)
}

// decode_request 从 JSON 字符串解码 IpcRequest。
pub fn decode_request(data string) !IpcRequest {
	return decode[IpcRequest](data)
}

// encode_response 将 IpcResponse 编码为 JSON 字符串。
pub fn encode_response(resp IpcResponse) string {
	return encode(resp)
}

// decode_response 从 JSON 字符串解码 IpcResponse。
pub fn decode_response(data string) !IpcResponse {
	return decode[IpcResponse](data)
}

// encode_event 将 IpcEvent 编码为 JSON 字符串。
pub fn encode_event(ev IpcEvent) string {
	return encode(ev)
}

// handle_request 根据命令注册表处理一个 IpcRequest，并返回 IpcResponse。
pub fn handle_request(reg &CommandRegistry, req IpcRequest) IpcResponse {
	res := reg.invoke(req.command, req.args) or {
		return IpcResponse{
			id:    req.id
			ok:    false
			error: err.msg()
		}
	}
	return IpcResponse{
		id:     req.id
		ok:     true
		result: res
	}
}
