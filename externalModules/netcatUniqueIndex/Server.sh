#!/bin/bash
#set -euo pipefail
#IFS=$'\n\t'

tmpFile=`mktemp`
localIn=`mktemp`
localOut=`mktemp`

privKey="a3fb1bd7065721ab33505b24cc95021f"
pubPass="24f6b2776aa8af3165d47f2c79600f1c"
primaryPort=10420
secondaryPort=10421

# bash run options
set -o pipefail


secondaryPortTimeOut=5
dbFile=database
uuidIndex=

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




isUUIDKnown()
{
	local uuidString="$(cat $dbFile | grep $1 )"

	if [ -n "$uuidString" ]; then
		return 0
	else
		return 1
	fi
}

getUUIDIndex()
{
	local uuidString="$(cat $dbFile | grep $1 )"

	uuidIndex="$(echo $uuidString | cut -f1 -d:)"
	return 0
}

addUUIDToDatabase()
{
indexArray=()

if [ "$(cat $dbFile | wc -l)" -gt 0 ];then
	while read uuidString; do
		indexArray+=("$(echo $uuidString | cut -f1 -d:)")
	done < $dbFile

	#as per:https://stackoverflow.com/questions/12744245/bash-how-to-find-the-highest-number-in-array
	highestIndex=${indexArray[0]}
	for n in "${indexArray[@]}" ; do
    	((n > highestIndex)) && highestIndex=$n
	done

	uuidIndex="$(($highestIndex + 1))"
	echo "$uuidIndex:$1" >> $dbFile
else
	uuidIndex=0
	echo "$uuidIndex:$1" >> $dbFile
fi
}


# encryption as per: https://unix.stackexchange.com/questions/291302/password-encryption-and-decryption
#echo foobar | openssl enc -aes-128-cbc -a -salt -pass pass:asdffdsa
#echo U2FsdGVkX1/lXSnI4Uplc6DwDPPUQ/WjHULJoKypTO8= | openssl enc -aes-128-cbc -a -d -salt -pass pass:asdffdsa

primaryPortHandler()
{
while :; do
	timeout 2 nc -l -p $primaryPort | head -n1 | tr -cd '[:alnum:] [:space:]' > $tmpFile

	if [ "$(< $tmpFile)" = "$pubPass" ]; then
		echo "Connected to authenticated user!"
		break
	fi
	cat /dev/null > $tmpFile
done

return 0
}

secondaryPortHandler()
{
rm -f $localIn; rm -f $localOut
mkfifo $localIn; mkfifo $localOut

( trap "kill 0" SIGINT; while :; do cat $localIn; done | nc -l -p $secondaryPort | tee $localOut 2>&1 1>/dev/null ) &

while :; do
while read inputString; do
	echo $inputString | openssl enc -aes-128-cbc -a -d -salt -pass pass:$privKey  2>&1 1>/dev/null

	if [ $? -eq 0 ]; then
		decryptedString="$(echo $inputString | openssl enc -aes-128-cbc -a -d -salt -pass pass:$privKey 2>/dev/null)" 
		echo "Got string: $inputString"
		echo "Decrypted string: $decryptedString"

		if [ -n "$decryptedString" ]; then
			if isUUIDKnown $decryptedString; then
				getUUIDIndex $decryptedString
		
				echo "Device with uuid $decryptedString is known with index $uuidIndex"
				echo $uuidIndex | openssl enc -aes-128-cbc -a -salt -pass pass:$privKey >> $localIn
			else
				addUUIDToDatabase $decryptedString
				echo "Adding new device UUID $decryptedString with index $uuidIndex to database!"
				echo $uuidIndex | openssl enc -aes-128-cbc -a -salt -pass pass:$privKey >> $localIn
			fi
			sleep 0.5 && return 0

		else
			echo "Decrypted string is zero!"
		fi

	else
			echo "Received bogus data"
	fi
done < $localOut
done

retCode=$?
pkill -x nc
kill %2
kill %1
kill  $bgJob1 1>/dev/null 2>/dev/null
return $retCode
}

#echo foobar | openssl enc -aes-128-cbc -a -salt -pass pass:asdffdsa
#echo U2FsdGVkX1/lXSnI4Uplc6DwDPPUQ/WjHULJoKypTO8= | openssl enc -aes-128-cbc -a -d -salt -pass pass:asdffdsa

cleanup()
{
	rm -f $tmpFile
	rm -f $localOut
	rm -f $localIn

	kill %1
	kill %2
	exit
}
trap cleanup INT TERM EXIT

main()
{

if [ ! -f $rdpIndexFile ]; then
	touch $rdpIndexFile
fi

if [ ! -f $dbFile ]; then
	touch $dbFile
fi

while :; do
	if primaryPortHandler; then
		(
			if secondaryPortHandler; then
		 		echo "Finished!"
			else
				echo "Something went wrong!"
			fi
		) &
		
		sleep $secondaryPortTimeOut; kill %1
	fi

	pkill -9 -x nc

echo end of loop!
done
}

main $@
