ip="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')"

if [ -f /sys/class/net/tun0/dev_id ]; then
	color="#A3BE8C"
else
	color="#B48EAD"
fi

echo "%{F$color}$ip%{F-}"
