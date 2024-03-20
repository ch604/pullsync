download_marill() { #download the marill program
	[ ! -d /root/bin ] && mkdir -p /root/bin
	wget -q http://files.liquidweb.com/migrations/marill -O /root/bin/marill
	chmod +x /root/bin/marill
	[ ! -s /root/bin/marill ] && ec red "Could not fetch marill, skipping auto-testing." && unset runmarill
}
