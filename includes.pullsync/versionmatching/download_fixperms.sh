download_fixperms () { #download the latest fixperms script
	wget -q http://files.liquidweb.com/migrations/fixperms/fixperms.sh -O /home/fixperms.sh
	[ ! -s /home/fixperms.sh ] && ec red "Download of fixperms.sh failed!" | errorlogit 2 && unset fixperms
}
