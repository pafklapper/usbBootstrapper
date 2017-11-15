#!/bin/bash 
# run dit script om de dmideocode informatie aan de installatielijst toe te voegen

installationDirectory=/srv/windowsUsbBootstrapper
cd $installationDirectory

. $installationDirectory/globalFunctions
. $installationDirectory/globalVariables
. $confFile

deviceName="$(dmidecode | grep -A3 '^System Information' | grep "Product Name" | cut -d: -f2)"

newTargetDevicesArray=$targetDevices
newTargetDevicesArray+=($deviceName)

newTargetDevicesString="$(echo "targetDevices=("$(for dev in ${newTargetDevicesArray[@]}; do printf \""$dev"\"; printf ' ';done)")")"

sed -i "/^targetDevices=/c\$newTargetDevicesString/" $confFile
