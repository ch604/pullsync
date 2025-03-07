multiplex() { #enable ssh keepalive for $ip, saves connection time on slow-connect sources
	ec yellow "Adding source IP to ssh config for multiplexing..."
	mkdir -m600 /root/.ssh 2>&1 | stderrlogit 3
	[ -f /root/.ssh/config ] && sed -i '/\#added\ by\ pullsync/,+4d' /root/.ssh/config #remove previously added rules if they exist
	cat >> /root/.ssh/config << EOF
#added by pullsync
Host $ip
  ControlPath ~/.ssh/pullsync.cm-%r@%h:%p
  ControlMaster auto
  ControlPersist 5m
EOF
	chmod 600 /root/.ssh/config
}
