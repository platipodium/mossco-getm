!$Id: halo_zones.F90,v 1.1 2003-04-07 12:05:42 kbk Exp $
#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: halo_zones - update halo zones in 'getm'
!
! !INTERFACE:
   module halo_zones

! !DESCRIPTION:
!  This module is included only to supply myid and nprocs used in various
!  places in 'getm'. From version 1.4 real use of MPI will be implemented.
!
! !USES:
#ifdef PARALLEL
   use halo_mpi
#endif
   IMPLICIT NONE
!
! !PUBLIC MEMBER FUNCTIONS:
   public init_halo_zones,update_2d_halo,update_3d_halo,wait_halo
!
! !PUBLIC DATA MEMBERS:
#ifndef PARALLEL
   integer, parameter	:: H_TAG=10,HU_TAG=11,HV_TAG=12
   integer, parameter	:: D_TAG=20,DU_TAG=21,DV_TAG=22
   integer, parameter   :: z_TAG=30,U_TAG=31,V_TAG=32
#endif
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
!  $Log: halo_zones.F90,v $
!  Revision 1.1  2003-04-07 12:05:42  kbk
!  new parallel related files
!
!  Revision 1.1.1.1  2002/05/02 14:01:29  gotm
!  recovering after CVS crash
!
! !LOCAL VARIABLES:
#ifndef PARALLEL
   integer, parameter	:: nprocs=1
#endif
!EOP
!-----------------------------------------------------------------------
!BOC

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_halo_zones - 
!
! !INTERFACE:
   subroutine init_halo_zones()
   IMPLICIT NONE
!
! !DESCRIPTION:
!  Initialize Parallel environment
!
! !INPUT PARAMETERS:
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
!
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_halo_zones'
#endif

#ifdef DEBUG
   write(debug,*) 'Leaving init_halo_zones()'
   write(debug,*)
#endif
   return
   end subroutine init_halo_zones
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: update_2d_halo - updates the halo zones for 2D fields.
!
! !INTERFACE:
   subroutine update_2d_halo(f1,f2,mask,imin,jmin,imax,jmax,tag)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  Print information on the MPI environment
!
! !INPUT PARAMETERS:
   integer, intent(in)		:: imin,jmin,imax,jmax
   integer, intent(in)		:: tag
   integer, intent(in) 		:: mask(-HALO+1:,-HALO+1:)
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE, intent(inout) 	:: f1(E2DFIELD),f2(E2DFIELD)
!
! !OUTPUT PARAMETERS:
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   integer	:: i,j,k
   integer	:: il,jl,ih,jh
!EOP
!-------------------------------------------------------------------------
!BOC
#if 0
   select case (tag)
      case(HU_TAG, U_TAG , DU_TAG) ! for variables defined on u-grid
         il=imin;ih=imax-1;jl=jmin;jh=jmax
      case(HV_TAG, V_TAG , DV_TAG) ! for variables defined on v-grid
         il=imin;ih=imax;jl=jmin;jh=jmax-1
      case default                 ! for variables defined on scalar-grid
         il=imin;ih=imax;jl=jmin;jh=jmax
   end select
#endif

   il=imin;ih=imax;jl=jmin;jh=jmax

   if (nprocs .eq. 1) then
      f1(il-1, : )  = f2(il,  :  )
      f1(ih+1, : )  = f2(ih, :  )
      f1( :, jl-1 ) = f2( :, jl  )
      f1( :, jh+1 ) = f2( :, jh )
   else
#ifdef PARALLEL
      call update_2d_halo_mpi(f1,f2,imin,jmin,imax,jmax,tag)
#endif
   end if
   return
   end subroutine update_2d_halo
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: update_3d_halo - updates the halo zones for 3D fields.
!
! !INTERFACE:
   subroutine update_3d_halo(f1,f2,mask,iimin,jjmin,iimax,jjmax,kmax,tag)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  Print information on the MPI environment
!
! !INPUT PARAMETERS:
   integer, intent(in)	:: iimin,jjmin,iimax,jjmax,kmax
   integer, intent(in)	:: tag
   integer, intent(in)	:: mask(-HALO+1:,-HALO+1:)
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE, intent(inout):: f1(I3DFIELD),f2(I3DFIELD)
!
! !OUTPUT PARAMETERS:
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   integer	:: i,j,k
   integer	:: il,jl,ih,jh
!EOP
!-------------------------------------------------------------------------
!BOC
#if 0
   select case (tag)
      case(HU_TAG, U_TAG , DU_TAG) ! for variables defined on u-grid
         il=iimin;ih=iimax-1;jl=jjmin+1;jh=jjmax-1
         il=iimin;ih=iimax-1;jl=jjmin;jh=jjmax
      case(HV_TAG, V_TAG , DV_TAG) ! for variables defined on v-grid
         il=iimin+1;ih=iimax-1;jl=jjmin;jh=jjmax-1
         il=iimin;ih=iimax;jl=jjmin;jh=jjmax-1
      case default                 ! for variables defined on scalar-grid
         il=iimin;ih=iimax;jl=jjmin;jh=jjmax
   end select
#endif

   il=iimin;ih=iimax;jl=jjmin;jh=jjmax

   if (nprocs .eq. 1) then
      f1(il-1, : , : )  = f2(il, : , :  )
      f1(ih+1, : , : )  = f2(ih, : , :  )
      f1( : , jl-1, : ) = f2( : , jl, : )
      f1( : , jh+1, : ) = f2( : , jh, : )
   else
#ifdef PARALLEL
      call update_3d_halo_mpi(f1,f2,iimin,jjmin,iimax,jjmax,kmax,tag)
#endif
   end if
   return
   end subroutine update_3d_halo
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: wait_halo - waits for any un-finished communications
!
! !INTERFACE:
   subroutine wait_halo(tag)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  Print information on the MPI environment
!
! !INPUT PARAMETERS:
   integer, intent(in)	:: tag
!
! !INPUT/OUTPUT PARAMETERS:
!
! !OUTPUT PARAMETERS:
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef PARALLEL
!kbk   if (nprocs .gt. 1) then
      call wait_halo_mpi(tag)
!kbk   end if
#endif
   return
   end subroutine wait_halo
!EOC

!-----------------------------------------------------------------------

   end module halo_zones

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------