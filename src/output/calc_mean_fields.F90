!$Id: calc_mean_fields.F90,v 1.1 2004-03-29 15:35:52 kbk Exp $
#include "cppdefs.h"
!----------------------------------------------------------------------
!BOP
!
! !IROUTINE: calc_mean_fields() - produces averaged output.
!
! !INTERFACE:
   subroutine calc_mean_fields(n,meanout)
!
! !DESCRIPTION:
!
! !USES:
   use domain, only: imax,imin,jmax,jmin
   use domain, only: iimax,iimin,jjmax,jjmin,kmax
   use domain, only: az,au,av
   use meteo, only: swr
   use m3d, only: M
   use variables_3d, only: hn,uu,hun,vv,hvn,ww,S,T,taub
   use diagnostic_variables
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)  :: n,meanout
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Adolf Stips
!
!  $Log: calc_mean_fields.F90,v $
!  Revision 1.1  2004-03-29 15:35:52  kbk
!  possible to store calculated mean fields
!
!
! !LOCAL VARIABLES:
   integer         :: i,j,k,rc
   REALTYPE        :: tmpf(I3DFIELD)
   REALTYPE,save   :: step=_ZERO_
   logical,save    :: first=.true.
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'calc_mean_fields() # ',Ncall
#endif

   if (first ) then
      LEVEL3 'calc_mean_fields(): initialising variables'
      allocate(swrmean(E2DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (swrmean)'
      allocate(ustarmean(E2DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (ustarmean)'
      allocate(ustar2mean(E2DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (ustar2mean)'
      allocate(uumean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (uumean)'
      allocate(vvmean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (vvmean)'
      allocate(wmean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (wmean)'
      allocate(humean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (humean)'
      allocate(hvmean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (hvmean)'
      allocate(hmean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (hmean)'
      allocate(Tmean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (Tmean)'
      allocate(Smean(I3DFIELD),stat=rc)
      if (rc /= 0) &
          stop 'calc_mean_fields.F90: Error allocating memory (Smean)'
      first = .false.
   end if

   if (step .eq. _ZERO_	) then
      uumean=_ZERO_; vvmean=_ZERO_; wmean=_ZERO_
      humean=_ZERO_; hvmean=_ZERO_; hmean=_ZERO_
      Tmean=_ZERO_; Smean=_ZERO_
      ustarmean=_ZERO_; ustar2mean=_ZERO_; swrmean=_ZERO_
   end if

!  Sum every macro time step, even less would be okay
   if(mod(n,M) .eq. 0) then 

      swrmean = swrmean + swr
!     AS this has to be checked, if it is the correct ustar, 
!     so we must not divide by rho_0 !!
      ustarmean = ustarmean + sqrt(taub)
      ustar2mean = ustar2mean + (taub)

      uumean = uumean + uu
      vvmean = vvmean + vv

!  calculate the real vertical velocities
!KBK - the towas done by Adolf Stips has some errors. For now the mean
!vertical velocity is the grid-ralated velocity.
#if 0
      tmpf=_ZERO_
      call towas(tmpf)
      wmean = wmean + tmpf
#else
      wmean = wmean + ww
#endif

      humean = humean + hun 
      hvmean = hvmean + hvn 

      Tmean = Tmean + T
      Smean = Smean + S
      hmean = hmean + hn

!  count them
      step = step + 1.0
   end if   ! here we summed them up

!  prepare for output
   if(meanout .gt. 0 .and. mod(n,meanout) .eq. 0) then

      if ( step .ge. 1.0) then
         uumean = uumean / step
         vvmean = vvmean / step
         wmean = wmean / step
         humean = humean / step
         hvmean = hvmean / step

         Tmean = Tmean / step
         Smean = Smean / step
         hmean = hmean / step

         ustarmean = ustarmean / step
         swrmean = swrmean / step

!  now calculate the velocities
         where ( humean .ne. _ZERO_ )
            uumean = uumean/humean
         elsewhere
            uumean =  _ZERO_
         end where

         where ( hvmean .ne. _ZERO_ )
            vvmean = vvmean/hvmean
         elsewhere
            vvmean = _ZERO_
         end where

!  we must destagger,  yes

         tmpf = _ZERO_
         do j=jjmin,jjmax
            do i=iimin,iimax
!  check if we are in the water
               if(au(i,j) .gt. 0 .and. au(i-1,j) .gt. 0) then
                  do k = 1, kmax
                     tmpf(i,j,k)=(uumean(i,j,k)+uumean(i-1,j,k))/2.0
                  end do !k
               end if
            end do
         end do
         uumean = tmpf

         tmpf = _ZERO_
         do j=jjmin,jjmax
            do i=iimin,iimax
!  check if we are in the water
               if(av(i,j) .gt. 0 .and. av(i,j-1) .gt. 0) then
                  do k = 1, kmax
                     tmpf(i,j,k)=(vvmean(i,j,k)+vvmean(i,j-1,k))/2.0
                  end do !k
               end if
            end do
         end do
         vvmean = tmpf

         tmpf = 0.0
         do j=jjmin,jjmax
            do i=iimin,iimax
!  check if we are in the water
               if(az(i,j) .gt. 0) then
                  tmpf(i,j,1)=wmean(i,j,1)/2.0
                  do k = 2, kmax
                     tmpf(i,j,k) = (wmean(i,j,k)+wmean(i,j,k-1))/2.0
                  end do
               end if
            end do
         end do
         wmean = tmpf
      end if
      step = _ZERO_
   end if

   return
   end subroutine calc_mean_fields
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2004 -  Adolf Stips  & Karsten Bolding                 !
!-----------------------------------------------------------------------