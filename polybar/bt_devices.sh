if [ $(bluetoothctl show | grep "Powered: yes" | wc -c) -eq 0 ]; then
	color="#666666"
else
	color="#B4BEAD"
fi

connection=$(bluetoothctl info | grep Alias | cut -d':' -f2)
if [ $(echo $connection | wc -c) -eq 1 ]; then
	connection="_"
fi

echo "%{F$color}$connection%{F-}"
