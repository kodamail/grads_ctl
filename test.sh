#!/bin/sh

#perl grads_ctl.pl \
#    ctl=/cwork5/kodama/dataset/jra25/raw_data/pressure/t/t.ctl \
#    sw=get_xdef
#
#exit

export PATH=${PATH}:./  # only needs for test

# いずれ grads_ctl.pl に全面移行した方がいい気がする


#CTL=/cwork5/kodama/dataset/jra25/raw_data/pressure/t/t.ctl
#CTL=/cwork5/kodama/nicam_product/200406.new_by_noda/run/ctl/ms_tem.ctl
CTL=/cwork5/kodama/COLA/ifs/t2047/x320/2001/ctl/IFS_T159_summer.ctl

#RET=`grads_ctl.pl ctl=${CTL} key=xdef target=type`
#RET=`grads_ctl.pl ctl=${CTL} key=XDEF target=3`
#RET=`grads_ctl.pl ctl=${CTL} key=XDEF target=all`
#RET=`grads_ctl.pl ctl=${CTL} key=TDEF target=STEP unit=MN`
#RET=`grads_ctl.pl ctl=${CTL} key=OPTIONS target=YREV`
#RET=`grads_ctl.pl ctl=${CTL} key=VAR_LIST`
#RET=`grads_ctl.pl ctl=${CTL} key=VAR var=geop target=LEVS`
#RET=`grads_ctl.pl ctl=${CTL} key=VAR var=geop target=UNITS`
#RET=`grads_ctl.pl ctl=${CTL} key=VAR var=t target=COMMENT`
#RET=`grads_ctl.pl ctl=${CTL} key=XDEF`
#RET=`grads_ctl.pl ctl=${CTL} key=CHSUB`
RET=`grads_ctl.pl ctl=${CTL} key=TITLE`
echo ${RET}

exit
#grads_ctl.pl ctl=/cwork5/kodama/dataset/jra25/raw_data/pressure/t/t.ctl \
#             key=xdef target=level pos=6

#grads_ctl.pl \
#    ctl=/cwork5/kodama/nicam_product/200406.new_by_noda/run/ctl/ms_tem.ctl \
#    key=xdef target=level pos=6


#exit

#source ./grads_ctl.sh /cwork5/kodama/dataset/jra25/raw_data/pressure/t/t.ctl
source ./grads_ctl.sh /cwork5/kodama/nicam_product/200406.new_by_noda/run/ctl/ms_tem.ctl 
XDEF=`get_XDEF`
#get_YDEF_LEVELS2
#exit
YLEVELS=(`get_YDEF_LEVELS2`)
echo ${XDEF}
echo ${YLEVELS[0]}

exit


#echo `get_XDEF`

FLAG=`get_OPTIONS LITTLE_ENDIAN`
FLAG=`get_OPTIONS xrev`
#if [${FLAG} ]
#if [ `get_OPTIONS LITTLE_ENDIAN` ]
#if [ `get_OPTIONS xrev` = 1 ]

if [ `get_OPTIONS LITTLE_ENDIAN` = 1 ]
then
    echo "true"
else
    echo "false"
fi
