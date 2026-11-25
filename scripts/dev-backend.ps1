[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-common.ps1')

$projectRoot = Get-ProjectRoot
Enable-ProjectToolFallbacks $projectRoot
Import-DotEnv (Join-Path $projectRoot '.env')
Set-Location -LiteralPath (Join-Path $projectRoot 'server')
& .\mvnw.cmd spring-boot:run
exit $LASTEXITCODE
