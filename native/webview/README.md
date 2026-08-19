# Vendored: webview/webview

本目录 `native/webview/` 是第三方开源库 **webview/webview** 的 vendored 头文件。

- 上游仓库：https://github.com/webview/webview
- 分支/版本：`master`（抓取自 `core/include/webview/`）
- 许可证：MIT（见本目录 `LICENSE`）
- 用途：vtauri 在 Windows 上用它封装 WebView2，实现 Web 前端渲染。

这些头文件是 header-only 的 C++ 实现，由 `native/webview_bridge.cpp`（`#include` 实现
`webview_bridge.cc`）编译为 `webview_bridge.obj` 供 V 链接（`v -cc msvc` 时自动编译）。
请勿直接修改这些 vendored 文件；如需升级，重新从上游抓取即可。
