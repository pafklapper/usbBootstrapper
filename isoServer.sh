#!/bin/bash


windowsMountPoint="/mnt/windows"
windowsISODirectory="$windowsMountPoint/windowsUsbBootstrapper"
windowsISO="$windowsISODirectory/WIN10.ISO.xz"

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
		logp warning "veeee"
		if [ -d $windowsMountPoint/Windows ]; then
			if [ $(df | grep $windowsMountPoint| awk '{ print +$4 }') -gt 10000000 ]; then
			logp fatal "je moeder"
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
	return 1
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
 return 0
}

manageISO()
{
if isIsoDownloaded && isISOUptodate; then
	logp info "Uptodate Windows ISO gevonden."
	return 0
else 
	logp info "Windows ISO zal worden gedownload..."
	if downloadISO; then
		logp info "Windows ISO succesvol gedownload."
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

