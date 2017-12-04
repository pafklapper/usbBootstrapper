#!/bin/bash

# bash run options
set -o pipefail

initConstants()
{
confFile=/etc/usbBootstrapper.config

logFile=/root/winUsbBootstrapper.log
. $confFile
}

initVars()
{
installationDirectory="$(dirname $(realpath "$0"))"
. $installationDirectory/globalVariables
. $installationDirectory/globalFunctions
}

mountWindowsHarddisk()
{
blkid|grep ntfs|while read ntfsLine; do
	ntfsBlk="$(echo $ntfsLine|cut -d: -f1)"
	if [ -b $ntfsBlk ]; then
		mkdir -p $windowsMountPoint
		mount -o remove_hiberfile $ntfsBlk $windowsMountPoint

		if [ $? -gt 0 ]; then
			logp warning "Er trad een fout op bij het inladen van de hardeschijf! Poging tot reparatie ..."
			umount -f $ntfsBlk
			ntfsfix -b -d $ntfsBlk
			if  [ $? -eq 0 ]; then
				logp info "Hardeschijf werd succesvol gerepareerd!"
			else
				logp fatal "De hardeschijf van deze computer is kapot en kan niet gerepareerd worden. Probeer een andere computer!"
			fi
		else
			if [ -d $windowsMountPoint/Windows ]; then
				if [ $(df | grep $windowsMountPoint| awk '{ print +$4 }') -gt 10000000 ]; then
					return 0
				else
					logp fatal "Deze computer heeft niet genoeg ruimte om de Windows schijf te kunnen hosten. Probeer een andere computer!"
				fi
			else
				umount $windowsMountPoint
			fi
		fi
	else
		logp fatal "Scriptfout in blokherkenning: variabele \$ntfsblk heeft invalide waarde $ntfsBlk "
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

isIsoValid()
{
logp info "Integriteitscontrole van de gedownloade schijf..."
localIsoChecksum="$(sha256sum $localIsoFile | cut -f1 -d\ )";
echo $localIsoChecksum > $localIsoChecksumFile

if [ "$localIsoChecksum" = "$remoteIsoChecksum" ];then
	return 0 
else
	return 1
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

if isIsoValid;then
	# update size
	echo $remoteIsoSize > $localIsoSizeFile
	logp info "De windows schijf is gevalideerd!"
else
	rm -f $localIsoFile; rm -f $localIsoChecksum
	logp fatal "De gedownloade schijf is corrupt!"
fi
}

acquireIso()
{
if isIsoDownloaded && isIsoUptodate && isIsoValid; then
	logp info "Uptodate en valide Windows ISO gevonden."
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

	currentIP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')"

	logp info "Het systeem is actief @ $currentIP!"
	logp notify "Server active @ $currentIP"
	logp warning "Gebruik de stroomknop op de pc om het systeem af te sluiten!"

	while :; do
		read input
		if [ "$input" = "stop" ]; then
			exit 1
		fi
		sleep 1
	done
}

finish(){
echo WAIT > $localIsoHostStatusUrl

if [ -L $nginxDefaultDirectory ]; then
	rm -f $logFileSymlink
	rm -f $nginxDefaultDirectory
fi
mkdir $nginxDefaultDirectory

# twice for the new non-symlink default folder
echo WAIT > $localIsoHostStatusUrl
ln -s $logHtmlFile $logFileSymlink

rm -rf $tempDir
umount -f $windowsMountPoint
}
trap finish INT TERM EXIT

main()
{
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
		echo usbBootstrapper > $localIsoHostId
		rm -f $logFileSymlink 2>&1 >/dev/null
		ln -s $logHtmlFile $logFileSymlink
		currentIP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')"
		logp info "De lokale webserver is online @ $currentIP!"
	fi


	if acquireIso; then
		logp info "Klaar om ISO te hosten. Bezig met opzetten webserver..."
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

initConstants && initVars && main $@

