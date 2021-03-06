#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: mirror_bdy_2d() - mirrors 2d variables
!
! !INTERFACE:
   subroutine mirror_bdy_2d(f,tag)
!
! !DESCRIPTION:
!  Some variables are mirrored outside the calculation domain in the
!  vicinity of the open boundaries. This is to avoid if statements
!  when calculating e.g. the Coriolis terms and advection.
!  This routines mirrors 2d variables.
!
! !USES:
   use halo_zones, only : U_TAG,V_TAG,H_TAG
   use domain, only: imin,imax,jmin,jmax
   use domain, only: az,au,av
   use domain, only: NWB,NNB,NEB,NSB
   use domain, only: wi,wfj,wlj,nj,nfi,nli,ei,efj,elj,sj,sfi,sli
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: tag
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE, intent(inout)             :: f(E2DFIELD)
!
! !OUTPUT PARAMETERS:
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   integer                   :: i,j,n
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'mirror_bdy_2d() # ',Ncall
#endif

   select case (tag)
      case (U_TAG)
         do n = 1,NNB
            j = nj(n)
            do i = max(imin-HALO,nfi(n)-1),nli(n)
               if (au(i,j) .eq. 3) f(i,j) = f(i,j-1)
            end do
         end do
         do n = 1,NSB
            j = sj(n)
            do i = max(imin-HALO,sfi(n)-1),sli(n)
               if (au(i,j) .eq. 3) f(i,j) = f(i,j+1)
            end do
         end do
#ifdef _MIRROR_BDY_EXTRA_
         do n = 1,NWB
            i = wi(n)
            do j = wfj(n),wlj(n)
               if (au(i-1,j) .eq. 0) f(i-1,j) = f(i,j)
            end do
!           KK-TODO: do we really need this?
            j = wfj(n)-1
            if ( jmin-HALO .le. j ) then
               if (au(i-1,j).eq.0 .and. au(i,j).eq.3) f(i-1,j) = f(i,j)
            end if
            j = wlj(n)+1
            if ( j .le. jmax+HALO ) then
               if (au(i-1,j).eq.0 .and. au(i,j).eq.3) f(i-1,j) = f(i,j)
            end if
         end do
         do n = 1,NEB
            i = ei(n)
            do j = efj(n),elj(n)
               if (au(i,j) .eq. 0) f(i,j) = f(i-1,j)
            end do
!           KK-TODO: do we really need this?
            j = efj(n)-1
            if ( jmin-HALO .le. j ) then
               if (au(i,j).eq.0 .and. au(i-1,j).eq.3) f(i,j) = f(i-1,j)
            end if
            j = elj(n)+1
            if ( j .le. jmax+HALO ) then
               if (au(i,j).eq.0 .and. au(i-1,j).eq.3) f(i,j) = f(i-1,j)
            end if
         end do
#endif
      case (V_TAG)
         do n = 1,NWB
            i = wi(n)
            do j = max(jmin-HALO,wfj(n)-1),wlj(n)
               if (av(i,j) .eq. 3) f(i,j) = f(i+1,j)
            end do
         end do
         do n = 1,NEB
            i = ei(n)
            do j = max(jmin-HALO,efj(n)-1),elj(n)
               if (av(i,j) .eq. 3) f(i,j) = f(i-1,j)
            end do
         end do
#ifdef _MIRROR_BDY_EXTRA_
         do n = 1,NNB
            j = nj(n)
            do i = nfi(n),nli(n)
               if (av(i,j) .eq. 0) f(i,j) = f(i,j-1)
            end do
!           KK-TODO: do we really need this?
            i = nfi(n)-1
            if ( imin-HALO .le. i ) then
               if (av(i,j).eq.0 .and. av(i,j-1).eq.3) f(i,j) = f(i,j-1)
            end if
            i = nli(n)+1
            if ( i .le. imax+HALO ) then
               if (av(i,j).eq.0 .and. av(i,j-1).eq.3) f(i,j) = f(i,j-1)
            end if
         end do
         do n = 1,NSB
            j = sj(n)
            do i = sfi(n),sli(n)
               if (av(i,j-1) .eq. 0) f(i,j-1) = f(i,j)
            end do
!           KK-TODO: do we really need this?
            i = sfi(n)-1
            if ( imin-HALO .le. i ) then
               if (av(i,j-1).eq.0 .and. av(i,j).eq.3) f(i,j-1) = f(i,j)
            end if
            i = sli(n)+1
            if ( i .le. imax+HALO ) then
               if (av(i,j-1).eq.0 .and. av(i,j).eq.3) f(i,j-1) = f(i,j)
            end if
         end do
#endif
      case default
         do n = 1,NWB
            i = wi(n)
            do j = wfj(n),wlj(n)
               if (az(i-1,j).eq.0 .and. az(i,j).gt.1) f(i-1,j) = f(i,j)
            end do
         end do

         do n = 1,NNB
            j = nj(n)
            do i = nfi(n),nli(n)
               if (az(i,j+1).eq.0 .and. az(i,j).gt.1) f(i,j+1) = f(i,j)
            end do
         end do

         do n = 1,NEB
            i = ei(n)
            do j = efj(n),elj(n)
               if (az(i+1,j).eq.0 .and. az(i,j).gt.1) f(i+1,j) = f(i,j)
            end do
         end do

         do n = 1,NSB
            j = sj(n)
            do i = sfi(n),sli(n)
               if (az(i,j-1).eq.0 .and. az(i,j).gt.1) f(i,j-1) = f(i,j)
            end do
         end do
   end select

#ifdef DEBUG
   write(debug,*) 'Leaving mirror_bdy_2d()'
   write(debug,*)
#endif

   return
   end subroutine mirror_bdy_2d
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2003 - Karsten Bolding and Hans Burchard               !
!-----------------------------------------------------------------------
