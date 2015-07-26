#!/bin/sh
#
# check existence of files
#
# If succeed, output "ok" and list of filename
#

# control file name
CTL=$1

# start and end time (e.g. 00z01jun2004)
TIME_START=$2
TIME_END=$3

# flag to specify exact time range (optional)
#   = ""     : [TIME_START:TIME_END]
#   = "MM"   : (TIME_START:TIME_END]
#   = "PP"   : [TIME_START:TIME_END)
#   = "MMPP":  (TIME_START:TIME_END)
TIME_FLAG=$4

#-------------------------------------------------------#

if [ ! -f "${CTL}" ] ; then
    echo "error in exist_data.sh: CTL=${CTL} does not exist."
    exit 1
fi

TEMP=$( date +%s )
cat > exist_data_${TEMP}.gs <<EOF
'reinit'
rc = gsfallow( 'on' )
'xopen -t ${CTL}'
type = sublin( result, 1 )
type = subwrd( type, 2 )
tmin = time2t( '${TIME_START}' )
tmax = time2t( '${TIME_END}' )
if( '${TIME_FLAG}' = 'PP' | '${TIME_FLAG}' = 'MMPP' )
  tmax = tmax - 1
endif
if( '${TIME_FLAG}' = 'MM' | '${TIME_FLAG}' = 'MMPP' )
  tmin = tmin + 1
endif
ret = write( "exist_data_${TEMP}.txt", tmin )
ret = write( "exist_data_${TEMP}.txt", tmax )
ret = write( "exist_data_${TEMP}.txt", type )
'quit'
EOF
#cat exist_data_${TEMP}.gs >&2
#grads -blc exist_data_${TEMP}.gs #> /dev/null
TYPE=$( grads -blc exist_data_${TEMP}.gs | grep ^using | awk '{ print $2 }' )
TMIN=$( sed exist_data_${TEMP}.txt -e "1,1p" -e d )
TMAX=$( sed exist_data_${TEMP}.txt -e "2,2p" -e d )
#TYPE=$( sed exist_data_${TEMP}.txt -e "3,3p" -e d )
rm exist_data_${TEMP}.gs exist_data_${TEMP}.txt
#echo "${TYPE}"
#echo "${TMIN} ${TMAX}"
#echo "ok"
#exit


if [ "${TYPE}" = "open" ] ; then
    EXT="grd"
#    XDEF=$( grads_ctl.pl ctl="${CTL}" key="XDEF" target="NUM" )
#    YDEF=$( grads_ctl.pl ctl="${CTL}" key="YDEF" target="NUM" )
#    ZDEF=$( grads_ctl.pl ctl="${CTL}" key="ZDEF" target="NUM" )
    DIMS=( $( grads_ctl.pl ${CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]} ; TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    VDEF=$( grep -i "^VARS" ${CTL} | awk '{ print $2 }' )

elif [ "${TYPE}" = "xdfopen" ] ; then
    EXT="nc"
else
    echo "error: TYPE=${TYPE} is not supported." >&2
    exit 1
fi


DSET=$( grep -i "^DSET" ${CTL} )
TEMP=$( echo ${DSET} | grep "%ch" )

# if DSET include %ch ...
if [ "${TEMP}" != "" ] ; then
#
# create CHSUB_LIST which is necessary
#
    LIST_TMIN=( )
    LIST_TMAX=( )
    LIST_CHSUB=( )
    CHSUB_TMIN=(  $( grep -i "^CHSUB" ${CTL} | awk '{ print $2 }' ) )
    CHSUB_TMAX=(  $( grep -i "^CHSUB" ${CTL} | awk '{ print $3 }' ) )
    CHSUB_CHSUB=( $( grep -i "^CHSUB" ${CTL} | awk '{ print $4 }' ) )
    for(( f=0; ${f}<${#CHSUB_CHSUB[@]}; f=${f}+1 )) ; do
#    echo ${f} ${CHSUB_TMIN[$f]} ${CHSUB_TMAX[$f]}
	HIT=0
	
	if [   ${CHSUB_TMIN[$f]} -le ${TMIN} \
	    -a           ${TMIN} -le ${CHSUB_TMAX[$f]} ] ; then
	    HIT=1
	elif [ ${CHSUB_TMIN[$f]} -le ${TMAX} \
	    -a         ${TMAX} -le ${CHSUB_TMAX[$f]} ] ; then
	    HIT=1
	elif [ ${TMIN} -le ${CHSUB_TMIN[$f]} \
	    -a ${TMAX} -ge ${CHSUB_TMAX[$f]} ] ; then
	    HIT=1
	fi
	
	if [ ${HIT} -eq 1 ] ; then
	    LIST_TMIN=(  ${LIST_TMIN[@]}  ${CHSUB_TMIN[$f]} )
	    LIST_TMAX=(  ${LIST_TMAX[@]}  ${CHSUB_TMAX[$f]} )
	    LIST_CHSUB=( ${LIST_CHSUB[@]} ${CHSUB_CHSUB[$f]} )
	fi
    done
    
    STATUS="ok"
        
    FILE_LIST=()
    for(( f=0; ${f}<${#LIST_CHSUB[@]}; f=${f}+1 )) ; do
	DIR=${CTL%${CTL##*/}}
	FILE=$( echo ${DSET} | sed \
	    -e "s|%ch|${LIST_CHSUB[$f]}|" \
	    -e "s|DSET  *^|${DIR}|" \
	    -e "s|DSET  *||" \
	    )
	FILE_LIST=( ${FILE_LIST[@]} ${FILE} )
    done

    for(( f=0; ${f}<${#LIST_CHSUB[@]}; f=${f}+1 )) ; do

	# check file existence 
	if [ ! -f ${FILE_LIST[$f]} ] ; then
	    STATUS="fail_file_exist"
	    break
	fi

	[ "${EXT}" = "nc" ] && continue

        # file size check
	let TINT=LIST_TMAX[$f]-LIST_TMIN[$f]+1
	SIZE_OUT=$( ls -lL ${FILE_LIST[$f]} | awk '{ print $5 }' )
	SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*${ZDEF}*${VDEF}*${TINT} | bc )
	if [ ${SIZE_OUT} -ne ${SIZE_OUT_EXACT} ] ; then
	    STATUS="fail_file_size"
	    break
	fi
    done
    
    # display
    echo ${STATUS}
    for FILE in ${FILE_LIST[@]} ; do
	echo ${FILE}
    done

else
    echo "except %ch is not supported"
    exit 1
fi
