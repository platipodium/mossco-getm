!$Id: general_coordinates.F90,v 1.1 2007-03-29 12:28:22 kbk Exp $
#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE:  general vertical coordinates
! \label{sec-general-coordinates}
!
! !INTERFACE:
   subroutine general_coordinates(first,cord_relax,maxdepth)
!
! !DESCRIPTION:
!
! Here, the vertical layer distribution in T-, U- and V-points is updated
! during every macro time step. This is done for the old and the new
! layer thicknesses at every point. Calculation of the layer distribution
! in the U- and V-points is done indepently from the calculation in the
! T-points, since different methods for the calculation of the 
! bathymetry values in the U- and V-points are possible, see routine
! {\tt uv\_depths} described on page \pageref{sec-uv-depth}.
!
! Here, three different methods for the vertical layer distribution
! are coded:
!
! \begin{enumerate}
! \item Classical $\sigma$ coordinates where layer interfaces for each 
! layer index have a fixed relative position $\sigma_k$ in the water column,
! which may be even equidistant or non-equidistant, see equations 
! (\ref{sigma}) and (\ref{formula_Antoine}). 
! The surface and bottom zooming factors 
! $d_u$ and $d_l$ are read in via the {\tt domain} namelist in {\tt getm.inp}
! as {\tt ddu} and {\tt ddl}.
! In the first call to coordinates, the relative interface positions
! {\tt dga} are calculated as a one-dimensional vector (in case of
! non-equidistant $\sigma$ coordinates), and those are then multiplied with
! the water depths in all T-, U- and V-points to get the layer thicknesses. 
! \item Also $z$- (i.e.\ geopotential) coordinates are enabled in GETM
! in principle. However, they may not yet work and need further
! development. First of all, fixed $z$-levels are defined by means of
! zooming factors and the maximum water depth $H_{\max}$:
!
! \begin{equation}\label{formula_Antoine_zlevels}
! z_k = H_{\max}\left(\frac{\mbox{tanh}\left( (d_l+d_u)(1+\sigma_k)-d_l\right)
! +\mbox{tanh}(d_l)}{\mbox{tanh}(d_l)+\mbox{tanh}(d_u)}-1\right),
! \qquad k=0,\dots,N\qquad
! \end{equation}
!
! Then, layers are from the surface down filled into the T-point 
! water column locally.
! When the last layer is shallower than {\tt hnmin} (hard coded as local
! variable), the two last layers are combined. The index of the lowest 
! layer is then stored in the integer field {\tt kmin\_pmz}.
! layer thicknesses in U- and V-points are then taken as the minimum 
! values of adjacent thicknesses in T-points, and bottom indices
! {\tt kumin\_pmz} and  {\tt kvmin\_pmz} are taken as the maximum
! of adjacent  {\tt kmin\_pmz} indices.
! \item The third and so far most powerful method are the genral
! vertical coordinates, discussed in section \ref{SectionGeneralCoordinates},
! see equations (\ref{sigma}) - (\ref{MLDTransform}), which is basically
! an interpolation between equidistant and non-equaidistant $\sigma$
! coordinates. During the first call, a three-dimensional field
! {\tt gga} containing the relative interface positions is calculated,
! which further down used together with the actual water depth in the 
! T-, U- and V-points for calculating the updated old and new layer
! thicknesses.
!\end{enumerate}
! 
! A fourth option will soon be the adaptive grids which have been
! conceptionally developed by \cite{BURCHARDea04}.
!
! !USES:
   use domain, only: ga,ddu,ddl,d_gamma,gamma_surf
   use domain, only: iimin,iimax,jjmin,jjmax,kmax,H,HU,HV,az,au,av,min_depth
   use variables_3d, only: dt,kmin,kumin,kvmin,ho,hn,huo,hun,hvo,hvn
   use variables_3d, only: sseo,ssen,ssuo,ssun,ssvo,ssvn
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   logical, intent(in)                 :: first
   REALTYPE, intent(in)                :: cord_relax
   REALTYPE, intent(in)                :: maxdepth
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Karsten Bolding
!
! !LOCAL VARIABLES:
   integer         :: i,j,k,rc,kk
   REALTYPE        :: alpha
   REALTYPE        :: HH,zz,r
   REALTYPE, save, dimension(:),     allocatable  :: dga,be,sig
   REALTYPE, save, dimension(:,:,:), allocatable  :: gga
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'coordinates() # ',Ncall
#endif

   if (first) then
      if (.not. allocated(ga)) allocate(ga(0:kmax),stat=rc)
      if (rc /= 0) stop 'coordinates: Error allocating (ga)'
      do k=0,kmax
         ga(k) = k
      end do
      allocate(sig(0:kmax),stat=rc)    ! dimensionless sigma-coordinate
      if (rc /= 0) STOP 'coordinates: Error allocating (sig)'
      allocate(be(0:kmax),stat=rc)     ! dimensionless beta-coordinate
      if (rc /= 0) STOP 'coordinates: Error allocating (be)'
      allocate(gga(I3DFIELD),stat=rc)  ! dimensionless gamma-coordinate
      if (rc /= 0) stop 'coordinates: Error allocating memory (gga)'
      be(0)=  -_ONE_
      sig(0)= -_ONE_
      if (ddu .lt. _ZERO_) ddu=_ZERO_
      if (ddl .lt. _ZERO_) ddl=_ZERO_
      do k=1,kmax
         be(k)=tanh((ddl+ddu)*k/float(kmax)-ddl)+tanh(ddl)
         be(k)=be(k)/(tanh(ddl)+tanh(ddu))-_ONE_
         sig(k)=k/float(kmax)-_ONE_
      end do
      if (gamma_surf) then
         kk=kmax
      else
         kk=1
      end if
      do j=jjmin-HALO,jjmax+HALO
         do i=iimin-HALO,iimax+HALO
            HH=max(sseo(i,j)+H(i,j),min_depth)
            alpha=min(&
                     ((be(kk)-be(kk-1))-D_gamma/HH&
                      *(sig(kk)-sig(kk-1)))&
                      /((be(kk)-be(kk-1))-(sig(kk)-sig(kk-1))),_ONE_)
            gga(i,j,0)=-_ONE_
            do k=1,kmax
               gga(i,j,k)=alpha*sig(k)+(1.-alpha)*be(k)
               if (gga(i,j,k) .lt. gga(i,j,k-1)) then
                  STDERR kk,(be(kk)-be(kk-1)),(sig(kk)-sig(kk-1))
                  STDERR D_gamma,HH
                  STDERR alpha
                  STDERR k-1,gga(i,j,k-1),be(k-1),sig(k-1)
                  STDERR k,gga(i,j,k),be(k),sig(k)
                  stop 'coordinates'
               end if
            end do
         end do
      end do

      kmin=1
      kumin=1
      kvmin=1

!     Here, the initial layer distribution is calculated.
      do k=1,kmax
         do j=jjmin-HALO,jjmax+HALO
            do i=iimin-HALO,iimax+HALO
               HH=max(sseo(i,j)+H(i,j),min_depth)
               hn(i,j,k)=HH*(gga(i,j,k)-gga(i,j,k-1))
            end do
         end do
      end do

      do k=1,kmax
         do j=jjmin-HALO,jjmax+HALO
            do i=iimin-HALO,iimax+HALO-1
               HH=max(ssuo(i,j)+HU(i,j),min_depth)
               huo(i,j,k)=HH*0.5*            &
                (gga(i,j,k)-gga(i,j,k-1)+gga(i+1,j,k)-gga(i+1,j,k-1))
               hun(i,j,k)=huo(i,j,k)
            end do
         end do
      end do

      do k=1,kmax
         do j=jjmin-HALO,jjmax+HALO-1
            do i=iimin-HALO,iimax+HALO
               HH=max(ssvo(i,j)+HV(i,j),min_depth)
               hvo(i,j,k)=HH*0.5*            &
                (gga(i,j,k)-gga(i,j,k-1)+gga(i,j+1,k)-gga(i,j+1,k-1))
               hvn(i,j,k)=hvo(i,j,k)
            end do
         end do
      end do
   end if ! first

! The general vertical coordinates can be relaxed towards the new layer
! thicknesses by the following relaxation time scale r. This should
! later be generalised also for sigma coordinates.

   do j=jjmin-HALO,jjmax+HALO
      do i=iimin-HALO,iimax+HALO
         r=cord_relax/dt*H(i,j)/maxdepth
         HH=ssen(i,j)+H(i,j)
         if (HH .lt. D_gamma) then
            do k=1,kmax
               ho(i,j,k)=hn(i,j,k)
               hn(i,j,k)=HH/float(kmax)
            end do
         else
            zz=-H(i,j)
            do k=1,kmax-1
               ho(i,j,k)=hn(i,j,k)
               hn(i,j,k)=(ho(i,j,k)*r+HH*(gga(i,j,k)-gga(i,j,k-1)))/(r+1.)
               zz=zz+hn(i,j,k)
            end do
            ho(i,j,kmax)=hn(i,j,kmax)
            hn(i,j,kmax)=ssen(i,j)-zz
         end if
      end do
   end do

   do j=jjmin-HALO,jjmax+HALO
      do i=iimin-HALO,iimax+HALO-1
!KBK         if (au(i,j) .gt. 0) then
            r=cord_relax/dt*HU(i,j)/maxdepth
            zz=-HU(i,j)
            HH=ssun(i,j)+HU(i,j)
            do k=1,kmax-1
               huo(i,j,k)=hun(i,j,k)
               hun(i,j,k)=(huo(i,j,k)*r+HH*0.5*(gga(i,j,k)-gga(i,j,k-1) &
                         +gga(i+1,j,k)-gga(i+1,j,k-1)))/(r+1.)
               zz=zz+hun(i,j,k)
            end do
            huo(i,j,kmax)=hun(i,j,kmax)
            hun(i,j,kmax)=ssun(i,j)-zz
!KBK         end if
      end do
   end do

   do j=jjmin-HALO,jjmax+HALO-1
      do i=iimin-HALO,iimax+HALO
!KBK         if (av(i,j).gt.0) then
            r=cord_relax/dt*HV(i,j)/maxdepth
            zz=-HV(i,j)
            HH=ssvn(i,j)+HV(i,j)
            do k=1,kmax-1
               hvo(i,j,k)=hvn(i,j,k)
               hvn(i,j,k)=(hvo(i,j,k)*r+HH*0.5*(gga(i,j,k)-gga(i,j,k-1) &
                         +gga(i,j+1,k)-gga(i,j+1,k-1)))/(r+1.)
               zz=zz+hvn(i,j,k)
            end do
            hvo(i,j,kmax)=hvn(i,j,kmax)
            hvn(i,j,kmax)=ssvn(i,j)-zz
!KBK         end if
      end do
   end do

#ifdef DEBUG
   write(debug,*) 'Leaving general_coordinates()'
   write(debug,*)
#endif
   return
   end subroutine general_coordinates
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2007 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------