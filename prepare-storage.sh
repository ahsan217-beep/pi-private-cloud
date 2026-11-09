#!/usr/bin/env bash
# Create the folder layout on the USB SSD and set the ownership Nextcloud expects.
# Refuses to run unless STORAGE_ROOT sits on a mounted drive other than the SD card.
#
# Usage: sudo bash prepare-storage.sh            (reads STORAGE_ROOT from .env)
set -euo pipefail

cd "$(dirname "$0")"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: it needs to chown folders to the www-data user (uid 33)." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "No .env found. Copy .env.example to .env and fill it in first." >&2
  exit 1
fi

STORAGE_ROOT="$(grep -E '^STORAGE_ROOT=' .env | cut -d= -f2-)"
if [[ -z "$STORAGE_ROOT" ]]; then
  echo "STORAGE_ROOT is not set in .env." >&2
  exit 1
fi

# Find the mount point that contains STORAGE_ROOT and make sure it is not "/".
mkdir -p "$STORAGE_ROOT"
MOUNT_POINT="$(findmnt -n -o TARGET --target "$STORAGE_ROOT")"
SOURCE_DEVICE="$(findmnt -n -o SOURCE --target "$STORAGE_ROOT")"
if [[ "$MOUNT_POINT" == "/" ]]; then
  echo "$STORAGE_ROOT is on the root filesystem ($SOURCE_DEVICE)." >&2
  echo "Mount the USB SSD first (see README), so data does not wear out the SD card." >&2
  exit 1
fi

echo "Using $STORAGE_ROOT on $SOURCE_DEVICE (mounted at $MOUNT_POINT)"

mkdir -p "$STORAGE_ROOT"/{html,data,db}
chown 33:33 "$STORAGE_ROOT/html" "$STORAGE_ROOT/data"
chmod 750 "$STORAGE_ROOT/data"

mkdir -p tailscale-state
chmod 700 tailscale-state

echo "Done. Next: docker compose up -d"
