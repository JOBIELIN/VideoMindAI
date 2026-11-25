[CmdletBinding()]
param([switch]$IncludeYtDlp)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is required. Install or update App Installer from Microsoft Store.'
}

$packages = @(
    'Docker.DockerDesktop',
    'Gyan.FFmpeg',
    'UB-Mannheim.TesseractOCR'
)
if ($IncludeYtDlp) {
    $packages += 'yt-dlp.yt-dlp'
}

foreach ($package in $packages) {
    Write-Host "Installing $package ..." -ForegroundColor Cyan
    & winget install --id $package --exact --source winget --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "Installation failed for $package (exit code $LASTEXITCODE)."
    }
}

Write-Host ''
Write-Host 'Tool installation completed.' -ForegroundColor Green
Write-Host 'Restart PowerShell so the updated PATH is loaded.'
Write-Host 'Docker Desktop may require WSL 2 setup and a Windows restart.'
