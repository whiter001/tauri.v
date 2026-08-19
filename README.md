# vtauri

用 **V 语言**（V 0.5.2，最新编译版）实现的 [Tauri](https://github.com/tauri-apps/tauri) 风格桌面应用框架，**Windows 优先**。

> 目标：将 Tauri「Web 前端 + 原生后端」的架构用 V 重新实现，产出一个在 Windows 上可用的桌面应用框架。

## 功能概览

| 模块 | 文件 | 说明 | 状态 |
|------|------|------|------|
| 配置系统 | `vtauri/config.v` | 解析 `vtauri.conf.json` | ✅ |
| 窗口系统 | `vtauri/window.v` / `window_windows.v` | Win32 `CreateWindowExW` + 消息循环（macOS 上窗口由 webview 库自建 NSWindow，window.v 桩） | ✅ |
| WebView 渲染 | `vtauri/webview.v` + `webview_windows.v` / `webview_darwin.v` | 集成 webview/webview（Windows 封装 WebView2，macOS 封装 WKWebView） | ✅（Windows 需真机联调；macOS 已验证） |
| IPC 协议 | `vtauri/ipc.v` | 前端 ↔ 后端消息编解码 | ✅ |
| 命令系统 | `vtauri/command.v` | 命令注册与分发 | ✅ |
| 应用主类 | `vtauri/app.v` | 整合各组件 | ✅ |
| 前端 API | `js/vtauri.js` | `invoke` / `listen` / `emit` | ✅ |
| 示例 | `examples/hello` | 最小可运行应用（原生 HTML） | ✅（可编译 `.exe`） |
| 示例 | `examples/vue` | Vue 3 + Vite 前端示例（单文件构建 / dev 模式） | ✅（可编译 `.exe`） |
| 示例 | `examples/react` | React 19 + Vite 前端示例（单文件构建 / dev 模式） | ✅（可编译 `.exe`） |
| 示例 | `examples/remote` | 远程 URL 加载示例（`load_url` 嵌套 vlang.io） | ✅（可编译 `.exe`） |
| C++ 桥 | `native/webview_bridge.cpp`（`#include` 实现于 `.cc`） | 把 webview 库暴露为稳定 C 接口（MSVC 编译为 `.obj`） | ✅ |
| macOS 打包 | `scripts/bundle_macos.sh` | .app 组包 + Info.plist + 图标 + ad-hoc/Developer ID 签名 | ✅ |
| macOS 菜单/窗口控制 | `vtauri/webview_darwin.v` + `native/webview_bridge.cc` | 标准菜单栏（About/Quit/Edit）、App.quit()、resizable 约束 | ✅ |
| 原生对话框 | `vtauri/dialog.v` / `dialog_darwin.v` | 消息框 / 打开文件（过滤）/ 保存文件，对应 tauri-plugin-dialog | ✅ macOS |
| 系统托盘 | `vtauri/tray.v` / `tray_darwin.v` | NSStatusItem 菜单栏图标 + 菜单项点击回调，对应 Tauri tray | ✅ macOS |

## 环境

- V 0.5.2（`4a8793c`，从源码最新编译）
- Windows 本机编译：安装 MSVC（Visual Studio / Build Tools），用 `v -cc msvc`，由 `native/webview_bridge.cpp` 编出 `webview_bridge.obj`
- 目标机需安装 [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)（Win10/11 通常已内置）
- macOS 本机编译：Xcode Command Line Tools 自带 clang++，无需额外依赖；V thirdparty builder 自动用 clang++ 编译 `native/webview_bridge.cpp` 为 `webview_bridge.o` 并链接 `-framework Cocoa -framework WebKit -lc++`

## 快速开始

### 1. 运行测试（本机 / Linux）

```bash
v test vtauri
```

Windows 本机建议使用 MSVC：

```powershell
v -cc msvc test vtauri
```

### 2. 编译示例为 Windows 可执行文件（MSVC）

hello 示例（原生 HTML 前端）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_hello_msvc.ps1 -Run
# ① 自动准备 WebView2 SDK 头文件
# ② 用 V + MSVC 编译 examples/hello 为 hello.exe（生成 PE32+ x86-64）
```

Vue / React 示例（前端是标准 Vite 工程，构建为单文件后嵌入 exe）：

```powershell
# 一键：npm install -> vite build -> MSVC 编译 exe
powershell -ExecutionPolicy Bypass -File scripts/build_examples_msvc.ps1 -Example all   # 或 vue / react
powershell -ExecutionPolicy Bypass -File scripts/build_examples_msvc.ps1 -Example vue -Run

# 只构建前端（生成 examples/vue|react/frontend/dist/index.html）
bash scripts/build_example_frontends.sh all        # 或 vue / react
```

Vue / React 示例支持两种加载模式：

- **打包模式（默认）**：加载编译期内嵌的 `frontend/dist/index.html`；
- **开发模式（start 模式 / localhost 加载）**：设置环境变量 `VTAURI_DEV_URL` 后，改为用 `load_url` 加载本地 Vite dev server，前端改动即时生效：

```powershell
# 终端 1：启动 Vite dev server
cd examples/vue/frontend
npm run dev

# 终端 2：指定 dev URL 再启动应用（Linux/macOS 用 VTAURI_DEV_URL=...）
set VTAURI_DEV_URL=http://localhost:5173
..\vue.exe        # 或 examples/react 下 react.exe
```

远程加载示例（`load_url` 直接嵌套远程页面，默认 vlang.io）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_examples_msvc.ps1 -Example remote -Run
# 自定义 URL：set VTAURI_REMOTE_URL=https://example.com
```

### 3. 在 Linux/macOS 上运行示例

macOS 上编译运行（弹出真实 WKWebView 窗口）：

```bash
v -cc clang -o hello examples/hello        # 自动编译 C++ 桥并链接 Cocoa/WebKit
cd examples/hello && ../../hello           # 或直接 -o 到该目录后运行
# 输出：vtauri example "vtauri-hello" v0.1.0 starting...
```

- **macOS**：真实 WKWebView 窗口（窗口由 webview 库自建 NSWindow），渲染与 IPC 可用；
- **Linux**：仍为桩窗口，验证核心逻辑。

> 也可用 `v run examples/hello`。注意 `examples/hello` 的 `main.v` 用相对路径读
> `vtauri.conf.json`，需在 `examples/hello` 目录下运行（找不到配置时回退 `default_config`）。

### 4. macOS 打包 .app

把编译好的可执行文件打成标准 macOS .app bundle（Finder 可双击、`open` 可启动、Dock 显示自定义图标）：

```bash
# ① 编译（Xcode CLT 自带 clang++，自动链接 Cocoa/WebKit）
v -cc clang -o build/hello examples/hello

# ② 没有设计素材时，用脚本生成演示图标（1024x1024 PNG）
scripts/gen_demo_icon.sh examples/hello/icon.png

# ③ 打包 .app（--icon 可选；--sign 传 Developer ID 走正式签名）
scripts/bundle_macos.sh --exe build/hello \
    --config examples/hello/vtauri.conf.json \
    --out "vtauri hello.app" --icon examples/hello/icon.png

# ④ 启动
open "vtauri hello.app"
```

产物结构：`Name.app/Contents/{Info.plist, MacOS/<productName>, Resources/vtauri.conf.json, Resources/icon.icns(可选)}`。
Info.plist 字段来自配置（`CFBundleExecutable`/`CFBundleName`/`CFBundleDisplayName`=`productName`、
`CFBundleIdentifier`=`identifier`、`CFBundleVersion`/`CFBundleShortVersionString`=`version`），
生成后自动 `plutil -lint` 校验；`--icon` 的 PNG 经 sips + iconutil 生成 `.icns`。

签名：默认 ad-hoc（`codesign --force --sign -`，本机运行足够）；`--sign "Developer ID Application: ..."`
走 `--options runtime --timestamp` 的正式签名，签后自动 `codesign -v`。
面向外部分发需公证（notarization），手动步骤见 [docs/usage.md](docs/usage.md) 的「macOS 打包与签名」一节。

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

## 前端框架示例（Vue / React）

`examples/vue` 与 `examples/react` 是完整的 **Vite 前端工程 + V 后端** 示例：

- 前端：标准 Vite 工程（`frontend/`），用 `vite-plugin-singlefile` 把构建产物内联为单个 `dist/index.html`；
- 集成：`frontend/src/vtauri.js` 由构建脚本从 `js/vtauri.js` 拷贝，`main.js(x)` 里 `import './vtauri.js'` 挂载 `window.__VTauri`；
- 后端：`main.v` 用 `$embed_file('frontend/dist/index.html')` 编译期嵌入，`load_html` 渲染；
- 命令：注册 `greet`（字符串）、`add`（JSON 对象参数）、`info`（JSON 对象返回），前端按钮逐一调用测试 IPC。

目录结构：

```
examples/vue/                 examples/react/
  main.v                        main.v
  vtauri.conf.json              vtauri.conf.json
  frontend/                     frontend/
    package.json                  package.json
    vite.config.js                vite.config.js
    index.html                    index.html
    src/
      main.js                     main.jsx
      App.vue                     App.jsx
      vtauri.js                   vtauri.js
```

开发调试前端时可直接 `cd examples/vue/frontend && npm run dev`，浏览器里会提示「未检测到 vtauri 运行时」，即 `__VTauri` 仅在 vtauri 窗口内注入。

**start 模式（localhost 加载）**：把 `VTAURI_DEV_URL=http://localhost:5173` 传给 `vue.exe` / `react.exe`，应用窗口会直接加载本地 Vite dev server（`app.load_url`），前端改动即时生效、无需重新编译 exe。

## 远程加载示例（examples/remote）

`examples/remote` 演示 `load_url` 远程加载方案：WebView 不渲染内嵌 HTML，而是直接导航到一个远程 URL，默认嵌套 [vlang.io](https://vlang.io)（V 语言官网）。

- 默认 URL 为 `https://vlang.io`，可通过环境变量 `VTAURI_REMOTE_URL` 覆盖为任意地址；
- 原生桥的 `__vtauriInvoke` 会在每次文档加载时注入，远程页面只要引入了 `js/vtauri.js`，依然能调用后端注册的命令；
- 构建：`powershell -ExecutionPolicy Bypass -File scripts/build_examples_msvc.ps1 -Example remote -Run`（remote 无 frontend 目录，跳过前端构建）。

## 架构对应

vtauri 与 Tauri 各组件的对应关系、各模块职责说明，见 [docs/usage.md](docs/usage.md) 的「架构对应」一节。

## 路线图

完整的 Phase 进度与后续规划，见 [docs/roadmap.md](docs/roadmap.md)。

## License

MIT
