# Context Gauge — combined hook + launcher
# Writes idle state, then launches gauge if not already running.
$ErrorActionPreference = 'SilentlyContinue'

# ── Write gauge state ──────────────────────────────────────────
$gaugeFile = Join-Path $env:TEMP "claude-context-gauge.json"
if ($args[0]) {
    $state = $args[0]
    $remaining = 100.0
    if (Test-Path $gaugeFile) {
        try {
            $existing = Get-Content $gaugeFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $remaining = if ($null -ne $existing.remaining) { [double]$existing.remaining } else { 100.0 }
        } catch {}
    }
    $data = "{`"remaining`":$remaining,`"status`":`"$state`",`"timestamp`":`"$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')`"}"
    try {
        $tmp = "$gaugeFile.tmp"
        [System.IO.File]::WriteAllText($tmp, $data, [System.Text.UTF8Encoding]::new($false))
        Move-Item -Force $tmp $gaugeFile
    } catch {
        [System.IO.File]::WriteAllText($gaugeFile, $data, [System.Text.UTF8Encoding]::new($false))
    }
}

# ── Launch if not running ──────────────────────────────────────
$existing = Get-Process context-gauge -ErrorAction SilentlyContinue
if (-not $existing) {
    $root = Split-Path $PSScriptRoot -Parent
    $exe = Join-Path $root 'src-tauri\target\release\context-gauge.exe'
    if (-not (Test-Path $exe)) {
        $exe = Join-Path $root 'src-tauri\target\debug\context-gauge.exe'
    }
    if (Test-Path $exe) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    }
}

exit 0
