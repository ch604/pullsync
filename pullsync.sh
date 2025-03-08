#!/bin/bash
# pullsync.sh
# awalilko@liquidweb.com
# based on initialsync by abrevick@liquidweb.com and various other migrations team members; thank you!
# https://github.com/ch604/pullsync

# last updated: Mar 06 2025
version="9.0.0"

############
# root check
############

[ ! "$(whoami)" = "root" ] && echo "Need to run as root!" && exit 1

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

####################################
# secure files and include variables
####################################

chmod 700 "$0"
find /root/includes.pullsync/ -type f -name "*.sh" -exec chmod 600 {} \;
find /root/includes.pullsync/ -type d -exec chmod 750 {} \;
# shellcheck disable=SC1091
source /root/includes.pullsync/variables.sh

#########
# startup
#########

#ensure bash is used
[ "$(ps -h -p "$$" -o comm)" != "bash" ] && exec bash "$0" "$*"

#log IP of ssh user who ran script (or if ran locally). compat with sudo users and screen sessions.
sshpid=${pid}
sshloop=0
while [ "$sshloop" = "0" ]; do
	if strings "/proc/$sshpid/environ" | grep -q ^SSH_CLIENT; then
		read -r sshClientIP sshClientSport sshClientDport < <(strings "/proc/$sshpid/environ" | awk -F= '/^SSH_CLIENT/ {print $2}')
		sshloop=1
	else
		sshpid=$(awk '/PPid/ {print $2}' "/proc/$sshpid/status")
		[ "$sshpid" = "0" ] && sshClientIP="localhost" && sshloop=1 #exit loop if we get too far up the tree
	fi
done

#make sure there is no other running pullsync.
if [ -f "$pidfile" ]; then
	echo "Found existing pullsync process id $(cat "$pidfile") in $pidfile, double check that another sync isnt running. exiting..."
	exit 1
fi

# check for newer version of script
if [ "$autoupdate" = 1 ]; then
	if host github.com &>/dev/null; then
		server_version=$(curl -s https://raw.githubusercontent.com/ch604/pullsync/master/pullsync.sh |grep ^version= | sed -e 's/^version="\([0-9.]*\)"/\1/')
		echo "Detected server version as $server_version"
		if [[ $server_version =~ $valid_version_format ]]; then # check for a valid version format
			if [ ! $version = "$(echo -e "$version\n$server_version" | sort -V | tail -1)" ]; then
				echo "$version is less than server $server_version, downloading new version to /root/pullsync.sh and executing."
				wget -q https://github.com/ch604/pullsync/archive/master.zip -O /root/pullsync-master.zip
				unzip /root/pullsync-master.zip pullsync-master/includes.pullsync/* -d /root/
				unzip /root/pullsync-master.zip pullsync-master/pullsync.sh -d /root/
				\rm -rf /root/includes.pullsync/
				mv -f /root/pullsync-master/includes.pullsync /root/
				rm -r /root/pullsync-master
				rm -f /root/pullsync-master.zip
				chmod 700 /root/pullsync.sh
				sleep .25
				exec bash /root/pullsync.sh "$@"
			else
				echo "$version is equal or greater than server $server_version"
			fi
		else
			echo "Script version on github.com is not in expected format, problem with the server? Continuing after a few seconds..."
			echo "Detected version as $server_version"
			sleep 3
		fi
	else
		echo "Couldn't resolve host github.com to check for updates."
	fi
fi

#start in screen
if [ -z "$STY" ]; then
	echo "Warning! Not in screen! Attempting to restart in an interactive screen session..."
	! which screen &> /dev/null && yum -yq install screen &> /dev/null
	! which screen &> /dev/null && echo "I can't find screen!" && exit 70
	chmod 755 /var/run/screen
	sleep .25
	screen -S "$scriptname" bash -c "bash $0 $*; bash"
	exit 0
fi

#this group of commands makes sure we are on a licensed cpanel server. outside of a function so we quit early if non-cpanel.
[ ! -f /etc/wwwacct.conf ] && echo "/etc/wwwacct.conf not found! Not a cpanel server?" && exit 99
[ ! -f /etc/cpanel/ea4/is_ea4 ] && echo "Is this a cPanel server??? If it is, its not running EA4, which is another problem altogether. Fix this before continuing." && exit 99
cpanel_main_ip=$(awk '/^ADDR [0-9]/ {print $2}' /etc/wwwacct.conf | tr -d '\n')
[ "$cpanel_main_ip" = "" ] && cpanel_main_ip=$(cat /var/cpanel/mainip)
[ "$cpanel_main_ip" = "" ] && echo "Could not detect main IP from /etc/wwwacct.conf or /var/cpanel/mainip! Ensure the main IP is set up in WHM?" && exit 99

# initalize working directory. $dir is a symlink to $dir.$starttime from last migration
[[ -d "$dir" || -L "$dir" ]] && rm -f "$dir" # remove old symlink
[ -d "$dir.$starttime" ] && echo "ERROR: $dir.$starttime already exists! Did you go back in time?" && exit 1
# shellcheck disable=SC2174
mkdir -p -m700 "$dir.$starttime"
ln -s "$dir.$starttime" "$dir"

# quit if something went really wrong
[ ! -d "$dir" ] && echo "ERROR: could not find $dir!"  && exit 1
mkdir "$dir/tmp" "$dir/log"
echo "$starttime" > "$dir/starttime.txt"
find /var/cpanel/users/ -type f -printf "%f\n" | grep -Ev "^HASH" > "$dir/existing_users.txt"

###################
# include functions
###################

# shellcheck disable=SC2044,SC1090
for f in $(find /root/includes.pullsync/ -mindepth 1 -type f -name "*.sh" \! -name "variables.sh" 2> /dev/null); do . "$f"; done

#trap control c keypress and pass it to control_c()
trap control_c SIGINT

#create lock file after bash function include
echo "$pid" > "$pidfile"
echo "${sshClientIP}" > "$dir/youdidthis"
printf "\e]0; pullsync-%s \a" "$(hostname)" 1>&2

###############
# startup logic
###############

#export functions for parallel
if ! export -f packagefunction rsync_homedir hosts_file ec ecnl rsync_homedir_wrapper rsync_email rsync_email_wrapper mysql_dbsync mysql_dbsync_user malware_scan logit ts sssh install_ssl resetea4versions sanitize_dblist nameserver_registrar eternallog stderrlogit nonhuman human wpt_speedtest awkmedian ab_test errorlogit user_mysql_listgen wpt_initcompare finalfunction processprogress dbscan apache_user_includes fpmconvert progress_bar parallel_lwhostscopy parallel_usercollide parallel_domcollide parallel_unsynceduser parallel_unsynceddom parallel_unrestored set_ipv6 cpbackup_finish parallel_cllve parallel_vhostsearch parallel_zonesearch srsync parallel_dnslookup parallel_nslookup parallel_besttime parallel_mysql_dbsync user_pgsql_listgen pgsql_dbsync user_email_listgen record_mapping mysqlprogress sql sssh_sql; then
	echo "ERROR: functions did not export properly! Remove /root/includes.pullsync/ and rerun script..."
	exit 1
fi
export dir userlist user_total remainingcount sshargs ip remote_tempdir rsyncargs rsyncspeed old_main_ip ded_ip_check single_dedip synctype rsync_update rsync_excludes hostsfile hostsfile_alt nocolor black grey red lightRed green lightGreen brown yellow blue lightBlue purple lightPurple cyan lightCyan white greyBg dblist_restore fpmconvert phpextrafail comment_crons malwarescan defaultea4profile log apacheextrafail fixperms starttime mysqldumpopts stderrlog dbbackup_schema initsyncwpt dopgsync skipsqlzip nodbscan start_disk expected_disk homemountpoints finaldiff jobnum ipv6 mailjobnum sqljobnum cm hg wn xx c

# start the script after functions are defined.
validate_license #make sure cpanel is licensed
installsupport #install all the things you need to function
ithinkimalonenow #warn if anyone else is on the machine
# shellcheck disable=SC2199
if [[ "" == "$@" ]]; then #if there are no arguments passed, run main()
	main
else
	argumentcheck "$@"
	automain
fi
#you made it to the end, good job!
