#!/usr/bin/env bash
# build_example_frontends.sh — 构建 examples/vue 与 examples/react 的前端
#
# 每个示例的前端是标准 Vite 工程（frontend/），构建产物用 vite-plugin-singlefile
# 内联为单个 dist/index.html，供 V 侧 main.v 的 $embed_file 编译期嵌入。
#
# 构建前会把仓库根 js/vtauri.js 拷贝到各 frontend/src/vtauri.js，
# 保证前端 bundle 里始终是最新版本的 vtauri API。
#
# 用法：
#   bash scripts/build_example_frontends.sh            # 构建全部示例前端
#   bash scripts/build_example_frontends.sh vue        # 只构建 vue
#   bash scripts/build_example_frontends.sh react      # 只构建 react

set -euo pipefail

cd "$(dirname "$0")/.."

VTAURI_JS="js/vtauri.js"

build_one() {
  local name="$1"
  local frontend="examples/${name}/frontend"
  local src_js="${frontend}/src/vtauri.js"

  echo "==> [${name}] Copying ${VTAURI_JS} -> ${src_js}"
  cp "${VTAURI_JS}" "${src_js}"

  if [ ! -d "${frontend}/node_modules" ]; then
    echo "==> [${name}] Installing npm dependencies"
    (cd "${frontend}" && npm install)
  fi

  echo "==> [${name}] Building frontend (vite build -> dist/index.html)"
  (cd "${frontend}" && npm run build)
  echo "==> [${name}] OK: ${frontend}/dist/index.html"
}

TARGET="${1:-all}"
case "${TARGET}" in
  all)   build_one vue; build_one react ;;
  vue)   build_one vue ;;
  react) build_one react ;;
  *)     echo "error: unknown target '${TARGET}' (expected: all | vue | react)" >&2; exit 1 ;;
esac

echo "==> All frontends built."
