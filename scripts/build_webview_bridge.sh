#!/usr/bin/env bash
# build_webview_bridge.sh — 用 g++ 编译 vtauri 的 C++ 桥接层
#
# vtauri 集成 webview/webview 库（header-only C++，内部封装 WebView2）。
# 该库不能由 V 直接 include（V 生成 C 代码），因此先把 native/webview_bridge.cc
# 编译为一个对象文件 native/webview_bridge.o，V 侧以 -lstdc++ 链接。
#
# 用法：
#   bash scripts/build_webview_bridge.sh            # 用本机 g++
#   CXX=x86_64-w64-mingw32-g++ bash scripts/build_webview_bridge.sh  # 交叉编译

set -euo pipefail

cd "$(dirname "$0")/.."

CXX="${CXX:-g++}"
NATIVE_DIR="native"
OUT="${NATIVE_DIR}/webview_bridge.o"

echo "==> Compiling ${NATIVE_DIR}/webview_bridge.cc with ${CXX}"

# -I native 让 #include "webview/webview.h" 与 "vtauri_webview.h" 可被解析。
"${CXX}" \
  -std=c++17 \
  -O2 \
  -I "${NATIVE_DIR}" \
  -c "${NATIVE_DIR}/webview_bridge.cc" \
  -o "${OUT}"

echo "==> OK: ${OUT}"
