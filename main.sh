# main driver script
tstart=`date +%s`
# single resolution hybrid using jacobian in the EnKF

# allow this script to submit other scripts on WCOSS
unset LSB_SUB_RES_REQ 

source $datapath/fg_only.sh # define fg_only variable (true for cold start).
echo "nodes = $NODES"

export startupenv="${datapath}/analdate.sh"
source $startupenv

#------------------------------------------------------------------------
mkdir -p $datapath

echo "BaseDir: ${basedir}"
echo "DataPath: ${datapath}"

############################################################################
# Main Program

echo "starting the cycle"

# substringing to get yr, mon, day, hr info
export yr=`echo $analdate | cut -c1-4`
export mon=`echo $analdate | cut -c5-6`
export day=`echo $analdate | cut -c7-8`
export hr=`echo $analdate | cut -c9-10`
export ANALHR=$hr
# environment analdate
export datapath2="${datapath}/${analdate}/"

# current analysis time.
export analdate=$analdate
# previous analysis time.
FHOFFSET=`expr $ANALINC \/ 2`
export analdatem1=`${incdate} $analdate -$ANALINC`
# next analysis time.
export analdatep1=`${incdate} $analdate $ANALINC`
# beginning of current assimilation window
export analdatem3=`${incdate} $analdate -$FHOFFSET`
# beginning of next assimilation window
export analdatep1m3=`${incdate} $analdate $FHOFFSET`
# end of next assimilation window
export analdatep1p3=`${incdate} $analdatep1 $FHOFFSET`
export hrp1=`echo $analdatep1 | cut -c9-10`
export hrm1=`echo $analdatem1 | cut -c9-10`
export hr=`echo $analdate | cut -c9-10`
export datapathp1="${datapath}/${analdatep1}/"
export datapathm1="${datapath}/${analdatem1}/"
mkdir -p $datapathp1
export CDATE=$analdate

date
echo "analdate minus 1: $analdatem1"
echo "analdate: $analdate"
echo "analdate plus 1: $analdatep1"

# make log dir for analdate
export current_logdir="${datapath2}/logs"
echo "Current LogDir: ${current_logdir}"
mkdir -p ${current_logdir}
# if a current log file exits move it
if [[ -f ${current_logdir}/run_fg_control.out ]];then
   if [[ -f ${current_logdir}/run_fg_control.out.failed.3 ]];then
      mv ${current_logdir}/run_fg_control.out.failed.1 ${current_logdir}/run_fg_control.out.failed.4
   fi
   if [[ -f ${current_logdir}/run_fg_control.out.failed.2 ]];then
      mv ${current_logdir}/run_fg_control.out.failed.1 ${current_logdir}/run_fg_control.out.failed.3
   fi
   if [[ -f ${current_logdir}/run_fg_control.out.failed.1 ]];then
      mv ${current_logdir}/run_fg_control.out.failed.1 ${current_logdir}/run_fg_control.out.failed.2
   fi
   if [[ -f ${current_logdir}/run_fg_control.out.failed ]];then
      mv ${current_logdir}/run_fg_control.out.failed ${current_logdir}/run_fg_control.out.failed.1
   fi
   mv ${current_logdir}/run_fg_control.out ${current_logdir}/run_fg_control.out.failed
fi

export PREINP="${RUN}.t${hr}z."
export PREINP1="${RUN}.t${hrp1}z."
export PREINPm1="${RUN}.t${hrm1}z."
 
if [ $RES_INC -lt $RES ] && [ $cold_start == 'false' ] ; then
   charnanal='control'
   echo "$analdate reduce resolution of FV3 history files `date`"
   iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
# IAU - multiple increments.
   for fh in $iaufhrs2; do
   # run concurrently, wait
   sh ${scriptsdir}/chgres.sh $datapath2/sfg_${analdate}_fhr0${fh}_${charnanal} ${replayanaldir_lores}/${analfileprefix_lores}_${analdate}.nc $datapath2/sfg_${analdate}_fhr0${fh}_${charnanal}.chgres > ${current_logdir}/chgres_fhr0${fh}.out
   errstatus=$?
   if [ $errstatus -ne 0 ]; then
     errexit=$errstatus
   fi
   fh=$((fh+FHOUT))
   if [ $errexit -ne 0 ]; then
      echo "adjustps/chgres step failed, exiting...."
      exit 1
   fi
   done
   echo "$analdate done reducing resolution of FV3 history files `date`"
fi
# run these steps in parallel,  all logic checks are perfomed inside these wrapper scripts

sh ${scriptsdir}/gsi_step.sh > ${current_logdir}/gsi_step.out 2>&1 &
pid1=$!
echo "gsi_step=" $pid1
sleep 2
# run snow DA 
${scriptsdir}/snow_da_step.sh > ${current_logdir}/snow_da_step.out 2>&1 &
pid2=$!
echo "snow_da_step=" $pid2
sleep 2
#  update sea-ice
${scriptsdir}/update_ice_step.sh > ${current_logdir}/update_ice_step.out 2>&1 &
pid3=$!
echo "update_ice_step=" $pid3
sleep 2
#  calculate ocean imcrement
${scriptsdir}/ocn_inc_step.sh > ${current_logdir}/ocn_inc_step.out 2>&1 &
pid4=$!
echo "ocn_inc_step=" $pid4
sleep 2
#  calculate atm_increment
${scriptsdir}/atm_inc_step.sh > ${current_logdir}/atm_inc_step.out 2>&1 &
pid5=$!
echo "atm_inc_step=" $pid5
sleep 2
# wait for the 5 background processes
wait $pid1
ec1=$?
wait $pid2
ec2=$?
wait $pid3
ec3=$?
wait $pid4
ec4=$?
wait $pid5
ec5=$?

if [ $ec1 == 0 ] && [ $ec2 == 0 ] && [ $ec3 == 0 ] && [ $ec4 == 0 ] && [ $ec5 == 0 ]; then
   echo "all parallel steps finished"
   sleep 5
else 
   if [ $ec1 != 0 ]; then
       echo "GSI step failed"
   fi
   if [ $ec2 != 0 ]; then
       echo "snow DA step failed"
   fi
   if [ $ec3 != 0 ]; then
       echo "update ice step failed"
   fi
   if [ $ec4 != 0 ]; then
       echo "ocn_inc step failed"
   fi
   if [ $ec5 != 0 ]; then
       echo "atm_inc step failed"
   fi
   exit 1
fi

echo "$analdate run high-res control first guess `date`"
sh ${scriptsdir}/run_fg_control.sh  > ${current_logdir}/run_fg_control.out   2>&1
control_done=`cat ${current_logdir}/run_fg_control.log`
if [ $control_done == 'yes' ]; then
  echo "$analdate high-res control first-guess completed successfully `date`"
else
  echo "$analdate high-res control did not complete successfully, exiting `date`"
  exit 1
fi

if [ $fg_only == 'false' ]; then

# cleanup
if [ $do_cleanup == 'true' ]; then
   sh ${scriptsdir}/clean.sh > ${current_logdir}/clean.out  2>&1
fi # do_cleanup = true

if [ $save_hpss == 'true' ] && [ $days_keep > 0 ]; then 
    FHDEL=`expr $days_keep \* -24`
    DELDATE=`${incdate} $analdate $FHDEL`
    DELPATH="${datapath}/${DELDATE}/"
    hpss_done=`cat ${DELPATH}/logs/hpss.log`
    ls -l ${DELPATH}/logs/hpss.log
    if [ $hpss_done == 'yes' ]; then
        echo "clean up: deleting $DELPATH"
        rm -rf $DELPATH
    else 
        echo "did not delete ${DELPATH}, check archiving OK" 
    fi
fi

cd $homedir
if [ $save_hpss == 'true' ]; then
   if [ $machine == 'aws' ] ; then
      ipadd=`cat ${scriptsdir}/front_end_ip.txt`
      ssh -o StrictHostKeyChecking=no ${USER}@$ipadd "export machine=$machine; export scriptsdir=$scriptsdir; export datapath=${datapath}; export analdate=${analdate}; export analdate_prod=$analdate_prod; export exptname=${exptname}; cd $scriptsdir; sh ./hpss.sh >&archive_${analdate}.out&"
   else
      cat ${machine}_preamble_hpss_slurm hpss.sh > job_hpss.sh
      echo "submitting job_hpss.sh ..."
      sbatch --export=ALL job_hpss.sh
      #sbatch --export=machine=${machine},analdate=${analdate},datapath2=${datapath2},hsidir=${hsidir},MODULESHOME=${MODULESHOME} job_hpss.sh
      if [ $? -eq 0 ]; then # exit status OK 
           echo "yes" > ${current_logdir}/hpss.log  
      else 
           echo "no" > ${current_logdir}/hpss.log  
      fi
   fi
fi

fi # skip to here if fg_only = true

echo "$analdate all done `date`"
if [ $resubmit == "false" ]; then
  exit
fi

# next analdate: increment by $ANALINC
export analdate=`${incdate} $analdate $ANALINC`

echo "export analdate=${analdate}" > $startupenv
echo "export analdate_end=${analdate_end}" >> $startupenv
echo "export analdate_prod=${analdate_prod}" >> $startupenv
echo "export fg_only=false" > $datapath/fg_only.sh
echo "export cold_start=false" >> $datapath/fg_only.sh

cd $homedir

if [ $analdate -le $analdate_end ]  && [ $resubmit == 'true' ]; then
   echo "current time is $analdate"
   if [ $resubmit == "true" ]; then
      echo "resubmit script for `date`"
      echo "machine = $machine"
      if [ "$coupled"  == 'ATM_OCN_ICE' ] || [ "$coupled"  == 'ATM_OCN_ICE_WAV' ];then
         cat ${machine}_preamble_cpld_slurm config.sh > job.sh
      else
         cat ${machine}_preamble_slurm config.sh > job.sh
      fi
      sbatch --export=ALL job.sh
   fi
fi

tend=`date +%s`
dt=`expr $tend - $tstart`
echo "Entire cycle took $dt seconds"
exit 0
