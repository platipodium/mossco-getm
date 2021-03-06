#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE:  initialise - setup the entire model
!
! !INTERFACE:
   module initialise
!
! !DESCRIPTION:
!
! !USES:
   use register_all_variables
#ifdef _FLEXIBLE_OUTPUT_
   use output_manager_core, only:output_manager_host=>host, type_output_manager_host=>type_host
   use time, only: CalDat,JulDay
   use output_manager
#endif
   IMPLICIT NONE
!
! !PUBLIC DATA MEMBERS:
   public                    :: init_model
   public                    :: init_initialise,do_initialise
   integer                   :: runtype=1
   logical                   :: dryrun=.false.
   character(len=64)         :: runid
   character(len=80)         :: title
   logical                   :: hotstart=.false.
   logical                   :: use_epoch=.false.
   logical                   :: save_initial=.false.
   character(len=PATH_MAX)   :: input_dir=''
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard

#ifdef _FLEXIBLE_OUTPUT_
   type,extends(type_output_manager_host) :: type_getm_host
   contains
      procedure :: julian_day => getm_host_julian_day
      procedure :: calendar_date => getm_host_calendar_date
   end type
#endif
!
!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_model - initialise getm
!
! !INTERFACE:
   subroutine init_model(dstr,tstr)
!
! !DESCRIPTION:
!  Wrapper for the different parts of model and time initialisation.
!
! !USES:
   use time       , only: init_time
   use integration, only: MinN,MaxN
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   character(len=*)                    :: dstr,tstr
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_model() # ',Ncall
#endif

   call init_initialise(dstr,tstr)
   call init_time(MinN,MaxN)
   call do_initialise()

#ifdef DEBUG
   write(debug,*) 'Leaving init_model()'
   write(debug,*)
#endif
   return
   end subroutine init_model
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: init_initialise - first part of init_model
!
! !INTERFACE:
   subroutine init_initialise(dstr,tstr)
!
! !DESCRIPTION:
!  Reads the namelist and initialises parallel runs.
!
! !USES:
   use kurt_parallel, only: init_parallel
#ifdef GETM_PARALLEL
   use halo_mpi, only: init_mpi,print_MPI_info
#endif
   use getm_timers, only: init_getm_timers, tic, toc, TIM_INITIALIZE
   use exceptions
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   character(len=*)                    :: dstr,tstr
!
! !DESCRIPTION:
!  Reads the namelist and initialises parallel runs.
!
! !REVISION HISTORY:
!  22Nov Author name Initial code
!
! !LOCAL VARIABLES:
   logical                   :: parallel=.false.
   character(len=PATH_MAX)   :: namlst_file=''

   namelist /param/ &
             dryrun,runid,title,parallel,runtype,  &
             hotstart,use_epoch,save_initial
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'init_initialise() # ',Ncall
#endif
#ifndef NO_TIMERS
   call init_getm_timers()
#endif
   ! Immediately start to time (rest of) init:
   call tic(TIM_INITIALIZE)

   ! We need to pass info about the input directory
#if 0
   call getarg(1,base_dir)
   if(len_trim(base_dir) .eq. 0) then
      call getenv("base_dir",base_dir)
   end if
   if(len_trim(base_dir) .gt. 0) then
      base_dir = trim(base_dir) // '/'
   end if
#endif

!
! In parallel mode it is imperative to let the instances
! "say hello" right away. For MPI this changes the working directory,
! so that input files can be read.
!
#ifdef GETM_PARALLEL
   call init_mpi()
#endif

#ifdef INPUT_DIR
   input_dir=trim(INPUT_DIR) // '/'
   STDERR 'input_dir:'
   STDERR input_dir
#endif
#ifdef _NAMLST_FILE_
   namlst_file=trim(_NAMLST_FILE_)
#else
   namlst_file=trim(input_dir) // 'getm.inp'
#endif
!
! Open the namelist file to get basic run parameters.
!
   title='A descriptive title can be specified in the param namelist'
   open(NAMLST,status='unknown',file=namlst_file)
   read(NAMLST,NML=param)

#ifdef NO_BAROCLINIC
   if(runtype .ge. 3) then
      FATAL 'getm not compiled for baroclinic runs'
      stop 'init_initialise()'
   end if
#endif

#ifdef NO_3D
   if(runtype .ge. 2) then
      FATAL 'getm not compiled for 3D runs'
      stop 'init_initialise()'
   end if
#endif

! call all modules init_ ... routines

   if (parallel) then
#ifdef GETM_PARALLEL
      call init_parallel(runid,input_dir)
#else
      STDERR 'You must define GETM_PARALLEL and recompile'
      STDERR 'in order to run in parallel'
      stop 'init_initialise()'
#endif
   end if

   STDERR LINE
   STDERR 'getm: Started on  ',dstr,' ',tstr
   STDERR LINE
   STDERR 'Initialising....'
   STDERR LINE
   LEVEL1 'the run id is: ',trim(runid)
   LEVEL1 'the title is:  ',trim(title)

   select case (runtype)
      case (1)
         LEVEL1 '2D run (hotstart=',hotstart,')'
      case (2)
         LEVEL1 '3D run - no density (hotstart=',hotstart,')'
      case (3)
         LEVEL1 '3D run - frozen density (hotstart=',hotstart,')'
      case (4)
         LEVEL1 '3D run - full (hotstart=',hotstart,')'
      case default
         FATAL 'A non valid runtype has been specified.'
         stop 'init_initialise()'
   end select

   call toc(TIM_INITIALIZE)

#ifdef DEBUG
   write(debug,*) 'Leaving init_initialise()'
   write(debug,*)
#endif
   return
   end subroutine init_initialise
!EOC
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: do_initialise - second part of init_model
!
! !INTERFACE:
   subroutine do_initialise()
!
! !DESCRIPTION:
!  Makes calls to the init functions of the
!  various model components.
!
! !USES:
   use kurt_parallel, only: myid
   use output, only: init_output,do_output,restart_file,out_dir
   use input,  only: init_input
   use domain, only: init_domain
   use domain, only: H
   use domain, only: iextr,jextr,imin,imax,ioff,jmin,jmax,joff,kmax
   use domain, only: xcord,ycord
   use domain, only: vert_cord,maxdepth,ga
   use domain, only: have_boundaries
   use time, only: update_time,write_time_string
   use time, only: start,timestr,timestep
   use time, only: julianday,secondsofday
   use m2d, only: init_2d,hotstart_2d,postinit_2d
   use variables_2d, only: Dvel
   use les, only: init_les
   use getm_timers, only: tic, toc, TIM_INITIALIZE
#ifndef NO_3D
   use m3d, only: init_3d,hotstart_3d,postinit_3d
#ifndef NO_BAROCLINIC
   use m3d, only: T
#endif
   use m3d, only: use_gotm
   use turbulence, only: init_turbulence
   use mtridiagonal, only: init_tridiagonal
   use rivers, only: init_rivers
   use variables_3d, only: avmback,avhback
#ifdef SPM
   use suspended_matter, only: init_spm
#endif
#ifdef _FABM_
   use getm_fabm, only: fabm_calc
   use getm_fabm, only: init_getm_fabm, postinit_getm_fabm
   use rivers, only: init_rivers_fabm
   use bdy_3d, only: init_bdy_3d_fabm
#endif
#ifdef GETM_BIO
   use bio, only: bio_calc
   use getm_bio, only: init_getm_bio
   use rivers, only: init_rivers_bio
#endif
#endif
   use parameters, only: init_parameters
   use meteo, only: metforcing,met_method,init_meteo,do_meteo
   use meteo, only: ssu,ssv
#ifndef NO_BAROCLINIC
   use meteo, only: swr,albedo
#endif
   use waves, only: init_waves,do_waves,waveforcing_method,NO_WAVES
   use integration,  only: MinN,MaxN
   use exceptions
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding & Hans Burchard
!
! !LOCAL VARIABLES:
   character(len=8)          :: buf
   character(len=PATH_MAX)   :: hot_in=''
   character(len=16)         :: postfix
!EOP
!-------------------------------------------------------------------------
!BOC
#ifdef DEBUG
   integer, save :: Ncall = 0
   Ncall = Ncall+1
   write(debug,*) 'do_initialise() # ',Ncall
#endif

   call tic(TIM_INITIALIZE)

   if(use_epoch) then
      LEVEL2 'using "',start,'" as time reference'
   end if

   call init_domain(input_dir,runtype)

   call init_parameters()

   call init_meteo(hotstart)

   call init_waves(hotstart,runtype)

#ifndef NO_3D
   call init_rivers(hotstart)
#endif

   call init_2d(runtype,timestep,hotstart)

#ifndef NO_3D
   if (runtype .gt. 1) then
      call init_3d(runtype,timestep,hotstart)
      if (use_gotm) then
         call init_turbulence(60,trim(input_dir) // 'gotmturb.nml',kmax)
      end if
      call init_tridiagonal(kmax)

#ifdef SPM
      call init_spm(trim(input_dir) // 'spm.inp',runtype)
#endif
#ifdef _FABM_
      call init_getm_fabm(trim(input_dir) // 'getm_fabm.inp',hotstart)
      if (fabm_calc) then
         call init_rivers_fabm()
         if (have_boundaries) call init_bdy_3d_fabm()
      end if
#endif
#ifdef GETM_BIO
      call init_getm_bio(trim(input_dir) // 'getm_bio.inp')
      call init_rivers_bio
#endif
   end if
#endif

   call init_les(runtype)

   call init_register_all_variables(runtype)

#ifdef _FLEXIBLE_OUTPUT_
   allocate(type_getm_host::output_manager_host)
   if (myid .ge. 0) then
      write(postfix,'(A,I4.4)') '.',myid
      call output_manager_init(fm,title,trim(postfix))
   else
      call output_manager_init(fm,title)
   end if
#endif

!   call init_output(runid,title,start,runtype,dryrun,myid)
   call init_output(runid,title,start,runtype,dryrun,myid,MinN,MaxN,save_initial)

   call do_register_all_variables(runtype)

   close(NAMLST)

#if 0
   call init_biology(hotstart)
#endif

   if (hotstart) then
      LEVEL1 'hotstart'
      if (myid .ge. 0) then
         write(buf,'(I4.4)') myid
         buf = '.' // trim(buf) // '.in'
      else
         buf = '.in'
      end if
      hot_in = trim(out_dir) //'/'// 'restart' // trim(buf)
      call restart_file(READING,trim(hot_in),MinN,runtype,use_epoch)
      LEVEL3 'MinN adjusted to ',MinN
      call update_time(MinN)
      call write_time_string()
      LEVEL3 timestr
      MinN = MinN+1

      call hotstart_2d(runtype)
#ifndef NO_3D
      if (runtype .ge. 2) then
         call hotstart_3d(runtype)
      end if
#endif
   end if

!  Note (KK): init_input() calls do_3d_bdy_ncdf() which requires hn
   call init_input(input_dir,MinN)

   call toc(TIM_INITIALIZE)

   if (metforcing) then
      call set_sea_surface_state(runtype,ssu,ssv,.true.)
      if(runtype .le. 2) then
         call do_meteo(MinN-1)
         if (met_method .eq. 2) then
            call get_meteo_data(MinN-1)
            call do_meteo(MinN-1)
         end if
#ifndef NO_BAROCLINIC
      else
         call do_meteo(MinN-1,T(:,:,kmax))
         if (met_method .eq. 2) then
            call get_meteo_data(MinN-1)
            call do_meteo(MinN-1,T(:,:,kmax))
         end if
         swr = swr*(_ONE_-albedo)
#endif
      end if
   end if

   if (waveforcing_method .ne. NO_WAVES) then
      call do_waves(MinN-1,Dvel)
   end if

   call tic(TIM_INITIALIZE)

   call postinit_2d(runtype,timestep,hotstart,MinN)
#ifndef NO_3D
   if (runtype .gt. 1) then
      call postinit_3d(runtype,timestep,hotstart,MinN)
#ifdef _FABM_
      if (fabm_calc) call postinit_getm_fabm()
#endif
   end if
#endif

   call finalize_register_all_variables(runtype)

   call toc(TIM_INITIALIZE)

   if (.not. dryrun) then
      call do_output(runtype,MinN-1,timestep)
#ifdef _FLEXIBLE_OUTPUT_
      if (save_initial) call output_manager_save(julianday,secondsofday,MinN-1)
#endif
   end if

#ifdef DEBUG
   write(debug,*) 'Leaving do_initialise()'
   write(debug,*)
#endif
   return
   end subroutine do_initialise
!EOC

!-----------------------------------------------------------------------

#ifdef _FLEXIBLE_OUTPUT_
   subroutine getm_host_julian_day(self,yyyy,mm,dd,julian)
      class (type_getm_host), intent(in) :: self
      integer, intent(in)  :: yyyy,mm,dd
      integer, intent(out) :: julian
      call JulDay(yyyy,mm,dd,julian)
   end subroutine

   subroutine getm_host_calendar_date(self,julian,yyyy,mm,dd)
      class (type_getm_host), intent(in) :: self
      integer, intent(in)  :: julian
      integer, intent(out) :: yyyy,mm,dd
      call CalDat(julian,yyyy,mm,dd)
   end subroutine
#endif

   end module initialise

!-----------------------------------------------------------------------
! Copyright (C) 2001 - Hans Burchard and Karsten Bolding               !
!-----------------------------------------------------------------------
