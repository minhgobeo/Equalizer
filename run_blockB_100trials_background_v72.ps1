param(
    [string]$SaveDir = "paper_final_blockB_100trials_v72",
    [string]$Profiles = "slow,medium,fast",
    [string]$SnrList = "15:30",
    [int]$Trials = 100,
    [int]$Samples = 80000,
    [int]$TrainLen = 12000,
    [int]$BatchTrials = 1,
    [int]$MaxRetries = 5,
    [double]$BaudGBd = 26.5625
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$logDir = Join-Path $SaveDir "_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Expand-SnrList([string]$Text) {
    if ($Text -match "^\s*(\d+)\s*:\s*(\d+)\s*$") {
        $a = [int]$Matches[1]
        $b = [int]$Matches[2]
        return @($a..$b)
    }
    return @($Text.Split(",") | ForEach-Object { [int]($_.Trim()) })
}

$profileItems = @($Profiles.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$snrItems = Expand-SnrList $SnrList
$masterLog = Join-Path $logDir "blockB_100trials_master.log"

"[$(Get-Date -Format s)] START Block B 100-trial run" | Tee-Object -FilePath $masterLog -Append
$baudHz = $BaudGBd * 1e9
"SaveDir=$SaveDir Profiles=$($profileItems -join ',') SNR=$($snrItems -join ',') Trials=$Trials Samples=$Samples TrainLen=$TrainLen BatchTrials=$BatchTrials MaxRetries=$MaxRetries BaudGBd=$BaudGBd" | Tee-Object -FilePath $masterLog -Append

foreach ($profile in $profileItems) {
    foreach ($snr in $snrItems) {
        $chunkLog = Join-Path $logDir ("chunk_{0}_snr{1}.log" -f $profile, $snr)
        $chunkCsv = Join-Path $SaveDir ("tmp_{0}_snr{1:D2}\ieee8023ck_markov_sweep_summary.csv" -f $profile, $snr)
        "[$(Get-Date -Format s)] RUN profile=$profile snr=$snr" | Tee-Object -FilePath $masterLog -Append
        if (-not (Test-Path $chunkCsv)) {
            $numBatches = [Math]::Ceiling($Trials / $BatchTrials)
            for ($bi = 1; $bi -le $numBatches; $bi++) {
                $batchCsv = Join-Path $SaveDir ("_batches_{0}_snr{1:D2}\batch{2:D3}\ieee8023ck_markov_sweep_summary.csv" -f $profile, $snr, $bi)
                if (Test-Path $batchCsv) {
                    "[$(Get-Date -Format s)] RESUME batch profile=$profile snr=$snr batch=$bi/$numBatches" | Tee-Object -FilePath $masterLog -Append
                    continue
                }
                $batchLog = Join-Path $logDir ("batch_{0}_snr{1}_b{2:D3}.log" -f $profile, $snr, $bi)
                $batchCmd = "run_blockB_100trials_onebatch_v72('$profile',$snr,$bi,'save_dir','$SaveDir','batch_trials',$BatchTrials,'samples',$Samples,'trainLen',$TrainLen,'baud',$baudHz);"
                for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
                    "[$(Get-Date -Format s)] RUN batch profile=$profile snr=$snr batch=$bi/$numBatches attempt=$attempt/$MaxRetries" | Tee-Object -FilePath $masterLog -Append
                    & matlab -wait -batch $batchCmd -logfile $batchLog
                    if (Test-Path $batchCsv) {
                        if ($LASTEXITCODE -ne 0) {
                            "[$(Get-Date -Format s)] WARN batch profile=$profile snr=$snr batch=$bi exit=$LASTEXITCODE but CSV exists; accepting" | Tee-Object -FilePath $masterLog -Append
                        }
                        break
                    }
                    "[$(Get-Date -Format s)] WARN batch profile=$profile snr=$snr batch=$bi attempt=$attempt failed exit=$LASTEXITCODE; CSV missing" | Tee-Object -FilePath $masterLog -Append
                    if ($attempt -eq $MaxRetries) {
                        "[$(Get-Date -Format s)] FAIL batch profile=$profile snr=$snr batch=$bi after $MaxRetries attempts" | Tee-Object -FilePath $masterLog -Append
                        exit $LASTEXITCODE
                    }
                }
            }
        }
        $mergeChunkLog = Join-Path $logDir ("merge_{0}_snr{1}.log" -f $profile, $snr)
        $mergeChunkCmd = "merge_blockB_100trials_chunk_v72('$profile',$snr,'save_dir','$SaveDir','trials',$Trials,'batch_trials',$BatchTrials,'samples',$Samples,'trainLen',$TrainLen,'baud',$baudHz);"
        & matlab -wait -batch $mergeChunkCmd -logfile $mergeChunkLog
        if ($LASTEXITCODE -ne 0 -and -not (Test-Path $chunkCsv)) {
            "[$(Get-Date -Format s)] FAIL merge profile=$profile snr=$snr exit=$LASTEXITCODE and CSV missing" | Tee-Object -FilePath $masterLog -Append
            exit $LASTEXITCODE
        }
        "[$(Get-Date -Format s)] DONE profile=$profile snr=$snr" | Tee-Object -FilePath $masterLog -Append
    }
}

$mergeLog = Join-Path $logDir "merge_and_plot.log"
$profileCell = "{'" + ($profileItems -join "','") + "'}"
$snrMat = "[" + ($snrItems -join " ") + "]"
$mergeCmd = "addpath(genpath(pwd)); out=run_blockB_tracking_stress_all_recursions_v72('snr',$snrMat,'profiles',$profileCell,'trials',$Trials,'samples',$Samples,'trainLen',$TrainLen,'baud',$baudHz,'save_dir','$SaveDir','fig_visible','off','resume',true); save(fullfile('$SaveDir','BlockB_100trials_FinalMerged.mat'),'out','-v7.3');"
"[$(Get-Date -Format s)] MERGE/PLOT" | Tee-Object -FilePath $masterLog -Append
& matlab -wait -batch $mergeCmd -logfile $mergeLog
if ($LASTEXITCODE -ne 0) {
    $mergedCsv = Join-Path $SaveDir "BlockB_TrackingStress_AllRecursions_LongTable.csv"
    if (Test-Path $mergedCsv) {
        "[$(Get-Date -Format s)] MERGE WARN exit=$LASTEXITCODE but merged CSV exists; accepting final merge" | Tee-Object -FilePath $masterLog -Append
    } else {
        "[$(Get-Date -Format s)] MERGE FAIL exit=$LASTEXITCODE and merged CSV missing" | Tee-Object -FilePath $masterLog -Append
        exit $LASTEXITCODE
    }
}

"[$(Get-Date -Format s)] COMPLETE Block B 100-trial run" | Tee-Object -FilePath $masterLog -Append
