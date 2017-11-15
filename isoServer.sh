#!/bin/bash


windowsMountPoint="/mnt/windows"
windowsISODirectory="$windowsMountPoint/windowsUsbBootstrapper"
windowsISO="$windowsISODirectory/WIN10.ISO.xz"

localISOChecksum="$windowsISODirectory/WIN10.ISO.xz.sha256"

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
remoteISOChecksum="$(curl $WINISOCHECKSUMURL 2>/dev/null)"

if [ "$(cat $localISOChecksum)" = "$remoteISOChecksum" ]; then
		return 0;
	else
		return 1;
	fi
}

downloadISO()
{
mkdir  -p $windowsISODirectory
WINISOSIZE="$(curl $WINISOSIZEURL 2>/dev/null)"
WINISOCHECKSUM="$(curl $WINISOCHECKSUMURL 2>/dev/null)"

logp info "Het systeem zal nu de geprepareerde Windows schijf downloaden..."
for i in {0..2}; do
	wget $WINISOURL -q -O - | pv --size $WINISOSIZE |  dd of=$windowsISO
	if [ $? -eq 0 ]; then
		logp info "De windows schijf is succesvol gedownload!"
		break
	else
		rm -f $windowsISO
		logp warning "Downloaden mislukt! Poging $i"
	fi
done

logp info "Integriteitscontrole van de gedownloade schijf..."
localISOChecksum="$(sha256sum $windowsISO)";
echo $localISOChecksum > $windowsISOChecksum

if [ "$localISOChecksum" = "$WINISOCHECKSUM" ];then
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

	localIP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')"

	logp info "Het systeem is actief op $localIP!"

	while :; do
		logp warning "Druk spatie en dan enter om het systeem af te sluiten!\ "
		read input

		if [ "$input" = ' ' ]; then
			break
		fi
	done
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
		if serveISO; then
			logp endsection
			logp info "Het systeem zal nu worden afgesloten..."
			sleep 3 && shutdown
		else
			return 1
		fi
	else
		logp fatal "ISO kon niet worden klaargezet!"
	fi
else
	logp fatal "Windows partitie kon niet worden geopend!"
fi
}

main $@

