#!/usr/bin/env bash

# TODO Switch references to config dir to variable
# TODO change line in park_dental.pref to enable lock: `unlock_way = no` -> `unlock_way = use`

IS_PRODUCTION="" # False
# IS_PRODUCTION="1" # True

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
    if [ -z "$IS_PRODUCTION" ]; then
        sudo apt install -y mesaflash || echo "Failed to install mesaflash"
        sudo apt install -y "$SCRIPT_DIR/src/jethornton_7i96_latest.deb" || \
        echo "Failed to install 7i96. This is usually okay, but if you need to reconfigure \
        the configs or flash the 7i96 then check your internet and install it manually with \
        \`apt install ./src/jethornton_7i96_latest.deb\`"
    fi

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

# Update interface

## Switch to gmoccapy, set HALUI variable, and add gmoccapy preference file
sudo sed -i 's/axis/gmoccapy\nHALUI = halui/g' ~/linuxcnc/configs/park_dental/park_dental.ini
cp "$SCRIPT_DIR/src/park_dental.pref" ~/linuxcnc/configs/park_dental/

# Setup input GPIO pins
### Set all resistors to pull-up
sudo touch /boot/config.txt
sudo sed -i "/gpio/d" /boot/config.txt
sudo sh -c 'echo "gpio=0-27=pu" >> /boot/config.txt'

## Side panel
cp "$SCRIPT_DIR/src/sidepanel.glade" ~/linuxcnc/configs/park_dental/
sudo sed -i 's/\[DISPLAY\]/\[DISPLAY\]\nEMBED_TAB_NAME = Sidepanel\nEMBED_TAB_LOCATION = box_left\nEMBED_TAB_COMMAND = gladevcp -x {XID} -H postgui_sidepanel.hal sidepanel.glade/g' \
    ~/linuxcnc/configs/park_dental/park_dental.ini

### Eject button
# TODO Update eject coordinates
sudo sed -i 's/\[HALUI\]/\[HALUI\]\nMDI_COMMAND = G0 X0 Y0 Z0 B0 C0/g' ~/linuxcnc/configs/park_dental/park_dental.ini

# Install autostart desktop icon
mkdir -p ~/.config/autostart
AUTOSTART=~/.config/autostart/park_dental.desktop
CONFIG_DIR="$( cd ~/linuxcnc/configs/park_dental && pwd )"

echo "[Desktop Entry]" > $AUTOSTART
echo "Name=Park Dental" >> $AUTOSTART
echo "Exec=/usr/bin/linuxcnc '$CONFIG_DIR/park_dental.ini'" >> $AUTOSTART
echo "Type=Application" >> $AUTOSTART
echo "Icon=linuxcncicon" >> $AUTOSTART

chmod +x $AUTOSTART

cp $AUTOSTART ~/Desktop/

# Add reboot icon to desktop
echo "#!/usr/bin/env bash" > ~/Desktop/Reboot
echo "reboot" >> ~/Desktop/Reboot
chmod +x ~/Desktop/Reboot

# Create gcode files mount point
sudo mkdir -p /media/pi/gcode
sudo chown 1000 /media/pi/gcode
sudo chgrp 1000 /media/pi/gcode
sudo sed -i "/MilFiles/d" /etc/fstab
sudo sh -c 'echo "//192.168.0.15/MilFiles /media/pi/gcode cifs uid=1000,r,suid,guest 0 0" >> /etc/fstab'

# Clear networking
sudo sed -i "/interface/d" /etc/dhcpcd.conf
sudo sed -i "/eth0/d" /etc/dhcpcd.conf
sudo sed -i "/eth1/d" /etc/dhcpcd.conf
sudo sed -i "/ip_address=/d" /etc/dhcpcd.conf

# Set static IP for 7i96 on eth0
sudo echo "interface eth0" >> /etc/dhcpcd.conf
sudo echo "static ip_address=10.10.10.9" >> /etc/dhcpcd.conf

# Setup eth1 for private network
sudo echo "interface eth1" >> /etc/dhcpcd.conf
sudo echo "static ip_address=192.168.0.25" >> /etc/dhcpcd.conf

# Wait for networking to boot
sudo raspi-config nonint do_boot_wait 0

# Disable Raspbian splash screen
sudo raspi-config nonint do_boot_splash 1

# Disable screen blanking
sudo raspi-config nonint do_blanking 1
