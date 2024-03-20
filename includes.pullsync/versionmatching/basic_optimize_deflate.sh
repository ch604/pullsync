basic_optimize_deflate(){ #turn on mod_deflate by adding a custom config
	# if the file already exists, back it up
	[ -s /etc/apache2/conf.d/deflate.conf ] && mv /etc/apache2/conf.d/deflate.conf{,.pullsync.bak}
	# ensure that mod_deflate is installed
	yum -y -q install ea-apache24-mod_deflate 2>&1 | stderrlogit 4
	cat >> /etc/apache2/conf.d/deflate.conf << EOF
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/text text/html text/plain text/xml text/css application/x-javascript application/javascript application/xhtml+xml application/rss+xml
</IfModule>
EOF
	chmod 644 /etc/apache2/conf.d/deflate.conf
}
