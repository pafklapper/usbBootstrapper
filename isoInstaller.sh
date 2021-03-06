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
	logp warning "IP-adres kon niet automatisch verkregen worden!"
	return 1
fi

while read -r candidateIp; do
	if [ "$(curl --max-time 2 -sff $candidateIp/id)" = "usbBootstrapServer" ]; then
		logp info "Moederschip gevonden op $candidateIp!"
		remoteIsoHost=$candidateIp
		return 0
	fi
done <<< "$ipSet"

if [ $? -eq 26 ]; then
	return 0
else
	logp warning "IP-adres kon niet automatisch verkregen worden!"
	return 1
fi
}

getIpManual()
{
logp info "Vul IP-adres handmatig in of druk op de stroomknop op de pc in om opnieuw op te starten."

while :;
do
	printf "IP-adres: "; read  remoteIsoHost
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
		echo "Dit is geen correct IP-adress. Probeer opnieuw!"
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
	logp info "IP-adres werd succesvol automatisch verkregen."
elif getIpManual; then
	logp info "IP-adres werd succesvol handmatig verkregen."
else
	logp fatal "IP-adres kon niet worden verkregen!"
fi

# ip should be updated with new $remoteIsoHost value
initVars

# set hostHDD
hostHDD="/dev/$(lsblk -no kname | grep mmc | grep -v -e "p[0-9]" -e "boot[0-9]" -e rpm)"

if [ ! -b $hostHDD ]; then
	logp fatal "De hardeschijf kon niet worden gevonden! : $hostHDD"
fi

while :;
do
	logp info "Begonnen met kopieren van geprepareerde schijf vanaf  $remoteIsoHost ..."

	remoteIsoSize="$(curl $remoteIsoSizeUrl 2>/dev/null)"
	wget $remoteIsoUrl -q -O - | pv --size $remoteIsoSize | xz -T4 -d | dd of=$hostHDD

	if [ $? -eq 0 ]; then
		sync
		break
	else
		logp warning "Er is iets fout gegaan! Systeem zal downloaden opnieuw proberen .. "
	fi
done

if [ ! $? -eq 0 ]; then exit 1; fi

# here code should be include to update rdp login values to reflect remotelogins made available by Unilogic

if $installationDirectory/externalModules/rdpIndex/Client.sh "$remoteIsoHost"; then
	logp info "Succesvol RDP index verkregen!"
	index="$(cat $rdpIndexFile)"

rdpTemplateFile="$installationDirectory/Verbinding met schoolnetwerk.rdp"
rdpTmpFile=`mktemp`
cat "$rdpTemplateFile" > "$rdpTmpFile"

sed -i "/^username/c\username:s:sirius\\\brinkLaptop$index" $rdpTmpFile 

if ! which partprobe; then apt -y install parted; fi

partprobe $hostHDD

mkdir -p /mnt/windows

mount "$hostHDD"p4 /mnt/windows 

cat "$rdpTmpFile" > "/mnt/windows/Users/de Brink/Desktop/Verbinding met Schoolnetwerk.rdp"

else
	logp warning "Kon RDP index niet verkrijgen!"
fi

efibootmgr -o 2001,0

		logp info "Installatie succesvol! druk op een toets om door te gaan."
		logp notify "Installatie voor client $currentIP afgerond!"
		read && logp warning "De computer sluit over vijf seconden af! De computer zal de eerst volgende keer windows verder configureren " && sleep 5 && poweroff

}

initConstants && initVars && main $@
