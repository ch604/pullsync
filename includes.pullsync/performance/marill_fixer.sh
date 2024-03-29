marill_fixer() { #attempt to fix common marill errors
	for dom in $(cut -d\( -f1 $dir/marill_fails.txt | awk -F"//" '{print $NF}' | sed '/^$/d'); do
		ec white "Working on $dom..."
		local loopcount=1 #count the number of passes
		unset loopbreak #exit flag

		while [ "$loopcount" -le 3 ]; do
			#retest the site to make sure its a fail
			local output=$(marill --domains=$(grep ^$dom: $dir/marilldomains.txt) -q --no-color)

			if echo "$output" | grep -q "^\[SUCCESS"; then
				ec green "$dom seems to work with a subsequent test:"
				echo "$output"
				loopbreak=1
			else
				local user=$(/scripts/whoowns $dom)
				local homedir=$(eval echo ~$user)
				local relpath=$(grep ^${dom}:\  /etc/userdatadomains | awk -F"==" '{print $5}' | sed -e 's|'$homedir'||' -e 's|^/||')
				if echo "$output" | grep -q cert\ valid\ for; then
					#bad certificate, retry http or ignore.
					:
				elif echo "$output" | grep -q redirection\ does\ not\ match; then
					ec yellow "$dom has bad redirection target, false positive"
					echo "$output"
					loopbreak=1
				elif echo "$output" | grep -q database\ connection\ error; then
					#db cnxn problem, if wp try readding grants
					if grep -q -i wordpress $homedir/$relpath/index.php && [ -f $homedir/$relpath/wp-config.php ]; then
						local wpdb=$(grep DB_NAME $homedir/$relpath/wp-config.php | cut -d\' -f4)
						local wpuser=$(grep DB_USER $homedir/$relpath/wp-config.php | cut -d\' -f4)
						if mysql -Nse 'show databases' | grep -q "$wpdb"; then
							ec yellow " Attempting wp grant fix for $dom"
							#backup grants
							mysql -Nse "show grants for $wpuser@'localhost';" >> $dir/marillfixer_backups.txt 2>&1
							echo "mysql -e \"grant all privileges on $wpdb.* to $wpuser@'localhost' identified by '$(grep DB_PASSWORD wp-config.php | cut -d\' -f4)'\"" | sh
						else
							ec red "Mysql database $wpdb is missing for $dom! You need to check this one out yourself."
							loopbreak=1
						fi
					fi
				elif echo "$output" | grep -q database\ access\ error; then
					#access denied?
					:
				elif echo "$output" | grep -q code:403; then
					#403 error, see if there is an index file, and if there is, fix perms
					if ! /bin/ls -A $homedir/$relpath/ | grep -q ^index\.; then
						ec red " There doesnt seem to be an index.* file for $dom"
						loopbreak=1
					else
						#try to fix perms?
						:
					fi
				elif echo "$output" | grep -q code:404; then
					#404 error
					:
				elif echo "$output" | grep -q code:200 && echo "$output" | grep -q asset\ bad\ status\ code; then
					#bad assets, ignore?
					:
				elif echo "$output" | grep -q code:200 && echo "$output" | grep -q php\ warnings; then
					#possibly a buggy plugin as below
					:
				elif echo "$output" | grep -q blank\ page; then
					#blank page, if wp try disabling plugins
					if grep -q -i wordpress $homedir/$relpath/index.php && [ -f $homedir/$relpath/wp-config.php ] && [ "$(which wp 2>/dev/null)" ]; then
						ec yellow " Blank page detected on wp site $dom. Attempting plugin cycle..."
						for plugin in $(su - $user -s /bin/bash -c "wp --path=$relpath plugin list" | awk '$2=="active" {print $1  }'); do
							su - $user -s /bin/bash -c "wp --path=$relpath plugin deactivate $plugin"
							local output=$(marill --domains=$(grep ^$dom: $dir/marilldomains.txt) -q --no-color)
							if ! echo "$output" | grep -q blank\ page; then
								ec yellow " Plugin $plugin was causing a blank page on $dom"
								loopbreak=1
								break #exit the plugin tester for loop leaving the bad plugin off
							else
								su - $user -s /bin/bash -c "wp --path=$relpath plugin activate $plugin"
							fi
						done
					fi
				else
					#cant tell!
					ec red " Not sure what's wrong with $dom from my rules..."
					loopbreak=1
				fi
			fi
			if [ "$loopbreak" ]; then
				ec yellow "Done with $dom in $loopcount passes"
				break #exit the while loop because of a known success or failure condition
			fi
			let loopcount+=1
		done #end while loop after 3 passes regardless

		#one more test outside the loop to determine success
		local output=$(marill --domains=$(grep ^$dom: $dir/marilldomains.txt) -q --no-color)
		if echo "$output" | grep -q "^\[SUCCESS"; then
			ec green "$dom is working!"
		else
			ec red "$dom failed to get fixed automatically"
		fi
	done
	unset loopbreak
}
