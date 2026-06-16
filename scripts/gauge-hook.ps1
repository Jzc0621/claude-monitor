param([string]$State = "idle")

# Context Gauge — Event Hook
# Writes state changes (compacting, stopped, idle) to the gauge file.
# Context percentage comes from the statusline hook, this handles lifecycle.

$gaugeFile = Join-Path $env:TEMP "claude-context-gauge.json"
$tmpFile = "$gaugeFile.tmp"

# Read existing data to preserve remaining percentage
$remaining = 100.0
if (Test-Path $gaugeFile) {
    try {
        $existing = Get-Content $gaugeFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $remaining = if ($null -ne $existing.remaining) { [double]$existing.remaining } else { 100.0 }
    } catch {}
}

$data = @{
    remaining = $remaining
    status    = $State
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json -Compress

try {
    [System.IO.File]::WriteAllText($tmpFile, $data, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Force $tmpFile $gaugeFile
} catch {
    [System.IO.File]::WriteAllText($gaugeFile, $data, [System.Text.UTF8Encoding]::new($false))
}

exit 0
