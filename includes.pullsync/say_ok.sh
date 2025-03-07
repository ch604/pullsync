say_ok() { #say enter to continue, or proceed if autopilot
	[ "$autopilot" ] && ec cyan "Running on autopilot! Proceeding!" && sleep 1 && return;
	ec lightCyan "Press enter to continue."
	rd
}
