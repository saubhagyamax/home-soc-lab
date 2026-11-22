# Build plan

Tick items off as they're done and add a dated entry to [build-log.md](build-log.md).

## Phase 0: Prep
- [x] Back up Windows files on the Legion
- [x] Confirm the home subnet (`ipconfig getifaddr en0` on the Mac, at home) and reserve `.50` and `.60`
- [x] Download the Proxmox VE ISO and balenaEtcher
- [x] Download the Windows 11 Enterprise evaluation ISO (x64, not LTSC)
- [x] Flash the Proxmox USB
- [x] BIOS: enable VT-x and VT-d, disable Secure Boot
- [x] Legion on Ethernet

## Phase 1: Proxmox VE
- [x] Install to the 256GB SSD, static IP `192.168.1.50`
- [x] Switch to the no-subscription repo and fully upgrade
- [x] Lid close ignored (`logind.conf`)
- [x] 1TB HDD added as `hdd` storage (ISOs, backups)
- [x] ISOs loaded: Ubuntu Server 24.04, Windows 11 eval, virtio-win

## Phase 2: Lab network
- [x] `vmbr1` bridge with no physical port
- [ ] (Optional, later) OPNsense VM between `vmbr0` and `vmbr1`

## Phase 3: Wazuh
- [ ] Ubuntu Server VM: 4 vCPU, 6GB, 80GB
- [ ] Second NIC on `vmbr1` (`10.10.10.10`)
- [ ] Wazuh all-in-one installed, admin password changed
- [ ] Indexer heap capped at 3GB (`jvm.options`)
- [ ] Snapshot `wazuh-fresh`

## Phase 4: Windows 11 victim
- [ ] VM: 2 vCPU, 4GB (balloon min 3GB), 64GB, VirtIO drivers
- [ ] Windows updated, renamed `WIN11-LAB`
- [ ] PowerShell Script Block Logging and advanced audit policy on
- [ ] Sysmon installed with sysmon-modular config
- [ ] Wazuh agent with Sysmon and PowerShell channels
- [ ] Atomic Red Team installed, prereqs fetched
- [ ] Moved to `vmbr1` at `10.10.10.20`, agent Active
- [ ] Snapshot `clean`

## Phase 5: Ubuntu target
- [ ] VM: 1 vCPU, 1GB, 20GB
- [ ] auditd and Wazuh agent, audit log collected
- [ ] Moved to `vmbr1` at `10.10.10.30`, agent Active
- [ ] Snapshot `clean`

## Phase 6: MacBook control centre
- [ ] SSH keys and `~/.ssh/config` (ProxyJump through Wazuh)
- [ ] RDP tunnel to Windows working
- [ ] End-to-end test: SSH brute force on the target raises an alert

## Phase 7: Detections (target: about 8 in 3 weeks)
- [ ] T1059.001 PowerShell
- [ ] T1053.005 Scheduled task
- [ ] T1547.001 Registry Run key
- [ ] T1003.001 LSASS access
- [ ] T1110.001 SSH brute force
- [ ] T1136.001 Local account creation

## Next projects
- [ ] Microsoft Sentinel and KQL detections on the same Windows VM
- [ ] Cloud detection pipeline: Terraform, CloudTrail, GuardDuty
- [ ] Detection-as-code: Sigma rules with CI
