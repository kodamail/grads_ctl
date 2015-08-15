#!/bin/sh

#YEAR=2004
#MONTH=1
#INPUT_DIR=/cwork5/kodama/dataset/jra25/raw_data/pressure/g
#OUTPUT_DIR=/cwork5/kodama/dataset/jra25/data_conv/pressure/288x145/monthly/g
#VAR_GRADS=g

YEAR=$1
VAR_GRADS=$2
INPUT_CTL=$3
OUTPUT_DATA=$4
#OUTPUT_CTL=$5    # optional


source grads_ctl.sh ${INPUT_CTL}
XDEF=`get_XDEF`
YDEF=`get_YDEF`
ZDEF=`get_ZDEF`
#DAYS=`date --date "${YEAR}-01-01 +1month-1days" +%d`

#NEXT_YEAR=`date --date "${YEAR}-${MONTH}-01 +1month" +%Y`
NEXT_YEAR=`expr ${YEAR} + 1`


# little or big endian
OPT_ENDIAN=""
FLAG_BIG_ENDIAN=`get_OPTIONS big_endian`
FLAG_LITTLE_ENDIAN=`get_OPTIONS little_endian`
[ "${FLAG_BIG_ENDIAN}" = "1" -a "${FLAG_LITTLE_ENDIAN}" = "1" ] \
    && echo "error: Ambiguous endian specifications" \
    && exit
[ "${FLAG_BIG_ENDIAN}" = "1" ]    && OPT_ENDIAN="-be"
[ "${FLAG_LITTLE_ENDIAN}" = "1" ] && OPT_ENDIAN="-le"

for(( i=1; $i<=10; i=$i+1 ))
do
    TEMP=`date +%s`
    GS=monthly_${TEMP}.gs
    [ ! -f ${GS} ] && break
    sleep 1s
done

trap "rm ${GS}" 0
cat > ${GS} <<EOF
'reinit'
rc = gsfallow( 'on' )
'open ${INPUT_CTL}'
'set gxout fwrite'
'set undef dfile'
'set fwrite ${OPT_ENDIAN} ${OUTPUT_DATA}'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set t 1'
*cm = cmonth( ${MONTH}, 3 )
*next_cm = cmonth( ${NEXT_MONTH}, 3 )
temp = time2t( '01jan${NEXT_YEAR}' )
t_start = t2time( time2t( '01jan${YEAR}' ) )
t_end = t2time( temp - 1 )
say 'ave( ${VAR_GRADS}, time='t_start', time='t_end' )'
*say 'ave( ${VAR_GRADS}, time=01'cm'${YEAR}, time= 18z${DAYS}'cm'${YEAR} )'
z = 1
while( z <= ${ZDEF} )
  say 'z = ' % z % ' / ' ${ZDEF}
  'set z 'z
  'd ave( ${VAR_GRADS}, time='t_start', time='t_end' )'
  'c'
  z = z + 1
endwhile
'disable fwrite'
'quit'
EOF
grads -blc ${GS}

# create control file
#if [ "${OUTPUT_CTL}" != "" ]
#then
#    sed ${INPUT_CTL} -e "s/yrev//gi" -e "s/6hr/1mo/" > ${OUTPUT_CTL}
#fi
