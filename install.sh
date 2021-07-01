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

## Setup raspberry pi gpio pins
#   dir is input/output, where 0 means input and 1 means output. exclude is for which pins are enabled, where 0 means use and 1 means do not use
#   Board pin reference, ordered by bitmap order (0 and 1 are excluded): 13 37 22 18 16 15 40 38 35 12 11 36 10 8 33 32 23 19 21 24 26 31 29 7 5 3
echo "loadrt hal_pi_gpio dir=$((2#11110000000000000000000000)) exclude=$((2#00000111111100111110000000))" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf hal_pi_gpio.read servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf hal_pi_gpio.write servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Setup Debounce
echo "loadrt debounce cfg=10" >> ~/linuxcnc/configs/park_dental/postgui.hal # NOTE May need to adjust cfg, this is the number of debounce inputs
echo "addf debounce.0 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Setup `and2`
echo "loadrt and2 count=2" >> ~/linuxcnc/configs/park_dental/postgui.hal # NOTE May need to adjust count, and add `addf`'s
echo "addf and2.0 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf and2.1 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Setup `or2`
echo "loadrt or2 count=7" >> ~/linuxcnc/configs/park_dental/postgui.hal # NOTE May need to adjust count, and add `addf`'s
echo "addf or2.0 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.1 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.2 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.3 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.4 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.5 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.6 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Setup `not`
echo "loadrt not count=7" >> ~/linuxcnc/configs/park_dental/postgui.hal # NOTE May need to adjust count, and add `addf`'s
echo "addf not.0 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf not.1 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf not.2 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf not.3 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf not.4 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf not.5 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf not.6 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Setup faults, removing and re-instating latch from io.hal
#   Move 7i96 esd pin to `or2` chain
echo "unlinkp estop-latch.0.fault-in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net remote-estop hm2_7i96.0.gpio.010.in_not => or2.0.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

echo "net estop-chain or2.0.out => estop-latch.0.fault-in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-1 or2.1.out => or2.0.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-2 or2.2.out => or2.1.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-3 or2.3.out => or2.2.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-4 or2.4.out => or2.3.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-5 or2.5.out => or2.4.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-6 or2.6.out => or2.5.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Connect LEDs via GPIO pins
### start: board29
echo "net start-led halui.program.is-running => hal_pi_gpio.pin-29-out" >> ~/linuxcnc/configs/park_dental/postgui.hal
### pause: board31
#   Merged with start button input so that halui.program.is-paused isn't referenced twice
### stop: board37
#   Merged with start button input so that halui.program.is-idle isn't referenced twice
### esd: board22
echo "net esd-led halui.estop.is-activated => hal_pi_gpio.pin-22-out" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Connect input GPIO pins
### start: board07
echo "net start-button-inverted hal_pi_gpio.pin-07-in => not.0.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-debounce not.0.out => debounce.0.0.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-to-start debounce.0.0.out => and2.0.in0 and2.1.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal
#### If program is idle
echo "net start-button-is-idle halui.program.is-idle => and2.0.in1 hal_pi_gpio.pin-37-out" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-start and2.0.out => halui.program.run" >> ~/linuxcnc/configs/park_dental/postgui.hal
#### If program is paused
echo "net start-button-is-paused halui.program.is-paused => and2.1.in1 hal_pi_gpio.pin-31-out" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-resume and2.1.out => halui.program.resume" >> ~/linuxcnc/configs/park_dental/postgui.hal

### pause: board13
echo "net pause-button-inverted hal_pi_gpio.pin-13-in => not.1.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net pause-button-debounce not.1.out => debounce.0.1.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net pause-button debounce.0.1.out => halui.program.pause" >> ~/linuxcnc/configs/park_dental/postgui.hal

### stop: board15
echo "net stop-button-debounce hal_pi_gpio.pin-15-in => debounce.0.2.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net stop-button debounce.0.2.out => halui.program.stop" >> ~/linuxcnc/configs/park_dental/postgui.hal

### esd: board16
echo "net esd-debounce hal_pi_gpio.pin-16-in => debounce.0.3.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net esd debounce.0.3.out => or2.1.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### servo fault: board12
# TODO Confirm this is for fault
echo "net servo-fault-inverted hal_pi_gpio.pin-12-in => not.6.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net servo-fault-debounce not.6.out => debounce.0.4.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net servo-fault debounce.0.4.out => or2.2.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### chiller fault: board33
echo "net chiller-fault-inverted hal_pi_gpio.pin-33-in => not.3.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net chiller-fault-debounce not.3.out => debounce.0.5.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net chiller-fault debounce.0.5.out => or2.3.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### cover open: board32
echo "net cover-open-inverted hal_pi_gpio.pin-32-in => not.5.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net cover-open-debounce not.5.out => debounce.0.6.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net cover-open debounce.0.6.out => or2.4.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### door open: board18
echo "net door-open-inverted hal_pi_gpio.pin-18-in => not.4.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net door-open-debounce not.4.out => debounce.0.7.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net door-open debounce.0.7.out => or2.5.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### blower fault: board10
echo "net blower-fault-inverted hal_pi_gpio.pin-10-in => not.2.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net blower-fault-debounce not.2.out => debounce.0.8.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net blower-fault debounce.0.8.out => or2.6.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Side panel
cp "$SCRIPT_DIR/src/sidepanel.glade" ~/linuxcnc/configs/park_dental/
echo "" >> ~/linuxcnc/configs/park_dental/postgui_sidepanel.hal
sudo sed -i 's/\[DISPLAY\]/\[DISPLAY\]\nEMBED_TAB_NAME = Sidepanel\nEMBED_TAB_LOCATION = box_left\nEMBED_TAB_COMMAND = gladevcp -x {XID} -H postgui_sidepanel.hal sidepanel.glade/g' \
    ~/linuxcnc/configs/park_dental/park_dental.ini

### Eject button
# TODO Update eject coordinates
sudo sed -i 's/\[HALUI\]/\[HALUI\]\nMDI_COMMAND = G0 X0 Y0 Z0 B0 C0/g' ~/linuxcnc/configs/park_dental/park_dental.ini
echo "net remote-eject halui.mdi-command-00 <= sidepanel.eject" >> ~/linuxcnc/configs/park_dental/postgui_sidepanel.hal

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

# Create gcode files mount point
sudo mkdir -p /media/pi/gcode
sudo chown pi /media/pi/gcode
sudo chgrp pi /media/pi/gcode
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
