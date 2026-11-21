# Design decisions

Short records of why the lab is built the way it is.

## 001: Blue team first
**Decision:** Focus the lab on defensive and SOC work, not offensive or pentesting.
**Why:** The target role is SOC analyst. Attack simulation is used only to generate telemetry for detections.

## 002: Wipe Windows and dedicate the laptop
**Decision:** Erase Windows on the Legion 5i instead of dual booting.
**Why:** The lab stays always-on and headless, uses the whole disk, and avoids boot-loader problems.

## 003: Proxmox VE on bare metal
**Decision:** Use Proxmox VE as the hypervisor.
**Why:** It gives snapshots for instant rollback after each attack, isolated software bridges, a web UI managed from the MacBook, and the same tooling real labs use.

## 004: Wazuh as the SIEM
**Decision:** Use Wazuh all-in-one.
**Why:** It's free, has native Windows, Sysmon and Linux agents, and supports custom XML rules with MITRE ATT&CK mapping. It fits on one 6GB VM.

## 005: Windows 11 Enterprise evaluation, not LTSC
**Decision:** Use the standard Enterprise evaluation (x64).
**Why:** It matches the endpoints corporate SOCs monitor, and includes Group Policy and advanced auditing, which Home lacks. LTSC is a niche edition. The 90-day expiry is handled by rebuilding from these docs.

## 006: Work within 16GB RAM (fixed)
**Decision:** Size the VMs to about 12.5GB in total and cap the Wazuh indexer heap at 3GB.
**Why:** The Legion's RAM can't be upgraded. Only one victim VM runs at a time, and Active Directory practice is done externally.

## 007: Isolated attack network
**Decision:** Victims live on `vmbr1`, with no route to the home network.
**Why:** Atomic Red Team tests must never touch real devices. Wazuh is dual-homed so it can still be reached.
