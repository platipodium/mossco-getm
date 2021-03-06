#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: depth_update - adjust the depth to new elevations.
!
! !INTERFACE:
   subroutine depth_update(zo,z,D,Dvel,DU,DV,from3d)

!  Note (KK): keep in sync with interface in m2d.F90
!
! !DESCRIPTION:
!
! This routine which is called at every micro time step updates all
! necessary depth related information. These are the water depths in the
! T-, U- and V-points, {\tt D}, {\tt DU} and {\tt DV}, respectively,
! and the drying value $\alpha$ defined in equation (\ref{alpha})
! on page \pageref{alpha} in the T-, the U- and the V-points
! ({\tt dry\_z}, {\tt dry\_u} and {\tt dry\_v}).
!
! When working with the option {\tt SLICE\_MODEL}, the water depths in the
! V-points are mirrored from $j=2$ to $j=1$ and $j=3$.
!
! !USES:
   use domain, only: imin,imax,jmin,jmax,H,HU,HV,min_depth,crit_depth
   use domain, only: az,au,av,dry_z,dry_u,dry_v
   use halo_zones, only: U_TAG,V_TAG
   use getm_timers,  only: tic, toc, TIM_DPTHUPDATE
!$ use omp_lib
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,dimension(E2DFIELD),intent(in)  :: zo,z
   logical,intent(in),optional              :: from3d
!
! !OUTPUT PARAMETERS:
   REALTYPE,dimension(E2DFIELD),intent(out) :: D,Dvel,DU,DV
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Karsten Bolding
!
! !LOCAL VARIABLES:
   integer                   :: i,j
#ifdef _NEW_DAF_
   REALTYPE                  :: hcritm1
#else
   REALTYPE                  :: d1,d2i
#endif
   REALTYPE,dimension(E2DFIELD) :: zvel
   logical                      :: update_dryingfactors
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'depth_update() # ',Ncall
#endif
   CALL tic(TIM_DPTHUPDATE)

! TODO/BJB: Why is this turned off?
! KK: ...because we need to have non-zero DU/DV at land-sea-interfaces
#undef USE_MASK

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,d1,d2i)

!  Depth in elevation points

!$OMP DO SCHEDULE(RUNTIME)
   do j=jmin-HALO,jmax+HALO
      do i=imin-HALO,imax+HALO
         D(i,j) = z(i,j)+H(i,j)
         zvel(i,j) = _HALF_ * ( zo(i,j) + z(i,j) )
         Dvel(i,j) = zvel(i,j) + H(i,j)
      end do
   end do
!$OMP END DO

!  U-points
!$OMP DO SCHEDULE(RUNTIME)
   do j=jmin-HALO,jmax+HALO
      do i=imin-HALO,imax+HALO-1
#ifdef USE_MASK
         if(au(i,j) .gt. 0) then
#endif
#ifdef _NEW_DAF_
         DU(i,j) = _HALF_*(zvel(i,j)+zvel(i+1,j)) + HU(i,j)
#else
         DU(i,j) = max( min_depth                                , &
                        _HALF_*(zvel(i,j)+zvel(i+1,j)) + HU(i,j) )
#endif
#ifdef USE_MASK
         end if
#endif
      end do
   end do
!$OMP END DO NOWAIT

!  V-points
!$OMP DO SCHEDULE(RUNTIME)
   do j=jmin-HALO,jmax+HALO-1
      do i=imin-HALO,imax+HALO
#ifdef USE_MASK
         if(av(i,j) .gt. 0) then
#endif
#ifdef _NEW_DAF_
         DV(i,j) = _HALF_*(zvel(i,j)+zvel(i,j+1)) + HV(i,j)
#else
         DV(i,j) = max( min_depth                                , &
                        _HALF_*(zvel(i,j)+zvel(i,j+1)) + HV(i,j) )
#endif
#ifdef USE_MASK
         end if
#endif
      end do
   end do
!$OMP END DO

   update_dryingfactors = .true.
   if (present(from3d)) then
      if (from3d) then
         update_dryingfactors = .false.
      end if
   end if
!  KK-TODO: why not set the dry masks in any case?
!           however, consider that last call is from postinit_3d
   if (update_dryingfactors) then
#ifdef _NEW_DAF_
   hcritm1 = _ONE_ / (crit_depth - min_depth)
!$OMP DO SCHEDULE(RUNTIME)
   do j=jmin-HALO,jmax+HALO
      do i=imin-HALO,imax+HALO
         if (az(i,j) .gt. 0) then
            dry_z(i,j)=max(_ZERO_,min(_ONE_,(D(i,j)-min_depth)*hcritm1))
         end if
     end do
  end do
!$OMP END DO
!$OMP DO SCHEDULE(RUNTIME)
   do j=jmin-HALO,jmax+HALO
      do i=imin-HALO,imax+HALO-1
         if (au(i,j) .gt. 0) then
            dry_u(i,j) = min( dry_z(i,j) , dry_z(i+1,j) )
         end if
     end do
  end do
!$OMP END DO NOWAIT
!$OMP DO SCHEDULE(RUNTIME)
   do j=jmin-HALO,jmax+HALO-1
      do i=imin-HALO,imax+HALO
         if (av(i,j) .gt. 0) then
            dry_v(i,j) = min( dry_z(i,j) , dry_z(i,j+1) )
         end if
     end do
  end do
!$OMP END DO
#else
   d1  = 2*min_depth
   d2i = _ONE_/(crit_depth-2*min_depth)
!$OMP DO SCHEDULE(RUNTIME)
   do j=jmin-HALO,jmax+HALO
      do i=imin-HALO,imax+HALO
         if (az(i,j) .gt. 0) then
            dry_z(i,j)=max(_ZERO_,min(_ONE_,(D(i,j)-_HALF_*d1)*d2i))
         end if
         if (au(i,j) .gt. 0) then
            dry_u(i,j) = max(_ZERO_,min(_ONE_,(DU(i,j)-d1)*d2i))
         end if
         if (av(i,j) .gt. 0) then
            dry_v(i,j) = max(_ZERO_,min(_ONE_,(DV(i,j)-d1)*d2i))
         end if
     end do
  end do
!$OMP END DO
#endif
   end if

!$OMP END PARALLEL

#ifdef _MIRROR_BDY_EXTRA_
   call mirror_bdy_2d(DU,U_TAG)
   call mirror_bdy_2d(DV,V_TAG)
#endif

#ifdef SLICE_MODEL
   j = jmax/2
   DV   (:,j-1) = DV   (:,j)
   DV   (:,j+1) = DV   (:,j)
   dry_v(:,j-1) = dry_v(:,j)
   dry_v(:,j+1) = dry_v(:,j)
#endif

#ifdef DEBUG
   do j=jmin,jmax
      do i=imin,imax

         if(D(i,j) .le. _ZERO_ .and. az(i,j) .gt. 0) then
            STDERR 'depth_update: D  ',i,j,H(i,j),D(i,j)
         end if

         if(DU(i,j) .le. _ZERO_ .and. au(i,j) .gt. 0) then
            STDERR 'depth_update: DU ',i,j,HU(i,j),DU(i,j)
         end if

         if(DV(i,j) .le. _ZERO_ .and. av(i,j) .gt. 0) then
            STDERR 'depth_update: DV ',i,j,HV(i,j),DV(i,j)
         end if

      end do
   end do
#endif

   CALL toc(TIM_DPTHUPDATE)
#ifdef DEBUG
   write(debug,*) 'Leaving depth_update()'
   write(debug,*)
#endif
   return
   end subroutine depth_update
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------
