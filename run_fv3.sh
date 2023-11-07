#!/bin/sh 
# model was compiled with these 
echo "starting at `date`"
source $MODULESHOME/init/sh
#skip_global_cycle=YES
if [ "$cold_start" == "true" ]; then
   skip_global_cycle=YES
   FHROT=0
else
   FHROT=3
fi

export WGRIB=`which wgrib`

export VERBOSE=${VERBOSE:-"NO"}
export quilting=${quilting:-'.true.'}
if [ "$VERBOSE" == "YES" ]; then
 set -x
fi

ulimit -s unlimited
export OMP_STACKSIZE=2048M

niter=${niter:-1}
export ISEED_SPPT=$((analdate*1000 + nmem*10 + 0 + niter))
export ISEED_SKEB=$((analdate*1000 + nmem*10 + 1 + niter))
export ISEED_SHUM=$((analdate*1000 + nmem*10 + 2 + niter))
#export ISEED_CA=$((analdate*1000 + nmem*10 + 3 + niter))
export ISEED_CA=$((analdate+nmem))
export ISEED_OCNSPPT=$((analdate*1000 + nmem*10 + 4 + niter))
export ISEED_EPBL=$((analdate*1000 + nmem*10 + 5 + niter))
export npx=`expr $RES + 1`
export LEVP=`expr $LEVS \+ 1`
# yr,mon,day,hr at middle of assim window (analysis time)
export yeara=`echo $analdate |cut -c 1-4`
export mona=`echo $analdate |cut -c 5-6`
export daya=`echo $analdate |cut -c 7-8`
export houra=`echo $analdate |cut -c 9-10`
echo "analdatem1 $analdatem1"
export yearprev=`echo $analdatem1 |cut -c 1-4`
export monprev=`echo $analdatem1 |cut -c 5-6`
export dayprev=`echo $analdatem1 |cut -c 7-8`
export hourprev=`echo $analdatem1 |cut -c 9-10`
if [ ! -z $longfcst ]; then
   export skip_calc_increment=1
   export skip_global_cycle=1
   export cold_start="false"
   export dont_copy_restart=1
   export iau_delthrs=-1
   # start date for forecast (previous analysis time)
   export year=`echo $analdatem1 |cut -c 1-4`
   export mon=`echo $analdatem1 |cut -c 5-6`
   export day=`echo $analdatem1 |cut -c 7-8`
   export hour=`echo $analdatem1 |cut -c 9-10`
   # current date in restart (beginning of analysis window)
   export year_start=`echo $analdatem3 |cut -c 1-4`
   export mon_start=`echo $analdatem3 |cut -c 5-6`
   export day_start=`echo $analdatem3 |cut -c 7-8`
   export hour_start=`echo $analdatem3 |cut -c 9-10`
   # end time of analysis window (time for next restart)
   export yrnext=`echo $analdatep1m3 |cut -c 1-4`
   export monnext=`echo $analdatep1m3 |cut -c 5-6`
   export daynext=`echo $analdatep1m3 |cut -c 7-8`
   export hrnext=`echo $analdatep1m3 |cut -c 9-10`
elif [ "${iau_delthrs}" != "-1" ]  && [ "${cold_start}" == "false" ]; then
   # start date for forecast (previous analysis time)
   export year=`echo $analdatem1 |cut -c 1-4`
   export mon=`echo $analdatem1 |cut -c 5-6`
   export day=`echo $analdatem1 |cut -c 7-8`
   export hour=`echo $analdatem1 |cut -c 9-10`
   # current date in restart (beginning of analysis window)
   export year_start=`echo $analdatem3 |cut -c 1-4`
   export mon_start=`echo $analdatem3 |cut -c 5-6`
   export day_start=`echo $analdatem3 |cut -c 7-8`
   export hour_start=`echo $analdatem3 |cut -c 9-10`
   # end time of analysis window (time for next restart)
   export yrnext=`echo $analdatep1m3 |cut -c 1-4`
   export monnext=`echo $analdatep1m3 |cut -c 5-6`
   export daynext=`echo $analdatep1m3 |cut -c 7-8`
   export hrnext=`echo $analdatep1m3 |cut -c 9-10`
else
   # if no IAU, start date is middle of window
   export year=`echo $analdate |cut -c 1-4`
   export mon=`echo $analdate |cut -c 5-6`
   export day=`echo $analdate |cut -c 7-8`
   export hour=`echo $analdate |cut -c 9-10`
   # date in restart file is same as start date (not continuing a forecast)
   export year_start=`echo $analdate |cut -c 1-4`
   export mon_start=`echo $analdate |cut -c 5-6`
   export day_start=`echo $analdate |cut -c 7-8`
   export hour_start=`echo $analdate |cut -c 9-10`
   # time for restart file
   if [ "${iau_delthrs}" != "-1" ] ; then
      # beginning of next analysis window
      export yrnext=`echo $analdatep1m3 |cut -c 1-4`
      export monnext=`echo $analdatep1m3 |cut -c 5-6`
      export daynext=`echo $analdatep1m3 |cut -c 7-8`
      export hrnext=`echo $analdatep1m3 |cut -c 9-10`
   else
      # end of next analysis window
      export yrnext=`echo $analdatep1 |cut -c 1-4`
      export monnext=`echo $analdatep1 |cut -c 5-6`
      export daynext=`echo $analdatep1 |cut -c 7-8`
      export hrnext=`echo $analdatep1 |cut -c 9-10`
   fi
fi
# end time of analysis window (time for next restart)
export yrendnext=`echo $analdatep1p3 |cut -c 1-4`
export monendnext=`echo $analdatep1p3 |cut -c 5-6`
export dayendnext=`echo $analdatep1p3 |cut -c 7-8`
export hrendnext=`echo $analdatep1p3 |cut -c 9-10`

# halve time step if niter>1 and niter==nitermax
if [[ $niter -gt 1 ]] && [[ $niter -eq $nitermax ]]; then
    dt_atmos=`python -c "print(${dt_atmos}/2)"`
    echo "dt_atmos changed to $dt_atmos..."
fi

# copy data, diag and field tables.
cd ${datapath2}/${charnanal}
if [ $? -ne 0 ]; then
  echo "cd to ${datapath2}/${charnanal} failed, stopping..."
  exit 1
fi
find -type l -delete
/bin/rm -f dyn* phy* *nemsio* PET* history/* 
export DIAG_TABLE=${DIAG_TABLE:-$scriptsdir/diag_table}
/bin/cp -f $DIAG_TABLE diag_table
/bin/cp -f $scriptsdir/nems.configure .

# insert correct starting time and output interval in diag_table template.
sed -i -e "s/YYYY MM DD HH/${year} ${mon} ${day} ${hour}/g" diag_table
sed -i -e "s/FHOUT/${FHOUT}/g" diag_table
/bin/cp -f $scriptsdir/field_table_${SUITE} field_table
/bin/cp -f $scriptsdir/data_table data_table
ln -sf ${scriptsdir}/fd_nems.yaml .

/bin/rm -rf RESTART
mkdir -p RESTART
mkdir -p history
mkdir -p INPUT

# make symlinks for fixed files and initial conditions.
cd INPUT
find -type l -delete
if [ "$cold_start" == "true" ]; then
   for file in ../*nc; do
       file2=`basename $file`
       ln -fs $file $file2
   done
fi

# Grid and orography data
n=1
if [[ $RES -eq 96 ]]; then
   fv3_input_data=FV3_input_data
else
   fv3_input_data=FV3_input_data${RES}
fi
while [ $n -le 6 ]; do
 ln -fs $FIXDIR/${fv3_input_data}/INPUT/C${RES}_grid.tile${n}.nc    C${RES}_grid.tile${n}.nc
 ln -fs $FIXDIR/FV3_fix_tiled/C${RES}/oro_C${RES}.${OCNRES}.tile${n}.nc oro_data.tile${n}.nc
 ln -fs $FIXDIR/${fv3_input_data}/INPUT_L127/oro_data_ls.tile${n}.nc oro_data_ls.tile${n}.nc
 ln -fs $FIXDIR/${fv3_input_data}/INPUT_L127/oro_data_ss.tile${n}.nc oro_data_ss.tile${n}.nc
 n=$((n+1))
done
ln -fs $FIXDIR/${fv3_input_data}/INPUT/grid_spec.nc  C${RES}_mosaic.nc
ln -fs $FIXDIR/CPL_FIX/aC${RES}o${ORES3}/grid_spec.nc  grid_spec.nc
ln -fs $FIXDIR/MOM6_FIX/${ORES3}/ocean_mosaic.nc ocean_mosaic.nc
# symlinks one level up from INPUT
cd ..
ln -fs $FIXDIR/FV3_fix/fix_co2_proj/* .
#ln -fs $FIXDIR/FV3_fix/*grb .
ln -fs $FIXDIR/FV3_fix/*txt .
ln -fs $FIXDIR/FV3_fix/*f77 .
ln -fs $FIXDIR/FV3_fix/*dat .
ln -fs $FIXDIR/FV3_input_data_RRTMGP/* .
ln -fs $FIXDIR/FV3_input_data_gsd/CCN_ACTIVATE.BIN CCN_ACTIVATE.BIN 
ln -fs $FIXDIR/FV3_input_data_gsd/freezeH2O.dat freezeH2O.dat   
ln -fs $FIXDIR/FV3_input_data_gsd/qr_acr_qg.dat qr_acr_qg.dat
ln -fs $FIXDIR/FV3_input_data_gsd/qr_acr_qs.dat qr_acr_qs.dat 
ln -fs $FIXDIR/FV3_input_data/ugwp_C384_tau.nc ugwp_limb_tau.nc
# for ugwpv1 and MERRA aerosol climo (IAER=1011)
for n in 01 02 03 04 05 06 07 08 09 10 11 12; do
  ln -fs $FIXDIR/FV3_input_data_INCCN_aeroclim/MERRA2/merra2.aerclim.2003-2014.m${n}.nc aeroclim.m${n}.nc
done
ln -fs  $FIXDIR/FV3_input_data_INCCN_aeroclim/aer_data/LUTS/optics_BC.v1_3.dat  optics_BC.dat
ln -fs  $FIXDIR/FV3_input_data_INCCN_aeroclim/aer_data/LUTS/optics_OC.v1_3.dat  optics_OC.dat
ln -fs  $FIXDIR/FV3_input_data_INCCN_aeroclim/aer_data/LUTS/optics_DU.v15_3.dat optics_DU.dat
ln -fs  $FIXDIR/FV3_input_data_INCCN_aeroclim/aer_data/LUTS/optics_SS.v3_3.dat  optics_SS.dat
ln -fs  $FIXDIR/FV3_input_data_INCCN_aeroclim/aer_data/LUTS/optics_SU.v1_3.dat  optics_SU.dat

# create netcdf increment files.
if [ "$cold_start" == "false" ] && [ -z $skip_calc_increment ]; then
   cd INPUT

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
  taper_pbl=.false.
  ak_bot=10000.,
  ak_top=5000.,
  bk_bot=1.0,
  bk_top=0.95
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
      echo "create ${increment_file}"
      /bin/rm -f ${increment_file}
      # last two args:  no_mpinc no_delzinc
      if [ $RES_INC -lt $RES ]; then
         export analfile="${replayanaldir_lores}/${analfileprefix_lores}_${analdate_tmp}.nc"
         echo "create ${increment_file} from ${fgfile} and ${analfile}"
         export "PGM=${execdir}/calc_increment_ncio.x "${fgfile}.chgres" ${analfile} ${increment_file}"
      else
         export analfile="${replayanaldir}/${analfileprefix}_${analdate_tmp}.nc"
         echo "create ${increment_file} from ${fgfile} and ${analfile}"
         export "PGM=${execdir}/calc_increment_ncio.x ${fgfile} ${analfile} ${increment_file}"
      fi
      nprocs=1 mpitaskspernode=1 ${scriptsdir}/runmpi
      if [ $? -ne 0 -o ! -s ${increment_file} ]; then
         echo "problem creating ${increment_file}, stopping .."
         exit 1
      fi
      export OMP_NUM_THREADS=$threads_save
   done # do next forecast
   cd ..
fi

# setup model namelist
if [ "$cold_start" == "true" ]; then
   # cold start from chgres'd GFS analyes
   stochini=F
   reslatlondynamics=""
   readincrement=F
   FHCYC=0
   iaudelthrs=-1
   #iau_inc_files="fv3_increment.nc"
   iau_inc_files=""
else
   # warm start from restart file with lat/lon increments ingested by the model
   if [ -s INPUT/atm_stoch.res.nc ]; then
     echo "stoch restart available, setting stochini=T"
     stochini=T # restart random patterns from existing file
   else
     echo "stoch restarts not available, setting stochini=F"
     stochini=F
   fi
   iaudelthrs=${iau_delthrs}
   FHCYC=${FHCYC}
   if [ "${iau_delthrs}" != "-1" ]; then
      if [ "$iaufhrs" == "3,4,5,6,7,8,9" ]; then
         iau_inc_files="'fv3_increment3.nc','fv3_increment4.nc','fv3_increment5.nc','fv3_increment6.nc','fv3_increment7.nc','fv3_increment8.nc','fv3_increment9.nc'"
      elif [ "$iaufhrs" == "3,6,9" ]; then
         iau_inc_files="'fv3_increment3.nc','fv3_increment6.nc','fv3_increment9.nc'"
      elif [ "$iaufhrs" == "6" ]; then
         iau_inc_files="'fv3_increment6.nc'"
      else
         echo "illegal value for iaufhrs"
         exit 1
      fi
      reslatlondynamics=""
      readincrement=F
   else
      reslatlondynamics="fv3_increment6.nc"
      readincrement=T
      iau_inc_files=""
   fi
fi

snoid='SNOD'

# Turn off snow analysis if it has already been used.
# (snow analysis only available once per day at 18z)
fntsfa=${obs_datapath}/gdas.${yeara}${mona}${daya}/${houra}/gdas.t${houra}z.rtgssthr.grb
fnacna=${obs_datapath}/gdas.${yeara}${mona}${daya}/${houra}/gdas.t${houra}z.seaice.5min.grb
fnsnoa=${obs_datapath}/gdas.${yeara}${mona}${daya}/${houra}/gdas.t${houra}z.snogrb_t1534.3072.1536
fnsnog=${obs_datapath}/gdas.${yearprev}${monprev}${dayprev}/${hourprev}/gdas.t${hourprev}z.snogrb_t1534.3072.1536
echo "running $WGRIB ${fnsnoa} to see if there are any $snoid messages"
$WGRIB ${fnsnoa}
#nrecs_snow=`$WGRIB ${fnsnoa} | grep -i $snoid | wc -l`
nrecs_snow=0
if [ $nrecs_snow -eq 0 ]; then
   # no snow depth in file, use model
   fnsnoa='' # no input file
   export FSNOL=99999 # use model value
   echo "no snow depth in snow analysis file, use model"
else
   # snow depth in file, but is it current?
   if [ `$WGRIB -4yr ${fnsnoa} 2>/dev/null|grep -i $snoid |\
         awk -F: '{print $3}'|awk -F= '{print $2}'` -le \
        `$WGRIB -4yr ${fnsnog} 2>/dev/null |grep -i $snoid  |\
               awk -F: '{print $3}'|awk -F= '{print $2}'` ] ; then
      echo "no snow analysis, use model"
      fnsnoa='' # no input file
      export FSNOL=99999 # use model value
   else
      echo "current snow analysis found in snow analysis file, replace model"
      #export FSNOL=-2 # use analysis value
      export FSNOL=99999 # for NOAH-MP
   fi
fi

FHRESTART=${FHRESTART:-"${RESTART_FREQ} -1"}
OUTPUTFH=${OUTPUTFH:-"${FHOUT} -1"}
if [ ! -z $longfcst ]; then
   FHMAX_FCST=$FHMAX
   FHRESTART=0
elif [ "${iau_delthrs}" != "-1" ]; then
   if [ "${cold_start}" == "true" ]; then
      FHMAX_FCST=$FHMAX
   else
      FHMAX_FCST=`expr $FHMAX + $ANALINC`
   fi
else
   FHMAX_FCST=$FHMAX
fi
sed -i -e "s/RESTART_FREQ/${RESTART_FREQ}/g" nems.configure

if [ -z $skip_global_cycle ]; then
   # run global_cycle to update surface in restart file.
   export BASE_GSM=${fv3gfspath}
   # global_cycle chokes for 3,9,15,18 UTC hours in CDATE
   #export CDATE="${year_start}${mon_start}${day_start}${hour_start}"
   export CDATE=${analdate}
   export CYCLEXEC=${execdir}/global_cycle
   export CYCLESH=${scriptsdir}/global_cycle.sh
   export COMIN=${PWD}/INPUT
   export COMOUT=$COMIN
   # thse should agree with names in input.nml
   export FNGLAC="${FIXGLOBAL}/global_glacier.2x2.grb"
   export FNMXIC="${FIXGLOBAL}/global_maxice.2x2.grb"
   export FNTSFC="${FIXGLOBAL}/RTGSST.1982.2012.monthly.clim.grb"
   export FNSNOC="${FIXGLOBAL}/global_snoclim.1.875.grb"
   export FNZORC="igbp"
   export FNALBC="${FIXTILED}/C${RES}.snowfree_albedo.tileX.nc"
   export FNALBC2="${FIXTILED}/C${RES}.facsf.tileX.nc"
   export FNAISC="${FIXGLOBAL}/CFSR.SEAICE.1982.2012.monthly.clim.grb"
   export FNVEGC="${FIXTILED}/C${RES}.vegetation_greenness.tileX.nc"
   export FNVETC="${FIXTILED}/C${RES}.vegetation_type.tileX.nc"
   export FNSOTC="${FIXTILED}/C${RES}.soil_type.tileX.nc"
   export FNSMCC="${FIXGLOBAL}/global_soilmgldas.statsgo.t766.1536.768.grb"
   export FNMSKH="${FIXGLOBAL}/global_slmask.t1534.3072.1536.grb"
   export FNTG3C="${FIXGLOBAL}/global_tg3clim.2.6x1.5.grb"
   export FNVMNC="${FIXTILED}/C${RES}.vegetation_greenness.tileX.nc"
   export FNVMXC="${FIXTILED}/C${RES}.vegetation_greenness.tileX.nc"
   export FNSLPC="${FIXTILED}/C${RES}.slope_type.tileX.nc"
   export FNABSC="${FIXTILED}/C${RES}.maximum_snow_albedo.tileX.nc"
   export FNTSFA="${fntsfa}"
   export FNSNOA="${fnsnoa}"
   export FNACNA="${fnacna}"
   export CASE="C${RES}"
   export PGM="${execdir}/global_cycle"
   if [ $NST_GSI -gt 0 ]; then
       export GSI_FILE=${datapath2}/${PREINP}dtfanl.nc
   fi
   sh ${scriptsdir}/global_cycle_driver.sh
   n=1
   while [ $n -le 6 ]; do
     ls -l ${COMOUT}/sfcanl_data.tile${n}.nc
     ls -l ${COMOUT}/sfc_data.tile${n}.nc
     if [ -s ${COMOUT}/sfcanl_data.tile${n}.nc ]; then
         /bin/mv -f ${COMOUT}/sfcanl_data.tile${n}.nc ${COMOUT}/sfc_data.tile${n}.nc
     else
         echo "global_cycle failed, exiting .."
         exit 1
     fi
     ls -l ${COMOUT}/sfc_data.tile${n}.nc
     n=$((n+1))
   done
   /bin/rm -rf rundir*
fi

# NSST Options
# nstf_name contains the NSST related parameters
# nstf_name(1) : NST_MODEL (NSST Model) : 0 = OFF, 1 = ON but uncoupled, 2 = ON and coupled
# nstf_name(2) : NST_SPINUP : 0 = OFF, 1 = ON,
# nstf_name(3) : NST_RESV (Reserved, NSST Analysis) : 0 = OFF, 1 = ON
# nstf_name(4) : ZSEA1 (in mm) : 0
# nstf_name(5) : ZSEA2 (in mm) : 0
# nst_anl      : .true. or .false., NSST analysis over lake
NST_MODEL=${NST_MODEL:-0}
NST_SPINUP=${NST_SPINUP:-0}
NST_RESV=${NST_RESV-0}
ZSEA1=${ZSEA1:-0}
ZSEA2=${ZSEA2:-0}
nstf_name=${nstf_name:-"$NST_MODEL,$NST_SPINUP,$NST_RESV,$ZSEA1,$ZSEA2"}
nst_anl=${nst_anl:-".true."}
if [ $NST_GSI -gt 0 ] && [ $FHCYC -gt 0]; then
   fntsfa='        ' # no input file, use GSI foundation temp
   #fnsnoa='        '
   fnacna='        '
fi

WRITE_DOPOST=${WRITE_DOPOST:-".false."}
if [ $WRITE_DOPOST == ".true." ]; then
   /bin/cp -f ${scriptsdir}/postxconfig* .
   /bin/cp -f ${scriptsdir}/params_grib2_tbl_new .
   /bin/cp -f ${scriptsdir}/post_tag_gfs${LEVP} itag
fi
ls -l 

cat > model_configure <<EOF
print_esmf:              .true.
total_member:            1
PE_MEMBER01:             ${nprocs}
start_year:              ${year}
start_month:             ${mon}
start_day:               ${day}
start_hour:              ${hour}
start_minute:            0
start_second:            0
nhours_fcst:             ${FHMAX_FCST}
fhrot:                   ${FHROT}
RUN_CONTINUE:            F
ENS_SPS:                 F
dt_atmos:                ${dt_atmos} 
output_1st_tstep_rst:    .false.
output_history:          ${OUTPUT_HISTORY:-".true."}
write_dopost:            ${WRITE_DOPOST:-".false."}
calendar:                'julian'
cpl:                     F
memuse_verbose:          F
atmos_nthreads:          ${OMP_NUM_THREADS}
use_hyper_thread:        F
ncores_per_node:         ${corespernode}
restart_interval:        ${FHRESTART}
output_fh:               ${OUTPUTFH}
quilting:                ${quilting}
write_groups:            ${write_groups}
write_tasks_per_group:   ${write_tasks}
num_files:               2
filename_base:           'dyn' 'phy'
output_grid:             'gaussian_grid'
output_file:             'netcdf_parallel' 'netcdf'
nbits:                   14
ideflate:                1
ichunk2d:                ${LONB}
jchunk2d:                ${LATB}
ichunk3d:                0
jchunk3d:                0
kchunk3d:                0
write_nsflip:            .true.
iau_offset:              ${iaudelthrs}
imo:                     ${LONB}
jmo:                     ${LATB}
EOF
cat model_configure

# copy template namelist file, replace variables.
if [ "$cold_start" == "true" ]; then
  warm_start=F
  externalic=T
  na_init=1
  mountain=F
  make_nh=T
else
  warm_start=T
  externalic=F
  na_init=0
  mountain=T
  make_nh=F
fi
/bin/cp -f ${scriptsdir}/${SUITE}.nml input.nml
#sed -i -e "s/SUITE/${SUITE}/g" input.nml
sed -i -e "s/LAYOUT/${layout}/g" input.nml
sed -i -e "s/NPX/${npx}/g" input.nml
sed -i -e "s/NPY/${npx}/g" input.nml
sed -i -e "s/LEVP/${LEVP}/g" input.nml
sed -i -e "s/LEVS/${LEVS}/g" input.nml
sed -i -e "s/IAU_DELTHRS/${iaudelthrs}/g" input.nml
sed -i -e "s/IAU_INC_FILES/${iau_inc_files}/g" input.nml
sed -i -e "s/WARM_START/${warm_start}/g" input.nml
sed -i -e "s/CDMBGWD/${cdmbgwd}/g" input.nml
sed -i -e "s/EXTERNAL_IC/${externalic}/g" input.nml
sed -i -e "s/NA_INIT/${na_init}/g" input.nml
sed -i -e "s/MOUNTAIN/${mountain}/g" input.nml
sed -i -e "s/MAKE_NH/${make_nh}/g" input.nml
sed -i -e "s/FRAC_GRID/${FRAC_GRID}/g" input.nml
sed -i -e "s/ISEED_CA/${ISEED_CA}/g" input.nml
# gcycle related params
sed -i -e "s/FHCYC/${FHCYC}/g" input.nml
sed -i -e "s/CRES/C${RES}/g" input.nml
sed -i -e "s/ORES/${OCNRES}/g" input.nml
sed -i -e "s!SSTFILE!${fntsfa}!g" input.nml
sed -i -e "s!FIXDIR!${FIXDIR}!g" input.nml
sed -i -e "s!ICEFILE!${fnacna}!g" input.nml
sed -i -e "s!SNOFILE!${fnsnoa}!g" input.nml
sed -i -e "s/FSNOL_PARM/${FSNOL}/g" input.nml
if [ $NSTFNAME == "2,0,0,0" ] && [ $cold_start == "true" ]; then
   NSTFNAME="2,1,0,0"
fi
sed -i -e "s/NSTFNAME/${NSTFNAME}/g" input.nml

sed -i -e "s/DO_sppt/${DO_SPPT}/g" input.nml
sed -i -e "s/PERT_MP/${PERT_MP}/g" input.nml
sed -i -e "s/PERT_CLDS/${PERT_CLDS}/g" input.nml
sed -i -e "s/DO_shum/${DO_SHUM}/g" input.nml
sed -i -e "s/DO_skeb/${DO_SKEB}/g" input.nml

sed -i -e "s/LONB/${LONB}/g" input.nml
sed -i -e "s/LATB/${LATB}/g" input.nml
sed -i -e "s/JCAP/${JCAP}/g" input.nml
sed -i -e "s/SPPT/${SPPT}/g" input.nml
sed -i -e "s/SHUM/${SHUM}/g" input.nml
sed -i -e "s/SKEB/${SKEB}/g" input.nml
sed -i -e "s/STOCHINI/${stochini}/g" input.nml
sed -i -e "s/ISEED_sppt/${ISEED_SPPT}/g" input.nml
sed -i -e "s/ISEED_shum/${ISEED_SHUM}/g" input.nml
sed -i -e "s/ISEED_skeb/${ISEED_SKEB}/g" input.nml
sed -i -e "s/ISEED_ocnsppt/${ISEED_OCNSPPT}/g" input.nml
sed -i -e "s/ISEED_epbl/${ISEED_EPBL}/g" input.nml
sed -i -e "s/OCN_sppt/${OCNSPPT}/g" input.nml
sed -i -e "s/OCNsppt_TAU/${OCNSPPT_TAU}/g" input.nml
sed -i -e "s/OCNsppt_LSCALE/${OCNSPPT_LSCALE}/g" input.nml
sed -i -e "s/EPBL/${EPBL}/g" input.nml
sed -i -e "s/epbl_TAU/${EPBL_TAU}/g" input.nml
sed -i -e "s/epbl_LSCALE/${EPBL_LSCALE}/g" input.nml

cat input.nml
ls -l INPUT

# run model
export PGM=$FCSTEXEC
echo "start running model `date`"
${scriptsdir}/runmpi
if [ $? -ne 0 ]; then
   echo "model failed..."
   exit 1
else
   echo "done running model.. `date`"
fi

# rename netcdf files (if quilting = .true.).
export DATOUT=${DATOUT:-$datapathp1}
if [ -z $longfcst ]; then
   datelabel=${analdatep1}
else
   datelabel=${analdatem1}
fi

if [ "$quilting" == ".true." ]; then
   ls -l dyn*.nc
   ls -l phy*.nc
   if [ -z $longfcst ]; then
      fh1=$FHMIN
      fh2=$FHMAX
      fo=$FHOUT
   else
      fh1=$FHMIN_LONG
      fh2=$FHMAX_LONG
      fo=$FHOUT_LONG
      /bin/mv -f dynf012.nc ${DATOUT}/sfg_${datelabel}_fhr12_${charnanal}
      /bin/mv -f phyf012.nc ${DATOUT}/bfg_${datelabel}_fhr12_${charnanal}
      ls -l
      if [ $WRITE_DOPOST == ".true." ]; then
         /bin/mv -f GFSPRS*F12 ${DATOUT}
         /bin/mv -f GFSFLX*F12 ${DATOUT}
      fi
   fi
   fh=$fh1
   while [ $fh -le $fh2 ]; do
     charfhr="fhr"`printf %02i $fh`
     charfhr2="f"`printf %03i $fh`
     if [ $fh -gt 100 ]; then
        charfhr2c="F"`printf %03i $fh`
     else
        charfhr2c="F"`printf %02i $fh`
     fi
     /bin/mv -f dyn${charfhr2}.nc ${DATOUT}/sfg_${datelabel}_${charfhr}_${charnanal}
     if [ $? -ne 0 ]; then
        echo "netcdffile missing..."
        exit 1
     fi
     /bin/mv -f phy${charfhr2}.nc ${DATOUT}/bfg_${datelabel}_${charfhr}_${charnanal}
     if [ $? -ne 0 ]; then
        echo "netcdf file missing..."
        exit 1
     fi
     if [ $WRITE_DOPOST == ".true." ]; then
        /bin/mv -f GFSPRS*${charfhr2c} ${DATOUT}
        /bin/mv -f GFSFLX*${charfhr2c} ${DATOUT}
     fi
     fh=$[$fh+$fo]
   done
fi

ls -l *nc
if [ -z $dont_copy_restart ]; then # if dont_copy_restart not set, do this
   ls -l RESTART
   # copy restart file to INPUT directory for next analysis time.
   /bin/rm -rf ${datapathp1}/${charnanal}/RESTART ${datapathp1}/${charnanal}/INPUT
   mkdir -p ${datapathp1}/${charnanal}/INPUT
   cd RESTART
   ls -l
   datestring="${yrnext}${monnext}${daynext}.${hrnext}0000."
   for file in ${datestring}*nc; do
      file2=`echo $file | cut -f3-10 -d"."`
      echo "copying $file to ${datapathp1}/${charnanal}/INPUT/$file2"
      /bin/mv -f $file ${datapathp1}/${charnanal}/INPUT/$file2
      if [ $? -ne 0 ]; then
        echo "restart file missing..."
        exit 1
      fi
      if [ $file2 == "ca_data.tile1.nc" ]; then
         touch ${datapathp1}/${charnanal}/INPUT/ca_data.nc
      fi
   done
   cd ..
   ls -l ${datapathp1}/${charnanal}/INPUT
fi

ls -l ${DATOUT}

# remove symlinks from INPUT directory
cd INPUT
find -type l -delete
cd ..
/bin/rm -rf RESTART

echo "all done at `date`"

exit 0
