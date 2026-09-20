#!/bin/bash
set -e

RAILWAY_HOST="proxy-production-cad4.up.railway.app"
LOCAL_PROXY="127.0.0.1:8796"

echo "[+] Setting up Daytona network proxy..."

# Stop any existing GOST process using port 8796
pkill -f "127.0.0.1:8796" 2>/dev/null || true

# Start GOST directly
nohup gost \
  -L="http://${LOCAL_PROXY}" \
  -F="http+mwss://${RAILWAY_HOST}:443?path=/ws" \
  >/tmp/gost.log 2>&1 &

echo "[+] Starting GOST..."
sleep 3

# Configure APT
mkdir -p /etc/apt/apt.conf.d

cat >/etc/apt/apt.conf.d/99proxy <<EOF
Acquire::http::Proxy "http://${LOCAL_PROXY}";
Acquire::https::Proxy "http://${LOCAL_PROXY}";
EOF

# Proxy environment
export HTTP_PROXY="http://${LOCAL_PROXY}"
export HTTPS_PROXY="http://${LOCAL_PROXY}"
export ALL_PROXY="http://${LOCAL_PROXY}"

export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export all_proxy="$ALL_PROXY"

echo "[+] Testing proxy..."

if curl -fsS \
  -x "http://${LOCAL_PROXY}" \
  https://deb.debian.org/ >/dev/null; then

    echo "[+] Proxy is working!"
    echo "[+] Daytona network fix applied."

else

    echo "[!] Proxy test failed."
    echo
    cat /tmp/gost.log
    exit 1
fi

echo "[+] Running apt update..."
apt-get update

echo
echo "========================================"
echo " Daytona proxy is READY"
echo " Local proxy: ${LOCAL_PROXY}"
echo " Railway: ${RAILWAY_HOST}"
echo "========================================"
