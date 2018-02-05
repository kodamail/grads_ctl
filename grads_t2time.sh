#!/bin/sh
export LANG=C
export PATH=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd ):${PATH}

CTL=$1
T=$2

cat > temp_grads_t2time_tmp_$$.gs <<EOF
'reinit'
rc = gsfallow('on')
'xopen ${CTL}'
time = t2time( ${T} )
ret = write( "temp_grads_t2time_tmp_$$.txt", time )
'quit'
EOF
grads -blc temp_grads_t2time_tmp_$$.gs > /dev/null

cat temp_grads_t2time_tmp_$$.txt


rm temp_grads_t2time_tmp_$$.gs temp_grads_t2time_tmp_$$.txt

