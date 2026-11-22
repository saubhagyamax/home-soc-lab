#!/bin/sh
# Creates the wazuh VM (ID 100) on the Proxmox host from the Ubuntu 24.04 cloud image.
# Run as root on the Proxmox host. Needs:
#   - /root/homelab_ed25519.pub (the Mac's lab SSH key)
#   - cloud-init-vendor.yaml copied to /var/lib/vz/snippets/wazuh-vendor.yaml
#   - snippets enabled on local storage: pvesm set local --content backup,vztmpl,iso,import,snippets
set -e
IMG=/mnt/pve/hdd/cloud-images/noble-server-cloudimg-amd64.img
BASE=https://cloud-images.ubuntu.com/noble/current

# Fetch and verify the cloud image
mkdir -p "$(dirname "$IMG")" && cd "$(dirname "$IMG")"
wget -q -O SHA256SUMS "$BASE/SHA256SUMS"
wget -q -O "$(basename "$IMG")" "$BASE/$(basename "$IMG")"
grep " \*$(basename "$IMG")\$" SHA256SUMS | sha256sum -c -

qm create 100 --name wazuh --ostype l26 --machine q35 --cpu host --cores 4 --memory 6144 --balloon 0 \
  --scsihw virtio-scsi-single --agent enabled=1 \
  --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1 \
  --serial0 socket --vga std --onboot 1
qm set 100 --scsi0 "local-lvm:0,import-from=$IMG,discard=on,ssd=1,iothread=1"
qm resize 100 scsi0 80G
qm set 100 --ide2 local-lvm:cloudinit --boot order=scsi0 \
  --ciuser seb --sshkeys /root/homelab_ed25519.pub \
  --ipconfig0 ip=192.168.1.60/24,gw=192.168.1.1 --ipconfig1 ip=10.10.10.10/24 \
  --nameserver 1.1.1.1 --searchdomain lab.local \
  --cicustom vendor=local:snippets/wazuh-vendor.yaml
qm start 100
