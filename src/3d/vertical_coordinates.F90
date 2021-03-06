#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: vertical_coordinates
!
! !INTERFACE:
   module vertical_coordinates
!
! !DESCRIPTION:
!
! !USES:
#ifdef SLICE_MODEL
   use variables_3d, only: kvmin
#endif
   use domain, only: imin,imax,jmin,jmax,kmax
   use domain, only: au,av
   use domain, only: H,vert_cord,maxdepth
   use halo_zones, only: U_TAG,V_TAG
   use variables_3d, only: ho,hn,huo,hun,hvo,hvn,hvel
   use variables_3d, only: zwn,zcn
   use variables_3d, only: Dun,Dvn
   use exceptions
   IMPLICIT NONE
!
! !PUBLIC DATA MEMBERS:
   public coordinates
   logical,public  :: restart_with_ho=.false.
   logical,public  :: restart_with_hn=.false.
   REALTYPE,public :: cord_relax=_ZERO_
!
! !PRIVATE DATA MEMBERS:
!
! !REVISION HISTORY:
!  Original author(s): Richard Hofmeister & Knut Klingbeil
!
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE:  coordinates - defines the vertical coordinate
! \label{sec-coordinates}
!
! !INTERFACE:
   subroutine coordinates(hotstart)
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
! The different methods for the vertical layer distribution
! are initialised and called to be chosen by the namelist paramter {\tt vert\_cord}:\\
! \\
! {\tt vert\_cord=1}: sigma coordinates (section~\ref{sec-sigma-coordinates}) \\
! {\tt vert\_cord=2}: z-level (not coded yet) \\
! {\tt vert\_cord=3}: general vertical coordinates (gvc, section~\ref{sec-general-coordinates})
! \\
! {\tt vert\_cord=5}: adaptive vertical coordinates (section~\ref{sec-adaptive-coordinates}) \\
! \\
!
!
! !USES:
   use getm_timers, only: tic, toc,TIM_COORDS
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
!   integer, intent(in)                 :: cord_type
!   REALTYPE, intent(in)                :: cord_relax
!   REALTYPE, intent(in)                :: maxdepth
   logical, intent(in)                 :: hotstart
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard & Karsten Bolding
!
! !LOCAL VARIABLES:
   logical, save   :: first=.true.
   integer         :: ii
!   integer         :: preadapt=0
   integer          :: i,j,k
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'coordinates() # ',Ncall
#endif
   call tic(TIM_COORDS)

   if (first) then
      if (hotstart) then
         if ( .not.restart_with_ho .or. .not.restart_with_hn ) then
            STDERR LINE
            LEVEL3 "ho and/or hn missing in restart file!!!"
            LEVEL3 "This might be ok for some specific settings, but in"
            LEVEL3 "general you should do a zero-length simulation with"
            LEVEL3 "your previous coordinate settings to create a valid"
            LEVEL3 "restart file."
            STDERR LINE
         end if
      end if

      select case (vert_cord)
         case (_SIGMA_COORDS_) ! sigma coordinates
            LEVEL2 'using ',kmax,' sigma layers'
            call sigma_coordinates(.true.,hotstart)
         case (_Z_COORDS_) ! z-level
            call getm_error("coordinates()","z-levels not implemented yet")
         case (_GENERAL_COORDS_) ! general vertical coordinates
            LEVEL2 'using ',kmax,' gvc layers'
            call general_coordinates(.true.,hotstart,cord_relax,maxdepth)
         case (_HYBRID_COORDS_) ! hybrid vertical coordinates
            LEVEL2 'using ',kmax,' hybrid layers'
            call hybrid_coordinates(.true.)
STDERR 'coordinates(): hybrid_coordinates not coded yet'
stop
         case (_ADAPTIVE_COORDS_) ! adaptive vertical coordinates
            LEVEL2 'using ',kmax,' adaptive layers'
            call adaptive_coordinates(.true.,hotstart)
         case default
      end select
      if (.not. hotstart) then
         ho = hn
      end if
      first = .false.
   else
      ho  = hn  ! ho before advection (already including rivers and fwf)
      huo = hun
      hvo = hvn
      select case (vert_cord)
         case (_SIGMA_COORDS_) ! sigma coordinates
            call sigma_coordinates(.false.,hotstart)
         case (_Z_COORDS_) ! z-level
         case (_GENERAL_COORDS_) ! general vertical coordinates
            call general_coordinates(.false.,hotstart,cord_relax,maxdepth)
         case (_HYBRID_COORDS_) ! hybrid vertical coordinates
            call hybrid_coordinates(.false.)
         case (_ADAPTIVE_COORDS_) ! adaptive vertical coordinates
            call adaptive_coordinates(.false.,hotstart)
         case default
      end select
   end if ! first

   zwn(:,:,0) = -H
   do k=1,kmax
      zwn(:,:,k) = zwn(:,:,k-1) + hn(:,:,k)
   end do
   zcn(:,:,1:kmax) = _HALF_ * ( zwn(:,:,0:kmax-1) + zwn(:,:,1:kmax) )

   hvel = _HALF_ * ( ho + hn )

   if (first .and. hotstart) then
   hun(_IRANGE_HALO_-1,:,1:kmax) = &
      _HALF_ * ( hvel(_IRANGE_HALO_-1,:,1:kmax) + hvel(1+_IRANGE_HALO_,:,1:kmax) )
   hvn(:,_JRANGE_HALO_-1,1:kmax) = &
      _HALF_ * ( hvel(:,_JRANGE_HALO_-1,1:kmax) + hvel(:,1+_JRANGE_HALO_,1:kmax) )

!  KK-TODO: as long as hvel is based on "new" ho (including rivers)
!           hun and hvn do not coincide with Dun and Dvn
   call hcheck(hun,Dun,au)
   call hcheck(hvn,Dvn,av)
   end if

#ifdef _MIRROR_BDY_EXTRA_
!  Note (KK): required for calculation of SS
!             with non-zero velocity behind open bdy
   call mirror_bdy_3d(hun,U_TAG)
   call mirror_bdy_3d(hvn,V_TAG)
#endif

#ifdef SLICE_MODEL
   j = jmax/2
   do i=imin,imax
      do k=kvmin(i,j),kmax
         hvn(i,j-1,k)=hvn(i,j,k)
         hvn(i,j+1,k)=hvn(i,j,k)
      end do
   end do
#endif

   call toc(TIM_COORDS)
#ifdef DEBUG
   write(debug,*) 'Leaving coordinates()'
   write(debug,*)
#endif
   return
   end subroutine coordinates
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE:  hcheck -
!
! !INTERFACE:
   subroutine hcheck(hn,Dn,mask)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,intent(in)        :: Dn(I2DFIELD)
   integer,intent(in)         :: mask(E2DFIELD)
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE,intent(inout)     :: hn(I3DFIELD)
!
! !REVISION HISTORY:
!  Original author(s): Richard Hofmeister
!
! !LOCAL VARIABLES:
   REALTYPE        :: HH,depthmin
   integer         :: i,j,k
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'hcheck() # ',Ncall
#endif

! Final check of layer thicnkess thoug not necessary if zpos treated correctly
   do j=jmin-HALO,jmax+HALO
      do i=imin-HALO,imax+HALO
         if (mask(i,j) .ne. 0) then
            HH=0.
            do k=1,kmax
               HH=HH+hn(i,j,k)
            end do
            do k=1,kmax
               hn(i,j,k)=hn(i,j,k)* Dn(i,j)/HH
            end do
         end if
      end do
   end do

#ifdef DEBUG
   write(debug,*) 'Leaving hcheck()'
   write(debug,*)
#endif
   return
   end subroutine hcheck
!EOC
!-----------------------------------------------------------------------

   end module vertical_coordinates

!-----------------------------------------------------------------------
! Copyright (C) 2012 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------
