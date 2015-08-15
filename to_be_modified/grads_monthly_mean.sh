#!/bin/sh

#YEAR=2004
#MONTH=1
#INPUT_DIR=/cwork5/kodama/dataset/jra25/raw_data/pressure/g
#OUTPUT_DIR=/cwork5/kodama/dataset/jra25/data_conv/pressure/288x145/monthly/g
#VAR_GRADS=g

YEAR=$1
MONTH=$2
VAR_GRADS=$3
INPUT_CTL=$4
OUTPUT_DATA=$5
#OUTPUT_CTL=$6    # optional


#source grads_ctl.sh ${INPUT_CTL}
#XDEF=`get_XDEF`
#YDEF=`get_YDEF`
#ZDEF=`get_ZDEF`

XDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=XDEF target=NUM )
YDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=YDEF target=NUM )
ZDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=ZDEF target=NUM )
EDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=EDEF target=NUM )
DAYS=`date --date "${YEAR}-${MONTH}-01 +1month-1days" +%d`

NEXT_YEAR=`date --date "${YEAR}-${MONTH}-01 +1month" +%Y`
NEXT_MONTH=`date --date "${YEAR}-${MONTH}-01 +1month" +%m`



# little or big endian
OPT_ENDIAN=""
FLAG_BIG_ENDIAN=$( grads_ctl.pl ctl=${INPUT_CTL} key="OPTIONS" target="big_endian" )
FLAG_LITTLE_ENDIAN=$( grads_ctl.pl ctl=${INPUT_CTL} key="OPTIONS" target="little_endian" )
#FLAG_BIG_ENDIAN=`get_OPTIONS big_endian`
#FLAG_LITTLE_ENDIAN=`get_OPTIONS little_endian`
[ "${FLAG_BIG_ENDIAN}" = "1" -a "${FLAG_LITTLE_ENDIAN}" = "1" ] \
    && echo "error: Ambiguous endian specifications" \
    && exit 1
[ "${FLAG_BIG_ENDIAN}" = "1" ]    && OPT_ENDIAN="-be"
[ "${FLAG_LITTLE_ENDIAN}" = "1" ] && OPT_ENDIAN="-le"

for(( i=1; $i<=10; i=$i+1 ))
do
    TEMP=$( date +%s )
    GS=monthly_${TEMP}.gs
    [ ! -f ${GS} ] && break
    sleep 1s
done




for(( e=1; ${e}<=${EDEF}; e=${e}+1 ))
do
    STR_ENS=""
    if [ ${EDEF} -gt 1 ] ; then
	STR_ENS=${e}
	[ ${e} -lt 100 ] && STR_ENS="0${STR_ENS}"
	[ ${e} -lt 10  ] && STR_ENS="0${STR_ENS}"
	STR_ENS="_bin${STR_ENS}"
    fi

    OUTPUT_FILE=${OUTPUT_DATA}${STR_ENS}

    trap "rm ${GS}" 0
    cat > ${GS} <<EOF
'reinit'
rc = gsfallow( 'on' )
'open ${INPUT_CTL}'
'set gxout fwrite'
'set undef dfile'
'set fwrite ${OPT_ENDIAN} ${OUTPUT_FILE}'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set t 1'
'set e ${e}'
if( '${EDEF}' > 1 )
  say 'e = ${e} / ${EDEF}'
endif
cm = cmonth( ${MONTH}, 3 )
next_cm = cmonth( ${NEXT_MONTH}, 3 )
temp = time2t( '01'next_cm'${NEXT_YEAR}' )
t_start = t2time( time2t( '01'cm'${YEAR}' ) )
t_end = t2time( temp - 1 )
say '  ave( ${VAR_GRADS}, time='t_start', time='t_end' )'
*say 'ave( ${VAR_GRADS}, time=01'cm'${YEAR}, time= 18z${DAYS}'cm'${YEAR} )'
z = 1
while( z <= ${ZDEF} )
  say '  z = ' % z % ' / ' ${ZDEF}
  'set z 'z
  'd ave( ${VAR_GRADS}, time='t_start', time='t_end' )'
  'c'
  z = z + 1
endwhile
'disable fwrite'
'quit'
EOF
    grads -blc ${GS}

done

# create control file
#if [ "${OUTPUT_CTL}" != "" ]
#then
#    sed ${INPUT_CTL} -e "s/yrev//gi" -e "s/6hr/1mo/" > ${OUTPUT_CTL}
#fi
