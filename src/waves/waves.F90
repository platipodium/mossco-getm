#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: waves
!
! !INTERFACE:
   module waves
!
! !DESCRIPTION:
!
!
! !USES:
   use variables_waves
   use parameters     , only: grav => g
   use exceptions
   use halo_zones     , only: update_2d_halo,wait_halo,H_TAG
   use domain         , only: imin,imax,jmin,jmax,az
   use meteo          , only: metforcing,met_method,tausx,tausy

   IMPLICIT NONE
   private
!
! !PUBLIC DATA MEMBERS:
   public init_waves,do_waves,uv_waves,uv_waves_3d

   integer,public,parameter :: NO_WAVES=0
   integer,public,parameter :: WAVES_RS=1
   integer,public,parameter :: WAVES_VF=2
   integer,public           :: waves_method=NO_WAVES
   integer,public,parameter :: WAVES_FROMEXT=0
   integer,public,parameter :: WAVES_FROMFILE=1
   integer,public,parameter :: WAVES_FROMWIND=2
   integer,public           :: waves_datasource=WAVES_FROMEXT
   logical,public           :: new_waves=.false.
   logical,public           :: new_StokesC=.false.
!
! !PRIVATE DATA MEMBERS:
!
! !REVISION HISTORY:
!  Original author(s): Ulf Graewe
!                      Saeed Moghimi
!                      Knut Klingbeil
!
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_waves - initialising WAVES
! \label{sec-init-waves}
!
! !INTERFACE:
   subroutine init_waves(runtype)

   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer,intent(in) :: runtype
!
! !DESCRIPTION:
!
! Here, some necessary memory is allocated (in case of the compiler option
! {\tt STATIC}), and information is written to the log-file of
! the simulation.
!
! !LOCAL VARIABLES
   namelist /waves/ waves_method,waves_datasource
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_waves() # ',Ncall
#endif

   LEVEL1 'init_waves'

   read(NAMLST,waves)
   select case (waves_method)
      case(NO_WAVES)
         LEVEL2 'no wave forcing'
         return
      case(WAVES_RS)
         LEVEL2 'wave forcing by Radiation Stress'
      case(WAVES_VF)
         LEVEL2 'wave forcing by Vortex Force'
      case default
         stop 'init_waves(): no valid waves_method specified'
   end select

   call init_variables_waves(runtype)

   select case (waves_datasource)
      case(WAVES_FROMEXT)
         LEVEL2 'wave data written from external'
      case(WAVES_FROMFILE)
         LEVEL2 'wave data read from file'
      case(WAVES_FROMWIND)
         LEVEL2 'wave data derived from wind data'
         if ( .not. metforcing ) then
            stop 'init_waves(): metforcing must be active for WAVES_FROMWIND'
         end if
      case default
         stop 'init_waves(): no valid waves_datasource specified'
   end select

   return
   end subroutine init_waves
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_waves -
! \label{sec-do-waves}
!
! !INTERFACE:
   subroutine do_waves(D)

! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,dimension(E2DFIELD),intent(in) :: D
!
! !DESCRIPTION:
!  D should be depth at velocity time stage.
!
! !LOCAL VARIABLES:
   REALTYPE,dimension(E2DFIELD) :: waveECm1
   REALTYPE                     :: wind
   integer                      :: i,j
   REALTYPE,parameter           :: pi=3.1415926535897932384626433832795029d0
   REALTYPE,parameter           :: twopi = _TWO_*pi
   REALTYPE,parameter           :: oneovertwopi=_ONE_/twopi
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_waves() # ',Ncall
#endif

   if (waves_datasource .eq. WAVES_FROMWIND) then
      new_waves = .true.
         do j=jmin-HALO,jmax+HALO
            do i=imin-HALO,imax+HALO
               if ( az(i,j) .gt. 0 ) then
!                 use of taus[x|y] because of:
!                    - missing temporal interpolation
!                    - missing halo update of [u|v]10
!                    - also valid for met_method=1
!                 however: only approximation for wind!
                  waveDir(i,j) = atan2(tausy(i,j),tausx(i,j)) ! cartesian convention and in radians
                  wind = sqrt(sqrt(tausx(i,j)**2 + tausy(i,j)**2)/(1.25d-3*1.25))
                  waveH(i,j) = wind2waveHeight(wind,D(i,j))
                  waveT(i,j) = wind2wavePeriod(wind,D(i,j))
                  waveK(i,j) = wavePeriod2waveNumber(waveT(i,j),D(i,j))
                  waveL(i,j) = twopi / waveK(i,j)
            end if
         end do
      end do
   end if


   if (new_waves) then

      new_waves = .false.

      coswavedir = cos(waveDir)
      sinwavedir = sin(waveDir)
      waveE = grav * (_QUART_*waveH)**2


      new_StokesC = .true.

      waveECm1 = waveE * waveK * waveT * oneovertwopi

!     depth-integrated Stokes drift in x-direction at T-point
      UStokesC = coswavedir * waveECm1

!     depth-integrated Stokes drift in y-direction at T-point
      VStokesC = sinwavedir * waveECm1

   end if


#ifdef DEBUG
   write(debug,*) 'Leaving do_waves()'
   write(debug,*)
#endif
   return
   end subroutine do_waves
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: uv_waves -
! \label{sec-uv-waves}
!
! !INTERFACE:
   subroutine uv_waves(Dvel,UEX,VEx)

   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,dimension(E2DFIELD),intent(in)    :: Dvel
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE,dimension(E2DFIELD),intent(inout) :: UEx,VEx
!
! !DESCRIPTION:
!
! !LOCAL VARIABLES
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'uv_waves() # ',Ncall
#endif

   select case(waves_method)
      case (WAVES_RS)
         call radiation_stress(Dvel,UEx,VEx)
      case (WAVES_VF)
         call vortex_force(UEx,VEx)
   end select

#ifdef DEBUG
   write(debug,*) 'Leaving uv_waves()'
   write(debug,*)
#endif
   return
   end subroutine uv_waves
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: uv_waves_3d -
! \label{sec-uv-waves-3d}
!
! !INTERFACE:
   subroutine uv_waves_3d(Dveln,hvel,uuEuler,vvEuler,hun,hvn,uuEx,vvEx)

   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,dimension(I2DFIELD),intent(in)    :: Dveln
   REALTYPE,dimension(I3DFIELD),intent(in)    :: hvel,uuEuler,vvEuler,hun,hvn
!
! !INPUT/OUTPUT PARAMETERS:
   REALTYPE,dimension(I3DFIELD),intent(inout) :: uuEx,vvEx
!
! !DESCRIPTION:
!
! !LOCAL VARIABLES
!
!EOP
!-----------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'uv_waves_3d() # ',Ncall
#endif

   select case(waves_method)
      case (WAVES_RS)
         call radiation_stress_3d(Dveln,hvel,uuEx,vvEx)
      case (WAVES_VF)
         call vortex_force_3d(uuEuler,vvEuler,hun,hvn,uuEx,vvEx)
   end select

#ifdef DEBUG
   write(debug,*) 'Leaving uv_waves_3d()'
   write(debug,*)
#endif
   return
   end subroutine uv_waves_3d
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: wind2waveHeight - estimates significant wave height from wind
!
! !INTERFACE:
   REALTYPE function wind2waveHeight(wind,depth)

! !USES:
   use parameters, only: grav => g
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,intent(in) :: wind,depth
!
! !DESCRIPTION:
!  Calculates significant wave height (Hm0) under assumption of unlimited fetch.
!  See page 250 in Holthuijsen (2007).
!
! !REVISION HISTORY:
!  Original author(s): Ulf Graewe
!                      Knut Klingbeil
!
! !LOCAL VARIABLES
   REALTYPE           :: depthstar,waveHeightstar
   REALTYPE,parameter :: waveHeightstar8 = 0.24d0
   REALTYPE,parameter :: k3 = 0.343d0
   REALTYPE,parameter :: m3 = 1.14d0
   REALTYPE,parameter :: p  = 0.572d0
!
!EOP
!-----------------------------------------------------------------------
!BOC

!  dimensionless depth
   depthstar = grav * depth / wind**2

!  dimensionless significant wave height
   waveHeightstar = waveHeightstar8 * tanh(k3*depthstar**m3)**p

!  significant wave height
   wind2waveHeight = wind**2 * waveHeightstar / grav

   end function wind2waveHeight
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: wind2wavePeriod - estimates peak wave period from wind
!
! !INTERFACE:
   REALTYPE function wind2wavePeriod(wind,depth)

! !USES:
   use parameters, only: grav => g
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,intent(in) :: wind,depth
!
! !DESCRIPTION:
!  Calculates peak wave period under assumption of unlimited fetch.
!  See page 250 in Holthuijsen (2007).
!  The peak wave period can be empirically related to the significant
!  wave period (Holthuijsen Eqs. (4.2.7) and (4.2.9)).
!
! !REVISION HISTORY:
!  Original author(s): Ulf Graewe
!                      Knut Klingbeil
!
! !LOCAL VARIABLES
   REALTYPE           :: depthstar,wavePeriodstar
   REALTYPE,parameter :: wavePeriodstar8 = 7.69d0
   REALTYPE,parameter :: k4 = 0.10d0
   REALTYPE,parameter :: m4 = 2.01d0
   REALTYPE,parameter :: q  = 0.187d0
!
!EOP
!-----------------------------------------------------------------------
!BOC

!  dimensionless depth
   depthstar = grav * depth / wind**2

!  dimensionless peak wave period
   wavePeriodstar = wavePeriodstar8 * tanh(k4*depthstar**m4)**q

!  peak wave period
   wind2wavePeriod = wind * wavePeriodstar / grav

   end function wind2wavePeriod
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: wavePeriod2waveNumber - approximates wave number from wave period
!
! !INTERFACE:
   REALTYPE function wavePeriod2waveNumber(period,depth)

! !USES:
   use parameters, only: grav => g
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE,intent(in) :: period,depth
!
! !DESCRIPTION:
!  x=k*D=kD,y=omega/sqrt(g/D)=omegastar
!  y=sqrt(x*tanh(x)),y(1)=0.8727=omegastar1
!  x'=lg(x),(dx'|dx)=1/(x*ln(10))
!  y'=lg(y),(dy'|dy)=1/(y*ln(10))
!  m'(x)=(dy'|dx')=(dy'|dy)*(dy|dx)*(dx|dx')=x/y*m(x)
!  m(x)=(dy|dx)=0.5*[tanh(x)+x*(1-tanh(x)**2)]/sqrt(x*tanh(x))
!  m(1)=0.677,m'(1)=0.77572=slopestar1
!  y'=lg(y(1))+m'(1)*x' <=> y=y(1)*[x**m'(1)] <=> x=(y/y(1))**(1/m'(1))
!  shallow: y=x       => x<=y(1)**(1/(1  -m'(1)))=0.5449  => y<=0.5449
!  deep   : y=sqrt(x) => x>=y(1)**(1/(0.5-m'(1)))=1.63865 => y>=1.28
!
!  For alternatives see Holthuijsen (2007) page 124
!  (Eckart, 1952 and Fenton, 1988)
!
! !REVISION HISTORY:
!  Original author(s): Knut Klingbeil
!
! !LOCAL VARIABLES
   REALTYPE           :: omega,omegastar,kD
   REALTYPE,parameter :: omegastar1_rec = _ONE_/0.8727d0
   REALTYPE,parameter :: slopestar1_rec = _ONE_/0.77572d0
   REALTYPE,parameter :: pi=3.1415926535897932384626433832795029d0
!
!EOP
!-----------------------------------------------------------------------
!BOC
 
   omega = _TWO_ * pi / period ! radian frequency
   omegastar = omega * sqrt(depth/grav) ! non-dimensional radian frequency

   if ( omegastar .lt. 0.5449d0 ) then
!     shallow-water approximation
      kD = omegastar
   else if ( omegastar .gt. 1.28d0 ) then
!     deep-water approximation
      kD = omegastar**2
   else
!     tangential approximation in loglog-space for full dispersion relation
      kD = (omegastar1_rec * omegastar) ** slopestar1_rec
   end if

   wavePeriod2waveNumber = kD / depth

   end function wavePeriod2waveNumber
!EOC
!-----------------------------------------------------------------------

   end module waves

!-----------------------------------------------------------------------
! Copyright (C) 2013 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------