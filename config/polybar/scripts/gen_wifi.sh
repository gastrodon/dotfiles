profile=$(netctl list |grep -Po '(?<=\* ).+')
connected=$(nmcli -t -f active,ssid dev wifi | grep -E ^yes | tr ":" "\n\n" | sed '1q;d')

if [ -f /sys/class/net/tun0/dev_id ]; then
	color="F#A3BE8C"
else
	color="F#B48EAD"
fi

if [ "$(echo $profile | wc -c)" -eq 1 ]; then
	profile="_"
fi

echo "%{$color}$profile%{F-}"
