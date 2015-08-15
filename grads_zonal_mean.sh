#!/bin/sh
. common.sh
create_temp
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

#set -x

export PATH=$( pwd ):${PATH}

CTL=""
VAR=""
OUTPUT=""
TMIN=""
TMAX=""
TINT=1
YMD_MIN=""  # in YYYYMMDD
YMD_MAX=""  # in YYYYMMDD
VERBOSE=0
E_START=
E_END=

if [ "$1" = "" ] ; then
    cat <<EOF
usage:
 $0
     ctl-filename variable-name output-filename
     [ -t tmin[:tmax[:tint]] ]
     [ -ymd ymdmin:ymdmax[:tint] ]
     [ -ymd ("["|"(")ymdmin:ymdmax[:tint](")"|"]") ]
     [ -z zmin[:zmax] ]
EOF
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
        echo "error in $0: $1 is not supported."
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

#VAR_GRADS=$1
#INPUT_CTL=$2
#OUTPUT_DATA=$3
#T_START=$4
#T_END=$5
#E_START=$6   # optional
#E_END=$7     # optional

[ "${E_START}" = "" ] && E_START=1
[ "${E_END}"   = "" ] && E_END=1

DIMS=( $( grads_ctl.pl ${CTL} DIMS NUM ) ) || exit 1 
XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}


# little or big endian
#OPT_ENDIAN=""
#FLAG_BIG_ENDIAN=`get_OPTIONS big_endian`
#FLAG_LITTLE_ENDIAN=`get_OPTIONS little_endian`
#[ "${FLAG_BIG_ENDIAN}" = "1" -a "${FLAG_LITTLE_ENDIAN}" = "1" ] \
#    && echo "error: Ambiguous endian specifications" \
#    && exit
#[ "${FLAG_BIG_ENDIAN}" = "1" ]    && OPT_ENDIAN="-be"
#[ "${FLAG_LITTLE_ENDIAN}" = "1" ] && OPT_ENDIAN="-le"

#echo ${TEMP_DIR}
#exit 1

#for(( i=1; $i<=10; i=$i+1 ))
#do
#    TEMP=`date +%s`
#    GS=monthly_${TEMP}.gs
#    DAT=monthly_${TEMP}.dat
#    [ ! -f ${GS} -o ! -f ${DAT} ] && break
#    [ ! -f ${GS} ] && break
#    sleep 1s
#done
#trap "rm ${GS} ${DAT}" 0
#trap "rm ${GS} " 0


#[ -f ${OUTPUT_DATA} ] && rm -f ${OUTPUT_DATA}
#for(( t=${TMIN}; $t<=${TMAX}; t=$t+1 ))
#do
#    
#done

#INPUT_DATA=`grep ^DSET ${INPUT_CTL} | sed -e "s/DSET  *^//" -e "s/%ch//"`
#echo ${INPUT_DATA}
#exit

#zonal_mean dummy fin fout xdef num undef

#exit

GS=${TEMP_DIR}/temp.gs


cat > ${GS} <<EOF
'reinit'
rc = gsfallow( 'on' )
'xopen ${CTL}'
'set gxout fwrite'
'set undef -0.99900e+35'
'set fwrite -be ${OUTPUT}'
'set x 1'
'set y 1 ${YDEF}'

*if( valnum('${T_START}') = 0 )
*  t_start = time2t( '${T_START}' )
*else
*  t_start = '${T_START}'
*endif
*if( valnum('${T_END}') = 0 )
*  t_end = time2t( '${T_END}' )
*else
*  t_end = '${T_END}'
*endif
t_start = ${TMIN}
t_end = ${TMAX}
e_start = ${E_START}
e_end = ${E_END}

say 't: ' % t_start % ' - ' % t_end % ' (int=${TINT})'
say 'e: ' % e_start % ' - ' % e_end

e = e_start
while( e <= e_end )
  if( e_start != 1 | e_end != 1 )
    say '  e = ' % e % ' / ' e_end
  endif
  'set e 'e

  t = t_start
  while( t <= t_end )
    say '    t = ' % t % ' / ' t_end
    'set t 't

    z = 1
    while( z <= ${ZDEF} )
      'set z 'z
      'd ave( ${VAR}, x=1, x=${XDEF} )'
      'c'
      z = z + 1
    endwhile

    t = t + ${TINT}
  endwhile

e = e + 1
endwhile

'disable fwrite'
'quit'
EOF

#cat ${GS}
#exit 1
grads -blc ${GS} || exit 1

echo "$0 normally finished."
