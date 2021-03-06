#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: Save 3D netCDF variables
!
! !INTERFACE:
   subroutine save_3d_ncdf(runtype,secs)
!
! !DESCRIPTION:
!
! !USES:
   use netcdf
   use exceptions
   use ncdf_3d
   use grid_ncdf,    only: xlen,ylen,zlen
   use domain,       only: imin,imax,jmin,jmax,kmax
   use domain,       only: H,az,au,av
   use domain,       only: dxv,dyu,areac
   use variables_3d, only: Uadv,Vadv
   use variables_3d, only: ssen,Dn
   use variables_3d, only: kmin,hn,hvel,uu,vv,ww,hcc,SS
   use variables_3d, only: velx3d,vely3d,w,velx2dadv,vely2dadv
   use variables_3d, only: taubx,tauby,taubmax_3d
   use variables_3d, only: zcn
#ifdef _MOMENTUM_TERMS_
   use variables_3d, only: tdv_u,adv_u,vsd_u,hsd_u,cor_u,epg_u,ipg_u
   use variables_3d, only: tdv_v,adv_v,vsd_v,hsd_v,cor_v,epg_v,ipg_v
#endif
#ifndef NO_BAROCLINIC
   use variables_3d, only: S,T,rho,rad,NN
   use variables_3d, only: diffxx,diffyy,diffxy
   use variables_3d, only: buoy
#endif
   use variables_3d, only: minus_bnh
   use variables_3d, only: numdis_3d,numdis_3d_old,phydis_3d
   use variables_3d, only: nummix_S,nummix_T,phymix_S,phymix_T
   use variables_3d, only: nummix_S_old,nummix_T_old
   use variables_les, only: AmC_3d
   use variables_3d, only: tke,num,nuh,eps
#ifdef SPM
   use variables_3d, only: spm_pool,spm
#endif
   use variables_waves
#ifdef SPM
   use suspended_matter, only: spm_save
#endif
#ifdef GETM_BIO
   use bio_var, only: numc
   use variables_3d, only: cc3d
#endif
#ifdef _FABM_
   use getm_fabm,only: model,fabm_pel,fabm_ben,fabm_diag,fabm_diag_hz
   use getm_fabm,only: phymix_fabm_pel,nummix_fabm_pel
#endif
   use parameters,   only: g,rho_0
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE, intent(in) :: runtype,secs
!
! !DEFINED PARAMTERS:
   logical, parameter   :: save3d=.true.
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   integer                   :: err,n
   integer                   :: start(4),edges(4)
   integer, save             :: n3d=0
   REALTYPE                  :: dum(1)
   REALTYPE,dimension(E2DFIELD) :: ws2d
   REALTYPE,dimension(I3DFIELD) :: ws
   integer                   :: k
!EOP
!-----------------------------------------------------------------------
!BOC
   n3d = n3d + 1
   if (n3d .eq. 1) then

      call save_grid_ncdf(ncid,save3d)

      start(1) = 1
      start(2) = 1
      start(3) = 1
      start(4) = n3d
      edges(1) = xlen
      edges(2) = ylen
      edges(3) = zlen
      edges(4) = 1

      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,hcc,-_ONE_, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,hcc_id,ws(_3D_W_),start(1:3),edges(1:3))
      if (err .NE. NF90_NOERR) go to 10

      err = nf90_sync(ncid)
      if (err .NE. NF90_NOERR) go to 10

   end if ! (n3d .eq. 1)

   start(1) = n3d
   edges(1) = 1
   dum(1) = secs
   err = nf90_put_var(ncid,time_id,dum,start,edges)

   start(1) = 1
   start(2) = 1
   start(3) = n3d
   edges(1) = xlen
   edges(2) = ylen
   edges(3) = 1

!  elevations
   call eta_mask(imin,jmin,imax,jmax,az,H,Dn,ssen,mask_depth_3d,elev_missing, &
                 imin,jmin,imax,jmax,ws2d)
   err = nf90_put_var(ncid,elev_id,ws2d(_2D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

!  avg. volume fluxes
   if (fluxu_id .ne. -1) then
         call to_fluxu(imin,jmin,imax,jmax,au, &
                       dyu,                    &
                       Uadv,flux_missing,ws2d)
      err = nf90_put_var(ncid,fluxu_id,ws2d(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (fluxv_id .ne. -1) then
         call to_fluxv(imin,jmin,imax,jmax,av, &
                       dxv,                    &
                       Vadv,flux_missing,ws2d)
      err = nf90_put_var(ncid,fluxv_id,ws2d(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

!  avg. velocities
   if (u_id .ne. -1) then
      err = nf90_put_var(ncid,u_id,velx2dadv(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (v_id .ne. -1) then
      err = nf90_put_var(ncid,v_id,vely2dadv(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (save_taub) then

      !  bottom stress (x)
      call cnv_2d(imin,jmin,imax,jmax,au,rho_0*taubx,tau_missing,       &
                  imin,jmin,imax,jmax,ws2d)
      err = nf90_put_var(ncid,taubx_id,ws2d(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10


      !  bottom stress (y)
      call cnv_2d(imin,jmin,imax,jmax,av,rho_0*tauby,tau_missing,       &
                  imin,jmin,imax,jmax,ws2d)
      err = nf90_put_var(ncid,tauby_id,ws2d(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10

   endif

   if (taubmax_3d_id .ne. -1) then
      call cnv_2d(imin,jmin,imax,jmax,az,rho_0*taubmax_3d,tau_missing, &
                  imin,jmin,imax,jmax,ws2d)
      err = nf90_put_var(ncid,taubmax_3d_id,ws2d(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if


   start(1) = 1
   start(2) = 1
   start(3) = 1
   start(4) = n3d
   edges(1) = xlen
   edges(2) = ylen
   edges(3) = zlen
   edges(4) = 1

   if (h_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,hn,hh_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,h_id,ws(_3D_W_),start,edges)
!      err = nf90_put_var(ncid,h_id,hn(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (zc_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,zcn,zc_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,zc_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

!  volume fluxes
   if (fluxuu_id .ne. -1) then
      ws(:,:,0) = flux_missing
      do k=1,kmax
         call to_fluxu(imin,jmin,imax,jmax,au, &
                       dyu,                    &
                       uu(:,:,k),flux_missing,ws(:,:,k))
      end do
      err = nf90_put_var(ncid,fluxuu_id,ws(_3D_W_),start,edges)
   end if
   if (fluxvv_id .ne. -1) then
      ws(:,:,0) = flux_missing
      do k=1,kmax
         call to_fluxv(imin,jmin,imax,jmax,av, &
                       dxv,                    &
                       vv(:,:,k),flux_missing,ws(:,:,k))
      end do
      err = nf90_put_var(ncid,fluxvv_id,ws(_3D_W_),start,edges)
   end if
   if (fluxw_id .ne. -1) then
      call to_fluxw(imin,jmin,imax,jmax,kmin,kmax,az, &
                    areac,                            &
                    ww,flux_missing,ws)
      err = nf90_put_var(ncid,fluxw_id,ws(_3D_W_),start,edges)
   end if

!  velocites
   if (uu_id .ne. -1) then
      err = nf90_put_var(ncid,uu_id,velx3d(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (vv_id .ne. -1) then
      err = nf90_put_var(ncid,vv_id,vely3d(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (w_id .ne. -1) then
      err = nf90_put_var(ncid,w_id,w(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

#ifdef _MOMENTUM_TERMS_
   err = nf90_put_var(ncid,tdv_u_id,tdv_u(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,adv_u_id,adv_u(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,vsd_u_id,vsd_u(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,hsd_u_id,hsd_u(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,cor_u_id,cor_u(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,epg_u_id,epg_u(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,ipg_u_id,ipg_u(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,tdv_v_id,tdv_v(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,adv_v_id,adv_v(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,vsd_v_id,vsd_v(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,hsd_v_id,hsd_v(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,cor_v_id,cor_v(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,epg_v_id,epg_v(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10

   err = nf90_put_var(ncid,ipg_v_id,ipg_v(_3D_W_),start,edges)
   if (err .NE. NF90_NOERR) go to 10
#endif

#ifndef NO_BAROCLINIC

   if (salt_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,S,salt_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,salt_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (temp_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,T,temp_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,temp_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (sigma_t_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,rho-1000.,rho_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,sigma_t_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (rad_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,rad,rad_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,rad_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (diffxx_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,diffxx,stirr_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,diffxx_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

#ifndef SLICE_MODEL
   if (diffyy_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,diffyy,stirr_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,diffyy_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (diffxy_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,diffxy,stirr_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,diffxy_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
#endif

#endif

   if (save_turb) then

      if (save_tke) then
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,tke,tke_missing, &
                     imin,imax,jmin,jmax,0,kmax,ws)
         err = nf90_put_var(ncid,tke_id,ws(_3D_W_),start,edges)
         if (err .NE. NF90_NOERR) go to 10
      end if

      if (save_num) then
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,num,num_missing, &
                     imin,imax,jmin,jmax,0,kmax,ws)
         err = nf90_put_var(ncid,num_id,ws(_3D_W_),start,edges)
         if (err .NE. NF90_NOERR) go to 10
      end if

      if (save_nuh) then
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,nuh,nuh_missing, &
                     imin,imax,jmin,jmax,0,kmax,ws)
         err = nf90_put_var(ncid,nuh_id,ws(_3D_W_),start,edges)
         if (err .NE. NF90_NOERR) go to 10
      end if

      if (save_eps) then
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,eps,eps_missing, &
                     imin,imax,jmin,jmax,0,kmax,ws)
         err = nf90_put_var(ncid,eps_id,ws(_3D_W_),start,edges)
         if (err .NE. NF90_NOERR) go to 10
      end if
   end if ! save_turb

   if (save_ss_nn) then

      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,SS,SS_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,SS_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10

#ifndef NO_BAROCLINIC
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,NN,NN_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,NN_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10

#endif

   end if ! save_ss_nn

   if (nd3d_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,numdis_3d,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,nd3d_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (nd3do_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,numdis_3d_old,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,nd3do_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (pd3d_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,phydis_3d,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,pd3d_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (nmS_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,nummix_S,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,nmS_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (nmSo_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,nummix_S_old,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,nmSo_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (pmS_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,phymix_S,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,pmS_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (nmT_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,nummix_T,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,nmT_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (nmTo_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,nummix_T_old,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,nmTo_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (pmT_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,phymix_T,nummix_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,pmT_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if

   if (bnh_id .ne. -1) then
      if (runtype.eq.2 .or. nonhyd_method.eq.1) then
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,-minus_bnh,bnh_missing, &
                     imin,imax,jmin,jmax,0,kmax,ws)
      else
#ifndef NO_BAROCLINIC
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,minus_bnh/max(buoy,SMALL),bnh_missing, &
                     imin,imax,jmin,jmax,0,kmax,ws)
#endif
      end if
      err = nf90_put_var(ncid,bnh_id,ws(_3D_W_),start,edges)
   end if

   if (Am_3d_id .ne. -1) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,AmC_3d,Am_3d_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,Am_3d_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if


!  volume fluxes
   if (fluxuuStokes_id .ne. -1) then
      ws(:,:,0) = waves_missing
      do k=1,kmax
         call to_fluxu(imin,jmin,imax,jmax,au, &
                       dyu,                    &
                       uuStokes(:,:,k),waves_missing,ws(:,:,k))
      end do
      err = nf90_put_var(ncid,fluxuuStokes_id,ws(_3D_W_),start,edges)
   end if
   if (fluxvvStokes_id .ne. -1) then
      ws(:,:,0) = waves_missing
      do k=1,kmax
         call to_fluxv(imin,jmin,imax,jmax,av, &
                       dxv,                    &
                       vvStokes(:,:,k),waves_missing,ws(:,:,k))
      end do
      err = nf90_put_var(ncid,fluxvvStokes_id,ws(_3D_W_),start,edges)
   end if

!  velocites
   if (uuStokes_id .ne. -1) then
      call to_3d_vel(imin,jmin,imax,jmax,kmin,kmax,az, &
                     hvel,uuStokesC,waves_missing,ws)
      err = nf90_put_var(ncid,uuStokes_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
   if (vvStokes_id .ne. -1) then
      call to_3d_vel(imin,jmin,imax,jmax,kmin,kmax,az, &
                     hvel,vvStokesC,waves_missing,ws)
      err = nf90_put_var(ncid,vvStokes_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if


#ifdef SPM
   if (spm_save) then
      call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,spm,spm_missing, &
                  imin,imax,jmin,jmax,0,kmax,ws)
      err = nf90_put_var(ncid,spm_id,ws(_3D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
      !spm pool is a 2d magnitude
      start(1) = 1
      start(2) = 1
      start(3) = n3d
      edges(1) = xlen
      edges(2) = ylen
      edges(3) = 1
      call cnv_2d(imin,jmin,imax,jmax,az,spm_pool,spmpool_missing,    &
                  imin,jmin,imax,jmax,ws)
      err = nf90_put_var(ncid,spmpool_id,ws2d(_2D_W_),start,edges)
      if (err .NE. NF90_NOERR) go to 10
   end if
#endif

#ifdef GETM_BIO
!   if (save_bio) then
      start(1) = 1
      start(2) = 1
      start(3) = 1
      start(4) = n3d
      edges(1) = xlen
      edges(2) = ylen
      edges(3) = zlen
      edges(4) = 1
      do n=1,numc
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,cc3d(n,:,:,:), &
                     bio_missing,imin,imax,jmin,jmax,0,kmax,ws)
         err = nf90_put_var(ncid,bio_ids(n),ws(_3D_W_),start,edges)
         if (err .NE.  NF90_NOERR) go to 10
      end do
!   end if
#endif

#ifdef _FABM_
    if (allocated(fabm_pel)) then
      start(1) = 1
      start(2) = 1
      start(3) = 1
      start(4) = n3d
      edges(1) = xlen
      edges(2) = ylen
      edges(3) = zlen
      edges(4) = 1
      do n=1,size(model%state_variables)
         if (fabm_ids(n)==-1) cycle
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,fabm_pel(:,:,:,n), &
                     model%state_variables(n)%missing_value,imin,imax,jmin,jmax,0,kmax,ws)
         err = nf90_put_var(ncid,fabm_ids(n),ws(_3D_W_),start,edges)
         if (err .NE.  NF90_NOERR) go to 10
      end do
      if (allocated(nummix_fabm_pel)) then
         do n=1,ubound(nummix_fabm_pel,4)
            if (nmpel_ids(n)==-1) cycle
            call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,nummix_fabm_pel(:,:,:,n), &
                        model%state_variables(n)%missing_value,imin,imax,jmin,jmax,0,kmax,ws)
            err = nf90_put_var(ncid,nmpel_ids(n),ws(_3D_W_),start,edges)
            if (err .NE.  NF90_NOERR) go to 10
         end do
      end if
      if (allocated(phymix_fabm_pel)) then
         do n=1,ubound(phymix_fabm_pel,4)
            if (pmpel_ids(n)==-1) cycle
            call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,phymix_fabm_pel(:,:,:,n), &
                        model%state_variables(n)%missing_value,imin,imax,jmin,jmax,0,kmax,ws)
            err = nf90_put_var(ncid,pmpel_ids(n),ws(_3D_W_),start,edges)
            if (err .NE.  NF90_NOERR) go to 10
         end do
      end if
      do n=1,size(model%diagnostic_variables)
         if (fabm_ids_diag(n)==-1) cycle
         call cnv_3d(imin,jmin,imax,jmax,kmin,kmax,az,fabm_diag(:,:,:,n), &
                     model%diagnostic_variables(n)%missing_value,imin,imax,jmin,jmax,0,kmax,ws)
         err = nf90_put_var(ncid,fabm_ids_diag(n),ws(_3D_W_),start,edges)
         if (err .NE.  NF90_NOERR) go to 10
      end do

      start(3) = n3d
      edges(3) = 1
      do n=1,size(model%bottom_state_variables)
         if (fabm_ids_ben(n)==-1) cycle
         call cnv_2d(imin,jmin,imax,jmax,az,fabm_ben(:,:,n), &
                     model%bottom_state_variables(n)%missing_value,imin,jmin,imax,jmax,ws2d)
         err = nf90_put_var(ncid,fabm_ids_ben(n),ws2d(_2D_W_),start(1:3),edges(1:3))
         if (err .NE.  NF90_NOERR) go to 10
      end do
      do n=1,size(model%horizontal_diagnostic_variables)
         if (fabm_ids_diag_hz(n)==-1) cycle
         call cnv_2d(imin,jmin,imax,jmax,az,fabm_diag_hz(:,:,n), &
                     model%horizontal_diagnostic_variables(n)%missing_value,imin,jmin,imax,jmax,ws2d)
         err = nf90_put_var(ncid,fabm_ids_diag_hz(n),ws2d(_2D_W_),start(1:3),edges(1:3))
         if (err .NE.  NF90_NOERR) go to 10
      end do

   end if
#endif

   if (sync_3d .ne. 0 .and. mod(n3d,sync_3d) .eq. 0) then
      err = nf90_sync(ncid)
      if (err .NE. NF90_NOERR) go to 10
   end if

   return

10 FATAL 'save_3d_ncdf: ',nf90_strerror(err)
   stop

   return
   end subroutine save_3d_ncdf
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
!-----------------------------------------------------------------------
