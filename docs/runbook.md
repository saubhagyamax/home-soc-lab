# Build runbook

The step-by-step build, from an untouched Windows laptop to a working home SOC. It's paired with the checklist in [plan.md](plan.md).

**Assumptions:**
- The home network is `192.168.1.0/24`. Phase 0 step 3 checks this; if it differs, swap the prefix everywhere.
- RAM is 16GB and can't be upgraded.

| Machine | Role | IP | vCPU / RAM / Disk |
| --- | --- | --- | --- |
| Proxmox host | Hypervisor | 192.168.1.50 | about 1.5GB RAM |
| `wazuh` | SIEM (all-in-one) | 192.168.1.60 + 10.10.10.10 | 4 / 6GB / 80GB |
| `win11` | Windows victim | 10.10.10.20 | 2 / 4GB / 64GB |
| `target` | Linux victim | 10.10.10.30 | 1 / 1GB / 20GB |

---

## Phase 0: Prep before wiping (about 45 min)

1. **Back up Windows on the Legion:** Desktop, Documents, Downloads, photos and game saves. Windows apps (OBS, games) won't run after this.
2. **RAM is fixed at 16GB.** Every VM size below fits inside it; the budget is in Phase 5.
3. **Home subnet:** at home, run `ipconfig getifaddr en0` on the Mac. Reserve two free addresses outside the router's DHCP range (`.50`, `.60`).
4. **Downloads (on the Mac):**
    - Proxmox VE ISO (latest), from proxmox.com → Downloads
    - balenaEtcher
    - Windows 11 **Enterprise** evaluation ISO, from the Microsoft Evaluation Center. Choose ISO, **x64** (not ARM64, not LTSC), English.
    - virtio-win.iso (stable): `https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso`. Alternatively, fetch it in Proxmox later with Download from URL.
5. **Flash the USB (8GB+)** with the Proxmox ISO using balenaEtcher.
6. **BIOS:** press F2 (or use the Novo button). Turn on Intel Virtualization Technology and VT-d, turn off Secure Boot, then save.
7. **Plug the Legion into the router with Ethernet.** Proxmox can't bridge over Wi-Fi. This Legion's built-in port is broken, so it uses a USB-C Ethernet adapter (ASIX AX88179A).

## Phase 1: Install Proxmox VE (about 1 hr)

**Install**

1. Press F12 at boot, pick the USB, and choose **Install Proxmox VE (Graphical)**.
2. **Target disk:** the 256GB NVMe SSD, not the 1TB HDD. Keep ext4.
3. **Location:** Australia, Australia/Melbourne, US keyboard.
4. Set the root password and email.
5. **Network:**
    - Management NIC: the wired one with a cable in it (here the USB-C adapter, `nic1`), never `wlp…`
    - Hostname: `legion.lab.local`
    - IP: `192.168.1.50/24`
    - Gateway: `192.168.1.1`
    - DNS: `1.1.1.1`
6. Install, remove the USB and reboot.
7. On the Mac, go to `https://192.168.1.50:8006` and log in as `root` (realm: Linux PAM).

**Post-install**

8. **Repositories:** go to node → Updates → Repositories. Disable both enterprise repos and add **No-Subscription**. Then Updates → Refresh → Upgrade. The subscription pop-up is harmless.
9. **Lid closed:** in `/etc/systemd/logind.conf`, set the two lines below, then run `systemctl restart systemd-logind`.

    ```
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    ```

10. **1TB HDD as storage:**
    1. Under node → Disks, select the HDD → Wipe Disk.
    2. Under Disks → Directory → Create, use ext4 and name it `hdd`.
    3. Under Datacenter → Storage → `hdd`, set Content to ISO image, VZDump backup and Container template.
11. **ISOs on `hdd`:**
    - Download from URL: Ubuntu Server 24.04 LTS and `virtio-win.iso`.
    - Upload from the Mac: the Windows 11 eval ISO.
12. **USB-C Ethernet adapter:** the adapter drops off the USB bus when the charger is plugged in, and the bridge doesn't re-add it. Install the watcher from [`configs/proxmox/`](../configs/proxmox/):
    - `vmbr0-port-watch` → `/usr/local/sbin/` (`chmod 755`)
    - `vmbr0-port-watch.service` → `/etc/systemd/system/`, then `systemctl enable --now vmbr0-port-watch`
    - `90-usb-nic-hotplug.rules` → `/etc/udev/rules.d/`, then `udevadm control --reload` (turns off USB autosuspend)
    - Test with a replug **and** a reboot. Without it, plugging in the charger drops the adapter and the host stays offline.
13. **Battery:** keep it plugged in. Optionally, if the file exists, limit charging:

    ```
    echo 1 > /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
    ```

    It resets on reboot.

VM disks live on the SSD (`local-lvm`); ISOs and backups go on the HDD.

## Phase 2: Isolated lab network (10 min)

1. Go to node → System → Network → Create → Linux Bridge.
2. Name it `vmbr1`. Leave IPv4, gateway and bridge ports **blank**. Comment: `lab-isolated`.
3. Click Apply Configuration.

- `vmbr0` = the home network, with internet; the Mac can reach it.
- `vmbr1` = the lab, `10.10.10.0/24`, with no internet; the Mac can't reach it directly.

**Install-then-isolate:** each victim is built on `vmbr0`, fully set up, then moved to `vmbr1` and snapshotted as `clean`.

**Optional later:** an OPNsense VM (1 vCPU, 1GB) with WAN on `vmbr0` and LAN on `vmbr1` at `10.10.10.1`. It costs 1GB of RAM, so only start it when a test needs internet.

## Phase 3: Wazuh SIEM VM (about 1.5 hrs)

**Create the VM (cloud image + cloud-init, no installer)**

The VM is built from Ubuntu's official 24.04 cloud image. cloud-init sets the user, SSH key, both NICs, timezone and guest agent on first boot, so there's no console install.

| Setting | Value |
| --- | --- |
| VM | ID 100, name `wazuh`, q35, CPU type `host`, 4 cores |
| Memory | 6144 MB, ballooning off |
| Disk | 80GB on `local-lvm`, Discard + SSD emulation + IO thread |
| `net0` | `vmbr0` → `eth0` `192.168.1.60/24`, gateway `192.168.1.1`, DNS `1.1.1.1` |
| `net1` | `vmbr1` → `eth1` `10.10.10.10/24` (lab, no gateway) |
| User | `seb`, key-only SSH (the Mac's `homelab_ed25519` key), passwordless sudo |

1. Copy the Mac's public key to the host: `scp ~/.ssh/homelab_ed25519.pub root@192.168.1.50:/root/`.
2. Copy [`configs/wazuh/cloud-init-vendor.yaml`](../configs/wazuh/cloud-init-vendor.yaml) to `/var/lib/vz/snippets/wazuh-vendor.yaml` and enable snippets on `local`.
3. Run [`configs/wazuh/create-vm.sh`](../configs/wazuh/create-vm.sh) on the host. It downloads and checksum-verifies the cloud image, creates the VM and starts it.
4. From the Mac: `ssh -i ~/.ssh/homelab_ed25519 seb@192.168.1.60`. Wait for `cloud-init status --wait`, then `sudo reboot` if `/var/run/reboot-required` exists.
5. Check: `ip -br a` shows both IPs, and `qm agent 100 ping` works on the host.

`cloud-init status` may say "degraded done" because of a deprecation notice about Proxmox's `user` key. It's harmless.

To set a console password for `seb` (optional, for the Proxmox console): `sudo passwd seb`.

**Install Wazuh (all-in-one)**

7. Copy the current one-liner from documentation.wazuh.com → Quickstart. For 4.14 it was `curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a`. It takes 10–20 minutes. Run it under `nohup` so a dropped SSH session can't kill it.
8. Save the printed `admin` password in a password manager.
9. **Set the indexer heap to 3GB (required on 16GB):** the 4.14 installer defaulted to 1GB, so this raises it to half the VM's RAM. Check with `ps -o args= -C java | grep -o -- -Xmx[0-9a-z]*`. in `/etc/wazuh-indexer/jvm.options`, set the lines below, then run `sudo systemctl restart wazuh-indexer`.

    ```
    -Xms3g
    -Xmx3g
    ```

10. On the Mac, open `https://192.168.1.60`. If it isn't ready, wait 2–3 minutes. Optionally change the admin password. The dashboard refuses ("Resource 'admin' is reserved"), so use `sudo bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh -u admin -p '<new>'` (special characters limited to `.*+?-`). The generated password is in `/root/wazuh-install-files.tar` (root only).
11. Take a snapshot named `wazuh-fresh`.

## Phase 4: Windows 11 victim VM (about 2 hrs)

**Create the VM**

| Tab | Setting |
| --- | --- |
| General | Name `win11` |
| OS | Win11 eval ISO, type Microsoft Windows 11, extra drive for VirtIO drivers = `virtio-win.iso` |
| System | q35, OVMF (UEFI), EFI disk + TPM v2.0 on `local-lvm`, Qemu Agent ticked |
| Disks | 64GB, VirtIO SCSI single, Discard on |
| CPU | 2 cores, type `host` |
| Memory | 4096 MB, Ballooning on, minimum 3072 MB |
| Network | `vmbr0`, VirtIO |

**Install Windows**

1. Boot from the CD.
2. When no disk is shown, Load driver → VirtIO CD → `vioscsi\w11\amd64`.
3. Load `NetKVM\w11\amd64` if asked. Choose **Domain join instead** to create the local account `labadmin`.
4. After login, run `virtio-win-guest-tools.exe` from the VirtIO CD.
5. Run Windows Update until clean. Rename the PC `WIN11-LAB`.

**Logging**

6. In `gpedit.msc`, go to Administrative Templates → Windows Components → Windows PowerShell and enable **Turn on PowerShell Script Block Logging**.
7. Under Advanced Audit Policy, enable Success + Failure for Logon/Logoff → Logon and for Object Access → Other Object Access Events.

**Sysmon**

8. Put Sysinternals Sysmon and `sysmonconfig.xml` (from olafhartong/sysmon-modular) in `C:\Tools\Sysmon`.
9. In an admin PowerShell, run `.\Sysmon64.exe -accepteula -i sysmonconfig.xml`.
10. Check Event Viewer → Microsoft → Windows → Sysmon → Operational is filling up.

**Wazuh agent**

11. In the dashboard, go to Agents → Deploy new agent → Windows, with server `10.10.10.10` and name `WIN11-LAB`. Run the generated command, then `NET START WazuhSvc`.
12. Add the `localfile` blocks from `configs/windows/ossec-localfile.xml` to `C:\Program Files (x86)\ossec-agent\ossec.conf`, then run `Restart-Service WazuhSvc`.

**Atomic Red Team**

13. In Defender, add an exclusion for `C:\AtomicRedTeam` (keep Defender on otherwise).
14. In an admin PowerShell:

    ```
    Set-ExecutionPolicy Bypass -Scope Process -Force
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
    Install-AtomicRedTeam -getAtomics
    ```

15. **While still online,** run `Invoke-AtomicTest <ID> -GetPrereqs` for T1059.001, T1053.005, T1547.001 and T1003.001.
16. Enable Remote Desktop.

**Isolate**

17. Shut down and change the NIC bridge to `vmbr1`.
18. Set a static IPv4 of `10.10.10.20/24` with no gateway.
19. Running `Test-NetConnection 10.10.10.10 -Port 1514` should give `True`, and the agent should show **Active**.
20. Take a snapshot named `clean`.

## Phase 5: Ubuntu target VM (about 45 min)

1. Create the VM: name `target`, 1 core, 1024 MB, 20GB, on `vmbr0`.
2. Install Ubuntu Server 24.04 (DHCP for now) with user `seb` and OpenSSH.
3. Run `sudo apt update && sudo apt full-upgrade -y && sudo apt install auditd qemu-guest-agent -y`.
4. Wazuh agent: in the dashboard, go to Deploy new agent → Linux DEB amd64, with server `10.10.10.10` and name `target`. Then run `sudo systemctl daemon-reload && sudo systemctl enable --now wazuh-agent`.
5. Add the audit log block from `configs/linux/ossec-localfile.xml` to `/var/ossec/etc/ossec.conf`, then run `sudo systemctl restart wazuh-agent`.
6. Shut down and move the NIC to `vmbr1`. Set netplan to `10.10.10.30/24` with no routes.
7. Confirm the agent is Active, then take a snapshot named `clean`.

**RAM budget (16GB, fixed)**

| Item | RAM |
| --- | --- |
| Proxmox host | about 1.5GB |
| `wazuh` | 6GB (indexer heap 3GB) |
| `win11` | 4GB (shrinks to 3GB) |
| `target` | 1GB |
| **Total** | **about 12.5GB** |

- Wazuh runs all the time. Start only the victim under test.
- Run OPNsense only when needed.
- If host RAM stays above 90%, shut a VM down.
- No domain controller fits, so practise Active Directory on TryHackMe or Hack The Box.

## Phase 6: MacBook control centre (20 min)

1. Run `ssh-keygen -t ed25519`, `ssh-copy-id root@192.168.1.50` and `ssh-copy-id seb@192.168.1.60`.
2. Append `configs/mac/ssh_config` to `~/.ssh/config`, then run `ssh-copy-id target`.
3. **RDP:** run `ssh -N -L 3389:10.10.10.20:3389 wazuh`, then use the Windows App to connect to `localhost` as `labadmin`.
4. **Bookmarks:** `https://192.168.1.50:8006` and `https://192.168.1.60`.
5. **End-to-end test:** run `ssh target`, then `ssh fakeuser@localhost` with a wrong password 6–8 times. An alert should appear in Wazuh within a minute.

## Phase 7: Attack, detect, tune (weeks 1–3)

**The loop, per technique:**

1. Run `Invoke-AtomicTest <ID> -ShowDetailsBrief` and pick a test.
2. Run it with `Invoke-AtomicTest <ID> -TestNumbers N`.
3. Check Wazuh Threat Hunting, filtered to the agent, for the last 15 minutes.
4. If nothing fired, find the raw event in Discover and write a rule in `rules/local_rules.xml`.
5. If it's noisy, add a level-0 child rule for the legitimate process. Record alert volume before and after.
6. Save a screenshot and the raw event JSON.
7. Clean up with `-Cleanup`, or roll back to `clean`.

**Custom rules:**
- They go in `/var/ossec/etc/rules/local_rules.xml`, with IDs 100000–120000.
- Always test with `/var/ossec/bin/wazuh-logtest`, then `sudo systemctl restart wazuh-manager`.
- The draft LSASS rule 100100 is untested. If logtest shows no match, swap `<if_group>windows</if_group>` for the parent Sysmon rule ID (`<if_sid>`).

**Starter techniques:** see [detections/README.md](../detections/README.md).

## Phase 8: Write-ups

Use `detections/_template.md` for each one. Aim for about 8 in 3 weeks, then start the Sentinel/KQL project.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Host drops off the network when the charger is plugged in | USB-C adapter re-registers and isn't re-added to `vmbr0` | Run `ifreload -a` on the console; install the watcher service (Phase 1 step 12) |
| No network after Proxmox install | Wi-Fi NIC picked | Set `bridge-ports` on `vmbr0` in `/etc/network/interfaces` to the Ethernet NIC, then `ifreload -a` |
| Windows installer shows no disk | VirtIO SCSI driver missing | Load `vioscsi\w11\amd64` |
| Agent never connects | Can't reach 10.10.10.10:1514/1515 | `Test-NetConnection`; check bridges and IPs |
| Dashboard not ready | Indexer starting or out of memory | Wait 3 min; `systemctl status wazuh-indexer`; check heap is 3g |
| No Sysmon events | `localfile` missing | Recheck `ossec.conf`, restart the agent |
| Atomic test fails offline | Prereqs missing | Roll back, move to `vmbr0`, `-GetPrereqs`, move back, re-snapshot |
| Laptop sleeps when the lid closes | logind change not applied | Recheck both lines, restart logind |
| VMs freezing | RAM exhausted | Run only Wazuh + one victim |
