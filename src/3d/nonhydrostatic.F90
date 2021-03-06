!$Id: nonhydrostatic.F90,v 1.9 2007-06-07 10:25:19 kbk Exp $
#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: nonhydrostatic
!
! !INTERFACE:
   module nonhydrostatic

! !DESCRIPTION:
!
! An alternative approach was chosen to test the inclusion of nonhydrostatic
! dynamics into GETM. It requires only minimal modifications to the existing
! hydrostatic kernel and the implementation of complicated numerical algorithms
! (e.\,g.\ parallelised Poisson solver as needed for the projection approach)
! is not necessary. Furthermore it might be more efficient for weak
! nonhydrostatic flow regimes.
!
! The terms of the vertical balance of momentum, neglected if the hydrostatic
! pressure assumption is applied, may be summarised as a new quantity:
!
! \bigskip{}
!
!
! \begin{equation}
! b_{\mathrm{nh}}:=\partial_{t}w+\nabla\cdot\left\{ \underline{u}w\right\} -\nabla_{\mathrm{H}}\cdot\left\{ A\nabla_{\mathrm{H}}w\right\} -\partial_{z}\left\{ \left(\nu+\nu_{\mathrm{t}}\right)\partial_{z}w\right\} .\label{eq:bnh}\end{equation}
!
!
! \bigskip{}
!
!
! The vertical integration of~$b_{\mathrm{nh}}$ yields the nonhydrostatic
! pressure contribution. However, the individual integration of~$b_{\mathrm{nh}}$
! and the subsequent evaluation of the horizontal gradient (needed for the
! horizontal balance of momentum) could be omitted. Since these operations are
! already implemented for the buoyancy, they would be redundant and would
! wastefully increase the computational (and~implementational) effort. Instead,
! the buoyancy could be corrected by~$b_{\mathrm{nh}}$ (therefore this quantity
! may be called \textit{nonhydrostatic buoyancy correction}):
!
! \bigskip{}
!
!
! \begin{equation}
! b_{\mathrm{c}}:=b-b_{\mathrm{nh}}.\label{eq:bc}\end{equation}
!
!
! \bigskip{}
!
!
! If the buoyancy in the horizontal balance of momentum is replaced by the
! corrected buoyancy~\eqref{eq:bc}, the nonhydrostatic pressure contribution
! is included into the already existing infrastructure in a consistent way.
!
! The quantification of the nonhydrostatic pressure contribution naturally
! incorporates a Dirichlet condition for the nonhydrostatic pressure
! contribution at the free surface. Since the alternative approach avoids an
! elliptic equation, no additional (or even artificial) BC is necessary.
!
! The calculation of the nonhydrostatic pressure contribution requires the
! information of the internal flow field, updated only at internal time stages.
! Thus, in an explicit mode-splitting model the nonhydrostatic pressure
! contribution cannot be updated during the depth-averaged integrations, and
! its coupling to the surface elevation is only possible by a corresponding
! interaction term. Within the alternative approach the nonhydrostatic pressure
! contribution can easily be incorporated into the depth-averaged equations, if
! the interaction term~$\underline{S}_{\mathrm{B}}$ is calculated in terms of
! the corrected buoyancy~\eqref{eq:bc}. Again no additional implementational
! and redundant computational effort is necessary. Since the final horizontal
! velocity is shifted to coincide with the mean depth-averaged one, the surface
! elevation does not need to be corrected.
!
! Additional nonhydrostatic computations are switched on depending on the namelist
! parameter \texttt{nonhyd_method} and require the compilation with
! {}``\texttt{export GETM\_NONHYD=true}''. Nonhydrostatic effects can either be
! disabled, passively screened or actively included during runtime.
!
! It must be stressed that the nonhydrostatic capability of GETM is still in
! test mode and users should really know what they are doing when using it!
!
! !USES:
   use exceptions
   use domain, only: imin,imax,jmin,jmax,kmax,az,H,HU,HV
   use domain, only: dxv,dyu,arcd1
   use variables_3d, only: kmin
   use variables_3d, only: minus_bnh,wco,w
   use variables_3d, only: uu_0,vv_0
   use variables_3d, only: dt,uu,vv,ww,ho,hn,hvel,hun,hvn,num
   use parameters, only: avmmol
   use m2d, only: no_2d
#ifndef NO_ADVECT
   use advection, only: NOSPLIT,CENTRAL
   use advection_3d, only: do_advection_3d
#endif
   use halo_zones, only: update_3d_halo,wait_halo,H_TAG
!$ use omp_lib
   IMPLICIT NONE
   private
!
! !PUBLIC DATA MEMBERS:
   public init_nonhydrostatic, do_nonhydrostatic

   integer,public  :: nonhyd_method=0
   logical,public  :: calc_hs2d=.true.
   integer,public  :: nonhyd_iters=1
   integer,public  :: bnh_filter=0
   REALTYPE,public :: bnh_weight=_ONE_
   logical,public  :: sbnh_filter=.false.
!
! !PRIVATE DATA MEMBERS:
   REALTYPE        :: dtm1
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Knut Klingbeil
!
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: init_nonhydrostatic
!
! !INTERFACE:
   subroutine init_nonhydrostatic()
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE

! !INPUT PARAMETERS:
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !LOCAL VARIABLES:
   integer                     :: rc
   namelist /nonhyd/ &
            calc_hs2d,nonhyd_iters,bnh_filter,bnh_weight,sbnh_filter
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_nonhydrostatic() # ',Ncall
#endif

   LEVEL2 'init_nonhydrostatic()'
   select case(nonhyd_method)
      case (0)
         LEVEL3 'disabled nonhydrostatic computations'
      case (-1)
         LEVEL3 'passive screening of nonhydrostatic effects'
      case (1)
         calc_hs2d = .false.
         read(NAMLST,nonhyd)
         if (nonhyd_iters .le. 0) nonhyd_iters=1
         LEVEL3 'number of iterations = ',nonhyd_iters
         select case(bnh_filter)
            case(0)
               LEVEL3 'do not filter bnh'
            case(1)
               LEVEL3 'one-stage FIR-filter'
               LEVEL4 'weight = ',real(bnh_weight)
            case(3)
               LEVEL3 'one-stage AR-IIR-filter (accumulative average)'
               LEVEL4 'weight = ',real(bnh_weight)
               if (_ZERO_ .lt. bnh_weight .and. bnh_weight .lt. _ONE_) then
                  LEVEL4 'eff. 99% nh timestep = ',&
                     real(ceiling(log(_ONE_-0.99d0)/log(_ONE_-bnh_weight)/real(nonhyd_iters,kind=REAL_SIZE))*dt)
                  LEVEL4 'eff. 67% nh timestep = ',&
                     real(ceiling(log(_ONE_-0.67d0)/log(_ONE_-bnh_weight)/real(nonhyd_iters,kind=REAL_SIZE))*dt)
                  LEVEL4 'eff. 50% nh timestep = ',&
                     real(ceiling(log(_ONE_-_HALF_)/log(_ONE_-bnh_weight)/real(nonhyd_iters,kind=REAL_SIZE))*dt)
               end if
            case(4)
               LEVEL3 'moving average over iterative stages'
            case(5)
               LEVEL3 'ramping filter over iterative stages'
               bnh_weight = _ONE_/real(nonhyd_iters,kind=REAL_SIZE)
            case default
               call getm_error("init_nonhydrostatic()", &
                               "no valid bnh_filter specified")
         end select
         if (.not. no_2d) then
            if (calc_hs2d) then
               LEVEL3 'exclude nh pressure gradient from slow terms'
            else if (sbnh_filter) then
               LEVEL3 'apply spatial filter to nh slow terms'
            end if
         end if
      case default
         call getm_error("init_nonhydrostatic()", &
                         "no valid nonhyd_method specified")
   end select

   if (nonhyd_method .ne. 0) then

      allocate(wco(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'init_nonhydrostatic: Error allocating memory (wco)'
      wco = _ZERO_

      allocate(minus_bnh(I3DFIELD),stat=rc)
      if (rc /= 0) stop 'init_nonhydrostatic: Error allocating memory (minus_bnh)'
      minus_bnh = _ZERO_

      if (nonhyd_iters .gt. 1) then
         allocate(uu_0(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'init_nonhydrostatic: Error allocating memory (uu_0)'
         allocate(vv_0(I3DFIELD),stat=rc)
         if (rc /= 0) stop 'init_nonhydrostatic: Error allocating memory (vv_0)'
      end if

      dtm1=_ONE_/dt
   end if

#ifdef DEBUG
   write(debug,*) 'Leaving init_nonhydrostatic()'
   write(debug,*)
#endif
   return
   end subroutine init_nonhydrostatic
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: do_nonhydrostatic
!
! !INTERFACE:
   subroutine do_nonhydrostatic(nonhyd_loop,vel3d_adv_split,vel3d_adv_hor,vel3d_adv_ver)
!
! !DESCRIPTION:
!
! !USES:
   use getm_timers, only: tic,toc,TIM_NONHYD
   IMPLICIT NONE

!
! !INPUT PARAMETERS:
   integer,intent(in)           :: nonhyd_loop,vel3d_adv_split,vel3d_adv_hor,vel3d_adv_ver
!
! !LOCAL VARIABLES:
   REALTYPE,dimension(I3DFIELD) :: wc,bnh
   integer                      :: i,j,k
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_nonhydrostatic() # ',Ncall
#endif
#ifdef SLICE_MODEL
   j = jmax/2 ! this MUST NOT be changed!!!
#endif
   call tic(TIM_NONHYD)

!  calculate w
   call to_w(imin,jmin,imax,jmax,kmin,kmax,az,dt,           &
             dxv,dyu,arcd1,                                 &
             H,HU,HV,hn,ho,hvel,uu,hun,vv,hvn,ww,_ZERO_,w)

   call update_3d_halo(w,w,az,imin,jmin,imax,jmax,kmax,H_TAG)
   call wait_halo(H_TAG)

!  initialise bnh by advective term
#ifndef NO_ADVECT
   wc = w
   call do_advection_3d(dt,wc,uu,vv,ww,hun,hvn,hvel,hvel,             &
                        NOSPLIT,CENTRAL,CENTRAL,_ZERO_,H_TAG,          &
                        advres=bnh)
   call update_3d_halo(bnh,bnh,az,imin,jmin,imax,jmax,kmax,H_TAG)
   call wait_halo(H_TAG)
#else
   bnh = _ZERO_
#endif

!$OMP PARALLEL DEFAULT(SHARED)                                         &
!$OMP          FIRSTPRIVATE(j)                                         &
!$OMP          PRIVATE(i,k)
!$OMP DO SCHEDULE(RUNTIME)
#ifndef SLICE_MODEL
   do j=jmin-HALO,jmax+HALO
#endif
      do i=imin-HALO,imax+HALO
         if ( az(i,j) .ge. 1 ) then

!           add vertical viscous terms
!           KK-TODO: do we really have to add num?
            bnh(i,j,1) = bnh(i,j,1)                         &
               - (num(i,j,1) + avmmol)                      &
                 * (             w(i,j,2) -    w(i,j,1)   ) &
                 / ( _HALF_*( hvel(i,j,1) + hvel(i,j,2) ) )
            do k=2,kmax-1
               bnh(i,j,k) = bnh(i,j,k)                                   &
                  - (                                                    &
                        (num(i,j,k) + avmmol)                            &
                        * (               w(i,j,k+1) -    w(i,j,k  )   ) &
                        / ( _HALF_ * ( hvel(i,j,k  ) + hvel(i,j,k+1) ) ) &
                      - (num(i,j,k-1) + avmmol)                          &
                        * (               w(i,j,k  ) -    w(i,j,k-1)   ) &
                        / ( _HALF_ * ( hvel(i,j,k-1) + hvel(i,j,k  ) ) ) &
                     )
            end do
            bnh(i,j,kmax) = bnh(i,j,kmax)                               &
               - (num(i,j,kmax-1) + avmmol)                             &
                 * (               w(i,j,kmax  ) -    w(i,j,kmax-1)   ) &
                 / ( _HALF_ * ( hvel(i,j,kmax-1) + hvel(i,j,kmax  ) ) )

!           add local vertical acceleration and divide by layer height
!           Note (KK): note units of wc now !!!
            wc(i,j,1:kmax) = hvel(i,j,1:kmax)*w(i,j,1:kmax)
            bnh(i,j,1:kmax) = (                                          &
                                 bnh(i,j,1:kmax)                         &
                               + (wc(i,j,1:kmax) - wco(i,j,1:kmax))*dtm1 &
                              )/hvel(i,j,1:kmax)

         end if
      end do
#ifndef SLICE_MODEL
   end do
#endif
!$OMP END DO
!$OMP END PARALLEL

#ifdef SLICE_MODEL
   bnh(:,j+1,:) = bnh(:,j,:)
#endif

!  filter bnh (result to minus_bnh)
   select case(bnh_filter)
      case (1)
         minus_bnh = -bnh_weight*bnh
      case (3)
         minus_bnh = -bnh_weight*bnh + (_ONE_- bnh_weight)*minus_bnh
      case (4)
         if (nonhyd_loop .eq. 1) then
            minus_bnh = _ZERO_
         end if
         bnh_weight = _ONE_/real(nonhyd_loop,kind=REAL_SIZE)
         minus_bnh = -bnh_weight*bnh + (_ONE_- bnh_weight)*minus_bnh ! gives 100% weight for first loop
      case (5)
         if (nonhyd_loop .eq. 1) then
            minus_bnh = _ZERO_
         end if
         minus_bnh = -bnh_weight*bnh + minus_bnh  ! not usable when iteration is prematurely abrupted
      case default
         minus_bnh = -bnh
   end select
!  bnh now free

!  break iteration
   !nonhyd_loop = nonhyd_iters

!  update wco
   if ( nonhyd_loop .eq. nonhyd_iters ) then
      wco = wc
   end if

   call toc(TIM_NONHYD)
#ifdef DEBUG
   write(debug,*) 'Leaving do_nonhydrostatic()'
   write(debug,*)
#endif
   return
   end subroutine do_nonhydrostatic
!EOC
!-----------------------------------------------------------------------

   end module nonhydrostatic

!-----------------------------------------------------------------------
! Copyright (C) 2011 - Knut Klingbeil                                  !
!-----------------------------------------------------------------------
