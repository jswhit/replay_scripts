#!/bin/bash --posix

/bin/rm -rf ufs-weather-model-p8_coupledmm
git clone https://github.com/ufs-community/ufs-weather-model ufs-weather-model-p8_coupledmm
cd ufs-weather-model-p8_coupledmm
git checkout Prototype-P8
git submodule update --init --recursive

# get version of dycore that supports mixed mode compilation
cd FV3
mv atmos_cubed_sphere atmos_cubed_sphere.save
git clone https://github.com/NOAA-EMC/GFDL_atmos_cubed_sphere atmos_cubed_sphere
cd atmos_cubed_sphere
git checkout fms_mixedmode
cd ../..

# patch to turn off saving of IAU increments in MOM6 restart
patch -p 0 < /scratch2/BMC/gsienkf/whitaker/mom6_iau_restart.diff
# load FMS 2022.03 module, path CMakeLists.txt to always use fms_r8
patch -p 0 < /scratch2/BMC/gsienkf/whitaker/mixedmode_p8.diff
# patch for skipping MOM6 restart at end
patch -p 0 < /scratch2/BMC/gsienkf/whitaker/mom_cap.diff

cd tests
./compile.sh hera.intel "-DAPP=S2SW -D32BIT=ON -DCCPP_SUITES=FV3_GFS_v17_coupled_p8" coupledmm YES YES
#./compile.sh hera.intel "-DAPP=S2SW -DCCPP_SUITES=FV3_GFS_v17_coupled_p8" coupled YES YES
