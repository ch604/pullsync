ea4profileconversion() { #convert remote running EA3/4 profile
	mkdir -p /etc/cpanel/ea4/profiles/custom/
	if [ "$remoteea" = "EA3" ]; then
		# run profile conversion against remote ea3 yaml file
		ec yellow "Setting up _main.yaml file for conversion..."
		srsync -R $ip:/var/cpanel/easy/apache/ $dir/
		if grep -q '"SymlinkProtection":' $dir/var/cpanel/easy/apache/profile/_main.yaml; then
			sed -i 's/\("SymlinkProtection":\).*/\1 1/g' $dir/var/cpanel/easy/apache/profile/_main.yaml
		else
			sed -i '/"optmods":/a \ \ \ \ "SymlinkProtection":\ 1' $dir/var/cpanel/easy/apache/profile/_main.yaml
		fi
		ec yellow "Converting EA3 profile to EA4..."
		/scripts/convert_ea3_profile_to_ea4 $dir/var/cpanel/easy/apache/profile/_main.yaml /etc/cpanel/ea4/profiles/custom/migration.json 2>&1 | stderrlogit 3
	elif [ "$remoteea" = "EA4" ]; then
		# export remote ea4 profile and copy to target custom directory
		ec yellow "Saving and copying configuration..."
		sssh "mkdir -p /etc/cpanel/ea4/profiles/custom; /usr/local/bin/ea_current_to_profile --output=/etc/cpanel/ea4/profiles/custom/migration.json" 2>&1 | stderrlogit 3
		srsync $ip:/etc/cpanel/ea4/profiles/custom/migration.json /etc/cpanel/ea4/profiles/custom/
	fi

	if [ -f /etc/cpanel/ea4/profiles/custom/migration.json ]; then
		# profile conversion success, run ea4
		sed -i 's/\"ea-php[0-9][0-9]-php\",//g' /etc/cpanel/ea4/profiles/custom/migration.json #remove dso to prevent install conflicts
		sed -i 's/,\"ea-php[0-9][0-9]-php\"]/]/g' /etc/cpanel/ea4/profiles/custom/migration.json #in case its the last elem in the array
		ec green "Success!"
		ea=1
	else
		# no output from profile conversion task, skip ea4
		ec red "Profile conversion failed! Skipping EA..." | errorlogit 3 root
		unset ea
	fi
}
