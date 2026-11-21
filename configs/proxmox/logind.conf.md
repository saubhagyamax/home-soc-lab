# Keep the Legion running with the lid closed

In `/etc/systemd/logind.conf`:

```
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
```

Then run `systemctl restart systemd-logind`.
