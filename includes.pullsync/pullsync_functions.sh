#!/bin/bash
# this file does nothing without pullsync.sh
# https://git.sysres.liquidweb.com/migrations/pullsync/tree/multifile

###################
# include functions
###################

for f in /root/includes.pullsync/global/*.sh; do
	. $f
done

for f in /root/includes.pullsync/menus/*.sh; do
	. $f
done

for f in /root/includes.pullsync/connection/*.sh; do
	. $f
done

for f in /root/includes.pullsync/mysql/*.sh; do
	. $f
done

for f in /root/includes.pullsync/versionmatching/*.sh; do
	. $f
done

for f in /root/includes.pullsync/getversions/*.sh; do
	. $f
done

for f in /root/includes.pullsync/initialsync/*.sh; do
	. $f
done

for f in /root/includes.pullsync/finalsync/*.sh; do
	. $f
done

for f in /root/includes.pullsync/misc/*.sh; do
	. $f
done

for f in /root/includes.pullsync/performance/*.sh; do
	. $f
done

for f in /root/includes.pullsync/progress/*.sh; do
	. $f
done
