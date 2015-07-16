#!/bin/sh

CTL=$1
TIME=$2

cat > temp_grads_time2t_tmp_$$.gs <<EOF
'reinit'
rc = gsfallow('on')
'xopen ${CTL}'
t = time2t( ${TIME} )
ret = write( "temp_grads_time2t_tmp_$$.txt", t )
'quit'
EOF
grads -blc temp_grads_time2t_tmp_$$.gs > /dev/null

cat temp_grads_time2t_tmp_$$.txt


rm temp_grads_time2t_tmp_$$.gs temp_grads_time2t_tmp_$$.txt

