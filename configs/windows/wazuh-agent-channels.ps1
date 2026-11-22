$ErrorActionPreference = "Stop"
$conf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
$blocks = @"

  <!-- Lab: Sysmon and PowerShell operational logs -->
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-PowerShell/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>

"@
$text = Get-Content $conf -Raw
if ($text -notmatch "Microsoft-Windows-Sysmon/Operational") {
  $i = $text.LastIndexOf("</ossec_config>")
  $text = $text.Substring(0, $i) + $blocks + $text.Substring($i)
  [IO.File]::WriteAllText($conf, $text)
}
[xml](Get-Content $conf -Raw) | Out-Null
Write-Output "ossec.conf valid XML"
Select-String -Path $conf -Pattern "<address>|Sysmon/Operational|PowerShell/Operational" | ForEach-Object { "  " + $_.Line.Trim() }
Start-Service WazuhSvc
Start-Sleep 15
Write-Output "WazuhSvc: $((Get-Service WazuhSvc).Status) / $((Get-Service WazuhSvc).StartType)"
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 60 | Where-Object { $_ -match "Connected|enroll|Valid key|ERROR|Analyzing event log" } | Select-Object -Last 8
