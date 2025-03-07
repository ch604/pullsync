download_malscan() { #download the malware scanning tool
	wget -q -O /root/migration_malware_scan https://raw.githubusercontent.com/marcocesarato/PHP-Antimalware-Scanner/master/dist/scanner --no-check-certificate
	[ ! -s /root/migration_malware_scan ] && ec red "Download of migraton_malware_scan failed! Not scanning!" | errorlogit 2 root && unset malwarescan
}
