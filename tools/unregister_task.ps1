chcp 65001 > $null
$n='청산도수산_정책자금_일일갱신'
Unregister-ScheduledTask -TaskName $n -Confirm:$false
Write-Output "UNREGISTERED: $n"
