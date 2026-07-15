param(
    [string]$RootDir = "paper_quick_BlockB_10trials_3baud_bt1_until_done_v72",
    [string]$Profiles = "slow,medium,fast",
    [string]$SnrList = "15:30",
    [int]$Trials = 10,
    [int]$Samples = 80000,
    [int]$TrainLen = 12000,
    [int]$MaxRetries = 8,
    [double[]]$BaudGBd = @(26.5625, 53.125)
)

$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

New-Item -ItemType Directory -Force -Path $RootDir | Out-Null
$masterLog = Join-Path $RootDir "blockB_quick_3baud_until_done_master.log"

function Expand-SnrList([string]$Text) {
    if ($Text -match "^\s*(\d+)\s*:\s*(\d+)\s*$") {
        return @([int]$Matches[1]..[int]$Matches[2])
    }
    return @($Text.Split(",") | ForEach-Object { [int]($_.Trim()) })
}

function BaudFolder([double]$baud) {
    $s = ("baud{0}GBd" -f $baud).Replace(".", "p")
    return $s
}

function Count-DoneChunks([string]$dir, [string[]]$profiles, [int[]]$snrs) {
    $count = 0
    foreach ($profile in $profiles) {
        foreach ($snr in $snrs) {
            $csv = Join-Path $dir ("tmp_{0}_snr{1:D2}\ieee8023ck_markov_sweep_summary.csv" -f $profile, $snr)
            if (Test-Path $csv) { $count++ }
        }
    }
    return $count
}

$profileItems = @($Profiles.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$snrItems = Expand-SnrList $SnrList
$targetChunks = $profileItems.Count * $snrItems.Count

"[$(Get-Date -Format s)] START quick Block B 802.3ck 2-baud until-done" | Tee-Object -FilePath $masterLog -Append
"RootDir=$RootDir Profiles=$($profileItems -join ',') SNR=$($snrItems -join ',') Trials=$Trials Samples=$Samples TrainLen=$TrainLen BaudGBd=$($BaudGBd -join ',')" | Tee-Object -FilePath $masterLog -Append

foreach ($baud in $BaudGBd) {
    $baudDir = Join-Path $RootDir (BaudFolder $baud)
    New-Item -ItemType Directory -Force -Path $baudDir | Out-Null
    "[$(Get-Date -Format s)] BAUD $baud GBd -> $baudDir" | Tee-Object -FilePath $masterLog -Append

    $round = 0
    while ((Count-DoneChunks $baudDir $profileItems $snrItems) -lt $targetChunks) {
        $round++
        $done = Count-DoneChunks $baudDir $profileItems $snrItems
        "[$(Get-Date -Format s)] BAUD $baud round=$round done=$done/$targetChunks" | Tee-Object -FilePath $masterLog -Append

        powershell -ExecutionPolicy Bypass -File .\run_blockB_100trials_background_v72.ps1 `
            -SaveDir $baudDir `
            -Profiles ($profileItems -join ",") `
            -SnrList $SnrList `
            -Trials $Trials `
            -Samples $Samples `
            -TrainLen $TrainLen `
            -BatchTrials 1 `
            -MaxRetries $MaxRetries `
            -BaudGBd $baud

        $exitCode = $LASTEXITCODE
        $doneAfter = Count-DoneChunks $baudDir $profileItems $snrItems
        "[$(Get-Date -Format s)] BAUD $baud round=$round exit=$exitCode done=$doneAfter/$targetChunks" | Tee-Object -FilePath $masterLog -Append

        if ($doneAfter -eq $done -and $exitCode -ne 0) {
            "[$(Get-Date -Format s)] BAUD $baud no progress in this round; sleeping 60s then retrying" | Tee-Object -FilePath $masterLog -Append
            Start-Sleep -Seconds 60
        }
    }
    "[$(Get-Date -Format s)] COMPLETE BAUD $baud GBd" | Tee-Object -FilePath $masterLog -Append
}

"[$(Get-Date -Format s)] COMPLETE quick Block B 802.3ck 2-baud until-done" | Tee-Object -FilePath $masterLog -Append
