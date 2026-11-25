[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $projectRoot '.env.example'
$envPath = Join-Path $projectRoot '.env'

if (Test-Path -LiteralPath $envPath) {
    Write-Host '.env already exists; no values were changed.'
    exit 0
}

function New-LocalSecret {
    $bytes = [byte[]]::new(18)
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

$content = Get-Content -Raw -LiteralPath $templatePath -Encoding UTF8
$replacements = @{
    'DB_PASSWORD' = New-LocalSecret
    'MYSQL_ROOT_PASSWORD' = New-LocalSecret
    'REDIS_PASSWORD' = New-LocalSecret
    'MINIO_SECRET_KEY' = New-LocalSecret
    'QDRANT_API_KEY' = New-LocalSecret
}

foreach ($entry in $replacements.GetEnumerator()) {
    $pattern = "(?m)^$([regex]::Escape($entry.Key))=.*$"
    $content = [regex]::Replace($content, $pattern, "$($entry.Key)=$($entry.Value)")
}

Set-Content -LiteralPath $envPath -Value $content -Encoding UTF8
Write-Host 'Created .env with generated local service passwords.' -ForegroundColor Green
Write-Host 'Add your SILICONFLOW_API_KEY before starting the infrastructure.' -ForegroundColor Yellow
