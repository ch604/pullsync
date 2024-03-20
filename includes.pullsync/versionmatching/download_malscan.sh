download_malscan() { #download the malware scanning tool
	wget -q -O /root/migration_scan http://cmsv.liquidweb.com/migration_scan
	chmod +x /root/migration_scan
	[ ! -x /root/migration_scan ] && ec red "Download of migraton_scan failed! Not scanning!" | errorlogit 2 && unset malwarescan
}
