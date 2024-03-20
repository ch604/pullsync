download_versionfinder() {
	[ ! -d /root/bin ] && mkdir -p /root/bin
	if (timeout 1 bash -c 'echo > /dev/tcp/scripts.ent.liquidweb.com/80') &>/dev/null; then
		wget -q http://scripts.ent.liquidweb.com/versionfinder -O /root/bin/versionfinder
		chmod +x /root/bin/versionfinder
		[ ! "$(which versionfinder 2> /dev/null)" ] && ec red "Download of versionfinder failed!" && unset versionscan
	else
		ec red "Download of versionfinder failed!" && unset versionscan
	fi
}
