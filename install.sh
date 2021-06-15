#!/usr/bin/env bash

# Get this repo's absolute path
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Exit on failure
set -e

# If user is root, request to be ran as normal user
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    if [[ -z "${ALLOW_ROOT}" ]]; then
        echo "Please run this as the user that will be running linuxcnc, \
or set the ALLOW_ROOT environment variable"
        exit 1
    fi
fi

# Install 7i96 (internet required)
sudo apt update || echo "Failed to run apt"

sudo apt install -y "$SCRIPT_DIR/dist/jethornton_7i96_latest.deb" || \
echo "Failed to install 7i96. This is usually okay, but if you need to reconfigure \
the configs or flash the 7i96 then check your internet and install it manually with \
\`apt install ./dist/jethornton_7i96_latest.deb\`"

# Make custom changes to configs
mkdir -p ~/linuxcnc/configs
rm -r ~/linuxcnc/configs/park_dental || true
cp -r "$SCRIPT_DIR/src/park_dental" ~/linuxcnc/configs/

# Update interface and remove unnecessary icons
sudo sed -i 's/axis/gmoccapy\nHALUI = halui/g' ~/linuxcnc/configs/park_dental/park_dental.ini
cp "$SCRIPT_DIR/src/park_dental.pref" ~/linuxcnc/configs/park_dental/

# Install autostart desktop icon
mkdir -p ~/.config/autostart
AUTOSTART=~/.config/autostart/park_dental.desktop
CONFIG_DIR="$( cd ~/linuxcnc/configs/park_dental && pwd )"

echo "[Desktop Entry]" > $AUTOSTART
echo "Name=LinuxCNC-HAL-PARK-DENTAL" >> $AUTOSTART
echo "Exec=/usr/bin/linuxcnc '$CONFIG_DIR/park_dental.ini'" >> $AUTOSTART
echo "Type=Application" >> $AUTOSTART
echo "Icon=linuxcncicon" >> $AUTOSTART

chmod +x $AUTOSTART

# Install GPIO daemon
rm -r ~/gpio_daemon 2> /dev/null || true
cp -r "$SCRIPT_DIR/src/gpio_daemon" ~/
python3 -m pip install -r ~/gpio_daemon/requirements.txt

# Install autostart for GPIO daemon
mkdir -p ~/.config/autostart
AUTOSTART=~/.config/autostart/gpio_daemon.desktop
GPIO_DAEMON_DIR="$( cd ~/gpio_daemon && pwd )"

echo "[Desktop Entry]" > $AUTOSTART
echo "Type=Application" >> $AUTOSTART
echo "Name=GPIO Daemon" >> $AUTOSTART
echo "Exec=python3 $GPIO_DAEMON_DIR/main.py" >> $AUTOSTART

chmod +x $AUTOSTART

# Set static IP for 7i96 on eth0
sudo sed -i "/interface eth0/d" /etc/dhcpcd.conf
sudo echo "interface eth0" >> /etc/dhcpcd.conf
sudo sed -i "/static ip_address=10.10.10.9/d" /etc/dhcpcd.conf
sudo echo "static ip_address=10.10.10.9" >> /etc/dhcpcd.conf
sudo echo "" >> /etc/dhcpcd.conf

# Set DHCP for external port on eth1
sudo sed -i "/eth1/d" /etc/dhcpcd.conf
sudo echo "iface eth1 inet dhcp" >> /etc/dhcpcd.conf

# Wait for networking to boot
sudo raspi-config nonint do_boot_wait 0
