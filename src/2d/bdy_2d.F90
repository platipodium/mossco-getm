#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE:  bdy_2d - 2D boundary conditions \label{bdy-2d}
!
! !INTERFACE:
   module bdy_2d
!
! !DESCRIPTION:
!
! Here, the two-dimensional boundary
! conditions for sea surface elevation and transports are handled.
!
! !USES:
   use parameters,only: g
   use halo_zones, only : z_TAG,H_TAG,U_TAG,V_TAG
   use domain, only: imin,jmin,imax,jmax,kmax,H,az,au,av
   use domain, only: nsbv,nsbvl,nbdy,NWB,NNB,NEB,NSB,bdy_index,bdy_index_l
   use domain, only: bdy_2d_desc,bdy_2d_type
   use domain, only: need_2d_bdy_elev,need_2d_bdy_u,need_2d_bdy_v
   use domain, only: wi,wfj,wlj,nj,nfi,nli,ei,efj,elj,sj,sfi,sli
   use domain, only: min_depth
   use domain, only: rigid_lid
   use time, only: write_time_string,timestr
   use variables_2d, only: dtm,z,zo,D,U,DU,V,DV,UEuler,VEuler
   use waves, only: waveforcing_method,NO_WAVES
   use variables_waves, only: UStokes,VStokes
   use domain, only: dxu,dyv
   use exceptions

   IMPLICIT NONE
!
   private
!
! !PUBLIC DATA MEMBERS:
   public init_bdy_2d, do_bdy_2d
   character(len=PATH_MAX),public       :: bdyfile_2d
   integer,public                       :: bdyfmt_2d
   integer,public                       :: bdy2d_ramp=-1
   integer,public                       :: bdy2d_sponge_size=0
   REALTYPE,dimension(:),pointer,public :: bdy_data,bdy_data_u,bdy_data_v
!
! !PRIVATE DATA MEMBERS:
   private bdy2d_active,bdy2d_need_elev,bdy2d_need_vel
   REALTYPE                             :: ramp=_ONE_
   logical                              :: ramp_is_active=.false.
   REALTYPE,dimension(:),allocatable    :: sp(:)
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
! !IROUTINE: init_bdy_2d - initialising 2D boundary conditions
! \label{sec-init-bdy-2d}
!
! !INTERFACE:
   subroutine init_bdy_2d(bdy2d,hotstart)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   logical, intent(in)                 :: hotstart
!
! !INPUT/OUTPUT PARAMETERS:
   logical, intent(inout)              :: bdy2d
!
! !LOCAL VARIABLES:
   integer :: i,j,n,l,shift, rc
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_bdy_2d() # ',Ncall
#endif

   LEVEL2 'init_bdy_2d'

   if (rigid_lid) then
      do l=1,nbdy
         select case (bdy_2d_type(l))
            case (CLAMPED)
               LEVEL3 'rigid lid resets local 2D bdy #',l
               LEVEL4 'old: ',trim(bdy_2d_desc(bdy_2d_type(l)))
               bdy_2d_type(l) = CLAMPED_VEL
               LEVEL4 'new: ',trim(bdy_2d_desc(bdy_2d_type(l)))
            case (ZERO_GRADIENT,SOMMERFELD,CLAMPED_ELEV,FLATHER_ELEV)
               LEVEL3 'rigid lid resets local 2D bdy #',l
               LEVEL4 'old: ',trim(bdy_2d_desc(bdy_2d_type(l)))
               bdy_2d_type(l) = CONSTANT
               LEVEL4 'new: ',trim(bdy_2d_desc(bdy_2d_type(l)))
            case (FLATHER_VEL)
               LEVEL3 'rigid lid resets local 2D bdy #',l
               LEVEL4 'old: ',trim(bdy_2d_desc(bdy_2d_type(l)))
               bdy_2d_type(l) = CLAMPED_VEL
               LEVEL4 'new: ',trim(bdy_2d_desc(bdy_2d_type(l)))
         end select
      end do
   end if


   if (bdy2d) then

      do l=1,nbdy
         if (bdy2d_need_elev(bdy_2d_type(l))) then
            need_2d_bdy_elev = .true.
            exit
         end if
      end do

      l = 0
      do n = 1,NWB
         l = l+1
         if (bdy2d_need_vel(bdy_2d_type(l))) then
            need_2d_bdy_u = .true.
            exit
         end if
      end do
      if (.not. need_2d_bdy_u) then
         l = l + NNB
         do n = 1,NEB
            l = l+1
            if (bdy2d_need_vel(bdy_2d_type(l))) then
               need_2d_bdy_u = .true.
               exit
            end if
         end do
      end if

      l = NWB
      do n = 1,NNB
         l = l+1
         if (bdy2d_need_vel(bdy_2d_type(l))) then
            need_2d_bdy_v = .true.
            exit
         end if
      end do
      if (.not. need_2d_bdy_v) then
         l = l + NEB
         do n = 1,NSB
            l = l+1
            if (bdy2d_need_vel(bdy_2d_type(l))) then
               need_2d_bdy_v = .true.
               exit
            end if
         end do
      end if

      if (need_2d_bdy_elev .or. need_2d_bdy_u .or. need_2d_bdy_v) then
         LEVEL3 'bdyfile_2d=',TRIM(bdyfile_2d)
         LEVEL3 'bdyfmt_2d=',bdyfmt_2d
         if (bdy2d_ramp .gt. 1) then
            LEVEL3 'bdy2d_ramp=',bdy2d_ramp
            ramp_is_active = .true.
            if (hotstart) then
               LEVEL4 'WARNING: hotstart is .true. AND bdy2d_ramp .gt. 1'
               LEVEL4 'WARNING: .. be sure you know what you are doing ..'
            end if
         end if
         if (need_2d_bdy_elev) then
            allocate(bdy_data(nsbvl),stat=rc)
            if (rc /= 0) stop 'init_bdy_2d: Error allocating memory (bdy_data)'
         end if
         if (need_2d_bdy_u) then
            allocate(bdy_data_u(nsbvl),stat=rc)
            if (rc /= 0) stop 'init_bdy_2d: Error allocating memory (bdy_data_u)'
         end if
         if (need_2d_bdy_v) then
            allocate(bdy_data_v(nsbvl),stat=rc)
            if (rc /= 0) stop 'init_bdy_2d: Error allocating memory (bdy_data_v)'
         end if
      else
         bdy2d = .false.
      end if

   else

      do l=1,nbdy
         if (bdy2d_active(bdy_2d_type(l))) then
            LEVEL3 'bdy2d=F resets local 2D bdy #',l
            LEVEL4 'old: ',trim(bdy_2d_desc(bdy_2d_type(l)))
            bdy_2d_type(l) = CONSTANT
            LEVEL4 'new: ',trim(bdy_2d_desc(bdy_2d_type(l)))
         end if
      end do

   end if

   if (bdy2d_sponge_size .gt. 0) then
      allocate(sp(bdy2d_sponge_size),stat=rc)
      if (rc /= 0) stop 'init_bdy_2d: Error allocating memory (sp)'

!        Sponge layer factors according to Martinsen and Engedahl, 1987.
!        Note (KK): factor=1 (bdy cell) does not count for sponge size
!                   (in contrast to earlier GETM)
      LEVEL3 "sponge layer factors for surface elevation:"
      do i=1,bdy2d_sponge_size
         sp(i) = ((_ONE_+bdy2d_sponge_size-i)/(_ONE_+bdy2d_sponge_size))**2
         LEVEL4 "sp(",i,")=",real(sp(i))
      end do
   else
      bdy2d_sponge_size = 0
   end if

   l = 0
   do n = 1,NWB
      l = l+1
      i = wi(n)
      do j = wfj(n),wlj(n)
         if (az(i,j) .eq. 2) then
            select case (bdy_2d_type(l))
               case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                  shift = bdy2d_sponge_size
               case (ZERO_GRADIENT,SOMMERFELD,CLAMPED_VEL,FLATHER_VEL)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( i+shift .gt. imax ) then
               FATAL 'local western bdy #',n,'too close to eastern subdomain edge'
               call getm_error('init_bdy_2d()', &
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
            select case (bdy_2d_type(l))
               case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                  shift = bdy2d_sponge_size
               case (ZERO_GRADIENT,SOMMERFELD,CLAMPED_VEL,FLATHER_VEL)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( j-shift .lt. jmin ) then
               FATAL 'local northern bdy #',n,'too close to southern subdomain edge'
               call getm_error('init_bdy_2d()', &
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
            select case (bdy_2d_type(l))
               case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                  shift = bdy2d_sponge_size
               case (ZERO_GRADIENT,SOMMERFELD,CLAMPED_VEL,FLATHER_VEL)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( i-shift .lt. imin ) then
               FATAL 'local eastern bdy #',n,'too close to western subdomain edge'
               call getm_error('init_bdy_2d()', &
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
            select case (bdy_2d_type(l))
               case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                  shift = bdy2d_sponge_size
               case (ZERO_GRADIENT,SOMMERFELD,CLAMPED_VEL,FLATHER_VEL)
                  shift = 1
               case default
                  shift = 0
            end select
            if ( j+shift .gt. jmax ) then
               FATAL 'local southern bdy #',n,'too close to northern subdomain edge'
               call getm_error('init_bdy_2d()', &
                               'southern open bdy too close to northern subdomain edge')
            else
               exit
            end if
         end if
      end do
   end do


#ifdef DEBUG
   write(debug,*) 'Leaving init_bdy_2d()'
   write(debug,*)
#endif
   return
   end subroutine init_bdy_2d
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  do_bdy_2d  - updating 2D boundary conditions
! \label{sec-do-bdy-2d}
!
! !INTERFACE:
   subroutine do_bdy_2d(loop,tag)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: loop,tag
!
! !INPUT/OUTPUT PARAMETERS:
!
! !LOCAL VARIABLES:
   REALTYPE                  :: cfl,depth,a
   integer                   :: i,j,k,ii,jj,kl,l,n
   REALTYPE, parameter       :: theta = _HALF_
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_bdy_2d() # ',Ncall
#endif

#if 0
   select case (bdyfmt_2d)
      case (NO_DATA)
      case (ANALYTICAL)
      case (ASCII)
      case (NETCDF)
!        Read in get_2d_bdy() via get_2d_bdy_ncdf()
      case default
         stop 'do_bdy_2d(): invalid bdyfmt_2d'
   end select
#endif

!  Data read - do time interpolation

   if (ramp_is_active) then
      if (loop .ge. bdy2d_ramp) then
         ramp = _ONE_
         ramp_is_active = .false.
         STDERR LINE
         call write_time_string()
         LEVEL3 timestr,': finished bdy2d_ramp=',bdy2d_ramp
         STDERR LINE
      else
         ramp = _ONE_*loop/bdy2d_ramp
      end if
   end if

   select case (tag)

      case (z_TAG,H_TAG)

         l = 0
         do n = 1,NWB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            i = wi(n)
            select case (bdy_2d_type(l))
               case (ZERO_GRADIENT,CLAMPED_VEL,FLATHER_VEL)
                  do j = wfj(n),wlj(n)
                     z(i,j) = z(i+1,j)
                  end do
               case (SOMMERFELD)
                  do j = wfj(n),wlj(n)
                     cfl = sqrt(g*_HALF_*(D(i,j)+D(i+1,j)))*dtm/DXU
                     z(i,j) = (                                             &
                                (_ONE_ - _TWO_*cfl*(_ONE_-theta))*z (i  ,j) &
                               +(_ONE_ + _TWO_*cfl*(_ONE_-theta))*zo(i+1,j) &
                               -(_ONE_ - _TWO_*cfl*theta        )*z (i+1,j) &
                              )/(_ONE_ + _TWO_*cfl*theta        )
                  end do
               case (CLAMPED_ELEV,CLAMPED)
                  do j = wfj(n),wlj(n)
                     z(i,j) = max(ramp*bdy_data(kl),-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
               case (FLATHER_ELEV)
                  do j = wfj(n),wlj(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j)+D(i+1,j))
!                    Note (KK): note approximation of sse at vel-time stage
                     a = ramp*bdy_data(kl) &
                         - _TWO_/sqrt(g*depth)*(U(i,j)-ramp*bdy_data_u(kl)*depth)
                     z(i,j) = max(a,-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do
         do n = 1,NNB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            j = nj(n)
            select case (bdy_2d_type(l))
               case (ZERO_GRADIENT,CLAMPED_VEL,FLATHER_VEL)
                  do i = nfi(n),nli(n)
                     z(i,j) = z(i,j-1)
                  end do
               case (SOMMERFELD)
                  do i = nfi(n),nli(n)
                     cfl = sqrt(g*_HALF_*(D(i,j-1)+D(i,j)))*dtm/DYVJM1
                     z(i,j) = (                                             &
                                (_ONE_ - _TWO_*cfl*(_ONE_-theta))*z (i,j  ) &
                               +(_ONE_ + _TWO_*cfl*(_ONE_-theta))*zo(i,j-1) &
                               -(_ONE_ - _TWO_*cfl*theta        )*z (i,j-1) &
                              )/(_ONE_ + _TWO_*cfl*theta        )
                  end do
               case (CLAMPED_ELEV,CLAMPED)
                  do i = nfi(n),nli(n)
                     z(i,j) = max(ramp*bdy_data(kl),-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
               case (FLATHER_ELEV)
                  do i = nfi(n),nli(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j-1)+D(i,j))
!                    Note (KK): note approximation of sse at vel-time stage
                     a = ramp*bdy_data(kl) &
                         + _TWO_/sqrt(g*depth)*(V(i,j-1)-ramp*bdy_data_v(kl)*depth)
                     z(i,j) = max(a,-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do
         do n = 1,NEB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            i = ei(n)
            select case (bdy_2d_type(l))
               case (ZERO_GRADIENT,CLAMPED_VEL,FLATHER_VEL)
                  do j = efj(n),elj(n)
                     z(i,j) = z(i-1,j)
                  end do
               case (SOMMERFELD)
                  do j = efj(n),elj(n)
                     cfl = sqrt(g*_HALF_*(D(i-1,j)+D(i,j)))*dtm/DXUIM1
                     z(i,j) = (                                             &
                                (_ONE_ - _TWO_*cfl*(_ONE_-theta))*z (i  ,j) &
                               +(_ONE_ + _TWO_*cfl*(_ONE_-theta))*zo(i-1,j) &
                               -(_ONE_ - _TWO_*cfl*theta        )*z (i-1,j) &
                              )/(_ONE_ + _TWO_*cfl*theta        )
                  end do
               case (CLAMPED_ELEV,CLAMPED)
                  do j = efj(n),elj(n)
                     z(i,j) = max(ramp*bdy_data(kl),-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
               case (FLATHER_ELEV)
                  do j = efj(n),elj(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i-1,j)+D(i,j))
!                    Note (KK): note approximation of sse at vel-time stage
                     a = ramp*bdy_data(kl) &
                         + _TWO_/sqrt(g*depth)*(U(i-1,j)-ramp*bdy_data_u(kl)*depth)
                     z(i,j) = max(a,-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do
         do n = 1,NSB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            j = sj(n)
            select case (bdy_2d_type(l))
               case (ZERO_GRADIENT,CLAMPED_VEL,FLATHER_VEL)
                  do i = sfi(n),sli(n)
                     z(i,j) = z(i,j+1)
                  end do
               case (SOMMERFELD)
                  do i = sfi(n),sli(n)
                     cfl = sqrt(g*_HALF_*(D(i,j)+D(i,j+1)))*dtm/DYV
                     z(i,j) = (                                             &
                                (_ONE_ - _TWO_*cfl*(_ONE_-theta))*z (i,j  ) &
                               +(_ONE_ + _TWO_*cfl*(_ONE_-theta))*zo(i,j+1) &
                               -(_ONE_ - _TWO_*cfl*theta        )*z (i,j+1) &
                              )/(_ONE_ + _TWO_*cfl*theta        )
                  end do
               case (CLAMPED_ELEV,CLAMPED)
                  do i = sfi(n),sli(n)
                     z(i,j) = max(ramp*bdy_data(kl),-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
               case (FLATHER_ELEV)
                  do i = sfi(n),sli(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j)+D(i,j+1))
!                    Note (KK): note approximation of sse at vel-time stage
                     a = ramp*bdy_data(kl) &
                         - _TWO_/sqrt(g*depth)*(V(i,j)-ramp*bdy_data_v(kl)*depth)
                     z(i,j) = max(a,-H(i,j)+min_depth)
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do

         if (bdy2d_sponge_size .gt. 0) then
            l = 0
            do n = 1,NWB
               l = l+1
               select case (bdy_2d_type(l))
                  case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                     i = wi(n)
                     do j = wfj(n),wlj(n)
                        if (az(i,j) .eq. 2) then
                           do ii=1,bdy2d_sponge_size
                              if (az(i+ii,j) .eq. 1) then
                                 z(i+ii,j) = sp(ii)*z(i,j)+(_ONE_-sp(ii))*z(i+ii,j)
                              else
                                 exit
                              end if
                           end do
                        end if
                     end do
               end select
            end do
            do n = 1,NNB
               l = l+1
               select case (bdy_2d_type(l))
                  case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                     j = nj(n)
                     do i = nfi(n),nli(n)
                        if (az(i,j) .eq. 2) then
                           do jj=1,bdy2d_sponge_size
                              if (az(i,j-jj) .eq. 1) then
                                 z(i,j-jj) = sp(jj)*z(i,j)+(_ONE_-sp(jj))*z(i,j-jj)
                              else
                                 exit
                              end if
                           end do
                        end if
                     end do
               end select
            end do
            do n = 1,NEB
               l = l+1
               select case (bdy_2d_type(l))
                  case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                     i = ei(n)
                     do j = efj(n),elj(n)
                        if (az(i,j) .eq. 2) then
                           do ii=1,bdy2d_sponge_size
                              if (az(i-ii,j) .eq. 1) then
                                 z(i-ii,j) = sp(ii)*z(i,j)+(_ONE_-sp(ii))*z(i-ii,j)
                              else
                                 exit
                              end if
                           end do
                        end if
                     end do
               end select
            end do
            do n = 1,NSB
               l = l+1
               select case (bdy_2d_type(l))
                  case (CONSTANT,CLAMPED_ELEV,CLAMPED)
                     j = sj(n)
                     do i = sfi(n),sli(n)
                        if (az(i,j) .eq. 2) then
                           do jj=1,bdy2d_sponge_size
                              if (az(i,j+jj) .eq. 1) then
                                 z(i,j+jj) = sp(jj)*z(i,j)+(_ONE_-sp(jj))*z(i,j+jj)
                              else
                                 exit
                              end if
                           end do
                        end if
                     end do
               end select
            end do
         end if


      case (U_TAG)

         l = 0
         do n = 1,NWB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            i = wi(n)
            select case (bdy_2d_type(l))
               case (FLATHER_VEL)
                  do j = wfj(n),wlj(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j)+D(i+1,j))
!                    Note (KK): note approximation of sse at vel-time stage
                     U(i,j) = ramp*bdy_data_u(kl)*depth &
                              - _HALF_*sqrt(g*depth)*(z(i,j)-ramp*bdy_data(kl))
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        UEuler(i,j) = U(i,j) - UStokes(i,j)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
               case (CLAMPED_VEL,CLAMPED)
                  do j = wfj(n),wlj(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j)+D(i+1,j))
                     U(i,j) = ramp*bdy_data_u(kl)*depth
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        UEuler(i,j) = U(i,j) - UStokes(i,j)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do
         l = l + NNB
         do n = 1,NEB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            i = ei(n)
            select case (bdy_2d_type(l))
               case (FLATHER_VEL)
                  do j = efj(n),elj(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i-1,j)+D(i,j))
!                    Note (KK): note approximation of sse at vel-time stage
                     U(i-1,j) = ramp*bdy_data_u(kl)*depth &
                                + _HALF_*sqrt(g*depth)*(z(i,j)-ramp*bdy_data(kl))
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        UEuler(i-1,j) = U(i-1,j) - UStokes(i-1,j)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
               case (CLAMPED_VEL,CLAMPED)
                  do j = efj(n),elj(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i-1,j)+D(i,j))
                     U(i-1,j) = ramp*bdy_data_u(kl)*depth
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        UEuler(i-1,j) = U(i-1,j) - UStokes(i-1,j)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do

      case (V_TAG)

         l = NWB
         do n = 1,NNB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            j = nj(n)
            select case (bdy_2d_type(l))
               case (FLATHER_VEL)
                  do i = nfi(n),nli(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j-1)+D(i,j))
!                    Note (KK): note approximation of sse at vel-time stage
                     V(i,j-1) = ramp*bdy_data_v(kl)*depth &
                                + _HALF_*sqrt(g*depth)*(z(i,j)-ramp*bdy_data(kl))
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        VEuler(i,j-1) = V(i,j-1) - VStokes(i,j-1)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
               case (CLAMPED_VEL,CLAMPED)
                  do i = nfi(n),nli(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j-1)+D(i,j))
                     V(i,j-1) = ramp*bdy_data_v(kl)*depth
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        VEuler(i,j-1) = V(i,j-1) - VStokes(i,j-1)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do
         l = l + NEB
         do n = 1,NSB
            l = l+1
            k = bdy_index(l)
            kl = bdy_index_l(l)
            j = sj(n)
            select case (bdy_2d_type(l))
               case (FLATHER_VEL)
                  do i = sfi(n),sli(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j)+D(i,j+1))
!                    Note (KK): note approximation of sse at vel-time stage
                     V(i,j) = ramp*bdy_data_v(kl)*depth &
                              - _HALF_*sqrt(g*depth)*(z(i,j)-ramp*bdy_data(kl))
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        VEuler(i,j) = V(i,j) - VStokes(i,j)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
               case (CLAMPED_VEL,CLAMPED)
                  do i = sfi(n),sli(n)
!                    Note (KK): approximate interface depths at vel-time stage
!                               by spatial mean at last sse-time stage
                     depth = _HALF_*(D(i,j)+D(i,j+1))
                     V(i,j) = ramp*bdy_data_v(kl)*depth
                     if ( waveforcing_method .ne. NO_WAVES ) then
                        VEuler(i,j) = V(i,j) - VStokes(i,j)
                     end if
                     k = k+1
                     kl = kl + 1
                  end do
            end select
         end do

   end select

#ifdef DEBUG
   write(debug,*) 'leaving do_bdy_2d()'
   write(debug,*)
#endif
   return
   end subroutine do_bdy_2d
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  LOGICAL function bdy2d_active -
!
! !INTERFACE:
   logical function bdy2d_active(type_2d)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer,intent(in)  :: type_2d
!
! !REVISION HISTORY:
!  Original author(s): Knut Klingbeil
!EOP
!-----------------------------------------------------------------------
!BOC

   select case (type_2d)
      case (CONSTANT)
         bdy2d_active = .false.
      case (CLAMPED)
         bdy2d_active = .true.
      case (ZERO_GRADIENT)
         bdy2d_active = .false.
      case (SOMMERFELD)
         bdy2d_active = .false.
      case (CLAMPED_ELEV)
         bdy2d_active = .true.
      case (FLATHER_ELEV)
         bdy2d_active = .true.
      case (FLATHER_VEL)
         bdy2d_active = .true.
      case (CLAMPED_VEL)
         bdy2d_active = .true.
      case default
         bdy2d_active = .false.
   end select

   return
   end function bdy2d_active
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  LOGICAL function bdy2d_need_elev -
!
! !INTERFACE:
   logical function bdy2d_need_elev(type_2d)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer,intent(in)  :: type_2d
!
! !REVISION HISTORY:
!  Original author(s): Knut Klingbeil
!EOP
!-----------------------------------------------------------------------
!BOC

   select case (type_2d)
      case (CONSTANT)
         bdy2d_need_elev = .false.
      case (CLAMPED)
         bdy2d_need_elev = .true.
      case (ZERO_GRADIENT)
         bdy2d_need_elev = .false.
      case (SOMMERFELD)
         bdy2d_need_elev = .false.
      case (CLAMPED_ELEV)
         bdy2d_need_elev = .true.
      case (FLATHER_ELEV)
         bdy2d_need_elev = .true.
      case (FLATHER_VEL)
         bdy2d_need_elev = .true.
      case (CLAMPED_VEL)
         bdy2d_need_elev = .false.
      case default
         bdy2d_need_elev = .false.
   end select

   return
   end function bdy2d_need_elev
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE:  LOGICAL function bdy2d_need_vel -
!
! !INTERFACE:
   logical function bdy2d_need_vel(type_2d)
!
! !DESCRIPTION:
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer,intent(in)  :: type_2d
!
! !REVISION HISTORY:
!  Original author(s): Knut Klingbeil
!EOP
!-----------------------------------------------------------------------
!BOC

   select case (type_2d)
      case (CONSTANT)
         bdy2d_need_vel = .false.
      case (CLAMPED)
         bdy2d_need_vel = .true.
      case (ZERO_GRADIENT)
         bdy2d_need_vel = .false.
      case (SOMMERFELD)
         bdy2d_need_vel = .false.
      case (CLAMPED_ELEV)
         bdy2d_need_vel = .false.
      case (FLATHER_ELEV)
         bdy2d_need_vel = .true.
      case (FLATHER_VEL)
         bdy2d_need_vel = .true.
      case (CLAMPED_VEL)
         bdy2d_need_vel = .true.
      case default
         bdy2d_need_vel = .false.
   end select

   return
   end function bdy2d_need_vel
!EOC
!-----------------------------------------------------------------------

   end module bdy_2d

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Karsten Bolding and Hans Burchard               !
!-----------------------------------------------------------------------
