#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: Encapsulate 2D netCDF quantities
!
! !INTERFACE:
   module ncdf_2d
!
! !DESCRIPTION:
!
! !USES:
   use output
   IMPLICIT NONE
!
! !PUBLIC DATA MEMBERS:
   integer                             :: ncid=-1

   integer                             :: x_dim,y_dim
   integer                             :: time_dim
   integer                             :: time_id

   integer                             :: elev_id
   integer                             :: fluxu_id=-1
   integer                             :: fluxv_id=-1
   integer                             :: u_id=-1
   integer                             :: v_id=-1
   integer                             :: res_u_id=-1,res_v_id=-1
   integer                             :: u10_id,v10_id
   integer                             :: airp_id,t2_id,hum_id,tcc_id
   integer                             :: tausx_id,tausy_id
   integer                             :: zenith_angle_id
   integer                             :: swr_id,albedo_id,shf_id
   integer                             :: evap_id=-1,precip_id=-1

   integer                             :: waveH_id=-1
   integer                             :: waveL_id=-1
   integer                             :: waveT_id=-1
   integer                             :: uStokes_id=-1
   integer                             :: vStokes_id=-1
   integer                             :: fluxuStokes_id=-1
   integer                             :: fluxvStokes_id=-1

   integer                             :: Am_2d_id=-1
   integer                             :: taubmax_id=-1
   integer                             :: break_stat_id=-1

   integer                             :: nd2d_id=-1
   integer                             :: nd2do_id=-1,pd2d_id=-1

! !DEFINED PARAMETERS
   REALTYPE, parameter                 :: elev_missing       =-9999.0
   REALTYPE, parameter                 :: vel_missing        =-9999.0
   REALTYPE, parameter                 :: flux_missing       =-99999.0
   REALTYPE, parameter                 :: airp_missing       =-9999.0
   REALTYPE, parameter                 :: t2_missing         =-9999.0
   REALTYPE, parameter                 :: hum_missing        =-9999.0
   REALTYPE, parameter                 :: tcc_missing        =-9999.0
   REALTYPE, parameter                 :: stress_missing     =-9999.0
   REALTYPE, parameter                 :: angle_missing      =-9999.0
   REALTYPE, parameter                 :: swr_missing        =-9999.0
   REALTYPE, parameter                 :: albedo_missing     =-9999.0
   REALTYPE, parameter                 :: shf_missing        =-9999.0
   REALTYPE, parameter                 :: evap_missing       =-9999.0
   REALTYPE, parameter                 :: precip_missing     =-9999.0
   REALTYPE, parameter                 :: waves_missing      =-9999.0
   REALTYPE, parameter                 :: Am_2d_missing      =-9999.0
   REALTYPE, parameter                 :: nummix_missing     =-9999.0
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
!EOP
!-----------------------------------------------------------------------

   end module ncdf_2d

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
