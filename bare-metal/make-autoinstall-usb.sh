#!/usr/bin/env bash
set -euo pipefail

###########################################
# Make Ubuntu autoinstall USB with cloud-init
# Usage: ./make-autoinstall-usb.sh /dev/sdX /path/to/iso /path/to/user-data
###########################################

DEVICE="${1:-}"
ISO="${2:-}"
USERDATA="${3:-}"

if [[ -z "$DEVICE" || -z "$ISO" || -z "$USERDATA" ]]; then
    echo "Usage: $0 /dev/sdX /path/to/ubuntu.iso /path/to/user-data"
    exit 1
fi

if [[ ! -f "$ISO" ]]; then
    echo "ERROR: ISO not found: $ISO"
    exit 1
fi

if [[ ! -f "$USERDATA" ]]; then
    echo "ERROR: user-data not found: $USERDATA"
    exit 1
fi

echo "=============================================="
echo " WARNING: This will erase EVERYTHING on $DEVICE"
echo " ISO:       $ISO"
echo " USER-DATA: $USERDATA"
echo "=============================================="
read -rp "Continue? (yes/NO): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

echo ">>> Writing ISO to USB..."
sudo dd if="$ISO" of="$DEVICE" bs=4M status=progress oflag=sync

echo ">>> Reloading partition table..."
sudo partprobe "$DEVICE"

echo ">>> Creating CIDATA partition..."
sudo parted "$DEVICE" --script mkpart CIDATA fat32 1024MiB 1100MiB || true

# Detect the new partition name (e.g. /dev/sdX2)
CIDATA_PART=$(ls "${DEVICE}"* | sort | tail -n 1)

echo ">>> Formatting CIDATA partition ($CIDATA_PART)..."
sudo mkfs.vfat -n CIDATA "$CIDATA_PART"

echo ">>> Mounting CIDATA partition..."
MNT=$(mktemp -d)
sudo mount "$CIDATA_PART" "$MNT"

echo ">>> Copying user-data and meta-data..."
sudo cp "$USERDATA" "$MNT/user-data"

# Auto-generate meta-data
HOSTNAME=$(grep -E "hostname:" "$USERDATA" | awk '{print $2}')
HOSTNAME=${HOSTNAME:-autoinstall-node}

cat <<EOF | sudo tee "$MNT/meta-data" >/dev/null
instance-id: $HOSTNAME
local-hostname: $HOSTNAME
EOF

echo ">>> Finalizing..."
sudo sync
sudo umount "$MNT"
rmdir "$MNT"

echo "=============================================="
echo " USB autoinstall drive is ready!"
echo " Boot from USB → Ubuntu installs automatically."
echo "=============================================="
