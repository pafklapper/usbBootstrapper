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

cat<<EOF
 ___           _        _ _       _   _      
|_ _|_ __  ___| |_ __ _| | | __ _| |_(_) ___ 
 | || '_ \/ __| __/ _\` | | |/ _\` | __| |/ _ \ 
 | || | | \__ \ || (_| | | | (_| | |_| |  __/
|___|_| |_|___/\__\__,_|_|_|\__,_|\__|_|\___|

** Installatieprogramma voor minilaptops op Siriusscholen
** Geschreven door Stan Verschuuren
** Dit werk valt onder het Creative Commons Attribution-NonCommercial-ShareAlike licensie
EOF

logp beginsection
logp info  "wachten op de netwerkverbinding... " && waitForNetwork

# selfupdate
if ! isGitRepoUptodate; then
	logp info "Updates installeren. Dit kan even duren..."
	( cd $installationDirectory && git pull )
	$installationDirectory/install.sh
	if [ $? -eq 0 ]; then
		logp info "Installeren van updates gelukt. De computer start in vijf seconden opnieuw op!"
		sleep 5 && reboot
	fi
fi

logp info "joepie alles flex"
