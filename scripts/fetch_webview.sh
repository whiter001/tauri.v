#!/usr/bin/env bash
# fetch_webview.sh — 从 webview/webview 上游抓取 vendored 头文件到 native/webview/
#
# 用法：bash scripts/fetch_webview.sh
set -euo pipefail

cd "$(dirname "$0")/.."

BASE="https://api.github.com/repos/webview/webview/contents/core/include/webview"
DEST="native/webview"

fetch_dir() {
  local api_path="$1" out_dir="$2"
  mkdir -p "${out_dir}"
  python3 - "$api_path" "$out_dir" <<'PY'
import json, os, sys, urllib.request
api_path, out_dir = sys.argv[1], sys.argv[2]
url = f"https://api.github.com/repos/webview/webview/contents/{api_path}"
req = urllib.request.Request(url, headers={"User-Agent": "curl"})
for x in json.load(urllib.request.urlopen(req)):
    if x["type"] == "dir":
        sub = os.path.join(out_dir, x["name"])
        fetch_dir(x["path"], sub)
    else:
        p = os.path.join(out_dir, x["name"])
        os.makedirs(os.path.dirname(p), exist_ok=True)
        r = urllib.request.Request(x["download_url"], headers={"User-Agent": "curl"})
        open(p, "wb").write(urllib.request.urlopen(r).read())
        print("wrote", p)
PY
}

echo "==> Fetching webview headers from ${BASE}"
fetch_dir "core/include/webview" "${DEST}"

echo "==> Fetching LICENSE"
curl -sL "https://raw.githubusercontent.com/webview/webview/master/LICENSE" -o "${DEST}/LICENSE"

echo "==> OK: vendored headers in ${DEST}"
