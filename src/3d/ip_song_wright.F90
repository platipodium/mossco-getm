!$Id: ip_song_wright.F90,v 1.1 2004-04-06 12:42:50 kbk Exp $
#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: ip_song_wright()
!
! !INTERFACE:
   subroutine ip_song_wright()
!
! !DESCRIPTION:
!
! !USES:
   use internal_pressure
   IMPLICIT NONE
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Karsten Bolding
!
!  $Log: ip_song_wright.F90,v $
!  Revision 1.1  2004-04-06 12:42:50  kbk
!  internal pressure calculations now uses wrapper
!
!
! !LOCAL VARIABLES:
   integer                   :: i,j,k
   REALTYPE                  :: dxm1,dym1
   REALTYPE                  :: grdl,grdu,rhol,rhou,prgr,dxz,dyz
!EOP
!-----------------------------------------------------------------------
!BOC
#if ! ( defined(SPHERICAL) || defined(CURVILINEAR) )
   dxm1 = _ONE_/DXU
   dym1 = _ONE_/DYV
#endif

!  First, the interface heights are calculated in order to get the
!  interface slopes further down.
   do j=jjmin,jjmax+1
      do i=iimin,iimax+1
         if (az(i,j) .ge. 1) then
            zz(i,j,1)=-H(i,j)+0.5*hn(i,j,1)
            do k=2,kmax
               zz(i,j,k)=zz(i,j,k-1)+0.5*(hn(i,j,k-1)+hn(i,j,k))
            end do
         end if
      end do
   end do

!  Calculation of layer integrated internal pressure gradient as it
!  appears on the right hand side of the u-velocity equation.
   do j=jjmin,jjmax
      do i=iimin,iimax
         if (au(i,j) .ge. 1) then
#if defined(SPHERICAL) || defined(CURVILINEAR)
            dxm1=_ONE_/DXU
#endif
            grdl=0.5*hun(i,j,kmax)*(rho(i+1,j,kmax)-rho(i,j,kmax))*dxm1
            rhol=0.5*(rho(i+1,j,kmax)+rho(i,j,kmax))       &
                     *(zz(i+1,j,kmax)- zz(i,j,kmax))*dxm1
            prgr=grdl
            idpdx(i,j,kmax)=hun(i,j,kmax)*prgr
            do k=kmax-1,1,-1
               grdu=grdl
               grdl=(0.5*(rho(i+1,j,k)+rho(i+1,j,k+1))               &
                        *0.5*(hn(i+1,j,k)+hn(i+1,j,k+1))             &
                    -0.5*(rho(i,j,k)+rho(i,j,k+1))                   &
                        *0.5*(hn(i,j,k)+hn(i,j,k+1)) )*dxm1
               rhou=rhol
               rhol=0.5*(rho(i+1,j,k)+rho(i,j,k))*(zz(i+1,j,k)-zz(i,j,k))*dxm1
               prgr=prgr+grdl-(rhou-rhol)
               idpdx(i,j,k)=hun(i,j,k)*prgr
            end do
         end if
      end do
   end do

!  Calculation of layer integrated internal pressure gradient as it
!  appears on the right hand side of the v-velocity equation.
   do j=jjmin,jjmax
      do i=iimin,iimax
         if (av(i,j) .ge. 1) then
#if defined(SPHERICAL) || defined(CURVILINEAR)
         dym1 = _ONE_/DYV
#endif
            grdl=0.5*hvn(i,j,kmax)*(rho(i,j+1,kmax)-rho(i,j,kmax))*dym1
            rhol=0.5*(rho(i,j+1,kmax)+rho(i,j,kmax))     &
                     *(zz(i,j+1,kmax)- zz(i,j,kmax))*dxm1
            prgr=grdl
            idpdy(i,j,kmax)=hvn(i,j,kmax)*prgr
            do k=kmax-1,1,-1
               grdu=grdl
               grdl=(0.5*(rho(i,j+1,k)+rho(i,j+1,k+1))               &
                        *0.5*(hn(i,j+1,k)+hn(i,j+1,k+1))             &
                    -0.5*(rho(i,j,k)+rho(i,j,k+1))                   &
                        *0.5*(hn(i,j,k)+hn(i,j,k+1)) )*dym1
               rhou=rhol
               rhol=0.5*(rho(i,j+1,k)+rho(i,j,k))*(zz(i,j+1,k)-zz(i,j,k))*dym1
               prgr=prgr+grdl-(rhou-rhol)
               idpdy(i,j,k)=hvn(i,j,k)*prgr
            end do
         end if
      end do
   end do

   return
   end subroutine ip_song_wright
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2004 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------