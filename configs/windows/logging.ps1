# Enables the Windows logging the lab's detections rely on. Run as Administrator.
# PowerShell Script Block Logging (same as the gpedit policy)
$k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
New-Item $k -Force | Out-Null
Set-ItemProperty $k -Name EnableScriptBlockLogging -Value 1 -Type DWord
# Advanced audit policy, by GUID so it works in any display language
auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable   # Logon
auditpol /set /subcategory:"{0CCE9227-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable   # Other Object Access Events
# Let subcategory settings override legacy category policy
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name SCENoApplyLegacyAuditPolicy -Value 1 -Type DWord
