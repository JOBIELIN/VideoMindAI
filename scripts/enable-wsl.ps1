[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdministrator) {
    throw 'Open PowerShell as Administrator, then run this script again.'
}

& wsl.exe --install --no-distribution
if ($LASTEXITCODE -ne 0) { throw "WSL installation failed (exit code $LASTEXITCODE)." }

& wsl.exe --update
if ($LASTEXITCODE -ne 0) { throw "WSL update failed (exit code $LASTEXITCODE)." }

Write-Host 'WSL 2 is installed. Restart Windows before starting Docker Desktop.' -ForegroundColor Green
