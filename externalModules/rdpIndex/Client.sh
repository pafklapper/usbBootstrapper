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
. /srv/usbBootstrapper/globalVariables
. /srv/usbBootstrapper/globalFunctions
}

privKey="a3fb1bd7065721ab33505b24cc95021f"
pubKey="24f6b2776aa8af3165d47f2c79600f1c"

primaryPort=10420
secondaryPort=10421

rhost="$1"

retryTimes=12

deviceUuid=""
uuidIndex=""

tmpFile=`mktemp`
localOut=`mktemp`
localIn=`mktemp`

getDeviceUuid()
{
deviceUuid="$(dmidecode -t 4 | grep ID | sed 's/.*ID://;s/ //g')"
return 0
}

primaryPortHandler()
{
echo $pubKey | nc -w2 $rhost $primaryPort

if [ $? -eq 0 ]; then
	echo connected succesfully
	return 0
else 
	return 1
fi
}

secondaryPortHandler()
{
rm -f $localIn; rm -f $localOut
mkfifo $localOut; mkfifo $localIn

if getDeviceUuid; then
	encryptedDeviceUuid="$(echo $deviceUuid | openssl enc -aes-128-cbc -a -salt -pass pass:$privKey)"

	sleep 0.5
	echo connecting with encDevUuid $encryptedDeviceUuid
	( while :; do cat $localIn; done | nc  $rhost $secondaryPort | tee $localOut )&
	bgJob=$!

	sleep 0.5
	echo $encryptedDeviceUuid >> $localIn

	echo tmpfile=
	cat $tmpFile

while :; do
	while read input; do
		echo input=$input
		if echo $input | openssl enc -aes-128-cbc -a -d -salt -pass pass:$privKey 2>&1 >/dev/null;then
			uuidIndex="$(echo $input | openssl enc -aes-128-cbc -a -d -salt -pass pass:$privKey)"
			return 5
		fi
	done < $localOut
	if [ $? -eq 5 ] ; then return 0; fi
	done
return $?
fi
}

#echo foobar | openssl enc -aes-128-cbc -a -salt -pass pass:asdffdsa

#echo U2FsdGVkX1/lXSnI4Uplc6DwDPPUQ/WjHULJoKypTO8= | openssl enc -aes-128-cbc -a -d -salt -pass pass:asdffdsa

cleanup()
{
	rm -f $tmpFile
	rm -f $localOut
	rm -f $localIn

	exit
}

trap cleanup INT TERM EXIT

main()
{

if [ ! -f $rdpIndexFile ]; then
	touch $rdpIndexFile
fi

for i in $(seq 0 $retryTimes)
do
	if primaryPortHandler; then
		secondaryPortHandler
		echo my device index is : $uuidIndex
		echo $uuidIndex > $rdpIndexFile
		exit 0
	fi
	sleep 1
done

exit 1
}

initConstants && initVars &&  main $@
