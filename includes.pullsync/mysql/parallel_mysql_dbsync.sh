parallel_mysql_dbsync(){ #wrapper for running mysql_dbsyncs alongside other tasks in the background
        # this is to run a sync task outside of users in parallel
        prep_for_mysql_dbsync
        echo "$dblist_restore" > $dir/dblist.txt
        while read -u9 db; do
                mysql_dbsync "$db"
        done 9<$dir/dblist.txt
}
