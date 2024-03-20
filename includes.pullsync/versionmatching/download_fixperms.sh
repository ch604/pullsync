download_fixperms () { #download the latest fixperms script
	wget -q https://raw.githubusercontent.com/ch604/fixperms/master/fixperms.sh -O /home/fixperms.sh
	[ ! -s /home/fixperms.sh ] && ec red "Download of fixperms.sh failed!" | errorlogit 2 && unset fixperms
}
