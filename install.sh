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
(find /var/lib/apt/periodic/update-success-stamp -mtime +1 | grep update-success-stamp) \
&& (/usr/bin/apt update || echo "Failed to run apt")

sudo apt install -y "$SCRIPT_DIR/dist/jethornton_7i96_latest.deb" || \
echo "Failed to install 7i96. This is usually okay, but if you need to reconfigure \
the configs or flash the 7i96 then check your internet and install it manually with \
\`apt install ./dist/jethornton_7i96_latest.deb\`"

# Make custom changes to configs
rm -r "$SCRIPT_DIR/dist/park_dental" || true
cp -r \
"$SCRIPT_DIR/src/park_dental/." \
"$SCRIPT_DIR/dist/park_dental"
# TODO Update interface and remove unnecessary icons

# Copy configs to linuxcnc config directory
cp -r "$SCRIPT_DIR/dist/park_dental" ~/linuxcnc/configs/

# Install autostart desktop icon
mkdir -p ~/.config/autostart
AUTOSTART=~/.config/autostart/park_dental.desktop

echo "[Desktop Entry]" > $AUTOSTART
echo "testing" >> $AUTOSTART

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
