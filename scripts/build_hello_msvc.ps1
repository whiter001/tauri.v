param(
  [switch]$Run,
  [string]$WebView2Version = "1.0.3537.50"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$WebView2Dir = Join-Path $RepoRoot "native\webview\detail\platform\windows\webview2"
$RequiredHeaders = @("WebView2.h", "WebView2EnvironmentOptions.h")
$MissingWebView2Headers = $RequiredHeaders | Where-Object {
  !(Test-Path -LiteralPath (Join-Path $WebView2Dir $_))
}

if ($MissingWebView2Headers.Count -gt 0) {
  $TempRoot = Join-Path $env:TEMP ("vtauri-webview2-sdk-" + [Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $TempRoot | Out-Null
  $Package = Join-Path $TempRoot "Microsoft.Web.WebView2.nupkg"

  Write-Host "==> Fetching Microsoft.Web.WebView2 $WebView2Version"
  Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/$WebView2Version" -OutFile $Package
  Expand-Archive -Path $Package -DestinationPath $TempRoot

  $IncludeDir = Join-Path $TempRoot "build\native\include"
  Copy-Item -Path (Join-Path $IncludeDir "WebView2*.h") -Destination $WebView2Dir -Force
}

$EventToken = Join-Path $WebView2Dir "EventToken.h"
if (!(Test-Path -LiteralPath $EventToken)) {
  $ProgramFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
  $WinKitIncludeRoot = Join-Path $ProgramFilesX86 "Windows Kits\10\Include"
  $SdkEventToken = Get-ChildItem -Path $WinKitIncludeRoot -Recurse -Filter "EventToken.h" | Sort-Object FullName -Descending | Select-Object -First 1

  if ($null -eq $SdkEventToken) {
    throw "EventToken.h not found. Install the Windows 10/11 SDK, then rerun this script."
  }

  Copy-Item -LiteralPath $SdkEventToken.FullName -Destination $EventToken -Force
}

Push-Location (Join-Path $RepoRoot "examples\hello")
try {
  Write-Host "==> Building examples/hello with MSVC"
  v -cc msvc -o main.exe main.v

  if ($Run) {
    Write-Host "==> Running examples/hello/main.exe"
    .\main.exe
  }
} finally {
  Pop-Location
}
