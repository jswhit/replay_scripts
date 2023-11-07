#!/usr/bin/env bash 

echo "run update ice"
echo "analdate   = "$analdate
echo "datapath2  = "$datapath2
echo "charnanal  = "$charnanal
echo "scriptsdir = "$scriptsdir  
echo "iceanaldir"= $iceanaldir
jedi_bin=${iceanaldir}/build/${machine}/bin
static_oras2cice=${iceanaldir}/static_${OCNRES}

YYYY=`echo $analdate | cut -c 1-4`
MM=`echo $analdate | cut -c 5-6`
DD=`echo $analdate | cut -c 7-8`
gdasapp_path=${iceanaldir}/modules/${machine}
SOCA_EXECDIR=${iceanaldir}/build/$machine/bin


# Create a place to run
RUNDIR=${datapath2}/${charnanal}/INPUT/tmpdir
echo "running ice update in "$RUNDIR
rm -rf ${RUNDIR}
mkdir -p ${RUNDIR}/output
cp ${iceanaldir}/input_files/* ${RUNDIR}
ln -sf ${static_oras2cice}/* ${RUNDIR}

cd ${RUNDIR}
cat oras_2cice_arctic.yaml.template | sed -e "s/YYYY/${YYYY}/g" | sed -e "s/MM/${MM}/g" | sed -e "s/DD/${DD}/g"  > ${RUNDIR}/oras_2cice_arctic.yaml
cat oras_2cice_antarctic.yaml.template | sed -e "s/YYYY/${YYYY}/g" | sed -e "s/MM/${MM}/g" | sed -e "s/DD/${DD}/g"  > ${RUNDIR}/oras_2cice_antarctic.yaml

cp ${datapath2}/${charnanal}/INPUT/iced.${YYYY}-${MM}-${DD}-32400.nc ${RUNDIR}/output/
# oras ice file
if [ "$machine" == 'aws' ];then
   if [[ ! -f ${iceanaldir}/oras5_ice_${YYYY}${MM}${DD}_${OCNRES}.nc ]]; then
      aws s3 cp s3://noaa-bmc-none-ca-ufs-rnr/replay/inputs/oras5_ice/${OCNRES}/${YYYY}/${MM}/oras5_ice_${YYYY}${MM}${DD}_${OCNRES}.nc ${iceanaldir}/oras_ice_input/${OCNRES}
   fi
fi
ln -sf ${iceanaldir}/oras_ice_input/${OCNRES}/oras5_ice_${YYYY}${MM}${DD}_${OCNRES}.nc ice-oras.nc
  
# Load the jedi modules
if [ $machine != 'aws' ];then
   echo ${gdasapp_path}/modulefiles
   module use ${gdasapp_path}/modulefiles
   module purge
   module load GDAS/hera
fi

# Insert ORAS5 seaice into the CICE restart 
cd ${RUNDIR}
if [ $machine == 'aws' ];then
   singularity exec --bind /lustre:/lustre ${SOCA_EXECDIR}/jedi-gnu-openmpi-dev_20210324.sif $scriptsdir/run_soca_convertstate.sh $SOCA_EXECDIR/soca_convertstate.x ${RUNDIR}/oras_2cice_arctic.yaml
else
   srun -n 1 ${jedi_bin}/soca_convertstate.x ./oras_2cice_arctic.yaml > NH.out
fi

ierr=$?
if [ $ierr -ne 0 ]; then
   echo "error in NH ice update"
   exit $ierr
fi
  
if [ $machine == 'aws' ];then
   singularity exec --bind /lustre:/lustre ${SOCA_EXECDIR}/jedi-gnu-openmpi-dev_20210324.sif $scriptsdir/run_soca_convertstate.sh $SOCA_EXECDIR/soca_convertstate.x ${RUNDIR}/oras_2cice_antarctic.yaml
else
   srun -n 1 ${jedi_bin}/soca_convertstate.x ./oras_2cice_antarctic.yaml > SH.out
fi   
ierr=$?
if [ $ierr -ne 0 ]; then
   echo "error in NH ice update"
   exit $ierr
fi
# move old restart and copy in new on
mv ${datapath2}/${charnanal}/INPUT/iced.${YYYY}-${MM}-${DD}-32400.nc ${datapath2}/${charnanal}/INPUT/bkg_iced.${YYYY}-${MM}-${DD}-32400.nc 
mv ${RUNDIR}/output/iced.${YYYY}-${MM}-${DD}-32400.nc ${datapath2}/${charnanal}/INPUT/anl_iced.${YYYY}-${MM}-${DD}-32400.nc
cd ${datapath2}/${charnanal}/INPUT/
/lustre/${USER}/conda_ufs/bin/python ${scriptsdir}/limit_snow_enthalpy.py iced.${YYYY}-${MM}-${DD}-32400.nc
cd ${scriptsdir}
if [ $? -eq 0 ]; then
   rm -rf $RUNDIR
fi
