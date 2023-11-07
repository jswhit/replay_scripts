echo "running on $machine using $NODES nodes"

# forecast resolution 
# 1/4 deg
export RES=384  
export RES_INC=384
export OCNRES="mx025"
export WAVE_MESH="glo_025"
# 1-deg
#export RES=96   
#export OCNRES=mx100

#export skip_calc_increment='true'
export exptname=GEFSv13_replay_streamSTREAM
export coupled=${coupled:-'ATM_OCN_ICE'} # NO or ATM_OCN_ICE, should be set in submit_job.sh
# The SUITE selection has been moved to the bottom of this script
export cores=`expr $NODES \* $corespernode`

export do_cleanup='true' # if true, create tar files, delete *mem* files.
export rungsi="run_gsi_4densvar.sh"
export cleanup_fg='true'
export replay_run_observer='true'
export cleanup_observer='true' 
export resubmit='true'
export save_hpss='true'
export days_keep=3  # if save_hpss="true", delete local directory copy for the cycle (current_date - days_keep) 
                    # set to 0 to turn off deleting of past directories
export NGGODAS="false" # use NG-GODAS (6-h) instead of ORAS5 (24-h)

# override values from above for debugging.
#export replay_run_observer='false'
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
#export save_hpss="false"

export do_snowDA='true'
export update_seaice='true'
 
if [ "$machine" == 'hera' ]; then
   export basedir=/scratch2/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/${USER}/${exptname}"
   export obs_datapath=/scratch1/NCEPDEV/global/glopara/dump
   source $MODULESHOME/init/sh
   module purge
   module use /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
   module load miniconda3
   module load intel/2022.1.2
   module load impi/2022.1.2
   module use /scratch2/NCEPDEV/nwprod/hpc-stack/libs/hpc-stack/modulefiles/stack
   module load hpc/1.2.0
   module load hpc-intel/2022.1.2
   module load hpc-impi/2022.1.2
   module load hdf5/1.10.6
   module load netcdf/4.7.4
   module load pio/2.5.7
   module load esmf/8.3.0b09
   module load fms/2022.04
   module load cdo/1.9.5
   module load nco/4.9.1
   module load wgrib
elif [ "$machine" == 'aws' ]; then
   export AWS_DEFAULT_REGION=us-east-2
   export basedir=/lustre/${USER}
   export datadir=$basedir
   export hsidir="null"
   export obs_datapath=/lustre/${USER}/obs_dump
   if ( ! eval module help > /dev/null 2>&1 ) ; then
        export MODULEPATH=/mnt/shared/manual_modules:/apps/lmod/lmod/modulefiles/Core:/apps/modules/modulefiles/Linux:/opt/cray/modulefiles:/opt/cray/craype/default/modulefiles:/apps/modules/modulefiles:/usr/share/Modules/modulefiles:/opt/intel/impi/2019.5.281/intel64/modulefiles
        source /apps/lmod/lmod/init/sh
   fi
   module load intel/2022.1.2
   module load impi/2022.1.2
   module load hdf5/1.10.6
   module load netcdf/4.7.0
   module load netcdf-hdf5parallel/4.7.4
   module load cdo/1.9.5
   module load wgrib/1.8.1.0b
   module load aws-utils/latest
elif [ "$machine" == 'orion' ]; then
   export basedir=/work/noaa/gsienkf/${USER}
   export datadir=/work/noaa/gsienkf/${USER}
   export hsidir="/ESRL/BMC/gsienkf/2year/${USER}/${exptname}"
   export obs_datapath=/work/noaa/rstprod/dump
   source $MODULESHOME/init/sh
   export save_hpss="false"
   module purge
   module use /apps/contrib/NCEP/libs/hpc-stack/modulefiles/stack
   module load hpc/1.1.0
   module load hpc-intel/2018.4
   module unload mkl/2020.2
   module load mkl/2018.4
   module load hpc-impi/2018.4
   module load python/3.7.5
   module load hdf5/1.10.6-parallel
   module load wgrib/1.8.0b
   module load nco
   export PYTHONPATH=/home/jwhitake/.local/lib/python3.7/site-packages
elif [ "$machine" == 'gaea' ]; then
   export basedir=/lustre/f2/dev/${USER}
   export datadir=/lustre/f2/scratch/${USER}
   export hsidir="/ESRL/BMC/gsienkf/2year/${USER}/${exptname}"
   #export hsidir="/3year/NCEPDEV/GEFSRR/${exptname}"
   export obs_datapath=/lustre/f2/dev/Jeffrey.S.Whitaker/fv3_reanl/gdas1bufr
   source /lustre/f2/pdata/esrl/gsd/contrib/lua-5.1.4.9/init/init_lmod.sh
   module use /lustre/f2/pdata/ncep_shared/hpc-stack/modulefiles/stack
   #source $MODULESHOME/init/sh
   module load PrgEnv-intel/6.0.5
   module rm intel
   module rm cray-mpich
   module rm netcdf
   module load hpc/1.1.0
   module load hpc-intel/18.0.6.288
   module load hpc-cray-mpich/7.7.11
   # Needed at runtime:
   module load alps
   module load hdf5/1.10.6
   module load netcdf/4.7.4
   module load pio/2.5.2
   module load esmf/8.2.1b04
   module load fms/2021.03
   module load wgrib
   module load cdo
else
   echo "${machine} unsupported machine"
   exit 1
fi
export datapath="${datadir}/${exptname}"
export logdir="${datadir}/logs/${exptname}"

# directory with bias correction files for GSI
# comment this out and 3DVar will be run to generate bias coeffs
export biascorrdir=${basedir}/biascor

# directory with analysis netcdf files
if [ $machine == 'hera' ]; then
    export replayanaldir=/scratch2/BMC/gsienkf/Philip.Pegion/reanalysis/era5/C${RES}
    export replayanaldir_lores=/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/era5anl/C${RES_INC}
    #export ocnanaldir=/scratch2/BMC/gsienkf/Philip.Pegion/UFS-ics/ICS/${OCNRES}/
    export iceanaldir=/scratch2/BMC/gsienkf/Philip.Pegion/ice_update_basedir
    export ocnanaldir=/scratch2/BMC/gsienkf/Philip.Pegion/UFS-coupled/ICS/${OCNRES}
elif [ $machine == 'aws' ]; then
    export replayanaldir=/lustre/${USER}/era5/C${RES}
    export replayanaldir_lores=/contrib/${USER}/era5/C${RES_INC}
    export ocnanaldir=/lustre/${USER}/ORAS5/${OCNRES}
    export iceanaldir=/lustre/${USER}/ice_update_basedir
elif [ $machine == 'orion' ]; then
    export replayanaldir=/work/noaa/gsienkf/whitaker/era5/C${RES}
    export replayanaldir_lores=/work/noaa/gsienkf/whitaker/era5/C${RES_INC}
    if [ $NGGODAS == "true" ]; then
        export ocnanaldir=/work/noaa/marine/Shastri.Paturi/PSL-final/ana # NG-GODAS
    else
        export ocnanaldir=/work/noaa/gsienkf/whitaker/oras5/${OCNRES}
    fi
else
    export replayanaldir=${basedir}/era5anl/C${RES}
    export replayanaldir_lores=${basedir}/era5anl/C${RES_INC}
    export ocnanaldir=${basedir}/oras5/${OCNRES}
fi
export analfileprefix="C${RES}_era5anl"
export analfileprefix_lores="C${RES_INC}_era5anl"

export NOSAT="YES" # if yes, no radiances assimilated
export NOCONV="NO"
#  nst_gsi  - indicator to control the Tr Analysis mode: 0 = no nst info in gsi at all;
#                                                        1 = input nst info, but used for monitoring only
#                                                        2 = input nst info, and used in CRTM simulation, but no Tr analysis
#                                                        3 = input nst info, and used in CRTM simulation and Tr analysis is on
export NST_GSI=0          # No NST in GSI
#export NST_GSI=2          # passive NST
export LSOIL=4
#export LSOIL=9 #RUC LSM
export FHCYC=6
if [ $FHCYC -gt 0 ]; then
    export skip_global_cycle='YES'
fi

# resolution dependent model parameters
if [ $RES -eq 384 ];then
   export LONB=1536 
   export LATB=768  
   export JCAP=766   
fi
if [ $RES -eq 96 ];then
   export JCAP=188 
   export LONB=384   
   export LATB=192  
fi
if [ $RES_INC -eq 96 ];then
   export LONB_INC=384   
   export LATB_INC=192  
fi

if [ $RES -eq 768 ]; then
   export dt_atmos=120
   export cdmbgwd_ctl="4.0,0.15,1.0,1.0"
elif [ $RES -eq 384 ]; then
   export dt_atmos=300
   export cdmbgwd="1.1,0.72,1.0,1.0"
elif [ $RES -eq 192 ]; then
   export dt_atmos=450
   export cdmbgwd="0.23,1.5,1.0,1.0"
elif [ $RES -eq 96 ]; then
   export dt_atmos=720
   export cdmbgwd="0.14,1.8,1.0,1.0"  # mountain blocking, ogwd, cgwd, cgwd src scaling
else
   echo "model time step for ensemble resolution C$RES not set"
   exit 1
fi
if [ "$OCNRES" == 'mx100' ]; then
   export dt_ocn=3600
   export ORES3='100'
elif [ "$OCNRES" == 'mx025' ]; then
   export dt_ocn=1800
   export ORES3='025'
else
   echo "$OCNRES is not supported, plesae try mx100 or mx025"
   exit 1
fi

export LONA=$LONB
export LATA=$LATB      
export ANALINC=6
export LEVS=127
export FHMIN=0
export FHMAX=9
export FHOUT=3
export FHOUT_OCN=6
export RESTART_FREQ=6
#export FHRESTART="0 3" # default is "$RESTART_FREQ,1"
export FRAC_GRID=T
export iaufhrs="6"
export iau_delthrs="6" # iau_delthrs < 0 turns IAU off
export WRITE_DOPOST=".true."
export coldstart_ice="false"  # no ice init available

export perturbed_replay="NO"
export nmem=0
#export perturbed_replay="YES"
#export nmem=2 # perturbed member (gets added to random seeds)
if [ $perturbed_replay == "YES" ]; then
    nmemm1=$((nmem01))
    #export analfileprefix="C${RES}_era5anl_${nmemm1}"
    export iau_forcing_factor_atm=100  
    export iau_forcing_factor_ocn=100  
    # these go in  nam_stochy block of atmospheric model input.nml
    export DO_SPPT=.true.
    export PERT_MP=.true.
    export PERT_CLDS=.true.
    export SPPT=0.5
    export DO_SHUM=.true.
    export SHUM=0.005
    export DO_SKEB=.true.
    export SKEB=0.3
    export OCNSPPT=0.8
    export OCNSPPT_TAU=21600
    export OCNSPPT_LSCALE=500000
    export EPBL=0.8
    export EPBL_TAU=21600
    export EPBL_LSCALE=500000
    # tese go in MOM_input
    export DO_OCNSPPT=True
    export DO_PERT_EPBL=True
else
    export iau_forcing_factor_atm=100  
    export iau_forcing_factor_ocn=100  
    # these go in  nam_stochy block of atmospheric model input.nml
    export SKEB=0
    export DO_SKEB=.false.
    export SPPT=0
    export DO_SPPT=.false.
    export PERT_MP=.false.
    export PERT_CLDS=.false.
    export SHUM=0
    export DO_SHUM=.false.
    export OCNSPPT=0.
    export OCNSPPT_TAU=21600
    export OCNSPPT_LSCALE=500000
    export EPBL=0.
    export EPBL_TAU=21600
    export EPBL_LSCALE=500000
    # tese go in MOM_input
    export DO_OCNSPPT=False
    export DO_PERT_EPBL=False
fi

# other model variables set in ${rungfs}
# other gsi variables set in ${rungsi}

export RUN=gdas # use gdas obs

export nitermax=1

export scriptsdir="${basedir}/scripts/${exptname}"
export homedir=$scriptsdir
export incdate="${scriptsdir}/incdate.sh"

if [ "$coupled" == 'NO' ];then
   export fv3exec='fv3_atm.exe'
   export DIAG_TABLE="${scriptsdir}/diag_table"
else
   export fv3exec='ufs_coupled.exe'
   export DIAG_TABLE="${scriptsdir}/diag_table_coupled"
fi

if [ "$machine" == 'hera' ]; then
   export FIXDIR=/scratch1/NCEPDEV/nems/emc.nemspara/RT/NEMSfv3gfs/input-data-20220414
   export gsipath=/scratch2/BMC/gsienkf/Jeffrey.S.Whitaker/gsi/GSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=/scratch2/NCEPDEV/nwprod/NCEPLIBS/fix/crtm_v2.3.0
   export execdir=${scriptsdir}/exec_${machine}
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
elif [ "$machine" == 'aws' ]; then
   export FIXDIR=/lustre/${USER}/fix_files/input-data-20220414
   export gsipath=/lustre/${USER}/fix_files/
   export fixgsi=${gsipath}/fix_gsi
   export fixcrtm=/lustre/$USER/fix_files/crtm_v2.3.0
   export execdir=${scriptsdir}/exec_${machine}
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi

   #source /apps/oneapi/setvars.sh
   export IPATH_NO_BACKTRACE=1

   export I_MPI_ROOT=/apps/oneapi/mpi/2021.3.0
   export I_MPI_TMI_PROVIDER=psm
   export I_MPI_HYDRA_BRANCH_COUNT=128
   export I_MPI_HYDRA_PMI_CONNECT=alltoall
   export I_MPI_PIN_RESPECT_CPUSET=off
   export I_MPI_PMI_LIBRARY=/apps/slurm/default/lib/libpmi2.so
   export IPATH_NO_BACKTRACE=1
   export intel_root=/apps/oneapi/compiler/2021.3.0
   export LD_LIBRARY_PATH=$I_MPI_ROOT/lib:$I_MPI_ROOT/lib/release:$I_MPI_ROOT/libfabric/lib:$MKL_ROOT/lib/intel64:$intel_root/linux/lib:$intel_root:linux/lib/x64:$intel_root/linux/lib/emu:$intel_root/linux/lib/oclfpga/host/linux64/lib:$intel_root/linux/lib/oclfpga/linux64/lib:$intel_root/linux/compiler/lib/intel64_lin:$LD_LIBRARY_PATH




elif [ "$machine" == 'orion' ]; then
   export FIXDIR=/work/noaa/nems/emc.nemspara/RT/NEMSfv3gfs/input-data-20220414
   export fv3gfspath=/work/noaa/global/glopara
   export gsipath=/work/noaa/gsienkf/Jeffrey.S.Whitaker/GSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=$fv3gfspath/crtm/crtm_v2.3.0
   export execdir=${scriptsdir}/exec_${machine}
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
elif [ "$machine" == 'gaea' ]; then
   # copied from /scratch2/NCEPDEV/climate/role.ufscpara/Prototype7.0/global-workflow/fix on 8/31/2021
   #export FIXDIR=/lustre/f2/dev/Jeffrey.S.Whitaker/p8fix
   export FIXDIR=/lustre/f2/pdata/ncep_shared/emc.nemspara/RT/NEMSfv3gfs/input-data-20220414
   export gsipath=/lustre/f2/dev/Jeffrey.S.Whitaker/GSI-github-emc
   export fixgsi=${gsipath}/fix
   export fixcrtm=/lustre/f2/pdata/ncep_shared/NCEPLIBS/lib/crtm/v2.3.0/fix
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
export aircraft_bc=.false.
export use_prepb_satwnd=.false.
export imp_physics=11 # used by GSI, not model
if [ $LEVS -eq 64 ]; then
  export nsig_ext=12
  export gpstop=50
  export GRIDOPTS="nlayers(63)=3,nlayers(64)=6,"
elif [ $LEVS -eq 127 ]; then
  export nsig_ext=56
  export gpstop=55
  export GRIDOPTS="nlayers(63)=1,nlayers(64)=1,"
else
  echo "LEVS must be 64 or 127"
  exit 1
fi
export NSTFNAME="2,0,0,0"

# new namelist settings for coupled/not-coupled
export running_wave="NO"
if [ "$coupled" == 'NO' ]; then
   export SUITE="FV3_GFS_v17_p8"
   export rungfs="run_fv3.sh"
elif [ "$coupled" == 'ATM_OCN_ICE' ]; then
   export SUITE="FV3_GFS_HR1"
   export rungfs="run_coupled.sh"
elif [ "$coupled" == 'ATM_OCN_ICE_WAV' ]; then
   export SUITE="FV3_GFS_HR1"
   export rungfs="run_coupled.sh"
   export running_wave="YES"
else
   echo "${coupled} option not supported"
   echo "please chose betwee NO ATM_OCN_ICE"
   exit 1
fi

cd $scriptsdir
echo "run main driver script"
if [ -z $longfcst ]; then
   echo "running replay cycle `date`..."
   sh -x main.sh
else
   echo "running long fcst for analdate=$analdate `date` .."
   sh run_longfcst.sh
   echo "done running long forecast for analdate=$analdate `date` .."
fi
