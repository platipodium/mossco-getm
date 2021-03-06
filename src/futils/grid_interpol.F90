#include "cppdefs.h"
#ifndef HALO
#define HALO 0
#endif

! This needs to be made smarter..
! If USE_VALID_LON_LAT_ONLY is set the inerpolation is only done for
! valid lat,lon specifications - however, sometimes it is only desirable
! to calculate using the mask information e.g. salinity and temperature
! climatologies.
! lat and lon should be initialised to something < -1000.
! Comment out the following line and re-compile then the mask-method is
! used
#define USE_VALID_LON_LAT_ONLY
! Compile with _OLD_GRID_INTERPOL_ to avoid errors for missing data points,
! and to not consider provided ocean masks.
!-----------------------------------------------------------------------
!BOP
!
! !MODULE:  grid_interpol - various interpolation routines
!
! !INTERFACE:
   module grid_interpol
!
! !DESCRIPTION:
!  If optional {\tt met\_mask} is provided to {\\tt init\_grid\_interpol()},
!  interpolation weights are set to avoid interpolation in cells with at
!  least one missing node.
!  If optional {\tt imask} is provided to {\tt do\_grid\_interpol()},
!  it will be considered to use modified interpolation weights, depending
!  on the optional provision of {\\tt fillvalue}. If {\tt fillvalue} is
!  present, missing data values are replaced by {\tt fillvalue} and the
!  original interpolation weights are used.
!  if {\tt imask} is not provided the original interpolation weights are
!  used and {\tt fillvalue} is not considered.
!
! !USES:
   use exceptions
   IMPLICIT NONE
!
! !PUBLIC DATA MEMBERS:
!
! !PRIVATE DATA MEMBERS:
   REALTYPE, parameter       :: pi=3.1415926535897932384626433832795029
   REALTYPE, parameter       :: deg2rad=pi/180.,rad2deg=180./pi
   REALTYPE, parameter       :: earth_radius=6370.9490e3

   integer :: il,ih,jl,jh
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
! !IROUTINE: init_grid_interpol - initialise grid interpolation.
!
! !INTERFACE:
   subroutine init_grid_interpol(imin,imax,jmin,jmax,mask,      &
                         olon,olat,met_lon,met_lat,southpole,   &
                         gridmap,beta,t,u,                      &
                         met_mask,break_on_missing)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  To be written.
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: imin,imax,jmin,jmax
   integer, intent(in)                 :: mask(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: olon(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: olat(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: met_lon(:),met_lat(:)
   REALTYPE, intent(in)                :: southpole(3)
   integer, optional, intent(in)       :: met_mask(:,:)
   logical, optional, intent(in)       :: break_on_missing
!
! !OUTPUT PARAMETERS:
   REALTYPE, intent(out)               :: beta(-HALO+1:,-HALO+1:)
   REALTYPE, intent(out)               :: t(-HALO+1:,-HALO+1:)
   REALTYPE, intent(out)               :: u(-HALO+1:,-HALO+1:)
   integer, intent(out)                :: gridmap(-HALO+1:,-HALO+1:,1:)
!
! !REVISION HISTORY:
!
!  See module for log.
!
! !LOCAL VARIABLES:
   integer                   :: rc
   integer                   :: i,j
   REALTYPE                  :: x(4),y(4)
   REALTYPE                  :: z
   REALTYPE                  :: xr,yr,zr
!EOP
!-------------------------------------------------------------------------
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_grid_interpol() # ',Ncall
#endif
   LEVEL1 'init_grid_interpol'

   il = imin; ih = imax
   jl = jmin; jh = jmax

#ifdef USE_VALID_LON_LAT_ONLY
   LEVEL2 'interpolates for all valid lat-lon'
#else
   LEVEL2 'interpolates only when mask > 0'
#endif

   if(southpole(3) .ne. _ZERO_ ) then
      FATAL 'southpole(3) (rotation) is not coded yet'
      stop 'init_grid_interpol'
   endif

   if(southpole(1) .ne. _ZERO_ .or. southpole(2) .ne. -90.) then
      LEVEL2 'source field domain (rotated coordinates):'
   else
      LEVEL2 'source field domain (geo-graphical coordinates):'
   end if
   if(met_lon(1) .lt. met_lon(size(met_lon))) then
      LEVEL3 'lon: ',met_lon(1),met_lon(size(met_lon))
   else
      LEVEL3 'lon: ',met_lon(size(met_lon)),met_lon(1)
   end if
   if(met_lat(1) .lt. met_lat(size(met_lat))) then
      LEVEL3 'lat: ',met_lat(1),met_lat(size(met_lat))
   else
      LEVEL3 'lon: ',met_lat(size(met_lat)),met_lat(1)
   end if

   LEVEL2 'target field domain:'
   LEVEL3 'lon: ',olon(1,1),olon(imax,jmax)
   LEVEL3 'lat: ',olat(1,1),olat(imax,jmax)

   gridmap = -999

      call interpol_coefficients(mask,southpole, &
                   olon,olat,met_lon,met_lat,beta,gridmap,t,u,         &
                   met_mask=met_mask,break_on_missing=break_on_missing)

#ifdef DEBUG
   write(debug,*) 'leaving init_grid_interpol()'
   write(debug,*)
#endif
   return
   end subroutine init_grid_interpol
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_grid_interpol - do grid interpolation.
!
! !INTERFACE:
   subroutine do_grid_interpol(mask,ifield,gridmap,t,u,ofield,imask,fillvalue)
   IMPLICIT NONE
!
! !DESCRIPTION:
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: mask(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in),target         :: ifield(:,:)
   integer, intent(in)                 :: gridmap(-HALO+1:,-HALO+1:,1:)
   REALTYPE, intent(in)                :: t(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: u(-HALO+1:,-HALO+1:)
   integer, intent(in),optional        :: imask(:,:)
   REALTYPE, intent(in),optional       :: fillvalue
!
! !OUTPUT PARAMETERS:
   REALTYPE, intent(out)               :: ofield(-HALO+1:,-HALO+1:)
!
! !REVISION HISTORY:
!
!  See module for log.
!
! !LOCAL VARIABLES:
   integer                   :: i,j,im,jm
   integer                   :: i1,i2,j1,j2
   integer                   :: ngood
   REALTYPE                  :: d11,d21,d22,d12
!   integer                   :: iil=LBOUND(ifield,1),iih=UBOUND(ifield,1)
!   integer                   :: ijl=LBOUND(ifield,2),ijh=UBOUND(ifield,2)
!   integer                   :: oil=LBOUND(ofield,1),oih=UBOUND(ofield,1)
!   integer                   :: ojl=LBOUND(ofield,2),ojh=UBOUND(ofield,2)
!   REALTYPE,dimension(iil:iih,ijl:ijh) :: tifield
!   REALTYPE,dimension(oil:oih,ojl:ojh) :: tt,tu
   REALTYPE,dimension(LBOUND(ifield,1):UBOUND(ifield,1),LBOUND(ifield,2):UBOUND(ifield,2)),target :: tifield
   REALTYPE,dimension(:,:),pointer :: pifield
   REALTYPE                  :: fv,tmp
   logical                   :: ok
!EOP
!-------------------------------------------------------------------------
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_grid_interpol() # ',Ncall
#endif

   pifield => ifield

   if ( present(imask) ) then
      if ( present(fillvalue) ) then
         where ( imask .gt. 0 )
            tifield = ifield
         elsewhere
            tifield = fillvalue
         end where
         pifield => tifield
      else
         ok = .true.
         do j=jl,jh
            do i=il,ih
               if (mask(i,j) .gt. 0) then
                  im = gridmap(i,j,1)
                  jm = gridmap(i,j,2)
                  if(im .gt. 0 .and. jm .gt. 0) then
                     ngood = imask(im  ,jm  )+imask(im+1,jm  )+ &
                             imask(im+1,jm+1)+imask(im  ,jm+1)
                     if (ngood .eq. 0) then
                        STDERR i,j,im,jm
                        ok = .false.
                     end if
                  end if
               end if
            end do
         end do
         if ( .not. ok ) then
            STDERR 'WARNING - do_grid_interpol: no nodes and no fillvalue'
            call getm_error("do_grid_interpol()","no nodes and no fillvalue.")
         end if
      end if
   end if

   if ( present(fillvalue) ) then
      fv = fillvalue
   else
      fv = _ZERO_
   end if

   do j=jl,jh
      do i=il,ih
#ifndef _OLD_GRID_INTERPOL_
         if (mask(i,j) .gt. 0) then
#endif
         i1 = gridmap(i,j,1)
         j1 = gridmap(i,j,2)
         if(i1 .gt. 0 .and. j1 .gt. 0) then
#ifdef _OLD_GRID_INTERPOL_
            if(i1 .ge. size(ifield,1) .or. j1 .ge. size(ifield,2)) then
               ofield(i,j) = ifield(i1,j1)
            else
#endif
               i2 = i1+1
               j2 = j1+1
               d11 = (_ONE_-t(i,j))*(_ONE_-u(i,j))
               d21 = t(i,j)*(_ONE_-u(i,j))
               d22 = t(i,j)*u(i,j)
               d12 = (_ONE_-t(i,j))*u(i,j)
               if (present(imask) .and. .not.present(fillvalue)) then
                  d11 = d11*imask(i1,j1)
                  d21 = d21*imask(i2,j1)
                  d22 = d22*imask(i2,j2)
                  d12 = d12*imask(i1,j2)
                  tmp = d11+d21+d22+d12
                  d11 = d11/tmp
                  d21 = d21/tmp
                  d22 = d22/tmp
                  d12 = d12/tmp
               end if
               ofield(i,j) = d11*pifield(i1,j1)+d21*pifield(i2,j1)+      &
                             d22*pifield(i2,j2)+d12*pifield(i1,j2)
#ifdef _OLD_GRID_INTERPOL_
            end if
#endif
         else
            ofield(i,j) = fv
         end if
#ifndef _OLD_GRID_INTERPOL_
         end if
#endif
      end do
   end do

#ifdef DEBUG
   write(debug,*) 'Leaving do_grid_interpol()'
   write(debug,*)
#endif
   return
   end subroutine do_grid_interpol
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_3d_grid_interpol - do grid interpolation.
!
! !INTERFACE:
   subroutine do_3d_grid_interpol(ifield,gridmap,t,u,ofield)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  To be written.
!
! !INPUT PARAMETERS:
   REALTYPE, intent(in)                :: ifield(:,:,:)
   integer, intent(in)                 :: gridmap(-HALO+1:,-HALO+1:,1:)
   REALTYPE, intent(in)                :: t(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: u(-HALO+1:,-HALO+1:)
!
! !OUTPUT PARAMETERS:
   REALTYPE, intent(out)               :: ofield(-HALO+1:,-HALO+1:,0:)
!
! !REVISION HISTORY:
!
!  See module for log.
!
! !LOCAL VARIABLES:
   integer                   :: i,j
   integer                   :: i1,i2,j1,j2
   REALTYPE                  :: d11,d21,d22,d12
!EOP
!-------------------------------------------------------------------------
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_3d_grid_interpol() # ',Ncall
#endif

   do j=jl,jh
      do i=il,ih
         i1 = gridmap(i,j,1)
         i2 = i1+1
         j1 = gridmap(i,j,2)
         j2 = j1+1
         d11 = (_ONE_-t(i,j))*(_ONE_-u(i,j))
         d21 = t(i,j)*(_ONE_-u(i,j))
         d22 = t(i,j)*u(i,j)
         d12 = (_ONE_-t(i,j))*u(i,j)
         ofield(i,j,1:) = d11*ifield(i1,j1,:)+d21*ifield(i2,j1,:)+     &
                          d22*ifield(i2,j2,:)+d12*ifield(i1,j2,:)
      end do
   end do

#ifdef DEBUG
   write(debug,*) 'Leaving do_3d_grid_interpol()'
   write(debug,*)
#endif
   return
   end subroutine do_3d_grid_interpol
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: to_rotated_lat_lon - from geographical to  rotated lat-lon
!
! !INTERFACE:
   subroutine to_rotated_lat_lon(southpole,alon,alat,rlon,rlat,beta)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  To be written.
!
! !INPUT PARAMETERS:
   REALTYPE, intent(in)                :: southpole(3)
   REALTYPE, intent(in)                :: alon
   REALTYPE, intent(in)                :: alat
!
! !INPUT/OUTPUT PARAMETERS:
! !OUTPUT PARAMETERS:
   REALTYPE, intent(out)               :: rlon
   REALTYPE, intent(out)               :: rlat
   REALTYPE, intent(out)               :: beta
!
! !REVISION HISTORY:
!
!  See module for log.
!
! !LOCAL VARIABLES:
   REALTYPE                  :: sinphis,cosphis
   REALTYPE                  :: alpha,cosalpha,sinalpha
   REALTYPE                  :: phi,sinphi,cosphi
   REALTYPE                  :: SA,CA,SB,CB
!
!EOP
!-------------------------------------------------------------------------
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'to_rotated_lat_lon() # ',Ncall
#endif

!   LEVEL1 'to_rotated_lat_lon'

   sinphis=sin(deg2rad*southpole(1))
   cosphis=cos(deg2rad*southpole(1))

   alpha = deg2rad*(alon-southpole(2))
   cosalpha = cos(alpha)
   sinalpha = sin(alpha)

   phi = deg2rad*alat
   sinphi = sin(phi)
   cosphi = cos(phi)

   rlat = asin(-sinphis*sinphi-cosphis*cosphi*cosalpha)*rad2deg

   SA = sinalpha*cosphi
   CA = cosphis*sinphi-sinphis*cosphi*cosalpha
   rlon = atan2(SA,CA)*rad2deg

   SB =  sinalpha*cosphis
   CB = -sinphis*cosphi+cosphis*sinphi*cosalpha
   beta = atan2(SB,CB)

#ifdef DEBUG
   write(debug,*) 'Leaving to_rotated_lat_lon()'
   write(debug,*)
#endif
   return
   end subroutine to_rotated_lat_lon
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: from_rotated_lat_lon - from rotated lat-lon to geographical
!
! !INTERFACE:
   subroutine from_rotated_lat_lon(southpole,rlon,rlat,alon,alat,beta)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  To be written.
!
! !INPUT PARAMETERS:
   REALTYPE, intent(in)                :: southpole(3)
   REALTYPE, intent(in)                :: rlon
   REALTYPE, intent(in)                :: rlat
!
! !OUTPUT PARAMETERS:
   REALTYPE, intent(out)               :: alon
   REALTYPE, intent(out)               :: alat
   REALTYPE, intent(out)               :: beta
!
! !REVISION HISTORY:
!
!  See module for log.
!
! !LOCAL VARIABLES:
   REALTYPE                  :: sinphis,cosphis
   REALTYPE                  :: lambda,coslambda,sinlambda
   REALTYPE                  :: phi,sinphi,cosphi
   REALTYPE                  :: SA,CA,SB,CB
!
!EOP
!-------------------------------------------------------------------------
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'to_rotated_lat_lon() # ',Ncall
#endif

   sinphis=sin(deg2rad*southpole(1))
   cosphis=cos(deg2rad*southpole(1))

   lambda = deg2rad*rlon
   coslambda = cos(lambda)
   sinlambda = sin(lambda)

   phi = deg2rad*rlat
   sinphi = sin(phi)
   cosphi = cos(phi)

   alat = asin(-sinphis*sinphi+cosphis*cosphi*coslambda)*rad2deg

   SA = -sinlambda*cosphi
   CA = cosphis*sinphi+sinphis*cosphi*coslambda
   alon = southpole(2)+atan2(-SA,-CA)*rad2deg

   SB =  -sinlambda*cosphis
   CB = -sinphis*cosphi-cosphis*sinphi*coslambda
   beta = atan2(SB,CB)

#ifdef DEBUG
   write(debug,*) 'Leaving to_rotated_lat_lon()'
   write(debug,*)
#endif
   return
   end subroutine from_rotated_lat_lon
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: spherical_dist - calculate distances on a sphere
!
! !INTERFACE:
   REALTYPE function spherical_dist(radius,lon1,lat1,lon2,lat2)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  Calculates the distance - in meters - between the two poinst specified
!  by (lon1,lat1) and (lon2,lat2). Radius is the radius of the sphere -
!  usually the radius of the earth.
!
! !INPUT PARAMETERS:
   REALTYPE, intent(in)                :: radius,lon1,lat1,lon2,lat2
!
! !REVISION HISTORY:
!
!  See module for log.
!
! !LOCAL VARIABLES:
   REALTYPE                  :: a,b,c
!EOP
!-------------------------------------------------------------------------
   a = sin(deg2rad*0.5*(lat2-lat1))
   b = sin(deg2rad*0.5*(lon2-lon1))
   c = a*a + cos(deg2rad*lat1)*cos(deg2rad*lat2)*b*b
   spherical_dist = radius*2.0*atan2(sqrt(c),sqrt(1-c))
   end function spherical_dist
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: interpol_coefficients - set up interpolation coeffcients
!
! !INTERFACE:
   subroutine interpol_coefficients(mask,sp,olon,olat,met_lon,met_lat, &
                                    beta,gridmap,t,u,                  &
                                    met_mask,break_on_missing)
   IMPLICIT NONE
!
! !DESCRIPTION:
!  To be written.
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: mask(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: sp(3)
   REALTYPE, intent(in)                :: olon(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: olat(-HALO+1:,-HALO+1:)
   REALTYPE, intent(in)                :: met_lon(:),met_lat(:)
   integer, optional, intent(in)       :: met_mask(:,:)
   logical, optional, intent(in)       :: break_on_missing
!
! !OUTPUT PARAMETERS:
   REALTYPE, intent(out)               :: beta(-HALO+1:,-HALO+1:)
   integer, intent(out)                :: gridmap(-HALO+1:,-HALO+1:,1:)
   REALTYPE, intent(out)               :: t(-HALO+1:,-HALO+1:)
   REALTYPE, intent(out)               :: u(-HALO+1:,-HALO+1:)
!
! !REVISION HISTORY:
!
!  See module for log.
!
! !LOCAL VARIABLES:
   logical                   :: rotated_grid
   integer                   :: i,j,im,jm
   REALTYPE                  :: alon,alat
   REALTYPE                  :: x,y,lon1,lat1,lon2,lat2
   integer                   :: ngood
   logical                   :: outside,ok,break
   integer                   :: max_i,max_j
   logical                   :: increasing_lat,increasing_lon
!EOP
!-------------------------------------------------------------------------
!  first find the lower left (im,jm) in the m-grid which coresponds to
!  olon(i,j), olat(i,j)

   if ( present(break_on_missing) ) then
      break = break_on_missing
   else
#ifdef _OLD_GRID_INTERPOL_
      break = .false.
#else
      break = .true.
#endif
   end if

   max_i = size(met_lon)
   max_j = size(met_lat)

   increasing_lon = met_lon(1) .lt. met_lon(max_i)
   increasing_lat = met_lat(1) .lt. met_lat(max_j)

   if(sp(1) .ne. _ZERO_ .or. sp(2) .ne. -90.) then
      rotated_grid = .true.
   else
      rotated_grid = .false.
   end if

   outside = .false.
   do j=jl,jh
      do i=il,ih
#ifdef USE_VALID_LON_LAT_ONLY
         if(olon(i,j) .gt. -1000. .and. olat(i,j) .gt. -1000.) then
#endif
         if(mask(i,j) .ge. 1) then
            if (rotated_grid) then
               call to_rotated_lat_lon(sp,olon(i,j),olat(i,j), &
                                       alon,alat,beta(i,j))
            else
               alon = olon(i,j)
               alat = olat(i,j)
               beta(i,j) = _ZERO_
            end if

            if (increasing_lon) then
               if(met_lon(1) .le. alon .and. alon .le. met_lon(max_i)) then
                  do im=1,max_i
                     if(met_lon(im) .gt. alon) EXIT
                  end do
                  gridmap(i,j,1) = im-1
               else
                  STDERR i,j,real(olon(i,j)),real(olat(i,j))
                  outside = .true.
               end if
            else
            endif

            if (increasing_lat) then
               if(met_lat(1) .le. alat .and. alat .le. met_lat(max_j)) then
                  do jm=1,max_j
                     if(met_lat(jm) .gt. alat) EXIT
                  end do
                  gridmap(i,j,2) = jm-1
               else
                  STDERR i,j,real(olon(i,j)),real(olat(i,j))
                  outside = .true.
               end if
            else
            endif
         end if
#ifdef USE_VALID_LON_LAT_ONLY
         end if
#endif
      end do
   end do

   if(outside) then
      STDERR 'WARNING - interpol_coefficients: Some points out side the area'
      if ( break ) then
         call getm_error("interpol_coefficients()",                    &
                         "Some points out side the area.")
      end if
   end if

!  then calculated the t and u coefficients - via distances - the point of
!  interest is (x,y)
   ok = .true.
   do j=jl,jh
      do i=il,ih
#ifdef USE_VALID_LON_LAT_ONLY
         if(olon(i,j) .gt. -1000. .and. olat(i,j) .gt. -1000.) then
#endif
         if(mask(i,j) .ge. 1) then
            if (rotated_grid) then
               call to_rotated_lat_lon(sp,olon(i,j),olat(i,j), &
                                       x,y,beta(i,j))
            else
               x = olon(i,j)
               y = olat(i,j)
            end if
            im = gridmap(i,j,1)
            jm = gridmap(i,j,2)
            if(im .gt. 0 .and. jm .gt. 0) then
               if(present(met_mask)) then
                  ngood = met_mask(im  ,jm  )+met_mask(im+1,jm  )+ &
                          met_mask(im+1,jm+1)+met_mask(im  ,jm+1)
               else
                  ngood = 4
               end if
               select case (ngood)
                  case (0)
!                    Note (KK): in the original code we did nothing,
!                               because t,u were initialised to -999
!                               and this was catched after init_grid_interpol
!                               in init_meteo_input_ncdf.
                     STDERR 'none:',i,j,real(olon(i,j)),real(olat(i,j))
                     ok = .false.
!                    condition for filling in do_grid_interpol()
                     gridmap(i,j,1) = -999
                     gridmap(i,j,2) = -999
#ifdef _OLD_GRID_INTERPOL_
                  case (1,2,3)
                     STDERR 'miss:',i,j,real(olon(i,j)),real(olat(i,j))
                     ok = .false.
                     t(i,j) = _ZERO_
                     u(i,j) = _ZERO_
                     if (present(met_mask)) then
!                    Note (KK): this is weird !!!
!                    if(met_mask(im,jm) .eq. 0 .or. met_mask(im,jm+1) .eq. 0 ) &
!                         t(i,j) = _ONE_
!                    if(met_mask(im,jm) .eq. 0 .or. met_mask(im+1,jm) .eq. 0 ) &
!                          u(i,j) = _ONE_
                     end if
                  case (4)
#else
               end select
#endif
                     lon1 = met_lon(im)
                     lat1 = met_lat(jm)
                     lon2 = met_lon(im+1)
                     lat2 = met_lat(jm+1)
                     t(i,j) = spherical_dist(earth_radius,x,lat1,lon1,lat1)/ &
                              spherical_dist(earth_radius,lon1,lat1,lon2,lat1)
                     u(i,j) = spherical_dist(earth_radius,lon1,y,lon1,lat1)/ &
                              spherical_dist(earth_radius,lon1,lat1,lon1,lat2)
#ifdef _OLD_GRID_INTERPOL_
                  case default
               end select
#endif
            end if
         end if
#ifdef USE_VALID_LON_LAT_ONLY
         else if (mask(i,j) .gt. 0) then
            FATAL 'Could not find coefficients for all water points'
            FATAL 'ocean(i,j) = ',i,j
            stop 'interpol_coefficients()'
         end if
#endif
      end do
   end do

   if ( .not. ok ) then
      STDERR 'WARNING - interpol_coefficients: no or missing nodes for interpolation'
      if ( break ) then
         call getm_error("interpol_coefficients()",                    &
                         "no nodes for interpolation.")
      end if
   end if

   end subroutine interpol_coefficients
!EOC

!-----------------------------------------------------------------------

   end module grid_interpol

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Karsten Bolding and Hans Burchard               !
!-----------------------------------------------------------------------
