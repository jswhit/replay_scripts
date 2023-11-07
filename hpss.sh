# need envars:  machine, analdate, datapath, hsidir
exitstat=0
source $MODULESHOME/init/sh
if [ $machine == "gaea" ]; then
   #module load hsi
   htar=/sw/rdtn/hpss/default/bin/htar
   hsi=/sw/rdtn/hpss/default/bin/hsi
elif [ $machine == "aws" ]; then
   module load aws-utils/latest
else
   module load hpss
   htar=`which htar`
   hsi=`which hsi`
fi
if [ $machine == "aws" ]; then
   nccompress=${HOME}/bin/nccompress
else
   nccompress=/home/Jeffrey.S.Whitaker/.local/bin/nccompress
fi

if [ $machine != "aws" ];then
   $hsi mkdir -p ${hsidir}/
fi
datapath2=${datapath}/${analdate}
YYYY=`echo $analdate | cut -c1-4`
MM=`echo $analdate | cut -c5-6`
DD=`echo $analdate | cut -c7-8`
HH=`echo $analdate | cut -c9-10`

# move increment files up 2 directories to save with diagnostics
/bin/mv -f ${datapath2}/control/INPUT/fv3_increment6.nc ${datapath2}
# move wave history files up 2 directories to save with diagnostics
if [ -f ${datapath2}/control/INPUT/mom6_increment.nc ]; then
   /bin/mv -f ${datapath2}/control/INPUT/mom6_increment.nc ${datapath2}
fi

cd ${datapath2}/control
find -type l -delete # delete symlinks

if [ $machine != "aws" ];then
   $hsi mkdir -p ${hsidir}
fi

# archive restarts only at 06Z (for 00Z 'analysis' time)
exitstat=0
if [ $HH == '06' ]; then
   cd ${datapath2}/control/INPUT
   # compress restart files.
   if [ -f $nccompress ]; then
      time $nccompress -d 1 -o -pa -m 50 *.nc
   else
      echo "nccompress not found, not compressing restarts"
   fi
   cd ${datapath}
   /bin/rm -f ${analdate}/control/INPUT/core.* ${analdate}/control/core.*
   /bin/rm -f ${analdate}/control/*.out_grd.ww3 ${analdate}/control/*.restart.ww3
   if [ $machine != "aws" ];then
      $htar -cvf ${hsidir}/${analdate}.restart.tar ${analdate}/control ${analdate}/GFSPRS.GrbF03 ${analdate}/GFSFLX.GrbF03 
      exitstat=$?
   else
      cd ${analdate}/control/
      mv restart.ww3 INPUT
      if [ $analdate -lt $analdate_prod ];then # put data in spin-up directory
         aws s3 cp --recursive INPUT s3://noaa-ufs-gefsv13replay-pds/spinup/${YYYY}/${MM}/${analdate}/ --profile noaa-bdp >&/dev/null
      else
         aws s3 cp --recursive INPUT s3://noaa-ufs-gefsv13replay-pds/${YYYY}/${MM}/${analdate}/ --profile noaa-bdp >&/dev/null
      fi
      if [ $? -ne 0 ]; then
        echo "s3 restart copy failed "$filename
        exitstat=1
      else
        echo "s3 restart copy succceeded "$filename
        #rm -rf INPUT
      fi
   fi
   if [ $exitstat -ne 0 ]; then
      echo "creating restart tar file failed"
      echo "no" > ${datapath}/${analdate}/logs/hpss.log
      exit $exitstat
   fi
else
 # just delete restarts on aws
   if [ $machine != "aws" ];then
      cd ${analdate}/control/
      if [ $HH == '00' ]; then  # save background and analysis sfc files
         mv INPUT/*sfc_data_back.tile?.nc ..
      fi
      rm -rf restart.ww3 INPUT
   fi
fi
cd $datapath
/bin/rm -f ${analdate}/control/*.out_grd.ww3 ${analdate}/control/*.restart.ww3 ${analdate}/control/*.out_pnt.ww3
/bin/mv -f ${analdate}/control control.save # move directory out of the way
/bin/rm -rf ${analdate}/GFS*06 ${analdate}/GFS*09 # remove restarts, keep fh=3 grib files
cd $datapath2
# compress history files
if [ -f $nccompress ]; then
   time $nccompress -d 1 -o -pa -m 50 ocn*nc
else
   echo "nccompress not found, not compressing history files"
fi
cd $datapath
/bin/rm -f ${analdate}/core.*
exitstat=0
if [ $machine != "aws" ];then
   htar -cvf ${hsidir}/${analdate}.history.tar ${analdate}
   exitstat=$?
else
   if [ $analdate -lt $analdate_prod ];then # put data in spin-up directory
       aws s3 cp --recursive $analdate s3://noaa-ufs-gefsv13replay-pds/spinup/${YYYY}/${MM}/${analdate}/ --profile noaa-bdp >&/dev/null
   else
       aws s3 cp --recursive $analdate s3://noaa-ufs-gefsv13replay-pds/${YYYY}/${MM}/${analdate}/ --profile noaa-bdp >&/dev/null
   fi
   if [ $? -ne 0 ]; then
      echo "s3 history copy failed "$filename
      exitstat=1
   else
      echo "s3 history copy succceeded "$filename
   fi
fi
/bin/mv -f control.save ${analdate}/control # move directory back
if [ $exitstat -ne 0 ]; then
   echo "creating history tar file failed"
   echo "no" > ${datapath}/${analdate}/logs/hpss.log
   cp -r ${datapath}/${analdate}/logs ${datapath}/log_archive/$analdate
   exit $exitstat
fi
echo "archiving was a success"
echo "yes" > ${datapath}/${analdate}/logs/hpss.log
cp -r ${datapath}/${analdate}/logs ${datapath}/log_archive/$analdate
exit 0
