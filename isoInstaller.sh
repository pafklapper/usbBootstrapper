#!/bin/bash
# written by pafklapper
# released under Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License 
# semantic: download iso from server node, than xzcat it unto the laptops harddrive

# constants
HOSTHDD=/dev/mmcblk1
APROXSIZE="3700M"

# initialize vars with empty value
IP=
STATUS=

# ripped from: https://www.linuxjournal.com/content/validating-ip-address-bash-script
function valid_ip()
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

isHostOnline()
{
	STATUS="$(timeout 5 curl -q http://$1/status 2>/dev/null)"
	if [ $? -eq 0 ]; then
		return 0
	else
		echo "No host available @ $1!"
		return 1
	fi
}

getIpAutomatic()
{
	# not written yes
	return 1
}

getIpManual()
{
while :;
do
	read -p "Enter IP-Adress: " IP

	if valid_ip $IP; then
		#check if host is up and serving
		if  isHostOnline $IP; then
			return 0
		else
			echo "Host at $IP is not reachable!"
		fi
	else
		echo "Invalid IPadress! Try Again:"
		IP=
	fi
	sleep 1;
done
}

waitForNetwork()
{
while :;
do
	timeout 5 ping -c1 google.com 1>/dev/null 2>/dev/null
	if [ $? -eq 0 ]; then
		echo "Network is accessible!"
		return 0
	fi

	sleep 1 
done


}



main()
{
# wait for network
echo "Waiting for network to come online..." && waitForNetwork

# get or set IP 
if  getIpAutomatic || ! getIpManual; then
	echo "FATAL: Could not get IPadress!"
	echo 1
fi

#check for HOSTHDD
if [ ! -b $HOSTHDD ]; then
	echo "FATAL: The harddisk was not found! : $HOSTHDD"
	exit 1;
fi

while :;
do
	echo "Copying reference image over from $IP. This could take a while ..."
	wget $IP/WIN10.ISO.xz -q -O - | pv --size $APROXSIZE | xz -d | dd of=$HOSTHDD
	if [ $? -eq 0 ]; then
		echo "Syncing disks.."
		sync
		echo "Installation complete! Press any key to continue "
		read && echo "Rebooting in 5 seconds.. " && sleep 5 && reboot
	else
		echo "An error happened! Trying again .. "
	fi
done

# now upload the unique device ID and get an RDP file in return

#dmidecode -t 4 | grep ID | sed 's/.*ID://;s/ //g'

}

main
