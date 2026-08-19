# vtauri 使用方案（Usage Guide）

> 本文档介绍如何使用 **vtauri** 开发一个基于 V 语言、Tauri 风格的桌面应用（正式支持 Windows / macOS，Linux 为桩验证）。
> vtauri 采用「Web 前端 + 原生后端」架构：后端用 **V 语言**实现原生能力，前端用 Web 技术渲染，二者通过 IPC 通信。

## 1. 环境准备

### 1.1 安装 V 语言

vtauri 基于 **V 0.5.2+** 开发，建议使用最新源码编译版。

```bash
# 克隆 V 源码并编译（Linux / macOS）
git clone https://github.com/vlang/v
cd v
make
# 将编译产物加入 PATH
sudo ./v symlink
```

### 1.2 Windows 编译工具（MSVC）

vtauri 的 WebView 集成依赖一个 C++ 桥，Windows 上编译 `.exe` 需要 **MSVC**
（Visual Studio 或 Build Tools，含 C++ 工作负载）。V 的 `v -cc msvc` 会自动发现
已安装的 MSVC 工具链，无需手动运行 `vcvars64.bat`。

```powershell
# 验证 MSVC 是否可用
v -cc msvc -o hello.exe main.v
```

> Linux / macOS 上无法编译 Windows 目标（vtauri 不再提供 MinGW 交叉编译方式）；
> 请直接在 Windows 本机使用 MSVC 构建。

### 1.3 macOS 编译工具（clang++）

macOS 是正式支持平台，无需额外依赖：Xcode Command Line Tools 自带 clang++。
V thirdparty builder 会自动用 clang++ 把 `native/webview_bridge.cpp` 编译为
`webview_bridge.o` 并链接 `-framework Cocoa -framework WebKit -lc++`。

```bash
# macOS 本机编译示例
v -cc clang -o hello examples/hello
```

行为差异：macOS 上窗口由 webview 库自建 NSWindow（`window.v` 为桩），
窗口标题与尺寸来自 `vtauri.conf.json` 的 `app.windows[]` 配置。

### 1.4 项目依赖

vtauri 的 V 代码除 V 标准库外**无外部依赖**（`v.mod` 的 `dependencies` 为空）。
为渲染 Web 前端，vtauri 集成了第三方 **webview/webview** 库（MIT，头文件已 vendored 在
`native/webview/`，内部封装 WebView2）。C++ 桥的实现位于
`native/webview_bridge.cpp`（`#include` 了 `webview_bridge.cc` 的实现），
由 V 的 thirdparty object builder 在 `v -cc msvc` 时自动用 cl 编译为 `webview_bridge.obj` 并链接。

## 2. 目录结构

```
vtauri/            # 框架核心（库模块 vtauri）
  config.v         # 配置系统：解析 vtauri.conf.json
  window.v         # 窗口抽象 + 跨平台桩（macOS 由 webview 库自建 NSWindow）
  window_windows.v # Win32 窗口实现（CreateWindowExW + 消息循环）
  webview.v        # WebView 抽象接口（跨平台调度）
  webview_windows.v# WebView Windows 实现（集成 webview/webview 库 + IPC）
  webview_darwin.v # WebView macOS 实现（WKWebView，窗口由库自建 NSWindow）
  ipc.v            # IPC 消息协议
  command.v        # 命令注册与分发
  app.v            # App 主类（聚合各组件）
  jsonx.v          # JSON 编解码辅助
native/            # WebView C++ 集成
  webview/         # vendored 的 webview/webview 头文件（MIT）
  vtauri_webview.h # V 侧 include 的 C 桥接接口
  webview_bridge.cc # C++ 桥实现（由 webview_bridge.cpp include）
  webview_bridge.cpp# MSVC 编译入口（V 的 thirdparty builder 自动编译为 .obj）
js/
  vtauri.js        # 前端 API（invoke / listen / emit）
examples/
  hello/           # 最小可运行示例（原生 HTML）
  vue/             # Vue 3 + Vite 前端示例
  react/           # React + Vite 前端示例
scripts/
  build_hello_msvc.ps1     # 一键用 MSVC 构建 hello 示例
  build_examples_msvc.ps1  # 一键用 MSVC 构建 vue / react 示例
  build_example_frontends.sh # 构建 vue / react 前端（vite build）
```

> **注意**：`vtauri/` 是一个纯 V 库模块，请勿在其中放置 `module main` 的入口文件，
> 否则会破坏该模块被示例项目导入。可运行入口统一放在 `examples/` 下。

## 3. 快速开始

### 3.1 直接运行示例

```bash
# 编译并运行最小示例（macOS 弹出真实 WKWebView 窗口；Linux 上窗口为桩实现，打印启动信息）
cd examples/hello
v run main.v

# macOS 上编译为可执行文件（自动编译 C++ 桥并链接 Cocoa/WebKit）
v -cc clang -o hello examples/hello

# Windows 上用 MSVC 编译为可执行文件
powershell -ExecutionPolicy Bypass -File scripts/build_hello_msvc.ps1
# 产出 examples/hello/hello.exe（PE32+ x86-64）
```

### 3.2 运行单元测试

```bash
# 在仓库根目录执行 vtauri 库的全部单元测试
v test vtauri
```

## 4. 从零创建一个 vtauri 应用

### 4.1 编写后端入口 `main.v`

```v
module main

import vtauri

// 内嵌前端资源（编译期嵌入可执行文件；路径相对本文件所在目录）
const index_html = $embed_file('index.html')
const vtauri_js = $embed_file('../../js/vtauri.js')

fn main() {
	// 1. 读取配置（可缺省，失败时回退默认配置）
	cfg := vtauri.load_config('vtauri.conf.json') or {
		eprintln('config error: ${err}')
		vtauri.default_config()
	}

	// 2. 创建并装配 App
	mut app := vtauri.new_app(cfg)

	// 3. 注册后端命令：前端可 invoke('greet', ...) 调用
	app.register_command('greet', vtauri.make_string_command(fn (name string) string {
		return 'Hello, ${name}!'
	}))

	// 4. 构建主窗口与 WebView
	app.build() or {
		eprintln('build failed: ${err}')
		return
	}

	// 5. 加载前端页面（把 vtauri.js 内联进 index.html，避免 set_html 时外部脚本 404）
	html := vtauri.inline_asset(index_html.to_string(), vtauri_js.to_string())
	app.load_html(html) or {
		eprintln('load_html failed: ${err}')
		return
	}

	// 6. 进入消息循环（Windows 上阻塞直到窗口关闭）
	app.run()
}
```

### 4.2 编写配置文件 `vtauri.conf.json`

```json
{
  "productName": "my-app",
  "identifier": "com.example.myapp",
  "version": "0.1.0",
  "app": {
    "windows": [
      {
        "title": "My App",
        "width": 1024,
        "height": 768,
        "center": true,
        "resizable": true
      }
    ]
  }
}
```

配置字段说明：

| 字段 | 类型 | 说明 |
|------|------|------|
| `productName` | string | 应用显示名 |
| `identifier` | string | 应用唯一标识（如 `com.example.app`） |
| `version` | string | 应用版本号 |
| `app.windows[]` | array | 窗口数组，取第一个作为主窗口 |
| `app.windows[].title` | string | 窗口标题 |
| `app.windows[].width` | number | 窗口宽度（px） |
| `app.windows[].height` | number | 窗口高度（px） |
| `app.windows[].center` | bool | 是否屏幕居中 |
| `app.windows[].resizable` | bool | 是否可调整大小 |

### 4.3 编写前端页面 `index.html`

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <title>My App</title>
</head>
<body>
  <button id="btn">调用后端</button>
  <div id="out">--</div>

  <!-- 引入 vtauri 前端 API -->
  <script src="vtauri.js"></script>
  <script>
    document.getElementById('btn').addEventListener('click', async function () {
      var out = document.getElementById('out');
      // 调用 V 后端注册的 greet 命令
      var result = await window.__VTauri.invoke('greet', 'whiter');
      out.textContent = result;
    });
  </script>
</body>
</html>
```

## 5. 前端 ↔ 后端通信

### 5.1 `invoke` — 调用后端命令

前端通过 `window.__VTauri.invoke(command, args)` 调用 V 后端注册的命令，返回 `Promise`。

```js
// 后端：app.register_command('greet', make_string_command(fn(name) { ... }))
const result = await window.__VTauri.invoke('greet', 'whiter');
// result === 'Hello, whiter!'
```

### 5.2 `listen` — 监听后端事件

```js
const unlisten = window.__VTauri.listen('update', (payload) => {
  console.log('收到事件', payload);
});
// 不再需要时取消监听
unlisten();
```

### 5.3 `emit` — 前端向后端发送事件通知

```js
window.__VTauri.emit('log', { level: 'info', message: 'hello' });
```

### 5.4 自定义命令（复杂参数）

命令处理器接收一个 JSON 参数串，返回 JSON 结果串。可使用 `json2` 编解码：

```v
import vtauri
import json2

struct AddArgs { a int b int }

fn main() {
	mut app := vtauri.new_app(vtauri.default_config())

	app.register_command('add', fn (args string) !string {
		a := json2.decode[AddArgs](args) or { return error('bad args') }
		return '${a.a + a.b}'
	})

	// ... build / run
}
```

```js
const sum = await window.__VTauri.invoke('add', { a: 20, b: 22 });
// sum === '42'
```

## 6. 编译与运行

| 场景 | 命令 | 说明 |
|------|------|------|
| Linux 本地运行 | `cd examples/hello && v run main.v` | 窗口为桩实现，验证核心逻辑 |
| macOS 本地编译运行 | `v -cc clang -o hello examples/hello` | 自动编译 C++ 桥并链接 Cocoa/WebKit，弹出真实 WKWebView 窗口 |
| 编译 hello 示例（MSVC） | `powershell scripts/build_hello_msvc.ps1` | 自动编译 `webview_bridge.cpp` 为 `.obj` 并链接 |
| 编译 vue/react 示例（MSVC） | `powershell scripts/build_examples_msvc.ps1 -Example all` | 构建前端 + MSVC 编译为 PE32+ |
| 构建 vue/react 前端 | `bash scripts/build_example_frontends.sh all` | `vite build` 内联为单 `dist/index.html` |
| 运行库测试 | `v -cc msvc test vtauri` | 全部单元测试 |

> **说明**：Windows 上运行 vtauri 应用时，WebView2 负责渲染前端页面并接管消息循环；
> 目标机需安装 [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)（Win10/11 通常已内置）。
> macOS 上运行 vtauri 应用时由 WKWebView 渲染，窗口由 webview 库自建 NSWindow，本机已验证；
> Linux 上运行 vtauri 应用时窗口系统为桩实现，核心的配置解析、IPC、命令系统逻辑可完整验证。

## 7. macOS 打包与签名

编译出可执行文件后，用 `scripts/bundle_macos.sh` 打包成标准 macOS .app bundle
（Finder 可双击、`open` 可启动、Dock 显示自定义图标）：

```bash
# ① 编译（Xcode CLT 自带 clang++，自动链接 Cocoa/WebKit）
v -cc clang -o build/hello examples/hello

# ② 没有设计素材时，用 gen_demo_icon.sh 生成演示图标（1024x1024 PNG）
scripts/gen_demo_icon.sh examples/hello/icon.png

# ③ 打包 .app（--icon 可选；--sign 传 Developer ID 走正式签名）
scripts/bundle_macos.sh --exe build/hello \
    --config examples/hello/vtauri.conf.json \
    --out "vtauri hello.app" --icon examples/hello/icon.png

# ④ 启动
open "vtauri hello.app"
```

脚本依赖均为 Xcode Command Line Tools 自带：`python3` / `plutil` / `sips` / `iconutil` / `codesign`。

### 7.1 bundle 目录结构

```
Name.app/
  Contents/
    Info.plist                  # 应用元数据（bundle 标识、版本、图标等）
    MacOS/<productName>         # 可执行文件（来自 --exe）
    Resources/
      vtauri.conf.json          # 配置（应用内包内优先读取）
      icon.icns                 # 可选：由 --icon 的 PNG 经 sips + iconutil 生成
```

### 7.2 Info.plist 与 vtauri.conf.json 的对应关系

| Info.plist 字段 | 来源 | 说明 |
|----------------|------|------|
| `CFBundleExecutable` / `CFBundleName` / `CFBundleDisplayName` | `productName` | 可执行文件名与应用显示名 |
| `CFBundleIdentifier` | `identifier` | 应用唯一标识 |
| `CFBundleVersion` / `CFBundleShortVersionString` | `version` | 构建版本 / 短版本号 |
| `CFBundlePackageType` | 固定 `APPL` | 应用包类型 |
| `LSMinimumSystemVersion` | 固定 `11.0` | 最低系统版本 |
| `NSHighResolutionCapable` | 固定 `true` | 支持 Retina 高分辨率 |
| `CFBundleIconFile` | `--icon` 提供时 | 值为 `icon`（对应 `Resources/icon.icns`） |

生成后脚本自动执行 `plutil -lint` 校验 Info.plist 合法性。

### 7.3 包内配置定位（bundled_config_path）

`.app` 被 Finder / `open` 启动时工作目录为 `/`，相对路径读不到工作目录下的配置文件。
`vtauri.bundled_config_path(path)` 解决该问题：当可执行文件位于 `.app` 包内、且
`Contents/Resources/` 下存在同名配置文件时返回包内路径（**包内优先**），否则原样返回
传入路径（**cwd 兜底**，保持现有相对路径行为）。`examples/hello/main.v` 已改用：

```v
cfg := vtauri.load_config(vtauri.bundled_config_path('vtauri.conf.json')) or { ... }
```

### 7.4 签名两级与公证

- **ad-hoc（默认）**：`--sign` 缺省为 `-`，执行 `codesign --force --sign -`，本机运行/调试足够；
- **Developer ID**：`--sign "Developer ID Application: <Team ID> (XXXX)"` 走
  `codesign --options runtime --timestamp`（hardened runtime）正式签名；
- 两种路径签后都会自动执行 `codesign -v` 校验。

面向外部分发还需公证（脚本不自动化，手动执行）：

```bash
xcrun notarytool submit "Name.app.zip" --apple-id <id> --team-id <team> --password <app-password> --wait
xcrun stapler staple "Name.app"
```

### 7.5 已知限制

- 应用没有菜单栏，Cmd+Q 不可用，退出只能关窗口（属后续项）；
- dmg 制作与公证流程未自动化。

## 8. 架构对应

| Tauri 组件 | vtauri 对应 | 说明 |
|-----------|------------|------|
| `tauri` core | `vtauri/app.v` | 聚合运行时、配置、命令、窗口、WebView |
| `tao` / `winit` | `vtauri/window.v` + `window_windows.v` | Win32 窗口创建与管理（macOS 上由 webview 库自建 NSWindow） |
| `wry` / `WebView2` | `vtauri/webview.v` + `webview_windows.v` / `webview_darwin.v` + `native/webview_bridge.cc` / `native/webview_bridge.cpp` | WebView2 / WKWebView 渲染（集成 webview/webview 库） |
| IPC / command | `vtauri/ipc.v` + `command.v` | 前后端消息编解码与命令分发 |
| `tauri.conf.json` | `vtauri/config.v` | 应用配置解析 |
| `@tauri-apps/api` | `js/vtauri.js` | 前端 `invoke` / `listen` / `emit` |

## 9. 常见问题（FAQ）

### Q1: `v run main.v` 报 `bad module definition: v imports module "vtauri"...`

`vtauri/` 目录内存在 `module main` 的文件导致模块冲突。确保 `vtauri/` 目录内所有非
`_test.v` 文件都声明为 `module vtauri`，可运行入口放在 `examples/` 下。

### Q2: 交叉编译报找不到 `libgc` / 链接错误

V 默认使用 Boehm GC。Linux 上先安装依赖：

```bash
sudo apt-get install -y libgc-dev
```

并在 V 的 `thirdparty` 中提供 `libgc.a`，或直接用系统 gcc 编译（V 会自动链接系统库）。

### Q3: Windows 真机上窗口不显示内容？

旧版本（骨架阶段）WebView2 渲染未实现，只显示空白 Win32 窗口。
本仓库已改为集成 webview/webview 库（方案 A）：

1. 确认已用 MSVC 编译：`powershell scripts/build_hello_msvc.ps1` 或 `powershell scripts/build_examples_msvc.ps1 -Example all`；
2. 确认目标机装有 WebView2 Runtime；
3. 若仍空白，检查 `app.build()` 之后是否调用了 `app.load_html(...)` 加载入口页面，
   以及页面中是否正确内联了 `js/vtauri.js`（参考 `examples/hello/main.v`）。
