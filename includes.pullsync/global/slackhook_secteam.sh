slackhook_secteam() { #post details of ip swap on ss+ server to security slack channel
	uuid=$(cat /usr/local/lp/etc/lp-UID)
	hostname=$(hostname)

	#fail if cant connect to slack.com
	timeout 1 bash -c 'cat < /dev/null > /dev/tcp/hooks.slack.com/443'
	if [ $? -ne 0 ]; then
		ec red "This server is running serversecure plus! Make sure you let the security team know about the IP swap when you are done! Something like:"
		ec white "Hello, the server $(hostname), $(cat /usr/local/lp/etc/lp-UID), just had an IP swap and is running SS+. Please update the SS+ database as needed for the new IP, $old_cpanel_main_ip. Thank you!"
		return 1
	fi

	message=$(cat << EOF
{
	"attachments": [
	{
		"fallback": "<!subteam^S0KEREZN1> pullsync.sh completed final sync and IP swap of SS+ target server $hostname ($uuid). Please update the SS+ license for this machine to $old_cpanel_main_ip. Thank you!",
		"pretext": "A pullsync final sync has been completed! <!subteam^S0KEREZN1>",
		"title": "pullsync.sh completed an IP swap of SS+ server $hostname!",
		"text": "Please update the SS+ license database with the new IP of this server.\nhostname: $hostname\nUUID (billing search): <https://billing.int.liquidweb.com/mysql/content/admin/search.mhtml?search_input=$uuid&search_submit=Search|$uuid>\nNew IP: $old_cpanel_main_ip",
		"color": "#F9BE59"
	}
    ]
}
EOF
)
	curl --silent -X POST --data-urlencode 'payload='"$message" $secteam_slackhook_url 2>&1 | stderrlogit 4
	ec yellow "This server is running SS+, and I've already let the security team know for you. Now you're gonna get it."
}
