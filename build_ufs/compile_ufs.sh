#!/bin/bash --posix

machine='hera'

/bin/rm -rf ufs-weather-model
git clone https://github.com/ufs-community/ufs-weather-model ufs-weather-model
cd ufs-weather-model
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
patch -p 0 < ../mom6_iau_restart.diff
# load FMS 2022.03 module, path CMakeLists.txt to always use fms_r8
patch -p 0 < ../mixedmode_p8.diff
# patch for skipping MOM6 restart at end
patch -p 0 < ../mom_cap.diff

cd tests
./compile.sh hera.intel "-DAPP=S2SW -D32BIT=ON -DCCPP_SUITES=FV3_GFS_v17_coupled_p8" coupled YES NO
cd ../
./compile.sh hera.intel "-DAPP=ATM -D32BIT=ON -DCCPP_SUITES=FV3_GFS_v17_p8" atmonly YES NO
/bin/cp -f ufs-weather-model/tests/fv3_coupled.exe ../exec_${machine}/ufs_coupled.exe
/bin/cp -f ufs-weather-model/tests/fv3_atmonly.exe ../exec_${machine}/fv3_atm.exe
/bin/rm -rf ufs-weather-model
