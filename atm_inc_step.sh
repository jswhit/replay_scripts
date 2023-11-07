#!/bin/sh 
tstart=`date +%s`
echo "starting atm_inc"
if [ "$cold_start" == "false" ] && [ -z $skip_calc_increment ]; then
   charnanal='control'
   cd ${datapath2}/${charnanal}/INPUT
   iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
# IAU - multiple increments.
   for fh in $iaufhrs2; do
      export increment_file="fv3_increment${fh}.nc"
      fhtmp=`expr $fh \- $ANALINC`
      analdate_tmp=`$incdate $analdate $fhtmp`
      threads_save=$OMP_NUM_THREADS
      export OMP_NUM_THREADS=8
      export fgfile=${datapath2}/sfg_${analdate}_fhr0${fh}_${charnanal}
      /bin/rm -f calc_increment_ncio.nml
      ff=`python -c "print($iau_forcing_factor_atm / 100.)"`
      export DONT_USE_DPRES=1
      export DONT_USE_DELZ=1
      cat > calc_increment_ncio.nml << EOF
&setup
  no_mpinc=.true.
  no_delzinc=.false.
  forcing_factor=${ff},
  taper_strat=.true.
  taper_strat_ozone=.true.
  taper_pbl=.false.
  ak_bot=10000.,
  ak_top=5000.,
  bk_bot=1.0,
  bk_top=0.95
  ak_bot_ozone=10.
  ak_top_ozone=1.
/
EOF
      cat calc_increment_ncio.nml
# usage:
#   input files: filename_fg filename_anal (1st two command line args)
#
#   output files: filename_inc (3rd command line arg)

#   4th command line arg is logical for controlling whether microphysics
#   increment should not be computed. (no_mpinc)
#   5th command line arg is logical for controlling whether delz
#   increment should not be computed (no_delzinc)
#   6th command line arg is logical for controlling whether humidity
#   and microphysics vars should be tapered to zero in stratosphere.
#   The vertical profile of the taper is controlled by ak_top and ak_bot.
   if [ "$machine" == 'aws' ];then
      echo "create ${increment_file}"
# get era5 file from S3 bucket
     YYYY=`echo $analdate | cut -c 1-4`
     MM=`echo $analdate | cut -c 5-6`
      echo "s3://noaa-bmc-none-ca-ufs-rnr/replay/inputs/era5/C${RES}/${YYYY}/${MM}/C${RES}_era5anl_${analdate}.nc"
      if [[ ! -f ${replayanaldir}/C${RES}_era5anl_${analdate}.nc ]]; then
         aws s3 cp s3://noaa-bmc-none-ca-ufs-rnr/replay/inputs/era5/C${RES}/${YYYY}/${MM}/C${RES}_era5anl_${analdate}.nc ${replayanaldir}
      fi
      rm ${replayanaldir}/C${RES}_era5anl_${analdatem1}.nc
   fi
      /bin/rm -f ${increment_file}
      # last two args:  no_mpinc no_delzinc
      if [ $RES_INC -lt $RES ]; then
         export analfile="${replayanaldir_lores}/${analfileprefix_lores}_${analdate_tmp}.nc"
         echo "create ${increment_file} from ${fgfile} and ${analfile}"
         export "PGM=${execdir}/calc_increment_ncio.x "${fgfile}.chgres" ${analfile} ${increment_file}"
      else
         export analfile="${replayanaldir}/${analfileprefix}_${analdate_tmp}.nc"
         echo "create ${increment_file} from ${fgfile} and ${analfile}"
         export "PGM=${execdir}/calc_increment_ncio.x ${fgfile} ${analfile} ${increment_file} ${current_logdir}/calc_atm_inc.out"
      fi
      nprocs=1 mpitaskspernode=1 ${scriptsdir}/runmpi
      if [ $? -ne 0 -o ! -s ${increment_file} ]; then
         echo "problem creating ${increment_file}, stopping .."
         exit 1
      fi
      export OMP_NUM_THREADS=$threads_save
   done # do next forecast
fi
tend=`date +%s`
dt=`expr $tend - $tstart`
echo "atm_inc step took $dt seconds"
echo  "exiting"
exit 0
