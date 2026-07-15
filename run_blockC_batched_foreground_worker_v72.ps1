param(
    [string]$SaveDir = "paper_final_BlockC_100trials_v72"
)

$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

$logDir = Join-Path $SaveDir "_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$psLog = Join-Path $logDir "blockC_batched_worker_$stamp.pslog"
$matLog = Join-Path $logDir "blockC_batched_worker_$stamp.matlab.log"

"[$(Get-Date -Format s)] START worker SaveDir=$SaveDir" | Tee-Object -FilePath $psLog -Append
& matlab -batch "run_blockC_batched_background_entry_v72" -logfile $matLog
$exitCode = $LASTEXITCODE
"[$(Get-Date -Format s)] MATLAB exit=$exitCode" | Tee-Object -FilePath $psLog -Append

$merged = Join-Path $SaveDir "BlockC_Endogenous_Aware_Merged.csv"
if (Test-Path $merged) {
    "[$(Get-Date -Format s)] Merged CSV exists: $merged" | Tee-Object -FilePath $psLog -Append
    exit 0
}
exit $exitCode
