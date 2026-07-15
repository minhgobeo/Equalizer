Set-Location -LiteralPath "C:\Users\DELL\Documents\MATLAB\paper_code_v72_ck_eye_split"
$matlab = "C:\Program Files\MATLAB\R2023a\bin\matlab.exe"
$log = "C:\Users\DELL\Documents\MATLAB\paper_code_v72_ck_eye_split\paper_final_overnight_v72\matlab_launcher.log"
& $matlab -batch "run_final_overnight_start" *> $log
