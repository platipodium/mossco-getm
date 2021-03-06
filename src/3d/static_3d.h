! Remember to update this value if you add more 3D arrays.
#ifdef SPM
  integer, parameter                   :: n3d_fields=28
#else
  integer, parameter                   :: n3d_fields=25
#endif
! Number of vertical layers in z,u,v columns
  INTEGER                              :: kmin(I2DFIELD)
  INTEGER                              :: kumin(I2DFIELD)
  INTEGER                              :: kvmin(I2DFIELD)
  INTEGER                              :: kmin_pmz(I2DFIELD)
  INTEGER                              :: kumin_pmz(I2DFIELD)
  INTEGER                              :: kvmin_pmz(I2DFIELD)

  REALTYPE,dimension(I3DFIELD),target  :: uu,vv,ww
  REALTYPE,dimension(I3DFIELD),target  :: velx3d,vely3d,w
  REALTYPE,dimension(I2DFIELD),target  :: velx2dadv,vely2dadv

#ifdef _MOMENTUM_TERMS_
  REALTYPE                             :: tdv_u(I3DFIELD)
  REALTYPE                             :: adv_u(I3DFIELD)
  REALTYPE                             :: vsd_u(I3DFIELD)
  REALTYPE                             :: hsd_u(I3DFIELD)
  REALTYPE                             :: cor_u(I3DFIELD)
  REALTYPE                             :: epg_u(I3DFIELD)
  REALTYPE                             :: ipg_u(I3DFIELD)

  REALTYPE                             :: tdv_v(I3DFIELD)
  REALTYPE                             :: adv_v(I3DFIELD)
  REALTYPE                             :: vsd_v(I3DFIELD)
  REALTYPE                             :: hsd_v(I3DFIELD)
  REALTYPE                             :: cor_v(I3DFIELD)
  REALTYPE                             :: epg_v(I3DFIELD)
  REALTYPE                             :: ipg_v(I3DFIELD)
#endif
#ifdef STRUCTURE_FRICTION
  REALTYPE                             :: sf(I3DFIELD)
#endif
  REALTYPE                             :: ho(I3DFIELD)
  REALTYPE,dimension(I3DFIELD),target  :: hn,hvel,hun,hvn
  REALTYPE,dimension(I3DFIELD),target  :: zwn,zcn
  REALTYPE                             :: huo(I3DFIELD)
  REALTYPE                             :: hvo(I3DFIELD)
  REALTYPE                             :: hcc(I3DFIELD)
  REALTYPE                             :: uuEx(I3DFIELD)
  REALTYPE                             :: vvEx(I3DFIELD)
  REALTYPE                             :: num(I3DFIELD)
  REALTYPE, target                     :: nuh(I3DFIELD)

! 3D turbulent fields
  REALTYPE                             :: tke(I3DFIELD)
  REALTYPE                             :: eps(I3DFIELD)
  REALTYPE                             :: SS(I3DFIELD)

#ifndef NO_BAROCLINIC
! 3D baroclinic fields
  REALTYPE                             :: NN(I3DFIELD)
  REALTYPE, target                     :: S(I3DFIELD)
  REALTYPE, target                     :: T(I3DFIELD)
  REALTYPE, target                     :: rho(I3DFIELD)
  REALTYPE                             :: rad(I3DFIELD)
  REALTYPE, target                     :: buoy(I3DFIELD)
  REALTYPE                             :: alpha(I3DFIELD)
  REALTYPE                             :: beta(I3DFIELD)
  REALTYPE                             :: light(I3DFIELD)
  REALTYPE                             :: heatflux_net(I2DFIELD)
#endif

#ifdef SPM
! suspended matter
  REALTYPE                             :: spm(I3DFIELD)
  REALTYPE                             :: spm_ws(I3DFIELD)
  REALTYPE                             :: spm_pool(I2DFIELD)
#endif

! 2D fields in 3D domain
  REALTYPE                             :: sseo(I2DFIELD)
  REALTYPE                             :: ssen(I2DFIELD)
  REALTYPE                             :: ssuo(I2DFIELD)
  REALTYPE                             :: ssun(I2DFIELD)
  REALTYPE                             :: ssvo(I2DFIELD)
  REALTYPE                             :: ssvn(I2DFIELD)
  REALTYPE,dimension(I2DFIELD),target  :: Dn,Dveln,Dun,Dvn
  REALTYPE,dimension(I2DFIELD),target  :: Uadv,Vadv

! 3D friction in 3D domain
  REALTYPE                             :: rru(I2DFIELD)
  REALTYPE                             :: rrv(I2DFIELD)
  REALTYPE,dimension(I2DFIELD)         :: zub,zvb
  REALTYPE                             :: taus(I2DFIELD)
  REALTYPE                             :: taubx(I2DFIELD)
  REALTYPE                             :: tauby(I2DFIELD)
  REALTYPE, target                     :: taub(I2DFIELD)

! light attenuation
  REALTYPE,target                      :: A(I2DFIELD)
  REALTYPE,target                      :: g1(I2DFIELD)
  REALTYPE,target                      :: g2(I2DFIELD)
  REALTYPE,target                      :: bioshade(I3DFIELD)
