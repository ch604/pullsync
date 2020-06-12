WARNING: CURRENTLY ONLY WORKS ON LIQUIDWEB SYSTEMS

Cool rsync wrapper for cPanel servers.

Migrate a single cPanel account, from a user list, a domain list, or all users, to another cPanel server. Update/final syncs, too.

Bonus features:
* php/http version matching 
* tweak settings and exim settings matching
* 3rd party software installation
* parallel account syncs (thanks to GNU Parallel by Ole Tange)
* lower TTLs
* one-time-use ssh key generation
...and more!

## INSTALLATION
```wget -O /root/pullsync.sh https://raw.githubusercontent.com/ch604/pullsync/master/pullsync.sh && chmod 700 ~/pullsync.sh```

Install screen also, if it isn't already:

```yum -y install screen```

## REQUIREMENTS
The script will only run on cPanel servers, and will only migrate from cPanel servers, both of which must be CentOS/RHEL. You must have direct root-level SSH access available to the source server.

## RUNNING PULLSYNC
If you know you will need to make some edits, crack open the file and do it to it, setting `autoupdate=0` at the top of the script.

Set up your userlist at /root/userlist.txt with space or newline separated cpanel usernames. If migrating all users, skip this step.

If you need to exclude files or databases, set up the appropriate files at /root/rsync_exclude.txt and /root/db_exclude.txt.

Finally, execute the script:
```bash /root/pullsync.sh```

Pullsync will install its own prerequisites (whois and parallel) if needed, and download its supporting files from this repo.

## LOG LOCATIONS
Pullsync writes its temporary files and logs to /home/temp/pullsync/, which is a symlink to a directory in /home/temp/ suffixed with the start time. Some important files to consider:

```
/pullsync.log #all script output is stored here
/error.log #important errors are logged here
/log/dbsync.log #this is the output from a mysql-only or final sync
/log/*.${user}.log #each user's tasks are logged in these files, there is a looplog, a pkgacct, a restorepkg, and an rsync log.
```

The pullsync directory is stuffed with all kinds of other output as well, including `/reply_url`, a copy of the url with testing output, `/dns.txt`, a summary of DNS resolution, and `/ticketnote.txt`, a summary of the changes pullsync attempted to make.

Copies of several key files from the source server are also copied into this directory for reference before, during, and after the migration, such at /etc/wwwacct.conf, /var/cpanel/users/, and /etc/ips, among others.

Finally, there is an eternal history file at /root/migration.log, showing what accounts were operated on at what times, and where you can get more details.

## TROUBLESHOOTING AND BUG REPORTING
You already know how to migrate and can fix it, right? ....right?
