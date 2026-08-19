# vtauri

用 **V 语言**（V 0.5.2，最新编译版）实现的 [Tauri](https://github.com/tauri-apps/tauri) 风格桌面应用框架，**Windows 优先**。

> 目标：将 Tauri「Web 前端 + 原生后端」的架构用 V 重新实现，产出一个在 Windows 上可用的桌面应用框架。

## 功能概览

| 模块 | 文件 | 说明 | 状态 |
|------|------|------|------|
| 配置系统 | `vtauri/config.v` | 解析 `vtauri.conf.json` | ✅ |
| 窗口系统 | `vtauri/window.v` / `window_windows.v` | Win32 `CreateWindowExW` + 消息循环 | ✅ |
| WebView 渲染 | `vtauri/webview.v` + `webview_windows.v` | 集成 webview/webview（封装 WebView2） | ✅（需 Windows 真机联调） |
| IPC 协议 | `vtauri/ipc.v` | 前端 ↔ 后端消息编解码 | ✅ |
| 命令系统 | `vtauri/command.v` | 命令注册与分发 | ✅ |
| 应用主类 | `vtauri/app.v` | 整合各组件 | ✅ |
| 前端 API | `js/vtauri.js` | `invoke` / `listen` / `emit` | ✅ |
| 示例 | `examples/hello` | 最小可运行应用 | ✅（可交叉编译 `.exe`） |
| C++ 桥 | `native/webview_bridge.cc` / `native/webview_bridge.cpp` | 把 webview 库暴露为稳定 C 接口（g++ 交叉编 `.o` / MSVC 本机编 `.obj`） | ✅ |

## 环境

- V 0.5.2（`4a8793c`，从源码最新编译）
- Windows 交叉编译：`x86_64-w64-mingw32-g++`（MinGW-w64，含 C++ 编译器），用 `native/webview_bridge.cc` 编出 `webview_bridge.o`
- Windows 本机编译：安装 MSVC（Visual Studio / Build Tools），用 `v -cc msvc`，由 `native/webview_bridge.cpp` 编出 `webview_bridge.obj`
- 目标机需安装 [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)（Win10/11 通常已内置）

## 快速开始

### 1. 运行测试（本机 / Linux）

```bash
v test vtauri
```

Windows 本机建议使用 MSVC：

```powershell
v -cc msvc test vtauri
```

### 2. 交叉编译示例为 Windows 可执行文件

```bash
bash scripts/build_hello_windows.sh
# ① 用 MinGW g++ 编译 native/webview_bridge.cc（C++ 桥）
# ② 用 V 交叉编译 examples/hello 为 hello.exe
# 生成 PE32+ x86-64 hello.exe
```

如果是在 Windows 本机使用 MSVC：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_hello_msvc.ps1 -Run
```

### 3. 在 Linux 上运行示例（窗口为桩，验证核心逻辑）

```bash
cd examples/hello
v run main.v
# 输出：vtauri example "vtauri-hello" v0.1.0 starting...
```

## 使用方案

完整的创建应用、注册命令、前后端通信、编译打包指南，见 [docs/usage.md](docs/usage.md)。

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

> 完整示例还会内嵌 `index.html` 与 `js/vtauri.js` 并通过 `app.load_html(...)` 渲染，
> 详见 `examples/hello/main.v`。

前端通过 `js/vtauri.js` 调用：

```js
const result = await window.__VTauri.invoke('greet', 'whiter');
```

## 架构对应

vtauri 与 Tauri 各组件的对应关系、各模块职责说明，见 [docs/usage.md](docs/usage.md) 的「架构对应」一节。

## 路线图

完整的 Phase 进度与后续规划，见 [docs/roadmap.md](docs/roadmap.md)。

## License

MIT
