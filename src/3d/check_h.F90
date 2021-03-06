!JMB
         subroutine ztoh(zpos,hn,depthmin)
#include "cppdefs.h"
!
! !DESCRIPTION:
!
! !USES:
   use domain,   only: imin,imax,jmin,jmax,kmax,H
   IMPLICIT NONE
   REALTYPE        :: zpos(I3DFIELD),hn(I3DFIELD),depthmin
   integer         :: i,j,k
      do k=1,kmax
      do j=jmin-HALO,jmax+HALO
       do i=imin-HALO,imax+HALO
       hn(i,j,k)= zpos(i,j,k)-zpos(i,j,k-1)
       hn(i,j,k)=max(hn(i,j,k),depthmin)
       enddo
       enddo
      enddo
! End Back to layer thickness
     return
     end
         subroutine htoz(hn,zpos)
#include "cppdefs.h"
!
! !DESCRIPTION:
!
! !USES:
   use domain,   only: imin,imax,jmin,jmax,kmax,H
   IMPLICIT NONE
   REALTYPE        :: zpos(I3DFIELD),hn(I3DFIELD),depthmin
   integer         :: i,j,k
!     write(6,*) 'htoz',imax,hn(imax/2,2,kmax/2),H(imax/2,2)
      do j=jmin-HALO,jmax+HALO
       do i=imin-HALO,imax+HALO
       zpos(i,j,0)=-H(i,j)
       do k=1,kmax
       zpos(i,j,k)=zpos(i,j,k-1)+hn(i,j,k)
       enddo
       enddo
      enddo
     return
     end

