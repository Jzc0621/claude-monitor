# Context Gauge — SessionStart helper: launch gauge if not already running.
$ErrorActionPreference = 'SilentlyContinue'

$existing = Get-Process context-gauge -ErrorAction SilentlyContinue
if (-not $existing) {
    $gaugeExe = Join-Path (Split-Path $PSScriptRoot -Parent) 'src-tauri\target\release\context-gauge.exe'
    if (-not (Test-Path $gaugeExe)) {
        # Fallback: check if we're running from source (cargo tauri dev)
        $gaugeExe = Join-Path (Split-Path $PSScriptRoot -Parent) 'src-tauri\target\debug\context-gauge.exe'
    }
    if (Test-Path $gaugeExe) {
        Start-Process $gaugeExe
    }
}
exit 0
