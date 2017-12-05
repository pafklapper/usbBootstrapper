#!/bin/bash
# use this script to install the suite

confFile=/etc/usbBootstrapper.config

installationDirectory=/srv/usbBootstrapper
. $installationDirectory/globalVariables

installDrivers()
{
	# rtl8723bs
	cd $installationDirectory/drivers/realtek/
	
	unzip -u rtl8723bs-SHRT.zip -d /tmp/ && cd /tmp/rtl8723bs-b3def82d8cbd0e7011bfaa6b70cd74725863e833 && make  && make install || { echo "Compilation of rtl8723bs failed!"; read; }
	
	#broadcom

	# add broadcom drivers from apt
	if [ ! "$(grep contrib /etc/apt/sources.list | wc -l)" -gt 2 ] ; then
		sed -i '/main/s/$/ non-free contrib/' /etc/apt/sources.list
	fi

if [ ! -f /etc/apt/apt.conf.d/99defaultrelease ]; then
	echo "APT::Default-Release "stable";" > /etc/apt/apt.conf.d/99defaultrelease && \
	grep -ve "^#" /etc/apt/sources.list > /etc/apt/sources.list.d/stable.list && \
	grep -ve "^#" /etc/apt/sources.list | sed 's/stretch/testing/g'> /etc/apt/sources.list.d/testing.list && \
	mv /etc/apt/sources.list /etc/apt/sources.list.bak
fi
	apt update && apt -t testing -y install broadcom-sta-dkms firmware-brcm80211 firmware-b43-installer firmware-b43legacy-installer

	cp -f $installationDirectory/drivers/broadcom/brcmfmac43430a0-sdio.bin /lib/firmware/brcm/ && cp -f $installationDirectory/drivers/broadcom/brcmfmac43430a0-sdio.txt /lib/firmware/brcm/ || { echo "installation of brcmfmac43430a0 failed!"; read; }
	
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

sed -i "/^installationDirectory=/c\installationDirectory=\"$(realpath `dirname $0`)\"" $confFile
source $confFile

echo "Installing for Debian" && sleep 1
apt -y install curl wget wpasupplicant xz-utils pv dmidecode build-essential nmap unzip nginx ntfs-3g net-tools jq linux-image-686 linux-headers-686 rfkill

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="text quiet nomodeset net.ifnames=0 biosdevname=0 rootdelay=9"' /etc/default/grub
sed -i '/^GRUB_TERMINAL/c\GRUB_TERMINAL=console' /etc/default/grub
sed -i '/^GRUB_TIMEOUT=/c\GRUB_TIMEOUT=15' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# https://github.com/theZiz/aha : ANSI -> HTML conversion
cd $installationDirectory
git submodule init
git submodule update
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

if [ -L /etc/systemd/system/usbBootstrapper.service ]; then rm -f /etc/systemd/system/usbBootstrapper.service; fi
ln -s $installationDirectory/usbBootstrapper.service /etc/systemd/system/usbBootstrapper.service

systemctl enable usbBootstrapper.service
systemctl disable getty@tty0.service


. $confFile

if [ -z "$TELEGRAMTOKEN" ]; then
	echo "Telegram not configured!"
elif [ -z "$TELEGRAMCHATID" ]; then
	curlTimeOut="10"
	channelId="-$(curl --max-time $curlTimeOut "https://api.telegram.org/bot$TELEGRAMTOKEN/getUpdates" | jq '.' | grep '"id"' | head -n1 | grep -o '[0-9]\+')" 
	if [ $? -eq 0 ] && [ -n "$channelId" ]; then
		sed -i "/^TELEGRAMCHATID=/c\TELEGRAMCHATID=\"$channelId\"" $confFile
	else
		echo "Could not get telegram chatid! please enter some text in chat on phone!"
	fi
fi
