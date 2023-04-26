#!/bin/bash
set -e
cd "$(dirname "$0")"

USER_DISK_IMAGE=user-data.qcow2
QEMU_ARGS=(\
  -smp 4
)

ALPINE_VERSION=3.13.4
# ALPINE_IMG_FILE=alpine-virt-$ALPINE_VERSION-aarch64.iso
ALPINE_IMG_FILE=alpine-standard-$ALPINE_VERSION-aarch64.iso
ALPINE_IMG_URL=https://dl-cdn.alpinelinux.org/alpine
ALPINE_IMG_URL=$ALPINE_IMG_URL/v${ALPINE_VERSION%.*}/releases/aarch64/$ALPINE_IMG_FILE

INSTALL=
if [ "$1" = "install" ]; then INSTALL=1; shift; fi

if [ ! -f "$USER_DISK_IMAGE" ]; then
  if [ -f user-data-init.qcow2 ]; then
    cp -v user-data-init.qcow2 "$USER_DISK_IMAGE"
  else
    echo "Missing user-data-init.qcow2 -- making new blank image" >&2
    qemu-img create -f qcow2 -o compression_type=zlib "$USER_DISK_IMAGE" 64G
    INSTALL=1
  fi
  chmod 0600 "$USER_DISK_IMAGE"
fi

if [ -n "$INSTALL" ]; then
  if ! [ -f $ALPINE_IMG_FILE ]; then
    echo "downloading $ALPINE_IMG_URL"
    curl -L --progress-bar -O "$ALPINE_IMG_URL"
  fi
  rm -f tmp.qcow2
  qemu-img create -f qcow2 -o compression_type=zlib tmp.qcow2 64G
  QEMU_ARGS+=( \
    -cdrom "$ALPINE_IMG_FILE" \
    -drive "if=virtio,file=tmp.qcow2" \
  )
fi

case "$(uname -m)" in
arm64)
  QEMU_ARGS+=( \
    -cpu host \
    -accel hvf \
  ) ;;
*)
  QEMU_ARGS+=( \
    -cpu cortex-a72 \
  ) ;;
esac

# [ -f QEMU_EFI.fd ] ||
#   wget http://releases.linaro.org/components/kernel/uefi-linaro/16.02/release/qemu64/QEMU_EFI.fd

# echo "You can connect to the QEMU monitor at $PWD/monitor.sock like this:"
# echo "  rlwrap socat -,echo=0,icanon=0 unix-connect:monitor.sock"

# first argument to this script is an optional vm snapshot to start from
[ -z "$1" ] || QEMU_ARGS+=( -loadvm "$1" )

exec qemu-system-aarch64 \
  -M virt \
  -m 2048 \
  -rtc base=utc,clock=host,driftfix=slew \
  \
  -bios QEMU_EFI.fd \
  \
  -device virtio-rng-pci \
  -device virtio-balloon \
  -nographic \
  -no-reboot \
  -serial mon:stdio \
  \
  -drive "if=virtio,file=$USER_DISK_IMAGE" \
  \
  -monitor "unix:monitor.sock,server,nowait" \
  \
  -netdev "user,id=net1,hostfwd=tcp:127.0.0.1:10022-:22" \
  -device "virtio-net-pci,netdev=net1" \
  \
  "${QEMU_ARGS[@]}"
