#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  adv_split_u - zonal advection of 2D quantities \label{sec-u-split-adv}
!
! !INTERFACE:
   subroutine adv_split_u(dt,f,fi,Di,adv,U,DU,   &
                          dxu,dyu,arcd1,         &
                          splitfac,scheme,AH,    &
                          mask_flux,mask_update, &
                          ffluxu,nvd)
!  Note (KK): Keep in sync with interface in advection.F90
!
! !DESCRIPTION:
!
! Executes an advection step in zonal direction for a 2D quantity. The
! 1D advection equation
!
! \begin{equation}\label{adv_u_step}
! D^n_{i,j} c^n_{i,j} =
! D^o_{i,j} c^o_{i,j}
! \displaystyle
! - \Delta t
! \frac{
! U_{i,j}\tilde c^u_{i,j}\Delta y^u_{i,j}-
! U_{i-1,j}\tilde c^u_{i-1,j}\Delta y^u_{i-1,j}
! }{\Delta x^c_{i,j}\Delta y^c_{i,j}},
! \end{equation}
!
! is accompanied by an fractional step for the 1D continuity equation
!
! \begin{equation}\label{adv_u_step_D}
! D^n_{i,j} =
! D^o_{i,j}
! \displaystyle
! - \Delta t
! \frac{
! U_{i,j}\Delta y^u_{i,j}-
! U_{i-1,j}\Delta y^u_{i-1,j}
! }{\Delta x^c_{i,j}\Delta y^c_{i,j}}.
! \end{equation}
!
! Here, $n$ and $o$ denote values before and after this operation,
! respectively, $n$ denote intermediate values when other
! 1D advection steps come after this and $o$ denotes intermediate
! values when other 1D advection steps came before this.
! Furthermore, when this $u$-directional split step is repeated
! during the total time step (Strang splitting), the time step $\Delta t$
! denotes a fraction of the full time step.
!
! The interfacial fluxes $\tilde c^u_{i,j}$ are calculated according to
! the third-order polynomial scheme (so-called P$_2$ scheme), cast in
! Lax-Wendroff form by:
!
! \begin{equation}\label{LaxWendroffForm}
! \tilde c_{i,j}=
! \left\{
! \begin{array}{ll}
! \left(c_{i,j}+\frac12 \tilde c_{i,j}^+ (1-|C_{i,j}|)
! (c_{i+1,j}-c_{i,j})\right) & \mbox{ for } U_{i,j} \geq 0, \\ \\
! \left(c_{i+1,j}+\frac12 \tilde c_{i,j}^- (1-|C_{i,j}|)
! (c_{i,j}-c_{i+1,j})\right) & \mbox{ else, }
! \end{array}
! \right.
! \end{equation}
!
! with the Courant number $C_{i,j}=u_{i,j}\Delta t/\Delta x$ and
!
! \begin{equation}\label{alphabeta}
! \tilde c_{i,j}^+=\alpha_{i,j}+\beta_{i,j}r^+_{i,j}, \quad
! \tilde c_{i,j}^-=\alpha_{i,j}+\beta_{i,j}r^-_{i,j},
! \end{equation}
!
! where
!
! \begin{equation}
! \alpha_{i,j}=\frac12 +\frac16(1-2|C_{i,j}|),\quad
! \beta _{i,j}=\frac12 -\frac16(1-2|C_{i,j}|),
! \end{equation}
!
! and
!
! \begin{equation}
! r^+_{i,j}=\frac{c_{i,j}-c_{i-1,j}}{c_{i+1,j}-c_{i,j}},
! \quad
! r^-_{i,j}=\frac{c_{i+2,j}-c_{i+1,j}}{c_{i+1,j}-c_{i,j}}.
! \end{equation}
!
! It should be noted, that for $\tilde c_{i,j}^+=\tilde c_{i,j}^-=1$
! the original Lax-Wendroff scheme and for
! $\tilde c_{i,j}^+=\tilde c_{i,j}^-=0$ the first-oder upstream scheme
! can be recovered.
!
! In order to obtain a monotonic and positive scheme, the factors
! $\tilde c_{i,j}^+$ are limited in the following way:
!
! \begin{equation}\label{PDM}
! \tilde c_{i,j}^+ \rightarrow \max \left[
! 0,\min\left(\tilde c_{i,j}^+,\frac{2}{1-|C_{i,j}|},
! \frac{2r^+_{i,j}}{|C_{i,j}|}\right)
! \right],
! \end{equation}
!
! and, equivalently, for $\tilde c_{i,j}^-$.
! This so-called PDM-limiter has been described in detail
! by \cite{LEONARD91}, who named the PDM-limited P$_2$ scheme
! also ULTIMATE QUICKEST (quadratic upstream interpolation
! for convective kinematics with estimated stream terms).
!
! Some simpler limiters which do not exploit the third-order
! polynomial properties of the discretisation (\ref{LaxWendroffForm}) have been
! listed by \cite{ZALEZAK87}. Among those are the MUSCL scheme by
! \cite{VANLEER79},
!
! \begin{equation}\label{MUSCL}
! \tilde c_{i,j}^+ \rightarrow \max \left[
! 0,\min\left(
! 2,2r^+_{i,j},\frac{1+r^+_{i,j}}{2}
! \right)
! \right],
! \end{equation}
!
! and the Superbee scheme by \cite{ROE85},
!
! \begin{equation}\label{Superbee}
! \tilde c_{i,j}^+ \rightarrow \max \left[
! 0,\min(1,2r^+_{i,j}),\min(r^+_{i,j},2)
! \right].
! \end{equation}
!
! The selector for the schemes is {\tt scheme}:
!
! \vspace{0.5cm}
!
! \begin{tabular}{ll}
! {\tt scheme = UPSTREAM}: & first-order upstream (monotone) \\
! {\tt scheme = P2}: & third-order polynomial (non-monotone) \\
! {\tt scheme = SUPERBEE}: & second-order TVD (monotone) \\
! {\tt scheme = MUSCL}: & second-order TVD (monotone) \\
! {\tt scheme = P2\_PDM}: & third-order ULTIMATE-QUICKEST (monotone) \\
! \end{tabular}
!
! \vspace{0.5cm}
!
! Furthermore, the horizontal diffusion in zonal direction
! with the constant diffusion
! coefficient {\tt AH} is carried out here by means of a central difference
! second-order scheme.
!
! !USES:
   use domain, only: imin,imax,jmin,jmax
   use advection, only: adv_interfacial_reconstruction
   use advection, only: UPSTREAM
!$ use omp_lib
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
#define _U2DFIELD_ _IRANGE_HALO_-1,_JRANGE_HALO_
!  Note (KK): in general dxu, dyu and mask_flux do only have valid data
!             within (_IRANGE_HALO_-1,_JRANGE_HALO_). In some cases the
!             original field extension may even be _IRANGE_HALO_. Then
!             explicit declared array bounds _IRANGE_HALO_-1 require a
!             provision of the corresponding subarray and will cause
!             copying of the non-contiguously data into a temporarily
!             array. Therefore they are declared as pointers here. This
!             however requires, that the provided pointers already carry
!             the correct bounds.
   REALTYPE,intent(in)                           :: dt,splitfac,AH
   REALTYPE,dimension(E2DFIELD),intent(in)       :: f,U,DU
   REALTYPE,dimension(:,:),pointer,intent(in)    :: dxu,dyu
   REALTYPE,dimension(E2DFIELD),intent(in)       :: arcd1
   integer,intent(in)                            :: scheme
   logical,dimension(:,:),pointer,intent(in)     :: mask_flux
   logical,dimension(E2DFIELD),intent(in)        :: mask_update
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE,dimension(E2DFIELD),intent(inout)    :: fi,Di,adv
   REALTYPE,dimension(:,:),pointer,intent(inout) :: ffluxu
   REALTYPE,dimension(:,:),pointer,intent(inout) :: nvd
!
! !LOCAL VARIABLES:
   REALTYPE,dimension(E2DFIELD) :: uflux,uflux2
   logical            :: use_AH,calc_nvd
   integer            :: i,j
   REALTYPE           :: dti,fio,Dio,advn,adv2n,cfl,fuu,fu,fd
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Karsten Bolding
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'adv_split_u() # ',Ncall
#endif
#ifdef SLICE_MODEL
   j = jmax/2 ! this MUST NOT be changed!!!
#endif

   use_AH = (AH .gt. _ZERO_)
   calc_nvd = associated(nvd)
   dti = splitfac*dt

!$OMP PARALLEL DEFAULT(SHARED)                                         &
!$OMP          FIRSTPRIVATE(j)                                         &
!$OMP          PRIVATE(i,fio,Dio,advn,adv2n,cfl,fuu,fu,fd)

! Calculating u-interface fluxes !
!$OMP DO SCHEDULE(RUNTIME)
#ifndef SLICE_MODEL
   do j=jmin-HALO,jmax+HALO
#endif
      do i=imin-HALO+1,imax+HALO-2
         if (mask_flux(i,j)) then
!           Note (KK): exclude x-advection of u across W/E open bdys
            if (U(i,j) .gt. _ZERO_) then
               cfl = U(i,j)/DU(i,j)*dti/DXU
               fu = f(i  ,j)               ! central
               if (mask_flux(i-1,j)) then
                  fuu = f(i-1,j)            ! upstream
               else
                  fuu = fu
               end if
               fd = f(i+1,j)            ! downstream
            else
               cfl = -U(i,j)/DU(i,j)*dti/DXU
               fu = f(i+1,j)               ! central
               if (mask_flux(i+1,j)) then
                  fuu = f(i+2,j)            ! upstream
               else
                  fuu = fu
               end if
               fd = f(i  ,j)            ! downstream
            end if
            fu = adv_interfacial_reconstruction(scheme,cfl,fuu,fu,fd)
            uflux (i,j) = U(i,j)*fu
            uflux2(i,j) = uflux(i,j)*fu
            if (use_AH) then
!              Horizontal diffusion
               uflux(i,j) = uflux(i,j) - AH*DU(i,j)*(f(i+1,j)-f(i  ,j))/DXU
            end if
         else
            uflux (i,j) = _ZERO_
            uflux2(i,j) = _ZERO_
         end if
      end do
#ifndef SLICE_MODEL
   end do
#endif
!$OMP END DO
!$OMP WORKSHARE
   if (associated(ffluxu)) then
      ffluxu(_U2DFIELD_) = ffluxu(_U2DFIELD_) + splitfac*dyu(_U2DFIELD_)*uflux(_U2DFIELD_)
   end if
!$OMP END WORKSHARE
!$OMP DO SCHEDULE(RUNTIME)
#ifndef SLICE_MODEL
   do j=jmin-HALO,jmax+HALO
#endif
      do i=imin-HALO+2,imax+HALO-2
         if (mask_update(i,j)) then
!           Note (KK): exclude x-advection of tracer and u across W/E open bdys
            fio = fi(i,j)
            Dio = Di(i,j)
            Di(i,j) =  Dio - dti*( U(i  ,j)*DYU           &
                                  -U(i-1,j)*DYUIM1)*ARCD1
            advn = splitfac*( uflux(i  ,j)*DYU           &
                             -uflux(i-1,j)*DYUIM1)*ARCD1
            fi(i,j) = ( Dio*fio - dt*advn ) / Di(i,j)
            adv(i,j) = adv(i,j) + advn
            if (calc_nvd) then
               adv2n = splitfac*( uflux2(i  ,j)*DYU           &
                                 -uflux2(i-1,j)*DYUIM1)*ARCD1
!               nvd(i,j) = nvd(i,j)                                       &
!                         -((Di(i,j)*fi(i,j)**2 - Dio*fio**2)/dt + adv2n)
               nvd(i,j) = ( Dio*nvd(i,j)                                   &
                           -((Di(i,j)*fi(i,j)**2 - Dio*fio**2)/dt + adv2n) &
                          )/Di(i,j)
            end if
         end if
      end do
#ifndef SLICE_MODEL
   end do
#endif
!$OMP END DO

!$OMP END PARALLEL

#ifdef DEBUG
   write(debug,*) 'Leaving adv_split_u()'
   write(debug,*)
#endif
   return
   end subroutine adv_split_u
!EOC
!-----------------------------------------------------------------------
! Copyright (C) 2004 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------
