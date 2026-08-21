# vtauri — 用 V 语言实现 Tauri（Windows 优先）

> 目标：将 [tauri-apps/tauri](https://github.com/tauri-apps/tauri) 的架构思想用 **V 语言** 重新实现，产出一个
> 在 **Windows 上可用的桌面应用框架**。本框架命名为 **vtauri**。

## 0. 环境

- V 版本：**0.5.2**（从源码最新编译，`4a8793c`）
- 交叉编译：Linux 下用 `x86_64-w64-mingw32-gcc` 生成 Windows 的 `PE32+` 可执行文件
- 命令：`v -os windows -o out.exe src/main.v`

验证结果：Win32 `MessageBoxW` 已能通过 `#flag windows -luser32` + `#include <windows.h>` + `fn C.MessageBoxW` 正常交叉编译。

## 1. Tauri 架构回顾（要翻译/复刻的点）

| Tauri 组件 | 作用 | vtauri 对应实现 |
|-----------|------|----------------|
| `tauri` core | 整合运行时、宏、工具、API 的主 crate | `vtauri/app.v` + 各子模块 |
| `tao` / `winit` | 跨平台窗口创建与管理 | `vtauri/window.v`（Win32 `CreateWindowExW`） |
| `wry` / `WebView2` | 在窗口内渲染 Web 前端 | `vtauri/webview.v` + `webview_windows.v`（集成 webview/webview） |
| IPC / command | 前端 JS ↔ 后端 V 的消息与命令 | `vtauri/ipc.v` + `vtauri/command.v` |
| `tauri.conf.json` | 编译期应用配置 | `vtauri/config.v`（运行时解析 JSON） |
| `@tauri-apps/api` | 前端可导入的 JS 接口 | `js/vtauri.js` |

## 2. 分期实施计划

### Phase 1 — 应用与配置骨架 ✅（本次完成）
- `config.v`：解析 `vtauri.conf.json`（`productName`、`identifier`、`mainWindow`、`version` 等）。
- `app.v`：`App` 结构体，持有配置、窗口、webview、命令注册表。
- `main.v` 入口：读取配置 → 创建 `App` → 启动。

### Phase 2 — Win32 窗口系统 ✅（本次完成）
- `window.v`：封装 Win32 `RegisterClassExW` / `CreateWindowExW`。
- 注册窗口类、窗口过程（`WndProc`），处理 `WM_DESTROY` 等消息。
- 消息循环（`GetMessageW` / `DispatchMessageW`）。
- 支持设置标题、尺寸、居中。

### Phase 3 — WebView2 渲染（方案 A：集成 webview/webview）✅（已实现）
- `native/webview_bridge.cc`（C++ 桥）：把 webview/webview（header-only C++，封装 WebView2）暴露为稳定 C 接口。
- `native/webview/`：vendored 的 webview/webview 头文件（MIT）。
- `webview_windows.v`：V 侧封装 `vtauri_wv_create / set_html / bind / return / run`。
- `app.build()` 创建窗口后 `attach` WebView 并 `bind_invoke`；通过 `load_html` 渲染嵌入的 HTML。
- 说明：C++ 桥需用 g++ 编译为 `native/webview_bridge.o`（见 `scripts/build_webview_bridge.sh`），Windows 真机验证。

### Phase 4 — IPC 消息传递与 command 命令系统（本次完成框架）
- `ipc.v`：定义前端→后端消息协议（`invoke(command, args)` / 回调）。
- `command.v`：命令注册表，`app.register_command('greet', fn)`；通过 `webview.post_message` 回传结果。

### Phase 5 — 前端 JS API（本次完成）
- `js/vtauri.js`：`window.__VTauri.invoke(...)`，实现类似 `@tauri-apps/api` 的 `invoke`、`listen`。

### Phase 6 — 示例 + 打包（本次完成示例）
- `examples/hello`：一个最小可运行示例（Win32 原生窗口 + JS API 绑定）。
- `tauri-bundler` 的 V 简化版：将前端资源嵌入二进制（`$embed_file`）。

## 3. 关键技术点（V 实现细节）

### 3.1 调用 Win32 API
```v
#flag windows -luser32
#include <windows.h>

fn C.CreateWindowExW(ext_style u32, class &u16, name &u16, style u32, x i32, y i32, w i32, h i32,
	parent voidptr, menu voidptr, instance voidptr, param voidptr) voidptr
```
要点：用 `&u16`（宽字符）传字符串（`str.to_wide()`）；对无返回值的 API 用 `voidptr`。

### 3.2 跨平台编译（Windows 分支）
用 `$if windows { }` 条件编译 + `$else { }` 兜底，保证在 Linux 上仍可编译测试。

### 3.3 WebView2 集成方案（方案 A：集成 webview/webview C 库）
V 不能直接 include C++ 头文件（V 生成 C 代码），因此：
1. 用 `native/webview_bridge.cc`（C++，`#include "webview/webview.h"`）把 C API 转发为稳定 C 符号；
2. 用 g++ 编译为 `native/webview_bridge.o`，V 以 `-lstdc++` 链接；
3. V 侧 `webview_windows.v` 声明这些 C 函数并调用。

IPC：用 `webview_bind` 把 `__vtauriInvoke` 暴露为页面全局函数，前端调用返回 Promise，
后端通过 `webview_return` 兑现为 `App.handle_ipc` 的响应。

## 4. 目录结构

```
vtauri/
  config.v     # 配置系统
  window.v     # Win32 窗口
  webview.v        # WebView 抽象接口（跨平台调度）
  webview_windows.v# WebView Windows 实现（桥接 webview 库 + IPC）
  ipc.v        # IPC 协议
  command.v    # 命令系统
  app.v        # App 主类
js/
  vtauri.js    # 前端 API
examples/
  hello/
    main.v
    vtauri.conf.json
    index.html
tests/
  config_test.v
```

## 5. 完成标准

- [x] 配置解析：读取 `vtauri.conf.json` 并生成 `AppConfig`
- [x] Win32 窗口：创建窗口 + 消息循环（可交叉编译为 `.exe`）
- [x] 命令系统：注册与调用命令
- [x] JS API：前端 `invoke`
- [x] 示例：`examples/hello` 可交叉编译
- [x] WebView 渲染：`index.html` 经 `$embed_file` 嵌入，`set_html` 渲染（方案 A，集成 webview 库）
- [ ] WebView2 真机渲染验证（需 Windows 主机 + WebView2 运行时）
- [x] macOS 支持：webview_darwin.v（WKWebView 后端，库自建 NSWindow），本机编译 + 渲染 + IPC 已验证
- [x] macOS 打包：bundle_macos.sh 组 .app（含图标与签名），open 启动 + Dock 图标已验证
- [x] macOS 菜单栏与窗口控制：标准菜单栏（Cmd+Q/Edit 快捷键）+ App.quit() + resizable 约束，真机已验证
- [x] macOS 原生对话框：dialog.v（消息框/打开/保存），IPC 全链路真机已验证
- [x] macOS 系统托盘：tray.v（NSStatusItem + 菜单回调），真机已验证
- [x] macOS 通知/剪贴板/shell open：notify.v（通知横幅真机确认）/ clipboard.v（剪贴板读写）/ shell.v（默认应用打开 URL），真机验证通过
- [x] macOS 托盘图片图标 + 自定义菜单栏：tray.set_icon（PNG template 图片图标，自适应菜单栏明暗）+ app.set_menus（完全替换菜单栏：自定义项回调 / 系统 selector / 快捷键 / 分隔线），真机验证通过

## 6. 后续路线（超出本次范围）
- 跨平台（Linux / 移动端）后端
- 应用打包器（`.msi` / NSIS `.exe` / dmg + 公证自动化）
- 前端资源打包与自更新
