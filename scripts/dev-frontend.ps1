[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-common.ps1')

$projectRoot = Get-ProjectRoot
Import-DotEnv (Join-Path $projectRoot '.env')
Set-Location -LiteralPath (Join-Path $projectRoot 'client')

if (-not (Test-Path -LiteralPath 'node_modules')) {
    & npm.cmd ci
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& npm.cmd run dev
exit $LASTEXITCODE
