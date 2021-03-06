#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE:  bdy_3d - 3D boundary conditions \label{bdy-3d}
!
! !INTERFACE:
   module bdy_3d
!
! !DESCRIPTION:
!
! Here, the three-dimensional boundary
! conditions for temperature and salinity are handled.
!
! !USES:
   use halo_zones, only : H_TAG,U_TAG,V_TAG
   use domain, only: imin,jmin,imax,jmax,kmax,H,az,au,av
   use domain, only: nsbvl,nbdy,NOB,NWB,NNB,NEB,NSB,bdy_index,bdy_index_l
   use domain, only: bdy_3d_desc,bdy_3d_type
   use domain, only: need_3d_bdy
   use domain, only: wi,wfj,wlj,nj,nfi,nli,ei,efj,elj,sj,sfi,sli
   use time, only: write_time_string,timestr
   use variables_3d
#ifdef _FABM_
   use getm_fabm, only: fabm_calc,model,fabm_pel,fabm_ben
#endif
   use exceptions
   IMPLICIT NONE
!
   private
!
! !PUBLIC DATA MEMBERS:
   public init_bdy_3d, do_bdy_3d,do_bdy_3d_vel
#ifdef _FABM_
   public init_bdy_3d_fabm
#endif
   public bdy_3d_west,bdy_3d_north,bdy_3d_east,bdy_3d_south
   character(len=PATH_MAX),public         :: bdyfile_3d
   integer,public                         :: bdyfmt_3d
   integer,public                         :: bdy3d_ramp=-1
   logical,public                         :: bdy3d_vel=.false.
   integer,public                         :: bdy3d_sponge_size=3
   logical,public                         :: bdy3d_tmrlx=.false.
   REALTYPE,public                        :: bdy3d_tmrlx_ucut=_ONE_/50
   REALTYPE                               :: bdy3d_tmrlx_umin
   REALTYPE,public                        :: bdy3d_tmrlx_max=_ONE_/4
   REALTYPE,public                        :: bdy3d_tmrlx_min=_ZERO_

   REALTYPE,dimension(:,:),pointer,public :: bdy_data_uu=>null()
   REALTYPE,dimension(:,:),pointer,public :: bdy_data_vv=>null()
   REALTYPE,dimension(:,:),pointer,public :: bdy_data_S=>null()
   REALTYPE,dimension(:,:),pointer,public :: bdy_data_T=>null()
#ifdef _FABM_
   REALTYPE,allocatable,target,public     :: bio_bdy(:,:,:)
   integer,allocatable,public             :: have_bio_bdy_values(:)
   integer,allocatable,public             :: bdy_bio_type(:,:)
#endif
!
! !PRIVATE DATA MEMBERS:
   private bdy3d_active
   REALTYPE                            :: ramp=_ONE_
   logical                             :: ramp_is_active=.false.
   REALTYPE,         allocatable       :: sp(:)
#ifdef _FABM_
   integer                             :: npel=-1,nben=-1
#endif
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_bdy_3d - initialising 3D boundary conditions
! \label{sec-init-bdy-3d}
!
! !INTERFACE:
   subroutine init_bdy_3d(bdy3d,runtype,hotstart,update_salt,update_temp)
!
! !DESCRIPTION:
!
! Here, the necessary fields {\tt S\_bdy} and {\tt T\_bdy} for
! salinity and temperature, respectively, are allocated.
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: runtype
   logical, intent(in)                 :: hotstart,update_salt,update_temp
!
! !INPUT/OUTPUT PARAMETERS:
   logical, intent(inout)              :: bdy3d
!
! !LOCAL VARIABLES:
   integer                   :: i,j,l,n,shift, rc
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_bdy_3d() # ',Ncall
#endif

   LEVEL2 'init_bdy_3d()'

   if (bdy3d) then
      if (bdy3d_vel) then
         need_3d_bdy = .true.
      else
         do l=1,nbdy
            if (bdy3d_active(bdy_3d_type(l))) then
               need_3d_bdy = .true.
               exit
            end if
         end do
      end if
      if (.not. need_3d_bdy) then
         bdy3d = .false.
      end if
   else
      bdy3d_vel = .false.
      do l=1,nbdy
         if (bdy3d_active(bdy_3d_type(l)) .or. runtype.eq.3) then
            LEVEL3 'bdy3d=F resets local 3D bdy #',l
            LEVEL4 'old: ',trim(bdy_3d_desc(bdy_3d_type(l)))
            bdy_3d_type(l) = CONSTANT
            LEVEL4 'new: ',trim(bdy_3d_desc(bdy_3d_type(l)))
         end if
      end do
   end if


   if (bdy3d) then

      LEVEL3 'bdyfile_3d=',TRIM(bdyfile_3d)
      LEVEL3 'bdyfmt_3d=',bdyfmt_3d
      LEVEL3 'bdy3d_vel=',bdy3d_vel
      if (bdy3d_vel .and. bdy3d_ramp.gt.1) then
         LEVEL3 'bdy3d_ramp=',bdy3d_ramp
         if (hotstart) then
            LEVEL4 'WARNING: hotstart is .true. AND bdy3d_ramp .gt. 1'
            LEVEL4 'WARNING: .. be sure you know what you are doing ..'
         end if
      end if

      if (bdy3d_tmrlx) then
         LEVEL3 'bdy3d_tmrlx=.true.'
         LEVEL3 'bdy3d_tmrlx_max=   ',bdy3d_tmrlx_max
         LEVEL3 'bdy3d_tmrlx_min=   ',bdy3d_tmrlx_min
         LEVEL3 'bdy3d_tmrlx_ucut=  ',bdy3d_tmrlx_ucut
         if (bdy3d_tmrlx_min<_ZERO_ .or. bdy3d_tmrlx_min>_ONE_)          &
              call getm_error("init_3d()",                               &
              "bdy3d_tmrlx_min is out of valid range [0:1]")
         if (bdy3d_tmrlx_max<bdy3d_tmrlx_min .or. bdy3d_tmrlx_max>_ONE_) &
              call getm_error("init_3d()",                               &
              "bdy3d_tmrlx_max is out of valid range [bdy3d_tmrlx_min:1]")
         if (bdy3d_tmrlx_ucut<_ZERO_)                                    &
              call getm_error("init_3d()",                               &
              "bdy3d_tmrlx_max is out of valid range [0:inf[")

!        Hardcoding of lower limit of velocity cut-off for temporal relaxation.
!        Linear variation between bdy3d_tmrlx_umin and bdy3d_tmrlx_ucut.
         bdy3d_tmrlx_umin = -_QUART_*bdy3d_tmrlx_ucut
         LEVEL3 'bdy3d_tmrlx_umin=  ',bdy3d_tmrlx_umin
      end if

      if (bdy3d_vel) then
         allocate(bdy_data_uu(0:kmax,nsbvl),stat=rc)
         if (rc /= 0) stop 'init_bdy_3d: Error allocating memory (bdy_data_uu)'
         allocate(bdy_data_vv(0:kmax,nsbvl),stat=rc)
         if (rc /= 0) stop 'init_bdy_3d: Error allocating memory (bdy_data_vv)'
      end if

      if (update_salt) then
         allocate(bdy_data_S(0:kmax,nsbvl),stat=rc)
         if (rc /= 0) stop 'init_bdy_3d: Error allocating memory (bdy_data_S)'
      end if

      if (update_temp) then
         allocate(bdy_data_T(0:kmax,nsbvl),stat=rc)
         if (rc /= 0) stop 'init_bdy_3d: Error allocating memory (bdy_data_T)'
      end if

   end if


   if (bdy3d_sponge_size .gt. 0) then
      allocate(sp(bdy3d_sponge_size),stat=rc)
      if (rc /= 0) stop 'init_bdy_3d: Error allocating memory (sp)'

!     Sponge layer factors according to Martinsen and Engedahl, 1987.
!     Note (KK): factor=1 (bdy cell) does not count for sponge size
!                (in contrast to earlier GETM)
      LEVEL3 "sponge layer factors:"
      do i=1,bdy3d_sponge_size
         sp(i) = ((_ONE_+bdy3d_sponge_size-i)/(_ONE_+bdy3d_sponge_size))**2
         LEVEL4 "sp(",i,")=",real(sp(i))
      end do
   else
      bdy3d_sponge_size = 0
   end if

   l = 0
   do n = 1,NWB
      l = l+1
      i = wi(n)
      do j = wfj(n),wlj(n)
         if (az(i,j) .eq. 2) then
            select case (bdy_3d_type(l))
               case (CONSTANT,CLAMPED)
                  shift = bdy3d_sponge_size
               case (ZERO_GRADIENT)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( i+shift .gt. imax ) then
               FATAL 'local western bdy #',n,'too close to eastern subdomain edge'
               call getm_error('init_bdy_3d()', &
                               'western open bdy too close to eastern subdomain edge')
            else
               exit
            end if
         end if
      end do
   end do
   do n = 1,NNB
      l = l+1
      j = nj(n)
      do i = nfi(n),nli(n)
         if (az(i,j) .eq. 2) then
            select case (bdy_3d_type(l))
               case (CONSTANT,CLAMPED)
                  shift = bdy3d_sponge_size
               case (ZERO_GRADIENT)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( j-shift .lt. jmin ) then
               FATAL 'local northern bdy #',n,'too close to southern subdomain edge'
               call getm_error('init_bdy_3d()', &
                               'northern open bdy too close to southern subdomain edge')
            else
               exit
            end if
         end if
      end do
   end do
   do n = 1,NEB
      l = l+1
      i = ei(n)
      do j = efj(n),elj(n)
         if (az(i,j) .eq. 2) then
            select case (bdy_3d_type(l))
               case (CONSTANT,CLAMPED)
                  shift = bdy3d_sponge_size
               case (ZERO_GRADIENT)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( i-shift .lt. imin ) then
               FATAL 'local eastern bdy #',n,'too close to western subdomain edge'
               call getm_error('init_bdy_3d()', &
                               'eastern open bdy too close to western subdomain edge')
            else
               exit
            end if
         end if
      end do
   end do
   do n = 1,NSB
      l = l+1
      j = sj(n)
      do i = sfi(n),sli(n)
         if (az(i,j) .eq. 2) then
            select case (bdy_3d_type(l))
               case (CONSTANT,CLAMPED)
                  shift = bdy3d_sponge_size
               case (ZERO_GRADIENT)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( j+shift .gt. jmax ) then
               FATAL 'local southern bdy #',n,'too close to northern subdomain edge'
               call getm_error('init_bdy_3d()', &
                               'southern open bdy too close to northern subdomain edge')
            else
               exit
            end if
         end if
      end do
   end do


#ifdef DEBUG
   write(debug,*) 'Leaving init_bdy_3d()'
   write(debug,*)
#endif
   return
   end subroutine init_bdy_3d
!EOC

!-----------------------------------------------------------------------
#ifdef _FABM_
!BOP
!
! !IROUTINE: init_bdy_3d_fabm
!
! !INTERFACE:
   subroutine init_bdy_3d_fabm()
!
! !DESCRIPTION:
!
! !USES:
   use getm_fabm, only: model
   IMPLICIT NONE
!
! !LOCAL VARIABLES:
   integer                   :: rc
   integer                   :: npel
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_bdy_3d_fabm() # ',Ncall
#endif

   npel = size(model%state_variables)

   allocate(bdy_bio_type(NOB,npel),stat=rc)
   if (rc /= 0) stop 'init_bdy_3d_fabm: Error allocating memory (bdy_bio_type)'
   bdy_bio_type = ZERO_GRADIENT

   allocate(have_bio_bdy_values(npel),stat=rc)
   if (rc /= 0) stop 'init_bdy_3d_fabm: Error allocating memory (have_bio_bdy_values)'
   have_bio_bdy_values = -1

#ifdef DEBUG
   write(debug,*) 'Leaving init_bdy_3d_fabm()'
   write(debug,*)
#endif
   return
   end subroutine init_bdy_3d_fabm
!EOC
#endif

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  do_bdy_3d  - updating 3D boundary conditions
! \label{sec-do-bdy-3d}
!
! !INTERFACE:
   subroutine do_bdy_3d(update_salt,update_temp)
!
! !DESCRIPTION:
!
! Here, the boundary conditions for salinity and temperature are
! copied to the boundary points and relaxed to the near boundary points
! by means of the flow relaxation scheme by \cite{MARTINSENea87}.
!
! As an extention to the flow relaxation scheme, it is possible
! to relax the boundary point values to the specified boundary
! condition in time, thus giving more realistic situations
! especially for outgoing flow conditions. This nudging is implemented
! to depend on the local (3D) current velocity perpendicular to
! the boundary. For strong outflow, the boundary condition is turned
! off, while for inflows it is given a high impact.
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   logical, intent(in)                     :: update_salt,update_temp
!
! !LOCAL VARIABLES:
#ifndef _POINTER_REMAP_
   REALTYPE,dimension(0:kmax,nsbvl),target :: bdy_data
#endif
   REALTYPE,dimension(:,:),pointer         :: p_bdy_data,p2d
   integer                                 :: i,j,l,n,o
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_bdy_3d() # ',Ncall
#endif

#if 0
   select case (tag)
      case (1)
!       Lateral zero-gradient boundary condition (north & south)
         do k=1,kmax
            do i=imin,imax
               if (au(i,jmin) .eq. 3) field(i,jmin,k)=field(i,jmin+1,k)
               if (au(i,jmax) .eq. 3) field(i,jmax,k)=field(i,jmax-1,k)
            end do
         end do
      case (2)
!       Lateral zero-gradient boundary conditions (west & east)
         do k=1,kmax
            do j=jmin,jmax
               if (av(imin,j) .eq. 3) field(imin,j,k)=field(imin+1,j,k)
               if (av(imax,j) .eq. 3) field(imax,j,k)=field(imax-1,j,k)
            end do
         end do
      case default
         FATAL 'Non valid tag'
         stop 'do_bdy_3d'
   end select
#endif

#ifndef _POINTER_REMAP_
   p_bdy_data => bdy_data
#endif

#ifndef NO_BAROCLINIC

   l = 0
   do n=1,NWB
      l = l+1
      if (update_salt) call bdy_3d_west(l,n,bdy_3d_type(l),S,bdy_data_S)
      if (update_temp) call bdy_3d_west(l,n,bdy_3d_type(l),T,bdy_data_T)
#ifdef _FABM_
      if (fabm_calc) then
         i = wi(n)
         do j=wfj(n),wlj(n)
            fabm_ben(i,j,:) = fabm_ben(i+1,j,:)
         end do
         do o=1,size(model%state_variables)
            select case (bdy_bio_type(l,o))
               case(ZERO_GRADIENT)
                  call bdy_3d_west(l,n,ZERO_GRADIENT,fabm_pel(:,:,:,o))
               case(CLAMPED)
#ifdef _POINTER_REMAP_
                  p2d => bio_bdy(:,:,o) ; p_bdy_data(0:,1:) => p2d
#else
                  bdy_data = bio_bdy(:,:,o)
#endif
                  call bdy_3d_west(l,n,CLAMPED,fabm_pel(:,:,:,o),p_bdy_data)
            end select
         end do
      end if
#endif
   end do

   do n = 1,NNB
      l = l+1
      if (update_salt) call bdy_3d_north(l,n,bdy_3d_type(l),S,bdy_data_S)
      if (update_temp) call bdy_3d_north(l,n,bdy_3d_type(l),T,bdy_data_T)
#ifdef _FABM_
      if (fabm_calc) then
         j = nj(n)
         do i = nfi(n),nli(n)
            fabm_ben(i,j,:) = fabm_ben(i,j-1,:)
         end do
         do o=1,size(model%state_variables)
            select case (bdy_bio_type(l,o))
               case(ZERO_GRADIENT)
                  call bdy_3d_north(l,n,ZERO_GRADIENT,fabm_pel(:,:,:,o))
               case(CLAMPED)
#ifdef _POINTER_REMAP_
                  p2d => bio_bdy(:,:,o) ; p_bdy_data(0:,1:) => p2d
#else
                  bdy_data = bio_bdy(:,:,o)
#endif
                  call bdy_3d_north(l,n,CLAMPED,fabm_pel(:,:,:,o),p_bdy_data)
            end select
         end do
      end if
#endif
   end do

   do n=1,NEB
      l = l+1
      if (update_salt) call bdy_3d_east(l,n,bdy_3d_type(l),S,bdy_data_S)
      if (update_temp) call bdy_3d_east(l,n,bdy_3d_type(l),T,bdy_data_T)
#ifdef _FABM_
      if (fabm_calc) then
         i = ei(n)
         do j=efj(n),elj(n)
            fabm_ben(i,j,:) = fabm_ben(i-1,j,:)
         end do
         do o=1,size(model%state_variables)
            select case (bdy_bio_type(l,o))
               case(ZERO_GRADIENT)
                  call bdy_3d_east(l,n,ZERO_GRADIENT,fabm_pel(:,:,:,o))
               case(CLAMPED)
#ifdef _POINTER_REMAP_
                  p2d => bio_bdy(:,:,o) ; p_bdy_data(0:,1:) => p2d
#else
                  bdy_data = bio_bdy(:,:,o)
#endif
                  call bdy_3d_east(l,n,CLAMPED,fabm_pel(:,:,:,o),p_bdy_data)
            end select
         end do
      end if
#endif
   end do

   do n = 1,NSB
      l = l+1
      if (update_salt) call bdy_3d_south(l,n,bdy_3d_type(l),S,bdy_data_S)
      if (update_temp) call bdy_3d_south(l,n,bdy_3d_type(l),T,bdy_data_T)
#ifdef _FABM_
      if (fabm_calc) then
         j = sj(n)
         do i = sfi(n),sli(n)
            fabm_ben(i,j,:) = fabm_ben(i,j+1,:)
         end do
         do o=1,size(model%state_variables)
            select case (bdy_bio_type(l,o))
               case(ZERO_GRADIENT)
                  call bdy_3d_south(l,n,ZERO_GRADIENT,fabm_pel(:,:,:,o))
               case(CLAMPED)
#ifdef _POINTER_REMAP_
                  p2d => bio_bdy(:,:,o) ; p_bdy_data(0:,1:) => p2d
#else
                  bdy_data = bio_bdy(:,:,o)
#endif
                  call bdy_3d_south(l,n,CLAMPED,fabm_pel(:,:,:,o),p_bdy_data)
            end select
         end do
      end if
#endif
   end do

#ifdef _FABM_
   if (fabm_calc) then
      do n=1,size(model%state_variables)
         call mirror_bdy_3d(fabm_pel(:,:,:,n),H_TAG)
      end do
      do n=1,size(model%bottom_state_variables)
         call mirror_bdy_2d(fabm_ben(:,:,  n),H_TAG)
      end do
   end if
#endif
#endif

#ifdef DEBUG
   write(debug,*) 'leaving do_bdy_3d()'
   write(debug,*)
#endif
   return
   end subroutine do_bdy_3d
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  bdy_3d_west -
!
! !INTERFACE:
   subroutine bdy_3d_west(l,n,bdy_type,f,bdy_data)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT VARIABLES:
   integer,intent(in)                                  :: l,n,bdy_type
   REALTYPE,dimension(:,:),pointer,intent(in),optional :: bdy_data
!
! !INPUT/OUTPUT VARIABLES:
   REALTYPE,dimension(I3DFIELD),intent(inout)          :: f
!
! !LOCAL VARIABLES:
   REALTYPE,dimension(0:kmax) :: bdyvert,rlxcoef
   REALTYPE                   :: wsum
   integer                    :: i,k,kl,ii,j,kk
!EOP
!-----------------------------------------------------------------------
!BOC

   i = wi(n)

   select case (bdy_type)
      case(ZERO_GRADIENT)
         do j=wfj(n),wlj(n)
            f(i,j,:) = f(i+1,j,:)
         end do
      case(CLAMPED)
         k = bdy_index(l)
         kl = bdy_index_l(l)
         do j=wfj(n),wlj(n)
            if (az(i,j) .eq. 2) then
               if (bdy3d_tmrlx) then
!                 Temporal relaxation: Weight inner (actual) solution near boundary
!                 with boundary condition (outer solution.)
                  wsum = _ZERO_
                  bdyvert(:) = _ZERO_
                  do ii=1,bdy3d_sponge_size
!                    Get (weighted avr of) inner near-bdy solution (sponge) cells:
                     if(az(i+ii,j) .ne. 0) then
                        wsum = wsum + sp(ii)
                        bdyvert(:) = bdyvert(:) + sp(ii)*f(i+ii,j,:)
                     else
                        exit
                     end if
                  end do
                  if (wsum>_ZERO_) then
!                    Local temporal relaxation coeficient depends on
!                    local current just *inside* domain:
                     do kk=1,kmax
                        if (uu(i,j,kk).ge.bdy3d_tmrlx_ucut) then
                           rlxcoef(kk) = bdy3d_tmrlx_max
                        else if (uu(i,j,kk).le.bdy3d_tmrlx_umin) then
                           rlxcoef(kk) = bdy3d_tmrlx_min
                        else
                           rlxcoef(kk) = (bdy3d_tmrlx_max-bdy3d_tmrlx_min)    &
                                *(uu(i,j,kk)-bdy3d_tmrlx_umin)                &
                                /(bdy3d_tmrlx_ucut-bdy3d_tmrlx_umin)          &
                                + bdy3d_tmrlx_min
                        end if
                     end do
!                    Weight inner and outer (bc) solutions for use
!                    in spatial relaxation/sponge
                     f(i,j,:) = (_ONE_-rlxcoef(:))*bdyvert(:)/wsum + rlxcoef(:)*bdy_data(:,kl)
                  else
!                    No near-bdy points. Just clamp bdy temporally:
                     f(i,j,:) = bdy_data(:,kl)
                  end if
               else
!                 No time-relaxation. Just clamp at bondary points.
                  f(i,j,:) = bdy_data(:,kl)
               end if
            end if
            k = k+1
            kl = kl + 1
         end do
   end select

   if (bdy3d_sponge_size .gt. 0) then
      select case (bdy_type)
         case (CONSTANT,CLAMPED)
            do j = wfj(n),wlj(n)
               if (az(i,j) .eq. 2) then
                  do ii=1,bdy3d_sponge_size
                     if (az(i+ii,j) .eq. 1) then
                        f(i+ii,j,:) = sp(ii)*f(i,j,:)+(_ONE_-sp(ii))*f(i+ii,j,:)
                     else
                        exit
                     end if
                  end do
               end if
            end do
      end select
   end if

   return
   end subroutine bdy_3d_west
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  bdy_3d_north -
!
! !INTERFACE:
   subroutine bdy_3d_north(l,n,bdy_type,f,bdy_data)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT VARIABLES:
   integer,intent(in)                                  :: l,n,bdy_type
   REALTYPE,dimension(:,:),pointer,intent(in),optional :: bdy_data
!
! !INPUT/OUTPUT VARIABLES:
   REALTYPE,dimension(I3DFIELD),intent(inout)          :: f
!
! !LOCAL VARIABLES:
   REALTYPE,dimension(0:kmax) :: bdyvert,rlxcoef
   REALTYPE                   :: wsum
   integer                    :: j,k,kl,i,jj,kk
!EOP
!-----------------------------------------------------------------------
!BOC

   j = nj(n)

   select case (bdy_type)
      case(ZERO_GRADIENT)
         do i = nfi(n),nli(n)
            f(i,j,:) = f(i,j-1,:)
         end do
      case(CLAMPED)
         k = bdy_index(l)
         kl = bdy_index_l(l)
         do i = nfi(n),nli(n)
            if (az(i,j) .eq. 2) then
               if (bdy3d_tmrlx) then
!                 Temporal relaxation: Weight inner (actual) solution near boundary
!                 with boundary condition (outer solution.)
                  wsum = _ZERO_
                  bdyvert(:) = _ZERO_
                  do jj=1,bdy3d_sponge_size
!                    Get (weighted avr of) inner near-bdy solution (sponge) cells:
                     if(az(i,j-jj) .ne. 0) then
                        wsum = wsum + sp(jj)
                        bdyvert(:) = bdyvert(:) + sp(jj)*f(i,j-jj,:)
                     else
                        exit
                     end if
                  end do
                  if (wsum>_ZERO_) then
!                    Local temporal relaxation coeficient depends on
!                    local current just *inside* domain:
                     do kk=1,kmax
                        if (vv(i,j-1,kk).le.-bdy3d_tmrlx_ucut) then
                           rlxcoef(kk) = bdy3d_tmrlx_max
                        else if (vv(i,j-1,kk).ge.-bdy3d_tmrlx_umin) then
                           rlxcoef(kk) = bdy3d_tmrlx_min
                        else
                           rlxcoef(kk) = -(bdy3d_tmrlx_max-bdy3d_tmrlx_min)   &
                                *(vv(i,j-1,kk)+bdy3d_tmrlx_umin)              &
                                /(bdy3d_tmrlx_ucut-bdy3d_tmrlx_umin)          &
                                + bdy3d_tmrlx_min
                        end if
                     end do
!                    Weight inner and outer (bc) solutions for use
!                    in spatial relaxation/sponge
                     f(i,j,:) = (_ONE_-rlxcoef(:))*bdyvert(:)/wsum + rlxcoef(:)*bdy_data(:,kl)
                  else
!                    No near-bdy points. Just clamp bdy temporally:
                     f(i,j,:) = bdy_data(:,kl)
                  end if
               else
!                 No time-relaxation. Just clamp at bondary points.
                  f(i,j,:) = bdy_data(:,kl)
               end if
            end if
            k = k+1
            kl = kl + 1
         end do
   end select

   if (bdy3d_sponge_size .gt. 0) then
      select case (bdy_type)
         case (CONSTANT,CLAMPED)
            do i = nfi(n),nli(n)
               if (az(i,j) .eq. 2) then
                  do jj=1,bdy3d_sponge_size
                     if (az(i,j-jj) .eq. 1) then
                        f(i,j-jj,:) = sp(jj)*f(i,j,:)+(_ONE_-sp(jj))*f(i,j-jj,:)
                     else
                        exit
                     end if
                  end do
               end if
            end do
      end select
   end if

   return
   end subroutine bdy_3d_north
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  bdy_3d_east -
!
! !INTERFACE:
   subroutine bdy_3d_east(l,n,bdy_type,f,bdy_data)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT VARIABLES:
   integer,intent(in)                                  :: l,n,bdy_type
   REALTYPE,dimension(:,:),pointer,intent(in),optional :: bdy_data
!
! !INPUT/OUTPUT VARIABLES:
   REALTYPE,dimension(I3DFIELD),intent(inout)          :: f
!
! !LOCAL VARIABLES:
   REALTYPE,dimension(0:kmax) :: bdyvert,rlxcoef
   REALTYPE                   :: wsum
   integer                    :: i,k,kl,ii,j,kk
!EOP
!-----------------------------------------------------------------------
!BOC

   i = ei(n)

   select case (bdy_type)
      case(ZERO_GRADIENT)
         do j=efj(n),elj(n)
            f(i,j,:) = f(i-1,j,:)
         end do
      case(CLAMPED)
         k = bdy_index(l)
         kl = bdy_index_l(l)
         do j=efj(n),elj(n)
            if (az(i,j) .eq. 2) then
               if (bdy3d_tmrlx) then
!                 Temporal relaxation: Weight inner (actual) solution near boundary
!                 with boundary condition (outer solution.)
                  wsum = _ZERO_
                  bdyvert(:) = _ZERO_
                  do ii=1,bdy3d_sponge_size
!                    Get (weighted avr of) inner near-bdy solution (sponge) cells:
                     if(az(i-ii,j) .ne. 0) then
                        wsum = wsum + sp(ii)
                        bdyvert(:) = bdyvert(:) + sp(ii)*f(i-ii,j,:)
                     else
                        exit
                     end if
                  end do
                  if (wsum>_ZERO_) then
!                    Local temporal relaxation coeficient depends on
!                    local current just *inside* domain:
                     do kk=1,kmax
                        if (uu(i-1,j,kk).le.-bdy3d_tmrlx_ucut) then
                           rlxcoef(kk) = bdy3d_tmrlx_max
                        else if (uu(i-1,j,kk).ge.-bdy3d_tmrlx_umin) then
                           rlxcoef(kk) = bdy3d_tmrlx_min
                        else
                           rlxcoef(kk) = -(bdy3d_tmrlx_max-bdy3d_tmrlx_min)   &
                                *(uu(i-1,j,kk)+bdy3d_tmrlx_umin)              &
                                /(bdy3d_tmrlx_ucut-bdy3d_tmrlx_umin)          &
                                + bdy3d_tmrlx_min
                        end if
                     end do
!                    Weight inner and outer (bc) solutions for use
!                    in spatial relaxation/sponge
                     f(i,j,:) = (_ONE_-rlxcoef(:))*bdyvert(:)/wsum + rlxcoef(:)*bdy_data(:,kl)
                  else
!                    No near-bdy points. Just clamp bdy temporally:
                     f(i,j,:) = bdy_data(:,kl)
                  end if
               else
!                 No time-relaxation. Just clamp at bondary points.
                  f(i,j,:) = bdy_data(:,kl)
               end if
            end if
            k = k+1
            kl = kl + 1
         end do
   end select

   if (bdy3d_sponge_size .gt. 0) then
      select case (bdy_type)
         case (CONSTANT,CLAMPED)
            do j = efj(n),elj(n)
               if (az(i,j) .eq. 2) then
                  do ii=1,bdy3d_sponge_size
                     if (az(i-ii,j) .eq. 1) then
                        f(i-ii,j,:) = sp(ii)*f(i,j,:)+(_ONE_-sp(ii))*f(i-ii,j,:)
                     else
                        exit
                     end if
                  end do
               end if
            end do
      end select
   end if

   return
   end subroutine bdy_3d_east
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  bdy_3d_south -
!
! !INTERFACE:
   subroutine bdy_3d_south(l,n,bdy_type,f,bdy_data)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT VARIABLES:
   integer,intent(in)                                  :: l,n,bdy_type
   REALTYPE,dimension(:,:),pointer,intent(in),optional :: bdy_data
!
! !INPUT/OUTPUT VARIABLES:
   REALTYPE,dimension(I3DFIELD),intent(inout)          :: f
!
! !LOCAL VARIABLES:
   REALTYPE,dimension(0:kmax) :: bdyvert,rlxcoef
   REALTYPE                   :: wsum
   integer                    :: j,k,kl,i,jj,kk
!EOP
!-----------------------------------------------------------------------
!BOC

   j = sj(n)

   select case (bdy_type)
      case(ZERO_GRADIENT)
         do i = sfi(n),sli(n)
            f(i,j,:) = f(i,j+1,:)
         end do
      case(CLAMPED)
         k = bdy_index(l)
         kl = bdy_index_l(l)
         do i = sfi(n),sli(n)
            if (az(i,j) .eq. 2) then
               if (bdy3d_tmrlx) then
!                 Temporal relaxation: Weight inner (actual) solution near boundary
!                 with boundary condition (outer solution.)
                  wsum = _ZERO_
                  bdyvert(:) = _ZERO_
                  do jj=1,bdy3d_sponge_size
!                    Get (weighted avr of) inner near-bdy solution (sponge) cells:
                     if(az(i,j+jj) .ne. 0) then
                        wsum = wsum + sp(jj)
                        bdyvert(:) = bdyvert(:) + sp(jj)*f(i,j+jj,:)
                     else
                        exit
                     end if
                  end do
                  if (wsum>_ZERO_) then
!                    Local temporal relaxation coeficient depends on
!                    local current just *inside* domain:
                     do kk=1,kmax
                        if (vv(i,j,kk).ge.bdy3d_tmrlx_ucut) then
                           rlxcoef(kk) = bdy3d_tmrlx_max
                        else if (vv(i,j,kk).le.bdy3d_tmrlx_umin) then
                           rlxcoef(kk) = bdy3d_tmrlx_min
                        else
                           rlxcoef(kk) = (bdy3d_tmrlx_max-bdy3d_tmrlx_min)    &
                                *(vv(i,j,kk)-bdy3d_tmrlx_umin)                &
                                /(bdy3d_tmrlx_ucut-bdy3d_tmrlx_umin)          &
                                + bdy3d_tmrlx_min
                        end if
                     end do
!                    Weight inner and outer (bc) solutions for use
!                    in spatial relaxation/sponge
                     f(i,j,:) = (_ONE_-rlxcoef(:))*bdyvert(:)/wsum + rlxcoef(:)*bdy_data(:,kl)
                  else
!                    No near-bdy points. Just clamp bdy temporally:
                     f(i,j,:) = bdy_data(:,kl)
                  end if
               else
!                 No time-relaxation. Just clamp at bondary points.
                  f(i,j,:) = bdy_data(:,kl)
               end if
            end if
            k = k+1
            kl = kl + 1
         end do
   end select

   if (bdy3d_sponge_size .gt. 0) then
      select case (bdy_type)
         case (CONSTANT,CLAMPED)
            do i = sfi(n),sli(n)
               if (az(i,j) .eq. 2) then
                  do jj=1,bdy3d_sponge_size
                     if (az(i,j+jj) .eq. 1) then
                        f(i,j+jj,:) = sp(jj)*f(i,j,:)+(_ONE_-sp(jj))*f(i,j+jj,:)
                     else
                        exit
                     end if
                  end do
               end if
            end do
      end select
   end if

   return
   end subroutine bdy_3d_south
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  do_bdy_3d_vel  - consider bdy velocity profiles
! \label{sec-do-bdy-3d-vel}
!
! !INTERFACE:
   subroutine do_bdy_3d_vel(loop,tag)
!
! !DESCRIPTION:
!
! !USES:
   use domain, only: rigid_lid
   use waves, only: waveforcing_method,NO_WAVES
   use variables_waves, only: uuStokes,vvStokes
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: loop,tag
!
! !INPUT/OUTPUT PARAMETERS:
!
! !LOCAL VARIABLES:
   logical,save              :: first=.true.
   logical,save              :: no_shift=.false.
   REALTYPE                  :: bdy_transport,Diff
   integer                   :: i,j,k,kl,l,n
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_bdy_3d_vel() # ',Ncall
#endif

   if (.not. bdy3d_vel) return

   if (first) then
#ifdef NO_BAROTROPIC
      no_shift = .true.
#else
#ifdef SLICE_MODEL
      no_shift = rigid_lid
#endif
#endif
      first = .false.
   end if

!  Data read - do time interpolation

   if (ramp_is_active) then
      if (loop .ge. bdy3d_ramp) then
         ramp = _ONE_
         ramp_is_active = .false.
         STDERR LINE
         call write_time_string()
         LEVEL3 timestr,': finished bdy3d_ramp=',bdy3d_ramp
         STDERR LINE
      else
         ramp = _ONE_*loop/bdy3d_ramp
      end if
   end if

   select case (tag)

      case (U_TAG)

         l = 0
         do n = 1,NWB
            l = l+1
            kl = bdy_index_l(l)
            i = wi(n)
            do j = wfj(n),wlj(n)
               bdy_transport = _ZERO_
               do k=kumin(i,j),kmax
                  bdy_transport = bdy_transport + hun(i,j,k)*bdy_data_uu(k,kl)
               end do
               Diff = ( Uadv(i,j) - ramp*bdy_transport ) / Dun(i,j)
               do k=kumin(i,j),kmax
#ifndef NO_BAROTROPIC
                  uu(i,j,k) = hun(i,j,k) * ( ramp*bdy_data_uu(k,kl) + Diff )
#else
                  uu(i,j,k) = hun(i,j,k) * ramp * bdy_data_uu(k,kl)
#endif
                  if (waveforcing_method .ne. NO_WAVES) then
                     uuEuler(i,j,k) = uu(i,j,k) - uuStokes(i,j,k)
                  end if
               end do
               kl = kl + 1
            end do
         end do
         l = l + NNB
         do n = 1,NEB
            l = l+1
            kl = bdy_index_l(l)
            i = ei(n)
            do j = efj(n),elj(n)
               bdy_transport = _ZERO_
               do k=kumin(i-1,j),kmax
                  bdy_transport = bdy_transport + hun(i-1,j,k)*bdy_data_uu(k,kl)
               end do
               Diff = ( Uadv(i-1,j) - ramp*bdy_transport ) / Dun(i-1,j)
               do k=kumin(i-1,j),kmax
#ifndef NO_BAROTROPIC
                  uu(i-1,j,k) = hun(i-1,j,k) * ( ramp*bdy_data_uu(k,kl) + Diff )
#else
                  uu(i-1,j,k) = hun(i-1,j,k) * ramp * bdy_data_uu(k,kl)
#endif
                  if (waveforcing_method .ne. NO_WAVES) then
                     uuEuler(i,j,k) = uu(i,j,k) - uuStokes(i,j,k)
                  end if
               end do
               kl = kl + 1
            end do
         end do

      case (V_TAG)

         l = NWB
         do n = 1,NNB
            l = l+1
            kl = bdy_index_l(l)
            j = nj(n)
            do i = nfi(n),nli(n)
               bdy_transport = _ZERO_
               do k=kvmin(i,j-1),kmax
                  bdy_transport = bdy_transport + hvn(i,j-1,k)*bdy_data_vv(k,kl)
               end do
               Diff = ( Vadv(i,j-1) - ramp*bdy_transport ) / Dvn(i,j-1)
               do k=kvmin(i,j-1),kmax
                  if (no_shift) then
                     vv(i,j-1,k) = hvn(i,j-1,k) * ramp * bdy_data_vv(k,kl)
                  else
                     vv(i,j-1,k) = hvn(i,j-1,k) * ( ramp*bdy_data_vv(k,kl) + Diff )
                  end if
                  if (waveforcing_method .ne. NO_WAVES) then
                     vvEuler(i,j,k) = vv(i,j,k) - vvStokes(i,j,k)
                  end if
               end do
               kl = kl + 1
            end do
         end do
         l = l + NEB
         do n = 1,NSB
            l = l+1
            kl = bdy_index_l(l)
            j = sj(n)
            do i = sfi(n),sli(n)
               bdy_transport = _ZERO_
               do k=kvmin(i,j),kmax
                  bdy_transport = bdy_transport + hvn(i,j,k)*bdy_data_vv(k,kl)
               end do
               Diff = ( Vadv(i,j) - ramp*bdy_transport ) / Dvn(i,j)
               do k=kvmin(i,j),kmax
                  if (no_shift) then
                     vv(i,j,k) = hvn(i,j,k) * ramp * bdy_data_vv(k,kl)
                  else
                     vv(i,j,k) = hvn(i,j,k) * ( ramp*bdy_data_vv(k,kl) + Diff )
                  end if
                  if (waveforcing_method .ne. NO_WAVES) then
                     vvEuler(i,j,k) = vv(i,j,k) - vvStokes(i,j,k)
                  end if
               end do
               kl = kl + 1
            end do
         end do

   end select

#ifdef DEBUG
   write(debug,*) 'leaving do_bdy_3d_vel()'
   write(debug,*)
#endif
   return
   end subroutine do_bdy_3d_vel
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  LOGICAL function bdy3d_active -
!
! !INTERFACE:
   logical function bdy3d_active(type_3d)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer,intent(in)  :: type_3d
!
! !REVISION HISTORY:
!  Original author(s): Knut Klingbeil
!EOP
!-----------------------------------------------------------------------
!BOC

   select case (type_3d)
      case (CONSTANT)
         bdy3d_active = .false.
      case (CLAMPED)
         bdy3d_active = .true.
      case (ZERO_GRADIENT)
         bdy3d_active = .false.
      case default
         bdy3d_active = .false.
   end select

   return
   end function bdy3d_active
!EOC
!-----------------------------------------------------------------------

   end module bdy_3d

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Karsten Bolding and Hans Burchard               !
!-----------------------------------------------------------------------
