#!/bin/bash
# written by pafklapper
# released under Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License 
# semantic: download iso from server node, than xzcat it unto the laptops harddrive

initVars()
{
installationDirectory=/srv/windowsUsbBootstrapper
cd $installationDirectory

. $installationDirectory/globalVariables
. $confFile
. $installationDirectory/globalFunctions
}

# constants
HOSTHDD=/dev/mmcblk1
APROXSIZE="3700M"

# ripped from: https://www.linuxjournal.com/content/validating-ip-address-bash-script
function isIpValid()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

getIpAutomatic()
{
	# not written yes
	return 1
}

getIpManual()
{
logp info "Vul IP-adress handmatig in of druk op de stroomknop op de pc in om opnieuw op te starten."

while :;
do
	read -p "IP adres: " remoteIsoHost

	echo $remoteIsoHost
	read

	if isIpValid $remoteIsoHost; then
		#check if host is up and serving
		if  isHostUp && [ -n "$(getHostStatus)" ] ; then
			sed -i '/remoteIsoHost=/c\remoteIsoHost=$remoteIsoHost' $confFile
			initVars
			return 0
		else
			logp warning "Host $localIsoHost is niet beschikbaar! Probeer opnieuw!"
		fi
	else
		echo "Dit is geen correct IP adress. Probeer opnieuw!"
		localIsoHost=
	fi
	sleep 1;
done
}

main()
{

# get or set IP 
if getIpAutomatic; then
	logp info "IP adress werd succesvol automatisch verkregen."
elif getIpManual; then
	logp info "IP werd succesvol handmatig verkregen."
else
	logp fatal "IP adress kon niet worden verkregen!"
fi

#check for HOSTHDD
if [ ! -b $HOSTHDD ]; then
	#logp fatal "De hardeschijf kon niet worden gevonden! : $HOSTHDD"

	echo testing: no memory block fail
	logp warning "De hardeschijf kon niet worden gevonden! : $HOSTHDD"
fi

while :;
do
	logp info "Begonnen met kopieren van geprepareerde schijf vanaf  $localIsoHost ..."

	remoteIsoSize="$(curl $remoteIsoSizeUrl 2>/dev/null)"
	#wget $remoteIsoUrl -q -O - | pv --size $remoteIsoSize | xz -d | dd of=$HOSTHDD
	echo TESTING: out put to /dev/zero
	wget $remoteIsoUrl -q -O - | pv --size $remoteIsoSize | xz -d | dd of=/dev/null
	if [ $? -eq 0 ]; then
		sync
		logp info "Installatie succesvol! druk op een toets om door te gaan."
		read && logp warning "De computer herstart in vijf seconden!.. " && sleep 5 && reboot
	else
		logp warning "Er is iets fout gegaan! Systeem zal downloaden opnieuw proberen .. "
	fi
done

# now upload the unique device ID and get an RDP file in return

#dmidecode -t 4 | grep ID | sed 's/.*ID://;s/ //g'

}

initVars
main
