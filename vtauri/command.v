// command.v — 命令注册与分发系统
// 对应 Tauri 的 command（前端 invoke 可调用的后端命令）。
// 简化模型：命令以名称注册，接收一个 JSON 参数串，返回一个 JSON 结果串。

module vtauri

// CommandHandler 命令处理器签名：入参为 JSON 字符串，返回 JSON 字符串与错误。
pub type CommandHandler = fn (args string) !string

// CommandRegistry 命令注册表。
pub struct CommandRegistry {
mut:
	commands map[string]CommandHandler = {}
}

// register 注册一个命令处理器。
pub fn (mut r CommandRegistry) register(name string, h CommandHandler) {
	r.commands[name] = h
}

// has 判断命令是否存在。
pub fn (r &CommandRegistry) has(name string) bool {
	return name in r.commands
}

// invoke 执行一个命令，返回其结果 JSON 字符串。
pub fn (r &CommandRegistry) invoke(name string, args string) !string {
	h := r.commands[name] or { return error('command not found: ${name}') }
	return h(args)
}

// --- 便捷构造命令的辅助函数 ---

// make_string_command 构造一个简单的、返回字符串的命令。
pub fn make_string_command(f fn (string) string) CommandHandler {
	return fn [f] (args string) !string {
		return encode(f(args))
	}
}

// 使 CommandRegistry 可跨模块组合进 App。
pub fn new_command_registry() CommandRegistry {
	return CommandRegistry{}
}
