#!/usr/bin/env pwsh
# Installs the latest rms-cli release for Windows.
#
# Usage:
#   irm https://raw.githubusercontent.com/shopload/rms-claude/main/scripts/install.ps1 | iex
#
# Env vars (optional):
#   RMS_CLI_INSTALL_DIR  where to install (default: $env:LOCALAPPDATA\rms-cli)
#   RMS_CLI_VERSION      specific version tag to install (default: latest)

$ErrorActionPreference = "Stop"

$repo = "shopload/rms-claude"

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
    "arm64"
} else {
    "amd64"
}
$asset = "rms-cli_windows_$arch.exe"

$baseUrl = if ($env:RMS_CLI_VERSION) {
    "https://github.com/$repo/releases/download/$env:RMS_CLI_VERSION"
} else {
    "https://github.com/$repo/releases/latest/download"
}

$installDir = if ($env:RMS_CLI_INSTALL_DIR) { $env:RMS_CLI_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "rms-cli" }
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$tmpExe = Join-Path $tmpDir $asset

try {
    Write-Host "Downloading $asset..."
    Invoke-WebRequest -Uri "$baseUrl/$asset" -OutFile $tmpExe -UseBasicParsing

    $destPath = Join-Path $installDir "rms-cli.exe"
    Move-Item -Force $tmpExe $destPath

    Write-Host ""
    Write-Host "rms-cli installed to $destPath"

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { $userPath = "" }
    if (";$userPath;" -notlike "*;$installDir;*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir".Trim(";"), "User")
        Write-Host ""
        Write-Host "Added $installDir to your user PATH. Restart your terminal for this to take effect."
    }

    Write-Host ""
    try {
        & $destPath --version
    } catch {
        Write-Warning "installed but couldn't run --version: $_"
    }

    Write-Host ""
    Write-Host "Next: rms-cli auth login --profile <name> --service-secret <secret> --license-key <key>"
} finally {
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}
