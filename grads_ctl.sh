#!/bin/sh
#
# common functions for handling GrADS control file by C. Kodama
#
# use "source grads.sh control-file-name" if you want to use this script.
#
GRADS_CTL=$1


###############################
#   OPTIONS
###############################
#
# usage1: FLAG=`get_OPTIONS xrev`
# usage2: if [ `get_OPTIONS LITTLE_ENDIAN` = 1 ]
# true: 1  false: 0
get_OPTIONS()
{
    TARGET=`echo $1 | tr [:lower:] [:upper:]`
    LIST=( `grep -i OPTIONS ${GRADS_CTL} | sed -e "s/^OPTIONS //g"` )
    for ELEMENT in ${LIST[@]}
    do
      ELEMENT=`echo ${ELEMENT} | tr [:lower:] [:upper:]`
      [ "${ELEMENT}" = "${TARGET}" ] && echo "1" && return
    done
    echo "0"
}

###############################
#   XDEF
###############################
#
# usage: XDEF=`get_XDEF`
get_XDEF()
{
#    grads_ctl.pl sw=get_xdef ctl=${GRADS_CTL}
    RET=`grep -i ^XDEF ${GRADS_CTL} | awk '{ print $2 }'`
    [ "${RET}" = "" ] && RET=0
    echo ${RET}
}
#
# usage: XLEVELS=( `get_XDEF_LEVELS` )
# Be careful! First element is number of levels.
# to be deleted
get_XDEF_LEVELS()
{
    get_CORE DEF_LEVELS X
}

# Be careful! First element is NOT number of levels.
get_XDEF_LEVELS2()
{
    grads_ctl.pl \
	ctl=${GRADS_CTL} \
	key=XDEF \
	target=levels
}

###############################
#   YDEF
###############################
#
get_YDEF()
{
    RET=`grep -i ^YDEF ${GRADS_CTL} | awk '{ print $2 }'`
    [ "${RET}" = "" ] && RET=0
    echo ${RET}
}
#
# usage: YLEVELS=( `get_YDEF_LEVELS` )
# Be careful! First element is number of levels.
# to be deleted
get_YDEF_LEVELS()
{
    get_CORE DEF_LEVELS Y
}

# Be careful! First element is NOT number of levels.
get_YDEF_LEVELS2()
{
    grads_ctl.pl \
	ctl=${GRADS_CTL} \
	key=YDEF \
	target=levels
}


###############################
#   ZDEF
###############################
#
get_ZDEF()
{
    RET=`grep -i ^ZDEF ${GRADS_CTL} | awk '{ print $2 }'`
    [ "${RET}" = "" ] && RET=0
    echo ${RET}
}
#
# Be careful! First element is number of levels.
get_ZDEF_LEVELS()
{
    get_CORE DEF_LEVELS Z
}

###############################
#   TDEF
###############################
#
get_TDEF()
{
    RET=`grep -i ^TDEF ${GRADS_CTL} | awk '{ print $2 }'`
    [ "${RET}" = "" ] && RET=0
    echo ${RET}
}

###############################
#   EDEF
###############################
#
get_EDEF()
{
    RET=`grep -i ^EDEF ${GRADS_CTL} | awk '{ print $2 }'`
    [ "${RET}" = "" ] && RET=0
    echo ${RET}
}

#
# $1: unit (optional) : SEC, MN, HR, or DY
#     If unit is NOT specified, then display "value" + "unit", e.g. 60mn
#     If unit is specified, then only display "value", e.g. 60
get_TDEF_INCRE()
{
    local tunit=`echo $1 | tr '[a-z]' '[A-Z]'`
    local ret=`grep -i ^TDEF ${GRADS_CTL} | tr '[a-z]' '[A-Z]' | awk '{ print $5 }'`
    [ "${tunit}" = "" ] && echo ${ret} && return

    local value=`echo ${ret} | sed -e "s/^\([0-9][0-9]*\)\(..*\)$/\1/"`
    local unit=`echo ${ret} | sed -e "s/^\([0-9][0-9]*\)\(..*\)$/\2/"`

    [ "${unit}" = "${tunit}" ] && echo ${value} && return

    local f_tunit=0  # factor to convert to sec 
    [ "${tunit}" = "SEC" ] && f_tunit=1
    [ "${tunit}" = "MN" ]  && f_tunit=60
    [ "${tunit}" = "HR" ]  && f_tunit=3600
    [ "${tunit}" = "DY" ]  && f_tunit=86400
    [ ${f_tunit} -le 0 ] && echo "error" && return
    
    local f_unit=0  # factor to convert to sec 
    [ "${unit}" = "SEC" ] && f_unit=1
    [ "${unit}" = "MN" ]  && f_unit=60
    [ "${unit}" = "HR" ]  && f_unit=3600
    [ "${unit}" = "DY" ]  && f_unit=86400
    [ ${f_unit} -le 0 ] && echo "error" && return

    echo "${value} * ${f_unit} / ${f_tunit}" | bc
}

###############################
#   VARS
###############################
#
get_VDEF()
{
    grep -i ^VARS ${GRADS_CTL} | awk '{ print $2 }'
}
#
get_VARLIST()
{
    get_CORE VARLIST
}



##########################################################
#   BELOW internal use only
##########################################################

#
# for complicated process
#
# key1 = DEF_LEVELS
#   key2 = X : X levels
#        = Y : Y levels
#        = Z : Z levels
#
# key1 = VARLIST
#
#
#
get_CORE()
{
    local key1=$1
    local key2=$2

    local world_start=0
    local world="" # current world

    local KEYWORDS=( "DSET" "CHSUB" "DTYPE" "INDEX" "STNMAP" \
                     "TITLE" "UNDEF" "UNPACK" "FILEHEADER" "XYHEADER" \
                     "THEADER" "HEADERBYTES" "TRAILERBYTES" "XVAR" "YVAR" \
                     "ZVAR" "STID" "TVAR" "TOFFVAR" "OPTIONS" \
                     "PDEF" "XDEF" "YDEF" "ZDEF" "TDEF" \
	"EDEF" "VECTORPAIRS" "VARS" "ENDVARS" )

    local n_start=1
    if [ "${key1}" == "DEF_LEVELS" ]
    then
	local n_start=`grep -n "^ *${key2}DEF" ${GRADS_CTL} | cut -d: -f 1`
    fi
    local n_end=`wc ${GRADS_CTL} | awk '{ print $1 }'`

    for(( n=${n_start}; ${n}<=${n_end}; n=${n}+1 ))
    do
        local line=`sed ${GRADS_CTL} -e "${n},${n}p" -e d`

	# determine current world
        local first=0
        local temp=`echo $line | awk '{ print $1 }'`
	for KEYWORD in ${KEYWORDS[@]}
	do
	    if [ "`echo ${temp} | grep -i $KEYWORD`" != ""  ]
	    then
		local world=`echo ${temp} | tr "[a-z]" "[A-Z]"`
		local first=1  # whether the world change or not
		break
	    fi
	done
	#echo ${world}

	if [ "${key1}" == "DEF_LEVELS" ]
        then
	    if [ "${world}" == "${key2}DEF" -a ${first} -eq 1 ]
            then
		local world_start=1
	        # local XDEF=`grep XDEF ${GRADS_CTL} | awk '{ print $2 }'`
		local DEF=`echo $line | awk '{ print $2 }'`
		echo "${DEF} " # first element

		local DEF_TYPE=`echo $line | awk '{ print $3 }' \
                                           | tr "[a-z]" "[A-Z]"`
		
		if [ "${DEF_TYPE}" == "LINEAR" ]
                then
#		    echo "error: not supported" >&2
		    local DEF_START=`echo $line | awk '{ print $4 }'`
		    local DEF_INCRE=`echo $line | awk '{ print $5 }'`
		    for(( i=1; $i<=${DEF}; i=$i+1 ))
		    do
		        echo -n `echo "${DEF_START} + ( $i - 1 ) * ${DEF_INCRE}" | bc`
			echo -n " "
		    done
		    return
                fi

		local TEMP=( `echo $line` )
		for(( i=3; $i<=${#TEMP[@]}-1; i=$i+1 ))
                do
		    echo -n "${TEMP[$i]} "
		done


	    elif [ "${world}" == "${key2}DEF" -a ${first} -ne 1 ]
            then
		local TEMP=( `echo $line` )
		for(( i=0; $i<=${#TEMP[@]}-1; i=$i+1 ))
		do
		    echo -n "${TEMP[$i]} "
		done
	    
	    elif [ ${world_start} -eq 1 ]
	    then
		return
	    fi
	fi  # end of DEF_LEVELS


	if [ "${key1}" == "VARLIST" -a "${world}" == "VARS" -a ${first} -eq 0 ]
        then
	    VAR=`echo $line | awk '{ print $1 }'`
	    echo -n "${VAR} "
	fi  # end of VARLIST


    done

}


