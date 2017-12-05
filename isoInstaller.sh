#!/bin/bash
# written by pafklapper
# released under Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License 
# semantic: download iso from server node, than xzcat it unto the laptops harddrive

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


# constants
HOSTHDD=/dev/mmcblk1

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
logp info "Proberen automatisch IP adres van computer die schijf host te verkrijgen..."

currentIP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')"
currentNet="$(echo $currentIP | cut -f 1,2,3 -d .)"

ipSet="$(nmap -T5 --max-parallelism=100 -oG - -n -sn -sP $currentNet.0/24 | awk '/Up$/{print $2}')"

if [ $? -gt 0 ]; then
	logp warning "IP adres kon niet automatisch verkregen worden!"
	return 1
fi


found=0
while read -r candidateIp; do
	if [ "$(curl --max-time 2 -sff $candidateIp/id)" = "usbBootstrapServer" ]; then
		logp info "Moederschip gevonden op $candidateIp!"
		remoteIsoHost=$candidateIp
		found=1
		return 0
	fi
done <<< "$ipSet"

if [ $found = 1 ]; then
	return 0
else
	logp warning "IP adres kon niet automatisch verkregen worden!"
	return 1
fi

#	for i in $(seq 0 255); do
#		candidateIp="$currentNet.$i"
#		if nc -v -n -z -w1 $candidateIp 80 1>/dev/null 2>&1;then
#			if [ "$(curl -sff $candidateIp/id)" = "usbBootstrapper" ]; then
#				logp info "Moederschip gevonden op $candidateIp!"
#				remoteIsoHost=$candidateIp
#				return 0
#			fi
#		fi
#	done
#
#	logp warning "IP adres kon niet automatisch verkregen worden!"
#	return 1
}

getIpManual()
{
logp info "Vul IP-adress handmatig in of druk op de stroomknop op de pc in om opnieuw op te starten."

while :;
do
	printf "IP-adress: "; read  remoteIsoHost
	initVars 

	if isIpValid $remoteIsoHost; then
		#check if host is up and serving
		if  isHostUp && [ -n "$(getHostStatus)" ] ; then
			sed -i '/remoteIsoHost=/c\remoteIsoHost=$remoteIsoHost' $confFile
			return 0
		else
			logp warning "Host $remoteIsoHost is niet beschikbaar! Probeer opnieuw!"
		fi
	else
		echo "Dit is geen correct IP adress. Probeer opnieuw!"
		remoteIsoHost=
	fi
	sleep 1;
done
}

main()
{
currentIP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')"
logp notify "Client active @ $currentIP"

# get or set IP 
if getIpAutomatic; then
	logp info "IP adress werd succesvol automatisch verkregen."
elif getIpManual; then
	logp info "IP werd succesvol handmatig verkregen."
else
	logp fatal "IP adress kon niet worden verkregen!"
fi

# set hostHDD
hostHDD="/dev/$(lsblk -no kname | grep mmc | grep -v -e "p[0-9]" -e "boot[0-9]" -e rpm)"

#echo hostHDD=$hostHDD
#read

if [ ! -b $hostHDD ]; then
	logp fatal "De hardeschijf kon niet worden gevonden! : $hostHDD"

	#echo TESTING! no memory block fail
	#logp warning "De hardeschijf kon niet worden gevonden! : $hostHDD"
fi

while :;
do
	logp info "Begonnen met kopieren van geprepareerde schijf vanaf  $remoteIsoHost ..."

	remoteIsoSize="$(curl $remoteIsoSizeUrl 2>/dev/null)"
	wget $remoteIsoUrl -q -O - | pv --size $remoteIsoSize | xz -T4 -d | dd conv=sparse of=$hostHDD
	#echo TESTING! output to /dev/zero
	#wget $remoteIsoUrl -q -O - | pv --size $remoteIsoSize | xz -T4 -d | dd of=/dev/null

	if [ $? -eq 0 ]; then
		sync
		logp info "Installatie succesvol! druk op een toets om door te gaan."
		logp notify "Installatie voor client $currentIP afgerond!"
		read && logp warning "De computer sluit over vijf seconden af! De computer zal de eerst volgende keer windows verder configureren " && sleep 5 && poweroff
	else
		logp warning "Er is iets fout gegaan! Systeem zal downloaden opnieuw proberen .. "
	fi
done

# now upload the unique device ID and get an RDP file in return

#dmidecode -t 4 | grep ID | sed 's/.*ID://;s/ //g'

}

initConstants && initVars && main $@
