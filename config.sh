echo "running on $machine using $NODES nodes"

export exptname=gfsv16_ufsreplay_test
export cores=`expr $NODES \* $corespernode`

export do_cleanup='true' # if true, create tar files, delete *mem* files.
export rungfs="run_fv3.sh"
export rungsi="run_gsi_4densvar.sh"
export cleanup_fg='true'
export replay_run_observer='true'
export cleanup_observer='true' 
export resubmit='true'
export save_hpss="true"
export do_cleanup='true'

# override values from above for debugging.
#export cleanup_observer="false"
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
 
if [ "$machine" == 'wcoss' ]; then
   export basedir=/gpfs/hps2/esrl/gefsrr/noscrub/${USER}
   export datadir=/gpfs/hps2/ptmp/${USER}
   export hsidir="/3year/NCEPDEV/GEFSRR/${USER}/${exptname}"
   export obs_datapath=${basedir}/gdas1bufr
elif [ "$machine" == 'theia' ]; then
   export basedir=/scratch3/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/scratch4/NCEPDEV/global/noscrub/dump
elif [ "$machine" == 'hera' ]; then
   export basedir=/scratch2/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/scratch1/NCEPDEV/global/glopara/dump
   source $MODULESHOME/init/sh
   module purge
   module load intel/18.0.5.274
   module load impi/2018.0.4 
   module use -a /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
   module load hdf5_parallel/1.10.6
   module load netcdf_parallel/4.7.4
   module load esmf/8.0.0_ParallelNetCDF
elif [ "$machine" == 'gaea' ]; then
   export basedir=/lustre/f1/unswept/${USER}
   export datadir=/lustre/f1/${USER}
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   #export hsidir="/3year/NCEPDEV/GEFSRR/${exptname}"
   export obs_datapath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/gdas1bufr
elif [ "$machine" == 'cori' ]; then
   export basedir=${SCRATCH}
   export datadir=$basedir
   export hsidir="fv3_reanl/${exptname}"
   export obs_datapath=${basedir}/gdas1bufr
else
   echo "machine must be 'wcoss', 'theia', 'gaea' or 'cori', got $machine"
   exit 1
fi
export datapath="${datadir}/${exptname}"
export logdir="${datadir}/logs/${exptname}"

# directory with bias correction files for GSI
# comment this out and 3DVar will be run to generate bias coeffs
export biascorrdir=/scratch2/BMC/gsienkf/whitaker/biascor
# directory with analysis netcdf files
#export replayanaldir=/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/C192ifsanal
#export analfileprefix="C192_ifsanl"
export replayanaldir=/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/gfsv16ifsanal
export analfileprefix="C192_ufsanl"
export ifsanal="false"  # true if using IFS analysis from original files, false if using pre-processed UFS or IFS analysis

# forecast resolution 
export RES=192  

export NOSAT="NO" # if yes, no radiances assimilated
export NOCONV="NO"
#  nst_gsi  - indicator to control the Tr Analysis mode: 0 = no nst info in gsi at all;
#                                                        1 = input nst info, but used for monitoring only
#                                                        2 = input nst info, and used in CRTM simulation, but no Tr analysis
#                                                        3 = input nst info, and used in CRTM simulation and Tr analysis is on
export NST_GSI=0          # No NST in GSI
#export NST_GSI=2          # passive NST
export SUITE="FV3_GFS_v16beta_no_nsst"
export LSOIL=4
#export LSOIL=9 #RUC LSM

# resolution dependent model parameters
export LONB=768  
export LATB=384  
export JCAP=382   
if [ $RES -eq 768 ]; then
   export dt_atmos=120
   export cdmbgwd_ctl="4.0,0.15,1.0,1.0"
elif [ $RES -eq 384 ]; then
   export dt_atmos=225
   export cdmbgwd="1.1,0.72,1.0,1.0"
elif [ $RES -eq 192 ]; then
   export dt_atmos=450
   export cdmbgwd="0.23,1.5,1.0,1.0"
elif [ $RES -eq 96 ]; then
   export dt_atmos=900
   export cdmbgwd="0.14,1.8,1.0,1.0"  # mountain blocking, ogwd, cgwd, cgwd src scaling
else
   echo "model time step for ensemble resolution C$RES_CTL not set"
   exit 1
fi

export LONA=$LONB
export LATA=$LATB      
export ANALINC=6
export LEVS=127
export FHMIN=3
export FHMAX=9
export FHOUT=3
export FHCYC=0
export iaufhrs="6"
export iau_delthrs="6" # iau_delthrs < 0 turns IAU off

# other model variables set in ${rungfs}
# other gsi variables set in ${rungsi}

export RUN=gdas # use gdas obs

export nitermax=1

export scriptsdir="${basedir}/scripts/${exptname}"
export homedir=$scriptsdir
export incdate="${scriptsdir}/incdate.sh"

export fv3exec='fv3-nonhydro.exe'

if [ "$machine" == 'hera' ]; then
   export fv3gfspath=/scratch1/NCEPDEV/global/glopara
   export FIXFV3=${fv3gfspath}/fix_nco_gfsv16/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix_nco_gfsv16/fix_am
   export gsipath=/scratch1/NCEPDEV/global/glopara/git/global-workflow/gfsv16b/sorc/gsi.fd
   export fixgsi=${gsipath}/fix
   export fixcrtm=/scratch2/NCEPDEV/nwprod/NCEPLIBS/fix/crtm_v2.3.0
   export execdir=${scriptsdir}/exec_${machine}
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
elif [ "$machine" == 'gaea' ]; then
# warning - these paths need to be updated on gaea
   export fv3gfspath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/fv3gfs/global_shared.v15.0.0
## export fv3gfspath=${basedir}/fv3gfs/global_shared.v15.0.0
   export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export gsipath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/ProdGSI
## export gsipath=${basedir}/ProdGSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=${fixgsi}/crtm_v2.2.3
   export execdir=${scriptsdir}/exec_${machine}
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
else
   echo "${machine} unsupported machine"
   exit 1
fi

export ANAVINFO=${fixgsi}/global_anavinfo.l${LEVS}.txt
export HYBENSINFO=${fixgsi}/global_hybens_info.l${LEVS}.txt
export CONVINFO=$fixgsi/global_convinfo.txt
export OZINFO=$fixgsi/global_ozinfo.txt
export SATINFO=$fixgsi/global_satinfo.txt

# parameters for GSI
export aircraft_bc=.true.
export use_prepb_satwnd=.false.

cd $scriptsdir
echo "run main driver script"
csh main.csh
