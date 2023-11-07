import xarray as xr
import numpy as np
import sys

infile=sys.argv[1]
anl=xr.open_dataset('anl_'+infile)
rhos      = 330.0
cp_ice    = 2106.
c1        = 1.0
Lsub      = 2.835e6
Lvap      = 2.501e6
Lfresh=Lsub - Lvap
rnslyr=1.0
puny=1.0E-012

# icepack formulate for snow temperature
A = c1 / (rhos * cp_ice)
B = Lfresh / cp_ice
zTsn = A * anl['qsno001'][:].values + B
# icepack formula for max snow tempature
Tmax = -anl['qsno001'][:].values*puny*rnslyr /(rhos*cp_ice*anl['vsnon'][:].values)

# enthlap at max now tempetarure
Qmax=rhos*cp_ice*(Tmax-Lfresh/cp_ice)

# fill in new enthalpy where snow temperature is too high
newq=np.where(zTsn <= Tmax,anl['qsno001'][:].values,Qmax)
newf=np.where(anl['vicen'] > 0.00001,anl['aicen'][:].values,0.0)

# fill in snow enthalpy (0) where there is no snow
newq2=np.where(anl['vsnon'][:]==0.0,anl['qsno001'][:].values,newq)
anl['qsno001'][:]=newq2
anl['aicen'][:]=newf
# write out file
anl.to_netcdf(infile)
