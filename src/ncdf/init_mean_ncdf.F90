#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: Initialise mean netCDf variables
!
! !INTERFACE:
   subroutine init_mean_ncdf(fn,title,starttime,runtype)
!
! !DESCRIPTION:
!
! !USES:
   use netcdf
   use exceptions
   use ncdf_common
   use ncdf_mean
   use domain, only: ioff,joff
   use domain, only: imin,imax,jmin,jmax,kmax
   use domain, only: vert_cord
   use m3d, only: update_temp,update_salt
   use nonhydrostatic, only: nonhyd_iters,bnh_filter,bnh_weight
   use meteo, only: metforcing
#ifdef GETM_BIO
   use bio_var, only: numc,var_names,var_units,var_long
#endif
#ifdef _FABM_
   use getm_fabm, only: model,fabm_pel,output_none
#endif
   use getm_version
!
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   character(len=*), intent(in)        :: fn,title,starttime
   integer, intent(in)                 :: runtype
!
! !DEFINED PARAMETERS:
   logical,    parameter               :: init3d=.true.
!
! !REVISION HISTORY:
!  Original author(s): Adolf Stips & Karsten Bolding
!
!  Revision 1.1  2004/03/29 15:38:10  kbk
!  possible to store calculated mean fields
!
! !LOCAL VARIABLES:
   integer                   :: n
   integer                   :: err
   integer                   :: scalar(1),f3_dims(3),f4_dims(4)
   REALTYPE                  :: fv,mv,vr(2)
   character(len=80)         :: history,tts
!EOP
!-------------------------------------------------------------------------
!BOC
!  create netCDF file
   err = nf90_create(fn, NF90_CLOBBER, ncid)
   if (err .NE. NF90_NOERR) go to 10

!  initialize all time-independent, grid related variables
   call init_grid_ncdf(ncid,init3d,x_dim,y_dim,z_dim)

!  define unlimited dimension
   err = nf90_def_dim(ncid,'time',NF90_UNLIMITED,time_dim)
   if (err .NE. NF90_NOERR) go to 10

!  netCDF dimension vectors
   f3_dims(3)= time_dim
   f3_dims(2)= y_dim
   f3_dims(1)= x_dim

   f4_dims(4)= time_dim
   f4_dims(3)= z_dim
   f4_dims(2)= y_dim
   f4_dims(1)= x_dim


!  globall settings
   history = 'GETM - www.getm.eu'
   tts = 'seconds since '//starttime

!  time
   err = nf90_def_var(ncid,'time',NF90_DOUBLE,time_dim,time_id)
   if (err .NE. NF90_NOERR) go to 10
   call set_attributes(ncid,time_id,units=trim(tts),long_name='time')

!  elevation
   err = nf90_def_var(ncid,'elevmean',NCDF_FLOAT_PRECISION,f3_dims,elevmean_id)
   if (err .NE. NF90_NOERR) go to 10
   fv = elev_missing
   mv = elev_missing
   vr(1) = -15.
   vr(2) =  15.
   call set_attributes(ncid,elevmean_id,long_name='mean elevation',units='m', &
                       FillValue=fv,missing_value=mv,valid_range=vr)

! Ustar at bottom
   fv = vel_missing; mv = vel_missing; vr(1) = -1; vr(2) = 1.
   err = nf90_def_var(ncid,'ustarmean',NCDF_FLOAT_PRECISION,f3_dims,ustarmean_id)
   if (err .NE. NF90_NOERR) go to 10
   call set_attributes(ncid,ustarmean_id,  &
          long_name='bottom friction velocity',units='m/s', &
          FillValue=fv,missing_value=mv,valid_range=vr)

! Standard deviation of ustar
   fv = vel_missing; mv = vel_missing; vr(1) = 0; vr(2) = 1.
   err = nf90_def_var(ncid,'ustar2mean',NCDF_FLOAT_PRECISION,f3_dims,ustar2mean_id)
   if (err .NE. NF90_NOERR) go to 10
   call set_attributes(ncid,ustar2mean_id,  &
          long_name='stdev of bottom friction velocity',units='m/s', &
          FillValue=fv,missing_value=mv,valid_range=vr)

   if (save_h) then
      fv = hh_missing
      mv = hh_missing
      err = nf90_def_var(ncid,'hmean',NCDF_FLOAT_PRECISION,f4_dims,hmean_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,hmean_id, &
                          long_name='mean layer thickness',  &
                          units='meters',FillValue=fv,missing_value=mv)
   end if

   fv = vel_missing
   mv = vel_missing
   vr(1) = -3.
   vr(2) =  3.

!  zonal velocity
   err = nf90_def_var(ncid,'uumean',NCDF_FLOAT_PRECISION,f4_dims,uumean_id)
   if (err .NE. NF90_NOERR) go to 10
   call set_attributes(ncid,uumean_id, &
          long_name='mean zonal vel.',units='m/s', &
          FillValue=fv,missing_value=mv,valid_range=vr)

!  meridional velocity
   err = nf90_def_var(ncid,'vvmean',NCDF_FLOAT_PRECISION,f4_dims,vvmean_id)
   if (err .NE. NF90_NOERR) go to 10
   call set_attributes(ncid,vvmean_id, &
          long_name='mean meridional vel.',units='m/s', &
          FillValue=fv,missing_value=mv,valid_range=vr)

!  vertical velocity
   err = nf90_def_var(ncid,'wmean',NCDF_FLOAT_PRECISION,f4_dims,wmean_id)
   if (err .NE. NF90_NOERR) go to 10
   call set_attributes(ncid,wmean_id, &
          long_name='mean vertical vel.',units='m/s', &
          FillValue=fv,missing_value=mv,valid_range=vr)

#ifndef NO_BAROCLINIC
   if (update_salt) then
      fv = salt_missing
      mv = salt_missing
      vr(1) =  0.
      vr(2) = 40.
      err = nf90_def_var(ncid,'saltmean',NCDF_FLOAT_PRECISION,f4_dims,saltmean_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,saltmean_id, &
             long_name='mean salinity',units='PSU', &
             FillValue=fv,missing_value=mv,valid_range=vr)
   end if

   if (update_temp) then
      fv = temp_missing
      mv = temp_missing
      vr(1) = -2.
      vr(2) = 40.
      err = nf90_def_var(ncid,'tempmean',NCDF_FLOAT_PRECISION,f4_dims,tempmean_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,tempmean_id, &
             long_name='mean temperature',units='degC',&
             FillValue=fv,missing_value=mv,valid_range=vr)
   end if

   if (save_rho) then
      fv = rho_missing
      mv = rho_missing
      vr(1) =  0.
      vr(2) = 30.
      err = nf90_def_var(ncid,'sigma_t',NCDF_FLOAT_PRECISION,f4_dims,sigma_tmean_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,sigma_tmean_id, &
             long_name='mean sigma_t',units='kg/m3',&
             FillValue=fv,missing_value=mv,valid_range=vr)
   end if

!  net heat flux
   if (metforcing) then
      fv = hf_missing; mv = hf_missing; vr(1) = 0; vr(2) = 1500.
      err = nf90_def_var(ncid,'hfmean',NCDF_FLOAT_PRECISION,f3_dims,hfmean_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,hfmean_id,  &
             long_name='mean net heat flux',units='W/m2', &
             FillValue=fv,missing_value=mv,valid_range=vr)
   end if

#endif

   if (metforcing) then
      fv = fwf_missing; mv = fwf_missing; vr(1) = -1.; vr(2) = 1.
      err = nf90_def_var(ncid,'fwfmean',NCDF_FLOAT_PRECISION,f3_dims,fwfmean_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,fwfmean_id,  &
             long_name='mean surface freshwater flux',units='m/s', &
             FillValue=fv,missing_value=mv,valid_range=vr)
   end if

   if (do_numerical_analyses_3d) then

      fv = nummix_missing
      mv = nummix_missing
      vr(1) = -100.0
      vr(2) =  100.0

      err = nf90_def_var(ncid,'numdis_3d',NCDF_FLOAT_PRECISION,f4_dims,nd3d_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,nd3d_id, &
          long_name='mean numerical dissipation', &
          units='W/kg',&
          FillValue=fv,missing_value=mv,valid_range=vr)

#ifdef _NUMERICAL_ANALYSES_OLD_
      err = nf90_def_var(ncid,'numdis_3d_old',NCDF_FLOAT_PRECISION,f4_dims,nd3do_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,nd3do_id, &
          long_name='mean numerical dissipation (old)', &
          units='W/kg',&
          FillValue=fv,missing_value=mv,valid_range=vr)
#endif

      err = nf90_def_var(ncid,'phydis_3d',NCDF_FLOAT_PRECISION,f4_dims,pd3d_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,pd3d_id, &
          long_name='mean physical dissipation', &
          units='W/kg',&
          FillValue=fv,missing_value=mv,valid_range=vr)

#ifdef _NUMERICAL_ANALYSES_OLD_
      err = nf90_def_var(ncid,'numdis_int',NCDF_FLOAT_PRECISION,f3_dims,ndint_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,ndint_id, &
          long_name='mean, vert. integrated numerical dissipation', &
          units='Wm/kg',&
          FillValue=fv,missing_value=mv,valid_range=vr)
#endif

      err = nf90_def_var(ncid,'phydis_int',NCDF_FLOAT_PRECISION,f3_dims,pdint_id)
      if (err .NE. NF90_NOERR) go to 10
      call set_attributes(ncid,pdint_id, &
          long_name='mean, vert. integrated physical dissipation', &
          units='Wm/kg',&
          FillValue=fv,missing_value=mv,valid_range=vr)

      if (update_salt) then

         err = nf90_def_var(ncid,'nummix_salt',NCDF_FLOAT_PRECISION,f4_dims,nmS_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,nmS_id, &
             long_name='mean numerical mixing of salinity', &
             units='psu**2/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)

#ifdef _NUMERICAL_ANALYSES_OLD_
         err = nf90_def_var(ncid,'nummix_salt_old',NCDF_FLOAT_PRECISION,f4_dims,nmSo_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,nmSo_id, &
             long_name='mean numerical mixing of salinity (old)', &
             units='psu**2/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)
#endif

         err = nf90_def_var(ncid,'phymix_salt',NCDF_FLOAT_PRECISION,f4_dims,pmS_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,pmS_id, &
             long_name='mean physical mixing of salinity', &
             units='psu**2/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)

#ifdef _NUMERICAL_ANALYSES_OLD_
         err = nf90_def_var(ncid,'nummix_salt_int',NCDF_FLOAT_PRECISION,f3_dims,nmSint_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,nmSint_id, &
             long_name='mean, vert.integrated numerical mixing of salinity', &
             units='psu**2 m/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)
#endif

         err = nf90_def_var(ncid,'phymix_salt_int',NCDF_FLOAT_PRECISION,f3_dims,pmSint_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,pmSint_id, &
             long_name='mean, vert.integrated physical mixing of salinity', &
             units='psu**2 m/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)
      end if

      if (update_temp) then

         err = nf90_def_var(ncid,'nummix_temp',NCDF_FLOAT_PRECISION,f4_dims,nmT_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,nmT_id, &
             long_name='mean numerical mixing of temperature', &
             units='degC**2/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)

#ifdef _NUMERICAL_ANALYSES_OLD_
         err = nf90_def_var(ncid,'nummix_temp_old',NCDF_FLOAT_PRECISION,f4_dims,nmTo_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,nmTo_id, &
             long_name='mean numerical mixing of temperature (old)', &
             units='degC**2/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)
#endif

         err = nf90_def_var(ncid,'phymix_temp',NCDF_FLOAT_PRECISION,f4_dims,pmT_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,pmT_id, &
             long_name='mean physical mixing of temperature', &
             units='degC**2/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)

#ifdef _NUMERICAL_ANALYSES_OLD_
         err = nf90_def_var(ncid,'nummix_temp_int',NCDF_FLOAT_PRECISION,f3_dims,nmTint_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,nmTint_id, &
             long_name='mean, vert.integrated numerical mixing of temperature', &
             units='degC**2 m/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)
#endif

         err = nf90_def_var(ncid,'phymix_temp_int',NCDF_FLOAT_PRECISION,f3_dims,pmTint_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,pmTint_id, &
             long_name='mean, vert.integrated physical mixing of temperature', &
             units='degC**2 m/s',&
             FillValue=fv,missing_value=mv,valid_range=vr)
      end if

   end if

   if (nonhyd_method .ne. 0) then
      fv = bnh_missing
      mv = bnh_missing
      if (runtype.eq.2 .or. nonhyd_method.eq.1) then
         vr(1) = -10.
         vr(2) = 10.
         err = nf90_def_var(ncid,'bnh',NCDF_FLOAT_PRECISION,f4_dims,bnh_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,bnh_id,long_name='nh buoyancy correction',units='m/s2',&
                             FillValue=fv,missing_value=mv,valid_range=vr)
         if (nonhyd_method .eq. 1) then
            err = nf90_put_att(ncid,bnh_id,'nonhyd_iters',nonhyd_iters)
            err = nf90_put_att(ncid,bnh_id,'bnh_filter',bnh_filter)
            if (bnh_filter .eq. 1 .or. bnh_filter .eq. 3) then
               err = nf90_put_att(ncid,bnh_id,'bnh_weight',bnh_weight)
            end if
         end if
      else
         vr(1) = 0.
         vr(2) = 10./SMALL
         err = nf90_def_var(ncid,'nhsp',NCDF_FLOAT_PRECISION,f4_dims,bnh_id)
         if (err .NE. NF90_NOERR) go to 10
         call set_attributes(ncid,bnh_id,long_name='nh screening parameter',units=' ',&
                             FillValue=fv,missing_value=mv,valid_range=vr)
      end if
   end if

#ifdef GETM_BIO
   allocate(biomean_id(numc),stat=err)
   if (err /= 0) stop 'init_3d_ncdf(): Error allocating memory (bio_ids)'

   fv = bio_missing
   mv = bio_missing
   vr(1) = -50.
   vr(2) = 9999.
   do n=1,numc
      err = nf90_def_var(ncid,trim(var_names(n)) // '_mean',NCDF_FLOAT_PRECISION, &
                         f4_dims,biomean_id(n))
      if (err .NE.  NF90_NOERR) go to 10
      call set_attributes(ncid,biomean_id(n), &
                          long_name=trim(var_long(n)), &
                          units=trim(var_units(n)), &
                          FillValue=fv,missing_value=mv,valid_range=vr)
   end do
#endif
#ifdef _FABM_
   if (allocated(fabm_pel)) then
      allocate(fabmmean_ids(size(model%state_variables)),stat=err)
      if (err /= 0) stop 'init_mean_ncdf(): Error allocating memory (fabmmean_ids)'
      fabmmean_ids = -1
      do n=1,size(model%state_variables)
         if (model%state_variables(n)%output==output_none) cycle
         err = nf90_def_var(ncid,model%state_variables(n)%name,NCDF_FLOAT_PRECISION,f4_dims,fabmmean_ids(n))
         if (err .NE.  NF90_NOERR) go to 10
         call set_attributes(ncid,fabmmean_ids(n), &
                          long_name    =trim(model%state_variables(n)%long_name), &
                          units        =trim(model%state_variables(n)%units),    &
                          FillValue    =model%state_variables(n)%missing_value,  &
                          missing_value=model%state_variables(n)%missing_value,  &
                          valid_min    =model%state_variables(n)%minimum,        &
                          valid_max    =model%state_variables(n)%maximum)
      end do

      allocate(fabmmean_ids_ben(size(model%bottom_state_variables)),stat=err)
      if (err /= 0) stop 'init_mean_ncdf(): Error allocating memory (fabmmean_ids_ben)'
      fabmmean_ids_ben = -1
      do n=1,size(model%bottom_state_variables)
         if (model%bottom_state_variables(n)%output==output_none) cycle
         err = nf90_def_var(ncid,model%bottom_state_variables(n)%name,NCDF_FLOAT_PRECISION,f3_dims,fabmmean_ids_ben(n))
         if (err .NE.  NF90_NOERR) go to 10
         call set_attributes(ncid,fabmmean_ids_ben(n), &
                       long_name    =trim(model%bottom_state_variables(n)%long_name), &
                       units        =trim(model%bottom_state_variables(n)%units),    &
                       FillValue    =model%bottom_state_variables(n)%missing_value,  &
                       missing_value=model%bottom_state_variables(n)%missing_value,  &
                       valid_min    =model%bottom_state_variables(n)%minimum,        &
                       valid_max    =model%bottom_state_variables(n)%maximum)
      end do

      allocate(fabmmean_ids_diag(size(model%diagnostic_variables)),stat=err)
      if (err /= 0) stop 'init_mean_ncdf(): Error allocating memory (fabmmean_ids_diag)'
      fabmmean_ids_diag = -1
      do n=1,size(model%diagnostic_variables)
         if (model%diagnostic_variables(n)%output==output_none) cycle
         err = nf90_def_var(ncid,model%diagnostic_variables(n)%name,NCDF_FLOAT_PRECISION,f4_dims,fabmmean_ids_diag(n))
         if (err .NE.  NF90_NOERR) go to 10
         call set_attributes(ncid,fabmmean_ids_diag(n), &
                       long_name    =trim(model%diagnostic_variables(n)%long_name), &
                       units        =trim(model%diagnostic_variables(n)%units),    &
                       FillValue    =model%diagnostic_variables(n)%missing_value,  &
                       missing_value=model%diagnostic_variables(n)%missing_value,  &
                       valid_min    =model%diagnostic_variables(n)%minimum,        &
                       valid_max    =model%diagnostic_variables(n)%maximum)
      end do

      allocate(fabmmean_ids_diag_hz(size(model%horizontal_diagnostic_variables)),stat=err)
      if (err /= 0) stop 'init_mean_ncdf(): Error allocating memory (fabmmean_ids_diag_hz)'
      fabmmean_ids_diag_hz = -1
      do n=1,size(model%horizontal_diagnostic_variables)
         if (model%horizontal_diagnostic_variables(n)%output==output_none) cycle
         err = nf90_def_var(ncid,model%horizontal_diagnostic_variables(n)%name,NCDF_FLOAT_PRECISION,f3_dims,fabmmean_ids_diag_hz(n))
         if (err .NE.  NF90_NOERR) go to 10
         call set_attributes(ncid,fabmmean_ids_diag_hz(n), &
                       long_name    =trim(model%horizontal_diagnostic_variables(n)%long_name), &
                       units        =trim(model%horizontal_diagnostic_variables(n)%units),    &
                       FillValue    =model%horizontal_diagnostic_variables(n)%missing_value,  &
                       missing_value=model%horizontal_diagnostic_variables(n)%missing_value,  &
                       valid_min    =model%horizontal_diagnostic_variables(n)%minimum,        &
                       valid_max    =model%horizontal_diagnostic_variables(n)%maximum)
      end do

      if (do_numerical_analyses_3d) then
         allocate(nummix_fabmmean_ids(size(model%state_variables)),stat=err)
         if (err /= 0) stop 'init_mean_ncdf(): Error allocating memory (nummix_fabmmean_ids)'
         nummix_fabmmean_ids = -1
         do n=1,size(model%state_variables)
            if (model%state_variables(n)%output==output_none) cycle
            err = nf90_def_var(ncid,'nummix_'//trim(model%state_variables(n)%name),NCDF_FLOAT_PRECISION,f4_dims,nummix_fabmmean_ids(n))
            if (err .NE.  NF90_NOERR) go to 10
            call set_attributes(ncid,nummix_fabmmean_ids(n), &
                             long_name    ='mean numerical mixing of '//trim(model%state_variables(n)%long_name), &
                             units        ='('//trim(model%state_variables(n)%units)//')**2/s',                   &
                             FillValue    =model%state_variables(n)%missing_value,                                &
                             missing_value=model%state_variables(n)%missing_value)
         end do
         allocate(phymix_fabmmean_ids(size(model%state_variables)),stat=err)
         if (err /= 0) stop 'init_mean_ncdf(): Error allocating memory (phymix_fabmmean_ids)'
         phymix_fabmmean_ids = -1
         do n=1,size(model%state_variables)
            if (model%state_variables(n)%output==output_none) cycle
            err = nf90_def_var(ncid,'phymix_'//trim(model%state_variables(n)%name),NCDF_FLOAT_PRECISION,f4_dims,phymix_fabmmean_ids(n))
            if (err .NE.  NF90_NOERR) go to 10
            call set_attributes(ncid,phymix_fabmmean_ids(n), &
                             long_name    ='mean physical mixing of '//trim(model%state_variables(n)%long_name), &
                             units        ='('//trim(model%state_variables(n)%units)//')**2/s',                   &
                             FillValue    =model%state_variables(n)%missing_value,                                &
                             missing_value=model%state_variables(n)%missing_value)
         end do
      end if

   end if
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

   10 FATAL 'init_mean_ncdf: ',nf90_strerror(err)
   stop 'init_mean_ncdf'
   end subroutine init_mean_ncdf
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2004 - Adolf Stips and Karsten Bolding (BBH)           !
!-----------------------------------------------------------------------
