#!/bin/sh
tstart=`date +%s`
OCN_IAU=False
charnanal='control'
cd ${datapath2}/${charnanal}/INPUT
ln -sf ${FIXDIR}/MOM6_FIX/${ORES3}/ocean_hgrid.nc .
if [ $NGGODAS == "true" ]; then
   OCN_IAU=True
   sh ${scriptsdir}/calc_ocean_increment_nggodas.sh 
   if [ $? -ne 0 ]; then
      echo "calc_ocean_increment failed..."
      exit 1
   else
      echo "done calculating ocean increment... `date`"
   fi
else
   # only do IAU on ocean for the 12z cycle for ORAS5
   if [ $ANALHR -eq 12 ]; then
      OCN_IAU=True
      if [ "$machine" == 'aws' ];then
         YYYY=`echo $analdate | cut -c 1-4`
         MM=`echo $analdate | cut -c 5-6`
         DD=`echo $analdate | cut -c 7-8`
         analdatem1d=`$incdate $analdate -24`
         YYYYm1d=`echo $analdatem1d | cut -c 1-4`
         MMm1d=`echo $analdatem1d | cut -c 5-6`
         DDm1d=`echo $analdatem1d | cut -c 7-8`
         if [[ ! -f ${ocnanaldir}/ORAS5.${OCNRES}_${YYYY}${MM}${DD}.ic.nc ]]; then
            aws s3 cp s3://noaa-bmc-none-ca-ufs-rnr/replay/inputs/oras5_ics/${OCNRES}/${YYYY}/${MM}/ORAS5.${OCNRES}_${YYYY}${MM}${DD}.ic.nc ${ocnanaldir} 
         fi
  # remove yesterday's ORAS5 file
         rm ${ocnanaldir}/ORAS5.${OCNRES}_${YYYYm1d}${MMm1d}${DDm1d}.ic.nc
      fi
      if [ $machine == 'hera' ];then
         #ln -sf ${ocnanaldir}/${yeara}${mona}${daya}/ORAS5.${OCNRES}.ic.nc ${ocnanaldir}/ORAS5.${OCNRES}_${yeara}${mona}${daya}.ic.nc
         ln -sf ${ocnanaldir}/${yeara}${mona}${daya}/ORAS5.${OCNRES}.ic.nc ${ocnanaldir}/ORAS5.mx025_${yeara}${mona}${daya}.ic.nc
      fi
      export "PGM=${execdir}/calc_ocean_increments_from_ORAS5 $analdate $datapath2 $ocnanaldir ${iau_forcing_factor_ocn}"
      nprocs=1 mpitaskspernode=1 ${scriptsdir}/runmpi 
      if [ $? -ne 0 ]; then
         echo "calc_ocean_increment failed..."
         exit 1
      else
         echo "done calculating ocean increment... `date`"
      fi
   fi
fi
tend=`date +%s`
dt=`expr $tend - $tstart`
echo "ocn_inc step took $dt seconds"
exit 0
