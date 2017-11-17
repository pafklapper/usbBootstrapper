#!/bin/bash
# written by pafklapper
# released under Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License 

installationDirectory=/srv/windowsUsbBootstrapper
cd $installationDirectory

. $installationDirectory/globalFunctions
. $installationDirectory/globalVariables
. $confFile

# wait for systemd to finish printing bootmessages
sleep 2 && clear

echo -e "\e[91m ___           _        _ _       _   _"
echo -e "\e[91m|_ _|_ __  ___| |_ __ _| | | __ _| |_(_) ___ "
echo -e "\e[91m | || '_ \/ __| __/ _\` | | |/ _\` | __| |/ _ \ "
echo -e "\e[91m | || | | \__ \ || (_| | | | (_| | |_| |  __/"
echo -e "\e[91m|___|_| |_|___/\__\__,_|_|_|\__,_|\__|_|\___|"
echo -e "\n"
echo -e "\e[91m** Installatieprogramma voor minilaptops op Siriusscholen"
echo -e "\e[91m** Geschreven door Stan Verschuuren"
echo -e "\e[91m** Dit werk valt onder het Creative Commons Attribution-NonCommercial-ShareAlike licensie\e[0m"

isHostTargetDevice()
{
	sysInfo="$(dmidecode | grep -A3 '^System Information')"

	for device in ${targetDevices[@]}; do 
		if [ -n "$(echo "$sysInfo" | grep "$device")" ];then
			return 0
		fi
	done
	return 1
}

main()
{
logp beginsection
logp info  "wachten op de netwerkverbinding... " && waitForNetwork

# selfupdate
if ! isGitRepoUptodate; then
	logp info "Updates installeren. Dit kan even duren..."
	apt update && apt upgrade -y
	( cd $installationDirectory && git pull )
	$installationDirectory/install.sh
	if [ $? -eq 0 ]; then
		logp endsection
		logp info "Installeren van updates gelukt. De computer start in vijf seconden opnieuw op!"
		sleep 5 && reboot
	else
		logp fatal "De computer moet opnieuw opgestart worden!"
	fi
fi

local isError
if isHostTargetDevice; then
	logp info "Dit apparaat zal van de Windows installatie voorzien worden!"
	$installationDirectory/isoInstaller.sh
	isError=$?
else
	logp info "Dit apparaat zal de installatieschijf hosten!"
	$installationDirectory/isoServer.sh
	isError=$?
fi

if [ $isError -gt 0 ]; then
	logp endsection
	logp fatal "Er is iets verschrikkelijk fout gegaan! :("
fi
}

tee -a $logFile | main $@ | tee -a $logFile
