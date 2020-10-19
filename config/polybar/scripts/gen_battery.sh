charged_bar=""
charged_fill=""

if [ $(cat /sys/class/power_supply/BAT0/status) = "Unknown" ]; then
	active_battery="BAT1"
else
	active_battery="BAT0"
fi

charged=$(expr $(cat /sys/class/power_supply/$active_battery/capacity) / 10)
discharged=$(expr 10 - $charged)

if [ $(cat /sys/class/power_supply/$active_battery/status) = "Unknown" ]; then
	charged_bar="?"
else
	charged_bar="|"
fi

while [ "$charged" -ne "0" ]; do
	charged_bars="$charged_bars$charged_bar"
	charged=$(expr $charged - 1)
done

while [ "$discharged" -ne "0" ]; do
	charged_bars="$charged_bars."
	discharged=$(expr $discharged - 1)
done

color="F#B48EAD"

if [ $(cat /sys/class/power_supply/$active_battery/capacity) -lt 10 ]; then
	color="F#BF616A"
fi

if [ $(cat /sys/class/power_supply/$active_battery/status) = "Charging" ]; then
	color="F#A3BE8C"
fi

echo "%{$color}$charged_bars%{F-}"
