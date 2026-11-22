# Runs Windows Update unattended. The Windows Update API refuses remote (SSH/WinRM) sessions,
# so this registers a one-off scheduled task that runs PSWindowsUpdate as SYSTEM and logs to C:\Lab\wu.log.
# Re-run Start-ScheduledTask LabWindowsUpdate after each reboot until no updates are listed.
# Reboot from inside Windows (shutdown /r) and never Stop/Reset the VM from Proxmox mid-update.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) { Install-PackageProvider NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null }
if (-not (Get-Module -ListAvailable PSWindowsUpdate)) { Install-Module PSWindowsUpdate -Force -Scope AllUsers }
New-Item -ItemType Directory C:\Lab -Force | Out-Null
$cmd = "Import-Module PSWindowsUpdate; Get-Date | Out-File C:\Lab\wu.log; Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose *>&1 | Out-File C:\Lab\wu.log -Append; 'WU-FINISHED' | Out-File C:\Lab\wu.log -Append"
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
Register-ScheduledTask -TaskName LabWindowsUpdate -Action $a -User SYSTEM -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName LabWindowsUpdate
