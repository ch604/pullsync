#!/bin/bash
# pullsync.sh
# by awalilko@liquidweb.com
# based on initialsync by abrevick@liquidweb.com and various other migrations team contributors; thank you!
# https://github.com/ch604/pullsync

# last updated: Jun 11 2020
version="7.5.7"

###############################
# ensure supporting files exist
###############################

#done before pid check, as there would probably not be a running pullsync if it had no supporting files
if [ ! -d /root/includes.pullsync/ ]; then
	echo "Missing supporting files! Downloading..."
	if host github.com &>/dev/null; then
		wget -q https://github.com/ch604/pullsync/archive/master.zip -O /root/pullsync-master.zip
		unzip /root/pullsync-master.zip pullsync-master/includes.pullsync/* -d /root/
		mv /root/pullsync-master/includes.pullsync /root/
		rm -r /root/pullsync-master
		rm -f /root/pullsync-master.zip
	else
		echo "Couldn't resolve github.com to download supporting files!"
		exit 2
	fi
fi

###################
# include variables
###################

source /root/includes.pullsync/variables.sh

#########
# startup
#########

#ensure bash is used
[ "$(ps h -p "$$" -o comm)" != "bash" ] && exec bash $0 $*

#log IP of ssh user who ran script (or if ran locally). compat with sudo users and screen sessions.
sshpid=${pid}
sshloop=0
while [ "$sshloop" = "0" ]; do
	if [ "$(strings /proc/${sshpid}/environ | grep ^SSH_CLIENT)" ]; then
		read sshClientIP sshClientSport sshClientDport <<< $(strings /proc/${sshpid}/environ | grep ^SSH_CLIENT | cut -d= -f2)
		sshloop=1
	else
		sshpid=$(cat /proc/${sshpid}/status | grep PPid | awk '{print $2}')
		[ "$sshpid" = "0" ] && sshClientIP="localhost" && sshloop=1 #exit loop if we get too far up the tree
	fi
done

#make sure there is no other running pullsync.
if [ -f "$pidfile" ]; then
	echo "Found existing pullsync process id `cat $pidfile` in $pidfile, double check that another sync isnt running. exiting..."
	exit 1
fi

# check for newer version of script
if [ $autoupdate = 1 ]; then
	if host githubusercontent.com &>/dev/null; then
		server_version=$(curl -s -r0-250 https://raw.githubusercontent.com/ch604/pullsync/master/pullsync.sh |grep ^version= | sed -e 's/^version="\([0-9.DEVmf]*\)"/\1/')
		echo "Detected server version as $server_version"
		if [[ $server_version =~ $valid_version_format ]]; then # check for a valid version format
			if [ ! $version = `echo -e "$version\n$server_version" | sort -V | tail -1` ]; then
				echo $version is less than server $server_version, downloading new version to /root/pullsync.sh and executing.
				wget -q https://github.com/ch604/pullsync/archive/master.zip -O /root/pullsync-master.zip
				unzip /root/pullsync-master.zip pullsync-master/includes.pullsync/* -d /root/
				unzip /root/pullsync-master.zip pullsync-master/pullsync.sh -d /root/
				mv /root/pullsync-master/includes.pullsync /root/
				rm -r /root/pullsync-master
				rm -f /root/pullsync-master.zip
				chmod 700 /root/pullsync.sh
				sleep .25
				exec bash /root/pullsync.sh $@
			else
				echo $version is equal or greater than server $server_version
			fi
		else
			echo "Script version on github.com is not in expected format, problem with the server? Continuing afer a few seconds..."
			echo "Detected version as $server_version"
			sleep 3
		fi
	else
		echo "Couldn't resolve host githubusercontent.com to check for updates."
	fi
fi

#start in screen
if [ ! "${STY}" ]; then
	echo "Warning! Not in screen! Attempting to restart in an interactive screen session..."
	chmod 755 /var/run/screen
	sleep .25
	screen -S $scriptname bash -c "bash $0 $*; bash"
	exit 0
fi

#this group of commands makes sure we are on a licensed cpanel server. outside of a function so we quit early if non-cpanel.
[ ! -f /etc/wwwacct.conf ] && echo "/etc/wwwacct.conf not found! Not a cpanel server?" && exit 99
cpanel_main_ip=`grep "^ADDR\ [0-9]" /etc/wwwacct.conf | awk '{print $2}' | tr -d '\n'`
[ "$cpanel_main_ip" = "" ] && cpanel_main_ip=`cat /var/cpanel/mainip`
[ "$cpanel_main_ip" = "" ] && echo "Could not detect main IP from /etc/wwwacct.conf or /var/cpanel/mainip! Ensure the main IP is set up in WHM?" && exit 99

# initalize working directory. $dir is a symlink to $dir.$starttime from last migration
[ -d "$dir" ] && rm -f $dir # remove old symlink
[ -d $dir.$starttime ] && echo "ERROR: $dir.$starttime already exists! Did you go back in time?" && exit 1
mkdir -p -m600 "$dir.$starttime"
ln -s "$dir.$starttime" "$dir"

# quit if something went really wrong
[ ! -d "$dir" ] && echo "ERROR: could not find $dir!"  && exit 1
mkdir $dir/tmp $dir/log
echo "$starttime" > $dir/starttime.txt
/bin/ls -A /var/cpanel/users | egrep -v "^HASH" > $dir/existing_users.txt

###################
# include functions
###################

source /root/includes.pullsync/pullsync_functions.sh

#trap control c keypress and pass it to control_c()
trap control_c SIGINT

#create lock file after bash function include
echo "$pid" > "$pidfile"
echo "${sshClientIP}" > $dir/youdidthis
printf "\e]0; pullsync-$(hostname) \a" 1>&2

###############
# startup logic
###############

#export functions for parallel
export -f packagefunction rsync_homedir hosts_file ec ecnl rsync_homedir_wrapper rsync_email mysql_dbsync mysql_dbsync_2 malware_scan logit ts sssh install_ssl resetea4versions sanitize_dblist nameserver_registrar eternallog stderrlogit nonhuman wpt_speedtest awkmedian ab_test errorlogit user_mysql_listgen wpt_initcompare finalfunction processprogress dbscan apache_user_includes
export dir user_total remainingcount sshargs ip remote_tempdir rsyncargs old_main_ip ded_ip_check single_dedip synctype rsync_update rsync_excludes hostsfile hostsfile_alt nocolor black grey red lightRed green lightGreen brown yellow blue lightBlue purple lightPurple cyan lightCyan white greyBg dblist_restore fcgiconvert phpextrafail comment_crons malwarescan defaultea4profile log solrver apacheextrafail fixperms starttime mysqldumpopts errlog dbbackup_schema initsyncwpt dopgsync

# start the script after functions are defined.
validate_license #make sure cpanel is licensed
installsupport #install all the things you need to function
ithinkimalonenow #warn if anyone else is on the machine
if [[ x == x"$@" ]]; then #if there are no arguments passed, run main()
	main
else
	argumentcheck "$@"
	automain
fi
#you made it to the end, good job!
