# Installs OpenSSH Server from Microsoft's GitHub MSI (checksum-pinned) for remote management.
# Do NOT use Add-WindowsCapability as well: if it is started and cancelled, Windows finishes it
# on the next update reboot, takes over the sshd service name and leaves no working service.
# Replace the key below with your own public key.
$ErrorActionPreference = 'Stop'
Start-Transcript -Path C:\setup-ssh2.log -Force | Out-Null
$url  = 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.4.0.0p1-Preview/OpenSSH-Win64-v10.4.0.0.msi'
$hash = '788D8643464A01EB63640A2FD746F9ED23D106B5A901A35F88DC8CD40E446AC9'
$msi  = "$env:TEMP\OpenSSH-Win64.msi"
Write-Host "Downloading OpenSSH MSI..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
if ((Get-FileHash $msi -Algorithm SHA256).Hash -ne $hash) { throw "Checksum mismatch, not installing." }
Write-Host "Checksum OK. Installing..." -ForegroundColor Cyan
$p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" ADDLOCAL=Server /qn /norestart" -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "msiexec failed with exit code $($p.ExitCode)" }
Set-Service sshd -StartupType Automatic
Start-Service sshd
if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}
$keyFile = 'C:\ProgramData\ssh\administrators_authorized_keys'
Set-Content -Path $keyFile -Value 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDWGmrv1Zim0guWzki9NyqaMl352mSxi9w1z/k3ItjK mac-homelab' -Encoding ascii
icacls.exe $keyFile /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force | Out-Null
Restart-Service sshd
$ga = Get-Service -Name 'QEMU-GA' -ErrorAction SilentlyContinue
if ($ga) { Set-Service QEMU-GA -StartupType Automatic; Start-Service QEMU-GA }
Write-Host "sshd: $((Get-Service sshd).Status)   QEMU-GA: $(if ($ga) { (Get-Service QEMU-GA).Status } else { 'not installed' })" -ForegroundColor Green
Write-Host "DONE. You can close this window." -ForegroundColor Green
Stop-Transcript | Out-Null
