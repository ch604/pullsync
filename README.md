![LastCommit](https://img.shields.io/github/last-commit/ch604/pullsync)
[![License](https://img.shields.io/badge/license-BSD3-green.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Donate](https://img.shields.io/badge/donate-paypal-blue)](https://www.paypal.me/walilkoa)

Cool migraiton script for cPanel servers.

Migrate a single cPanel account, from a user list, a domain list, or all users, to another cPanel server. Update/final syncs, too.

![Pullsync Preview](https://imgur.com/NzdUqtU.png)

Bonus features:
* php/http version matching 
* tweak settings and exim settings matching
* common 3rd party software installation
* parallel account syncs (thanks to GNU Parallel by Ole Tange)
* lower TTLs
* one-time-use ssh key generation
* copy-paste information to send to clients
* IP swap support (if datacenter supports this)
...and more!

## REQUIREMENTS
The script will only run on cPanel servers, and will only migrate from cPanel servers, both of which must be CentOS/RHEL. You must have direct root-level SSH access available to the source server.

The script has been tested as far back as CentOS 4 for source, but newer features have not been fully verified against this. Only CentOS 6 or 7 targets are supported at this time.

The script also assumes that you have migrated websites manually in the past, as, in essence, this is a bash script you downloaded from the internet, and you should treat it as such.

Lastly, you will need screen installed.

```yum -y install screen```

## RUNNING PULLSYNC
Pullsync is run from the TARGET of your migration.

Set up your userlist at /root/userlist.txt with space or newline separated cpanel usernames. If migrating all users, skip this step.

If you need to exclude files or databases, set up the appropriate files at /root/rsync_exclude.txt and /root/db_exclude.txt.

Finally, download and execute the script:

```wget -O /root/pullsync.sh https://raw.githubusercontent.com/ch604/pullsync/master/pullsync.sh && chmod 700 ~/pullsync.sh```

```bash /root/pullsync.sh```

Pullsync will install its own prerequisites (whois, parallel, etc) if needed, and download its supporting files from this repo. It will restart itself in screen if necessary, and present a user-friendly menu to proceed from there.

## LOG LOCATIONS
Pullsync writes its temporary files and logs to /home/temp/pullsync/, which is a symlink to a directory in /home/temp/ suffixed with the start time. Some important files to consider:

```
/pullsync.log #all script output is stored here
/error.log #important errors are logged here
/log/dbsync.log #this is the output from a mysql-only or final sync
/log/*.${user}.log #each user's tasks are logged in these files, there is a looplog, a pkgacct, a restorepkg, and an rsync log.
```

The pullsync directory is stuffed with all kinds of other output as well, including `/reply_url`, a copy of the url with testing output, `/dns.txt`, a summary of DNS resolution, and `/ticketnote.txt`, a summary of the changes pullsync attempted to make. Additoinal files will be called out during the script that the technician performing the migration should pay attention to.

Copies of several key files from the source server are also copied into this directory for reference before, during, and after the migration, such at /etc/wwwacct.conf, /var/cpanel/users/, and /etc/ips, among others.

Finally, there is an eternal history file at /root/migration.log, showing what accounts were operated on at what times, and where you can get more details.

## TROUBLESHOOTING AND BUG REPORTING
You already know how to migrate and can fix it, right? ....right?

Bugs can be reported on this repository.
