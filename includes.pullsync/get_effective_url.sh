get_effective_url(){ #turn a passed url into an effective target (avoid testing redirects for ab)
	echo $(curl -w "%{url_effective}\n" -I -L -s -S $1 -o /dev/null | sed -e '/[^/]$/ s|$|/|')
}
