# main driver script
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

env
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

if [ $fg_only == 'false' ]; then
    if [ $replay_run_observer == "true" ]; then
       export charnanal='control'
       export charnanal2='control'
       export lobsdiag_forenkf='.false.'
       export skipcat="false"
       echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
       if [ -z $biascorrdir ]; then # 3DVar to cycle bias correction files
          sh ${scriptsdir}/run_3dvaranal.sh > ${current_logdir}/run_gsi_observer.out  2>&1
       else
          sh ${scriptsdir}/run_gsiobserver.sh > ${current_logdir}/run_gsi_observer.out   2>&1
       fi
       # once observer has completed, check log files.
       hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
       if [ $hybrid_done == 'yes' ]; then
         echo "$analdate gsi observer completed successfully `date`"
       else
         echo "$analdate gsi observer did not complete successfully, exiting `date`"
         exit 1
       fi
    fi
fi
 
if [ $do_snowDA == 'true' ]; then
 if [ $hr == '00' ]; then # only calling land DA at 00 

    # check if land DA has already been done.
    lndp_done=`cat ${current_logdir}/landDA.log`
    if [ $lndp_done == 'yes' ]; then
      echo "$analdate  land DA already done this time step, skipping.  `date`"
    else

     echo "$analdate calling land DA `date`"
     charnanal='control'
     export RSTRDIR=${datapath2}/${charnanal}/INPUT/
     # stage restarts
     export ym3=`echo $analdatem3 | cut -c1-4`
     export mm3=`echo $analdatem3 | cut -c5-6`
     export dm3=`echo $analdatem3 | cut -c7-8`
     export hm3=`echo $analdatem3 | cut -c9-10`
     n=1 
     while [ $n -le 6 ]; do
        ln -fs ${RSTRDIR}/sfc_data.tile${n}.nc  ${RSTRDIR}/${ym3}${mm3}${dm3}.${hm3}0000.sfc_data.tile${n}.nc
      n=$((n+1))
     done

     ${scriptsdir}/land-DA_update/do_landDA.sh settings_snowDA > ${current_logdir}/landDA.out 2>&1
     if [[ $? != 0 ]]; then
        echo "$analdate land DA failed, exiting"
        exit 1
     else
        echo "$analdate finished land DA `date`"
        echo "yes" > ${current_logdir}/landDA.log 2>&1
     fi
   fi # land DA already done
 fi # 00
fi # do_snowDA

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

fi # skip to here if fg_only = true

echo "$analdate all done `date`"
if [ $resubmit == "false" ]; then
  exit
endif

# next analdate: increment by $ANALINC
export analdate=`${incdate} $analdate $ANALINC`

echo "export analdate=${analdate}" > $startupenv
echo "export analdate_end=${analdate_end}" >> $startupenv
echo "export fg_only=false" > $datapath/fg_only.sh
echo "export cold_start=false" >> $datapath/fg_only.sh

cd $homedir

if [ $analdate -le $analdate_end ]  && [ $resubmit == 'true' ]; then
   echo "current time is $analdate"
   if [ $resubmit == "true" ]; then
      echo "resubmit script for `date`"
      echo "machine = $machine"
      if [ "$coupled"  == 'ATM_OCN_ICE' ];then
         cat ${machine}_preamble_cpld_slurm config.sh > job.sh
      else
         cat ${machine}_preamble_slurm config.sh > job.sh
      fi
      sbatch --export=ALL job.sh
   fi
fi

exit 0
