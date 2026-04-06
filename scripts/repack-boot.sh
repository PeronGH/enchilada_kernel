#!/bin/bash
# Repack stock boot.img with a custom kernel, optionally with Magisk.
#
# Usage: repack-boot.sh <kernel> <stock-boot> <output> [--magisk <magisk-dir>]
#
# magisk-dir must contain: libmagiskboot.so, libmagiskinit.so, libmagisk.so,
#                          libinit-ld.so, stub.apk
#
# Set MAGISKBOOT to override the path to magiskboot binary.

set -euo pipefail

KERNEL="$1"
STOCK_BOOT="$2"
OUTPUT="$3"
MAGISK_DIR=""

if [ "${4:-}" = "--magisk" ]; then
  MAGISK_DIR="$5"
fi

# Find magiskboot: explicit env, magisk-dir, or PATH
if [ -z "${MAGISKBOOT:-}" ]; then
  if [ -n "$MAGISK_DIR" ] && [ -x "$MAGISK_DIR/libmagiskboot.so" ]; then
    MAGISKBOOT="$MAGISK_DIR/libmagiskboot.so"
  else
    MAGISKBOOT="magiskboot"
  fi
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

"$MAGISKBOOT" unpack "$STOCK_BOOT"
cp "$KERNEL" kernel

if [ -n "$MAGISK_DIR" ]; then
  cp ramdisk.cpio ramdisk.cpio.orig
  cp "$MAGISK_DIR/libmagiskinit.so" magiskinit
  cp "$MAGISK_DIR/libmagisk.so" magisk
  cp "$MAGISK_DIR/libinit-ld.so" init-ld
  cp "$MAGISK_DIR/stub.apk" stub.apk

  "$MAGISKBOOT" compress=xz magisk magisk.xz
  "$MAGISKBOOT" compress=xz stub.apk stub.xz
  "$MAGISKBOOT" compress=xz init-ld init-ld.xz

  cat > config <<EOF
KEEPVERITY=false
KEEPFORCEENCRYPT=false
RECOVERYMODE=false
VENDORBOOT=false
SHA1=$("$MAGISKBOOT" sha1 "$STOCK_BOOT")
EOF

  "$MAGISKBOOT" cpio ramdisk.cpio \
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

"$MAGISKBOOT" repack "$STOCK_BOOT" "$OUTPUT"
