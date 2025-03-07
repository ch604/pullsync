parallel_clphp() { #applies source php selector settings as needed for user passed as $1
	local prefix
	if [ -d "$(eval echo ~$1)"/.cl.selector ]; then
		ec yellow "  setting $1"
		prefix=$(cagefsctl --getprefix "$1")
		mkdir -p "$dir/oldcagefs/$prefix/$1"
		mv "/var/cagefs/$prefix/$1/etc/cl.selector" "$dir/oldcagefs/$prefix/$1/"
		mv "/var/cagefs/$prefix/$1/etc/cl.php.d" "$dir/oldcagefs/$prefix/$1/"
		cagefsctl --force-update-etc "$1"
	fi
}
