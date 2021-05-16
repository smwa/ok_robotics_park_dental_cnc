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
## Update if it has been more than a day
PERIODIC_PATH="/var/lib/apt/periodic/update-success-stamp"
(find $PERIODIC_PATH | grep update-success-stamp) || (sudo /usr/bin/apt update && sudo touch $PERIODIC_PATH || echo "Failed to run apt")
(find $PERIODIC_PATH -mtime +1 | grep update-success-stamp) \
&& (sudo /usr/bin/apt update && sudo touch $PERIODIC_PATH || echo "Failed to run apt")

sudo apt install -y "$SCRIPT_DIR/dist/jethornton_7i96_latest.deb" || \
echo "Failed to install 7i96. This is usually okay, but if you need to reconfigure \
the configs or flash the 7i96 then check your internet and install it manually with \
\`apt install ./dist/jethornton_7i96_latest.deb\`"

# Make custom changes to configs
rm -r "$SCRIPT_DIR/dist/park_dental" || true
cp -r \
"$SCRIPT_DIR/src/park_dental/." \
"$SCRIPT_DIR/dist/park_dental"

# Update interface and remove unnecessary icons
sudo sed -i 's/axis/gmoccapy\nHALUI = halui/g' "$SCRIPT_DIR/dist/park_dental/park_dental.ini"
cp \
"$SCRIPT_DIR/src/park_dental.pref" \
"$SCRIPT_DIR/dist/park_dental/"

# Copy configs to linuxcnc config directory
mkdir -p ~/linuxcnc/configs
cp -r "$SCRIPT_DIR/dist/park_dental" ~/linuxcnc/configs/

# Install autostart desktop icon
mkdir -p ~/.config/autostart
AUTOSTART=~/.config/autostart/park_dental.desktop
CONFIG_DIR="$( cd ~/linuxcnc/configs/park_dental && pwd )"

echo "[Desktop Entry]" > $AUTOSTART
echo "Name=LinuxCNC-HAL-PARK-DENTAL" >> $AUTOSTART
echo "Exec=/usr/bin/linuxcnc '$CONFIG_DIR/park_dental.ini' ; reboot" >> $AUTOSTART
echo "Type=Application" >> $AUTOSTART
echo "Comment=" >> $AUTOSTART
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
echo "Encoding=UTF-8" >> $AUTOSTART
echo "Version=1.0.0" >> $AUTOSTART
echo "Type=Application" >> $AUTOSTART
echo "Name=GPIO Daemon" >> $AUTOSTART
echo "Comment=Interfaces between GPIO pins and LinuxCNC" >> $AUTOSTART
echo "Exec=python3 $GPIO_DAEMON_DIR/main.py" >> $AUTOSTART
echo "StartupNotify=false" >> $AUTOSTART
echo "Categories=Utility;" >> $AUTOSTART

chmod +x $AUTOSTART

# Set static IP
sudo sed -i "/interface eth0/d" /etc/dhcpcd.conf
sudo echo "interface eth0" >> /etc/dhcpcd.conf
sudo sed -i "/static ip_address=10.10.10.9/d" /etc/dhcpcd.conf
sudo echo "static ip_address=10.10.10.9" >> /etc/dhcpcd.conf
