#!/usr/bin/env bash

# TODO change line in park_dental.pref to enable lock: `unlock_way = no` -> `unlock_way = use`

# IS_PRODUCTION="" # False
IS_PRODUCTION="1" # True

USE_NETWORK="" # False
# USE_NETWORK="1" # True

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

if [ "$USE_NETWORK" ]; then
    # Update apt and upgrade all packages
    sudo apt update || echo "Failed to run apt"
    sudo apt upgrade -y || echo "Failed to upgrade packages"

    # Install 7i96
    sudo apt install -y mesaflash || echo "Failed to install mesaflash"
    sudo apt install -y "$SCRIPT_DIR/src/jethornton_7i96_latest.deb" || \
    echo "Failed to install 7i96. This is usually okay, but if you need to reconfigure \
    the configs or flash the 7i96 then check your internet and install it manually with \
    \`apt install ./src/jethornton_7i96_latest.deb\`"

    # Install glade
    if [ -z "$IS_PRODUCTION" ]; then
        sudo apt install -y glade-3 || \
        echo "Failed to install glade-3. This is usually okay, but if you need to setup \
        the glade widgets then check your internet and install it manually with \
        \`apt install glade-3\`"
    fi
fi

# Copy configs from repo
mkdir -p ~/linuxcnc/configs
rm -r ~/linuxcnc/configs/park_dental || true
cp -r "$SCRIPT_DIR/src/park_dental" ~/linuxcnc/configs/

# Setup input GPIO pins
### Set all resistors to pull-up
sudo touch /boot/config.txt
sudo sed -i "/gpio/d" /boot/config.txt
sudo sh -c 'echo "gpio=0-27=pu" >> /boot/config.txt'
sudo sed -i "/over_voltage/d" /boot/config.txt
sudo sh -c 'echo "over_voltage=6" >> /boot/config.txt'
sudo sed -i "/arm_freq/d" /boot/config.txt
sudo sh -c 'echo "arm_freq=1800" >> /boot/config.txt'


# Install desktop icons and autostarts
mkdir -p ~/.config/autostart
cp "$SCRIPT_DIR/src/park_dental.desktop" ~/.config/autostart/
cp "$SCRIPT_DIR/src/park_dental.desktop" ~/Desktop/
cp "$SCRIPT_DIR/src/Reboot.sh" ~/Desktop/

# Install modified gmoccapy.glade file
sudo cp -n /usr/share/gmoccapy/gmoccapy.glade /usr/share/gmoccapy/gmoccapy.glade.bak
sudo cp "$SCRIPT_DIR/src/gmoccapy.glade" /usr/share/gmoccapy/gmoccapy.glade

# Create gcode files mount point
sudo mkdir -p /media/pi/gcode
sudo chown 1000 /media/pi/gcode
sudo chgrp 1000 /media/pi/gcode
sudo sed -i "/MilFiles/d" /etc/fstab
if [ "$IS_PRODUCTION" ]; then
    echo "//jarvis/Network\040Data/Mill\040Files /media/pi/gcode cifs uid=1000,ro,noperm,noauto,users,_netdev,username=laser,password=J3D@2401,domain=juellcompanies 0 0" | sudo tee -a /etc/fstab > /dev/null
fi
echo "@reboot sleep 45 && mount /media/pi/gcode" | sudo crontab -

# Clear networking
# sudo sed -i "/interface/d" /etc/dhcpcd.conf
sudo sed -i "/eth0/d" /etc/dhcpcd.conf
# sudo sed -i "/eth1/d" /etc/dhcpcd.conf
sudo sed -i "/ip_address=/d" /etc/dhcpcd.conf

# Set static IP for 7i96 on eth0
sudo echo "interface eth0" >> /etc/dhcpcd.conf
sudo echo "static ip_address=10.10.10.9" >> /etc/dhcpcd.conf

# Setup eth1 for private network
# sudo echo "interface eth1" >> /etc/dhcpcd.conf
# sudo echo "static ip_address=192.168.0.25" >> /etc/dhcpcd.conf

# Wait for networking to boot
sudo raspi-config nonint do_boot_wait 0

# Enable Raspbian splash screen
sudo raspi-config nonint do_boot_splash 0
sudo cp -n /usr/share/plymouth/themes/pix/splash.png /usr/share/plymouth/themes/pix/splash.png.bak
sudo cp "$SCRIPT_DIR/src/splash.*" /usr/share/plymouth/themes/pix
sudo chown root /usr/share/plymouth/themes/pix/splash.*
sudo sed -i "/exit 0/d" /etc/rc.local
sudo sed -i "/omxplayer/d" /etc/rc.local
sudo echo "omxplayer /usr/share/plymouth/themes/pix/splash.mov &" >> /etc/rc.local
sudo echo "exit 0" >> /etc/rc.local

# Disable screen blanking
sudo raspi-config nonint do_blanking 1
