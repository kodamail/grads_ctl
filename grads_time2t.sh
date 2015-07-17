#!/bin/sh
export LANG=en

CTL=$1
TIME=$2

# TIME is YYYYMMDD?
FLAG=$( echo "${TIME}" | grep -e "^[0-9]\{8\}" )
if [ "${FLAG}" != "" ] ; then
    TIME=$( date --date "${TIME}" +00z%d%b%Y )
fi


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

