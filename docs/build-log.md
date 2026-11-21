# Build log

Newest first. One entry per session: what was done, what broke, what was learned.

## 2026-11-21
- Planned the lab: Proxmox on the Legion 5i, Wazuh SIEM, Windows 11 and Ubuntu victims on an isolated bridge.
- Confirmed the RAM is fixed at 16GB and sized the VMs to fit (about 12.5GB in total, indexer heap capped).
- Chose Windows 11 Enterprise evaluation (x64) over LTSC.
- Started Phase 0: downloaded Proxmox VE 9.2 (SHA-256 verified), balenaEtcher 2.1.9 and virtio-win 0.1.302.
- Downloaded the Windows 11 Enterprise evaluation ISO (x64, build 26300) and flashed the Proxmox USB (32GB).
- Confirmed the home subnet is 192.168.1.0/24 (router .1); .50 and .60 were free.
- Wiped Windows, enabled VT-x/VT-d, disabled Secure Boot and installed Proxmox VE 9.2 on the SSD at 192.168.1.50. Web UI reachable from the Mac.
- Switched to the no-subscription repo and upgraded to 9.2.32; lid close ignored; 1TB HDD wiped and added as `hdd`.
- **Broke:** plugging in the charger dropped the USB-C Ethernet adapter off the USB bus. It came back as `nic1` but wasn't re-added to `vmbr0`, so the host went offline. `ifreload -a` on the console fixed it.
- **Fix:** a udev rule re-runs `ifreload -a` whenever the adapter re-registers and turns off USB autosuspend for it. Tested by unplugging and replugging the adapter: the host recovered on its own.
- **Learned:** a Linux bridge doesn't re-add a hot-plugged port. Check `bridge link` when a host has an IP but no traffic.
- Loaded ISOs on `hdd`: Ubuntu Server 24.04.5 (SHA-256 verified by Proxmox), Windows 11 eval (hash matches the Mac copy) and virtio-win.
