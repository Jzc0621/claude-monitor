# Context Gauge — StatusLine Hook
# Reads Claude Code session JSON from stdin, extracts context_window info,
# writes to temp file for the gauge app to read.
# Also outputs a minimal status line to keep the terminal happy.

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$in = [Console]::In.ReadToEnd()
if (-not $in) { Write-Output "Claude"; exit 0 }

try { $j = $in | ConvertFrom-Json } catch { Write-Output "Claude"; exit 0 }

# ── Extract context data ───────────────────────────────────────
$remaining = $j.context_window.remaining_percentage
$status = "normal"

if ($j.exceeds_200k_tokens) {
    $status = "critical"
}

# ── Write gauge file ────────────────────────────────────────────
$gaugeFile = Join-Path $env:TEMP "claude-context-gauge.json"
$tmpFile = "$gaugeFile.tmp"

$data = @{
    remaining = if ($null -ne $remaining) { [double]$remaining } else { 100.0 }
    status    = $status
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json -Compress

try {
    [System.IO.File]::WriteAllText($tmpFile, $data, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Force $tmpFile $gaugeFile
} catch {
    [System.IO.File]::WriteAllText($gaugeFile, $data, [System.Text.UTF8Encoding]::new($false))
}

# ── Minimal status line output ──────────────────────────────────
$dir = Split-Path $j.workspace.current_dir -Leaf
$ctx = if ($null -ne $remaining) { "$([math]::Round($remaining))%" } else { "---" }
Write-Output "[$dir] ctx $ctx"
