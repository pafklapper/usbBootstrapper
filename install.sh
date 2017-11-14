#!/bin/sh
# use this script to install the suite

source $(dirname "$0")/config

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="text nomodeset net.ifnames=0 biosdevname=0"' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# debian specific!
apt -y install curl wget wpasupplicant xz-utils pv

cat<<EOF>/etc/network/interfaces
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug eth1
iface eth1 inet dhcp

auto wlan0
iface wlan0 inet dhcp
	wpa-ssid $WPASSID
	wpa-psk $WPAPSK
EOF
systemctl reenable networking.service

ln -s $(dirname "$0")/main.sh /etc/systemd/system/windowsUsbBootstrapper.sh
systemctl enable windowsUsbBootstrapper.service
systemctl disable getty@tty0.service
