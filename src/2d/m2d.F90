#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m2d - depth integrated hydrodynamical model (2D)
!
! !INTERFACE:
   module m2d
!
! !DESCRIPTION:
!  This module contains declarations for all variables related to 2D
!  hydrodynamical calculations. Information about the calculation domain
!  is included from the {\tt domain} module.
!  The module contains public subroutines for initialisation, integration
!  and clean up of the 2D model component.
!  The actual calculation routines are called in {\tt integrate\_2d}
!  and are linked
!  in from the library {\tt lib2d.a}.
!
! !USES:
   use exceptions
   use time, only: julianday,secondsofday
   use domain, only: imin,imax,iextr,jmin,jmax,jextr,az,au,av,ax,H,min_depth
   use domain, only: ilg,ihg,jlg,jhg
   use domain, only: ill,ihl,jll,jhl
   use domain, only: rigid_lid,have_boundaries
!KB   use get_field, only: get_2d_field
   use advection, only: init_advection,print_adv_settings,NOADV
   use les, only: les_mode,LES_MOMENTUM
   use halo_zones, only: update_2d_halo,wait_halo,H_TAG,U_TAG,V_TAG
   use waves, only: uv_waves,waveforcing_method,NO_WAVES
   use variables_waves, only: UStokesC,UStokesCint,UStokes
   use variables_waves, only: VStokesC,VStokesCint,VStokes
   use variables_2d
   use bdy_2d, only: init_bdy_2d
   use bdy_2d, only: bdyfile_2d,bdyfmt_2d,bdy2d_ramp,bdy2d_sponge_size
   IMPLICIT NONE

   interface

      subroutine depth_update(zo,z,D,Dvel,DU,DV,from3d)
         use domain, only: imin,imax,jmin,jmax
         IMPLICIT NONE
         REALTYPE,dimension(E2DFIELD),intent(in)  :: zo,z
         logical,intent(in),optional              :: from3d
         REALTYPE,dimension(E2DFIELD),intent(out) :: D,Dvel,DU,DV
      end subroutine depth_update

      subroutine velocity_update(dt,z,zo,Dvel,U,DU,V,DV,wwm,wwp,missing,  &
                                 velx,vely)
         use domain, only: imin,imax,jmin,jmax
         IMPLICIT NONE
         REALTYPE,intent(in)                      :: dt
         REALTYPE,dimension(E2DFIELD),intent(in)  :: z,zo,Dvel,U,DU,V,DV
         REALTYPE,dimension(E2DFIELD),target,intent(in),optional :: wwm,wwp
         REALTYPE,intent(in),optional             :: missing
         REALTYPE,dimension(E2DFIELD),intent(out) :: velx,vely
      end subroutine velocity_update

      subroutine uv_advect(Uf,Vf,U,V,D,Dvel,DU,DV,numdis)
         use domain, only: imin,imax,jmin,jmax
         IMPLICIT NONE
         REALTYPE,dimension(E2DFIELD),intent(in)        :: Uf,Vf,U,V
         REALTYPE,dimension(E2DFIELD),target,intent(in) :: D,Dvel,DU,DV
         REALTYPE,dimension(:,:),pointer,intent(out),optional :: numdis
      end subroutine uv_advect

      subroutine uv_diffusion(An_method,U,V,D,DU,DV,phydis)
         use domain, only: imin,imax,jmin,jmax
         IMPLICIT NONE
         integer,intent(in)                                   :: An_method
         REALTYPE,dimension(E2DFIELD),intent(in)              :: U,V,D,DU,DV
         REALTYPE,dimension(:,:),pointer,intent(out),optional :: phydis
      end subroutine uv_diffusion

      subroutine uv_diff_2dh(An_method,UEx,VEx,U,V,D,DU,DV,  &
                             dudxC,dvdyC,dudyX,dvdxX,shearX, &
                             AmC,AmX,phydis,hsd_u,hsd_v)
         use domain, only: imin,imax,jmin,jmax
         IMPLICIT NONE
         integer,intent(in)                                :: An_method
         REALTYPE,dimension(E2DFIELD),intent(in),optional  :: U,V,D,DU,DV
         REALTYPE,dimension(E2DFIELD),intent(in),optional  :: dudxC,dvdyC
         REALTYPE,dimension(:,:),pointer,intent(in),optional  :: dudyX,dvdxX
         REALTYPE,dimension(E2DFIELD),intent(in),optional  :: shearX
         REALTYPE,dimension(E2DFIELD),intent(in),optional  :: AmC,AmX
         REALTYPE,dimension(E2DFIELD),intent(inout)        :: UEx,VEx
         REALTYPE,dimension(:,:),pointer,intent(out)       :: phydis
         REALTYPE,dimension(E2DFIELD),intent(out),optional :: hsd_u,hsd_v
      end subroutine uv_diff_2dh

      subroutine bottom_friction(U1,V1,DU1,DV1,Dvel,ru,rv,kwe,zub,zvb,taubmax)
         use domain, only: imin,imax,jmin,jmax
         IMPLICIT NONE
         REALTYPE,dimension(E2DFIELD),intent(in)  :: U1,V1,DU1,DV1,Dvel
         REALTYPE,dimension(E2DFIELD),intent(out) :: ru,rv
         logical,intent(in),optional              :: kwe !keyword-enforcer
         REALTYPE,dimension(E2DFIELD),intent(out),target,optional :: zub,zvb
         REALTYPE,dimension(:,:),pointer,intent(out),optional     :: taubmax
      end subroutine bottom_friction

! Temporary interface (should be read from module):
      subroutine get_2d_field(fn,varname,il,ih,jl,jh,break_on_missing,f)
         character(len=*),intent(in)   :: fn,varname
         integer, intent(in)           :: il,ih,jl,jh
         logical, intent(in)           :: break_on_missing
         REALTYPE, intent(out)         :: f(:,:)
      end subroutine get_2d_field

   end interface
!
! !PUBLIC DATA MEMBERS:
   logical                   :: no_2d
   integer                   :: vel2d_adv_split=0
   integer                   :: vel2d_adv_hor=1
   integer,parameter         :: NO_AM=0,AM_LAPLACE=1,AM_LES=2,AM_CONSTANT=3
   integer                   :: Am_method=NO_AM
   REALTYPE                  :: Am_const=1.8d-6
!  method for specifying horizontal numerical diffusion coefficient
!     (0=const, 1=from named nc-file)
   integer                   :: An_method=0
   REALTYPE                  :: An_const=-_ONE_
   character(LEN = PATH_MAX) :: An_file
   integer                   :: MM=1,residual=-1
   integer                   :: sealevel_check=0
   logical                   :: bdy2d=.false.
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   logical,private           :: ufirst=.false.
!
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_2d - initialise 2D related stuff.
!
! !INTERFACE:
   subroutine init_2d(runtype,timestep,hotstart)
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype
   REALTYPE, intent(in)                :: timestep
   logical, intent(in)                 :: hotstart
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !DESCRIPTION:
!  Here, the {\tt m2d} namelist is read from {\tt getm.inp}, and the check
!  for the fulfilment of the CFL criterium for shallow water theory
!  {\tt cfl\_check} is called. A major part of this subroutine deals
!  then with the setting of local bathymetry values and initial surface
!  elevations in $u$- and $v$-points, also by calls to the subroutines
!  {\tt uv\_depths} and {\tt depth\_update}.
!
! !LOCAL VARIABLES:
   integer                   :: rc
   integer                   :: i,j
   integer                   :: elev_method=1
   REALTYPE                  :: elev_const=_ZERO_
   integer,parameter :: rk = kind(_ONE_)
   character(LEN = PATH_MAX) :: elev_file='elev.nc'
   namelist /m2d/ &
          elev_method,elev_const,elev_file,                       &
          MM,vel2d_adv_split,vel2d_adv_hor,                       &
          Am_method,Am_const,An_method,An_const,An_file,          &
          residual,sealevel_check,                                &
          bdy2d,bdyfmt_2d,bdy2d_ramp,bdyfile_2d,bdy2d_sponge_size
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_2d() # ',Ncall
#endif

   LEVEL1 'init_2d'

#ifdef SLICE_MODEL
!  Note (KK): sse=0,U=0,dyV=0,V set in 3d
   no_2d = rigid_lid
#else
!  Note (KK): sse=0,U=V=0
   no_2d = (rigid_lid .and. (imin.eq.iextr .or. jmin.eq.jextr))
#endif

   dtm = timestep

#ifndef NO_BAROTROPIC
   if (.not. rigid_lid) call cfl_check()
#endif

!  Read 2D-model specific things from the namelist.
   read(NAMLST,m2d)

!  Allocates memory for the public data members - if not static
   call init_variables_2d(runtype,no_2d)
   call init_advection()

   if (.not. no_2d) then
      LEVEL2 'Advection of depth-averaged velocities'
#ifdef NO_ADVECT
      if (vel2d_adv_hor .ne. NOADV) then
         LEVEL2 "reset vel2d_adv_hor= ",NOADV," because of"
         LEVEL2 "obsolete NO_ADVECT macro. Note that this"
         LEVEL2 "behaviour will be removed in the future."
         vel2d_adv_hor = NOADV
      end if
#endif
      call print_adv_settings(vel2d_adv_split,vel2d_adv_hor,_ZERO_)
   end if

   if (.not. hotstart) then
      select case (elev_method)
         case(1)
            LEVEL2 'setting initial surface elevation to ',real(elev_const)
            where ( az.gt.0 ) z = elev_const
         case(2)
            LEVEL2 'getting initial surface elevation from ',trim(elev_file)
            call get_2d_field(trim(elev_file),"elev",ilg,ihg,jlg,jhg,.true.,z(ill:ihl,jll:jhl))
!           Note (KK): we need halo update only for periodic domains
            call update_2d_halo(z,z,az,imin,jmin,imax,jmax,H_TAG)
            call wait_halo(H_TAG)
         case default
            stop 'init_2d(): invalid elev_method'
      end select

      where ( az.gt.0 .and. z.lt.-H+min_depth)
         z = -H+min_depth
      end where
      zo = z
!     KK-TODO: check whether we need D[ |U|V] in init_3d
!              otherwise we can move this call by default to postinit_2d
!              or initialise()
      call depth_update(zo,z,D,Dvel,DU,DV)
   end if


   select case (Am_method)
      case(NO_AM)
         LEVEL2 'Am_method=0 -> horizontal momentum diffusion not included'
      case(AM_LAPLACE)
         LEVEL2 'Am_method=1 -> Using constant horizontal momentum diffusion (Laplacian)'
         if (Am_const .lt. _ZERO_) then
           call getm_error("init_2d()", &
                           "Constant horizontal momentum diffusion <0");
         end if
         LEVEL3 real(Am_const)
         deformC=.true.
      case(AM_LES)
         LEVEL2 'Am_method=2 -> using LES parameterisation'
         les_mode=LES_MOMENTUM
         deformC=.true.
         deformX=.true.
         deformUV=.true.
      case(AM_CONSTANT)
         LEVEL2 'Am_method=3 -> Using constant horizontal momentum diffusion'
         if (Am_const .lt. _ZERO_) then
           call getm_error("init_2d()", &
                           "Constant horizontal momentum diffusion <0");
         end if
         LEVEL3 real(Am_const)
         deformC=.true.
         deformX=.true.
      case default
         call getm_error("init_2d()", &
                         "A non valid Am_method has been chosen");
   end select


   if (.not. no_2d) then

      select case (An_method)
         case(0)
            LEVEL2 'An_method=0 -> horizontal numerical diffusion not included'
         case(1)
            LEVEL2 'An_method=1 -> Using constant horizontal numerical diffusion'
            if (An_const .lt. _ZERO_) then
               call getm_error("init_2d()", &
                               "Constant horizontal numerical diffusion <0");
            end if
         case(2)
            LEVEL2 'An_method=2 -> Using space varying horizontal numerical diffusion'
            LEVEL2 '..  will read An from An_file ',trim(An_file)

            allocate(AnC(E2DFIELD),stat=rc)
            if (rc /= 0) stop 'init_2d: Error allocating memory (AnC)'
            AnC = _ZERO_

            call get_2d_field(trim(An_file),"An",ilg,ihg,jlg,jhg,.true.,AnC(ill:ihl,jll:jhl))

            if (MINVAL(AnC(imin:imax,jmin:jmax),mask=(az(imin:imax,jmin:jmax).ge.1)) .lt. _ZERO_) then
               call getm_error("init_2d()", &
                               "negative numerical diffusivity in An field");
            end if

!           Note (KK): halo update is only needed for periodic domains
            call update_2d_halo(AnC,AnC,az,imin,jmin,imax,jmax,H_TAG)
            call wait_halo(H_TAG)

            if (MAXVAL(AnC(imin-1:imax+1,jmin-1:jmax+1),mask=(az(imin-1:imax+1,jmin-1:jmax+1).ge.1)) .eq. _ZERO_) then
!              Note (BJB): If all An values are really zero, then we should not use An-smoothing at all...
!                          Note that smoothing may be on in other subdomains.
               LEVEL2 '  All An is zero for this (sub)domain - switching to An_method=0'
               An_method=0
            else
!              Note (KK): since a HALO update of AnX is not needed,
!                         the allocation of AnX can be done locally
!                         and dependent on the test above

               allocate(AnX(E2DFIELD),stat=rc)
               if (rc /= 0) stop 'init_2d: Error allocating memory (AnX)'

               ! Compute AnX (An in X-points) based on AnC and the X- and T- masks
               ! We loop over the X-points in the present domain.
               do j=jmin-1,jmax
                  do i=imin-1,imax
                     if (ax(i,j) .ge. 1) then
                        AnX(i,j) = _QUART_*( AnC(i,j) + AnC(i+1,j) + AnC(i,j+1) + AnC(i+1,j+1) )
                     end if
                  end do
               end do
            end if
         case default
            call getm_error("init_2d()", &
                            "A non valid An method has been chosen");
      end select

      if (.not. rigid_lid) then
#ifdef _NO_SEALEVEL_CHECK_
         if (sealevel_check .ne. 0) then
            LEVEL2 "WARNING: reset sealevel_check=0 because of _NO_SEALEVEL_CHECK_ macro."
            sealevel_check=0
         end if
#endif
         if (sealevel_check .eq. 0) then
            LEVEL2 'sealevel_check=0 --> NaN checks disabled'
         else if (sealevel_check .gt. 0) then
            LEVEL2 'sealevel_check>0 --> NaN values will result in error conditions'
         else
            LEVEL2 'sealevel_check<0 --> NaN values will result in warnings'
         end if
      end if

   end if


   if (.not.no_2d .and. have_boundaries) then
      call init_bdy_2d(bdy2d,hotstart)
   else
      bdy2d = .false.
   end if

#ifdef DEBUG
   write(debug,*) 'Leaving init_2d()'
   write(debug,*)
#endif
   return
   end subroutine init_2d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: hotstart_2d - re-initialise some 2D after hotstart read.
!
! !INTERFACE:
   subroutine hotstart_2d(runtype)
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
!  This routine provides possibility to reset/initialize 2D variables to
!  ensure that velocities are correctly set on land cells after read
!  of a hotstart file.
!
! !LOCAL VARIABLES:
   integer                   :: i,j
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'hotstart_2d() # ',Ncall
#endif

   LEVEL1 'hotstart_2d'

!  KK-TODO: velocity update *after* reset of U and V ?!
   call depth_update(zo,z,D,Dvel,DU,DV)
   call velocity_update(dtm,z,zo,Dvel,U,DU,V,DV,velx=velx,vely=vely)

!
! It is possible that a user changes the land mask and reads an "old" hotstart file.
! In this case the "old" velocities will need to be zeroed out.

      do j=jmin,jmax
         do i=imin,imax
            if ( au(i,j).eq.0 .and. U(i,j).ne._ZERO_ .and. (az(i,j).eq.1 .or. az(i+1,j).eq.1) ) then
               LEVEL3 'hotstart_2d: Reset to mask(au), U=0 for i,j=',i,j
            end if
         end do
      end do
      where (au .eq. 0)
         U    = _ZERO_
         Uint = _ZERO_
      end where
      call mirror_bdy_2d(U   ,U_TAG)
      call mirror_bdy_2d(Uint,U_TAG)

      do j=jmin,jmax
         do i=imin,imax
            if ( av(i,j).eq.0 .and. V(i,j).ne._ZERO_ .and. (az(i,j).eq.1 .or. az(i,j+1).eq.1) ) then
               LEVEL3 'hotstart_2d: Reset to mask(av), V=0 for i,j=',i,j
            end if
         end do
      end do
      where (av .eq. 0)
         V    = _ZERO_
         Vint = _ZERO_
      end where
      call mirror_bdy_2d(V   ,V_TAG)
      call mirror_bdy_2d(Vint,V_TAG)

!     This is only needed for proper flexible output
      where (az .eq. 0)
         z  = -9999.0d0
         zo = -9999.0d0
      end where

   return
   end subroutine hotstart_2d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: postinit_2d -
!
! !INTERFACE:
   subroutine postinit_2d(runtype,timestep,hotstart,MinN)
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
!
! !LOCAL VARIABLES:
!
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'postinit_2d() # ',Ncall
#endif

   LEVEL1 'postinit_2d'

   ufirst = ( mod(MinN,2) .eq. 0 )

   call postinit_variables_2d(no_2d)

   if (waveforcing_method .ne. NO_WAVES) then
!     calculate initial Stokes drift...
      call stokes_drift(dtm,Dvel,UEx,VEx)
!     ...and initialise Eulerian transports accordingly
      UEuler = U - UStokes
      VEuler = V - VStokes
   end if


   return
   end subroutine postinit_2d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: integrate_2d - sequence of calls to do 2D model integration
!
! !INTERFACE:
   subroutine integrate_2d(runtype,loop,tausx,tausy,airp)
   use getm_timers, only: tic, toc, TIM_INTEGR2D

   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype,loop
   REALTYPE, intent(in)                :: tausx(E2DFIELD)
   REALTYPE, intent(in)                :: tausy(E2DFIELD)
   REALTYPE, intent(in)                :: airp(E2DFIELD)
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !DESCRIPTION:
!  Here, all 2D related subroutines are called. The major calls and their
!  meaning are:
!
!  \vspace{0.5cm}
!
!  \begin{tabular}{ll}
!  {\tt call update\_2d\_bdy} & read in new lateral boundary conditions \\
!  {\tt call bottom\_friction} & update bottom friction\\
!  {\tt call uv\_advect} & calculate 2D advection terms\\
!  {\tt call uv\_diffusion} & calculate 2D  diffusion terms\\
!  {\tt call momentum} & iterate 2D momemtum equations\\
!  {\tt call sealevel} & update sea surface elevation\\
!  {\tt call depth\_update} & update water depths\\
!  {\tt call do\_residual} & calculate intermdediate values for residual currents
!  \end{tabular}
!
!  \vspace{0.5cm}
!
!  It should be noted that some of these calls may be excluded for certain
!  compiler options set in the {\tt Makefile} of the application.
!
! !LOCAL VARIABLES:
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'integrate_2d() # ',Ncall
#endif
   call tic(TIM_INTEGR2D)

   if (mod(loop-1,MM) .eq. 0) then        ! MacroMicro time step
      call bottom_friction(UEuler,VEuler,DU,DV,Dvel,ru,rv,taubmax=taubmax)
   end if

   call uv_advect(Uf,Vf,U,V,D,Dvel,DU,DV,numdis_2d)
   call uv_diffusion(An_method,UEuler,VEuler,D,DU,DV,phydis_2d) ! Has to be called after uv_advect.

   call toc(TIM_INTEGR2D)

   if (waveforcing_method .ne. NO_WAVES) then
      call uv_waves(UEuler,VEuler,UStokes,VStokes,UStokesC,VStokesC,Dvel,DU,DV,UEx,VEx) ! add forcing
      call stokes_drift(dtm,Dvel,UEx,VEx)             ! calculate new Stokes drift
   end if

   call momentum(loop,tausx,tausy,airp,ufirst)

   if (rigid_lid) then
!     Note (KK): we need to solve Poisson equation to get final transports
!                that fulfill dxU+dyV=0
      stop 'integrate_2d(): Poisson solver for rigid lid computations not implemented yet!'
   end if

   if (runtype .gt. 1) then
      call tic(TIM_INTEGR2D)
      Uint=Uint+U
      Vint=Vint+V
      if (waveforcing_method .ne. NO_WAVES) then
         UEulerInt = UEulerInt + UEuler
         VEulerInt = VEulerInt + VEuler
         UStokesCint = UStokesCint + UStokesC
         VStokesCint = VStokesCint + VStokesC
      end if
      call toc(TIM_INTEGR2D)
   end if

   if (.not. rigid_lid) then
      call sealevel(loop)
      call depth_update(zo,z,D,Dvel,DU,DV)
   end if

   call velocity_update(dtm,z,zo,Dvel,U,DU,V,DV,velx=velx,vely=vely)

   if(residual .gt. 0) then
      call tic(TIM_INTEGR2D)
      call do_residual(0)
      call toc(TIM_INTEGR2D)
   end if

#ifdef DEBUG
     write(debug,*) 'Leaving integrate_2d()'
     write(debug,*)
#endif
   return
   end subroutine integrate_2d
!EOC


!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: clean_2d - cleanup after 2D run.
!
! !INTERFACE:
   subroutine clean_2d()
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !DESCRIPTION:
!  This routine executes a final call to {\tt do\_residual} where the residual
!  current calculations are finished.
!
! !LOCAL VARIABLES:
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'clean_2d() # ',Ncall
#endif

   if(residual .gt. 0) then
      call do_residual(1)
   end if

#ifdef DEBUG
   write(debug,*) 'Leaving clean_2d()'
   write(debug,*)
#endif
   return
   end subroutine clean_2d
!EOC

!-----------------------------------------------------------------------

   end module m2d

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
