#!/bin/sh
# Installation script for the udm-iptv service
#
# Copyright (C) 2022 Fabian Mastenbroek.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

set -e

if command -v unifi-os > /dev/null 2>&1; then
    echo "error: You need to be in UniFi OS to run the installer."
    echo "Please run the following command to enter UniFi OS:"
    echo
    printf "\t unifi-os shell\n"
    exit 1
fi

UDM_IPTV_VERSION=3.0.6
FORK_RAW=https://raw.githubusercontent.com/kayvanaarssen/udm-iptv/master

dest=$(mktemp -d)

echo "Downloading packages..."

# Download udm-iptv package from upstream release
curl -sS -o "$dest/udm-iptv.deb" -L "https://github.com/fabianishere/udm-iptv/releases/download/v$UDM_IPTV_VERSION/udm-iptv_${UDM_IPTV_VERSION}_all.deb"

# Fix permissions on the packages
chown _apt:root "$dest/udm-iptv.deb"

echo "Installing packages..."

# Update APT sources (best effort)
apt-get update 2>&1 1>/dev/null || true

# Install dialog package for interactive install
apt-get install -q -y dialog 2>&1 1>/dev/null || echo "Failed to install dialog... Using readline frontend"

# Install udm-iptv
apt-get install -o Acquire::AllowUnsizedPackages=1 -q "$dest/udm-iptv.deb"

# Overwrite fork-modified files that are not in the upstream .deb release.
# The upstream .deb ships the original udm-iptv management script; we replace
# it with our version that adds the 'persist' command and UCG recovery logic.
echo "Applying fork patches..."
curl -sS -o /usr/bin/udm-iptv "$FORK_RAW/udm-iptv"
chmod +x /usr/bin/udm-iptv

# Install the on-boot recovery script into the package directory.
mkdir -p /usr/lib/udm-iptv
curl -sS -o /usr/lib/udm-iptv/10-udm-iptv.sh "$FORK_RAW/scripts/10-udm-iptv.sh"
chmod +x /usr/lib/udm-iptv/10-udm-iptv.sh

# Set up /data/ persistence for UCG devices (firmware updates wipe the root fs).
if [ -d /data ]; then
    mkdir -p /data/udm-iptv /data/on_boot.d

    # Cache the .deb so the boot recovery script can reinstall without network.
    cp "$dest/udm-iptv.deb" /data/udm-iptv/udm-iptv.deb

    # Back up current config if it already exists.
    [ -f /etc/udm-iptv.conf ] && cp /etc/udm-iptv.conf /data/udm-iptv/udm-iptv.conf

    # Install the boot recovery script.
    cp /usr/lib/udm-iptv/10-udm-iptv.sh /data/on_boot.d/10-udm-iptv.sh
    chmod +x /data/on_boot.d/10-udm-iptv.sh
fi

# Delete downloaded packages
rm -rf "$dest"

echo "Installation successful... You can find your configuration at /etc/udm-iptv.conf."
echo
echo "Use the following command to reconfigure the script:"
echo
printf "\t udm-iptv reconfigure\n"
echo
if [ -d /data ]; then
    echo "UCG persistence: boot recovery script installed to /data/on_boot.d/10-udm-iptv.sh"
    echo "After a firmware update, udm-iptv will be automatically reinstalled on next boot."
    echo "(Requires UniFi OS native on_boot.d support or the unifios-utilities on-boot package.)"
    echo "Run 'udm-iptv persist' at any time to refresh the persistence cache."
fi
