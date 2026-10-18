
#!/usr/bin/env bash
set -Eeuo pipefail

# Nessus installer for Debian/Ubuntu/Kali Linux (amd64)
# Official Tenable download endpoint.

VERSION="10.12.5"
PACKAGE="Nessus-${VERSION}-ubuntu1604_amd64.deb"
URL="https://www.tenable.com/downloads/api/v2/pages/nessus/files/${PACKAGE}"
INSTALL_DIR="/tmp/nessus-install"
LOG="/var/log/nessus-install.log"

# Require root
if [[ $EUID -ne 0 ]]; then
    echo "Run this script with sudo: sudo $0"
    exit 1
fi

# Check platform
if ! command -v dpkg >/dev/null 2>&1; then
    echo "Error: dpkg is unavailable. This script requires Debian-based Linux."
    exit 1
fi

exec > >(tee -a "$LOG") 2>&1

echo "=== Nessus installation started: $(date) ==="

# Install download dependencies
apt-get update
apt-get install -y curl ca-certificates

# Download package from Tenable
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "Downloading $PACKAGE ..."
curl --fail --location --retry 3 \
    --output "$PACKAGE" "$URL"

# Reject an empty or invalid download
if [[ ! -s "$PACKAGE" ]] ||
   ! dpkg-deb --info "$PACKAGE" >/dev/null 2>&1; then
    echo "Error: Downloaded file is not a valid Debian package."
    exit 1
fi

# Install Nessus
echo "Installing Nessus..."
if ! dpkg -i "$PACKAGE"; then
    echo "Resolving package dependencies..."
    apt-get install -f -y
    dpkg -i "$PACKAGE"
fi

# Enable and start the service
systemctl enable nessusd.service
systemctl restart nessusd.service

# Verify service
echo "Waiting for service startup..."
sleep 5

if systemctl is-active --quiet nessusd.service; then
    echo "SUCCESS: Nessus service is running."
else
    echo "ERROR: Nessus service failed to start."
    systemctl status nessusd.service --no-pager || true
    journalctl -u nessusd.service -n 50 --no-pager || true
    exit 1
fi

echo
systemctl status nessusd.service --no-pager
echo
echo "Open https://localhost:8834 to finish Nessus setup."
echo "Installation log: $LOG"
echo "=== Finished: $(date) ==="
