#!/bin/sh
export LANG=en

CTL=$1
TIME=$2
OPT=$3  # -gt

if [ ! -f "${CTL}" ] ; then
    echo "error in grads_time2t.sh: CTL=${CTL} does not exist."
    exit 1
fi
if [ "${TIME}" = "" ] ; then
    echo "error in grads_time2t.sh: TIME is not specified."
    exit 1
fi

# TIME is YYYYMMDD?
FLAG=$( echo "${TIME}" | grep -e "^[0-9]\{8\}" )
if [ "${FLAG}" != "" ] ; then
    TIME=$( date --utc --date "${TIME}" +00z%d%b%Y )
fi


cat > temp_grads_time2t_tmp_$$.gs <<EOF
'reinit'
rc = gsfallow('on')
'xopen ${CTL}'
t = time2t( ${TIME} )
time_t = t2time( t )
ret = write( "temp_grads_time2t_tmp_$$.txt", t )
ret = write( "temp_grads_time2t_tmp_$$.txt", time_t )
'quit'
EOF
grads -blc temp_grads_time2t_tmp_$$.gs > /dev/null
#T=$( cat temp_grads_time2t_tmp_$$.txt )
T=$( sed temp_grads_time2t_tmp_$$.txt -e "1,1p" -e d )
TIME_T=$( sed temp_grads_time2t_tmp_$$.txt -e "2,2p" -e d )

rm temp_grads_time2t_tmp_$$.gs temp_grads_time2t_tmp_$$.txt

#echo ${T}
#echo ${TIME_T}

if [ "${OPT}" != "" ] ; then
    SEC=$(   date --utc --date "${TIME}"   +%s )
    SEC_T=$( date --utc --date "${TIME_T}" +%s )

    # TIME of T should be later than TIME, i.e. (TIME:*]
    if [ "${OPT}" = "-gt" -a ! ${SEC_T} -gt ${SEC} ] ; then
	let T=T+1

    elif [ "${OPT}" = "-ge" -a ! ${SEC_T} -ge ${SEC} ] ; then
	let T=T+1

    elif [ "${OPT}" = "-lt" -a ! ${SEC_T} -lt ${SEC} ] ; then
	let T=T-1

    elif [ "${OPT}" = "-le" -a ! ${SEC_T} -le ${SEC} ] ; then
	let T=T-1
    fi

fi




echo ${T}
