control_c() { #if control_c is pushed, attempt to clean up
  echo
  echo "Control-C pushed, exiting..." | errorlogit 1
  [ "$(jobs -pr)" ] && kill $(jobs -pr) && sleep 1 #try to kill any bg jobs
  stty sane
  exitcleanup 130
}
