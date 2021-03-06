#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: cfl_check - check for explicit barotropic time step.
!
! !INTERFACE:
   subroutine cfl_check()
!
! !DESCRIPTION:
!
! This routine loops over all horizontal grid points and calculated the
! maximum time step according to the shallow water criterium by
! \cite{BECKERSea93}:
!
! \begin{equation}
! \Delta t_{\max} = \min_{i,j} \left\{\frac{\Delta x_{i,j} \Delta y_{i,j}}
! {\sqrt{2} c_{i,j} \sqrt{\Delta x_{i,j}^2+ \Delta y_{i,j}^2}}\right\}
! \end{equation}
!
! with the local Courant number
!
! \begin{equation}
! c_{i,j}=\sqrt{g H_{i,j}},
! \end{equation}
!
! where $g$ is the gravitational acceleration and $H_{i,j}$ is the local
! bathymetry value. In case that the chosen micro time step $\Delta t_m$
! is larger than $\Delta t_{\max}$, the program will be aborted. In any
! the CFL diagnostics will be written to standard output.
!

!
! !USES:
   use parameters, only: g
   use domain, only: imin,imax,jmin,jmax,H,az
   use domain, only: dyc,dxc
   use variables_2d, only: dtm
   IMPLICIT NONE
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   integer                   :: pos(2),max_pos(2),rc,i,j
   REALTYPE                  :: h_max=-99.,c,max_dt,dtt,dxeff
   logical, dimension(:,:), allocatable :: lmask
!EOP
!-----------------------------------------------------------------------
!BOC
   LEVEL2 'CFL check'

   allocate(lmask(imin:imax,jmin:jmax),stat=rc)
   if (rc /= 0) stop 'cfl_check: Error allocating memory (lmask)'

   lmask = .false.
   lmask = (az(imin:imax,jmin:jmax) .gt. 0)
   h_max = maxval(H(imin:imax,jmin:jmax),mask = lmask)
   pos = maxloc(H(imin:imax,jmin:jmax),mask = lmask)
   max_dt=1000000000.
   do i=imin,imax
      do j=jmin,jmax
         if (az(i,j) .ge. 1 .and. H(i,j) .gt. _ZERO_) then
#if 0
            dtt=min(dxc(i,j),dyc(i,j))/sqrt(2.*g*H(i,j))
#else
            c = sqrt(g*H(i,j))
#ifdef SLICE_MODEL
            dxeff = dxc(i,j)
#else
            dxeff = (dxc(i,j)*dyc(i,j))/ &
                     (sqrt(2.0)*sqrt(dxc(i,j)*dxc(i,j)+dyc(i,j)*dyc(i,j)))
#endif
!           Becker and Deleersnijder
            dtt = dxeff/c
#endif
            if (dtt .lt. max_dt) then
               max_dt=dtt
               max_pos(1)=i
               max_pos(2)=j
            end if
         end if
      end do
   end do
   if (max_dt .lt. 1000000000.) then
   LEVEL3 'max CFL number at depth=',real(H(max_pos(1),max_pos(2))),' at ',max_pos
   LEVEL3 'at this position, dx = ',real(dxc(max_pos(1),max_pos(2))),' and dy =  ',real(dyc(max_pos(1),max_pos(2)))
   end if

   if (dtm .gt. max_dt) then
      FATAL 'reduce time-step (',real(dtm),') below ',real(max_dt)
      stop 'cfl_check()'
   else
      LEVEL3 'used dt (',real(dtm),') is less than ',real(max_dt)
   end if

#ifdef FORTRAN90
   deallocate(lmask,stat=rc)
   if (rc /= 0) stop 'cfl_check: Error allocating memory (lmask)'
#endif
   return
   end subroutine cfl_check
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
