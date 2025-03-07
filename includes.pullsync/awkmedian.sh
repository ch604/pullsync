awkmedian() { #get the median value for newline separated input of numbers
	cat - | awk 'BEGIN { OFMT = "%.0f"; c = 0; sum = 0;} $1 ~ /^[0-9]*(\.[0-9]*)?$/ { a[c++] = $1; sum += $1; } END { ave = sum / c; if( (c % 2) == 1 ) { median = a[ int(c/2) ]; } else { median = ( a[c/2] + a[c/2-1] ) / 2; } print median }'
}
