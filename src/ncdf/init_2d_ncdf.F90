#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: Initialise 2D netCDf variables
!
! !INTERFACE:
   subroutine init_2d_ncdf(fn,title,starttime)
!
! !DESCRIPTION:
!
! !USES:
   use netcdf
   use exceptions
   use ncdf_common
   use ncdf_2d
   use domain, only: imin,imax,jmin,jmax
   use domain, only: ioff,joff
   use meteo,  only: metforcing,calc_met
   use meteo,  only: fwf_method
   use m2d,    only: Am_method,NO_AM,residual
   use getm_version
!
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   character(len=*), intent(in)        :: fn,title,starttime

! !DEFINED PARAMETERS:
   logical,    parameter               :: init3d=.false.
!
! !REVISION HISTORY:
!
! !LOCAL VARIABLES:
   integer                   :: err
   integer                   :: scalar(1),f2_dims(2),f3_dims(3)
   REALTYPE                  :: fv,mv,vr(2)
   character(len=80)         :: history,ts
!EOP
!-------------------------------------------------------------------------
!BOC
!  create netCDF file
   err = nf90_create(fn, NF90_CLOBBER, ncid)
   if (err .NE. NF90_NOERR) go to 10

!  initialize all time-independent, grid related variables
   call init_grid_ncdf(ncid,init3d,x_dim,y_dim)

!  define unlimited dimension
   err = nf90_def_dim(ncid,'time',NF90_UNLIMITED,time_dim)
   if (err .NE. NF90_NOERR) go to 10

!  netCDF dimension vectors
   f2_dims(2)= y_dim
   f2_dims(1)= x_dim

   f3_dims(3)= time_dim
   f3_dims(2)= y_dim
   f3_dims(1)= x_dim

!  gobal settings
   history = 'GETM - www.getm.eu'
   ts = 'seconds since '//starttime

!  time
   err = nf90_def_var(ncid,'time',NF90_DOUBLE,time_dim,time_id)
   if (err .NE. NF90_NOERR) go to 10
   call set_attributes(ncid,time_id,units=trim(ts),long_name='time')

!  elevation
   err = nf90_def_var(ncid,'elev',NCDF_FLOAT_PRECISION,f3_dims,elev_id)
   if (err .NE. NF90_NOERR) go to 10
   fv = elev_missing
   mv = elev_missing
   vr(1) = -15.
   vr(2) =  15.
   call set_attributes(ncid,elev_id,long_name='elevation',units='meters', &
                       FillValue=fv,missing_value=mv,valid_range=vr)

!  volume fluxes
   if (save_fluxes) then
      fv = flux_missing
      mv = flux_missing
      vr(1) = -10000.
      vr(2) =  10000.
      err = nf90_def_var(ncid,'fluxu',NCDF_FLOAT_PRECISION,f3_dims,fluxu_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,fluxu_id,long_name='grid-related volume flux in local x-direction (U-point)', &
                          units='m3/s',                                   &
                          FillValue=fv,missing_value=mv,valid_range=vr)
      err = nf90_def_var(ncid,'fluxv',NCDF_FLOAT_PRECISION,f3_dims,fluxv_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,fluxv_id,long_name='grid-related volume flux in local y-direction (V-point)', &
                          units='m3/s',                                   &
                          FillValue=fv,missing_value=mv,valid_range=vr)
   end if

!  velocities
   if (save_vel2d) then
      fv = vel_missing
      mv = vel_missing
      vr(1) = -3.
      vr(2) =  3.
      err = nf90_def_var(ncid,'u',NCDF_FLOAT_PRECISION,f3_dims,u_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,u_id,long_name='velocity in global x-direction (T-point)',units='m/s', &
                          FillValue=fv,missing_value=mv,valid_range=vr)
      err = nf90_def_var(ncid,'v',NCDF_FLOAT_PRECISION,f3_dims,v_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,v_id,long_name='velocity in global y-direction (T-point)',units='m/s', &
                          FillValue=fv,missing_value=mv,valid_range=vr)
   end if

   if (do_numerical_analyses_2d) then
      fv = nummix_missing
      mv = nummix_missing
      vr(1) = -100.0
      vr(2) = 100.0
      err = nf90_def_var(ncid,'numdis_2d',NCDF_FLOAT_PRECISION,f3_dims,nd2d_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,nd2d_id, &
          long_name='numerical dissipation', &
          units='W/kg',&
          FillValue=fv,missing_value=mv,valid_range=vr)
#ifdef _NUMERICAL_ANALYSES_OLD_
      err = nf90_def_var(ncid,'numdis_2d_old',NCDF_FLOAT_PRECISION,f3_dims,nd2do_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,nd2do_id, &
          long_name='numerical dissipation (old)', &
          units='W/kg',&
          FillValue=fv,missing_value=mv,valid_range=vr)
#endif
      if (Am_method .ne. NO_AM) then
         err = nf90_def_var(ncid,'phydis_2d',NCDF_FLOAT_PRECISION,f3_dims,pd2d_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,pd2d_id, &
             long_name='physical dissipation', &
             units='W/kg',&
             FillValue=fv,missing_value=mv,valid_range=vr)
      end if
   end if

!  meteorology
   if (metforcing .and. save_meteo) then
      if (calc_met) then
         fv = vel_missing; mv = vel_missing; vr(1) = -50.; vr(2) =  50.
         err = nf90_def_var(ncid,'u10',NCDF_FLOAT_PRECISION,f3_dims,u10_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,u10_id,long_name='U10',units='m/s', &
                             FillValue=fv,missing_value=mv,valid_range=vr)
         err = nf90_def_var(ncid,'v10',NCDF_FLOAT_PRECISION,f3_dims,v10_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,v10_id,long_name='V10',units='m/s', &
                             FillValue=fv,missing_value=mv,valid_range=vr)

         fv = airp_missing; mv = airp_missing;
         vr(1) = 90.e3; vr(2) = 110.e3
         err = nf90_def_var(ncid,'airp',NCDF_FLOAT_PRECISION,f3_dims,airp_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,airp_id,  &
                             long_name='air pressure',units='Pascal', &
                             FillValue=fv,missing_value=mv,valid_range=vr)

         fv = t2_missing; mv = t2_missing; vr(1) = 0; vr(2) = 325.
         err = nf90_def_var(ncid,'t2',NCDF_FLOAT_PRECISION,f3_dims,t2_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,t2_id,  &
                             long_name='temperature (2m)',units='Kelvin', &
                             FillValue=fv,missing_value=mv,valid_range=vr)

         fv = hum_missing; mv = hum_missing; vr(1) = 0; vr(2) = 100.
         err = nf90_def_var(ncid,'hum',NCDF_FLOAT_PRECISION,f3_dims,hum_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,hum_id,  &
                             long_name='humidity',units='kg/kg', &
                             FillValue=fv,missing_value=mv,valid_range=vr)

         fv = tcc_missing; mv = tcc_missing; vr(1) = 0.; vr(2) = 1.
         err = nf90_def_var(ncid,'tcc',NCDF_FLOAT_PRECISION,f3_dims,tcc_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,tcc_id,  &
                             long_name='total cloud cover',units='fraction', &
                             FillValue=fv,missing_value=mv,valid_range=vr)
      end if

      fv = stress_missing; mv = stress_missing; vr(1) = -1; vr(2) = 1.
      err = nf90_def_var(ncid,'tausx',NCDF_FLOAT_PRECISION,f3_dims,tausx_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,tausx_id,  &
                          long_name='surface stress - x',units='N/m2', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      err = nf90_def_var(ncid,'tausy',NCDF_FLOAT_PRECISION,f3_dims,tausy_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,tausy_id,  &
                          long_name='surface stress - y',units='N/m2', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      fv = angle_missing; mv = angle_missing; vr(1) = _ZERO_; vr(2) = 90.
      err = nf90_def_var(ncid,'zenith_angle',NCDF_FLOAT_PRECISION, &
                         f3_dims,zenith_angle_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,zenith_angle_id,  &
                          long_name='solar zenith angle',units='degrees', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      fv = albedo_missing; mv = albedo_missing; vr(1) = _ZERO_; vr(2) = _ONE_
      err = nf90_def_var(ncid,'albedo',NCDF_FLOAT_PRECISION,f3_dims,albedo_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,albedo_id,  &
                          long_name='surface albedo',units='', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      fv = swr_missing; mv = swr_missing; vr(1) = 0; vr(2) = 1500.
      err = nf90_def_var(ncid,'swr',NCDF_FLOAT_PRECISION,f3_dims,swr_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,swr_id,  &
                          long_name='short wave radiation',units='W/m2', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      fv = shf_missing; mv = shf_missing; vr(1) = -1000; vr(2) = 1000.
      err = nf90_def_var(ncid,'shf',NCDF_FLOAT_PRECISION,f3_dims,shf_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,shf_id,  &
                          long_name='surface heat fluxes',units='W/m2', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      if (fwf_method .ge. 2) then
         fv = evap_missing; mv = evap_missing; vr(1) = -1.0; vr(2) = 1.
         err = nf90_def_var(ncid,'evap',NCDF_FLOAT_PRECISION,f3_dims,evap_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,evap_id,  &
                            long_name='evaporation',units='m/s', &
                            FillValue=fv,missing_value=mv,valid_range=vr)
      end if

      if (fwf_method .eq. 2 .or. fwf_method .eq. 3) then
         fv = precip_missing; mv = precip_missing; vr(1) = -1.; vr(2) = 1.
         err = nf90_def_var(ncid,'precip',NCDF_FLOAT_PRECISION,f3_dims,precip_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,precip_id,  &
                            long_name='precipitation',units='m/s', &
                            FillValue=fv,missing_value=mv,valid_range=vr)
      end if

   end if


   if (save_waves) then

      fv = waves_missing
      mv = waves_missing

      err = nf90_def_var(ncid,'waveH',NCDF_FLOAT_PRECISION,f3_dims,waveH_id)
      if (err .NE. NF90_NOERR) go to 10
      vr(1) =  0.
      vr(2) = 15.
      call set_attributes(ncid,waveH_id,long_name='significant wave height',units='meters', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      err = nf90_def_var(ncid,'waveL',NCDF_FLOAT_PRECISION,f3_dims,waveL_id)
      if (err .NE. NF90_NOERR) go to 10
      vr(1) =     0.
      vr(2) = 10000.
      call set_attributes(ncid,waveL_id,long_name='mean wave length',units='meters', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      err = nf90_def_var(ncid,'waveT',NCDF_FLOAT_PRECISION,f3_dims,waveT_id)
      if (err .NE. NF90_NOERR) go to 10
      vr(1) =    0.
      vr(2) = 1000.
      call set_attributes(ncid,waveT_id,long_name='wave period',units='seconds', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

!     volume fluxes
      if (save_fluxes) then
         vr(1) = -3.
         vr(2) =  3.
         err = nf90_def_var(ncid,'fluxuStokes',NCDF_FLOAT_PRECISION,f3_dims,fluxuStokes_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,fluxuStokes_id,long_name='grid-related volume Stokes flux in local x-direction (U-point)', &
                             units='m3/s',                                                                                   &
                             FillValue=fv,missing_value=mv,valid_range=vr)
         err = nf90_def_var(ncid,'fluxvStokes',NCDF_FLOAT_PRECISION,f3_dims,fluxvStokes_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,fluxvStokes_id,long_name='grid-related volume Stokes flux in local y-direction (V-point)', &
                             units='m3/s',                                                                                   &
                             FillValue=fv,missing_value=mv,valid_range=vr)
      end if

!     velocities
      if (save_vel2d) then
         vr(1) = -1.
         vr(2) =  1.
         err = nf90_def_var(ncid,'uStokes',NCDF_FLOAT_PRECISION,f3_dims,uStokes_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,uStokes_id,long_name='Stokes drift in global x-direction (T-point)',units='m/s', &
                             FillValue=fv,missing_value=mv,valid_range=vr)
         err = nf90_def_var(ncid,'vStokes',NCDF_FLOAT_PRECISION,f3_dims,vStokes_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,vStokes_id,long_name='Stokes drift in global y-direction (T-point)',units='m/s', &
                             FillValue=fv,missing_value=mv,valid_range=vr)
      end if

   end if


   if (Am_method.eq.AM_LES .and. save_Am_2d) then
      fv = Am_2d_missing; mv = Am_2d_missing; vr(1) = 0.; vr(2) =  500.
      err = nf90_def_var(ncid,'Am_2d',NCDF_FLOAT_PRECISION,f3_dims,Am_2d_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,Am_2d_id,long_name='hor. eddy viscosity',units='m2/s', &
                          FillValue=fv,missing_value=mv,valid_range=vr)
   end if

   if (save_taub) then
      fv = stress_missing; mv = stress_missing; vr(1) = 0.; vr(2) = 20.
      err = nf90_def_var(ncid,'taubmax',NCDF_FLOAT_PRECISION,f3_dims,taubmax_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,taubmax_id,  &
                          long_name='max. bottom stress',units='N/m2', &
                          FillValue=fv,missing_value=mv,valid_range=vr)
   end if

   if (residual .gt. 0) then
!     residual currents - u and v
      fv = vel_missing; mv = vel_missing; vr(1) = -3.; vr(2) =  3.
      err = nf90_def_var(ncid,'res_u',NCDF_FLOAT_PRECISION,f2_dims,res_u_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,res_u_id,long_name='res. u',units='m/s', &
                          FillValue=fv,missing_value=mv,valid_range=vr)

      err = nf90_def_var(ncid,'res_v',NCDF_FLOAT_PRECISION,f2_dims,res_v_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,res_v_id,long_name='res. v',units='m/s', &
                          FillValue=fv,missing_value=mv,valid_range=vr)
   end if

#ifdef USE_BREAKS
      err = nf90_def_var(ncid,'break_stat',NF90_INT,f3_dims(1:2),break_stat_id)
      if (err .ne. NF90_NOERR) call netcdf_error(err,                  &
                                  "init_2d_ncdf()","break_stat")
      call set_attributes(ncid,break_stat_id, &
                          long_name='stats (emergency breaks)')
#endif

!  globals
   err = nf90_put_att(ncid,NF90_GLOBAL,'title',trim(title))
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_att(ncid,NF90_GLOBAL,'model ',trim(history))
   if (err .NE. NF90_NOERR) go to 10

#if 0
   err = nf90_put_att(ncid,NF90_GLOBAL,'git hash:   ',trim(git_commit_id))
   if (err .NE. NF90_NOERR) go to 10
   err = nf90_put_att(ncid,NF90_GLOBAL,'git branch: ',trim(git_branch_name))
   if (err .NE. NF90_NOERR) go to 10
#endif

!   history = FORTRAN_VERSION
!   err = nf90_put_att(ncid,NF90_GLOBAL,'compiler',trim(history))
!   if (err .NE. NF90_NOERR) go to 10

   ! leave define mode
   err = nf90_enddef(ncid)
   if (err .NE. NF90_NOERR) go to 10

   return

   10 FATAL 'init_2d_ncdf: ',nf90_strerror(err)
   stop 'init_2d_ncdf'
   end subroutine init_2d_ncdf
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
