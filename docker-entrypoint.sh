#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${VPNGATE_DATA_DIR:-/app/data}" /app/data/configs

if [ ! -c /dev/net/tun ]; then
  echo "[WARN] /dev/net/tun is not available. Start the container with --device /dev/net/tun:/dev/net/tun."
fi

if [ -w /proc/sys/net/ipv4/conf/all/rp_filter ]; then
  echo 2 > /proc/sys/net/ipv4/conf/all/rp_filter || true
fi
if [ -w /proc/sys/net/ipv4/conf/default/rp_filter ]; then
  echo 2 > /proc/sys/net/ipv4/conf/default/rp_filter || true
fi

exec python3 /app/vpngate_manager.py
