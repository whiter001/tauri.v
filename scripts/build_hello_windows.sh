#!/usr/bin/env bash
# build_hello_windows.sh — 交叉编译 examples/hello 为 Windows .exe
#
# 步骤：
#   1. 用 MinGW g++ 编译 native/webview_bridge.cc 为 .o
#   2. 用 V 交叉编译 examples/hello/main.v 为 .exe（链接上述 .o + -lstdc++）
#
# 前置要求：
#   - V 编译器（v）在 PATH 中
#   - x86_64-w64-mingw32-g++（MinGW-w64）在 PATH 中
#
# 用法：bash scripts/build_hello_windows.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> [1/2] Compiling native webview bridge (C++)"
CXX="${CXX:-x86_64-w64-mingw32-g++}" bash scripts/build_webview_bridge.sh

echo "==> [2/2] Cross-compiling examples/hello"
cd examples/hello
v -os windows -o hello.exe main.v

echo "==> OK: examples/hello/hello.exe"
