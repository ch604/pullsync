displayhelp() { #print help text for cli users
	echo "
pullsync $version

Migrate between cPanel servers

CLI flags are currently in beta. Use unattended features at your own risk!

Example initial sync:
	bash pullsync.sh -t all -i 123.45.67.89 -k /path/to/private/keyfile [-p 22] [-m]

Example final sync:
	bash pullsync.sh -t final -i 123.45.67.89 -k /path/to/private/keyfile [-p 22] [-sred]

Currently supported flags:

	(none)		Manual migration with main menu

	-t TYPE		Automatic TYPE migration (required)
			Accepted options:
				all
				list: requires /root/userlist.txt
				final: requires /root/userlist.txt
	-i IP		Migrate data from IP (required with -t)
	-p PORT		Connect over ssh port PORT (defaults to 22)
	-k KEY		Full path to functional passwordless private SSH key (required)

	-l EMAIL	Set contact email to EMAIL after initial sync
	-m		Perform sane version matching
	-x		Scan php files for malware during transfer
	-y		Run marill auto-testing after sync (all/list only)

	-s		Stop services for final sync
	-r		Restart services after final sync
	-e		Run maintenance page engine on source server during final sync
	-d		Copy dns back to source server

	-u		Slack user for slack reporting
	-h		Display this help and exit

The following issues will cause pullsync to fail after a sane startup:
	* insufficient disk space on target/source
	* dns clustering set up on target/source
"
}
