[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-common.ps1')

$projectRoot = Get-ProjectRoot
Set-Location -LiteralPath $projectRoot
Enable-ProjectToolFallbacks $projectRoot

$envFile = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    & (Join-Path $PSScriptRoot 'init-env.ps1')
    throw 'Set SILICONFLOW_API_KEY in .env, then run this script again.'
}

foreach ($command in @('docker', 'java', 'node', 'ffmpeg', 'tesseract')) {
    Assert-Command $command
}

Import-DotEnv $envFile
foreach ($variable in @(
    'DB_PASSWORD',
    'MYSQL_ROOT_PASSWORD',
    'REDIS_PASSWORD',
    'MINIO_SECRET_KEY',
    'QDRANT_API_KEY',
    'SILICONFLOW_API_KEY'
)) {
    Assert-ConfiguredValue $variable
}

$mysqlData = Join-Path $projectRoot 'mysql\data\mysql'
$appUser = if ($env:MYSQL_APP_USER) { $env:MYSQL_APP_USER } else { 'dovideo' }
if (-not (Test-Path -LiteralPath $mysqlData) -and $env:DB_USERNAME -ne $appUser) {
    throw 'DB_USERNAME and MYSQL_APP_USER must match for a fresh database.'
}

$javaText = (& java --version | Select-Object -First 1) -join ''
$javaMatch = [regex]::Match($javaText, '(?:java\s+|")(?<version>\d+)(?:\.|\")')
if (-not $javaMatch.Success -or [int]$javaMatch.Groups['version'].Value -lt 21) {
    throw "JDK 21+ is required; found: $javaText"
}

$nodeText = (& node --version).TrimStart('v')
$nodeMajor = [int]($nodeText.Split('.')[0])
if ($nodeMajor -lt 22) {
    throw "Node.js 22+ is required; found: $nodeText"
}

Ensure-DockerDesktopReady
& docker info | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop engine is unavailable.' }

& docker compose --env-file $envFile config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose configuration validation failed.' }

& docker compose --env-file $envFile up --wait --wait-timeout 240
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose services did not become ready.' }

$qdrantHeaders = @{ 'api-key' = $env:QDRANT_API_KEY }
Invoke-WebRequest -Uri 'http://127.0.0.1:6333/healthz' -Headers $qdrantHeaders -UseBasicParsing | Out-Null
Invoke-WebRequest -Uri 'http://127.0.0.1:9000/minio/health/live' -UseBasicParsing | Out-Null

& docker compose --env-file $envFile ps
Write-Host ''
Write-Host 'Infrastructure is ready.' -ForegroundColor Green
Write-Host 'Start the backend:  .\scripts\dev-backend.ps1'
Write-Host 'Start the frontend: .\scripts\dev-frontend.ps1'
