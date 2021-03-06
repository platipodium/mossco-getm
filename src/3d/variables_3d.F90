#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: variables_3d - global 3D related variables \label{sec-variables-3d}
!
! !INTERFACE:
   module variables_3d
!
! !DESCRIPTION:
!  This modules contains declarations for all variables related to 3D
!  hydrodynamical calculations. Information about the calculation domain
!  is included from the {\tt domain} module.
!  The variables are either statically defined in {\tt static\_3d.h} or
!  dynamically allocated in {\tt dynamic\_declarations\_3d.h}.
!  The variables which need to be declared have the following dimensions,
!  units and meanings:
!
! \vspace{0.5cm}
! \begin{supertabular}{llll}
! {\tt kmin} & 2D & [-] & lowest index in T-point \\
! {\tt kumin} & 2D &[-]  & lowest index in U-point \\
! {\tt kvmin} & 2D &[-]  & lowest index in V-point \\
! {\tt kmin\_pmz} & 2D &[-]  & lowest index in T-point (poor man's
! $z$-coordinate)\\
! {\tt kumin\_pmz} & 2D &[-]  & lowest index in U-point (poor man's
! $z$-coordinate)\\
! {\tt kvmin\_pmz} & 2D &[-]  & lowest index in V-point (poor man's
! $z$-coordinate)\\
! {\tt uu} & 3D & [m$^2$s$^{-1}$] & layer integrated $u$ transport
! $p_k$\\
! {\tt vv} & 3D & [m$^2$s$^{-1}$] & layer integrated $v$ transport
! $q_k$\\
! {\tt ww} & 3D & [m\,s$^{-1}$] & grid-related vertical velocity
! $\bar w_k$\\
! {\tt ho} & 3D & [m] & old layer height in T-point \\
! {\tt hn} & 3D & [m]& new layer height in T-point \\
! {\tt huo} & 3D &[m]& old layer height in U-point \\
! {\tt hun} & 3D & [m]& new layer height in U-point \\
! {\tt hvo} & 3D & [m]& old layer height in V-point \\
! {\tt hvn} & 3D & [m]& new layer height in V-point \\
! {\tt hcc} & 3D &[-] & hydrostatic consistency index in T-points\\
! {\tt uuEx} & 3D & [m$^2$s$^{-2}$] & sum of advection and
! diffusion for $u$-equation\\
! {\tt vvEx} & 3D &  [m$^2$s$^{-2}$]& sum of advection and
! diffusion for $v$-equation\\
! {\tt num} & 3D &  [m$^2$s$^{-1}$]& eddy viscosity on $w$-points
! $\nu_t$\\
! {\tt nuh} & 3D &  [m$^2$s$^{-1}$]& eddy diffusivity on $w$-points $\nu'_t$\\
! {\tt tke} & 3D &  [m$^2$s$^{-2}$]& turbulent kinetic energy $k$\\
! {\tt eps} & 3D &  [m$^2$s$^{-3}$]& turbulent dissipation rate
! $\eps$ \\
! {\tt SS} & 3D & [s$^{-2}$]& shear-frequency squared $M^2$ \\
! {\tt NN} & 3D &  [s$^{-2}$]& Brunt-V\"ais\"al\"a frequency squared$N^2$ \\
! {\tt S} & 3D & [psu] & salinity $S$ \\
! {\tt T} & 3D & [$^{\circ}$C]& potential temperature $\theta$ \\
! {\tt rad} & 3D & [Wm$^{-2}$]& Short wave penetration \\
! {\tt rho} & 3D & [kg\,m$^{-3}$]& density $rho$ \\
! {\tt buoy} & 3D & [m\,s$^{-2}$]& buoyancy $b$ \\
! {\tt idpdx} & 3D & [m$^2$s$^{-2}$] & $x$-component of internal
! pressure gradient \\
! {\tt idpdy} & 3D & [m$^2$s$^{-2}$]& $y$-component of internal
! pressure gradient\\
! {\tt spm} & 3D & [kg\,m$^{-3}$] & suspended matter concentration \\
! {\tt spm\_ws} & 3D & [m\,s$^{-1}$] & settling velocity of
! suspended matter \\
! {\tt spm\_pool} & 2D & [kg\,m$^{-2}$] & bottom pool of suspended
! matter\\
! {\tt uadv} & 3D & [m\,s$^{-1}$] & interpolated $x$-component of
! momentum advection velocity \\
! {\tt vadv} & 3D &  [m\,s$^{-1}$]& interpolated $y$-component of
! momentum advection velocity \\
! {\tt wadv} & 3D &  [m\,s$^{-1}$]& interpolated  vertical component of
! momentum advection velocity \\
! {\tt huadv} & 3D &[m] & interpolated height of advective flux
! layer ($x$-component) \\
! {\tt hvadv} & 3D &[m] & interpolated height of advective flux
! layer ($y$-component) \\
! {\tt hoadv} & 3D &[m] & old height of advective finite volume cell
! \\
! {\tt hnadv} & 3D &[m] & new height of advective finite volume
! cell\\
! {\tt sseo} & 2D & [m]& sea surface elevation before macro time
! step (T-point)\\
! {\tt ssen} & 2D & [m]& sea surface elevation after macro time
! step (T-point)\\
! {\tt ssuo} & 2D & [m]& sea surface elevation before macro time
! step (U-point)\\
! {\tt ssun} & 2D & [m]&sea surface elevation after macro time step
! (U-point)\\
! {\tt ssvo} & 2D & [m]& sea surface elevation before macro time
! step (V-point)\\
! {\tt ssvn} & 2D & [m]& sea surface elevation after macro time
! step (V-point)\\
! {\tt rru} & 2D & [m\,s$^{-1}$]&drag coefficient times curret speed
! in U-point\\
! {\tt rrv} & 2D & [m\,s$^{-1}$]&drag coefficient times curret speed
! in V-point\\
! {\tt taus} & 2D & [m$^2$s$^{-2}$]& normalised surface stress
! (T-point) \\
! {\tt taub} & 2D & [m$^2$s$^{-2}$]& normalised bottom stress
! (T-point) \\
! \end{supertabular}
!
! \vspace{0.5cm}
!
! It should be noted that depending on compiler options and runtype not
! all these variables are defined.
!
! The module contains public subroutines to initialise (see
! {\tt init\_variables\_3d}) and cleanup (see {\tt clean\_variables\_3d}).
!
! !USES:
   use domain, only: imin,imax,jmin,jmax,kmax,az,bottfric_method,rdrag
   use waves , only: waveforcing_method,waves_method,NO_WAVES,WAVES_VF
   use waves , only: waves_bbl_method,NO_WBBL
   IMPLICIT NONE
!
! !PUBLIC DATA MEMBERS:
   REALTYPE                            :: dt,cnpar=0.9
   REALTYPE                            :: avmback=_ZERO_,avhback=_ZERO_
   logical                             :: save_Sfluxu=.false.
   logical                             :: save_Sfluxv=.false.
   logical                             :: save_Sfluxw=.false.
   logical                             :: do_numerical_analyses_3d=.false.
   logical                             :: deformC_3d=.false.
   logical                             :: deformX_3d=.false.
   logical                             :: deformUV_3d=.false.
   logical                             :: calc_stirr=.false.
!
#ifdef STATIC
#include "static_3d.h"
#else
#include "dynamic_declarations_3d.h"
#endif

!  the following fields will be allocated for waves
   REALTYPE, dimension(:,:  ), pointer :: Uadvf=>NULL(),Vadvf=>NULL()
   REALTYPE, dimension(:,:  ), pointer :: UEulerAdv=>NULL(),VEulerAdv=>NULL()
   REALTYPE, dimension(:,:,:), pointer :: uuf=>NULL(),vvf=>NULL()
   REALTYPE, dimension(:,:,:), pointer :: uuEuler=>NULL(),vvEuler=>NULL()
   REALTYPE, dimension(:,:  ), pointer :: taubmax_3d=>NULL()

   REALTYPE,dimension(:,:,:),pointer         :: Sfluxu=>null()
   REALTYPE,dimension(:,:,:),pointer         :: Sfluxv=>null()
   REALTYPE,dimension(:,:,:),pointer         :: Sfluxw=>null()

   REALTYPE,dimension(:,:,:),pointer         :: numdis_3d=>null()
   REALTYPE,dimension(:,:,:),pointer         :: phydis_3d=>null()
   REALTYPE, dimension(:,:,:), allocatable   :: numdis_3d_old
   REALTYPE, dimension(:,:), allocatable     :: numdis_int,phydis_int
   REALTYPE,dimension(:,:,:),pointer         :: nummix_S=>null()
   REALTYPE,dimension(:,:,:),pointer         :: nummix_T=>null()
   REALTYPE, dimension(:,:,:), allocatable   :: nummix_S_old,nummix_T_old
   REALTYPE,dimension(:,:,:),pointer         :: phymix_S=>null()
   REALTYPE,dimension(:,:,:),pointer         :: phymix_T=>null()
   REALTYPE, dimension(:,:), allocatable     :: nummix_S_int,nummix_T_int
   REALTYPE, dimension(:,:), allocatable     :: phymix_S_int,phymix_T_int

!  the following fields will only be allocated if deformCX_3d=.true.
   REALTYPE,dimension(:,:,:),allocatable :: dudxC_3d,dvdyC_3d
   REALTYPE,dimension(:,:,:),pointer     :: dudyX_3d=>null()
   REALTYPE,dimension(:,:,:),pointer     :: dvdxX_3d=>null()
   REALTYPE,dimension(:,:,:),allocatable :: shearX_3d

!  the following fields will only be allocated if deformUV_3d=.true.
   REALTYPE,dimension(:,:,:),allocatable :: dudxV_3d,dvdyU_3d,shearU_3d

!  the following fields will only be allocated if calc_stirring=.true.
   REALTYPE,dimension(:,:,:),allocatable :: diffxx,diffxy,diffyx,diffyy

!  the following fields will be allocated in init_nonhydrostatic
   REALTYPE,dimension(:,:,:),allocatable,target :: minus_bnh
   REALTYPE,dimension(:,:,:),allocatable :: wco
   REALTYPE,dimension(:,:,:),allocatable :: uu_0,vv_0

!  the following fields will be allocated in init_internal_pressure
   REALTYPE,dimension(:,:,:),pointer            :: idpdx,idpdy
   REALTYPE,dimension(:,:,:),allocatable,target :: idpdx_hs,idpdy_hs
   REALTYPE,dimension(:,:,:),allocatable,target :: idpdx_nh,idpdy_nh
   REALTYPE,dimension(:,:,:),allocatable,target :: idpdx_full,idpdy_full

#ifdef GETM_BIO
   REALTYPE, allocatable               :: cc3d(:,:,:,:)
   REALTYPE, allocatable               :: ws3d(:,:,:,:)
#endif
#ifdef _FABM_
   REALTYPE, allocatable, dimension(:,:,:,:) :: fabm_pel,fabm_diag
   REALTYPE, allocatable, dimension(:,:,:)   :: fabm_ben,fabm_diag_hz
#endif
   integer                             :: size3d_field
   integer                             :: mem3d
   integer                             :: preadapt
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_variables_3d - initialise 3D related stuff
! \label{sec-init-variables}
!
! !INTERFACE:
   subroutine init_variables_3d(runtype)
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype
!
! !DESCRIPTION:
!  Dynamic allocation of memory for 3D related fields via
!  {\tt dynamic\_allocations\_3d.h} (unless the compiler option
!  {\tt STATIC} is set). Furthermore, most variables are initialised here.
!
! !LOCAL VARIABLES:
   integer                   :: i,j, rc
   integer,parameter         :: rk = kind(_ONE_)
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_variables_3d() # ',Ncall
#endif

   LEVEL2 'init_variables_3d'
   size3d_field=((imax+HALO)-(imin+HALO)+1)*        &
                ((jmax+HALO)-(jmin+HALO)+1)*(kmax+1)
   mem3d=n3d_fields*size3d_field*REAL_SIZE

!  Allocates memory for the public data members - if not static
#ifndef STATIC
#include "dynamic_allocations_3d.h"
#endif

   kmin = 1

   ho = _ZERO_ ; hn = _ZERO_ ; hvel = _ZERO_ ; hun = _ZERO_ ; hvn = _ZERO_
   uu = _ZERO_ ; vv = _ZERO_ ; ww = _ZERO_

   velx3d = -9999.0 ; vely3d = -9999.0 ; w = -9999.0
   velx2dadv = -9999.0 ; vely2dadv = -9999.0
   forall(i=imin-HALO:imax+HALO, j=jmin-HALO:jmax+HALO, az(i,j).ne.0)
      velx3d   (i,j,1:kmax) = _ZERO_
      vely3d   (i,j,1:kmax) = _ZERO_
      w        (i,j,1:kmax) = _ZERO_
      velx2dadv(i,j)        = _ZERO_
      vely2dadv(i,j)        = _ZERO_
   end forall

#ifdef _MOMENTUM_TERMS_
   tdv_u = _ZERO_ ; adv_u = _ZERO_ ; vsd_u = _ZERO_ ; hsd_u = _ZERO_
   cor_u = _ZERO_ ; epg_u = _ZERO_ ; ipg_u = _ZERO_
   tdv_v = _ZERO_ ; adv_v = _ZERO_ ; vsd_v = _ZERO_ ; hsd_v = _ZERO_
   cor_v = _ZERO_ ; epg_v = _ZERO_ ; ipg_v = _ZERO_
#endif
   ssen = _ZERO_ ; ssun = _ZERO_ ; ssvn = _ZERO_
   Dn = _ZERO_ ; Dveln = _ZERO_ ; Dun = _ZERO_ ; Dvn = _ZERO_
   Uadv = _ZERO_ ; Vadv = _ZERO_

   Uadvf     => Uadv ; Vadvf     => Vadv
   UEulerAdv => Uadv ; VEulerAdv => Vadv
   uuf       => uu   ; vvf       => vv
   uuEuler   => uu   ; vvEuler   => vv
   taubmax_3d   => taub


   if (waveforcing_method .ne. NO_WAVES) then

      allocate(UEulerAdv(I2DFIELD),stat=rc)
      if (rc /= 0) stop 'init_3d: Error allocating memory (UEulerAdv)'
      UEulerAdv = _ZERO_
      allocate(VEulerAdv(I2DFIELD),stat=rc)
      if (rc /= 0) stop 'init_3d: Error allocating memory (VEulerAdv)'
      VEulerAdv = _ZERO_

      allocate(uuEuler(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'init_3d: Error allocating memory (uuEuler)'
      allocate(vvEuler(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'init_3d: Error allocating memory (vvEuler)'

      if (waves_method .eq. WAVES_VF) then
         Uadvf => UEulerAdv ; Vadvf => VEulerAdv
         uuf   => uuEuler   ; vvf   => vvEuler
      end if

      if (waves_bbl_method .ne. NO_WBBL) then
         allocate(taubmax_3d(I2DFIELD),stat=rc)
         if (rc /= 0) stop 'init_3d: Error allocating memory (taubmax_3d)'
      end if

   end if


   zub = -9999.0 ; zvb = -9999.0 ! must be initialised for gotm
   if (bottfric_method .eq. 1) then
      rru = rdrag
      rrv = rdrag
   else
      rru = _ZERO_
      rrv = _ZERO_
   end if

   uuEx= _ZERO_ ; vvEx= _ZERO_
   SS=_ZERO_
   tke=1.e-10 ; eps=1.e-10
   preadapt=0

#ifndef NO_BAROCLINIC
   NN=_ZERO_
   rad=_ZERO_
   heatflux_net = _ZERO_
   light=_ONE_
   bioshade = _ONE_
#endif

#ifdef STRUCTURE_FRICTION
   sf = _ZERO_
#endif

#ifdef DEBUG
   write(debug,*) 'Leaving init_variables_3d()'
   write(debug,*)
#endif
   return
   end subroutine init_variables_3d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: postinit_variables_3d - re-initialise some 3D stuff.
!
! !INTERFACE:
   subroutine postinit_variables_3d(update_temp,update_salt)
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   logical, intent(in)                 :: update_temp,update_salt
!
! !DESCRIPTION:
!
! !LOCAL VARIABLES:
   integer                   :: rc
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'postinit_variables_3d() # ',Ncall
#endif

!  must be in postinit because flags are set init_getm_fabm
   if (deformC_3d) then
      allocate(dudxC_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (dudxC_3d)'
      dudxC_3d=_ZERO_
#ifndef SLICE_MODEL
      allocate(dvdyC_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (dvdyC_3d)'
      dvdyC_3d=_ZERO_
#endif
   end if
   if (deformX_3d) then
      allocate(shearX_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (shearX_3d)'
      shearX_3d=_ZERO_

      if (do_numerical_analyses_3d) then
            allocate(dvdxX_3d(I3DFIELD),stat=rc)
            if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (dvdxX_3d)'
            dvdxX_3d=_ZERO_
#ifndef SLICE_MODEL
            allocate(dudyX_3d(I3DFIELD),stat=rc)
            if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (dudyX_3d)'
            dudyX_3d=_ZERO_
#endif
      end if
   end if
   if (deformUV_3d) then
      allocate(dudxV_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (dudxV_3d)'
      dudxV_3d=_ZERO_

#ifndef SLICE_MODEL
      allocate(dvdyU_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (dvdyU_3d)'
      dvdyU_3d=_ZERO_
#endif

      allocate(shearU_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (shearU_3d)'
      shearU_3d=_ZERO_
   end if
   if (calc_stirr) then
      allocate(diffxx(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (diffxx)'
      diffxx=_ZERO_

#ifndef SLICE_MODEL
      allocate(diffxy(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (diffxy)'
      diffxy=_ZERO_

      allocate(diffyx(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (diffyx)'
      diffyx=_ZERO_

      allocate(diffyy(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_variables_3d: Error allocating memory (diffyy)'
      diffyy=_ZERO_
#endif
   end if

   if (save_Sfluxu) then
      allocate(Sfluxu(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (Sfluxu)'
      Sfluxu = _ZERO_
   end if
   if (save_Sfluxv) then
      allocate(Sfluxv(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (Sfluxv)'
      Sfluxv = _ZERO_
   end if
   if (save_Sfluxw) then
      allocate(Sfluxw(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (Sfluxw)'
      Sfluxw = _ZERO_
   end if

!  must be in postinit because do_numerical_analyses is set in init_output
   if (do_numerical_analyses_3d) then

      allocate(phydis_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (phydis_3d)'
      phydis_3d = _ZERO_
      allocate(phydis_int(I2DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (phydis_int)'
      phydis_int = _ZERO_
      allocate(numdis_3d(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (numdis_3d)'
      numdis_3d = _ZERO_
#ifdef _NUMERICAL_ANALYSES_OLD_
      allocate(numdis_3d_old(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (numdis_3d_old)'
      numdis_3d_old = _ZERO_
      allocate(numdis_int(I2DFIELD),stat=rc)
      if (rc /= 0) stop 'postinit_3d: Error allocating memory (numdis_int)'
      numdis_int = _ZERO_
#endif

      if (update_temp) then
         allocate(phymix_T(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (phymix_T)'
         phymix_T = _ZERO_
         allocate(phymix_T_int(I2DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (phymix_T_int)'
         phymix_T_int = _ZERO_
         allocate(nummix_T(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (nummix_T)'
         nummix_T = _ZERO_
#ifdef _NUMERICAL_ANALYSES_OLD_
         allocate(nummix_T_old(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (nummix_T_old)'
         nummix_T_old = _ZERO_
         allocate(nummix_T_int(I2DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (nummix_T_int)'
         nummix_T_int = _ZERO_
#endif
      end if

      if (update_salt) then
         allocate(phymix_S(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (phymix_S)'
         phymix_S = _ZERO_
         allocate(phymix_S_int(I2DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (phymix_S_int)'
         phymix_S_int = _ZERO_
         allocate(nummix_S(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (nummix_S)'
         nummix_S = _ZERO_
#ifdef _NUMERICAL_ANALYSES_OLD_
         allocate(nummix_S_old(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (nummix_S_old)'
         nummix_S_old = _ZERO_
         allocate(nummix_S_int(I2DFIELD),stat=rc)
         if (rc /= 0) stop 'postinit_3d: Error allocating memory (nummix_S_int)'
         nummix_S_int = _ZERO_
#endif
      end if

   end if


#ifdef DEBUG
   write(debug,*) 'Leaving postinit_variables_3d()'
   write(debug,*)
#endif
   return
   end subroutine postinit_variables_3d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: clean_variables_3d - cleanup after 3D run.
!
! !INTERFACE:
   subroutine clean_variables_3d()
   IMPLICIT NONE
!
! !DESCRIPTION:
!  This routine cleans up after a 3D integrationby doing nothing so far.
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'clean_3d() # ',Ncall
#endif

! Deallocates memory for the public data members

#ifdef DEBUG
     write(debug,*) 'Leaving clean_variables_3d()'
     write(debug,*)
#endif
   return
   end subroutine clean_variables_3d
!EOC

!-----------------------------------------------------------------------

   end module variables_3d

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
