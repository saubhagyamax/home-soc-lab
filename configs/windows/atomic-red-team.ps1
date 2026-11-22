# Installs Invoke-AtomicRedTeam and the atomics, with a Defender exclusion for C:\AtomicRedTeam only.
# Set the machine execution policy to RemoteSigned first, or the all-users profile will not load.
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory C:\AtomicRedTeam -Force | Out-Null
Add-MpPreference -ExclusionPath "C:\AtomicRedTeam"
Write-Output "Defender exclusions: $((Get-MpPreference).ExclusionPath -join ', ')"
Write-Output "Defender real-time protection on: $(-not (Get-MpPreference).DisableRealtimeMonitoring)"
Set-ExecutionPolicy Bypass -Scope Process -Force
IEX (IWR "https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1" -UseBasicParsing)
Install-AtomicRedTeam -getAtomics -Force
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
Write-Output "Invoke-AtomicRedTeam version: $((Get-Module Invoke-AtomicRedTeam).Version)"
Write-Output "atomics folders: $((Get-ChildItem C:\AtomicRedTeam\atomics -Directory).Count)"
# Load the module automatically in every PowerShell session
$profileLine = 'Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force; $PSDefaultParameterValues = @{"Invoke-AtomicTest:PathToAtomicsFolder"="C:\AtomicRedTeam\atomics"}'
New-Item -ItemType File -Path $PROFILE.AllUsersAllHosts -Force | Out-Null
Set-Content -Path $PROFILE.AllUsersAllHosts -Value $profileLine
Write-Output "profile: $($PROFILE.AllUsersAllHosts)"
