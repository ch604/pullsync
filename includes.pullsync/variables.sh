# these settings can be changed by the technician to accomodate certain situations. if you modify these, they will be lost upon script update, so turn off autoupdate with this variable
autoupdate=1

# declare number of parallel processes for initial sync. lower this if load is too great. not tested above 3; progress functions may not show everything. mailbox and sql parallel sync uses a separate job number, which declares number of mailboxes per user and tables per database synced at one time. These multiple by jobnum for total process count, and also add one for the core sync process. Defaults of 3/3/3 will have 3 users syncing at a time with 3 mailboxes each and 3 tables, making a total of 30 move processes at the same time.
jobnum=3
mailjobnum=3
sqljobnum=1

# delay time in seconds for refreshing the progress functions, speed this up if you like seeing everything, or slow it down if you like copying and pasting
refreshdelay=3

# potential prefixes for natted ip warning check. pipe separated for regex.
natprefix="172.16|192.168|10."

# excluded users when selecting all users. pipe separated for regex. HASH* is added to the string separately, so the wildcard is added properly.
badusers="system|root|nobody"

# excluded when selecting all databases. filtered as above. ^logaholicDB and ^cptmpdb are added separately. pipe separated for regex.
baddbs="performance_schema|information_schema|cphulkd|eximstats|horde|leechprotect|modsec|mysql|roundcube|whmxfer|test|lost\+found|tmpdir|sys|perl5|cp_aftlgc"

# filter out stuff like error_log, backup-*.tar.gz. great for initial, final, and homedir syncs. add extra one-off excludes to /root/rsync_exclude.txt.
rsync_excludes='--exclude=error_log --exclude=backup-*.tar.gz --exclude=.trash --exclude=.cagefs'
[ -f /root/rsync_exclude.txt ] && rsync_excludes="$rsync_excludes --exclude-from=/root/rsync_exclude.txt"

# database excludes for final and mysql only syncs can be added to /root/db_exclude.txt (one per line). good for large databases that you dont want to sync again, or dbs that you only sync a few tables for manually.

# similarly, database includes for final and mysql only syncs can be added to /root/db_include.txt (one per line). great for syncing databases that dont belong to a cpanel user. this is added before the excludes and the baddbs filter as above.

# the speed, in kbps, of initial and update syncs will be limited to avoid excess network load on the source server. decrease this on overloaded source servers. this limit is removed on final syncs by setting it to "0".
rsyncspeed="3000"

# at the conclusion of hands-off portions of syncs, a slack hook can be activated. uncomment add a url for your slack hook here.
#slackhook_url="https://hooks.slack.com/services/your/url/goeshere"

# if you would like documents to be uploaded to a publicly accessible hastebin, you can do so by uncommenting and adding a url to a haste-server installation (https://github.com/toptal/haste-server)
#hastebin_url="myhastebinurl.com"

# these programs are prerequisites for pullsync to run, and will be installed just after version checking and before the main loop. these should be names of readily available packages for el7+ in the base or epel repos.
requireds="dialog whois virt-what bc rubygems ipcalc jq parallel oniguruma bind-utils"

# the following files are rsynced over from old server to the $dir just after connection.
filelist="/etc/apf
/etc/apache2/conf.d
/etc/apache2/conf
/etc/container/ve.cfg
/etc/cl.selector
/etc/cpbackup.conf
/etc/cpupdate.conf
/etc/cron*
/etc/csf
/etc/exim.conf
/etc/exim.conf.localopts
/etc/fstab
/etc/named.conf
/etc/passwd
/etc/proftpd
/etc/valiases
/etc/sysconfig/clock
/etc/sysconfig/network-scripts
/etc/NetworkManager/system-connections
/etc/userdomains
/etc/userdatadomains
/etc/wwwacct.conf
/etc/localdomains
/etc/remotedomains
/etc/blockeddomains
/etc/alwaysrelay
/etc/localaliases
/etc/cpanel/ea4/
/etc/ips
/etc/mail/spamassassin
/etc/mailhelo
/etc/mailips
/etc/spammeripblocks
/etc/my.cnf
/etc/hosts.allow
/etc/ssh/sshd_config
/etc/security/access.conf
/opt/cpanel/ea-php*/root/etc/php.ini
/opt/cpanel/ea-php*/root/etc/php.d
/root/.my.cnf
/root/.forward
/root/.ssh/authorized_keys
/usr/local/apache/conf
/usr/local/cpanel/version
/usr/local/cpanel/3rdparty/etc/phpmyadmin/php.ini
/usr/local/lib/php.ini
/usr/share/ssl
/usr/my.cnf
/var/cpanel/apps
/var/cpanel/authn
/var/cpanel/databases
/var/cpanel/useclusteringdns
/var/cpanel/cluster
/var/cpanel/conf
/var/cpanel/cpanel.config
/var/cpanel/backups
/var/cpanel/resellers
/var/cpanel/cpnat
/var/cpanel/mainip
/var/cpanel/ssl
/var/cpanel/domainmap
/var/cpanel/users
/var/cpanel/users.cache
/var/cpanel/userdata
/var/cpanel/icontact_event_importance.json
/var/cpanel/iclevels.conf
/var/cpanel/webtemplates
/var/cpanel/customizations
/var/cpanel/greylist
/var/cpanel/hulkd
/var/cpanel/easy
/var/cpanel/mysqlaccesshosts
/var/cpanel/mysql/remote_profiles/profiles.json
/var/cpanel/mysql_status
/var/cpanel/nameserverips.yaml
/var/cpanel/globalcache
/var/cpanel/datastore
/var/lib/named/chroot/var/named/master
/var/spool/cron
/var/ssl
/var/named
"

# ok, stop editing! the follwing are vars that should not change
scriptname=$(basename "$0" .sh)
starttime=$(date +%F.%T)
starttimeepoch=$(date +%s)
dir="/home/temp/pullsync"
noopdir="/home/temp/noop-pullsync"
pidfile="$dir/pullsync.pid"
pid="$$"
log="$dir/$scriptname.log"
stderrlog="$dir/$scriptname.stderr.log"
rsyncargs="-aqHz --timeout=900"
userlistfile="/root/userlist.txt"
domainlistfile="/root/domainlist.txt"
remote_tempdir="/home/temp/pullsynctmp.$starttime" # cpmove files are created here on remote server
hostsfile="/usr/local/apache/htdocs/hosts.txt"
hostsfile_alt="/usr/local/apache/htdocs/hostsfile.txt"
sshargs="-o GSSAPIAuthentication=no" #disable "POSSIBLE BREAKIN ATTEMPT" messages and first host key acceptance
proglist="ffmpeg imagick memcache cmc cmm cmq cse mailscanner java cpanelsolr postgres modremoteip nodejs npm tomcat redis solr pdftk elasticsearch wkhtmltopdf apc sodium imunify spamassassin"
LANG="en_US.UTF-8"
c=$(tput el)

#colors
nocolor="\E[0m"; black="\033[0;30m"; grey="\033[1;30m"; red="\033[0;31m"; lightRed="\033[1;31m"; green="\033[0;32m"; lightGreen="\033[1;32m"; brown="\033[0;33m"; yellow="\033[1;33m"; blue="\033[0;34m"; lightBlue="\033[1;34m"; purple="\033[0;35m"; lightPurple="\033[1;35m"; cyan="\033[0;36m"; lightCyan="\033[1;36m"; white="\033[1;37m"; greyBg="\033[1;37;40m"

#unicode
cm='\u2705' #green checkmark
wn='\u26A0\uFE0F' #warning triangle
xx='\u274C' #red x
hg='\u23F3' #hourglass

#regex
valid_ip_format="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
valid_port_format="^([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"
valid_version_format="^[0-9]+\.[0-9]+\.[0-9]+$"

#system users and services
systemusers="root|bin|daemon|adm|sync|shutdown|halt|mail|uucp|operator|games|gopher|ftp|nobody|systemd-*|dbus|vcsa|abrt|haldaemon|ntp|saslauth|postfix|sshd|tcpdump|named|mysql|cpanelhorde|mailnull|cpanel|cpanelphpmyadmin|cpanelphppgadmin|cpanelroundcube|mailman|cpanellogin|cpaneleximfilter|cpaneleximscanner|cpses|dovecot|dovenull|avahi-autoipd|polkitd|sssh|chrony|tss|rtkit|pipewire|flatpak|rpc|rpcuser|nscd|cpanelconnecttrack|cpanelanalytics|postgres|apache|cpanelcabcache|systuser|system|avahi|pcap|smmsp|xfs|news|oprofile|memcached|rpm|nagios|geoclue|clamav"
systemservices="anacron|bandmin|bluetooth|nfslock|microcode_ctl|readahead_early|rpcidmapd|yum-updatesd|kudzu|firstboot|hidd|rawdevices|udev-post|acpid|haldaemon|haldemon|messagebus|netfs|network|portreserve|blk-availability|filelimits|autofs|cpuspeed|cups|mcelogd|rpcbind|rpcgssd|stunnel|microcode|restorecond|syslog|isdn|lvm2-monitor|avahi-daemon|ip6tables|ntpd|iscsi|iscsid|kcare|mysql|mysqld|tuned|mariadbd|mariadb|systemd-*|mailman|rhel-*|cups|rhsmcertd"

#sql variables which can be matched
sql_variables="innodb_buffer_pool_size innodb_buffer_pool_instances table_open_cache key_buffer_size max_connections"