#!/bin/bash
# Repack stock boot.img with a custom kernel, optionally with Magisk.
#
# Usage: repack-boot.sh <magisk-dir> <kernel> <stock-boot> <output> [--magisk]
#
# magisk-dir is an extracted Magisk APK (contains lib/ and assets/).
# --magisk patches Magisk root into the boot image.

set -euo pipefail

MAGISK_DIR="$(realpath "$1")"
KERNEL="$(realpath "$2")"
STOCK_BOOT="$(realpath "$3")"
OUTPUT="$(realpath -m "$4")"
PATCH_MAGISK=false

[ "${5:-}" = "--magisk" ] && PATCH_MAGISK=true

MAGISKBOOT="$MAGISK_DIR/lib/x86_64/libmagiskboot.so"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

"$MAGISKBOOT" unpack "$STOCK_BOOT"
cp "$KERNEL" kernel

if $PATCH_MAGISK; then
  cp ramdisk.cpio ramdisk.cpio.orig
  cp "$MAGISK_DIR/lib/arm64-v8a/libmagiskinit.so" magiskinit
  cp "$MAGISK_DIR/lib/arm64-v8a/libmagisk.so" magisk
  cp "$MAGISK_DIR/lib/arm64-v8a/libinit-ld.so" init-ld
  cp "$MAGISK_DIR/assets/stub.apk" stub.apk

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
