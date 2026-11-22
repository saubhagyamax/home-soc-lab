# Build log

Newest first. One entry per session: what was done, what broke, what was learned.

## 2026-11-22
- Diagnosed the failed replug: the adapter appears as `eth0` and is renamed to `nic1` a moment later, and udev can't reliably act on the final name or wait for it.
- **Fix v3:** moved the re-attach out of udev into `vmbr0-port-watch.service`, which listens to `ip monitor link` and re-attaches `nic1` to `vmbr0` whenever it's missing from the bridge. udev now only turns off USB autosuspend.
- Tests passed: simulated detach (re-attached instantly), reboot (back in about 57s), real replug (re-attached in the same second as the adapter came back).
- Phase 1 done.
- Created `vmbr1` (no physical port, no IP, comment `lab-isolated`). `vmbr0` unaffected. Phase 2 done (OPNsense still deferred).
- Built the `wazuh` VM from the Ubuntu 24.04 cloud image (checksum verified) with cloud-init instead of the installer: both NICs, user, SSH key and guest agent set on first boot. SSH was up 16s after start.
- Installed Wazuh 4.14.10 all-in-one with the Quickstart script (about 7 min). Raised the indexer heap from the installer's 1GB default to 3GB. All four services active; dashboard reachable from the Mac.
- Kept the generated admin password. The dashboard can't change `admin` ("Resource 'admin' is reserved"); the password tool is the way if needed.
- Snapshot `wazuh-fresh` taken. Thin pool shows an overprovisioning warning (160GB promised vs 141GB pool) but real use is 14%.
- Phase 3 done.

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
- **Broke again:** the first rule ran `systemd-run ifreload` from udev. After a reboot it blocked udev, `ifupdown2-pre` timed out and `vmbr0` was never created. Recovered from the console (moved the rule aside, `systemctl restart networking`).
- **Fix v2:** udev now calls a small script that only runs `ip link set nic1 master vmbr0 up`, and only if `vmbr0` already exists. Reboot test passed (back in about 49s). **Replug test failed:** the adapter did not rejoin `vmbr0` after a hot replug. Not yet diagnosed.
- **Learned:** a Linux bridge doesn't re-add a hot-plugged port; check `bridge link` when a host has an IP but no traffic. Never call systemd or ifupdown from a udev rule, and test boot-time changes with a reboot.
- Loaded ISOs on `hdd`: Ubuntu Server 24.04.5 (SHA-256 verified by Proxmox), Windows 11 eval (hash matches the Mac copy) and virtio-win.
