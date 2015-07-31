#!/bin/sh
#
# just type ./get_data.sh for usage
#
export LANG=en
export PATH=$( pwd ):${PATH}


CTL=""
VAR=""
OUTPUT=""
TMIN=""
TMAX=""
ZMIN=1
ZMAX=""
TINT=1
YMD_MIN=""  # in YYYYMMDD
YMD_MAX=""  # in YYYYMMDD
VERBOSE=0

if [ "$1" = "" ] ; then
    cat <<EOF
usage:
 get_data.sh ctl-filename variable-name output-filename
             -t tmin[:tmax[:tint]]
             [ -ymd ymdmin:ymdmax[:tint] ]
             [ -ymd ("["|"(")ymdmin:ymdmax[:tint](")"|"]") ]
             -z zmin[:zmax]
EOF
#               -gdate gdatemin:gdatemax[:tint]
    exit
fi


while [ "$1" != "" ] ; do

    if [ "$1" = "-t" ] ; then
	shift; TMP=$1
	TMIN=$( echo ${TMP} | cut -d : -f 1 )
	TMAX=$( echo ${TMP} | cut -d : -f 2 )
	TINT=$( echo ${TMP} | cut -d : -f 3 )
	[ "${TMAX}" = "" ] && TMAX=${TMIN}
	[ "${TINT}" = "" ] && TINT=1

    elif [ "$1" = "-z" ] ; then
	shift; TMP=$1
	ZMIN=$( echo ${TMP} | cut -d : -f 1 )
	ZMAX=$( echo ${TMP} | cut -d : -f 2 )
	[ "${ZMAX}" = "" ] && ZMAX=${ZMIN}

    elif [ "$1" = "-ymd" ] ; then
	shift; TMP=$1
	YMD_MIN=$( echo ${TMP} | cut -d : -f 1 )
	YMD_MAX=$( echo ${TMP} | cut -d : -f 2 )
	TINT=$( echo ${TMP} | cut -d : -f 3 )
	[ "${TINT}" = "" ] && TINT=1

    elif [ "$1" = "-v" ] ; then
	let VERBOSE=VERBOSE+1

    elif [ "${CTL}" = "" ] ; then
	CTL=$1

    elif [ "${VAR}" = "" ] ; then
	VAR=$1

    elif [ "${OUTPUT}" = "" ] ; then
	OUTPUT=$1

    else
	echo "error in get_data.sh: $1 is not supported."
	exit 1
    fi

    shift
done

if [ ${VERBOSE} -gt 1 ] ; then
    echo "CTL: ${CTL}"
    echo "VAR: ${VAR}"
    echo "OUTPUT: ${OUTPUT}"
    
    echo "TMIN: ${TMIN}"
    echo "TMAX: ${TMAX}"
    echo "TINT: ${TINT}"
    echo "YMD_MIN: ${YMD_MIN}"
    echo "YMD_MAX: ${YMD_MAX}"
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
#    GRADS_MIN=$( date --date "${YMD_MIN}" +00z%d%b%Y )
#    GRADS_MAXPP=$( date --date "${YMD_MAX} 1 days" +00z%d%b%Y )
fi


if [ ${VERBOSE} -eq 1 ] ; then
    echo "get_data.sh: TMIN=${TMIN}, TMAX=${TMAX}, TINT=${TINT}, CTL=${CTL}"
fi


GS=temp_get_data_$$.gs

cat > ${GS} <<EOF
'reinit'
rc = gsfallow( 'on' )
'xopen ${CTL}'
'set gxout fwrite'
'set fwrite -be ${OUTPUT}'
'set undef -0.99900E+35'
xdef = qctlinfo( 1, 'xdef', 1 )
ydef = qctlinfo( 1, 'ydef', 1 )
if( '${ZMAX}' = '' )
  zmax = qctlinfo( 1, 'zdef', 1 )
else
  zmax = '${ZMAX}'
endif
say xdef
'set x 1 'xdef
'set y 1 'ydef
tmin = ${TMIN}
tmax = ${TMAX}
t = tmin
while( t <= tmax )
  say 't = ' % t
  'set t 't
  z = ${ZMIN}
  while( z <= zmax )
*    say '  z = ' % z
    'set z 'z
    'd ${VAR}'
    z = z + 1
  endwhile
  t = t + ${TINT}
endwhile
'disable fwrite'
'quit'
EOF
if [ ${VERBOSE} -gt 1 ] ; then
    cat ${GS}
    grads -blc ${GS} || exit e
else
    grads -blc ${GS} > /dev/null  || exit 1
fi

rm ${GS}

