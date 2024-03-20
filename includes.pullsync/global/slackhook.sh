slackhook() { #post details of finished migration to slack channel
	[ ! "$slackhook_url" ] && return
	hostname=`hostname`
	[ -z "$1" ] && color=7CD197 || color=$1 #set color to passed parameter, or green if unset
	slackuser=${slackuser:-"migrations-team"}

	#fail if cant connect to slack.com
	timeout 1 bash -c 'cat < /dev/null > /dev/tcp/hooks.slack.com/443'
	[ $? -ne 0 ] && return 1

	message=$(cat << EOF
{
	"attachments": [
	{
	    "fallback": "pullsync.sh complete\n@$slackuser\nstarted at $starttime by $sshClientIP\nserver: $cpanel_main_ip, \n<$replyurl | reply url: $reply_url",
	    "pretext": "A pullsync has completed <@$slackuser>",
	    "title": "$synctype sync completed on $hostname",
	    "title_link": "nil",
	    "text": "From $ip to ${cpanel_main_ip}\n<${reply_url}|reply url>\n<${marill_log_url}|marill debug log> and <${marill_output_url}|marill output>",
	    "color": "#$color"

	}
    ]
}
EOF
)
	[ ! "$color" = "7CD197" ] && message="$(echo $message | sed 's/completed/completed with errors/')"
	curl --silent -X POST --data-urlencode 'payload='"$message" $slackhook_url 2>&1 | stderrlogit 4
}
