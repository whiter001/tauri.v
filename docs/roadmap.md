# vtauri 路线图（Roadmap）

> 记录各 Phase 的完成情况与后续规划。更详细的设计与拆分见仓库根目录的 [plan.md](plan.md)。

## 已完成

- [x] **Phase 1：应用与配置骨架** — `vtauri/config.v` 解析 `vtauri.conf.json`，`vtauri/app.v` 聚合运行时
- [x] **Phase 2：Win32 窗口系统** — `vtauri/window_windows.v` 基于 `CreateWindowExW` + 消息循环；非 Windows 平台提供桩实现
- [x] **Phase 3：IPC 与命令系统** — `vtauri/ipc.v` 消息编解码、`vtauri/command.v` 命令注册与分发
- [x] **Phase 4：前端 JS API** — `js/vtauri.js` 提供 `invoke` / `listen` / `emit`
- [x] **Phase 5：示例 + Windows 交叉编译** — `examples/hello` 最小可运行应用，配套交叉编译脚本
- [x] **Phase 6：WebView 渲染** — 集成 webview/webview 库（封装 WebView2），通过 `set_html` 渲染；支持 MSVC 本机编译与窗口尺寸自适应
- [x] **Phase 7：macOS 支持** — `vtauri/webview_darwin.v` 基于 webview/webview 的 WKWebView 后端，窗口由库自建 NSWindow；本机编译、渲染与 IPC 已验证
- [x] **Phase 8：macOS 打包** — `scripts/bundle_macos.sh` 组 .app（Info.plist/图标/ad-hoc 或 Developer ID 签名），`scripts/gen_demo_icon.sh` 程序生成演示图标；`bundled_config_path` 支持包内配置
- [x] **Phase 9：macOS 菜单栏与窗口控制** — 自动安装标准菜单栏（Cmd+Q、Edit 复制粘贴快捷键）、App.quit()、resizable 配置生效
- [x] **Phase 10：macOS 原生对话框** — vtauri/dialog.v：消息框 / 打开文件 / 保存文件（NSAlert/NSOpenPanel/NSSavePanel），前后端 IPC 全链路真机验证
- [x] **Phase 11：macOS 系统托盘** — vtauri/tray.v：NSStatusItem 托盘图标 + 菜单项回调（动态类 IMP），点击退出链路真机验证

## 待办

- [ ] **WebView2 真机渲染验证**（需 Windows 主机 + WebView2 运行时）
- [ ] 原生菜单自定义、通知、托盘图片图标
- [ ] 跨平台（Linux）
- [ ] 应用打包器（NSIS / MSI / dmg + 公证自动化）
