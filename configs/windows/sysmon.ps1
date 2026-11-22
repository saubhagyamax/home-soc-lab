# Installs Sysmon with the sysmon-modular default config. Run as Administrator.
# sysmon-modular publishes built configs as release assets (not in the repo tree) with a SHA256SUMS file.
# Update $release and $expect from https://github.com/olafhartong/sysmon-modular/releases/latest
$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"
$release = "configs-a45dedb13a43"
$expect  = "64BEC37BA849C5F2934A55D2A29E7DDFAE46A30D56F7F2908D1F8A454898797E"
$d = "C:\Tools\Sysmon"; New-Item -ItemType Directory $d -Force | Out-Null; Set-Location $d
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile Sysmon.zip -UseBasicParsing
Expand-Archive Sysmon.zip -DestinationPath $d -Force
$sig = Get-AuthenticodeSignature .\Sysmon64.exe
if ($sig.Status -ne "Valid" -or $sig.SignerCertificate.Subject -notmatch "Microsoft") { throw "Sysmon64.exe signature check failed" }
Invoke-WebRequest "https://github.com/olafhartong/sysmon-modular/releases/download/$release/sysmonconfig.xml" -OutFile sysmonconfig.xml -UseBasicParsing
if ((Get-FileHash .\sysmonconfig.xml).Hash -ne $expect) { throw "sysmonconfig.xml checksum mismatch" }
& .\Sysmon64.exe -accepteula -i sysmonconfig.xml
