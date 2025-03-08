securityfeatures() { #look for common security features on source
	local securityfeat keycount
	ec yellow "Checking for security customizations..."
	if [ "$port" -ne 22 ]; then
		# remote ssh port not 22
		ec red "I'm sure you know, but the remote SSH port is NOT 22! It's $port!" | errorlogit 3 root
		securityfeat=1
	fi
	if [ "$(grep -i ^PermitRootLogin "$dir/etc/ssh/sshd_config" | awk '{print $2}')" = "without-password" ]; then #if no, script wouldnt work
		# permitrootlogin line isnt 'yes', and cannot be 'no' because we wouldnt be conneced
		ec red "Remote root SSH is set to 'without-password'!" | errorlogit 3 root
		securityfeat=1
	fi
	if grep -qve "^#" -e "^$" "$dir/etc/security/access.conf"; then
		# non-commented and non-blank lines in access.conf
		ec red "There are active lines in remote /etc/security/access.conf!" | errorlogit 3 root
		securityfeat=1
	fi
	if grep -qve "^#" -e "^$" "$dir/etc/hosts.allow"; then
		# non-commented and non-blank lines in hosts.allow
		ec red "There are active lines in remote /etc/hosts.allow!" | errorlogit 3 root
		securityfeat=1
	fi
	keycount=$(grep -cv -e "^#" -e "^$" -e "Parent\ Child\ key" -e "Backup\ key\ Workflow" -e "pullsync" "$dir/root/.ssh/authorized_keys")
	if [ "$keycount" -gt 0 ]; then
		# count of lines in authorized_keys that are not commented, not blank, and are not part of a storm parent workflow
		ec red "There are $keycount active SSH keys in remote /root/.ssh/authorized_keys!" | errorlogit 3 root
		securityfeat=1
	fi
	if [ -f "$dir/var/cpanel/authn/api_tokens_v2/whostmgr/root.json" ] && [ "$(jq '.tokens | length' "$dir/var/cpanel/authn/api_tokens_v2/whostmgr/root.json")" -gt 0 ] ; then
		# tokens exist within api_tokens_v2 json file of any type
		ec red "There are WHM Access Tokens on the source server! (checked against /var/cpanel/authn/api_tokens_v2/whostmgr/root.json)" | errorlogit 3 root
		securityfeat=1
	fi
	if [ $securityfeat ]; then
		# of any of the above if statements were triggered, print a warning
		ec lightRed "Please make sure the above items are implemented after the final sync is complete! All relevant remote files are stored in $dir. (logged in $dir/error.log)"
		say_ok
	else
		ec green "No features detected."
	fi
}
