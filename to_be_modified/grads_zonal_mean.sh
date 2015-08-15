#!/bin/sh

#YEAR=2004
#MONTH=1
#INPUT_DIR=/cwork5/kodama/dataset/jra25/raw_data/pressure/g
#OUTPUT_DIR=/cwork5/kodama/dataset/jra25/data_conv/pressure/zonal145/tstep/g
#VAR_GRADS=g

#YEAR=$1
#MONTH=$2

VAR_GRADS=$1
INPUT_CTL=$2
OUTPUT_DATA=$3
T_START=$4
T_END=$5
E_START=$6   # optional
E_END=$7     # optional

[ "${E_START}" = "" ] && E_START=1
[ "${E_END}"   = "" ] && E_END=1

source grads_ctl.sh ${INPUT_CTL}
XDEF=`get_XDEF`
YDEF=`get_YDEF`
ZDEF=`get_ZDEF`

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
#    DAT=monthly_${TEMP}.dat
#    [ ! -f ${GS} -o ! -f ${DAT} ] && break
    [ ! -f ${GS} ] && break
    sleep 1s
done
#trap "rm ${GS} ${DAT}" 0
trap "rm ${GS} " 0


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




cat > ${GS} <<EOF
'reinit'
rc = gsfallow( 'on' )
'open ${INPUT_CTL}'
'set gxout fwrite'
'set undef dfile'
'set fwrite ${OPT_ENDIAN} ${OUTPUT_DATA}'
'set x 1'
'set y 1 ${YDEF}'
if( valnum('${T_START}') = 0 )
  t_start = time2t( '${T_START}' )
else
  t_start = '${T_START}'
endif
if( valnum('${T_END}') = 0 )
  t_end = time2t( '${T_END}' )
else
  t_end = '${T_END}'
endif
e_start = ${E_START}
e_end = ${E_END}

say 't: ' % t_start % ' - ' t_end
say 'e: ' % e_start % ' - ' e_end

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
      'd ave( ${VAR_GRADS}, x=1, x=${XDEF} )'
      'c'
      z = z + 1
    endwhile

    t = t + 1
  endwhile

e = e + 1
endwhile

'disable fwrite'
'quit'
EOF
grads -blc ${GS}
