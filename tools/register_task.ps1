# 청산도수산 정책자금 대시보드 — 일일 자동 갱신 작업 등록 (매일 08:00)
chcp 65001 > $null
$ErrorActionPreference = 'Stop'
$taskName = '청산도수산_정책자금_일일갱신'

$action = New-ScheduledTaskAction -Execute 'wsl.exe' `
  -Argument '-d Ubuntu -e bash -lc "/home/t0106/cheongsando-susan/update.sh"'

$trigger = New-ScheduledTaskTrigger -Daily -At 8:00AM

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
  -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
  -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
  -Settings $settings -Principal $principal -Force `
  -Description '매일 오전 8시: 청산도수산 정책자금 공고를 최신화하고 GitHub/Netlify 배포 + N드라이브 저장 (WSL update.sh 실행)' | Out-Null

$t = Get-ScheduledTask -TaskName $taskName
$i = Get-ScheduledTaskInfo -TaskName $taskName
Write-Output "REGISTERED: $($t.TaskName)  state=$($t.State)"
Write-Output "NextRun: $($i.NextRunTime)"
