#!/bin/sh 
HH=`expr $analdate | cut -c9-10`
if [ $HH == '00' ];then
tstart=`date +%s`
# run gsi observer
if [ $fg_only == 'false' ] && [ $cold_start == 'false' ] && [ $replay_run_observer == "true" ]; then
   # check to see if observer already ran successfully
   if [ -f ${current_logdir}/run_gsi_observer.log ];then
      hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
   else
      hybrid_done='no'
   fi
   if [ $hybrid_done != 'yes' ]; then
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
tend=`date +%s`
dt=`expr $tend - $tstart`
echo "gsi step took $dt seconds"
fi
exit 0
