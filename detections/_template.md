# TXXXX.XXX: Technique name

## Technique
ATT&CK ID, tactic, and one line on what an attacker gains.

## Simulation
```powershell
Invoke-AtomicTest TXXXX.XXX -TestNumbers N
```
Date run, host, snapshot used.

## Telemetry
Event IDs and the fields that showed the activity. Screenshot: `../screenshots/TXXXX-telemetry.png`

## Detection
```xml
<!-- rule from rules/local_rules.xml -->
```
Why each condition is there.

## Tuning
False positives seen, the exclusion added, and alert volume before and after.

## Triage (L1 analyst)
1. What to check first
2. What confirms it's malicious
3. When to escalate, and what to include
