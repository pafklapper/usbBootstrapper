#!/bin/bash

installationDirectory=/srv/windowsUsbBootstrapper
cd $installationDirectory

. $installationDirectory/globalVariables
. $confFile
. $installationDirectory/globalFunctions

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

isIsoDownloaded()
{
 if [ -d $localIsoDirectory ] && [ -f $localIsoFile ]; then
 	return 0;
 else
 	return 1;
 fi
}

isIsoUptodate()
{
remoteIsoChecksum="$(curl $remoteIsoChecksumUrl 2>/dev/null)"

if [ "$(cat $localIsoChecksumFile)" = "$remoteIsoChecksum" ]; then
		return 0;
	else
		return 1;
	fi
}

downloadIso()
{
mkdir  -p $localIsoDirectory
remoteIsoSize="$(curl $remoteIsoSizeUrl 2>/dev/null)"
remoteIsoChecksum="$(curl $remoteIsoChecksumUrl 2>/dev/null)"

logp info "Het systeem zal nu de geprepareerde Windows schijf downloaden..."
for i in {0..2}; do
	wget $remoteIsoUrl -q -O - | pv --size $remoteIsoSize |  dd of=$localIsoFile
	if [ $? -eq 0 ]; then
		logp info "De windows schijf is succesvol gedownload!"
		sync
		break
	else
		rm -f $localIsoFile
		logp warning "Downloaden mislukt! Poging $i"
	fi
done

logp info "Integriteitscontrole van de gedownloade schijf..."
localIsoChecksum="$(sha256sum $localIsoFile | cut -f1 -d\ )";
echo $localIsoChecksum > $localIsoChecksumFile

if [ "$localIsoChecksum" = "$remoteIsoChecksum" ];then
	logp info "De windows schijf is gevalideerd!"
else
	rm -f $localIsoFile; rm -f $localIsoChecksum
	logp fatal "De gedownloade schijf is corrupt!"
fi
}

manageIso()
{
if isIsoDownloaded && isIsoUptodate; then
	logp info "Uptodate Windows ISO gevonden."
	return 0
else
	while :; do
		if isHostUp; then
		case "$(getHostStatus)" in
			OK)
				if downloadIso; then
					return 0
				else
					logp fatal "Windows ISO kon niet worden gedownload!"
				fi
			;;
			WAIT)
				logp info "De externe host $remoteIsoHost is nog aan het opwarmen. Een moment geduld."
				sleep 60
			;;
			*)
				logp warning "De externe host $remoteIsoHost heeft onbekende status!"
				sleep 60
			;;
		esac
		else
			logp fatal "De externe host $remoteIsoHost is offline! "
		fi

	sleep 1
	done
fi
}

serveIso()
{
	echo OK > $localIsoHostStatusUrl

	if ! systemctl is-active nginx >/dev/null; then
		logp fatal "De lokale webserver is niet online!"
	fi

	localIP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')"

	logp info "Het systeem is actief op $localIP!"
	logp warning "Gebruik de stroomknop op de pc om het systeem af te sluiten!"

	while :; do sleep 1; done
}

finish(){
echo WAIT > $localIsoHostStatusUrl

if [ -L $nginxDefaultDirectory ]; then
	rm -f $nginxDefaultDirectory
fi
mkdir $nginxDefaultDirectory


umount -f $windowsMountPoint
}
trap finish INT TERM EXIT

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

	mkdir  -p $localIsoDirectory && ln -s $localIsoDirectory $nginxDefaultDirectory || logp fatal "Kon de lokale hostfolder niet aanmaken!"
	
	if systemctl start nginx; then
		echo WAIT > $localIsoHostStatusUrl
		logp info "De lokale webserver is online!"
	fi


	if manageIso; then
		logp info "Klaar om ISO te hosten. Bezig met opstarten webserver..."
		if serveIso; then
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

