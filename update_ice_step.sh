#!/bin/sh -x
tstart=`date +%s`
export charnanal='control'
if [ $update_seaice == 'true' ];then
   # update ice restart file from previous cycle
   if [ $ANALHR -eq '12' ]; then
      YYYY=`expr $analdate | cut -c1-4`
      MM=`expr $analdate | cut -c5-6`
      DD=`expr $analdate | cut -c7-8`
      pwd
      if [ -f ${datapath2}/${charnanal}/INPUT/bkg_iced.${YYYY}-${MM}-${DD}-32400.nc ];then
         echo "skipping ice update"
      else
         echo "running ice update"
         cd $scriptsdir
         ./update_ice.sh
         if [ $? -ne 0 ]; then
           echo "ice update failed"
           exit 3
         fi
         cd ${datapath2}/${charnanal}
      fi
   fi
fi
tend=`date +%s`
dt=`expr $tend - $tstart`
echo "gsi step took $dt seconds"
exit 0
