#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
! !IROUTINE:  adv_split_w - vertical advection of 3D quantities \label{sec-w-split-adv}
!
! !INTERFACE:
   subroutine adv_split_w(dt,f,fi,hi,adv,ww,      &
                          splitfac,scheme,tag,az, &
                          itersmax,ffluxw,nvd)
!  Note (KK): Keep in sync with interface in advection_3d.F90
!
! !DESCRIPTION:
!
! Executes an advection step in vertical direction. The 1D advection
! equation
!
! \begin{equation}\label{adv_w_step}
! h^n_{i,j,k} c^n_{i,j,k} =
! h^o_{i,j,k} c^o_{i,j,k}
! - \Delta t
! \left(w_{i,j,k}\tilde c^w_{i,j,k}-w_{i,j,k-1}\tilde c^w_{i,j,k-1}\right),
! \end{equation}
!
! is accompanied by an fractional step for the 1D continuity equation
!
! \begin{equation}\label{adv_w_step_h}
! h^n_{i,j,k}  =
! h^o_{i,j,k}
! - \Delta t
! \left(w_{i,j,k}\tilde -w_{i,j,k-1}\right).
! \end{equation}
!
! Here, $n$ and $o$ denote values before and after this operation,
! respectively, $n$ denote intermediate values when other
! 1D advection steps come after this and $o$ denotes intermediate
! values when other 1D advection steps came before this.
!
! The interfacial fluxes $\tilde c^w_{i,j,k}$ are calculated by means of
! monotone and non-monotone schemes which are described in detail in
! section \ref{sec-u-split-adv} on page \pageref{sec-u-split-adv}.
!
! !USES:
   use domain, only: imin,imax,jmin,jmax,kmax
   use advection, only: adv_interfacial_reconstruction
   use advection, only: NOADV
   use advection_3d, only: W_TAG
   use halo_zones, only: U_TAG,V_TAG
!$ use omp_lib
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,intent(in)                               :: dt,splitfac
   REALTYPE,dimension(I3DFIELD),intent(in),target    :: f
   REALTYPE,dimension(I3DFIELD),intent(in)           :: ww
   integer,intent(in)                                :: scheme,tag,itersmax
   integer,dimension(E2DFIELD),intent(in)            :: az
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE,dimension(I3DFIELD),target,intent(inout) :: fi,hi,adv
   REALTYPE,dimension(:,:,:),pointer,intent(inout)   :: ffluxw
   REALTYPE,dimension(:,:,:),pointer,intent(inout)   :: nvd
!
! !LOCAL VARIABLES:
   logical            :: calc_ffluxw,calc_nvd
   integer            :: i,j,k,kshift,it,iters,iters_new,rc
   REALTYPE           :: cfl,itersm1,dti,dtik,fio,hio,advn,adv2n,fuu,fu,fd,splitfack
   REALTYPE,dimension(:),allocatable        :: wflux,wflux2
   REALTYPE,dimension(:),allocatable,target :: cfl0
   REALTYPE,dimension(:),pointer            :: fo,faux,fiaux,hiaux,advaux,ffluxwaux,nvdaux,cfls
   REALTYPE,dimension(:),pointer            :: p_fiaux,p_hiaux,p_advaux,p_ffluxwaux,p_nvdaux
   REALTYPE,dimension(:),pointer            :: p1d
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Karsten Bolding
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'adv_split_w() # ',Ncall
#endif
#ifdef SLICE_MODEL
   j = jmax/2 ! this MUST NOT be changed!!!
#endif

   if (tag .eq. W_TAG) then
      kshift = 1
   else
      kshift = 0
   end if

   calc_ffluxw = associated(ffluxw)
   calc_nvd    = associated(nvd)
   dti = splitfac*dt

#ifdef NO_BAROTROPIC
   if (itersmax .le. 1) then
      stop 'adv_split_w: do enable iterations with compiler option NO_BAROTROPIC'
   end if
#endif

!$OMP PARALLEL DEFAULT(SHARED)                                         &
!$OMP          FIRSTPRIVATE(j)                                         &
!$OMP          PRIVATE(rc,wflux,wflux2,cfl0,cfls)                      &
!$OMP          PRIVATE(fo,faux,fiaux,hiaux,advaux,ffluxwaux,nvdaux)    &
!$OMP          PRIVATE(p_fiaux,p_hiaux,p_advaux,p_ffluxwaux,p_nvdaux)  &
!$OMP          PRIVATE(cfl,itersm1,dtik,splitfack)                     &
!$OMP          PRIVATE(i,k,it,iters,iters_new,fio,hio,advn,adv2n,fuu,fu,fd)


   if (scheme .ne. NOADV) then

!     Each thread allocates its own HEAP storage:
      allocate(wflux(0:kmax),stat=rc)    ! work array
      if (rc /= 0) stop 'adv_split_w: Error allocating memory (wflux)'
      wflux(0   ) = _ZERO_
      wflux(kmax) = _ZERO_

#ifndef _POINTER_REMAP_
      allocate(fo(0:kmax),stat=rc)    ! work array
      if (rc /= 0) stop 'adv_split_w: Error allocating memory (fo)'
#endif

      allocate(fiaux(0:kmax),stat=rc)    ! work array
      if (rc /= 0) stop 'adv_split_w: Error allocating memory (fiaux)'

      allocate(hiaux(0:kmax),stat=rc)    ! work array
      if (rc /= 0) stop 'adv_split_w: Error allocating memory (hiaux)'

      allocate(advaux(0:kmax),stat=rc)    ! work array
      if (rc /= 0) stop 'adv_split_w: Error allocating memory (advaux)'

      allocate(cfl0(0:kmax),stat=rc)    ! work array
      if (rc /= 0) stop 'adv_split_w: Error allocating memory (cfl0)'

      allocate(cfls(0:kmax),stat=rc)    ! work array
      if (rc /= 0) stop 'adv_split_w: Error allocating memory (cfls)'

      if (calc_ffluxw) then
         allocate(ffluxwaux(0:kmax),stat=rc)    ! work array
         if (rc /= 0) stop 'adv_split_w: Error allocating memory (ffluxwaux)'
      end if

      if (calc_nvd) then
         allocate(wflux2(0:kmax),stat=rc)    ! work array
         if (rc /= 0) stop 'adv_split_w: Error allocating memory (wflux2)'
         wflux2(0   ) = _ZERO_
         wflux2(kmax) = _ZERO_

         allocate(nvdaux(0:kmax),stat=rc)    ! work array
         if (rc /= 0) stop 'adv_split_w: Error allocating memory (nvdaux)'
      end if

!     Note (KK): as long as h[u|v]n([i|j]max+HALO) are trash (SMALL)
!                they have to be excluded from the loop to avoid
!                unnecessary iterations and warnings

!$OMP DO SCHEDULE(RUNTIME)
#ifndef SLICE_MODEL
      do j=jmin-HALO,jmax+HALO-1
#endif
         do i=imin-HALO,imax+HALO-1
            if (az(i,j) .eq. 1) then
!              Note (KK): exclude vertical advection of normal velocity at open bdys

               do k=1-kshift,kmax-1
                  cfl0(k) = abs(ww(i,j,k))*dti/(_HALF_*(hi(i,j,k)+hi(i,j,k+1)))
               end do

               iters = 1
               itersm1 = _ONE_
               dtik = dti
               splitfack = splitfac

#ifndef _POINTER_REMAP_
               fo = f(i,j,:)
#endif

               p_fiaux     => fiaux
               p_hiaux     => hiaux
               p_advaux    => advaux
               p_ffluxwaux => ffluxwaux
               p_nvdaux    => nvdaux

               it = 1

               do while (it .le. iters)

                  if (it .eq. 1) then
                     fiaux  = fi (i,j,:)
                     hiaux  = hi (i,j,:)
                     advaux = adv(i,j,:)
                     if (calc_ffluxw) ffluxwaux = ffluxw(i,j,:)
                     if (calc_nvd)    nvdaux    = nvd   (i,j,:)
#ifdef _POINTER_REMAP_
                     p1d => f(i,j,:) ; faux(0:) => p1d
#else
                     faux => fo
#endif
                     cfls = cfl0
                  else
                     do k=1-kshift,kmax-1
                        cfls(k) = abs(ww(i,j,k))*dti/(_HALF_*(hiaux(k)+hiaux(k+1)))
                     end do
                  end if

                  if (iters .lt. itersmax) then
!                    estimate number of iterations by maximum cfl number in water column
                     cfl = maxval(cfls(1-kshift:kmax-1))
                     iters_new = max(1,ceiling(cfl))
                     if (iters_new .gt. iters) then
                        if (iters_new .gt. itersmax) then
!$OMP CRITICAL
                           STDERR 'adv_split_w: too many iterations needed at'
                           STDERR 'i=',i,' j=',j,':',iters_new
                           STDERR 'cfl=',real(cfl/itersmax)
!$OMP END CRITICAL
                           iters = itersmax
                        else
                           iters = iters_new
                        end if
                        itersm1 = _ONE_ / iters
                        dtik = dti * itersm1
                        splitfack = splitfac * itersm1
                        if (it .gt. 1) then
#ifdef DEBUG
!$OMP CRITICAL
                           STDERR 'adv_split_w: restart iterations during it=',it
                           STDERR 'i=',i,' j=',j,':',iters
!$OMP END CRITICAL
#endif
                           it = 1
                           cycle
                        end if
                     end if
                  end if

!                 Calculating w-interface fluxes !
                  do k=1-kshift,kmax-1
!                    Note (KK): overwrite zero flux at k=0 in case of W_TAG
                     if (ww(i,j,k) .gt. _ZERO_) then
                        fu = faux(k)               ! central
                        if (k .gt. 1-kshift) then
                           fuu = faux(k-1)            ! upstream
                        else
                           fuu = fu
                        end if
                        fd  = faux(k+1)            ! downstream
                     else
                        fu = faux(k+1)               ! central
                        if (k .lt. kmax-1) then
                           fuu = faux(k+2)            ! upstream
                        else
                           fuu = fu
                        end if
                        fd  = faux(k  )            ! downstream
                     end if
                     fu = adv_interfacial_reconstruction(scheme,cfls(k)*itersm1,fuu,fu,fd)
                     wflux(k) = ww(i,j,k)*fu
                     if (calc_nvd) then
                        wflux2(k) = wflux(k)*fu
                     end if
                  end do

#ifdef _POINTER_REMAP_
                  if (it .eq. iters) then
                     p1d => fi (i,j,:) ; p_fiaux (0:) => p1d
                     p1d => hi (i,j,:) ; p_hiaux (0:) => p1d
                     p1d => adv(i,j,:) ; p_advaux(0:) => p1d
                     if (calc_ffluxw) then
                        p1d => ffluxw(i,j,:) ; p_ffluxwaux(0:) => p1d
                     end if
                     if (calc_nvd) then
                        p1d => nvd(i,j,:) ; p_nvdaux(0:) => p1d
                     end if
                  end if
#endif

                  if (calc_ffluxw) p_ffluxwaux = ffluxwaux + splitfack*wflux

                  do k=1,kmax-kshift
!                    Note (KK): in case of W_TAG do not advect at k=kmax
                     fio = fiaux(k)
                     hio = hiaux(k)
                     p_hiaux(k) = hio - dtik*(ww(i,j,k  )-ww(i,j,k-1))
                     advn = splitfack*(wflux(k  )-wflux(k-1))
                     p_fiaux(k) = ( hio*fio - dt*advn ) / p_hiaux(k)
                     p_advaux(k) = advaux(k) + advn
                     if (calc_nvd) then
                        adv2n = splitfack*(wflux2(k  )-wflux2(k-1))
!                        p_nvdaux(k) = nvdaux(k)                                            &
!                                     -((p_hiaux(k)*p_fiaux(k)**2 - hio*fio**2)/dt + adv2n)
                        p_nvdaux(k) = ( hio*nvdaux(k)                                        &
                                       -((p_hiaux(k)*p_fiaux(k)**2 - hio*fio**2)/dt + adv2n) &
                                      )/p_hiaux(k)
                     end if
                  end do

                  faux => p_fiaux
                  it = it + 1

               end do

#ifndef _POINTER_REMAP_
               fi (i,j,1:kmax-kshift) = p_fiaux (1:kmax-kshift)
               hi (i,j,1:kmax-kshift) = p_hiaux (1:kmax-kshift)
               adv(i,j,1:kmax-kshift) = p_advaux(1:kmax-kshift)
               if (calc_ffluxw) ffluxw(i,j,1:kmax-kshift) = p_ffluxwaux(1:kmax-kshift)
               if (calc_nvd)    nvd   (i,j,1:kmax-kshift) = p_nvdaux   (1:kmax-kshift)
#endif

            end if

         end do
#ifndef SLICE_MODEL
      end do
#endif
!$OMP END DO NOWAIT

!     Each thread must deallocate its own HEAP storage:
      deallocate(wflux,stat=rc)
      if (rc /= 0) stop 'adv_split_w: Error deallocating memory (wflux)'

#ifndef _POINTER_REMAP_
      deallocate(fo,stat=rc)
      if (rc /= 0) stop 'adv_split_w: Error deallocating memory (fo)'
#endif

      deallocate(fiaux,stat=rc)
      if (rc /= 0) stop 'adv_split_w: Error deallocating memory (fiaux)'

      deallocate(hiaux,stat=rc)
      if (rc /= 0) stop 'adv_split_w: Error deallocating memory (hiaux)'

      deallocate(advaux,stat=rc)
      if (rc /= 0) stop 'adv_split_w: Error deallocating memory (advaux)'

      deallocate(cfl0,stat=rc)
      if (rc /= 0) stop 'adv_split_w: Error deallocating memory (cfl0)'

      deallocate(cfls,stat=rc)
      if (rc /= 0) stop 'adv_split_w: Error deallocating memory (cfls)'

      if (calc_ffluxw) then
         deallocate(ffluxwaux,stat=rc)
         if (rc /= 0) stop 'adv_split_w: Error deallocating memory (ffluxwaux)'
      end if

      if (calc_nvd) then
         deallocate(wflux2,stat=rc)
         if (rc /= 0) stop 'adv_split_w: Error deallocating memory (wflux2)'
         deallocate(nvdaux,stat=rc)
         if (rc /= 0) stop 'adv_split_w: Error deallocating memory (nvdaux)'
      end if

   end if

!$OMP END PARALLEL

#ifdef DEBUG
   write(debug,*) 'Leaving adv_split_w()'
   write(debug,*)
#endif
   return
   end subroutine adv_split_w
!EOC
!-----------------------------------------------------------------------
! Copyright (C) 2004 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------
