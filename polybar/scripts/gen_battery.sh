charged=$(expr $(cat /sys/class/power_supply/BAT0/capacity) / 10)
discharged=$(expr 10 - $charged)

charged_bar=""
charged_fill=""

while [ "$charged" -ne "0" ]; do
	charged_bars="$charged_bars|"
	charged=$(expr $charged - 1)
done

while [ "$discharged" -ne "0" ]; do
	charged_bars="$(echo $charged_bars)."
	discharged=$(expr $discharged - 1)
done

color="F#FFFFFF"

if [ $(cat /sys/class/power_supply/BAT0/capacity) -lt 10 ]; then
	color="F#FF0000"
fi

if [ $(cat /sys/class/power_supply/BAT0/status) = "Charging" ]; then
	color="F#00FF00"
fi

echo "%{$color}$charged_bars%{F-}"
