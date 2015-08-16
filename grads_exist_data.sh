#!/bin/sh
#
# check existence of files (do not check file size)
#
# If succeed, output "ok" and list of filename
#
export LANG=en
export PATH=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd ):${PATH}


CTL=""   # control file name
TMIN=""
TMAX=""
YMD_MIN=""  # in YYYYMMDD -> YYYYMMDD 00:00:00
YMD_MAX=""  # in YYYYMMDD -> YYYYMMDD 00:00:00
VERBOSE=0
LIST=0

if [ "$1" = "" ] ; then
    cat <<EOF
usage:
 $0
     ctl-filename 
     -t tmin[:tmax]
     [ -ymd ymdmin:ymdmax ]
     [ -ymd ("["|"(")ymdmin:ymdmax(")"|"]") ]
     [-list]
EOF
    exit
fi

while [ "$1" != "" ] ; do
    if [ "$1" = "-t" ] ; then
        shift; TMP=$1
        TMIN=$( echo ${TMP} | cut -d : -f 1 )
        TMAX=$( echo ${TMP} | cut -d : -f 2 )
        [ "${TMAX}" = "" ] && TMAX=${TMIN}

    elif [ "$1" = "-ymd" ] ; then
        shift; TMP=$1
        YMD_MIN=$( echo ${TMP} | cut -d : -f 1 )
        YMD_MAX=$( echo ${TMP} | cut -d : -f 2 )

    elif [ "$1" = "-v" ] ; then
        let VERBOSE=VERBOSE+1

    elif [ "$1" = "-list" ] ; then
        LIST=1

    elif [ "${CTL}" = "" ] ; then
        CTL=$1

    else
        echo "error in $0: $1 is not supported." >&2
        exit 1
    fi

    shift
done

#-------------------------------------------------------#

if [ ! -f "${CTL}" ] ; then
    echo "error in $0: CTL=${CTL} does not exist." >&2
    exit 1
fi

if [ "${YMD_MIN}" != "" -a "${YMD_MAX}" != "" ] ; then
    if [ "${YMD_MIN:0:1}" = "(" ] ; then
        TMIN=$( grads_time2t.sh ${CTL} ${YMD_MIN:1:8} -gt ) || exit 1
    elif [ "${YMD_MIN:0:1}" = "[" ] ; then
        TMIN=$( grads_time2t.sh ${CTL} ${YMD_MIN:1:8} -ge ) || exit 1
    else
        TMIN=$( grads_time2t.sh ${CTL} ${YMD_MIN:0:8} -ge ) || exit 1
    fi

    TMP=${YMD_MAX:${#YMD_MAX}-1:1}
    if [ "${TMP}" = ")" ] ; then
        TMAX=$( grads_time2t.sh ${CTL} ${YMD_MAX:0:8} -lt ) || exit 1
    else
        TMAX=$( grads_time2t.sh ${CTL} ${YMD_MAX:0:8} -le ) || exit 1
    fi
fi

if [ ${VERBOSE} -eq 1 ] ; then
    echo "$0: TMIN=${TMIN}, TMAX=${TMAX}, CTL=${CTL}" >&2
fi

if [ ${TMIN} -gt ${TMAX} ] ; then
    echo "error in $0: tmin(=${TMIN}) > tmax(=${TMAX})" >&2
    exit 1
fi
TDEF=( $( grads_ctl.pl ${CTL} TDEF NUM ) ) || exit 1
if [ ${TMIN} -lt 1 -o ${TMAX} -gt ${TDEF} ] ; then
    echo "fail_tdef_out_of_range"
    exit
fi

STATUS="ok"
DSET_LIST=( $( grads_ctl.pl ${CTL} DSET "${TMIN}:${TMAX}" ) ) || exit 1
FILE_LIST=()
for DSET in ${DSET_LIST[@]} ; do
    FILE=$( echo "${DSET}" | sed -e "s|^^|${CTL%/*}/|" ) || exit 1
    FILE_LIST[${#FILE_LIST[@]}]=${FILE}

    if [ ! -f ${FILE} ] ; then
	STATUS="fail_file_exist"
	break
    fi
done

# display
echo ${STATUS}
if [ ${LIST} -eq 1 ] ; then
    for FILE in ${FILE_LIST[@]} ; do
    echo ${FILE}
    done
fi

exit
