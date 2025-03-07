parallel_nslookup() { #look up nameserver registrars in parallel for dnscheck()
	local registrar
	registrar=$(nameserver_registrar "$1")
	echo -e "$1\t$(grep -c "$1" <(cat "$dir/dnsoutput/source.txt" "$dir/dnsoutput/not_here.txt" 2> /dev/null))\t$(dig +short "$1" @8.8.8.8 | head -1)\t$registrar"
}
