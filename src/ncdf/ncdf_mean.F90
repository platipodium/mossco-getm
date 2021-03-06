#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: Encapsulate netCDF mean quantities
!
! !INTERFACE:
   module ncdf_mean
!
! !DESCRIPTION:
!
! !USES:
   use output
   IMPLICIT NONE
!
! !PUBLIC DATA MEMBERS:
   integer                             :: ncid=-1

   integer                             :: x_dim,y_dim,z_dim
   integer                             :: time_dim
   integer                             :: time_id

   integer                             :: ustarmean_id,ustar2mean_id
   integer                             :: elevmean_id
   integer                             :: uumean_id,vvmean_id,wmean_id
   integer                             :: hmean_id=-1
   integer                             :: saltmean_id=-1
   integer                             :: tempmean_id=-1
   integer                             :: sigma_tmean_id=-1
   integer                             :: bnh_id=-1
   integer                             :: fwfmean_id=-1
   integer                             :: hfmean_id=-1
   integer                             :: nd3d_id=-1,nd3do_id=-1,pd3d_id=-1
   integer                             :: ndint_id=-1,pdint_id=-1
   integer                             :: nmS_id=-1
   integer                             :: nmT_id=-1
   integer                             :: nmSo_id=-1,pmS_id=-1,nmSint_id=-1,pmSint_id=-1
   integer                             :: nmTo_id=-1,pmT_id=-1,nmTint_id=-1,pmTint_id=-1
#ifdef GETM_BIO
   integer, allocatable                :: biomean_id(:)
#endif
#ifdef _FABM_
   integer, allocatable                :: fabmmean_ids(:)
   integer, allocatable                :: fabmmean_ids_ben(:)
   integer, allocatable                :: fabmmean_ids_diag(:)
   integer, allocatable                :: fabmmean_ids_diag_hz(:)
   integer, allocatable                :: nummix_fabmmean_ids(:)
   integer, allocatable                :: phymix_fabmmean_ids(:)
#endif

   REALTYPE, parameter                 :: elev_missing=-9999.0
   REALTYPE, parameter                 :: hh_missing=-9999.0
   REALTYPE, parameter                 :: fwf_missing=-9999.0
   REALTYPE, parameter                 :: hf_missing=-9999.0
   REALTYPE, parameter                 :: vel_missing=-9999.0
   REALTYPE, parameter                 :: salt_missing=-9999.0
   REALTYPE, parameter                 :: temp_missing=-9999.0
   REALTYPE, parameter                 :: rho_missing=-9999.0
   REALTYPE, parameter                 :: tke_missing=-9999.0
   REALTYPE, parameter                 :: eps_missing=-9999.0
   REALTYPE, parameter                 :: bnh_missing    =-9999.0
   REALTYPE, parameter                 :: nummix_missing=-9999.0
#if (defined(GETM_BIO) || defined(_FABM_))
   REALTYPE, parameter                 :: bio_missing=-9999.0
#endif

!
!  Original author(s): Adolf Stips & Karsten Bolding
!
!EOP
!-----------------------------------------------------------------------

   end module ncdf_mean

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
