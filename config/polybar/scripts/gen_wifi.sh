profile=$(netctl list |grep -Po '(?<=\* ).+')

if [ -f /sys/class/net/tun0/dev_id ]; then
	color="F#A3BE8C"
else
	color="F#B48EAD"
fi

# TODO check if profile is empty [ -e "$profile"]
if [ ! "$(netctl is-active $profile)" = 'active' ]; then
	profile="_"
fi

echo "%{$color}$profile%{F-}"
