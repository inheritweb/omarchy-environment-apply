#!/bin/bash
set -euo pipefail

DATA_DIR="/data"
SHARED_DIR="/shared"
DISK="${DATA_DIR}/omarchy.qcow2"
ISO="${DATA_DIR}/installer.iso"

MEMORY="${MEMORY:-8G}"
CPUS="${CPUS:-4}"
DISK_SIZE="${DISK_SIZE:-80G}"
VM_ISO_URL="${VM_ISO_URL:-https://iso.omarchy.org/omarchy-3.8.2.iso}"

mkdir -p "$DATA_DIR" "$SHARED_DIR"

if [[ ! -f "$ISO" ]]; then
  echo "[vm] Downloading installer ISO from $VM_ISO_URL"
  rm -f "${ISO}.part"
  wget -O "${ISO}.part" "$VM_ISO_URL"
  mv "${ISO}.part" "$ISO"
fi

if [[ ! -f "$DISK" ]]; then
  echo "[vm] Creating VM disk at $DISK ($DISK_SIZE)"
  qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
  FIRST_BOOT=true
else
  FIRST_BOOT=false
fi

echo "[vm] VNC exposed on host: 127.0.0.1:5900"
if [[ "$FIRST_BOOT" == true ]]; then
  echo "[vm] First boot: Omarchy installer ISO attached. Complete installation manually via VNC."
  CDROM_OPTION=( -cdrom "$ISO" )
  BOOT_ORDER="dc"
else
  echo "[vm] Starting Omarchy from existing VM disk."
  CDROM_OPTION=()
  BOOT_ORDER="d"
fi

exec qemu-system-x86_64 \
  -m "$MEMORY" \
  -smp "$CPUS" \
  -machine q35,accel=kvm:tcg \
  -name omarchy-vm \
  -drive file="$DISK",format=qcow2 \
  "${CDROM_OPTION[@]}" \
  -boot order="$BOOT_ORDER" \
  -display vnc=:0 \
  -device VGA,edid=on,xres=1760,yres=990,vgamem_mb=32 \
  -net user,smb="$SHARED_DIR" \
  -net nic \
  -qmp unix:/data/qmp.sock,server=on,wait=off \
  -serial mon:stdio
