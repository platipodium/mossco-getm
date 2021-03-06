   integer         :: iextr=-1, jextr=-1
   integer         :: imin=-1,imax=-1,jmin=-1,jmax=-1
   integer         :: kmax=1

!  coordinate axes - grid-type = 1 or 2
   REALTYPE, dimension(:), allocatable, target :: xcord, ycord

!  coordinate axes - grid-type = 3 or 4
   REALTYPE, dimension(:), allocatable, target :: xxcord, yxcord

!  mask
   REALTYPE, dimension(:,:), allocatable    :: mask
   integer,dimension(:,:),allocatable,target :: az,au,av,ax

!  bathymetry
   REALTYPE, dimension(:,:), allocatable    :: H,HU,HV
   REALTYPE, dimension(:,:), allocatable    :: dry_z,dry_u,dry_v

!  coriolis terms
   REALTYPE, dimension(:,:), allocatable    :: cor,coru,corv

!  lat/lon
   REALTYPE, dimension(:,:), allocatable, target :: lonc,latc
   REALTYPE, dimension(:,:), allocatable, target :: lonx,latx
   REALTYPE, dimension(:,:), allocatable, target :: lonu,latu
   REALTYPE, dimension(:,:), allocatable, target :: lonv,latv

!  grid convergence
!KB   REALTYPE, dimension(:,:), allocatable    :: angle
   REALTYPE, dimension(:,:), allocatable    :: convc,convx
   REALTYPE, dimension(:,:), allocatable    :: cosconv,sinconv

!  grid points
   REALTYPE, dimension(:,:), allocatable, target :: xx,yx
   REALTYPE, dimension(:,:), allocatable, target :: xc,yc
   REALTYPE, dimension(:,:), allocatable, target :: xu,yu
   REALTYPE, dimension(:,:), allocatable, target :: xv,yv

!  metric parameters
   REALTYPE                                 :: dx=-_ONE_,dy=-_ONE_,ard1
   REALTYPE                                 :: dlon=-_ONE_,dlat=-_ONE_
   REALTYPE,dimension(:,:),allocatable,target :: dxdyc,dydxc
   REALTYPE,dimension(:,:),allocatable,target :: dxc,dxu,dxv,dxx
   REALTYPE,dimension(:,:),allocatable,target :: dyc,dyu,dyv,dyx
   REALTYPE,dimension(:,:),allocatable,target :: areac,arcd1,arud1,arvd1

!  bottom roughness
   REALTYPE, dimension(:,:), allocatable    :: z0,zub0,zvb0
