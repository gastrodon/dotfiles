if test -f /sys/class/net/tun0/dev_id; then
	color="%{F#00FF00}"
else
	color="%{F#FF0000}"
fi

echo "$(echo $color)vpn%{F-}"
