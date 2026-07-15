param(
    [string]$SaveDir = "paper_final_BlockC_100trials_v72"
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$logDir = Join-Path $SaveDir "_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$startupLog = Join-Path $logDir "blockC_batched_matlab_startup.log"

Start-Process -FilePath matlab `
    -ArgumentList @("-batch", "run_blockC_batched_background_entry_v72", "-logfile", $startupLog) `
    -WorkingDirectory $PSScriptRoot `
    -WindowStyle Hidden

"Started Block C batched MATLAB background runner. Startup log: $startupLog"
