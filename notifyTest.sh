#!/bin/bash	
TELEGRAMTOKEN="493444548:AAGFeb28ki0c8y-hedQga10oY5PBM18NMbo"
	
	# as ripped from: https://www.forsomedefinition.com/automation/creating-telegram-bot-notifications/
		curlTimeOut="10"
		CHATID="-$(curl --max-time $curlTimeOut "https://api.telegram.org/bot$TELEGRAMTOKEN/getUpdates" | jq '.' | grep '"id"' | head -n1 | grep -o '[0-9]\+')" 
		URL="https://api.telegram.org/bot$TELEGRAMTOKEN/sendMessage"
		TEXT="$1"

echo CHATID=$CHATID
echo URL=$URL
echo TEXT=$TEXT

		curl -s --max-time $curlTimeOut -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT" $URL >/dev/null

