summarize() { #summarize the migrations run on this server
	ec yellow "Checking for previous migrations..."
	local oldlist=(`ls -c /home/temp/ | grep "pullsync\." | grep -v "$starttime"`)
	if [ ! ${#oldlist[@]} = 0 ]; then
		ec yellow "Detected ${#oldlist[@]} previous pullsync folders."
		ec yellow "Putting summary of each in $dir/summary.txt..."
		for each in ${oldlist[@]}; do
			local oec=$(awk '/exit code: / {print $NF}' /home/temp/$each/pullsync.log)
			echo -e "---------------\n$each"
			echo "started by $(cat /home/temp/$each/youdidthis)"
			echo "synctype was $(awk '/synctype: / {print $NF}' /home/temp/$each/pullsync.log)"
			echo "exit code $oec indicates:"
			case $oec in
				0) echo "success" ;;
				1) echo "pullsync already running" ;;
				2) echo "missing supporting files" ;;
				3) echo "ssh connection failed" ;;
				4) echo "failed to find userlist" ;;
				5) echo "failed to find domainlist" ;;
				7) echo "user conflicts" ;;
				9) echo "autopilot failure" ;;
				50) echo "getopts got no data from source" ;;
				60) echo "bad command fed to syncprogress" ;;
				70) echo "parallel failed to install" ;;
				80) echo "screen detection failed after ipswap" ;;
				99) echo "exit from menu or non-cpanel source/target" ;;
				120) echo "final sync aborted from failed mysqldumps" ;;
				130) echo "control-c pushed" ;;
				132) echo "tried to migrate mysql 8 into some other mysql version" ;;
				140) echo "pip/pyyaml failed to install" ;;
				400) echo "success (hosts file gen)" ;;
				401) echo "success (marill gen)" ;;
				402) echo "success (dns check)" ;;
				403) echo "success (summarize)" ;;
				404) echo "uninstall complete.... hang on a sec...." ;;
				405) echo "success (webpagetest)" ;;
				406) echo "success (apache benchmark)" ;;
				*) echo "i'm not actually sure..." ;;
			esac
			echo "source ip: $(cat /home/temp/$each/ip.txt)"
			echo "source port: $(cat /home/temp/$each/port.txt)"
			echo "old userlist ($(cat /home/temp/$each/$userlist.txt | wc -w)): $(cat /home/temp/$each/userlist.txt | tr '\n' ' ')"
			echo ""
		done >> $dir/summary.txt
	else
		ec yellow "No old migrations found! Come on, man!"
	fi
	ec green "Done! See output at (cat $dir/summary.txt)"
}
