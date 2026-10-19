#!/bin/bash
# ==============================================================================
# Kali Linux VMware Mouse Cursor & Desktop Integration Fix
# Run this script inside any Kali Linux VM running on VMware Workstation / Player
# ==============================================================================

echo "[*] Applying VMware Software Cursor fix for Kali Linux..."

# 1. Force Software Cursor in Xorg (bypasses broken virtual GPU hardware cursor)
sudo mkdir -p /etc/X11/xorg.conf.d
cat << 'EOF' | sudo tee /etc/X11/xorg.conf.d/20-modesetting.conf
Section "Device"
    Identifier "Modesetting"
    Driver "modesetting"
    Option "SWCursor" "true"
EndSection
EOF

# 2. Reset cursor theme and size to visible defaults
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "Adwaita" 2>/dev/null
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 24 2>/dev/null
xsetroot -cursor_name left_ptr 2>/dev/null

# 3. Ensure open-vm-tools-desktop is installed for seamless mouse & clipboard
if ! dpkg -s open-vm-tools-desktop >/dev/null 2>&1; then
    echo "[*] Installing open-vm-tools-desktop..."
    sudo apt-get update -y
    sudo apt-get install -y open-vm-tools-desktop
fi

sudo systemctl enable --now open-vm-tools 2>/dev/null

echo "[+] Done! Restarting display manager to apply changes..."
sudo systemctl restart lightdm
