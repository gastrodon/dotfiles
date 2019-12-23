ssid=$(nmcli -t -f active,ssid dev wifi | egrep ^yes | tr ":" "\n" | sed '2q;d')

connected=$(nmcli -t -f active,ssid dev wifi | egrep ^yes | tr ":" "\n\n" | sed '1q;d')

if [ -f /sys/class/net/tun0/dev_id ]; then
	color="F#00FF00"
else
	color="F#FFFFFF"
fi

if [ $(echo $ssid | wc -c) -eq 1 ]; then
	ssid="_"
fi

echo "%{$color}$ssid%{F-}"
