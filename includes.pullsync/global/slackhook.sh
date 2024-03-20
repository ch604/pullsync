slackhook() { #post details of finished migration to slack channel
	hostname=`hostname`
	uuid=`cat /usr/local/lp/etc/lp-UID`
	[ -z "$1" ] && color=7CD197 || color=$1 #set color to passed parameter, or green if unset
	[ $lwuser ] && lwuser="@$lwuser" || lwuser='!subteam^S8N7J2VP1' #ping migrations-onshift team if no user set

	#fail if cant connect to slack.com
	timeout 1 bash -c 'cat < /dev/null > /dev/tcp/hooks.slack.com/443'
	[ $? -ne 0 ] && return 1

	message=$(cat << EOF
{
	"attachments": [
	{
	    "fallback": "pullsync.sh complete\n$lwuser\nstarted at $starttime by $sshClientIP\nserver: $cpanel_main_ip, billing link: <https://billing.int.liquidweb.com/mysql/content/admin/search.mhtml?search_input=$uuid&search_submit=Search|$uuid>\n<$replyurl | reply url: $reply_url",
	    "pretext": "A pullsync has completed <$lwuser>",
	    "title": "$synctype sync completed on $hostname",
	    "title_link": "nil",
	    "text": "From $ip to ${cpanel_main_ip}\nbilling search: <https://billing.int.liquidweb.com/mysql/content/admin/search.mhtml?search_input=$uuid&search_submit=Search|$uuid>\nsalesforce ticket: <https://liquidweb.my.salesforce.com/_ui/search/ui/UnifiedSearchResults?searchType=2&fen=500&asPhrase=1&str=$ticket|$ticket>\n<${reply_url}|reply url>\n<${marill_log_url}|marill debug log> and <${marill_output_url}|marill output>",
	    "color": "#$color"

	}
    ]
}
EOF
)
	[ ! "$color" = "7CD197" ] && message="$(echo $message | sed 's/completed/completed with errors/')"
	[ "$ticket" = "" ] && message="$(echo $message | sed 's/salesforce.*|>\\n//')"
	curl --silent -X POST --data-urlencode 'payload='"$message" $slackhook_url 2>&1 | stderrlogit 4
}
