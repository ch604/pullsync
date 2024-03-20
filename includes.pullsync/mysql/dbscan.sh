dbscan(){ #scan passed database stream for malware, append file if detected
	echo $tb | grep -Eq -e '*_redirection_404' -e '*_redirection_logs' -e '*_wfHits' && return
	if cat | grep -Eiq -e 'eval[ ]?\(' -e 'base64_decode[ ]?\(' -e 'gzinflate[ ]?\(' -e 'error_reporting[ ]?\((0|off)\)' -e 'shell_exec[ ]?\(' -e 'str_rot13[ ]?\('; then
		echo "$db.$tb" >> $dir/dbmalware.txt
	fi
}
