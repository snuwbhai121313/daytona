#!/bin/bash
set -e

RAILWAY_HOST="proxy-production-cad4.up.railway.app"
LOCAL_PROXY="127.0.0.1:8796"
GOST_VERSION="2.12.0"

echo "[+] Installing Daytona network proxy..."

# Install basic tools if available
apt-get update -o Acquire::Retries=3 || true
apt-get install -y curl wget tar ca-certificates || true

# Download GOST if not installed
if ! command -v gost >/dev/null 2>&1; then
    echo "[+] GOST not found, downloading..."

    ARCH="$(uname -m)"

    case "$ARCH" in
        x86_64|amd64)
            GOST_ARCH="amd64"
            ;;
        aarch64|arm64)
            GOST_ARCH="arm64"
            ;;
        *)
            echo "[!] Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    TMP_DIR="$(mktemp -d)"

    curl -fL \
      "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz" \
      -o "$TMP_DIR/gost.tar.gz"

    tar -xzf "$TMP_DIR/gost.tar.gz" -C "$TMP_DIR"

    install -m 755 "$TMP_DIR/gost" /usr/local/bin/gost

    rm -rf "$TMP_DIR"

    echo "[+] GOST installed."
fi

echo "[+] GOST version:"
gost -V || gost --version || true

# Stop previous GOST bridge
pkill -f "gost.*8796" 2>/dev/null || true

# Start GOST
echo "[+] Starting GOST..."

nohup gost \
  -L="http://${LOCAL_PROXY}" \
  -F="http+mwss://${RAILWAY_HOST}:443?path=/ws" \
  >/tmp/gost.log 2>&1 &

sleep 4

# Check listener
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
echo " Local proxy : ${LOCAL_PROXY}"
echo " Railway     : ${RAILWAY_HOST}"
echo "========================================"
