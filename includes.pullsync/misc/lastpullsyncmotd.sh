lastpullsyncmotd() { #change the motd to the current pull info
	if grep -q pullsync /etc/motd; then #only update if motd has been added already
		ec yellow "Updating motd with start time..."
		grep -q "Last\ pullsync" /etc/motd && sed -i '/^Last\ pullsync/d' /etc/motd #remove old runtime
		echo "Last pullsync ($synctype) (${ticket:-noticket}) started at: $starttime" >> /etc/motd
	fi
}
