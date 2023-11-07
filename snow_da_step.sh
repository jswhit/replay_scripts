#!/bin/sh 
tstart=`date +%s`
echo "entering snow da"
if [ $do_snowDA == 'true' ] && [ $fg_only == 'false' ] && [ $cold_start == 'false' ] && [ $hr == '00' ]; then # only calling land DA at 00 
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
    
      if [ ! -s settings_snowDA_${machine} ]; then
         echo "no settings_snowDA file for ${machine}, can't run snow DA..."
         exit 1
      fi
      ${scriptsdir}/land-DA_update/do_landDA.sh settings_snowDA_${machine} > ${current_logdir}/landDA.out 2>&1
      if [[ $? != 0 ]]; then
         echo "$analdate land DA failed, trying again"
         sleep 15
         ${scriptsdir}/land-DA_update/do_landDA.sh settings_snowDA_${machine} > ${current_logdir}/landDA.out 2>&1
         if [[ $? != 0 ]]; then
            echo "$analdate land DA failed, exiting"
            exit 1
         else
            echo "$analdate finished land DA after 2nd try `date`"
            echo "yes" > ${current_logdir}/landDA.log 2>&1
            rm -rf ${datapath2}/landDA/DA/hofx
            rm -rf ${datapath2}/landDA/DA/IMSproc
#         mv ${datapath2}/landDA/DA/logs/* ${current_logdir}
            rm -rf ${datapath2}/landDA/DA/jedi_incr/*
         fi
      else
         echo "$analdate finished land DA `date`"
         echo "yes" > ${current_logdir}/landDA.log 2>&1
         rm -rf ${datapath2}/landDA/DA/hofx
         rm -rf ${datapath2}/landDA/DA/IMSproc
#         mv ${datapath2}/landDA/DA/logs/* ${current_logdir}
         rm -rf ${datapath2}/landDA/DA/jedi_incr/*
      fi
   fi # land DA already done
fi # do_snowD
tend=`date +%s`
dt=`expr $tend - $tstart`
echo "gsi step took $dt seconds"
exit 0 
