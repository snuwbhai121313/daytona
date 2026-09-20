#!/bin/bash
set -e

RAILWAY_HOST="proxy-production-cad4.up.railway.app"
LOCAL_PROXY="127.0.0.1:8796"

echo "[+] Setting up Daytona network proxy..."

# Remove existing bridge
docker rm -f gost-bridge 2>/dev/null || true

# Start GOST
docker run -d \
    --net=host \
    --restart unless-stopped \
    --name gost-bridge \
    ginuerzh/gost:latest \
    -L="http://${LOCAL_PROXY}" \
    -F="http+mwss://${RAILWAY_HOST}:443?path=/ws"

echo "[+] Waiting for GOST..."
sleep 3

# Configure APT
mkdir -p /etc/apt/apt.conf.d

cat > /etc/apt/apt.conf.d/99proxy <<EOF
Acquire::http::Proxy "http://${LOCAL_PROXY}";
Acquire::https::Proxy "http://${LOCAL_PROXY}";
EOF

# Proxy environment variables
export HTTP_PROXY="http://${LOCAL_PROXY}"
export HTTPS_PROXY="http://${LOCAL_PROXY}"
export ALL_PROXY="http://${LOCAL_PROXY}"

export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export all_proxy="$ALL_PROXY"

echo "[+] Testing internet connection..."

if curl -fsS \
    -x "http://${LOCAL_PROXY}" \
    https://deb.debian.org/ >/dev/null; then

    echo "[+] Proxy connection successful!"

else

    echo "[!] Proxy connection failed."
    docker logs gost-bridge --tail 30
    exit 1

fi

echo "[+] Running apt update..."
apt-get update

echo
echo "========================================"
echo " Daytona network fix applied"
echo "========================================"
echo " Local proxy : ${LOCAL_PROXY}"
echo " Railway host : ${RAILWAY_HOST}"
echo " APT proxy   : enabled"
echo "========================================"
