print_finalsync_message() { #upload the message built in build_finalsync_reply() using haste()
	ec yellow "Uploading finalsync reply..."
	reply_url=$(cat $dir/finalsyncreply.txt | haste)
	echo $reply_url > $dir/finalreply_url
	ec green "Finalsync reply generated at $reply_url"
	[ $cue_tech_to_replace_dns_details ] && ec red "DONT FORGET TO CREATE DNS DETAILS IN THIS REPLY FOR CUSTOMER TO FINALIZE THE MIGRATON"
}
