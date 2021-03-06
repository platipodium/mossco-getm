#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: start_macro - initialise the macro loop \label{sec-start-macro}
!
! !INTERFACE:
   subroutine start_macro()
!
! !DESCRIPTION:
!
! This routine needs to be called from {\tt m3d} at the beginning
! of each macro time step. Here, the sea surface elevations at the
! before and after the macro time step are updated at the
! T-, U- and V-points.the sea surface elevations at the
! before and after the macro time step are updated at the
! T-, U- and V-points, their notation is {\tt sseo}, {\tt ssen},
! {\tt ssuo}, {\tt ssun}, {\tt ssvo} and {\tt ssvn}, where {\tt e},
! {\tt u} and {\tt v} stand for T-, U- and V-point and {\tt o} and
! {\tt n} for old and new, respectively, see also the description of
! {\tt variables\_3d} in section \ref{sec-variables-3d} on page
! \pageref{sec-variables-3d}.
!
! Furthermore, the vertically integrated transports {\tt Uint}
! and {\tt Vint} are here divided by the number of micro time
! steps per macro time step, {\tt M}, in order to obtain
! the time-averaged transports.
!
!
! !USES:
   use domain, only: imin,imax,jmin,jmax,kmax,H,HU,HV,az,min_depth
   use m2d, only: z,Uint,Vint,UEulerInt,VEulerInt
   use variables_2d, only: fwf_int
   use m3d, only: M
   use waves, only: waveforcing_method,NO_WAVES
   use variables_waves, only: UStokesCint,UStokesCadv
   use variables_waves, only: VStokesCint,VStokesCadv
   use variables_3d, only: sseo,ssen,ssuo,ssun,ssvo,ssvn,Dn,Dveln,Dun,Dvn,hn
   use variables_3d, only: Uadv,Vadv,UEulerAdv,VEulerAdv
   use halo_zones, only : update_2d_halo,wait_halo,z_TAG
   use getm_timers, only: tic, toc, TIM_STARTMCR
   IMPLICIT NONE
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Karsten Bolding
!
! !LOCAL VARIABLES:
   integer                   :: i,j
   REALTYPE,dimension(I2DFIELD) :: ssevel
   REALTYPE                  :: split
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'start_macro() # ',Ncall
#endif
   call tic(TIM_STARTMCR)

   call update_2d_halo(fwf_int,fwf_int,az,imin,jmin,imax,jmax,z_TAG)
   call wait_halo(z_TAG)

   do j=jmin-HALO,jmax+HALO
      do i=imin-HALO,imax+HALO
!        fwf_int(az=2)<>0; do not mess with open bdy cells!
         if (az(i,j) .eq. 1) then
            ssen(i,j)      = ssen(i,j)      + fwf_int(i,j)
            hn  (i,j,kmax) = hn  (i,j,kmax) + fwf_int(i,j)
         end if
      end do
   end do

   do j=jmin-HALO,jmax+HALO         ! Defining 'old' and 'new' sea surface
      do i=imin-HALO,imax+HALO      ! elevation for macro time step
!        Note (KK): this sseo already includes rivers and fwf
         sseo(i,j)=ssen(i,j)
         ssen(i,j)=z(i,j)
         ssevel(i,j) = _HALF_ * ( sseo(i,j) + ssen(i,j) )
         Dn(i,j) = ssen(i,j) + H(i,j)
         Dveln(i,j) = ssevel(i,j) + H(i,j)
!        KK-TODO: use of Dn & Co. in more routines (coordinates,momentum,rivers)
!                 and replacement of ssun+HU by Dun!
!                 and removement of ssun?
!                 calculation of Dveln,Dun,Dvn by depth_update
      end do
   end do

   do j=jmin-HALO,jmax+HALO             ! Same for U-points
      do i=imin-HALO,imax+HALO-1
         ssuo(i,j) = ssun(i,j) ! needed for reconstruction of huo (sigma,gvc)
#ifdef _NEW_DAF_
         ssun(i,j) = _HALF_*( ssevel(i,j) + ssevel(i+1,j) )
         Dun(i,j) = ssun(i,j) + HU(i,j)
#else
         Dun(i,j) = max( min_depth                                    , &
                         _HALF_*(ssevel(i,j)+ssevel(i+1,j)) + HU(i,j) )
         ssun(i,j) = Dun(i,j) - HU(i,j)
#endif
      end do
   end do

   do j=jmin-HALO,jmax+HALO-1
      do i=imin-HALO,imax+HALO             ! Same for V-points
         ssvo(i,j) = ssvn(i,j) ! needed for reconstruction of hvo (sigma,gvc)
#ifdef _NEW_DAF_
         ssvn(i,j) = _HALF_*( ssevel(i,j) + ssevel(i,j+1) )
         Dvn(i,j) = ssvn(i,j) + HV(i,j)
#else
         Dvn(i,j) = max( min_depth                                    , &
                         _HALF_*(ssevel(i,j)+ssevel(i,j+1)) + HV(i,j) )
         ssvn(i,j) = Dvn(i,j) - HV(i,j)
#endif
      end do
   end do

! Defining vertically integrated, conservative
! u- and v-transport for macro time step

   split = _ONE_/M
   Uadv = split*Uint
   Vadv = split*Vint
   if (waveforcing_method .ne. NO_WAVES) then
      UEulerAdv   = split*UEulerInt
      VEulerAdv   = split*VEulerInt
      UStokesCadv = split*UStokesCint
      VStokesCadv = split*VStokesCint
   end if

   call toc(TIM_STARTMCR)
#ifdef DEBUG
   write(debug,*) 'Leaving start_macro()'
   write(debug,*)
#endif
   return
   end subroutine start_macro
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------
