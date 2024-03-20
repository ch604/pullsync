slackhook_final() { #post details of final sync to monitoring slack channel, needs to ensure source is lw server.
	uuid=`cat $dir/usr/local/lp/etc/lp-UID` #get source server uuid
	hostname=$(sssh "hostname") #source server hostname
	[ $lwuser ] && lwuser="@$lwuser" || lwuser='!subteam^S8N7J2VP1' #ping migrations-onshift team if no user set

	# change color for not restarting services
	if [ "$stopservices" -a ! "$restartservices" ]; then
		color=ff3333
	else
		color=7CD197
	fi

	#fail if cant connect to slack.com
	timeout 1 bash -c 'cat < /dev/null > /dev/tcp/hooks.slack.com/443'
	[ $? -ne 0 ] && return 1

	message=$(cat << EOF
{
	"attachments": [
	{
	    "fallback": "pullsync.sh starting final sync\n$lwuser\nstarted at $starttime by $sshClientIP\nserver: $hostname $ip, billing link: <https://billing.int.liquidweb.com/mysql/content/admin/search.mhtml?search_input=$uuid&search_submit=Search|$uuid>\n<$replyurl | reply url: $reply_url",
	    "pretext": "A pullsync final sync has been started by <$lwuser>",
	    "title": "$hostname services going down",
	    "title_link": "nil",
	    "text": "Migration from $ip to ${cpanel_main_ip}\nsource billing search: <https://billing.int.liquidweb.com/mysql/content/admin/search.mhtml?search_input=$uuid&search_submit=Search|$uuid>\nsalesforce ticket: <https://liquidweb.my.salesforce.com/_ui/search/ui/UnifiedSearchResults?searchType=2&fen=500&asPhrase=1&str=$ticket|$ticket>",
	    "color": "#$color"
	}
    ]
}
EOF
)
	[ "$color" = "ff3333" ] && message="$(echo $message | sed 's/\"pretext\"[^,]*,/\"pretext\":\ \"FINAL SYNC WITHOUT RESTARTING SERVICES\",/')" #if not restarting services, warn more boldly
	[ "$ticket" = "" ] && message="$(echo $message | sed 's/salesforce.*|>\\n//')" #remove sf link if no ticket number
	curl --silent -X POST --data-urlencode 'payload='"$message" $slackhook_url 2>&1 | stderrlogit 4
}
