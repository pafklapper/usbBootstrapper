#!/bin/bash
# use this script to install the suite

confFile=/etc/usbBootstrapper.config

installationDirectory=/srv/usbBootstrapper
. $installationDirectory/globalVariables

installDrivers()
{
	# rtl8723bs
	cd $installationDirectory/drivers/realtek/
	
	unzip rtl8723bs-SHRT.zip -d /tmp/
	cd /tmp/rtl8723bs-b3def82d8cbd0e7011bfaa6b70cd74725863e833
	
	 make 
	 make install
	
	#broadcom
	cp $installationDirectory/drivers/broadcom/brcmfmac43430a0-sdio.bin /lib/firmware/brcm/
	cp $installationDirectory/drivers/broadcom/brcmfmac43430a0-sdio.txt /lib/firmware/brcm/
	
	
	
	depmod -a
	modprobe -r r8723bs; modprobe r8723bs
	modprobe -r brcmfmac; modprobe brcmfmac
	
	systemctl restart networking
}
if [ "$1" = "drivers" ]; then echo "installing drivers!" && installDrivers; exit; fi


if [ ! -f $confFile ]; then
	cp $(dirname $0)/configTemplate $confFile
fi

if [ -n "$(grep TESTING=y $confFile)" ]; then
	echo Edit config file first!
	echo then remove/change TESTING=y
	read -p "press a key +enter to continue!" && exit 1
fi

source $confFile

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="text nomodeset net.ifnames=0 biosdevname=0 rootdelay=5"' /etc/default/grub
sed -i '/^GRUB_TERMINAL/c\GRUB_TERMINAL=console' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing for Debian" && sleep 1
apt -y install curl wget wpasupplicant xz-utils pv dmidecode build-essential nmap unzip

# https://github.com/theZiz/aha : ANSI -> HTML conversion
cd $installationDirectory/externalModules/aha
make


cat<<EOF>/etc/network/interfaces
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug eth1
iface eth1 inet dhcp

allow-hotplug wlan0
iface wlan0 inet dhcp
	wpa-ssid "$WPASSID"
	wpa-psk "$WPAPSK"
EOF

systemctl reenable networking.service

if [ -f  /etc/systemd/system/windowsUsbBootstrapper.service ]; then rm -f /etc/systemd/system/windowsUsbBootstrapper.service; fi
ln -s $(dirname $(realpath "$0"))/windowsUsbBootstrapper.service /etc/systemd/system/windowsUsbBootstrapper.service

systemctl enable windowsUsbBootstrapper.service
systemctl disable getty@tty0.service
