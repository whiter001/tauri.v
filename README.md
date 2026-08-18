# vtauri

用 **V 语言**（V 0.5.2，最新编译版）实现的 [Tauri](https://github.com/tauri-apps/tauri) 风格桌面应用框架，**Windows 优先**。

> 目标：将 Tauri「Web 前端 + 原生后端」的架构用 V 重新实现，产出一个在 Windows 上可用的桌面应用框架。

## 功能概览

| 模块 | 文件 | 说明 | 状态 |
|------|------|------|------|
| 配置系统 | `vtauri/config.v` | 解析 `vtauri.conf.json` | ✅ |
| 窗口系统 | `vtauri/window.v` / `window_windows.v` | Win32 `CreateWindowExW` + 消息循环 | ✅ |
| WebView 渲染 | `vtauri/webview.v` | WebView2 绑定骨架 | 🚧（需 Windows 真机联调） |
| IPC 协议 | `vtauri/ipc.v` | 前端 ↔ 后端消息编解码 | ✅ |
| 命令系统 | `vtauri/command.v` | 命令注册与分发 | ✅ |
| 应用主类 | `vtauri/app.v` | 整合各组件 | ✅ |
| 前端 API | `js/vtauri.js` | `invoke` / `listen` / `emit` | ✅ |
| 示例 | `examples/hello` | 最小可运行应用 | ✅（可交叉编译 `.exe`） |

## 环境

- V 0.5.2（`4a8793c`，从源码最新编译）
- Windows 交叉编译：`x86_64-w64-mingw32-gcc`

## 快速开始

### 1. 运行测试（本机 / Linux）

```bash
v test vtauri
```

### 2. 交叉编译示例为 Windows 可执行文件

```bash
cd examples/hello
v -os windows -o hello.exe main.v
# 生成 PE32+ x86-64 hello.exe
```

### 3. 在 Linux 上验证核心逻辑（窗口为桩）

```bash
VMODULES=/workspace v -o demo demo.v && ./demo
```

## 示例（examples/hello/main.v）

```v
import vtauri

fn main() {
	cfg := vtauri.load_config('vtauri.conf.json') or { vtauri.default_config() }
	mut app := vtauri.new_app(cfg)

	// 注册后端命令
	app.register_command('greet', vtauri.make_string_command(fn (name string) string {
		return 'Hello, ${name}!'
	}))

	app.build() or { eprintln('build failed: ${err}'); return }
	app.run() // 进入消息循环
}
```

前端通过 `js/vtauri.js` 调用：

```js
const result = await window.__VTauri.invoke('greet', 'whiter');
```

## 架构对应

| Tauri 组件 | vtauri 对应 |
|-----------|------------|
| `tauri` core | `vtauri/app.v` |
| `tao` / `winit` | `vtauri/window.v` |
| `wry` / `WebView2` | `vtauri/webview.v` |
| IPC / command | `vtauri/ipc.v` + `command.v` |
| `tauri.conf.json` | `vtauri/config.v` |
| `@tauri-apps/api` | `js/vtauri.js` |

## 路线图

- [x] Phase 1：应用与配置骨架
- [x] Phase 2：Win32 窗口系统
- [x] Phase 3：IPC 与命令系统
- [x] Phase 4：前端 JS API
- [x] Phase 5：示例 + Windows 交叉编译
- [ ] WebView2 真机渲染（需 Windows 运行时验证）
- [ ] 系统托盘、原生菜单、通知
- [ ] 跨平台（Linux / macOS）
- [ ] 应用打包器（NSIS / MSI）

详见 [plan.md](plan.md)。

## License

MIT
