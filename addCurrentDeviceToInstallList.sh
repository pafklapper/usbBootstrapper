#!/bin/bash 
# run dit script om de dmideocode informatie aan de installatielijst toe te voegen

installationDirectory=/srv/windowsUsbBootstrapper
cd $installationDirectory

. $installationDirectory/globalFunctions
. $installationDirectory/globalVariables
. $confFile

deviceName="$(dmidecode | grep -A3 '^System Information' | grep "Product Name" | cut -d: -f2)"

if [ -n "$(echo $targetDevices | grep $deviceName)" ]; then
	logp info "Device already enrolled!"
	exit 0
fi

newTargetDevicesArray=$targetDevices
newTargetDevicesArray+=($deviceName)

newTargetDevicesString="$(echo "targetDevices=("$(for dev in ${newTargetDevicesArray[@]}; do printf \""$dev"\"; printf ' ';done)")")"

sed -iE '/^targetDevices=/d' $confFile
echo $newTargetDevicesString >> $confFile

logp info "Succesfully enrolled device!"

#sed -i "/^targetDevices=/c\ $newTargetDevicesString/" $confFile
