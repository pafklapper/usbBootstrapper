#!/bin/sh
# use this script to install the suite

confFile=/etc/windowsUsbBootstrapper.config

if [ ! -f $confFile ]; then
	cp $(dirname $0)/configTemplate $confFile
fi

if [ -n "$(grep TESTING=y $confFile)" ]; then
	echo Edit config file first!
	echo then remove/change TESTING=y
	exit 0
fi

source $confFile

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="rd.systemd.show_status=false loglevel=0 text nomodeset net.ifnames=0 biosdevname=0"' /etc/default/grub
sed -i '/^GRUB_TERMINAL/c\GRUB_TERMINAL=console' /etc/default/grub
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

allow-hotplug wlan0
iface wlan0 inet dhcp
	wpa-ssid $WPASSID
	wpa-psk $WPAPSK
EOF
systemctl reenable networking.service

ln -s $(dirname $(realpath "$0"))/windowsUsbBootstrapper.service /etc/systemd/system/windowsUsbBootstrapper.service
systemctl enable windowsUsbBootstrapper.service
systemctl disable getty@tty0.service
