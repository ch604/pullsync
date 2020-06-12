autophpmenu(){
	if [ "$localea" = "EA4" ]; then
		#run ea4, convert remote profile
		ea=1
		ea4profileconversion
	else
		#upgrade to ea4
		migrateea4=1
		ea=1
	fi
}
