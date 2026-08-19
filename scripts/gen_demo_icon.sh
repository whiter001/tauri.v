#!/usr/bin/env bash
# gen_demo_icon.sh — 生成 vtauri 示例应用的 macOS 风格图标（1024x1024 PNG）
#
# 用 Swift 绘制：深蓝(#1B3A5C) → 蓝紫(#3B6CB4) 垂直渐变圆角矩形，
# 中央居中白色粗体 "V"；输出单张 PNG，可直接传给 scripts/bundle_macos.sh --icon。
#
# 用法：
#   scripts/gen_demo_icon.sh examples/hello/icon.png
#
# 依赖：swift（Xcode Command Line Tools）。可重复执行（覆盖输出文件）。

set -euo pipefail

OUT="${1:-}"
if [ -z "${OUT}" ]; then
  echo "usage: $(basename "$0") <输出 png 路径>" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUT}")"

OUT_PATH="${OUT}" swift - <<'SWIFT'
import AppKit

let outPath = ProcessInfo.processInfo.environment["OUT_PATH"]!

// 1024x1024 像素位图（1pt = 1px，不随屏幕 Retina 缩放而变成 2048）
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: 1024, height: 1024)

guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("error: 无法创建位图绘制上下文")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// 圆角矩形（macOS 图标风格，约 22% 圆角）
let rect = NSRect(x: 0, y: 0, width: 1024, height: 1024)
let path = NSBezierPath(roundedRect: rect, xRadius: 225, yRadius: 225)

// 深蓝 (#1B3A5C) → 蓝紫 (#3B6CB4) 垂直渐变
let top = NSColor(calibratedRed: 0x1B / 255.0, green: 0x3A / 255.0, blue: 0x5C / 255.0, alpha: 1.0)
let bottom = NSColor(calibratedRed: 0x3B / 255.0, green: 0x6C / 255.0, blue: 0xB4 / 255.0, alpha: 1.0)
let gradient = NSGradient(starting: top, ending: bottom)!
gradient.draw(in: path, angle: -90)

// 居中白色粗体 "V"
let font = NSFont.boldSystemFont(ofSize: 620)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
]
let text = NSAttributedString(string: "V", attributes: attrs)
let textSize = text.size()
let origin = NSPoint(x: (1024 - textSize.width) / 2,
                     y: (1024 - textSize.height) / 2)
text.draw(at: origin)

NSGraphicsContext.restoreGraphicsState()

// 导出 PNG
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("error: 无法生成 PNG 数据")
}
do {
    try png.write(to: URL(fileURLWithPath: outPath))
} catch {
    fatalError("error: 无法写入 \(outPath): \(error)")
}
SWIFT

echo "==> OK: ${OUT}"
