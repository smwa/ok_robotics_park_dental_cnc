#!/usr/bin/env bash

# TODO Switch references to config dir to variable

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
#   GPIO Pin Reference(not rpi pin numbering) (0 and 1 are excluded): 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2
echo "loadrt hal_pi_gpio dir=$((2#01100000000000000000011000)) exclude=$((2#00000011101101001111100101))" >> ~/linuxcnc/configs/park_dental/postgui.hal
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
echo "loadrt or2 count=6" >> ~/linuxcnc/configs/park_dental/postgui.hal # NOTE May need to adjust count, and add `addf`'s
echo "addf or2.0 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.1 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.2 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.3 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.4 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf or2.5 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Setup faults
echo "loadrt estop_latch" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "addf estop-latch.0 servo-thread" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-loopout iocontrol.0.emc-enable-in <= estop-latch.0.ok-out" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-loopin iocontrol.0.user-enable-out => estop-latch.0.ok-in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-reset iocontrol.0.user-request-enable => estop-latch.0.reset" >> ~/linuxcnc/configs/park_dental/postgui.hal

echo "net estop-chain or2.0.out => estop-latch.0.fault-in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-1 or2.1.out => or2.0.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-2 or2.2.out => or2.1.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-3 or2.3.out => or2.2.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-4 or2.4.out => or2.3.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net estop-chain-5 or2.5.out => or2.4.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Connect LEDs via GPIO pins
### start: board29 gpio5
echo "net start-led halui.program.is-running => hal_pi_gpio.pin-05-out" >> ~/linuxcnc/configs/park_dental/postgui.hal
### pause: board31 gpio6
echo "net start-led halui.program.is-paused => hal_pi_gpio.pin-06-out" >> ~/linuxcnc/configs/park_dental/postgui.hal
### stop: board37 gpio26
echo "net start-led halui.program.is-idle => hal_pi_gpio.pin-26-out" >> ~/linuxcnc/configs/park_dental/postgui.hal
### esd: board22 gpio25
echo "net start-led halui.estop.is-activated => hal_pi_gpio.pin-25-out" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Connect input GPIO pins
### start: board5 gpio3
echo "net start-button-debounce hal_pi_gpio.pin-3-in => debounce.0.0.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
#### If program is idle
echo "net start-button-to-start debounce.0.0.out => and2.0.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-is-idle halui.program.is-idle => and2.0.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-start and2.0.out => halui.program.run" >> ~/linuxcnc/configs/park_dental/postgui.hal
#### If program is paused
echo "net start-button-to-resume debounce.0.0.out => and2.1.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-is-paused halui.program.is-paused => and2.1.in1" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net start-button-resume and2.1.out => halui.program.resume" >> ~/linuxcnc/configs/park_dental/postgui.hal

### pause: board13 gpio27
echo "net pause-button-debounce hal_pi_gpio.pin-27-in => debounce.0.1.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net pause-button debounce.0.1.out => halui.program.pause" >> ~/linuxcnc/configs/park_dental/postgui.hal

### stop: board15 gpio22
echo "net stop-button-debounce hal_pi_gpio.pin-22-in => debounce.0.2.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net stop-button debounce.0.2.out => halui.program.stop" >> ~/linuxcnc/configs/park_dental/postgui.hal

### servo fault: board12 gpio18 # TODO Confirm this is for fault
echo "net servo-fault-debounce hal_pi_gpio.pin-18-in => debounce.0.3.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net servo-fault debounce.0.3.out => or2.0.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### esd: board16 gpio23
echo "net esd-debounce hal_pi_gpio.pin-23-in => debounce.0.4.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net esd debounce.0.4.out => or2.1.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### chiller fault: board33 gpio13
echo "net chiller-fault-debounce hal_pi_gpio.pin-13-in => debounce.0.5.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net chiller-fault debounce.0.5.out => or2.2.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### cover open: board32 gpio12
echo "net cover-open-debounce hal_pi_gpio.pin-12-in => debounce.0.6.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net cover-open debounce.0.6.out => or2.3.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### door open: board18 gpio24
echo "net door-open-debounce hal_pi_gpio.pin-24-in => debounce.07.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net door-open debounce.0.7.out => or2.4.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

### blower fault: board10 gpio15
echo "net blower-fault-debounce hal_pi_gpio.pin-15-in => debounce.0.8.in" >> ~/linuxcnc/configs/park_dental/postgui.hal
echo "net blower-fault debounce.0.8.out => or2.5.in0" >> ~/linuxcnc/configs/park_dental/postgui.hal

## Eject button
# TODO Update eject coordinates
sudo sed -i 's/\[HALUI\]/\[HALUI\]\nMDI_COMMAND = G0 X0 Y0 Z0 B0 C0/g' ~/linuxcnc/configs/park_dental/park_dental.ini

cp "$SCRIPT_DIR/src/eject.glade" ~/linuxcnc/configs/park_dental/
echo "net remote-eject halui.mdi-command-00 <= eject.button" >> ~/linuxcnc/configs/park_dental/postgui_eject.hal
sudo sed -i 's/\[DISPLAY\]/\[DISPLAY\]\nEMBED_TAB_NAME = Eject\nEMBED_TAB_LOCATION = box_left\nEMBED_TAB_COMMAND = gladevcp -x {XID} -H postgui_eject.hal eject.glade/g' \
    ~/linuxcnc/configs/park_dental/park_dental.ini

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
sudo sh -c 'echo "//192.168.0.15/MilFiles /media/pi/gcode cifs user,uid=1000,r,suid 0 0" >> /etc/fstab'

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
