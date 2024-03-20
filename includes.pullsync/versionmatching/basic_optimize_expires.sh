basic_optimize_expires(){ #turn on mod_expires by adding a custom config
	# if the file already exists, back it up
	[ -s /etc/apache2/conf.d/expires.conf ] && mv /etc/apache2/conf.d/expires.conf{,.pullsync.bak}
	cat >> /etc/apache2/conf.d/expires.conf << EOF
<IfModule mod_expires.c>
  ExpiresActive on
  ExpiresByType image/jpg "access plus 1 month"
  ExpiresByType image/gif "access plus 1 month"
  ExpiresByType image/jpeg "access plus 1 month"
  ExpiresByType image/png "access plus 1 month"
  ExpiresByType text/css "access plus 1 month"
  ExpiresByType text/javascript "access plus 1 month"
  ExpiresByType application/javascript "access plus 1 month"
  ExpiresByType application/x-shockwave-flash "access plus 1 month"
  ExpiresByType text/css "now plus 1 month"
  ExpiresByType image/ico "access plus 1 month"
  ExpiresByType image/x-icon "access plus 1 month"
  ExpiresByType text/html "access plus 600 seconds"
  ExpiresDefault "access plus 2 days"
</IfModule>
EOF
	chmod 644 /etc/apache2/conf.d/expires.conf
}
