#!/usr/bin/env bash
# bundle_macos.sh — 将 vtauri 可执行文件打包成 macOS .app bundle
#
# 产物结构：
#   Name.app/Contents/
#     Info.plist                  # 应用元数据（bundle 标识、版本、图标等）
#     MacOS/<productName>         # 拷贝自 --exe 的可执行文件
#     Resources/vtauri.conf.json  # 配置文件（应用内会优先读取包内配置，
#                                 # 这样从 Finder / open 启动（cwd=/）也不会丢失配置）
#     Resources/icon.icns         # 可选：由 --icon 的 PNG 生成
#
# 用法：
#   scripts/bundle_macos.sh --exe build/hello \
#       --config examples/hello/vtauri.conf.json --out "vtauri hello.app"
#   scripts/bundle_macos.sh --exe build/hello \
#       --config examples/hello/vtauri.conf.json --out "vtauri hello.app" \
#       --icon examples/hello/icon.png --sign "Developer ID Application: XXX"
#
# --sign 缺省为 "-"（ad-hoc 签名，本地运行/调试用）；传入真实身份时走
# --options runtime --timestamp 的 Developer ID 签名路径。
# 依赖：python3 / plutil / sips / iconutil / codesign（Xcode Command Line Tools）。

set -euo pipefail

usage() {
  echo "usage: $(basename "$0") --exe <binary> --config <vtauri.conf.json> --out <Name.app> [--icon <png>] [--sign <identity>]" >&2
  exit 1
}

EXE=""
CONFIG=""
OUT=""
ICON=""
SIGN="-"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --exe)
      [ "$#" -ge 2 ] || { echo "error: --exe 需要参数" >&2; usage; }
      EXE="$2"
      shift 2
      ;;
    --config)
      [ "$#" -ge 2 ] || { echo "error: --config 需要参数" >&2; usage; }
      CONFIG="$2"
      shift 2
      ;;
    --out)
      [ "$#" -ge 2 ] || { echo "error: --out 需要参数" >&2; usage; }
      OUT="$2"
      shift 2
      ;;
    --icon)
      [ "$#" -ge 2 ] || { echo "error: --icon 需要参数" >&2; usage; }
      ICON="$2"
      shift 2
      ;;
    --sign)
      [ "$#" -ge 2 ] || { echo "error: --sign 需要参数" >&2; usage; }
      SIGN="$2"
      shift 2
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      ;;
  esac
done

if [ -z "${EXE}" ] || [ -z "${CONFIG}" ] || [ -z "${OUT}" ]; then
  echo "error: --exe / --config / --out 均为必填参数" >&2
  usage
fi

for f in "${EXE}" "${CONFIG}"; do
  if [ ! -e "${f}" ]; then
    echo "error: 文件不存在: ${f}" >&2
    exit 1
  fi
done

if [ -n "${ICON}" ] && [ ! -e "${ICON}" ]; then
  echo "error: 图标文件不存在: ${ICON}" >&2
  exit 1
fi

# 从 vtauri.conf.json 提取字段；缺失/为空时报错并打 usage 到 stderr。
extract_field() {
  python3 -c '
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        cfg = json.load(f)
except Exception as e:
    print(f"error: 无法解析配置文件 {sys.argv[1]}: {e}", file=sys.stderr)
    sys.exit(1)
field = sys.argv[2]
val = cfg.get(field, "")
if not isinstance(val, str) or not val.strip():
    print(f"error: 配置字段 {field} 缺失或为空", file=sys.stderr)
    sys.exit(1)
print(val.strip())
' "$1" "$2"
}

PRODUCT_NAME="$(extract_field "${CONFIG}" productName)" || usage
IDENTIFIER="$(extract_field "${CONFIG}" identifier)" || usage
VERSION="$(extract_field "${CONFIG}" version)" || usage

echo "==> 将创建应用包: ${OUT}"

if [ -e "${OUT}" ]; then
  echo "==> 移除已存在的 ${OUT}"
  rm -rf "${OUT}"
fi
mkdir -p "${OUT}/Contents/MacOS" "${OUT}/Contents/Resources"

# --- Info.plist ---
PLIST="${OUT}/Contents/Info.plist"

ICON_KEYS=""
if [ -n "${ICON}" ]; then
  ICON_KEYS=$(cat <<'EOF'
	<key>CFBundleIconFile</key>
	<string>icon</string>
EOF
)
fi

cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>${IDENTIFIER}</string>
	<key>CFBundleName</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundleDisplayName</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
${ICON_KEYS}
</dict>
</plist>
EOF

plutil -lint "${PLIST}"

# --- 可执行文件与配置 ---
cp "${EXE}" "${OUT}/Contents/MacOS/${PRODUCT_NAME}"
chmod +x "${OUT}/Contents/MacOS/${PRODUCT_NAME}"
cp "${CONFIG}" "${OUT}/Contents/Resources/vtauri.conf.json"

# --- 图标（可选）：PNG -> .iconset -> .icns ---
if [ -n "${ICON}" ]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  ICONSET="${TMP_DIR}/$(basename "${OUT}" .app).iconset"
  mkdir -p "${ICONSET}"

  gen_icon() {
    sips -z "$1" "$1" "${ICON}" --out "$2" >/dev/null
  }

  gen_icon 16   "${ICONSET}/icon_16x16.png"
  gen_icon 32   "${ICONSET}/icon_16x16@2x.png"
  gen_icon 32   "${ICONSET}/icon_32x32.png"
  gen_icon 64   "${ICONSET}/icon_32x32@2x.png"
  gen_icon 128  "${ICONSET}/icon_128x128.png"
  gen_icon 256  "${ICONSET}/icon_128x128@2x.png"
  gen_icon 256  "${ICONSET}/icon_256x256.png"
  gen_icon 512  "${ICONSET}/icon_256x256@2x.png"
  gen_icon 512  "${ICONSET}/icon_512x512.png"
  gen_icon 1024 "${ICONSET}/icon_512x512@2x.png"

  iconutil -c icns "${ICONSET}" -o "${OUT}/Contents/Resources/icon.icns"

  rm -rf "${TMP_DIR}"
  trap - EXIT
fi

# --- 签名 ---
if [ "${SIGN}" = "-" ]; then
  echo "==> ad-hoc 签名: ${OUT}"
  codesign --force --sign - "${OUT}"
else
  echo "==> 签名（identity=${SIGN}）: ${OUT}"
  codesign --force --options runtime --timestamp --sign "${SIGN}" "${OUT}"
fi
codesign -v "${OUT}"

echo "==> OK: ${OUT}（productName=${PRODUCT_NAME}, identifier=${IDENTIFIER}, version=${VERSION}）"
