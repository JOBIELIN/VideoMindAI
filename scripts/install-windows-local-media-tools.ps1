[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$installerDirectory = Join-Path $env:TEMP 'dovideo-tools'
$ffmpegDirectory = Join-Path $projectRoot 'tools\ffmpeg'
$ocrDirectory = Join-Path $projectRoot 'tools\ocr'

New-Item -ItemType Directory -Force -Path $installerDirectory, $ffmpegDirectory | Out-Null

Push-Location $installerDirectory
try {
    $packageName = (& npm.cmd pack '@ffmpeg-installer/win32-x64@4.1.0' --silent).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $packageName) {
        throw 'Could not download the project-local FFmpeg package.'
    }
    & tar -xf (Join-Path $installerDirectory $packageName) -C $ffmpegDirectory --strip-components=1
    if ($LASTEXITCODE -ne 0) { throw 'Could not extract project-local FFmpeg.' }
}
finally {
    Pop-Location
}

Push-Location $ocrDirectory
try {
    & npm.cmd ci
    if ($LASTEXITCODE -ne 0) { throw 'Could not install the project-local OCR runtime.' }
}
finally {
    Pop-Location
}

& (Join-Path $ffmpegDirectory 'ffmpeg.exe') -version | Select-Object -First 1
& (Join-Path $ocrDirectory 'tesseract.cmd') --list-langs
Write-Host 'Project-local FFmpeg and Chinese/English OCR are ready.' -ForegroundColor Green
