#!/usr/bin/env pwsh
# Installs the latest rms-cli release for Windows.
#
# Requires: gh (GitHub CLI) — https://cli.github.com
# The gh CLI handles authentication for private repositories automatically.
#
# Usage:
#   pwsh scripts/install.ps1
#
# Env vars (optional):
#   RMS_CLI_INSTALL_DIR  where to install (default: $env:LOCALAPPDATA\rms-cli)
#   RMS_CLI_VERSION      specific version tag to install (default: latest)

$ErrorActionPreference = "Stop"

$repo = "shopload/rms-claude"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh (GitHub CLI) is required but not found.`nInstall it from https://cli.github.com and run 'gh auth login' first."
    exit 1
}

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
    "arm64"
} else {
    "amd64"
}
$asset = "rms-cli_windows_$arch.exe"

$installDir = if ($env:RMS_CLI_INSTALL_DIR) { $env:RMS_CLI_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "rms-cli" }
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

try {
    Write-Host "Downloading $asset..."

    $versionArgs = if ($env:RMS_CLI_VERSION) { @("--tag", $env:RMS_CLI_VERSION) } else { @() }
    gh release download @versionArgs `
        --repo $repo `
        --pattern $asset `
        --dir $tmpDir

    $destPath = Join-Path $installDir "rms-cli.exe"
    Move-Item -Force (Join-Path $tmpDir $asset) $destPath

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
