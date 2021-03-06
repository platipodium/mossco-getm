#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m3d - 3D model component
!
! !INTERFACE:
   module m3d
!
! !DESCRIPTION:
!  This module contains declarations for all variables related to 3D
!  hydrodynamical calculations. Information about the calculation domain
!  is included from the {\tt domain} module.
!  The module contains public subroutines for initialisation, integration
!  and clean up of the 3D model component.
!  The {\tt m3d} module is initialised in the routine {\tt init\_3d}, see
!  section \ref{sec-init-3d} described on page
!  \pageref{sec-init-3d}.
!  The actual calculation routines are called in {\tt integrate\_3d}
!  (see section \ref{sec-integrate-3d} on page \pageref{sec-integrate-3d}).
!  and are linked in from the library {\tt lib3d.a}.
!  After the simulation, the module is closed in {\tt clean\_3d}, see
!  section \ref{sec-clean-3d} on page \pageref{sec-clean-3d}.
! !USES:
   use exceptions
   use time, only: write_time_string,timestr
   use domain, only: have_boundaries,maxdepth,vert_cord,az
   use domain, only: bottfric_method
   use les, only: do_les_3d
   use les, only: les_mode,NO_LES,LES_MOMENTUM
   use m2d, only: depth_update,bottom_friction
   use m2d, only: no_2d
   use variables_2d, only: deformC,deformX,deformUV
   use variables_2d, only: z
#ifndef NO_BAROCLINIC
   use temperature, only: init_temperature,do_temperature,init_temperature_field
   use salinity, only: init_salinity,do_salinity,init_salinity_field
   use eqstate,    only: init_eqstate, do_eqstate
#endif
   use nonhydrostatic, only: nonhyd_method,init_nonhydrostatic
   use internal_pressure, only: init_internal_pressure, do_internal_pressure
   use internal_pressure, only: ip_method,ip_ramp,ip_ramp_is_active
   use variables_3d
   use vertical_coordinates, only: coordinates,cord_relax
   use advection, only: NOADV
   use advection_3d, only: init_advection_3d,print_adv_settings_3d,adv_ver_iterations
   use bdy_3d, only: init_bdy_3d, do_bdy_3d
   use bdy_3d, only: bdyfile_3d,bdyfmt_3d,bdy3d_vel,bdy3d_ramp,bdy3d_sponge_size
   use bdy_3d, only: bdy3d_tmrlx, bdy3d_tmrlx_ucut, bdy3d_tmrlx_max, bdy3d_tmrlx_min
   use waves, only: waveforcing_method,NO_WAVES,uv_waves_3d,stokes_drift_3d
   use variables_waves, only: UStokesC,UStokesCadv,uuStokes
   use variables_waves, only: VStokesC,VStokesCadv,vvStokes
#ifdef _FABM_
   use getm_fabm, only: fabm_calc,init_getm_fabm_fields
#endif
   use parameters, only: rho_0
!  Necessary to use halo_zones because update_3d_halos() have been moved out
!  temperature.F90 and salinity.F90 - should be changed at a later stage
   use halo_zones, only: update_2d_halo,update_3d_halo,wait_halo,D_TAG,U_TAG,V_TAG

   IMPLICIT NONE
!
! !PUBLIC DATA MEMBERS:
   integer                             :: M=1
   logical                             :: calc_ip=.false.
   logical                             :: calc_bottfric=.false.
   integer                             :: vel3d_adv_split=0
   integer                             :: vel3d_adv_hor=1
   integer                             :: vel3d_adv_ver=1
   integer                             :: turb_adv_split=0
   integer                             :: turb_adv_hor=0
   integer                             :: turb_adv_ver=0
   logical                             :: smooth_bvf_hor=.false.
   logical                             :: smooth_bvf_ver=.false.
   logical                             :: calc_temp=.false.
   logical                             :: calc_salt=.false.
   logical                             :: update_temp=.false.
   logical                             :: update_salt=.false.
   logical                             :: use_gotm=.true.
   logical                             :: bdy3d=.false.
   REALTYPE                            :: ip_fac=_ONE_
   integer                             :: vel_check=0
   REALTYPE                            :: min_vel=-4*_ONE_,max_vel=4*_ONE_
   logical                             :: ufirst=.true.
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   logical         :: advect_turbulence=.false.
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_3d - initialise 3D related stuff \label{sec-init-3d}
!
! !INTERFACE:
   subroutine init_3d(runtype,timestep,hotstart)
!
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype
   REALTYPE, intent(in)                :: timestep
   logical, intent(in)                 :: hotstart
!
! !DESCRIPTION:
!  Here, the {\tt m3d} namelist is read from {\tt getm.inp}, and the
!  initialisation of variables is called (see routine {\tt init\_variables}
!  described on page \pageref{sec-init-variables}).
!  Furthermore, a number of consistency checks are made for the choices
!  of the momentum advection schemes. When higher-order advection schemes
!  are chosen for the momentum advection, the compiler option {\tt UV\_TVD}
!  has to be set. Here, the macro time step $\Delta t$ is calculated
!  from the micro time step $\Delta t_m$ and the split factor {\tt M}.
!  Then, in order to have the vertical coordinate system present already here,
!  {\tt coordinates} (see page \pageref{sec-coordinates}) needs to be called,
!  in order to enable proper interpolation of initial values for
!  potential temperature $\theta$ and salinity $S$ for cold starts.
!  Those initial values are afterwards read in via the routines
!  {\tt init\_temperature} (page \pageref{sec-init-temperature}) and
!  {\tt init\_salinity} (page \pageref{sec-init-salinity}).
!  Finally, in order to prepare for the first time step, the momentum advection
!  and internal pressure gradient routines are initialised and the
!  internal pressure gradient routine is called.
!
! !LOCAL VARIABLES:
   integer         :: rc
   NAMELIST /m3d/ &
             M,cnpar,cord_relax,adv_ver_iterations,       &
             bdy3d,bdyfmt_3d,bdy3d_vel,bdy3d_ramp,        &
             bdyfile_3d,bdy3d_sponge_size,                &
             bdy3d_tmrlx,bdy3d_tmrlx_ucut,                &
             bdy3d_tmrlx_max,bdy3d_tmrlx_min,             &
             vel3d_adv_split,vel3d_adv_hor,vel3d_adv_ver, &
             turb_adv_split,turb_adv_hor,turb_adv_ver,    &
             calc_temp,calc_salt,                         &
             use_gotm,avmback,avhback,smooth_bvf_hor,smooth_bvf_ver, &
             nonhyd_method,ip_method,ip_ramp,             &
             vel_check,min_vel,max_vel
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_3d() # ',Ncall
#endif

   LEVEL1 'init_3d'

   if (kmax .gt. 1) calc_bottfric = .true.

!  Read 3D-model specific things from the namelist.
   read(NAMLST,m3d)
!   rewind(NAMLST)

   calc_ip = (runtype.ge.3 .or. nonhyd_method.eq.1)

   deformC_3d =deformC
   deformX_3d =deformX
   deformUV_3d=deformUV

   LEVEL2 "splitting factor M: ",M

! Allocates memory for the public data members - if not static
   call init_variables_3d(runtype)
   call init_advection_3d()

!  Sanity checks for advection specifications
   LEVEL2 'Advection of horizontal 3D velocities'
#ifdef NO_ADVECT
   if (vel3d_adv_hor .ne. NOADV) then
      LEVEL2 "reset vel3d_adv_hor= ",NOADV," because of"
      LEVEL2 "obsolete NO_ADVECT macro. Note that this"
      LEVEL2 "behaviour will be removed in the future."
      vel3d_adv_hor = NOADV
   end if
   if (vel3d_adv_ver .ne. NOADV) then
      LEVEL2 "reset vel3d_adv_ver= ",NOADV," because of"
      LEVEL2 "obsolete NO_ADVECT macro. Note that this"
      LEVEL2 "behaviour will be removed in the future."
      vel3d_adv_ver = NOADV
   end if
#endif
   call print_adv_settings_3d(vel3d_adv_split,vel3d_adv_hor,vel3d_adv_ver,_ZERO_)

   LEVEL2 'vel_check=',vel_check
   if (vel_check .ne. 0) then
      LEVEL3 'doing sanity checks on velocities'
      LEVEL3 'min_vel=',min_vel
      LEVEL3 'max_vel=',max_vel
      if (vel_check .gt. 0) then
         LEVEL3 'out-of-bound values result in termination of program'
      end if
      if (vel_check .lt. 0) then
         LEVEL3 'out-of-bound values result in warnings only'
      end if
   end if

   dt = M*timestep

   LEVEL2 "Turbulence settings"
#ifdef CONSTANT_VISCOSITY
   if (use_gotm) then
      LEVEL3 "Reset use_gotm=F because of obsolete CONSTANT_VISCOSITY macro."
      use_gotm = .false.
   end if
#endif

   avmback = max(_ZERO_,avmback)
   avhback = max(_ZERO_,avhback)

   if (.not. use_gotm) then
      LEVEL3 'turbulent vertical viscosity set to constant: ',real(avmback)
      LEVEL3 'turbulent vertical diffusivity set to constant: ',real(avhback)
      num=avmback
      nuh=avhback
   else
      LEVEL2 'Advection of TKE and eps'

#ifdef NO_ADVECT
      if (turb_adv_hor .ne. NOADV) then
         LEVEL2 "reset turb_adv_hor= ",NOADV," because of"
         LEVEL2 "obsolete NO_ADVECT macro. Note that this"
         LEVEL2 "behaviour will be removed in the future."
         turb_adv_hor = NOADV
      end if
      if (turb_adv_ver .ne. NOADV) then
         LEVEL2 "reset turb_adv_ver= ",NOADV," because of"
         LEVEL2 "obsolete NO_ADVECT macro. Note that this"
         LEVEL2 "behaviour will be removed in the future."
         turb_adv_ver = NOADV
      end if
#endif
      call print_adv_settings_3d(turb_adv_split,turb_adv_hor,turb_adv_ver,_ZERO_)

      advect_turbulence = (turb_adv_hor.ne.NOADV .or. turb_adv_ver.ne.NOADV)

#ifdef TURB_ADV
      if (.not. advect_turbulence) then
         LEVEL2 "WARNING: ignored obsolete TURB_ADV macro!"
      end if
#endif

      LEVEL3 'background turbulent vertical viscosity set to: ',real(avmback)
      LEVEL3 'background turbulent vertical diffusivity set to: ',real(avhback)
      if (bottfric_method.ne.2 .and. bottfric_method.ne.3) then
         STDERR LINE
         LEVEL3 "WARNING: consistency with GOTM requires quadratic bottom friction!!!"
         STDERR LINE
      end if
      num=1.d-15
      nuh=1.d-15

#ifdef SMOOTH_BVF_HORI
      if (.not. smooth_bvf_hor) then
         LEVEL2 "reset smooth_bvf_hor=T because of obsolete"
         LEVEL2 "SMOOTH_BVF_HORI macro. Note that this"
         LEVEL2 "behaviour will be removed in the future."
         smooth_bvf_hor = .true.
      end if
#endif
      LEVEL2 "smooth_bvf_hor = ",smooth_bvf_hor

#ifdef _SMOOTH_BVF_VERT_
      if (.not. smooth_bvf_ver) then
         LEVEL2 "reset smooth_bvf_ver=T because of obsolete"
         LEVEL2 "_SMOOTH_BVF_VERT_ macro. Note that this"
         LEVEL2 "behaviour will be removed in the future."
         smooth_bvf_ver = .true.
      end if
#endif
      LEVEL2 "smooth_bvf_ver = ",smooth_bvf_ver

   end if

!  Needed for interpolation of temperature and salinity
   if (.not. hotstart) then
      ssen = z
      call start_macro()
      call coordinates(hotstart)
      call hcc_check()
   end if

   if (runtype .eq. 2) then
      calc_temp = .false.
      calc_salt = .false.
#ifndef NO_BAROCLINIC
      rho = rho_0
   else
      T = _ZERO_ ; S = _ZERO_ ; rho = _ZERO_
      if(calc_temp) call init_temperature(hotstart)
      if(calc_salt) call init_salinity(hotstart)
      call init_eqstate()
#endif
   end if

   call init_nonhydrostatic()

   if (calc_ip) then
      call init_internal_pressure(runtype,hotstart,nonhyd_method)
   end if

   if (.not.hotstart .and. vert_cord.eq._ADAPTIVE_COORDS_) then
      call preadapt_coordinates(runtype,preadapt)
   end if

   if (runtype .eq. 4) then
      if (calc_salt) update_salt = .true.
      if (calc_temp) update_temp = .true.
   end if

   if (have_boundaries) then
      call init_bdy_3d(bdy3d,runtype,hotstart,update_salt,update_temp)
   else
      bdy3d = .false.
   end if

#ifdef DEBUG
   write(debug,*) 'Leaving init_3d()'
   write(debug,*)
#endif
   return
   end subroutine init_3d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: hotstart_3d - re-initialise some 3D after hotstart read.
!
! !INTERFACE:
   subroutine hotstart_3d(runtype)
! !USES:
   use domain, only: imin,imax,jmin,jmax, az,au,av
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !DESCRIPTION:
!  This routine provides possibility to reset/initialize 3D variables to
!  ensure that velocities are correctly set on land cells after read
!  of a hotstart file.
!
! !LOCAL VARIABLES:
   integer                   :: i,j,rc
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'hotstart_3d() # ',Ncall
#endif

   LEVEL1 'hotstart_3d'

   call depth_update(sseo,ssen,Dn,Dveln,Dun,Dvn,from3d=.true.)
!  KK-TODO: do not store ss[u|v]n in hotstart file
!           can be calculated here (if needed at all... use of D[u|v]n)
!  ssun = Dun - HU
!  ssvn = Dvn - HV
   call coordinates(.true.)

#ifndef NO_BAROCLINIC
   if (calc_temp) then
      LEVEL2 'hotstart temperature:'
      call init_temperature_field()
   end if
   if (calc_salt) then
      LEVEL2 'hotstart salinity:'
      call init_salinity_field()
   end if
#endif
#ifdef _FABM_
   if (fabm_calc) then
      LEVEL2 'hotstart getm_fabm:'
      call init_getm_fabm_fields()
   end if
#endif

   if (nonhyd_method .eq. 1) then
      call do_internal_pressure(2)
   end if

   call velocity_update_3d(.true.,.true.)


! Hotstart fix - see postinit_2d

      do j=jmin,jmax
         do i=imin,imax
            if ( au(i,j).eq.0 .and. ANY(uu(i,j,1:kmax).ne._ZERO_) .and. (az(i,j).eq.1 .or. az(i+1,j).eq.1) ) then
               LEVEL3 'hotstart_3d: Reset to mask(au), uu=0 for i,j=',i,j
            end if
         end do
      end do
      do j=jmin-HALO,jmax+HALO
         do i=imin-HALO,imax+HALO
            if (au(i,j) .eq. 0) then
               uu(i,j,:)  = _ZERO_
               Uadv(i,j)  = _ZERO_
            end if
         end do
      end do
      call mirror_bdy_3d(uu  ,U_TAG)
      call mirror_bdy_2d(Uadv,U_TAG)

      do j=jmin,jmax
         do i=imin,imax
            if ( av(i,j).eq.0 .and. ANY(vv(i,j,1:kmax).ne._ZERO_) .and. (az(i,j).eq.1 .or. az(i,j+1).eq.1) ) then
               LEVEL3 'hotstart_3d: Reset to mask(av), vv=0 for i,j=',i,j
            end if
         end do
      end do
      do j=jmin-HALO,jmax+HALO
         do i=imin-HALO,imax+HALO
            if (av(i,j) .eq. 0) then
               vv(i,j,:)  = _ZERO_
               Vadv(i,j)  = _ZERO_
            end if
         end do
      end do
      call mirror_bdy_3d(vv  ,V_TAG)
      call mirror_bdy_2d(Vadv,V_TAG)

!     These may not be necessary, but we clean up anyway just in case.
      do j=jmin-HALO,jmax+HALO
         do i=imin-HALO,imax+HALO
            if(az(i,j) .eq. 0) then
               tke(i,j,:) = _ZERO_
               num(i,j,:) = 1.e-15
               nuh(i,j,:) = 1.e-15
#ifndef NO_BAROCLINIC
               S(i,j,:)   = -9999.0
               T(i,j,:)   = -9999.0
#endif
            end if
         end do
      end do

   return
   end subroutine hotstart_3d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: postinit_3d - re-initialise some 3D after hotstart read.
!
! !INTERFACE:
   subroutine postinit_3d(runtype,timestep,hotstart,MinN)
! !USES:
   use domain, only: imin,imax,jmin,jmax, az,au,av
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype,MinN
   REALTYPE, intent(in)                :: timestep
   logical, intent(in)                 :: hotstart
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !DESCRIPTION:
!  This routine provides possibility to reset/initialize 3D variables to
!  ensure that velocities are correctly set on land cells after read
!  of a hotstart file.
!
! !LOCAL VARIABLES:
   integer                   :: i,j,ischange,rc
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'postinit_3d() # ',Ncall
#endif

   LEVEL1 'postinit_3d'

   ufirst = ( mod(int(ceiling((_ONE_*MinN)/M)),2) .eq. 1 )

!  must be in postinit because flags are set init_getm_fabm
#ifdef _FABM_
   if (fabm_calc) calc_bottfric = .true.
#endif

   call postinit_variables_3d(update_temp,update_salt)

   if (waveforcing_method .ne. NO_WAVES) then
!     calculate initial Stokes drift...
      if ( .not. hotstart ) then
         UStokesCadv = UStokesC ; VStokesCadv = VStokesC
      end if
      call stokes_drift_3d(dt,Dveln,hvel) ! do not update [uu|vv]Ex!!!
!     ...and initialise Eulerian transports accordingly
      uuEuler = uu - uuStokes
      vvEuler = vv - vvStokes
   end if

   if (hotstart) then
      if (vert_cord .eq. _ADAPTIVE_COORDS_) call shear_frequency()
      call bottom_friction(uuEuler(:,:,1),vvEuler(:,:,1),hun(:,:,1),hvn(:,:,1), &
                           Dveln,rru,rrv)
   end if

#ifndef NO_BAROCLINIC
   if (runtype .ge. 3) then
      call do_eqstate()
      call buoyancy_frequency()
      call do_internal_pressure(1)
   end if
#endif

   if (.not. hotstart) then
#ifndef NO_BAROTROPIC
      if (.not. no_2d) then
         call stop_macro(runtype,.false.)
      end if
#endif
   end if

!  KK-TODO: call stop_macro also for hotstarts => do not store slow terms in restart files
!           requires storage of [U|V]adv (when hotstart is done within 2d cycle)
!           and calculation of Dn,Dun,Dvn for hostarts

   return
   end subroutine postinit_3d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: integrate_3d - calls to do 3D model integration
! \label{sec-integrate-3d}
!
! !INTERFACE:
   subroutine integrate_3d(runtype,n)
!
! !USES:
   use getm_timers, only: tic, toc, TIM_INTEGR3D
#ifndef NO_BAROCLINIC
   use getm_timers, only: TIM_TEMPH, TIM_SALTH
#endif

   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype,n
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !DESCRIPTION:
! This is a wrapper routine to call all 3D related subroutines.
! The call position for the {\tt coordinates} routine depends on
! the compiler option
! The call sequence is as follows:
!
! \vspace{0.5cm}
!
! \begin{tabular}{lll}
! {\tt start\_macro}           & initialising a 3d step & see page
! \pageref{sec-start-macro} \\
! {\tt do\_bdy\_3d}            & boundary conditions for $\theta$ and $S$ & see
! page \pageref{sec-do-bdy-3d} \\
! {\tt coordinates}            & layer heights ({\tt MUTFLAT} defined) & see
! page \pageref{sec-coordinates} \\
! {\tt bottom\_friction\_3d}   & bottom friction & see page
! \pageref{sec-bottom-friction-3d} \\
! {\tt do\_internal\_pressure} & internal pressure gradient & see page
! \pageref{sec-do-internal-pressure} \\
! {\tt uu\_momentum\_3d}       & layer-integrated $u$-velocity & see page
! \pageref{sec-uu-momentum-3d} \\
! {\tt vv\_momentum\_3d}       & layer-integrated $v$-velocity & see page
! \pageref{sec-vv-momentum-3d} \\
! {\tt coordinates}            & layer heights ({\tt MUTFLAT} not defined) & see
! page \pageref{sec-coordinates} \\
! {\tt ww\_momentum\_3d}       & grid-related vertical velocity & see page
! \pageref{sec-ww-momentum-3d} \\
! {\tt uv\_advect\_3d}         & momentum advection & see page
! \pageref{sec-uv-advect-3d} \\
! {\tt uv\_diffusion\_3d}      & momentum diffusion & see page
! \pageref{sec-uv-diffusion-3d} \\
! {\tt stresses\_3d}           & stresses (for GOTM) & see page
! \pageref{sec-stresses-3d} \\
! {\tt ss\_nn}                 & shear and stratification (for GOTM) & see page
! \pageref{sec-ss-nn} \\
! {\tt gotm}                   & interface and call to GOTM & see page
! \pageref{sec-gotm} \\
! {\tt do\_temperature}        & potential temperature equation & see page
! \pageref{sec-do-temperature} \\
! {\tt do\_salinity}           & salinity equation & see page
! \pageref{sec-do-salinity} \\
! {\tt do\_eqstate}            & equation of state & see page
! \pageref{sec-do-eqstate} \\
! {\tt do\_spm}                & suspended matter equation & see page
! \pageref{sec-do-spm} \\
! {\tt do\_getm\_bio}          & call to GOTM-BIO (not yet released) & \\
! {\tt slow\_bottom\_friction} & slow bottom friction & see page
! \pageref{sec-slow-bottom-friction} \\
! {\tt slow\_terms}            & sum of slow terms & see page
! \pageref{sec-slow-terms} \\
! {\tt stop\_macro}            & finishing a 3d step & see page
! \pageref{sec-stop-macro}
! \end{tabular}
!
! \vspace{0.5cm}
!
! Several calls are only executed for certain compiler options. At each
! time step the call sequence for the horizontal momentum equations is
! changed in order to allow for higher order accuracy for the Coriolis
! rotation.
!
! !LOCAL VARIABLES:
!
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'integrate_3d() # ',Ncall
#endif

   call start_macro()
   call coordinates(.false.)

   call tic(TIM_INTEGR3D)
   if (ip_ramp_is_active) then
      if (n .ge. ip_ramp) then
         ip_fac = _ONE_
         ip_ramp_is_active = .false.
         STDERR LINE
         call write_time_string()
         LEVEL3 timestr,': finished ip_ramp=',ip_ramp
         STDERR LINE
      else
         ip_fac = _ONE_*n/ip_ramp
      end if
   end if
   call toc(TIM_INTEGR3D)

#ifdef STRUCTURE_FRICTION
   call structure_friction_3d
#endif
   if (waveforcing_method .ne. NO_WAVES) then
!     calculate new Stokes drift
      call stokes_drift_3d(dt,Dveln,hvel,uuEx,vvEx)
   end if

   call momentum_3d(runtype,n)

   if (calc_bottfric) then
      call tic(TIM_INTEGR3D)
      call bottom_friction(uuEuler(:,:,1),vvEuler(:,:,1),hun(:,:,1),hvn(:,:,1), &
                           Dveln,rru,rrv,zub=zub,zvb=zvb,taubmax=taubmax_3d)
      call toc(TIM_INTEGR3D)
      call stresses_3d()
   end if

   if (kmax .gt. 1) then
!     KK-TODO: In realistic simulations (gotm) we need SS
!              in any case, therefore it is done here by default.
!              In the future one might check whether a very seldom case
!              is present, where it can be skipped.
!              We need SS: 1) #if (!defined(CONSTANT_VISCOSITY) && !defined(PARABOLIC_VISCOSITY))
!                          2) adpative coordinates
!                          3) if(do_numerical_analyses_3d) [physical dissipation analyses]
      call shear_frequency()
   end if

   call deformation_rates_3d()

   if (les_mode .ne. NO_LES) call do_les_3d(dudxC_3d,dudxV_3d, &
#ifndef SLICE_MODEL
                                            dvdyC_3d,dvdyU_3d, &
#endif
                                            shearX_3d,shearU_3d)

   if (kmax .gt. 1) then

      call uv_advect_3d()
      call uv_diffusion_3d()  ! Must be called after uv_advect_3d

      if (waveforcing_method .ne. NO_WAVES) then
!        add new wave forcing
         call uv_waves_3d(uuEuler,vvEuler,Dveln,hvel,hun,hvn,uuEx,vvEx)
      end if

      if (use_gotm) then
         call gotm()
         if (advect_turbulence) call tke_eps_advect_3d()
      end if

   end if

   if (do_numerical_analyses_3d) call physical_dissipation_3d()

#ifndef NO_BAROCLINIC
!  prognostic T and S
   if (calc_stirr) call tracer_stirring()
   if (update_temp) call do_temperature(n)
   if (update_salt) call do_salinity(n)
#endif

   if (have_boundaries) call do_bdy_3d(update_salt,update_temp)


#ifndef NO_BAROCLINIC

   call tic(TIM_INTEGR3D)

!  The following is a bit clumpsy and should be changed when do_bdy_3d()
!  operates on individual fields and not as is the case now - on both
!  T and S.
   if (update_temp) then
      call tic(TIM_TEMPH)
      call update_3d_halo(T,T,az,imin,jmin,imax,jmax,kmax,D_TAG)
      call wait_halo(D_TAG)
      call toc(TIM_TEMPH)
      call mirror_bdy_3d(T,D_TAG)
   end if
   if (update_salt) then
      call tic(TIM_SALTH)
      call update_3d_halo(S,S,az,imin,jmin,imax,jmax,kmax,D_TAG)
      call wait_halo(D_TAG)
      call toc(TIM_SALTH)
      call mirror_bdy_3d(S,D_TAG)
   end if

   call toc(TIM_INTEGR3D)

   if (runtype .eq. 4) then
      call do_eqstate()

!     KK-TODO: In realistic simulations (baroclinic+gotm) we need NN
!              in any case, therefore it is done here by default.
!              In the future one might check whether a very seldom case
!              is present, where it can be skipped.
!              We need NN (runtype .ge. 3):
!                          1) #if (!defined(CONSTANT_VISCOSITY) && !defined(PARABOLIC_VISCOSITY))
!                          2) adaptive coordinates
      call buoyancy_frequency()

      call do_internal_pressure(1)

   end if
#endif

#ifndef NO_BAROTROPIC
   if (.not. no_2d) then
      call stop_macro(runtype,.true.)
   end if
#endif

#ifdef DEBUG
     write(debug,*) 'Leaving integrate_3d()'
     write(debug,*)
#endif
   return
   end subroutine integrate_3d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: clean_3d - cleanup after 3D run \label{sec-clean-3d}
!
! !INTERFACE:
   subroutine clean_3d()
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !DESCRIPTION:
! Here, a call to the routine {\tt clean\_variables\_3d} which howewer
! does not do anything yet.
!
! !LOCAL VARIABLES:
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'clean_3d() # ',Ncall
#endif

   call clean_variables_3d()

#ifdef DEBUG
     write(debug,*) 'Leaving clean_3d()'
     write(debug,*)
#endif
   return
   end subroutine clean_3d
!EOC

!-----------------------------------------------------------------------

   end module m3d

!-----------------------------------------------------------------------
! Copyright (C) 2000 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
