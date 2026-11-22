# Wazuh indexer heap (16GB host)

In `/etc/wazuh-indexer/jvm.options`, set the heap to half the VM's 6GB. The 4.14 installer defaults to 1GB:

```
-Xms3g
-Xmx3g
```

Then run `sudo systemctl restart wazuh-indexer`.
