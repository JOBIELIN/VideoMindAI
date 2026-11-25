$ErrorActionPreference = 'Stop'

function Get-ProjectRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Import-DotEnv {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing configuration file: $Path"
    }

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) {
            continue
        }

        $parts = $trimmed.Split('=', 2)
        if ($parts.Count -ne 2) {
            continue
        }

        $name = $parts[0].Trim()
        $value = $parts[1].Trim()
        if (($value.StartsWith("'") -and $value.EndsWith("'")) -or
            ($value.StartsWith('"') -and $value.EndsWith('"'))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        Set-Item -Path "Env:$name" -Value $value
    }
}

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

function Assert-ConfiguredValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('change-')) {
        throw "Set a non-example value for $Name in .env"
    }
}

function Enable-ProjectToolFallbacks {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $toolDirectories = @(
        (Join-Path $ProjectRoot 'tools\ffmpeg'),
        (Join-Path $ProjectRoot 'tools\ocr'),
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin')
    )
    foreach ($directory in $toolDirectories) {
        # Prefer an installed FFmpeg; legacy bundled fallback may not support current flags.
        if ($directory -eq (Join-Path $ProjectRoot 'tools\ffmpeg') -and
            (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
            continue
        }
        if (Test-Path -LiteralPath $directory) {
            $env:Path = "$directory;$env:Path"
        }
    }
}

function Test-DockerDesktopEngineReady {
    return (Test-Path -LiteralPath '\\.\pipe\dockerDesktopLinuxEngine')
}

function Get-DockerDesktopExecutable {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    throw 'Docker Desktop executable was not found.'
}

function Reset-StaleDockerRuntimeSockets {
    $localRoot = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\') + '\'
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $runtimeDirectories = @(
        (Join-Path $env:LOCALAPPDATA 'Docker\run'),
        (Join-Path $env:LOCALAPPDATA 'docker-secrets-engine')
    )

    foreach ($sourceDirectory in $runtimeDirectories) {
        $resolvedSource = [System.IO.Path]::GetFullPath($sourceDirectory)
        if (-not $resolvedSource.StartsWith($localRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to move unexpected Docker runtime directory: $resolvedSource"
        }

        if (Test-Path -LiteralPath $resolvedSource) {
            $leaf = Split-Path -Leaf $resolvedSource
            $parent = Split-Path -Parent $resolvedSource
            $destination = Join-Path $parent "$leaf-stale-$timestamp"
            $suffix = 0
            while (Test-Path -LiteralPath $destination) {
                $suffix += 1
                $destination = Join-Path $parent "$leaf-stale-$timestamp-$suffix"
            }
            Move-Item -LiteralPath $resolvedSource -Destination $destination -ErrorAction Stop
        }
        New-Item -ItemType Directory -Path $resolvedSource -Force | Out-Null
    }
}

function Wait-DockerDesktopEngine {
    param([int]$TimeoutSeconds = 90)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-DockerDesktopEngineReady) {
            return $true
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Ensure-DockerDesktopReady {
    if (Test-DockerDesktopEngineReady) {
        return
    }

    $staleSockets = @(
        (Join-Path $env:LOCALAPPDATA 'Docker\run\sailor-ingest.sock'),
        (Join-Path $env:LOCALAPPDATA 'docker-secrets-engine\engine.sock')
    ) | Where-Object { Test-Path -LiteralPath $_ }

    if ($staleSockets.Count -gt 0) {
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -like '*docker*' -or $_.ProcessName -like 'com.docker*' } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        & wsl --shutdown
        Start-Sleep -Seconds 2
        Reset-StaleDockerRuntimeSockets
    }

    $dockerDesktop = Get-DockerDesktopExecutable
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden
    if (-not (Wait-DockerDesktopEngine)) {
        throw 'Docker Desktop did not become ready within 90 seconds.'
    }
}
