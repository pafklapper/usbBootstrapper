#!/bin/bash


windowsMountPoint="/mnt/windows"
windowsISODirectory="$windowsMountPoint/windowsUsbBootstrapper"
windowsISO="$windowsISODirectory/WIN10.ISO.xz"

echo $windowsISO
exit 

nginxDefaultDirectory="/var/www/html"

installationDirectory=/srv/windowsUsbBootstrapper
cd $installationDirectory

. $installationDirectory/globalFunctions
. $installationDirectory/globalVariables
. $confFile




mountWindowsHarddisk()
{
blkid|grep ntfs|while read ntfsLine; do
	ntfsBlk="$(echo $ntfsLine|cut -d: -f1)"
	if [ -b $ntfsBlk ]; then
		mkdir -p $windowsMountPoint
		mount $ntfsBlk $windowsMountPoint

		if [ -d $windowsMountPoint/Windows ]; then
			if [ $(df | grep $windowsMountPoint| awk '{ print +$4 }') -gt 10000000 ]; then
				return 0
			else
				logp fatal "Deze computer heeft niet genoeg ruimte om de Windows schijf te kunnen hosten. Probeer een andere computer!"
			fi
		else
			umount $windowsMountPoint
		fi
	else
		logp fatal "NTFS blok herkenning mislukt!"
	fi
done

	if [ ! -d $windowsMountPoint/Windows ]; then
		return 1
	fi
}

isISODownloaded()
{
 if [ -d $windowsISODirectory ] && [ -f $windowsISO ]; then
 	return 0;
 else
 	return 1;
 fi
}

isISOUptodate()
{
	return 0
}

downloadISO()
{
mkdir  -p $windowsISODirectory
WINISOSIZE="$(curl $WINISOSIZEURL 2>/dev/null)"
WINISOCHECKSUM="$(curl $WINISOCHECKSUMURL 2>/dev/null)"


logp info "Het systeem zal nu de geprepareerde Windows schijf downloaden..."
for i in (0..2); do
	wget $WINISOURL -q -O - | pv --size $WINISOSIZE $ |  dd of=$windowsISO
	if [ $? -eq 0]; then
		logp info "De windows schijf is succesvol gedownload!"
		break
	else
		rm -f $windowsISO
		logp warning "Downloaden mislukt! Poging $i"
	fi
done

logp info "Integriteitscontrole van de gedownloade schijf..."
localWINISOCHECKSUM="$(sha256sum $windowsISO)";

if [ "$localWINISOCHECKSUM" = "$WINISOCHECKSUM" ];then
	logp info "De windows schijf is gevalideerd!"
else
	rm -f $windowsISO
	logp fatal "De gedownloade schijf is corrupt!"
fi
}

manageISO()
{
if isISODownloaded && isISOUptodate; then
	logp info "Uptodate Windows ISO gevonden."
	return 0
else 
	if downloadISO; then
		return 0
	else
		logp fatal "Windows ISO kon niet worden gedownload!"
	fi
fi
}

serveISO()
{
	systemctl start nginx
	if [ $? -gt 0 ]; then
		logp fatal "NGINX kon niet worden gestart!"
	fi

	sleep 100
}

finish(){
	if [ -L $nginxDefaultDirectory ]; then
		rm -f $nginxDefaultDirectory
	fi
	mkdir $nginxDefaultDirectory

	umount -f $windowsMountPoint
}
trap finish EXIT

main()
{
if [ -z "$(dpkg -l | grep -i nginx)" ]; then
	logp info "NGINX aan 't installeren..."
	apt update && apt -y install nginx

	if [ $? -gt 0 ]; then 
		logp fatal "NGINX kon niet worden geïnstalleerd!"
	fi
fi

if [ -z "$(dpkg -l | grep -i ntfs-3g)" ]; then
	logp info "Hardeschijf driver aan 't installeren..."
	apt update && apt -y install ntfs-3g

	if [ $? -gt 0 ]; then 
		logp fatal "Hardeschijfdriver kon niet worden geïnstalleerd!"
	fi
fi

logp info  "Klaarmaken NGINX..."
if [ ! -d $nginxDefaultDirectory ]; then
		logp fatal "NGINX standaardfolder is niet aanwezig!"
	else
		rm -rf $nginxDefaultDirectory
fi

if mountWindowsHarddisk; then
	logp info "Windows installatie gevonden."

	ln -s $windowsISODirectory $nginxDefaultDirectory

	if manageISO; then
		logp info "Klaar om ISO te hosten. Bezig met opstarten NGINX..."
		serveISO
	else
		logp fatal "ISO kon niet worden klaargezet!"
	fi
else
	logp fatal "Windows partitie kon niet worden geopend!"
fi
}

main $@

