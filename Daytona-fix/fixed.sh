#!/bin/bash
set -e

RAILWAY_HOST="proxy-production-cad4.up.railway.app"
LOCAL_PROXY="127.0.0.1:8796"
GOST_VERSION="2.12.0"

echo "[+] Daytona network proxy"

# Install required tools
echo "[+] Installing dependencies..."
apt-get update || true
apt-get install -y curl wget tar ca-certificates || true

# Install GOST
if ! command -v gost >/dev/null 2>&1; then
    echo "[+] GOST not found. Downloading..."

    ARCH="$(uname -m)"

    if [ "$ARCH" = "x86_64" ]; then
        GOST_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        GOST_ARCH="arm64"
    else
        echo "[!] Unsupported architecture: $ARCH"
        exit 1
    fi

    TMP="$(mktemp -d)"

    curl -fL \
        "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz" \
        -o "$TMP/gost.tar.gz"

    tar -xzf "$TMP/gost.tar.gz" -C "$TMP"

    install -m 755 "$TMP/gost" /usr/local/bin/gost

    rm -rf "$TMP"

    echo "[+] GOST installed."
fi

echo "[+] GOST:"
gost -V || true

# Kill old bridge
pkill -f "gost.*8796" 2>/dev/null || true

# Start GOST bridge
echo "[+] Starting GOST..."

nohup gost \
    -L="http://${LOCAL_PROXY}" \
    -F="http+mwss://${RAILWAY_HOST}:443?path=/ws" \
    >/tmp/gost.log 2>&1 &

sleep 4

# Check GOST
if ! (echo >/dev/tcp/127.0.0.1/8796) >/dev/null 2>&1; then
    echo "[!] GOST failed to start."
    cat /tmp/gost.log
    exit 1
fi

# Configure APT
mkdir -p /etc/apt/apt.conf.d

cat >/etc/apt/apt.conf.d/99proxy <<EOF
Acquire::http::Proxy "http://${LOCAL_PROXY}";
Acquire::https::Proxy "http://${LOCAL_PROXY}";
EOF

# Configure proxy environment
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
echo "========================================"
echo " Local : ${LOCAL_PROXY}"
echo " Remote: ${RAILWAY_HOST}"
echo "========================================"
