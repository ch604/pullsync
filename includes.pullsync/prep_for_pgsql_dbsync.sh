prep_for_pgsql_dbsync() { # if pgsql is running on both machines, set $dopgsync and make sure we have folders ready
	if sssh "pgrep 'postgres|postmaster' &> /dev/null" && pgrep 'postgres|postmaster' &> /dev/null; then
		dopgsync=1
		# shellcheck disable=SC2174
		mkdir -p -m600 "$dir/pgdumps" "$dir/pre_pgdumps"
		sssh "mkdir -p -m600 $remote_tempdir 2> /dev/null"
	else
		unset dopgsync
	fi
}