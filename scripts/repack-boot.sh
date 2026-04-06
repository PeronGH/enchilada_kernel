#!/bin/bash
# Repack stock boot.img with a custom kernel, optionally with Magisk.
#
# Usage: repack-boot.sh <kernel> <stock-boot> <output> [--magisk <magisk-dir>]
#
# magisk-dir must contain: libmagiskinit.so, libmagisk.so, libinit-ld.so, stub.apk

set -euo pipefail

KERNEL="$1"
STOCK_BOOT="$2"
OUTPUT="$3"
MAGISK_DIR=""

if [ "${4:-}" = "--magisk" ]; then
  MAGISK_DIR="$5"
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

magiskboot unpack "$STOCK_BOOT"
cp "$KERNEL" kernel

if [ -n "$MAGISK_DIR" ]; then
  cp ramdisk.cpio ramdisk.cpio.orig
  cp "$MAGISK_DIR/libmagiskinit.so" magiskinit
  cp "$MAGISK_DIR/libmagisk.so" magisk
  cp "$MAGISK_DIR/libinit-ld.so" init-ld
  cp "$MAGISK_DIR/stub.apk" stub.apk

  magiskboot compress=xz magisk magisk.xz
  magiskboot compress=xz stub.apk stub.xz
  magiskboot compress=xz init-ld init-ld.xz

  cat > config <<EOF
KEEPVERITY=false
KEEPFORCEENCRYPT=false
RECOVERYMODE=false
VENDORBOOT=false
SHA1=$(magiskboot sha1 "$STOCK_BOOT")
EOF

  magiskboot cpio ramdisk.cpio \
    "add 0750 init magiskinit" \
    "mkdir 0750 overlay.d" \
    "mkdir 0750 overlay.d/sbin" \
    "add 0644 overlay.d/sbin/magisk.xz magisk.xz" \
    "add 0644 overlay.d/sbin/stub.xz stub.xz" \
    "add 0644 overlay.d/sbin/init-ld.xz init-ld.xz" \
    "patch" \
    "backup ramdisk.cpio.orig" \
    "mkdir 000 .backup" \
    "add 000 .backup/.magisk config"
fi

magiskboot repack "$STOCK_BOOT" "$OUTPUT"
