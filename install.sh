#!/bin/bash
# use this script to install the suite

confFile=/etc/windowsUsbBootstrapper.config

installationDirectory=/srv/windowsUsbBootstrapper
. $installationDirectory/globalVariables


if [ ! -f $confFile ]; then
	cp $(dirname $0)/configTemplate $confFile
fi

if [ -n "$(grep TESTING=y $confFile)" ]; then
	echo Edit config file first!
	echo then remove/change TESTING=y
	read -p "press a key +enter to continue!" && exit 1
fi

source $confFile

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="text nomodeset net.ifnames=0 biosdevname=0"' /etc/default/grub
sed -i '/^GRUB_TERMINAL/c\GRUB_TERMINAL=console' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# debian specific!
apt -y install curl wget wpasupplicant xz-utils pv dmidecode

apt install software-properties-common

# https://github.com/nodesource/distributions#debmanual
add-apt-repository -y -r ppa:chris-lea/node.js
rm -f /etc/apt/sources.list.d/chris-lea-node_js-*.list
rm -f /etc/apt/sources.list.d/chris-lea-node_js-*.list.sav

curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -


# Replace with the branch of Node.js or io.js you want to install: node_0.10, node_0.12, node_4.x, node_5.x, etc...
VERSION=node_6.x
# The below command will set this correctly, but if lsb_release isn't available, you can set it manually:
# - For Debian distributions: wheezey, jessie, sid, etc...
# - For Ubuntu distributions: trusty, xenial, etc...
# - For Debian or Ubuntu derived distributions your best option is to use the codename corresponding to the upstream release your distribution is based off. This is an advanced scenario and unsupported if your distribution is not listed as supported per earlier in this README.
DISTRO="$(lsb_release -s -c)"
echo "deb https://deb.nodesource.com/$VERSION $DISTRO main" | tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src https://deb.nodesource.com/$VERSION $DISTRO main" | tee -a /etc/apt/sources.list.d/nodesource.list

apt update
apt install nodejs npm

cd $installationDirectory/externalModules/wetty
npm install 

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

if [ -f  /etc/systemd/system/windowsUsbBootstrapper.service ]; then rm -f /etc/systemd/system/windowsUsbBootstrapper.service; fi
ln -s $(dirname $(realpath "$0"))/windowsUsbBootstrapper.service /etc/systemd/system/windowsUsbBootstrapper.service

systemctl enable windowsUsbBootstrapper.service
systemctl disable getty@tty0.service
