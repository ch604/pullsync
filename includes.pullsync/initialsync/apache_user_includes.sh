apache_user_includes() { #scan for per-user includes in apache and import to target
	local user=$1
	local user_domains=$(grep ^DNS /var/cpanel/users/${user} |cut -d= -f2 |grep -v \*)
	[ -h $dir/usr/local/apache/conf/userdata ] && local udfolder="$dir/etc/apache2/conf.d/userdata" || local udfolder="$dir/usr/local/apache/conf/userdata"
	[ "$localea" = "EA4" ] && local localudfolder="/etc/apache2/conf.d/userdata" || local localudfolder="/usr/local/apache/conf/userdata"
	#if user has no includes folder for 2_4, fuggedaboudit
	[ -d $udfolder/std/2_4/$user -o -d $udfolder/ssl/2_4/$user ] || return
	for domain in ${user_domains}; do
		if [ "$(\ls $udfolder/s{td,sl}/2_4/$user/$domain/*.conf 2> /dev/null)" ]; then
			#make target folders for includes, copy in the confs
			mkdir -p $localudfolder/{std,ssl}/2_4/$user/$domain
			rsync -aq $udfolder/std/2_4/$user/$domain/*.conf $localudfolder/std/2_4/$user/$domain/
			rsync -aq $udfolder/ssl/2_4/$user/$domain/*.conf $localudfolder/ssl/2_4/$user/$domain/
			/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
			httpd -t 2>&1 | stderrlogit 4
			if [ "${PIPESTATUS[0]}" = "0" ]; then
				#config test ok
				/scripts/restartsrv_apache 2>&1 | stderrlogit 4
				ec green "Added custom apache includes for $user"
			else
				rm -f $localudfolder/{std,ssl}/2_4/$user/$domain/*.conf
				ec red "Tried to add custom apache includes for $user, but config test failed!" | errorlogit 3
				#rebuild httpd.conf to get rid of include line
				/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
				/scripts/restartsrv_apache 2>&1 | stderrlogit 4
			fi
		fi
	done
}
