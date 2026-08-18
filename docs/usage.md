# vtauri 使用方案（Usage Guide）

> 本文档介绍如何使用 **vtauri** 开发一个基于 V 语言、Tauri 风格的 Windows 桌面应用。
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

### 1.2 Windows 交叉编译工具（Linux 上开发 Windows 应用时）

在 Linux 上交叉编译 Windows `.exe` 需要 MinGW（含 C++ 编译器，因为 vtauri 的 WebView 集成依赖一个 C++ 桥）：

```bash
# Debian / Ubuntu
sudo apt-get install -y g++-mingw-w64-x86-64
```

在 Windows 本机上开发则无需此工具，直接用 `v -os windows` 或默认编译即可。

### 1.3 项目依赖

vtauri 的 V 代码除 V 标准库外**无外部依赖**（`v.mod` 的 `dependencies` 为空）。
为渲染 Web 前端，vtauri 集成了第三方 **webview/webview** 库（MIT，头文件已 vendored 在
`native/webview/`，内部封装 WebView2），仅需在构建时用 C++ 编译器把
`native/webview_bridge.cc` 编译为一个对象文件即可。

## 2. 目录结构

```
vtauri/            # 框架核心（库模块 vtauri）
  config.v         # 配置系统：解析 vtauri.conf.json
  window.v         # 窗口抽象 + 跨平台桩
  window_windows.v # Win32 窗口实现（CreateWindowExW + 消息循环）
  webview.v        # WebView 抽象接口（跨平台调度）
  webview_windows.v# WebView Windows 实现（集成 webview/webview 库 + IPC）
  ipc.v            # IPC 消息协议
  command.v        # 命令注册与分发
  app.v            # App 主类（聚合各组件）
  jsonx.v          # JSON 编解码辅助
native/            # WebView C++ 集成
  webview/         # vendored 的 webview/webview 头文件（MIT）
  vtauri_webview.h # V 侧 include 的 C 桥接接口
  webview_bridge.cc# C++ 桥实现（需 g++ 编译为 .o）
js/
  vtauri.js        # 前端 API（invoke / listen / emit）
examples/
  hello/           # 最小可运行示例
scripts/
  build_webview_bridge.sh # 编译 C++ 桥
  build_hello_windows.sh  # 一键交叉编译示例
```

> **注意**：`vtauri/` 是一个纯 V 库模块，请勿在其中放置 `module main` 的入口文件，
> 否则会破坏该模块被示例项目导入。可运行入口统一放在 `examples/` 下。

## 3. 快速开始

### 3.1 直接运行示例

```bash
# 编译并运行最小示例（Linux 上窗口为桩实现，打印启动信息）
cd examples/hello
v run main.v

# 交叉编译为 Windows 可执行文件（先编译 C++ 桥，再交叉编译）
bash scripts/build_hello_windows.sh
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
const (
	index_html = $embed_file('index.html')
	vtauri_js  = $embed_file('../../js/vtauri.js')
)

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
| 编译 C++ 桥 | `bash scripts/build_webview_bridge.sh` | 用 g++ 生成 `native/webview_bridge.o` |
| 交叉编译 Windows | `bash scripts/build_hello_windows.sh` | 一键编译桥 + 交叉编译为 PE32+ |
| 运行库测试 | `v test vtauri` | 全部单元测试 |

> **说明**：Windows 上运行 vtauri 应用时，WebView2 负责渲染前端页面并接管消息循环；
> 目标机需安装 [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)（Win10/11 通常已内置）。
> Linux 上运行 vtauri 应用时窗口系统为桩实现，核心的配置解析、IPC、命令系统逻辑可完整验证；
> 真正的 WebView2 渲染需在 Windows 运行时联调。

## 7. 架构对应

| Tauri 组件 | vtauri 对应 | 说明 |
|-----------|------------|------|
| `tauri` core | `vtauri/app.v` | 聚合运行时、配置、命令、窗口、WebView |
| `tao` / `winit` | `vtauri/window.v` + `window_windows.v` | Win32 窗口创建与管理 |
| `wry` / `WebView2` | `vtauri/webview.v` + `webview_windows.v` + `native/webview_bridge.cc` | WebView2 渲染（集成 webview/webview 库） |
| IPC / command | `vtauri/ipc.v` + `command.v` | 前后端消息编解码与命令分发 |
| `tauri.conf.json` | `vtauri/config.v` | 应用配置解析 |
| `@tauri-apps/api` | `js/vtauri.js` | 前端 `invoke` / `listen` / `emit` |

## 8. 常见问题（FAQ）

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

1. 确认已编译 C++ 桥：`bash scripts/build_webview_bridge.sh`；
2. 确认目标机装有 WebView2 Runtime；
3. 若仍空白，检查 `app.build()` 之后是否调用了 `app.load_html(...)` 加载入口页面，
   以及页面中是否正确内联了 `js/vtauri.js`（参考 `examples/hello/main.v`）。
