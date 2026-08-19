param(
  [ValidateSet("vue", "react", "remote", "all")]
  [string]$Example = "all",
  [switch]$Run
)

# build_examples_msvc.ps1 — 用 MSVC 构建 examples/vue、examples/react 与 examples/remote 的 Windows 可执行文件
#
# 步骤（每个带 frontend 的示例）：
#   1. 把仓库根 js/vtauri.js 拷贝到 frontend/src/vtauri.js（保持前端 bundle 中的 API 最新）
#   2. npm install（若 node_modules 不存在）+ vite build（vite-plugin-singlefile 内联为单 HTML）
#   3. v -cc msvc 编译 main.v（V 的 thirdparty object builder 自动用 cl 编译
#      native/webview_bridge.cpp 为 .obj 并链接，无需手动运行 vcvars64.bat）
#
# remote 示例没有 frontend 目录，直接执行第 3 步（无内嵌资源，用 load_url 加载远程页面）。
#
# 前置要求：
#   - V 编译器（v）在 PATH 中
#   - node / npm 在 PATH 中
#   - MSVC（Visual Studio / Build Tools）已安装
#   - 目标机需安装 WebView2 Runtime（Win10/11 通常已内置）
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/build_examples_msvc.ps1 -Example vue
#   powershell -ExecutionPolicy Bypass -File scripts/build_examples_msvc.ps1 -Example remote -Run
#   powershell -ExecutionPolicy Bypass -File scripts/build_examples_msvc.ps1 -Example all -Run

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Build-Example([string]$name) {
  $ExampleDir = Join-Path $RepoRoot "examples\$name"
  $FrontendDir = Join-Path $ExampleDir "frontend"

  if (Test-Path $FrontendDir) {
    # 1. 同步 vtauri 前端 API
    Write-Host "==> [$name] Copying js/vtauri.js -> frontend/src/vtauri.js"
    Copy-Item (Join-Path $RepoRoot "js\vtauri.js") (Join-Path $FrontendDir "src\vtauri.js") -Force

    # 2. 前端依赖与单文件构建
    if (!(Test-Path (Join-Path $FrontendDir "node_modules"))) {
      Write-Host "==> [$name] Installing npm dependencies"
      Push-Location $FrontendDir
      npm install
      Pop-Location
    }

    Write-Host "==> [$name] Building frontend (vite build -> dist/index.html)"
    Push-Location $FrontendDir
    npm run build
    Pop-Location
  } else {
    Write-Host "==> [$name] No frontend/ directory, skipping frontend build"
  }

  # 3. MSVC 编译
  Write-Host "==> [$name] Compiling with MSVC (v -cc msvc)"
  Push-Location $ExampleDir
  v -cc msvc -o "$name.exe" main.v
  Pop-Location
  Write-Host "==> [$name] OK: examples/$name/$name.exe"

  if ($Run) {
    Write-Host "==> [$name] Launching $name.exe"
    Start-Process -FilePath (Join-Path $ExampleDir "$name.exe")
  }
}

$Targets = if ($Example -eq "all") { @("vue", "react", "remote") } else { @($Example) }
foreach ($t in $Targets) {
  Build-Example $t
}

Write-Host "==> All examples built."
