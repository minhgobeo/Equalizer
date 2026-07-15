# run_blockA_hybrid_autoloop.ps1
# Auto-launches MATLAB to run Block A hybrid config, resumes on crash/interrupt.
# Does NOT touch any running MATLAB instances.
#
# Tier LOW  SNR 15-22 : 1e6 samples, 10 trials
# Tier HIGH SNR 23-30 : 1e7 samples, 100 trials
#
# Usage: .\run_blockA_hybrid_autoloop.ps1

param(
    [string]$WorkDir    = "C:\Users\DELL\Documents\MATLAB\paper_code_v72_ck_eye_split",
    [string]$SaveDir    = "paper_final_BlockA_hybrid_v72",
    [string]$MatlabExe  = "C:\Program Files\MATLAB\R2023a\bin\matlab.exe",
    [int]   $TotalSNR   = 16,
    [int]   $MaxRetries = 30,
    [int]   $RetrySleep = 20
)

$LogFile = Join-Path $WorkDir "blockA_hybrid_autoloop_log.txt"

function Write-Log {
    param([string]$Msg)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"
    Write-Host $line
    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}

function Get-DoneCount {
    $chunkRoot = Join-Path $WorkDir $SaveDir "chunks"
    if (-not (Test-Path $chunkRoot)) { return 0 }
    $mats = Get-ChildItem -Path $chunkRoot -Recurse -Filter "blockA_snr*.mat" -ErrorAction SilentlyContinue
    return $mats.Count
}

# ---- preflight --------------------------------------------------------------
if (-not (Test-Path $MatlabExe)) {
    Write-Log "ERROR: MATLAB not found at $MatlabExe"
    exit 1
}

Write-Log "=== BlockA-hybrid autoloop START | TotalSNR=$TotalSNR MaxRetries=$MaxRetries ==="
Write-Log "MATLAB : $MatlabExe"
Write-Log "WorkDir: $WorkDir"
Write-Log "SaveDir: $SaveDir"

# ---- main loop --------------------------------------------------------------
$attempt = 0

while ($true) {
    $done = Get-DoneCount
    Write-Log "Status: $done / $TotalSNR SNRs checkpointed"

    if ($done -ge $TotalSNR) {
        Write-Log "=== All $TotalSNR SNRs complete — autoloop DONE ==="
        break
    }

    if ($attempt -ge $MaxRetries) {
        Write-Log "=== Max retries ($MaxRetries) reached with $done/$TotalSNR done — stopping ==="
        break
    }

    $attempt++
    $matlabOut = Join-Path $WorkDir "matlab_blockA_attempt${attempt}_stdout.txt"
    $matlabErr = Join-Path $WorkDir "matlab_blockA_attempt${attempt}_stderr.txt"

    Write-Log "--- Attempt #$attempt: launching MATLAB (out=$matlabOut) ---"

    try {
        $proc = Start-Process `
            -FilePath    $MatlabExe `
            -ArgumentList @("-nosplash", "-nodesktop", "-batch", "run_blockA_hybrid_launcher") `
            -WorkingDirectory $WorkDir `
            -RedirectStandardOutput $matlabOut `
            -RedirectStandardError  $matlabErr `
            -Wait `
            -PassThru

        $exitCode = $proc.ExitCode
        Write-Log "MATLAB attempt #$attempt exited with code $exitCode"

        # Log last lines of MATLAB output
        if (Test-Path $matlabOut) {
            $tail = Get-Content $matlabOut -Tail 5 -ErrorAction SilentlyContinue
            if ($tail) { $tail | ForEach-Object { Write-Log "  [matlab] $_" } }
        }

        if ($exitCode -ne 0) {
            Write-Log "Non-zero exit ($exitCode) — retry in ${RetrySleep}s"
            Start-Sleep -Seconds $RetrySleep
        }
    }
    catch {
        Write-Log "Start-Process failed: $_"
        Start-Sleep -Seconds $RetrySleep
    }
}

$finalDone = Get-DoneCount
Write-Log "=== autoloop END: $finalDone / $TotalSNR SNRs checkpointed ==="
