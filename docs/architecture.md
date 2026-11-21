# Architecture

## Hosts and addressing

| Machine | Role | Network | IP | vCPU / RAM / Disk |
| --- | --- | --- | --- | --- |
| Proxmox host | Hypervisor (Legion 5i) | home | 192.168.1.50 | about 1.5GB RAM reserved |
| `wazuh` | SIEM, all-in-one | home + lab | 192.168.1.60, 10.10.10.10 | 4 / 6GB / 80GB |
| `win11` | Windows victim | lab | 10.10.10.20 | 2 / 4GB / 64GB |
| `target` | Linux victim | lab | 10.10.10.30 | 1 / 1GB / 20GB |

The addresses assume a `192.168.1.0/24` home network. Adjust them if yours differs.

## Networks

- **`vmbr0`**: bridged to the Legion's Ethernet port. It has internet, and the MacBook can reach it.
- **`vmbr1`**: no physical port, so it's isolated. All attack simulation happens here.

**Install-then-isolate:** each victim VM is built on `vmbr0` so it can fetch updates and tooling. Its NIC is then moved to `vmbr1` and a `clean` snapshot is taken.

## Access from the MacBook

| Target | How |
| --- | --- |
| Proxmox UI | `https://192.168.1.50:8006` |
| Wazuh dashboard | `https://192.168.1.60` |
| Wazuh shell | `ssh wazuh` |
| Ubuntu target | `ssh target` (ProxyJump via `wazuh`) |
| Windows desktop | `ssh -N -L 3389:10.10.10.20:3389 wazuh`, then Windows App to `localhost` |

## Resource budget (16GB, fixed)

The total is about 12.5GB with everything running. Wazuh runs all the time; start only the victim under test. A Windows Server domain controller doesn't fit, so Active Directory practice happens on external platforms.

## Storage

- **256GB NVMe SSD:** Proxmox and all VM disks (`local-lvm`)
- **1TB HDD:** ISOs and backups (`hdd`)
