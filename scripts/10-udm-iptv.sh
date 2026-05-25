#!/bin/sh
# Restore udm-iptv after a firmware update on UCG/UniFi OS devices.
# Placed in /data/on_boot.d/ so it survives root filesystem replacements.

PERSIST_DIR=/data/udm-iptv
DEB="$PERSIST_DIR/udm-iptv.deb"
CONF_BACKUP="$PERSIST_DIR/udm-iptv.conf"
CONF=/etc/udm-iptv.conf

if ! dpkg -l udm-iptv 2>/dev/null | grep -q '^ii'; then
    if [ -f "$DEB" ]; then
        echo "[udm-iptv] Package missing after firmware update — reinstalling from $DEB"
        apt-get install -o Acquire::AllowUnsizedPackages=1 -q "$DEB" || true

        # Restore config if it was wiped along with the package
        if [ -f "$CONF_BACKUP" ] && { [ ! -f "$CONF" ] || ! grep -q "IPTV_WAN_INTERFACE" "$CONF" 2>/dev/null; }; then
            echo "[udm-iptv] Restoring configuration from backup"
            cp "$CONF_BACKUP" "$CONF"
        fi

        systemctl start udm-iptv || true
    else
        echo "[udm-iptv] Package missing and no cached .deb found at $DEB — run the installer again"
    fi
fi

# Keep the config backup current on every boot
if [ -f "$CONF" ]; then
    mkdir -p "$PERSIST_DIR"
    cp "$CONF" "$CONF_BACKUP"
fi
