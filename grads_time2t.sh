#!/bin/sh
. common.sh || exit 1
create_temp
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap 'finish' 0

export LANG=en
export PATH=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd ):${PATH}

CTL=$1
TIME=$2
OPT=$3  # -gt

if [ ! -f "${CTL}" ] ; then
    echo "error in grads_time2t.sh: CTL=${CTL} does not exist." >&2
    exit 1
fi
if [ "${TIME}" = "" ] ; then
    echo "error in grads_time2t.sh: TIME is not specified." >&2
    exit 1
fi

# TIME is YYYYMMDD? -> assumed to be YYYYMMDD 00:00:00
FLAG=$( echo "${TIME}" | grep -e "^[0-9]\{8\}" )
if [ "${FLAG}" != "" ] ; then
    TIME=$( date --utc --date "${TIME}" +00z%d%b%Y ) || exit 1
fi

#cat > temp_grads_time2t_tmp_$$.gs <<EOF
cat > ${TEMP_DIR}/temp.gs <<EOF
'reinit'
rc = gsfallow('on')
'xopen ${CTL}'
t = time2t( ${TIME} )
time_t = t2time( t )
ret = write( "${TEMP_DIR}/temp.txt", t )
ret = write( "${TEMP_DIR}/temp.txt", time_t )
'quit'
EOF
grads -blc ${TEMP_DIR}/temp.gs > /dev/null
T=$( sed ${TEMP_DIR}/temp.txt -e "1,1p" -e d ) || exit 1
TIME_T=$( sed ${TEMP_DIR}/temp.txt -e "2,2p" -e d ) || exit 1
rm ${TEMP_DIR}/temp.gs ${TEMP_DIR}/temp.txt

if [ "${OPT}" != "" ] ; then
    SEC=$(   date --utc --date "${TIME}"   +%s ) || exit 1
    SEC_T=$( date --utc --date "${TIME_T}" +%s ) || exit 1

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
