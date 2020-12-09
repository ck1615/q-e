!
! Copyright (C) 2019 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-----------------------------------------------------------------------------------
PROGRAM xclib_test
  !--------------------------------------------------------------------------------
  !! Testing program for xc_lib library in QE. Different options:
  !
  !! * dft-info: infos on the input DFT;
  !! * xc-benchmark: difference with respect to a given set of benchmark data (on file);
  !! * gen-benchmark: generate set of benchmark data on file;
  !! * dft-comparison: show difference between two DFTs (E and V differences).
  !
  !! Available cases:
  !
  !! * LDA;
  !! * derivative of LDA (dmxc);
  !! * GGA;
  !! * derivative of GGA (dgcxc);
  !! * metaGGA.
  !
  USE kind_l,  ONLY: DP
  !use dft_par_mod
  USE constants_l, ONLY: pi
  USE xc_lib,  ONLY: xclib_set_dft_from_name, xclib_set_exx_fraction, &
                     xclib_get_ID, xclib_reset_dft, xc_gcx
  USE xclib_parallel_include
#if defined(__LIBXC)
  USE xc_f03_lib_m
#endif
  !
  IMPLICIT NONE
  !
#if defined(__MPI)
  INTEGER    STATUS(MPI_STATUS_SIZE)
#else
#define MPI_MAX_PROCESSOR_NAME 64
#endif  
  INTEGER :: mype, npes, comm, ntgs, root
  LOGICAL :: iope
  INTEGER :: ierr, ierrm
  
  INTEGER :: nnodes, nlen
  INTEGER :: i
  
  !
  INTEGER, PARAMETER :: stdin  = 5
  INTEGER, PARAMETER :: stdout = 6
  !
  INTEGER, PARAMETER :: npoints = 90000
  !
  INTEGER :: nnr_b, nnr2, nnr_int, nnrb, nnrt, nnrbt
  !
  CHARACTER(LEN=30) :: test, family
  
  INTEGER :: nr, nnr, nrpe, nspin, nskip
  REAL(DP) :: aver_sndu, aver_recu, fact
  
  REAL(DP) :: rhoi(2), grhoi(3,2), taui(2)
  
  !-------- Common vars ----------------------
  
  CHARACTER(LEN=120) :: aprx, e_q, f_q
  INTEGER :: ii, ns, np, ipol, quit, i_sub, ithr, nthr, iip, iout
  REAL(DP) :: exx_frctn
  LOGICAL :: LDA, GGA, MGGA, POLARIZED, ENERGY_ONLY, DF_OK
  !LOGICAL :: is_it_out, is_dit_out
  REAL(DP), PARAMETER :: null=0.0_DP, pi34=0.6203504908994_DP
  REAL(DP), PARAMETER :: thresh_lda  = 0.d0, & !1.E-6_DP, &
                         thresh_gga  = 0.d0, & !1.E-6_DP, &
                         thresh_mgga = 0.d0 !1.E-6_DP
  !
  INTEGER :: iexch1, icorr1, igcx1, igcc1, imeta1, imetac1
  INTEGER :: iexch2, icorr2, igcx2, igcc2, imeta2, imetac2
  !
  !----------dft1 vars --------------------------
  REAL(DP), ALLOCATABLE :: rho(:,:), rho_tz(:,:), rho_b(:,:),rhotz_b(:,:) !,rhobr(:,:)
  REAL(DP), ALLOCATABLE :: grho(:,:,:), grh(:,:,:), grho_b(:,:,:), grh_b(:,:,:)
  REAL(DP), ALLOCATABLE :: ex1(:), ec1(:)
  REAL(DP), ALLOCATABLE :: exg1(:), ecg1(:)
  REAL(DP), ALLOCATABLE :: vx1(:,:), vc1(:,:)
  REAL(DP), ALLOCATABLE :: dmuxc1(:,:,:)
  REAL(DP), ALLOCATABLE :: dvxcrr1(:,:,:), dvxcsr1(:,:,:), &
                           dvxcss1(:,:,:)
  !
  REAL(DP), ALLOCATABLE :: v1x1(:,:), v2x1(:,:), v3x1(:,:)
  REAL(DP), ALLOCATABLE :: v1c1(:,:), v2c_ud1(:)
  REAL(DP), ALLOCATABLE :: v2c1(:,:), v3c1(:,:)
  !
  !--------- dft2 vars -----------------------
  CHARACTER(LEN=120) :: name1, name2
  !
  CHARACTER(LEN=30) :: dft1
  CHARACTER(LEN=30) :: dft2
  !
  REAL(DP), ALLOCATABLE :: tau(:,:), tau_b(:,:)
  REAL(DP), ALLOCATABLE :: ex2(:), ec2(:)
  REAL(DP), ALLOCATABLE :: exg2(:), ecg2(:)
  REAL(DP), ALLOCATABLE :: vx2(:,:), vc2(:,:)
  REAL(DP), ALLOCATABLE :: dmuxc2(:,:,:)
  REAL(DP), ALLOCATABLE :: dvxcrr2(:,:,:), dvxcsr2(:,:,:), &
                           dvxcss2(:,:,:)
  !
  REAL(DP), ALLOCATABLE :: v1x2(:,:), v2x2(:,:), v3x2(:,:)
  REAL(DP), ALLOCATABLE :: v1c2(:,:), v2c2(:,:), v2c_ud2(:)
  REAL(DP), ALLOCATABLE :: v2cm(:,:,:), v3c2(:,:)
  !
  !----------diff vars --------------------------
  LOGICAL :: ex_is_out, ec_is_out, vx_is_out, vc_is_out, &
             something_out, dmuxc_is_out
  LOGICAL :: v1x_is_out, v2x_is_out, v1c_is_out, v2c_is_out, &
             v3x_is_out, v3c_is_out, &
             dvxcrr_is_out, dvxcsr_is_out, dvxcss_is_out, dvgga_is_out
  !
  REAL(DP) :: diff_thr_v_lda, diff_thr_e_lda, diff_thr_dmuxc
  REAL(DP) :: diff_thr_e_gga, diff_thr_v_gga, diff_thr_dvxc
  REAL(DP) :: diff_thr_e_mgga, diff_thr_v_mgga
  !
  REAL(DP) :: grho2(2)
  REAL(DP) :: grho_ud
  !
  !
  !
  ! ... LDA benchmark data
  REAL(DP) :: ex_aver_b(2),   ec_aver_b(2),   &
              vx_aver_b(1,2), vc_aver_b(1,2), &
              dv_aver_b(3)
  !
  ! ... GGA benchmark data
  REAL(DP) :: v1x_aver_b(1,2), v1c_aver_b(1,2), &
              v2x_aver_b(1,2), v2c_aver_b(1,3), &
              v2c_ud1_aver(2), v2c_ud1_min(2), v2c_ud1_max(2), &
              dvxcrr_aver_b(1,3), dvxcsr_aver_b(1,3), &
              dvxcss_aver_b(1,3)
  !
  ! ... mGGA benchmark data
  REAL(DP) :: v3x_aver_b(1,2), v3c_aver_b(1,2)

  !
  REAL(DP) :: vaver(2), vmax(2), vmin(2)
  !
  !
  CHARACTER(LEN=MPI_MAX_PROCESSOR_NAME), allocatable :: proc_name(:)
  CHARACTER(LEN=MPI_MAX_PROCESSOR_NAME), allocatable :: node_name(:)
  INTEGER, allocatable :: proc2node(:)
#if defined(_OPENMP)
  INTEGER, EXTERNAL :: omp_get_max_threads
#endif
  !
#if defined(_OPENMP)
  INTEGER :: PROVIDED
#endif
  !
  NAMELIST /input_namelist/ test, nspin, family, DF_OK, dft1, dft2
  !
  NAMELIST /lda_benchmark_data / ex_aver_b, ec_aver_b, vx_aver_b, vc_aver_b, &
                                 ex2, ec2, vx2, vc2
  NAMELIST /dlda_benchmark_data/ dv_aver_b, dmuxc2
  NAMELIST /gga_benchmark_data / ex_aver_b, ec_aver_b, v1x_aver_b, v1c_aver_b, &
                                 v2x_aver_b, v2c_aver_b,v2c_ud1_aver, ex2, ec2,&
                                 v1x2, v1c2, v2x2, v2c2, v2c_ud2
  NAMELIST /dgga_benchmark_data/ dvxcrr_aver_b, dvxcsr_aver_b, dvxcss_aver_b,  &
                                 dvxcrr2, dvxcsr2, dvxcss2
  NAMELIST /mgga_benchmark_data/ ex_aver_b, ec_aver_b, ex_aver_b, ec_aver_b,     &
                                 v1x_aver_b, v1c_aver_b, v2x_aver_b, v2c_aver_b, &
                                 v3x_aver_b, v3c_aver_b, ex2, ec2, v1x2, v1c2,   &
                                 v2x2, v2c2, v3x2, v3c2
  !
#if defined(__MPI)
  !
#if defined(_OPENMP)
  CALL MPI_Init_thread(MPI_THREAD_FUNNELED, PROVIDED, ierr)
#else
  CALL MPI_Init(ierr)
#endif  
  CALL mpi_comm_rank(MPI_COMM_WORLD,mype,ierr)
  CALL mpi_comm_size(MPI_COMM_WORLD,npes,ierr)
  comm = MPI_COMM_WORLD
  ntgs = 1
  root = 0
  IF(mype==root) THEN
     iope = .TRUE.
  ELSE
     iope = .FALSE.
  ENDIF
#else
  mype = 0
  npes = 1
  comm = 0
  ntgs = 1
  root = 0
  iope = .TRUE.
#endif
  !
  ! ... init
  test = 'none'
  dft1 = 'none'
  dft2 = 'none'
  DF_OK = .FALSE.
  energy_only = .FALSE.
  nspin = 1
  !
  ! ... get input from file
  !
  IF (mype==root) THEN
    READ( stdin, input_namelist )
    IF ( test(1:4)=='gen-' ) THEN
      test = 'exe-benchmark'
      WRITE( stdout, input_namelist )
      test = 'gen-benchmark'
    ENDIF  
  ENDIF
  !
#if defined(__MPI)
  CALL MPI_BCAST( test,   30, MPI_CHARACTER, 0, MPI_COMM_WORLD, ierr )
  CALL MPI_BCAST( family, 30, MPI_CHARACTER, 0, MPI_COMM_WORLD, ierr )
  CALL MPI_BCAST( dft1,   30, MPI_CHARACTER, 0, MPI_COMM_WORLD, ierr )
  CALL MPI_BCAST( dft2,   30, MPI_CHARACTER, 0, MPI_COMM_WORLD, ierr )
  CALL MPI_BCAST( nspin,   1, MPI_INT,       0, MPI_COMM_WORLD, ierr )
  CALL MPI_BCAST( DF_OK,   1, MPI_LOGICAL,   0, MPI_COMM_WORLD, ierr )
#endif
  !
  !
  ALLOCATE( proc_name( npes ) )
  ALLOCATE( node_name( npes ) )
  ALLOCATE( proc2node( npes ) )
  nnodes = 0
  !
  DO i = 1, npes
#if defined(__MPI)
    IF ( mype == i-1 ) THEN
       CALL MPI_Get_processor_name( proc_name(i), nlen, ierr )
    ENDIF
    CALL MPI_BCAST( nlen, 1, MPI_INT, i-1, MPI_COMM_WORLD, ierr )
    CALL MPI_BCAST( proc_name(i), MPI_MAX_PROCESSOR_NAME, MPI_CHARACTER,&
                    i-1, MPI_COMM_WORLD, ierr )
#else
     proc_name(i) = 'localhost'
#endif
!      IF( mype == root ) THEN
!        write(6,310)  i, proc_name(i)
!      ENDIF
310 FORMAT(' pe = ',I5,' name = ', A20) 
    DO ii = 1, nnodes
       IF ( proc_name(i) == node_name(ii) ) THEN
          EXIT
       ENDIF
    ENDDO
    !
    IF ( ii > nnodes ) THEN
       nnodes = nnodes + 1
       node_name(nnodes) = proc_name(i)
    ENDIF
    proc2node(i) = ii
  ENDDO
  !
  IF ( mype == root .AND. test/='gen-benchmark' ) THEN
    WRITE(stdout,*) ; WRITE(stdout,*) ' --- XC_LIB TESTING PROGRAM --- '
    WRITE(stdout,*)
    WRITE(stdout,*) 'Node list:'
    WRITE(stdout,*) 
    DO ii = 1, nnodes
       WRITE(stdout,310)  ii, node_name(ii)
    ENDDO
    WRITE(stdout,*) ; WRITE(stdout,*) 'Test type: ', test
    WRITE(stdout,*)
  ENDIF
  !
#if defined(__MPI)
  CALL MPI_BARRIER( MPI_COMM_WORLD, ierr)
#endif
!

!============================================================  
!     !
!     IF ( test=='dft-info' ) THEN
!       !
!       CALL xclib_set_dft_from_name( dft1 )
!       !
!       WRITE(stdout,*) " "
!       WRITE(stdout,*) "=================================== "//CHAR(10)//" "
!       WRITE(stdout,*) "QE functional IDs:"//CHAR(10)//" "
!       !
!       ! ... q-e
!       !
!       WRITE(stdout,*) "- LDA IDs: ",  iexch1, icorr1
!       !
!       IF ( GGA )  WRITE(stdout,*) "- GGA IDs: ",  igcx1,  igcc1
!       !
!       IF ( MGGA ) WRITE(stdout,*) "- MGGA IDs: ", imeta1, imetac1
!       !
!       ! ... libxc
!       !
!       WRITE(stdout,*) " "
!       WRITE(stdout,*) "LIBXC functional IDs and info:"//CHAR(10)//" "
!       IF ( LDA ) THEN
!         !
!         name1 = xc_f03_functional_get_name( iexch2 )
!         name2 = xc_f03_functional_get_name( icorr2 )
!         !
!         WRITE(stdout,*) "- LDA IDs: ", iexch2, icorr2
!         WRITE(stdout,*) "- LDA exch: " , TRIM(name1)
!         WRITE(stdout,*) "- LDA corr: " , TRIM(name2)
!         WRITE(stdout,*) " "
!       ENDIF
!       !
!       IF ( GGA ) THEN
!         !
!         name1 = xc_f03_functional_get_name( igcx2 )
!         name2 = xc_f03_functional_get_name( igcc2 )
!         !
!         WRITE(stdout,*) "- GGA IDs: ", igcx2, igcc2
!         WRITE(stdout,*) "- GGA exch: " , TRIM(name1)
!         WRITE(stdout,*) "- GGA corr: " , TRIM(name2)
!         WRITE(stdout,*) " "
!       ENDIF
!       !
!       IF ( MGGA ) THEN
!         !
!         name1 = xc_f03_functional_get_name( imeta2 )
!         name2 = xc_f03_functional_get_name( imetac2 )
!         !
!         WRITE(stdout,*) "- MGGA IDs: ", imeta2, imetac2
!         WRITE(stdout,*) "- MGGA exch: " , TRIM(name1)
!         WRITE(stdout,*) "- MGGA corr: " , TRIM(name2)
!         WRITE(stdout,*) " "
!       ENDIF
!   
!   
! !      -..............
!   
!   
!       !
!     ENDIF !dft-info
!     !
!   ENDIF !ionode
!==================================================================================
  !
  !
  ! ... point distribution over CPUs
  !
  nr = 0
  IF ( MOD(npoints,npes)<=(mype+1) ) nr = 1
  nnr = npoints/npes + ABS(nr-1)
  IF (nr==1) nrpe = mype*nnr
  IF (nr==0) nrpe = npoints-(npoints/npes)*(npes-mype-1)
  !
  ns = nspin
  !
  ! ... initialization of averages
  !
  ex_aver_b  = 0._DP ; ec_aver_b  = 0._DP
  vx_aver_b  = 0._DP ; vc_aver_b  = 0._DP
  v1x_aver_b = 0._DP ; v2x_aver_b = 0._DP
  v3x_aver_b = 0._DP ; v1c_aver_b = 0._DP
  v2c_aver_b = 0._DP ; v3c_aver_b = 0._DP
  dv_aver_b  = 0._DP
  dvxcrr_aver_b = 0._DP
  dvxcsr_aver_b = 0._DP
  dvxcss_aver_b = 0._DP
  !
  ! ... initialize first DFT
  !
  CALL xclib_set_dft_from_name( dft1 )
  !
  LDA = .FALSE.
  GGA = .FALSE.
  MGGA= .FALSE.
  !
  iexch1 = xclib_get_ID('LDA','EXCH')
  icorr1 = xclib_get_ID('LDA','CORR')
  IF (iexch1+icorr1/=0)  LDA = .TRUE.
  igcx1 = xclib_get_ID('GGA','EXCH')
  igcc1 = xclib_get_ID('GGA','CORR')
  IF (igcx1+igcc1/=0)    GGA = .TRUE.
  imeta1  = xclib_get_ID('MGGA','EXCH')
  imetac1 = xclib_get_ID('MGGA','CORR')
  IF (imeta1+imetac1/=0) MGGA = .TRUE.
  !
  IF ( MGGA .AND. DF_OK ) THEN
    WRITE(stdout,*) " "
    WRITE(stdout,*) "ERROR: derivative not available with MGGA."
    GO TO 10
  ENDIF
  !
  IF (ns == 2 .AND. icorr1/=0 .AND. icorr1/=1 .AND. icorr1/=2 .AND. &
                    icorr1/=4 .AND. icorr1/=8 .AND. icorr1/=3 .AND. &
                    icorr1/=7 .AND. icorr1/=13) THEN
     WRITE(stdout,*) CHAR(10)//" ERROR: icorr1 not available at these &
                               &conditions"//CHAR(10)
     GO TO 10
  ENDIF
  !
  !
  ! ... index stuff
  !
  POLARIZED = .FALSE.
  IF (ns == 2) THEN
     POLARIZED = .TRUE.
  ENDIF
  !
  IF (.NOT. POLARIZED) THEN
    nnr_b = 1
  ELSE
    IF (LDA ) nnr_b = 2
    IF (GGA ) nnr_b = 4
    IF (MGGA) nnr_b = 5
  ENDIF  
  !
  IF (LDA ) nthr = 1
  IF (GGA ) nthr = 2
  IF (MGGA) nthr = 3
  !
  nnrt = nnr+nthr
  nnrb = nnr
  IF (test(5:13)=='benchmark') nnrb = nnr_b
  nnrbt = nnrb+nthr
  ! 
  np = 1
  IF (ns==2) np = 3
  !
  !
  ! ------ ALLOCATIONS --------
  !
  ! ... input
  !
  ALLOCATE( rho(nnrt,ns) )
  ALLOCATE( rho_tz(nnrt,ns) )
  IF ( GGA .OR. MGGA ) ALLOCATE( grho(3,nnrt,ns) )
  IF ( MGGA ) ALLOCATE( tau(nnrt,ns) )
  !
  IF ( test(5:13)=='benchmark' ) THEN
    ALLOCATE( rhotz_b(nnrbt,ns) )
    ALLOCATE( rho_b(nnr_b+nthr,ns) )
    IF ( GGA .OR. MGGA ) ALLOCATE( grho_b(3,nnr_b+nthr,ns) )
    IF ( MGGA ) ALLOCATE( tau_b(nnr_b+nthr,ns) )
  ENDIF
  !
  ! ... dft1 output arrays
  !
  IF (.NOT. DF_OK) ALLOCATE( ex1(nnrt), ec1(nnrt) )
  !
  IF ( LDA .OR. GGA ) THEN
     IF ( LDA ) THEN
       IF ( .NOT. DF_OK ) THEN
         ALLOCATE( vx1(nnrt,ns), vc1(nnrt,ns) )
       ELSE
         ALLOCATE( dmuxc1(nnrt,ns,ns) )
       ENDIF 
     ENDIF
     !
     IF ( GGA ) THEN
       IF ( .NOT. DF_OK ) THEN
         ALLOCATE( exg1(nnrt), ecg1(nnrt) )
         ALLOCATE( v1x1(nnrt,ns), v2x1(nnrt,ns) )
         ALLOCATE( v1c1(nnrt,ns) )
         ALLOCATE( v2c1(nnrt,ns), v2c_ud1(nnrt) )
       ELSE
         ALLOCATE( grh(nnrt,3,ns) )
         IF ( test(5:13)=='benchmark' ) ALLOCATE( grh_b(nnrt,3,ns) )
         ALLOCATE( dvxcrr1(nnrt,ns,ns), dvxcsr1(nnrt,ns,ns), &
                   dvxcss1(nnrt,ns,ns) )
       ENDIF
     ENDIF
  ELSEIF ( MGGA ) THEN
     ALLOCATE( v1x1(nnrt,ns), v2x1(nnrt,ns) )
     ALLOCATE( v1c1(nnrt,ns) )
     ALLOCATE( v2c1(nnrt,ns) )
     ALLOCATE( v3x1(nnrt,ns), v3c1(nnrt,ns) )
  ENDIF
  !
  ! ... dft2 output / benchmark data arrays
  !
  IF (.NOT. DF_OK) ALLOCATE( ex2(nnrbt), ec2(nnrbt) )
  !
  IF ( LDA .OR. GGA ) THEN
     IF ( LDA ) THEN
       IF ( .NOT. DF_OK ) THEN
         ALLOCATE( vx2(nnrbt,ns), vc2(nnrbt,ns) )
       ELSE
         ALLOCATE( dmuxc2(nnrbt,ns,ns) )
       ENDIF 
     ENDIF
     !
     IF ( GGA ) THEN
       IF ( .NOT. DF_OK ) THEN
         ALLOCATE( exg2(nnrbt), ecg2(nnrbt) )
         ALLOCATE( v1x2(nnrbt,ns), v2x2(nnrbt,ns) )
         ALLOCATE( v1c2(nnrbt,ns) )
         ALLOCATE( v2c2(nnrbt,ns), v2c_ud2(nnrbt) )
       ELSE
         ALLOCATE( dvxcrr2(nnrbt,ns,ns), dvxcsr2(nnrbt,ns,ns), &
                   dvxcss2(nnrbt,ns,ns) )
       ENDIF
     ENDIF
  ELSEIF ( MGGA ) THEN
     ALLOCATE( v1x2(nnrbt,ns), v2x2(nnrbt,ns) )
     ALLOCATE( v1c2(nnrbt,ns) )
     ALLOCATE( v2c2(nnrbt,ns) )
     ALLOCATE( v3x2(nnrbt,ns), v3c2(nnrbt,ns) )
  ENDIF
  !
  !
  !=========================================================================
  ! SET (PROVISIONAL) INPUT GRID FOR BENCHMARK TEST:
  ! ========================================================================
  ! LDA
  ! rho unpol 1p 0.6
  ! 
  ! rho pol   2p 0.6 0.1
  !              0.1 0.6
  ! --------------------------
  ! GGA
  ! rho  unpol 1p  0.6      grho 0.1 0.2 0.3
  ! 
  ! rho  pol   4p  0.6 0.1  grho 0.1 0.2 0.3  0.4 0.3 0.2
  !                0.1 0.6       0.1 0.2 0.3  0.4 0.3 0.2 
  !                0.6 0.1       0.4 0.3 0.2  0.1 0.2 0.3
  !                0.1 0.6       0.4 0.3 0.2  0.3 0.2 0.1
  ! --------------------------
  ! MGGA
  ! rho  unpol 1p  0.6      grho 0.1 0.2 0.3               tau 0.1
  ! 
  ! rho  pol   5p  0.6 0.1  grho 0.1 0.2 0.3  0.4 0.3 0.2  tau 0.1 0.2
  !                0.1 0.6       0.1 0.2 0.3  0.4 0.3 0.2  tau 0.1 0.2
  !                0.6 0.1       0.4 0.3 0.2  0.1 0.2 0.3  tau 0.1 0.2
  !                0.1 0.6       0.4 0.3 0.2  0.3 0.2 0.1  tau 0.1 0.2
  !                0.1 0.6       0.4 0.3 0.2  0.3 0.2 0.1  tau 0.2 0.1
  ! --------------------------  
  !
  !
  IF (test(5:13)=='benchmark' .AND. mype==root) THEN
    IF (nspin == 1) THEN
      rho_b(1,1) = 0.6_DP ; rhotz_b(1,1) = 0.6_DP
      IF (family/='LDA')  grho_b(:,1,1) = (/ 0.1_DP, 0.2_DP, 0.3_DP /)
      IF (family=='MGGA') tau_b(1,1) = 0.1_DP
    ELSE
      DO i = 1, nnr_b
        IF (MOD(i,2)==0) rho_b(i,:) = (/ 0.6_DP, 0.1_DP /) 
        IF (MOD(i,2)/=0) rho_b(i,:) = (/ 0.1_DP, 0.6_DP /)
        IF (MOD(i,2)==0) rhotz_b(i,:) = (/ 0.7_DP, 0.5_DP /) 
        IF (MOD(i,2)/=0) rhotz_b(i,:) = (/ 0.7_DP, -0.5_DP /)
        IF ( family/='LDA') THEN
          IF (i<=2) THEN
            grho_b(:,i,1) = (/ 0.1_DP, 0.2_DP, 0.3_DP /)
            grho_b(:,i,2) = (/ 0.4_DP, 0.3_DP, 0.2_DP /)
          ELSE
            grho_b(:,i,1) = (/ 0.4_DP, 0.3_DP, 0.2_DP /)
            grho_b(:,i,2) = (/ 0.1_DP, 0.2_DP, 0.3_DP /)
          ENDIF
        ENDIF
      ENDDO
      !
      IF (family=='MGGA') THEN
        rho_b(5,:) = (/ 0.1_DP, 0.6_DP /)
        grho_b(:,5,1) = (/ 0.4_DP, 0.3_DP, 0.2_DP /)
        grho_b(:,5,2) = (/ 0.1_DP, 0.2_DP, 0.3_DP /)
        DO i = 1, 4
          tau_b(i,:) = (/ 0.1_DP, 0.2_DP/)
        ENDDO  
        tau_b(5,:) = (/ 0.2_DP, 0.1_DP /)
      ENDIF
    ENDIF
  ENDIF
  !
  !============================================================================
  ! READ BENCHMARK DATA FROM FILE
  !============================================================================
  !
  IF (test=='exe-benchmark' .AND. mype==root) THEN
    IF (.NOT. DF_OK) THEN
      IF (family=='LDA' ) READ(stdin, lda_benchmark_data)
      IF (family=='GGA' ) READ(stdin, gga_benchmark_data)
      IF (family=='MGGA') READ(stdin, mgga_benchmark_data)
    ELSE
      IF (family=='LDA')  READ(stdin, dlda_benchmark_data)
      IF (family=='GGA')  READ(stdin, dgga_benchmark_data)
    ENDIF
  ENDIF
  !
  !============================================================================
  ! BUILD ARBITRARY INPUT FOR A LARGE GRID (for Etot and Vtot test)
  !============================================================================
  !
  fact = (3.d0/5.d0)*(3.d0*pi*pi)**(2.0/3.0)
  !
  rho  = 0.0_DP
  IF ( GGA .OR. MGGA ) grho = 0.0_DP
  IF ( MGGA ) tau = 0.0_DP
  !
  DO ii = 1, nnr
     !
     iip = nrpe+ii
     !
     rho(ii,1) = DBLE(iip)/DBLE(npoints+2)
     IF (.NOT. POLARIZED) rho_tz(ii,1) = rho(ii,1)
     !  
     IF ( GGA .OR. MGGA ) THEN
       grho(1,ii,1) = ABS( 0.05_DP + 0.8_DP*SIN(DBLE(iip)) )
       grho(2,ii,1) = ABS( 0.05_DP + 0.7_DP*SIN(DBLE(iip)) )
       grho(3,ii,1) = ABS( 0.05_DP + 0.6_DP*SIN(DBLE(iip)) )
     ENDIF  
     !
     IF ( MGGA ) tau(ii,1) = fact*ABS(rho_b(ii,1)*ns)**(5.0/3.0)/ns
     !  
     IF ( POLARIZED ) THEN  
        !  
        rho(ii,2) = (1.0_DP - rho(ii,1))*0.7_DP  
        rho_tz(ii,1) = rho(ii,1) + rho(ii,2)  
        rho_tz(ii,2) = rho(ii,1) - rho(ii,2)  
        !  
        IF ( GGA .OR. MGGA ) THEN  
           grho(1,ii,2) = ABS( (1.0_DP - grho(1,ii,1))*0.7_DP )  
           grho(2,ii,2) = ABS( (1.0_DP - grho(2,ii,1))*0.6_DP )
           grho(3,ii,2) = ABS( (1.0_DP - grho(3,ii,1))*0.5_DP )
        ENDIF
        !  
        IF ( MGGA ) tau(ii,2) = fact*ABS(rho_b(ii,2)*ns)**(5.0/3.0)/ns
        !  
     ENDIF
     !
  ENDDO
  !
  !
  !--- THRESHOLD POINTS ---
  rho(nnr+1,1) = thresh_lda/3.0_DP
  IF (.NOT. POLARIZED) rho_tz(nnr+1,1) = rho(nnr+1,1)
  IF ( POLARIZED ) THEN
     rho(nnr+1,2) = rho(nnr,1)
     rho_tz(nnr+1,1) = rho(nnr+1,1) + rho(nnr+1,2)
     rho_tz(nnr+1,2) = rho(nnr+1,1) - rho(nnr+1,2)
  ENDIF
  !
  IF ( GGA .OR. MGGA ) THEN
    grho(:,nnr+1,1) = grho(:,nnr,1)
    !
    rho(nnr+2,:) = rho(nnr,:)
    IF (.NOT. POLARIZED) rho_tz(nnr+2,1) = rho(nnr+2,1)
    !
    grho(:,nnr+2,1) = thresh_gga/10
    IF ( POLARIZED ) THEN
      rho_tz(nnr+2,1) = rho(nnr+2,1) + rho(nnr+2,2)
      rho_tz(nnr+2,2) = rho(nnr+2,1) - rho(nnr+2,2)
      grho(:,nnr+2,2) = grho(:,nnr,2)
    ENDIF
    !
    IF ( MGGA ) THEN  
      tau(nnr+1,:) = tau(nnr,:)
      tau(nnr+2,:) = tau(nnr,:)
      !
      rho(nnr+3,:) = rho(nnr,:)
      grho(:,nnr+3,:) = grho(:,nnr,:)
      !
      tau(nnr+3,1) = thresh_mgga/10
      IF ( POLARIZED ) tau(nnr+3,2) = tau(nnr,2)
    ENDIF
    !
  ENDIF
  !
  IF (mype==root .AND. test(5:13)=='benchmark') THEN
    rho_b(nnrb+1:nnrbt,:) = rho(nnr+1:nnr+nthr,:)
    rhotz_b(nnrb+1:nnrbt,:) = rho_tz(nnr+1:nnr+nthr,:)
    IF (family/='LDA') grho_b(:,nnrb+1:nnrbt,:) = grho(:,nnr+1:nnr+nthr,:)
    IF (family=='MGGA') tau_b(nnrb+1:nnrbt,:) = tau(nnr+1:nnr+nthr,:)
    !
    rho(1:nnrbt,1:ns) = rho_b(1:nnrbt,1:ns)
    rho_tz(1:nnrbt,1:ns) = rhotz_b(1:nnrbt,1:ns)
    IF (family/='LDA')  grho(:,1:nnrbt,1:ns) = grho_b(:,1:nnrbt,1:ns)
    IF (family=='MGGA') tau(1:nnrbt,1:ns) = tau_b(1:nnrbt,1:ns)
  ENDIF
  !
  diff_thr_e_lda = 1.0E-6_DP
  diff_thr_v_lda = 1.0E-6_DP
  diff_thr_dmuxc = 1.0E-6_DP
  !
  diff_thr_e_gga = 1.0E-12_DP
  diff_thr_v_gga = 1.0E-12_DP
  diff_thr_dvxc  = 1.0E-16_DP
  !
  diff_thr_e_mgga = 1.0E-12_DP
  diff_thr_v_mgga = 1.0E-12_DP
  !
  
  !============================================================================
  ! Calculation of energies and potential 
  !==============================================================================
  !
  IF ( LDA ) THEN
     !
     IF (.NOT. DF_OK ) THEN 
       CALL xc( nnr+nthr, ns, ns, rho_tz, ex1, ec1, vx1, vc1 )
     ELSE
       CALL dmxc( nnr+nthr, ns, rho, dmuxc1 )
     ENDIF
     !
  ENDIF   
  !
  IF ( GGA ) THEN
    !
    IF ( .NOT. DF_OK ) THEN
      !
      IF ( .NOT. LDA ) THEN
        ex1 = 0.d0  ;  ec1 = 0.d0
        vx1 = 0.d0  ;  vc1 = 0.d0
      ENDIF
      !
      CALL xc_gcx( nnr+nthr, ns, rho, grho, exg1, ecg1, v1x1, v2x1, v1c1, v2c1, v2c_ud1 )
      !
      ex1 = ex1*rho_tz(:,1) + exg1
      ec1 = ec1*rho_tz(:,1) + ecg1
      !
      v1x1 = v1x1 + vx1
      v1c1 = v1c1 + vc1
      !
    ELSE
      !
      DO ii = 1, nnr+nthr
        grh(ii,1:3,1) = grho(1:3,ii,1)
        IF (ns==2) grh(ii,1:3,2) = grho(1:3,ii,2)
      ENDDO
      !
      CALL dgcxc( nnr+nthr, ns, rho, grh, dvxcrr1, dvxcsr1, dvxcss1 )
      !
      dvxcrr1 = dvxcrr1 + dmuxc1
      !
    ENDIF
     !
  ENDIF
  !
  IF ( MGGA ) THEN
     ALLOCATE( v2cm(np,nnr+nthr,ns) )
     CALL xc_metagcx( nnr+nthr, ns, np, rho, grho, tau, ex1, &
                      ec1, v1x1, v2x1, v3x1, v1c1, v2cm, v3c1 )
     !
     v2c1 = v2cm(1,:,:)
     DEALLOCATE( v2cm )
  ENDIF
  !
  !
  IF (test == 'dft-comparison'.OR. test(1:4)=='gen-') THEN
    !
    IF (test == 'dft-comparison') THEN
      CALL xclib_reset_dft()
      CALL xclib_set_dft_from_name( dft2 )
    ENDIF
    IF (test(1:4)=='gen-') dft2 = dft1
    !
    !
    LDA = .FALSE.
    GGA = .FALSE.
    MGGA= .FALSE.
    iexch2 = xclib_get_ID('LDA','EXCH')
    icorr2 = xclib_get_ID('LDA','CORR')
    IF (iexch2+icorr2/=0)  LDA = .TRUE.
    igcx2 = xclib_get_ID('GGA','EXCH')
    igcc2 = xclib_get_ID('GGA','CORR')
    IF (igcx2+igcc2/=0)    GGA = .TRUE.
    imeta2  = xclib_get_ID('MGGA','EXCH')
    imetac2 = xclib_get_ID('MGGA','CORR')
    IF (imeta2+imetac2/=0) MGGA = .TRUE.
    !
    
    IF ( LDA ) THEN
      IF ( .NOT. DF_OK ) THEN
          CALL xc( nnrb+nthr, ns, ns, rho_tz(1:nnrbt,:), ex2, ec2, vx2, vc2 )
      ELSE
          CALL dmxc( nnrb+nthr, ns, rho(1:nnrbt,:), dmuxc2 )
      ENDIF
    ENDIF
    !
    !
    IF ( GGA ) THEN
      IF ( .NOT. DF_OK ) THEN
        !
        IF ( .NOT. LDA ) THEN
          ex2 = 0.d0  ;  ec2 = 0.d0
          vx2 = 0.d0  ;  vc2 = 0.d0
        ENDIF
        !
        CALL xc_gcx( nnrbt, ns, rho(1:nnrbt,:), grho(:,1:nnrbt,:), exg2, ecg2, &
                     v1x2, v2x2, v1c2, v2c2, v2c_ud2 )
        !
        ex2 = ex2*rho_tz(1:nnrbt,1) + exg2
        ec2 = ec2*rho_tz(1:nnrbt,1) + ecg2
        !
        v1x2 = v1x2 + vx2
        v1c2 = v1c2 + vc2
        !
      ELSE
        !
        DO ii = 1, nnrbt
          grh(ii,1:3,1) = grho(1:3,ii,1)
          IF (ns==2) grh(ii,1:3,2) = grho(1:3,ii,2)
        ENDDO
        !
        CALL dgcxc( nnrbt, ns, rho(1:nnrbt,:), grh(1:nnrbt,:,:), dvxcrr2, dvxcsr2, dvxcss2 )
        !
        IF ( LDA ) dvxcrr2 = dvxcrr2 + dmuxc2
        !
      ENDIF
      !
    ENDIF
    !
    !
    IF ( MGGA ) THEN
      ALLOCATE( v2cm(np,nnrbt,ns) )
      CALL xc_metagcx( nnrbt, ns, np, rho(1:nnrbt,:), grho(:,1:nnrbt,:), tau(1:nnrbt,:), &
                       ex2, ec2, v1x2, v2x2, v3x2, v1c2, v2cm, v3c2 )
      v2c2 = v2cm(1,:,:)
      DEALLOCATE( v2cm )
    ENDIF    
    !
  ENDIF
  !
  !
  !====================================================================================
  ! COMPUTE AND PRINT TEST RESULTS
  !=====================================================================================
  !
  !
  IF (mype==root .AND. test(1:4)/='gen-') THEN
    WRITE(stdout,*) ' '
    WRITE(stdout,911) npoints
  ENDIF  
  !
  !... calculate statistics of E over a large number of points (npoints)
  !
  IF ( .NOT. DF_OK ) THEN
    CALL evxc_stats( 'Ex', diff_thr_e_lda, ex1, ex2, ex_aver_b )
    CALL evxc_stats( 'Ec', diff_thr_e_lda, ec1, ec2, ec_aver_b )
  ENDIF
  !
  !
  IF ( LDA .AND. .NOT. GGA ) THEN
     !
     !
     ! ... calculate statistics of V over a large number of points (npoints)
     !
     IF ( .NOT. DF_OK ) THEN
       CALL evxc_stats( 'Vx', diff_thr_v_lda, vx1, vx2, vx_aver_b(1,:) )
       CALL evxc_stats( 'Vc', diff_thr_v_lda, vc1, vc2, vc_aver_b(1,:) )
     ELSE
       CALL derivxc_stats( 'dmuxc', diff_thr_v_lda, dmuxc1, dmuxc2, dv_aver_b )
     ENDIF
     !
     !
     IF (test(5:13)=='benchmark') THEN
       ex_is_out = .TRUE.     ; ec_is_out = .TRUE.
       vx_is_out = .TRUE.     ; vc_is_out = .TRUE. 
       something_out = .TRUE. ; dmuxc_is_out = .TRUE.
     ENDIF  
     !
     ! 
     iout = 0
     !
     DO ii = 1, nnrb
        !
        IF ( mype/=root ) CYCLE
        !
        IF ( test == 'dft-comparison' ) THEN
          !
          IF ( .NOT. DF_OK ) THEN
            !
            ex_is_out = is_it_out( diff_thr_e_lda, 1, ex1(ii:ii), ex2(ii:ii) )
            ec_is_out = is_it_out( diff_thr_e_lda, 1, ec1(ii:ii), ec2(ii:ii) )
            !
            IF (.NOT. energy_only) THEN
              vx_is_out = is_it_out( diff_thr_v_lda,ns, vx1(ii,:), vx2(ii,:) )
              vc_is_out = is_it_out( diff_thr_v_lda,ns, vc1(ii,:), vc2(ii,:) )
            ENDIF
            something_out = ANY( (/ex_is_out, ec_is_out, vx_is_out, vc_is_out/) )
          ELSE
            dmuxc_is_out = is_dit_out( diff_thr_dmuxc, dmuxc1(ii,:,:), dmuxc2(ii,:,:) )
          ENDIF
          !
        ENDIF
        !        
        IF ( something_out .OR. dmuxc_is_out ) THEN
          !
          iout = iout + 1
          !
          IF (iout<=10) THEN
            IF (test(1:4)/='gen-') WRITE(stdout,*) " "
            !
            IF ( test=='exe-benchmark' ) THEN
              rhoi(1:ns)=rho_b(ii,1:ns)
              WRITE(stdout,909) nrpe+ii, nnr_b
            ELSEIF ( test=='dft-comparison' ) THEN
              rhoi(1:ns) = rho(ii,1:ns)
              WRITE(stdout,909) nrpe+ii, npoints
            ENDIF
            !
            IF (test(1:4)/='gen-') THEN
              IF ( .NOT. POLARIZED ) WRITE(stdout, 401 ) rhoi(1)
              IF (       POLARIZED ) WRITE(stdout, 402 ) rhoi(1), rhoi(2)
              WRITE(stdout,*) " "
            ENDIF
            !
            IF (.NOT. DF_OK) THEN
              !
              IF ( ex_is_out ) CALL print_diff( 'Ex', ex1(ii:ii), ex2(ii:ii) )
              IF ( ec_is_out ) CALL print_diff( 'Ec', ec1(ii:ii), ec2(ii:ii) )
              !
              IF (.NOT. ENERGY_ONLY) THEN
                IF ( vx_is_out ) CALL print_diff( 'Vx', vx1(ii,:), vx2(ii,:) )
                IF ( vc_is_out ) CALL print_diff( 'Vc', vc1(ii,:), vc2(ii,:) )
              ENDIF
              !
            ELSE  
              !
              CALL print_diff2( 'dmuxc', dmuxc1(ii,:,:), dmuxc2(ii,:,:) )
              !
            ENDIF !df_ok
            !
          ENDIF
          !
        ENDIF
        !
     ENDDO
     !
     ! ... THRESHOLD TEST 
     !
     IF (mype==root) THEN
       IF (test(1:4)/='gen-') THEN
         WRITE(stdout,*) " "
         WRITE(stdout,*) "--- INPUT THRESHOLD CHECK ---"
         WRITE(stdout,*) " "
       ENDIF  
       !
       DO ithr = 1, nthr
         !
         IF (test(1:4)/='gen-') THEN
           WRITE(stdout,*) " "
           WRITE(stdout,910) ithr, nthr
         ENDIF
         !
         rhoi(1:ns) = rho(nnrb+ithr,1:ns)
         IF ( test(5:13)=='benchmark' ) rhoi(1:ns)=rho_b(nnrb+ithr,1:ns)
         !
         IF (test(1:4)/='gen-') THEN
           IF ( .NOT. POLARIZED ) WRITE(stdout, 401 ) rhoi(1)
           IF (       POLARIZED ) WRITE(stdout, 402 ) rhoi(1), rhoi(2)
           WRITE(stdout,*) " "
         ENDIF
         !
         IF (.NOT. DF_OK) THEN
           CALL print_diff( 'Ex', ex1(nnr+ithr:nnrb+ithr), ex2(nnrb+ithr:nnrb+ithr) )
           CALL print_diff( 'Ec', ec1(nnr+ithr:nnrb+ithr), ec2(nnrb+ithr:nnrb+ithr) )
           IF (.NOT. ENERGY_ONLY) THEN
             CALL print_diff( 'Vx', vx1(nnr+ithr,:), vx2(nnrb+ithr,:) )
             CALL print_diff( 'Vc', vc1(nnr+ithr,:), vc2(nnrb+ithr,:) )
           ENDIF
         ELSE
           CALL print_diff2( 'dmuxc', dmuxc1(nnr+ithr,:,:), dmuxc2(nnrb+ithr,:,:) )
         ENDIF !df_ok
       ENDDO
     ENDIF
     !
     !
  ELSEIF ( GGA ) THEN
     !
     ! ... calculate statistics over a large number of points (npoints)
     !
     IF ( .NOT. DF_OK ) THEN
       CALL evxc_stats( 'V1x', diff_thr_v_gga, v1x1, v1x2, v1x_aver_b )
       CALL evxc_stats( 'V2x', diff_thr_v_gga, v2x1, v2x2, v2x_aver_b )
       CALL evxc_stats( 'V1c', diff_thr_v_gga, v1c1, v1c2, v1c_aver_b )
       CALL evxc_stats( 'V2c', diff_thr_v_gga, v2c1, v2c2, v2c_aver_b )
     ELSE
       CALL derivxc_stats( 'dvxcrr', diff_thr_v_gga, dvxcrr1, dvxcrr2, dvxcrr_aver_b )
       CALL derivxc_stats( 'dvxcsr', diff_thr_v_gga, dvxcsr1, dvxcsr2, dvxcsr_aver_b )
       CALL derivxc_stats( 'dvxcss', diff_thr_v_gga, dvxcss1, dvxcss2, dvxcss_aver_b )
     ENDIF
     !
     !
     IF (test(5:13)=='benchmark')  THEN
       ex_is_out = .TRUE.  ; ec_is_out = .TRUE.
       v1x_is_out = .TRUE. ; v2x_is_out = .TRUE.
       v1c_is_out = .TRUE. ; v2c_is_out = .TRUE.
       dvxcrr_is_out = .TRUE. ; dvxcsr_is_out = .TRUE.
       dvxcss_is_out = .TRUE.
       something_out = .TRUE. ; dvgga_is_out = .TRUE.
     ENDIF
     !
     iout = 0
     !
     DO ii = 1, nnrb
        !
        IF (mype/=root) CYCLE
        !
        IF (test=='dft-comparison') THEN
          IF ( .NOT. DF_OK ) THEN
            ex_is_out = is_it_out( diff_thr_e_gga, 1, ex1(ii:ii), ex2(ii:ii) )
            ec_is_out = is_it_out( diff_thr_e_gga, 1, ec1(ii:ii), ec2(ii:ii) )
            !
            IF (.NOT. energy_only) THEN
              v1x_is_out = is_it_out( diff_thr_v_gga,ns, v1x1(ii,:), v1x2(ii,:) )
              v2x_is_out = is_it_out( diff_thr_v_gga,ns, v2x1(ii,:), v2x2(ii,:) )
              v1c_is_out = is_it_out( diff_thr_v_gga,ns, v1c1(ii,:), v1c2(ii,:) )
              v2c_is_out = is_it_out( diff_thr_v_gga,np, v2c1(ii,:), v2c2(ii,:), &
                                                         v2c_ud1(ii), v2c_ud2(ii) )
            ENDIF
            something_out = ANY( (/ex_is_out, ec_is_out, v1x_is_out, v2x_is_out, &
                                   v1c_is_out, v2c_is_out/) )
          ELSE           
            dvxcrr_is_out = is_dit_out( diff_thr_dvxc, dvxcrr1(ii,:,:), dvxcrr2(ii,:,:) )
            dvxcsr_is_out = is_dit_out( diff_thr_dvxc, dvxcsr1(ii,:,:), dvxcsr2(ii,:,:) )
            dvxcss_is_out = is_dit_out( diff_thr_dvxc, dvxcss1(ii,:,:), dvxcss2(ii,:,:) )
            !
            dvgga_is_out  = ANY((/dvxcrr_is_out, dvxcsr_is_out, dvxcss_is_out/))
          ENDIF
        ENDIF
        !
        !
        IF ( something_out .OR. dvgga_is_out ) THEN
          !
          iout = iout + 1 
          ! 
          IF (iout<=10) THEN 
            !
            IF ( test=='exe-benchmark' ) THEN 
              WRITE(stdout,*) " "
              rhoi(1:ns)=rho_b(ii,1:ns) ; grhoi(:,1:ns) = grho_b(:,ii,1:ns)
              WRITE(stdout,909) nrpe+ii, nnr_b
            ELSEIF ( test=='dft-comparison' ) THEN 
              WRITE(stdout,*) " "
              rhoi(1:ns) = rho(ii,1:ns) ; grhoi(:,1:ns) = grho(:,ii,1:ns) 
              WRITE(stdout,909) nrpe+ii, npoints
            ENDIF
            !
            IF ( test/='gen-benchmark' ) THEN 
              IF (.NOT. POLARIZED ) THEN 
                WRITE(stdout,401) rhoi(1) 
                grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2 
                WRITE(stdout,501) grho2(1) 
              ELSE 
                WRITE(stdout,402) rhoi(1), rhoi(2) 
                grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2 
                grho2(2) = grhoi(1,2)**2 + grhoi(2,2)**2 + grhoi(3,2)**2 
                grho_ud  = grhoi(1,1) * grhoi(1,2) + & 
                           grhoi(2,1) * grhoi(2,2) + & 
                           grhoi(3,1) * grhoi(3,2) 
                WRITE(stdout,503) grho2(1), grho_ud, grho2(2) 
              ENDIF 
              WRITE(stdout,*) " "
            ENDIF  
            ! 
            ! 
            IF (.NOT. DF_OK) THEN 
              ! 
              IF (ex_is_out) CALL print_diff( 'Ex', ex1(ii:ii), ex2(ii:ii) ) 
              IF (ec_is_out) CALL print_diff( 'Ec', ec1(ii:ii), ec2(ii:ii) ) 
              ! 
              IF (.NOT. ENERGY_ONLY) THEN 
                ! 
                IF (v1x_is_out) CALL print_diff( 'V1x', v1x1(ii,:), v1x2(ii,:) ) 
                IF (v2x_is_out) CALL print_diff( 'V2x', v2x1(ii,:), v2x2(ii,:) ) 
                IF (v1c_is_out) CALL print_diff( 'V1c', v1c1(ii,:), v1c2(ii,:) ) 
                IF (v2c_is_out) CALL print_diff( 'V2c', v2c1(ii,:), v2c2(ii,:),  & 
                                                          v2c_ud1(ii), v2c_ud2(ii) ) 
                ! 
              ENDIF 
              ! 
            ELSE 
              ! 
              IF (test/='gen-benchmark') WRITE(stdout,*) " " 
              ! 
              IF (dvxcrr_is_out) CALL print_diff2( 'dvxcrr', dvxcrr1(ii,:,:), dvxcrr2(ii,:,:) ) 
              IF (dvxcsr_is_out) CALL print_diff2( 'dvxcsr', dvxcsr1(ii,:,:), dvxcsr2(ii,:,:) ) 
              IF (dvxcss_is_out) CALL print_diff2( 'dvxcss', dvxcss1(ii,:,:), dvxcss2(ii,:,:) ) 
              ! 
            ENDIF 
            ! 
          ENDIF !iout 
          ! 
        ENDIF 
        ! 
     ENDDO 
     ! 
     ! 
     ! ... THRESHOLD TEST 
     ! 
     IF (mype==root) THEN
       IF (test(1:4)/='gen-' ) THEN
         WRITE(stdout,*) " " 
         WRITE(stdout,*) "--- INPUT THRESHOLD CHECK ---" 
         WRITE(stdout,*) " " 
       ENDIF  
       ! 
       DO ithr = 1, nthr 
         ! 
         rhoi(1:ns) = rho(nnrb+ithr,1:ns)   ; grhoi(:,1:ns) = grho(:,nnrb+ithr,1:ns) 
         IF ( test=='exe-benchmark' ) THEN 
           rhoi(1:ns)=rho_b(nnrb+ithr,1:ns) ; grhoi(:,1:ns) = grho_b(:,nnrb+ithr,1:ns) 
         ENDIF   
         ! 
         IF (test/='gen-benchmark') THEN
           IF (.NOT. POLARIZED ) THEN 
             WRITE(stdout,*) " "
             WRITE(stdout,401) rhoi(1) 
             grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2 
             WRITE(stdout,501) grho2(1) 
           ELSE 
             WRITE(stdout,*) " "
             WRITE(stdout,402) rhoi(1), rhoi(2) 
             grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2 
             grho2(2) = grhoi(1,2)**2 + grhoi(2,2)**2 + grhoi(3,2)**2 
             grho_ud  = grhoi(1,1) * grhoi(1,2) + & 
                        grhoi(2,1) * grhoi(2,2) + & 
                        grhoi(3,1) * grhoi(3,2) 
             WRITE(stdout,503) grho2(1), grho_ud, grho2(2) 
           ENDIF 
           WRITE(stdout,*) " " 
         ENDIF  
         ! 
         IF (.NOT. DF_OK) THEN 
           CALL print_diff( 'Ex', ex1(nnrb+ithr:nnrb+ithr), ex2(nnrb+ithr:nnrb+ithr) ) 
           CALL print_diff( 'Ec', ec1(nnrb+ithr:nnrb+ithr), ec2(nnrb+ithr:nnrb+ithr) ) 
           IF (.NOT. ENERGY_ONLY) THEN 
             CALL print_diff( 'V1x', v1x1(nnrb+ithr,:), v1x2(nnrb+ithr,:) ) 
             CALL print_diff( 'V2x', v2x1(nnrb+ithr,:), v2x2(nnrb+ithr,:) ) 
             CALL print_diff( 'V1c', v1c1(nnrb+ithr,:), v1c2(nnrb+ithr,:) ) 
             CALL print_diff( 'V2c', v2c1(nnrb+ithr,:), v2c2(nnrb+ithr,:),  & 
                                     v2c_ud1(nnrb+ithr), v2c_ud2(nnrb+ithr) ) 
           ENDIF 
         ELSE   
           CALL print_diff2( 'dvxcrr', dvxcrr1(nnrb+ithr,:,:), dvxcrr2(nnrb+ithr,:,:) ) 
           CALL print_diff2( 'dvxcsr', dvxcsr1(nnrb+ithr,:,:), dvxcsr2(nnrb+ithr,:,:) ) 
           CALL print_diff2( 'dvxcss', dvxcss1(nnrb+ithr,:,:), dvxcss2(nnrb+ithr,:,:) ) 
         ENDIF 
         ! 
       ENDDO !df_ok 
       ! 
     ENDIF 
     ! 
     ! 
  ELSEIF ( MGGA ) THEN 
     !
     !
     ! ... calculate statistics over a large number of points (npoints) 
     ! 
     CALL evxc_stats( 'V1x', diff_thr_v_mgga, v1x1, v1x2, v1x_aver_b(1,:) )
     CALL evxc_stats( 'V2x', diff_thr_v_mgga, v2x1, v2x2, v2x_aver_b(1,:) ) 
     CALL evxc_stats( 'V1c', diff_thr_v_mgga, v1c1, v1c2, v1c_aver_b(1,:) )
     CALL evxc_stats( 'V2c', diff_thr_v_mgga, v2c1, v2c2, v2c_aver_b(1,:) ) 
     CALL evxc_stats( 'V3x', diff_thr_v_mgga, v3x1, v3x2, v3x_aver_b(1,:) ) 
     CALL evxc_stats( 'V3c', diff_thr_v_mgga, v3c1, v3c2, v3c_aver_b(1,:) ) 
     ! 
     ! ... calculate values over a few benchmark points (nnr_b) 
     ! 
     IF (mype == root) THEN 
       !
       IF (test(5:13)=='benchmark') THEN
         ex_is_out = .TRUE.  ; ec_is_out = .TRUE.
         v1x_is_out = .TRUE. ; v2x_is_out = .TRUE. 
         v3x_is_out = .TRUE. ; v1c_is_out = .TRUE. 
         v2c_is_out = .TRUE. ; v3c_is_out = .TRUE. 
         something_out = .TRUE. 
       ENDIF 
       ! 
       iout = 0 
       !
       DO ii = 1, nnrb 
         !
         IF (test=='dft-comparison') THEN 
           !
           ex_is_out = is_it_out( diff_thr_e_mgga, 1, ex1(ii:ii), ex2(ii:ii) ) 
           ec_is_out = is_it_out( diff_thr_e_mgga, 1, ec1(ii:ii), ec2(ii:ii) ) 
           !
           IF (.NOT. energy_only) THEN 
             v1x_is_out = is_it_out( diff_thr_v_mgga,ns, v1x1(ii,:), v1x2(ii,:) ) 
             v2x_is_out = is_it_out( diff_thr_v_mgga,ns, v2x1(ii,:), v2x2(ii,:) ) 
             v3x_is_out = is_it_out( diff_thr_v_mgga,ns, v3x1(ii,:), v3x2(ii,:) ) 
             v1c_is_out = is_it_out( diff_thr_v_mgga,ns, v1c1(ii,:), v1c2(ii,:) ) 
             v2c_is_out = is_it_out( diff_thr_v_mgga,ns, v2c1(ii,:), v2c2(ii,:) ) 
             v3c_is_out = is_it_out( diff_thr_v_mgga,ns, v3c1(ii,:), v3c2(ii,:) ) 
           ENDIF 
           ! 
           something_out = ANY( (/ex_is_out, ec_is_out, v1x_is_out, v2x_is_out, & 
                                  v3x_is_out, v1c_is_out, v2c_is_out, & 
                                  v3c_is_out/) ) 
         ENDIF 
         ! 
         IF ( something_out ) THEN 
            ! 
            iout = iout + 1 
            ! 
            IF (iout<=10) THEN 
              IF (test(1:4)/='gen-') THEN
                WRITE(stdout,*) " " 
                IF ( test=='exe-benchmark' ) THEN
                  WRITE(stdout,909) ii, nnr_b
                  rhoi(1:ns) = rho_b(ii,1:ns) ; grhoi(:,1:ns) = grho_b(:,ii,1:ns) 
                  taui(1:ns) = tau_b(ii,1:ns) 
                ELSE 
                  WRITE(stdout,909) ii, npoints
                  rhoi(1:ns) = rho(ii,1:ns) ; grhoi(:,1:ns) = grho(:,ii,1:ns) 
                  taui(1:ns) = tau(ii,1:ns)
                ENDIF
              ENDIF  
              ! 
              IF (test/='gen-benchmark') THEN
                IF (.NOT. POLARIZED ) THEN 
                  WRITE(stdout,401) rhoi(1) 
                  grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2 
                  WRITE(stdout,501) grho2(1) 
                  WRITE(stdout,601) taui(1) 
                ELSE 
                  WRITE(stdout,402) rhoi(1), rhoi(2) 
                  grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2 
                  grho2(2) = grhoi(1,2)**2 + grhoi(2,2)**2 + grhoi(3,2)**2 
                  grho_ud  = grhoi(1,1) * grhoi(1,2) + & 
                             grhoi(2,1) * grhoi(2,2) + & 
                             grhoi(3,1) * grhoi(3,2) 
                  WRITE(stdout,503) grho2(1), grho_ud, grho2(2) 
                  WRITE(stdout,602) taui(1), taui(2) 
                ENDIF 
              ENDIF
              ! 
              IF ( ex_is_out ) CALL print_diff( 'Ex', ex1(ii:ii), ex2(ii:ii) )
              IF ( ec_is_out ) CALL print_diff( 'Ec', ec1(ii:ii), ec2(ii:ii) )
              ! 
              IF (.NOT. ENERGY_ONLY) THEN
                IF ( v1x_is_out ) CALL print_diff( 'V1x', v1x1(ii,:), v1x2(ii,:) )
                IF ( v2x_is_out ) CALL print_diff( 'V2x', v2x1(ii,:), v2x2(ii,:) )
                IF ( v1c_is_out ) CALL print_diff( 'V1c', v1c1(ii,:), v1c2(ii,:) )
                IF ( v2c_is_out ) CALL print_diff( 'V2c', v2c1(ii,:), v2c2(ii,:) ) 
                IF ( v3x_is_out ) CALL print_diff( 'V3x', v3x1(ii,:), v3x2(ii,:) ) 
                IF ( v3c_is_out ) CALL print_diff( 'V3c', v3c1(ii,:), v3c2(ii,:) ) 
              ENDIF !not energy only 
              ! 
           ENDIF  
         ENDIF 
         ! 
       ENDDO 
     ENDIF   
     ! 
     ! 
     ! ... THRESHOLD TEST 
     ! 
     IF ( mype==root ) THEN 
       !
       IF (test/='gen-benchmark') THEN
         WRITE(stdout,*) " "  
         WRITE(stdout,*) "--- INPUT THRESHOLD CHECK ---"  
         WRITE(stdout,*) " "  
       ENDIF  
       !  
       DO ithr = 1, nthr  
         ! 
         rhoi(1:ns) = rho(nnrb+ithr,1:ns)   ; grhoi(:,1:ns) = grho(:,nnr+ithr,1:ns) 
         taui(1:ns) = tau(nnrb+ithr,1:ns) 
         IF ( test=='exe-benchmark' ) THEN 
           rhoi(1:ns) = rho_b(nnrb+ithr,1:ns) ; grhoi(:,1:ns) = grho_b(:,nnrb+ithr,1:ns) 
           taui(1:ns) = tau_b(nnrb+ithr,1:ns) 
         ENDIF 
         !
         IF (test/='gen-benchmark') THEN
           WRITE(stdout,*) " " 
           WRITE(stdout,910) ithr, nthr 
           IF (.NOT. POLARIZED ) THEN    
             WRITE(stdout,401) rhoi(1) 
             grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2    
             WRITE(stdout,501) grho2(1)  
             WRITE(stdout,601) taui(1) 
           ELSE    
             WRITE(stdout,402) rhoi(1), rhoi(2)    
             grho2(1) = grhoi(1,1)**2 + grhoi(2,1)**2 + grhoi(3,1)**2    
             grho2(2) = grhoi(1,2)**2 + grhoi(2,2)**2 + grhoi(3,2)**2    
             grho_ud  = grhoi(1,1) * grhoi(1,2) + &
                        grhoi(2,1) * grhoi(2,2) + &
                        grhoi(3,1) * grhoi(3,2)    
             WRITE(stdout,503) grho2(1), grho_ud, grho2(2) 
             WRITE(stdout,602) taui(1), taui(2) 
           ENDIF
           WRITE(stdout,*) " " 
         ENDIF
         !    
         CALL print_diff( 'Ex', ex1(nnrb+ithr:nnrb+ithr), ex2(nnrb+ithr:nnrb+ithr) )    
         CALL print_diff( 'Ec', ec1(nnrb+ithr:nnrb+ithr), ec2(nnrb+ithr:nnrb+ithr) )
         IF (.NOT. ENERGY_ONLY) THEN
           CALL print_diff( 'V1x', v1x1(nnrb+ithr,:), v1x2(nnrb+ithr,:) )
           CALL print_diff( 'V2x', v2x1(nnrb+ithr,:), v2x2(nnrb+ithr,:) )
           CALL print_diff( 'V1c', v1c1(nnrb+ithr,:), v1c2(nnrb+ithr,:) )
           CALL print_diff( 'V2c', v2c1(nnrb+ithr,:), v2c2(nnrb+ithr,:) )
           CALL print_diff( 'V3x', v3x1(nnrb+ithr,:), v3x2(nnrb+ithr,:) )
           CALL print_diff( 'V3c', v3c1(nnrb+ithr,:), v3c2(nnrb+ithr,:) )
         ENDIF
         !  
       ENDDO
       ! 
     ENDIF  !mype
     ! 
  ENDIF
  
  
  IF (test=='gen-benchmark' .AND. mype==root) THEN
    IF (.NOT. DF_OK) THEN
      IF ( family=='LDA' ) WRITE(stdout,lda_benchmark_data)
      IF ( family=='GGA' ) WRITE(stdout,gga_benchmark_data)
      IF ( family=='MGGA') WRITE(stdout,mgga_benchmark_data)
    ELSE
      IF ( family=='LDA' ) WRITE(stdout,dlda_benchmark_data)
      IF ( family=='GGA' ) WRITE(stdout,dgga_benchmark_data)
    ENDIF
  ENDIF  
  ! 
  !
  401 FORMAT('rho: ',F17.14)
  402 FORMAT('rho(up,down): ',F17.14,4x,F17.14)
  !
  501 FORMAT('grho2: ',F17.14)
  502 FORMAT('grho2(uu,dd): ',F17.14,4x,F17.14)
  503 FORMAT('grho2(uu,ud,dd): ',F17.14,4x,F17.14,4x,F17.14)
  !
  601 FORMAT('tau: ',F17.14)
  602 FORMAT('tau(up,down): ',F17.14,4x,F17.14)
  !
  909 FORMAT('grid-point: ',I5,' of ',I5)
  910 FORMAT('threshold-point: ',I4,' of ',I4)
  911 FORMAT(' TOTAL VALUES OVER ',I5,' POINTS')
  !
  !
  !
  ! ------ DEALLOCATIONS --------
  !
  DEALLOCATE( rho, rho_tz )
  !
  IF ( GGA .OR. MGGA ) DEALLOCATE( grho )
  IF ( MGGA ) DEALLOCATE( tau )
  !
  IF ( test(5:13)=='benchmark' ) THEN
    DEALLOCATE( rho_b, rhotz_b )
    IF ( GGA .OR. MGGA ) DEALLOCATE( grho_b )
    IF ( MGGA ) DEALLOCATE( tau_b )
  ENDIF
  !
  ! ... dft1 output arrays
  !
  IF (.NOT. DF_OK) DEALLOCATE( ex1, ec1 )
  !
  IF ( LDA .OR. GGA ) THEN
     IF ( LDA ) THEN
       IF ( .NOT. DF_OK ) THEN
         DEALLOCATE( vx1, vc1 )
       ELSE
         DEALLOCATE( dmuxc1 )
       ENDIF 
     ENDIF
     !
     IF ( GGA ) THEN
       IF ( .NOT. DF_OK ) THEN
         DEALLOCATE( exg1, ecg1 )
         DEALLOCATE( v1x1, v2x1 )
         DEALLOCATE( v1c1 )
         DEALLOCATE( v2c1, v2c_ud1 )
       ELSE
         DEALLOCATE( grh )
         IF ( test(5:13)=='benchmark' ) DEALLOCATE( grh_b )
         DEALLOCATE( dvxcrr1, dvxcsr1, dvxcss1 )
       ENDIF
     ENDIF
  ELSEIF ( MGGA ) THEN
     DEALLOCATE( v1x1, v2x1 )
     DEALLOCATE( v1c1 )
     DEALLOCATE( v2c1 )
     DEALLOCATE( v3x1, v3c1 )
  ENDIF
  !
  ! ... dft2 output / benchmark data arrays
  !
  IF (.NOT. DF_OK) DEALLOCATE( ex2, ec2 )
  !
  IF ( LDA .OR. GGA ) THEN
     IF ( LDA ) THEN
       IF ( .NOT. DF_OK ) THEN
         DEALLOCATE( ex2, ec2 )
         DEALLOCATE( vx2, vc2 )
       ELSE
         DEALLOCATE( dmuxc2 )
       ENDIF 
     ENDIF
     !
     IF ( GGA ) THEN
       IF ( .NOT. DF_OK ) THEN
         DEALLOCATE( exg2, ecg2 )
         DEALLOCATE( v1x2, v2x2 )
         DEALLOCATE( v1c2 )
         DEALLOCATE( v2c2, v2c_ud2 )
       ELSE
         DEALLOCATE( dvxcrr2, dvxcsr2, dvxcss2 )
       ENDIF
     ENDIF
  ELSEIF ( MGGA ) THEN
     DEALLOCATE( v1x2, v2x2 )
     DEALLOCATE( v1c2 )
     DEALLOCATE( v2c2 )
     DEALLOCATE( v3x2, v3c2 )
  ENDIF
  !
  !
  DEALLOCATE( proc_name )
  DEALLOCATE( node_name )
  DEALLOCATE( proc2node )
  !
#if defined(__MPI)
  CALL mpi_finalize( ierr )
#endif
  !
  !
  WRITE(stdout,*) " "
  !
10 STOP
  !
  !
 CONTAINS
!
!
!------------------------------------------------------------------------
SUBROUTINE diff_average( thr, x_qe, x_lxc, aver_abs_perc, nnr_int )
  !----------------------------------------------------------------------
  !! Calculates average difference (both absolute and percentage) between
  !! qe and libxc quantities.
  !
  IMPLICIT NONE
  !
  REAL(DP), INTENT(IN)  :: thr
  REAL(DP), INTENT(IN)  :: x_qe(nnr), x_lxc(nnr)
  REAL(DP), INTENT(OUT) :: aver_abs_perc(2)
  !! 1: absolute difference;  2: percentage difference
  INTEGER, INTENT(OUT) :: nnr_int
  !
  INTEGER  :: i
  REAL(DP) :: calc_perc_diff
  REAL(DP) :: abs_diff, perc_diff
  !
  nnr_int = 0
  aver_abs_perc = 0.d0
  !
  DO i = 1, nnr
    !
    abs_diff  = ABS(x_qe(i) - x_lxc(i))
    perc_diff = calc_perc_diff( thr, x_qe(i), x_lxc(i) )
    !
    aver_abs_perc(1) = aver_abs_perc(1) + abs_diff
    !
    IF ( perc_diff < 0.d0 ) CYCLE
    !
    nnr_int = nnr_int+1
    aver_abs_perc(2) = aver_abs_perc(2) + perc_diff
    !
  ENDDO
  !
  aver_abs_perc(1) = aver_abs_perc(1) / DBLE(npoints)
  aver_abs_perc(2) = aver_abs_perc(2) / DBLE(npoints)  !(nnr_int)
  !
  RETURN
  !
END SUBROUTINE diff_average
!
!



!-------------------------------------------------------------------------
SUBROUTINE diff_max( thr, x_qe, x_lxc, max_abs_perc )
  !-----------------------------------------------------------------------
  !! Finds the max difference (both absolute and percentage) between qe
  !! and libxc quantities.
  !
  IMPLICIT NONE
  !
  REAL(DP), INTENT(IN)  :: thr
  REAL(DP), INTENT(IN)  :: x_qe(nnr), x_lxc(nnr)
  REAL(DP), INTENT(OUT) :: max_abs_perc(2)
  !
  INTEGER :: i
  REAL(DP) :: calc_perc_diff
  REAL(DP) :: abs_diff, perc_diff
  REAL(DP) :: abs_diff_prev, perc_diff_prev
  !
  abs_diff_prev  = 0.0_DP
  perc_diff_prev = 0.0_DP
  !
  DO i = 1, nnr
    !
    abs_diff  = ABS(x_qe(i) - x_lxc(i))
    perc_diff = calc_perc_diff( thr, x_qe(i), x_lxc(i) )
    !
    IF ( abs_diff > abs_diff_prev ) THEN
      max_abs_perc(1) = abs_diff
      abs_diff_prev = abs_diff
    ENDIF
    !
    IF ( perc_diff > perc_diff_prev ) THEN
      max_abs_perc(2) = perc_diff
      perc_diff_prev = perc_diff
    ENDIF
    !
  ENDDO
  !
  RETURN
  !
END SUBROUTINE diff_max
!
!
!--------------------------------------------------------------------------
SUBROUTINE diff_min( thr, x_qe, x_lxc, min_abs_perc )
  !------------------------------------------------------------------------
  !! Finds the max difference (both absoulte and percentage) between qe
  !! and libxc quantities.
  !
  IMPLICIT NONE
  !
  REAL(DP), INTENT(IN)  :: thr
  REAL(DP), INTENT(IN)  :: x_qe(nnr), x_lxc(nnr)
  REAL(DP), INTENT(OUT) :: min_abs_perc(2)
  !
  INTEGER  :: i
  REAL(DP) :: calc_perc_diff
  REAL(DP) :: abs_diff, perc_diff
  REAL(DP) :: perc_diff_prev, abs_diff_prev
  !
  abs_diff_prev  = 1000.d0
  perc_diff_prev = 1000.d0
  !
  DO i = 1, nnr
    !
    abs_diff  = ABS(x_qe(i) - x_lxc(i))
    perc_diff = calc_perc_diff( thr, x_qe(i), x_lxc(i) )
    !
    IF ( abs_diff < abs_diff_prev .and. abs_diff>0.d0 ) THEN
      min_abs_perc(1) = abs_diff
      abs_diff_prev = abs_diff
    ENDIF
    !
    IF ( perc_diff < 0.d0 ) CYCLE
    !
    IF ( perc_diff < perc_diff_prev ) THEN
      min_abs_perc(2) = perc_diff
      perc_diff_prev = perc_diff
    ENDIF
    !
  ENDDO
  !
  RETURN
  !
END SUBROUTINE diff_min
!
!--------------------------------------------------------------------
SUBROUTINE print_stat( what, vaver, vmax, vmin, averref )
  !------------------------------------------------------------------
  !
  IMPLICIT NONE
  !
  CHARACTER(len=*), INTENT(IN) :: what
  REAL(DP), INTENT(IN) :: vaver(2), vmax(2), vmin(2)
  REAL(DP), OPTIONAL :: averref
  !
  IF (test=='dft-comparison') THEN
    WRITE(stdout,*) " "
    WRITE(stdout,*) " ", TRIM(what)
    WRITE(stdout,*) "AVR abs: ", vaver(1), "   AVR %: ", vaver(2)
    WRITE(stdout,*) "MAX abs: ", vmax(1),  "   MAX %: ", vmax(2)
    WRITE(stdout,*) "MIN abs: ", vmin(1),  "   MIN %: ", vmin(2)
  ELSEIF (test=='exe-benchmark') THEN
    WRITE(stdout,*) " "
    WRITE(stdout,*) " ", TRIM(what)
    WRITE(stdout,*) "AVR test: ", vaver(1)
    WRITE(stdout,*) "AVR ref : ", averref
    WRITE(stdout,*) "diff    : ", vaver(1)-averref
  ELSEIF  (test=='gen-benchmark') THEN
    !^WRITE(stdout,*) vaver(1)
  ENDIF
  !
END SUBROUTINE print_stat
!
!------------------------------------------------------------------
SUBROUTINE print_diff( what, x_qe, x_lxc, x_ud_qe, x_ud_lxc )
  !-----------------------------------------------------------------
  !
  IMPLICIT NONE
  !
  CHARACTER(len=*), INTENT(IN) :: what
  REAL(DP), INTENT(IN) :: x_qe(ns), x_lxc(ns)
  REAL(DP), INTENT(IN), OPTIONAL :: x_ud_qe, x_ud_lxc
  !
  IF (test/='gen-benchmark') THEN
    WRITE(stdout,*) " "
    WRITE(stdout,*) what
  ENDIF
  !
  IF ( .NOT. POLARIZED .OR. what(1:1)=='E' ) THEN
    IF (test/='gen-benchmark') THEN
      IF (test=='dft-comparison') THEN
        WRITE(stdout,101) x_qe(1)
        WRITE(stdout,201) x_lxc(1)
      ELSEIF (test=='exe-benchmark') THEN
        WRITE(stdout,111) x_qe(1)
        WRITE(stdout,211) x_lxc(1)
      ENDIF
      WRITE(stdout,*) " --- "
      WRITE(stdout,301) ABS(x_qe(1)-x_lxc(1))
    ELSE
      !^WRITE(stdout,*) x_qe(1)
    ENDIF
  ELSEIF ( POLARIZED ) THEN
    IF ( .NOT. PRESENT(x_ud_qe) ) THEN
      IF (test/='gen-benchmark') THEN
        IF ( test=='dft-comparison' ) THEN
          WRITE(stdout,102) x_qe(1), x_qe(2)
          WRITE(stdout,202) x_lxc(1), x_lxc(2)
        ELSEIF (test=='exe-benchmark') THEN
          WRITE(stdout,112) x_qe(1), x_qe(2)
          WRITE(stdout,212) x_lxc(1), x_lxc(2)
        ENDIF
        WRITE(stdout,*) " --- "
        WRITE(stdout,302) ABS(x_qe(1)-x_lxc(1)), ABS(x_qe(2)-x_lxc(2))
      ELSE
        !^ WRITE(stdout,*) x_qe(1), x_qe(2)
      ENDIF
    ELSE
      IF ( test/='gen-benchmark' ) THEN
        IF ( test=='dft-comparison' ) THEN
          WRITE(stdout,103) x_qe(1), x_ud_qe, x_qe(2)
          WRITE(stdout,203) x_lxc(1), x_ud_lxc, x_lxc(2)
        ELSEIF ( test=='exe-benchmark' ) THEN
          WRITE(stdout,113) x_qe(1), x_ud_qe, x_qe(2)
          WRITE(stdout,213) x_lxc(1), x_ud_lxc, x_lxc(2)
        ENDIF
        WRITE(stdout,*) " --- "
        WRITE(stdout,303) ABS(x_qe(1)-x_lxc(1)), ABS(x_ud_qe-x_ud_lxc), &
                          ABS(x_qe(2)-x_lxc(2))
      ELSE
        !^IF (.NOT.present(x_ud_qe)) THEN
        !^  WRITE(stdout,*) x_qe(1), x_qe(2)
        !^ELSE  
        !^  WRITE(stdout,*) x_qe(1), x_ud_qe, x_qe(2)
        !^ENDIF  
      ENDIF
    ENDIF
  ENDIF
  !
  101 FORMAT('dft1: ',F17.14)
  102 FORMAT('dft1: ',F17.14,4x,F17.14)
  103 FORMAT('dft1: ',F17.14,4x,F17.14,4x,F17.14)
  201 FORMAT('dft2: ',F17.14)
  202 FORMAT('dft2: ',F17.14,4x,F17.14)
  203 FORMAT('dft2: ',F17.14,4x,F17.14,4x,F17.14)
  111 FORMAT('test: ',F17.14)
  112 FORMAT('test: ',F17.14,4x,F17.14)
  113 FORMAT('test: ',F17.14,4x,F17.14,4x,F17.14)
  211 FORMAT('ref: ',1x,F17.14)
  212 FORMAT('ref: ',1x,F17.14,4x,F17.14)
  213 FORMAT('ref: ',1x,F17.14,4x,F17.14,4x,F17.14)
  301 FORMAT('diff: ',F17.14)
  302 FORMAT('diff: ',F17.14,4x,F17.14)
  303 FORMAT('diff: ',F17.14,4x,F17.14,4x,F17.14)
  !
END SUBROUTINE print_diff
!
!-----------------------------------------------------------------------
SUBROUTINE print_diff2( what, dxc_qe, dxc_lxc )
  !---------------------------------------------------------------------
  !
  IMPLICIT NONE
  !
  CHARACTER(len=*), INTENT(IN) :: what
  REAL(DP), INTENT(IN) :: dxc_qe(ns,ns), dxc_lxc(ns,ns)
  !
  IF (test/='gen-benchmark') THEN
    WRITE(stdout,*) " "
    WRITE(stdout,*) what
  ENDIF
  !
  IF ( .NOT. POLARIZED ) THEN
    IF (test/='gen-benchmark') THEN
      IF (test=='dft-comparison') THEN
        WRITE(stdout,101) dxc_qe(1,1)
        WRITE(stdout,201) dxc_lxc(1,1)
      ELSE
        WRITE(stdout,111) dxc_qe(1,1)
        WRITE(stdout,211) dxc_lxc(1,1)
      ENDIF
      WRITE(stdout,*) " --- "
      WRITE(stdout,301) dxc_qe(1,1)-dxc_lxc(1,1)
    ELSE
      !WRITE(stdout,*) dxc_qe(1,1)
    ENDIF
  ELSE
    IF (test/='gen-benchmark') THEN
      IF (test=='dft-comparison') THEN
        WRITE(stdout,103) dxc_qe(1,1), dxc_qe(2,1), dxc_qe(2,2) !, dxc_qe(1,2)
        WRITE(stdout,203) dxc_lxc(1,1), dxc_lxc(2,1), dxc_lxc(2,2)
      ELSE
        WRITE(stdout,113) dxc_qe(1,1), dxc_qe(2,1), dxc_qe(2,2) !, dxc_qe(1,2)
        WRITE(stdout,213) dxc_lxc(1,1), dxc_lxc(2,1), dxc_lxc(2,2) 
      ENDIF
      WRITE(stdout,*) " --- "
      WRITE(stdout,303) dxc_qe(1,1)-dxc_lxc(1,1), dxc_qe(2,1)-dxc_lxc(2,1), &
                        dxc_qe(2,2)-dxc_lxc(2,2)
    ELSE
      !WRITE(stdout,*) dxc_qe(1,1), dxc_qe(2,1), dxc_qe(2,1), dxc_qe(2,2)
    ENDIF
  ENDIF
  !
  101 FORMAT('dft1: ',F17.14)
  103 FORMAT('dft1: ',F17.14,4x,F17.14,4x,F17.14)
  201 FORMAT('dft2: ',F17.14)
  203 FORMAT('dft2: ',F17.14,4x,F17.14,4x,F17.14)
  111 FORMAT('test: ',F17.14)
  113 FORMAT('test: ',F17.14,4x,F17.14,4x,F17.14)
  211 FORMAT('ref: ',1x,F17.14)
  213 FORMAT('ref: ',1x,F17.14,4x,F17.14,4x,F17.14)
  301 FORMAT('diff: ',F17.14)
  303 FORMAT('diff: ',F17.14,4x,F17.14,4x,F17.14)
  !
END SUBROUTINE print_diff2
!
!
SUBROUTINE evxc_stats( what, thr, xc_qe, xc_lxc, aver )
  !
  IMPLICIT NONE
  !
  CHARACTER(len=*) :: what
  REAL(DP), INTENT(IN) :: thr, xc_qe(nnr+nthr,ns)
  REAL(DP), INTENT(IN) :: xc_lxc(nnr+nthr,ns)
  REAL(DP), INTENT(INOUT) :: aver(2)
  !
  REAL(DP) :: xc_aver(2,2), xc_max(2,2), xc_min(2,2)
  !
  real(dp) :: aver_snd(1), aver_rec(1)
  integer :: ierr2
  !
  IF (test/='gen-benchmark') THEN
    WRITE(stdout,*) " "
    IF ( POLARIZED .AND. what(1:1)/='E' ) WRITE(stdout,*) what
  ENDIF
  !
  xc_aver=0.d0
  xc_max=0.d0
  xc_min=0.d0
  !
  IF ( test=='dft-comparison' ) THEN
    CALL diff_average( thr, xc_qe(1:nnr,1), xc_lxc(1:nnr,1), xc_aver(:,1), nnr_int )
    CALL diff_max( thr, xc_qe(1:nnr,1), xc_lxc(1:nnr,1), xc_max(:,1) )
    CALL diff_min( thr, xc_qe(1:nnr,1), xc_lxc(1:nnr,1), xc_min(:,1) )
    !write(stdout,*) 'ddd', xc_qe(1,1), xc_lxc(1,1)
  ELSE
    xc_aver(1,1) = SUM(xc_qe(1:nnr,1))/npoints
    xc_max(1,1) = MAXVAL( xc_qe(1:nnr,1) )
    xc_min(1,1) = MINVAL( xc_qe(1:nnr,1) )
    !
    aver_snd = xc_aver(1,1)
    CALL MPI_REDUCE( aver_snd, aver_rec, 1, MPI_DOUBLE_PRECISION, MPI_SUM, 0, comm, ierr2 )
    xc_aver(1:1,1) = aver_rec
  ENDIF
  !
  IF ( .NOT. POLARIZED .OR. what(1:1)=='E' ) THEN
     IF (mype==root) THEN
       IF (test=='dft-comparison')  CALL print_stat( what, xc_aver(:,1), xc_max(:,1), xc_min(:,1) )
       IF (test(5:13)=='benchmark') CALL print_stat( what, xc_aver(:,1), xc_max(:,1), xc_min(:,1), aver(1) )
     ENDIF
  ELSE
    IF ( test=='dft-comparison' ) THEN
      CALL diff_average( thr, xc_qe(1:nnr,2), xc_lxc(1:nnr,2), xc_aver(:,2), nnr_int )
      CALL diff_max( thr, xc_qe(1:nnr,2), xc_lxc(1:nnr,2), xc_max(:,2) )
      CALL diff_min( thr, xc_qe(1:nnr,2), xc_lxc(1:nnr,2), xc_min(:,2) )
      !
      IF (TRIM(what)=='V2c' .AND. GGA ) THEN
        CALL diff_average( diff_thr_v_gga, v2c_ud1, v2c_ud2, vaver, nnr_int )
        CALL diff_max( diff_thr_v_gga, v2c_ud1, v2c_ud2, vmax )
        CALL diff_min( diff_thr_v_gga, v2c_ud1, v2c_ud2, vmin )
        !
        IF (mype==root) CALL print_stat( 'cross', vaver, vmax, vmin )
      ENDIF
      !      
    ELSE
      xc_aver(1,2) = SUM(xc_qe(1:nnr,2))/npoints
      xc_max(1,2) = MAXVAL( xc_qe(1:nnr,2) )
      xc_min(1,2) = MINVAL( xc_qe(1:nnr,2) )
      !
      aver_snd = xc_aver(1,2)
      CALL MPI_REDUCE( aver_snd, aver_rec, 1, MPI_DOUBLE_PRECISION, MPI_SUM, 0, comm, ierr2 )
      xc_aver(1:1,2) = aver_rec
      !
      IF (TRIM(what)=='V2c' .AND. GGA ) THEN
        v2c_ud1_aver(1) = SUM(v2c_ud1(1:nnr))/npoints
        v2c_ud1_max(1) = MAXVAL( v2c_ud1(1:nnr) )
        v2c_ud1_min(1) = MINVAL( v2c_ud1(1:nnr) )
        ! 
        aver_sndu = v2c_ud1_aver(1)
        CALL MPI_REDUCE( aver_sndu, aver_recu, 1, MPI_DOUBLE_PRECISION, MPI_SUM, 0, comm, ierrm )
        v2c_ud1_aver(1) = aver_recu
        !
        IF (mype==root) CALL print_stat( 'cross', v2c_ud1_aver , v2c_ud1_max, v2c_ud1_min, v2c_aver_b(1,3) )
      ENDIF
      !
    ENDIF
    !
    IF (mype==root) THEN
      CALL print_stat( 'up',   xc_aver(:,1), xc_max(:,1), xc_min(:,1), aver(1) )
      CALL print_stat( 'down', xc_aver(:,2), xc_max(:,2), xc_min(:,2), aver(2) )
    ENDIF 
    !
  ENDIF
  !
  IF (test=='gen-benchmark') THEN
     aver = xc_aver(1,:)
     IF (TRIM(what)=='V2c' .AND. GGA .AND. ns==2) v2c_aver_b(1,3)=v2c_ud1_aver(1)
  ENDIF   
  !
  RETURN
  !
END SUBROUTINE evxc_stats

!
!
!---------------------------------------------------------------------
SUBROUTINE derivxc_stats( what, thr, dxc_qe, dxc_lxc, aver )
  !-------------------------------------------------------------------
  !
  IMPLICIT NONE
  !
  CHARACTER(len=*), INTENT(IN) :: what
  REAL(DP), INTENT(IN) :: thr
  REAL(DP), INTENT(IN) :: dxc_qe(nnr+nthr,ns,ns)
  REAL(DP), INTENT(IN) :: dxc_lxc(nnr+nthr,ns,ns)
  REAL(DP), INTENT(INOUT) :: aver(3)
  !
  REAL(DP) :: dxc_aver(2,np), dxc_max(2,np), dxc_min(2,np)
  !
  REAL(DP) :: aver_snd(1), aver_rec(1)
  INTEGER :: ierr2
  !
  IF (test/='gen-benchmark') THEN
    WRITE(stdout,*) " "
    WRITE(stdout,*) what
  ENDIF
  !
  dxc_aver = 0.d0
  dxc_min=0.d0
  dxc_max=0.d0
  !
  IF ( test=='dft-comparison' ) THEN
    CALL diff_average( thr, dxc_qe(1:nnr,1,1), dxc_lxc(1:nnr,1,1), dxc_aver(1:nnr,1), nnr_int )
    CALL diff_max( thr, dxc_qe(1:nnr,1,1), dxc_lxc(1:nnr,1,1), dxc_max(1:nnr,1) )
    CALL diff_min( thr, dxc_qe(1:nnr,1,1), dxc_lxc(1:nnr,1,1), dxc_min(1:nnr,1) )
  ELSE
    dxc_aver(1,1) = SUM(dxc_qe(1:nnr,1,1))/npoints
    dxc_max(1,1) = MAXVAL( dxc_qe(1:nnr,1,1) )
    dxc_min(1,1) = MINVAL( dxc_qe(1:nnr,1,1) )
    !
    aver_snd = dxc_aver(1,1)
    CALL MPI_REDUCE( aver_snd, aver_rec, 1, MPI_DOUBLE_PRECISION, MPI_SUM, 0, comm, ierr2 )
    dxc_aver(1:1,1) = aver_rec
  ENDIF
  !
  IF ( .NOT. POLARIZED ) THEN
    IF (mype==root) THEN
      IF (test=='dft-comparison') CALL print_stat( what, dxc_aver(1:nnr,1), dxc_max(1:nnr,1), dxc_min(1:nnr,1) )
      IF (test(5:13)=='benchmark') CALL print_stat( what, dxc_aver(1:nnrb,1), dxc_max(1:nnrb,1), dxc_min(1:nnrb,1), aver(1) )
    ENDIF  
  ELSE
  
    IF ( test=='dft-comparison' ) THEN
      CALL diff_average( thr, dxc_qe(1:nnr,1,2), dxc_lxc(1:nnr,1,2), dxc_aver(1:nnr,2), nnr_int )
      CALL diff_max( thr, dxc_qe(1:nnr,1,2), dxc_lxc(1:nnr,1,2), dxc_max(1:nnr,2) )
      CALL diff_min( thr, dxc_qe(1:nnr,1,2), dxc_lxc(1:nnr,1,2), dxc_min(1:nnr,2) )
      !
      CALL diff_average( thr, dxc_qe(1:nnr,2,2), dxc_lxc(1:nnr,2,2), dxc_aver(1:nnr,3), nnr_int )
      CALL diff_max( thr, dxc_qe(1:nnr,2,2), dxc_lxc(1:nnr,2,2), dxc_max(1:nnr,3) )
      CALL diff_min( thr, dxc_qe(1:nnr,2,2), dxc_lxc(1:nnr,2,2), dxc_min(1:nnr,3) )
      !
    ELSE
      dxc_aver(1,2) = SUM(dxc_qe(1:nnr,1,2))/npoints
      dxc_max(1,2) = MAXVAL( dxc_qe(1:nnr,1,2) )
      dxc_min(1,2) = MINVAL( dxc_qe(1:nnr,1,2) )
      !
      aver_snd = dxc_aver(1,2)
      CALL MPI_REDUCE( aver_snd, aver_rec, 1, MPI_DOUBLE_PRECISION, MPI_SUM, 0, comm, ierr2 )
      dxc_aver(1:1,2) = aver_rec
      
      dxc_aver(1,3) = SUM(dxc_qe(1:nnr,2,2))/npoints
      dxc_max(1,3) = MAXVAL( dxc_qe(1:nnr,2,2) )
      dxc_min(1,3) = MINVAL( dxc_qe(1:nnr,2,2) )
      !
      aver_snd = dxc_aver(1,3)
      CALL MPI_REDUCE( aver_snd, aver_rec, 1, MPI_DOUBLE_PRECISION, MPI_SUM, 0, comm, ierr2 )
      dxc_aver(1:1,3) = aver_rec
    ENDIF
    !
    IF (mype==root) THEN
      CALL print_stat( 'up-up', dxc_aver(:,1), dxc_max(:,1), dxc_min(:,1),aver(1) )
      CALL print_stat( 'up-down', dxc_aver(:,2), dxc_max(:,2), dxc_min(:,2), aver(2) )
      CALL print_stat( 'down-down', dxc_aver(:,3), dxc_max(:,3), dxc_min(:,3) ,aver(3) )
    ENDIF  
    !
  ENDIF
  
  IF (test=='gen-benchmark') aver(1:np) = dxc_aver(1,:)
  
  !
  RETURN
  !
END SUBROUTINE derivxc_stats
!
!------------------------------------------------------------------------
FUNCTION is_it_out( diff_thr, dm, x_qe, x_lxc, x_ud_qe, x_ud_lxc )
  !----------------------------------------------------------------------
  !
  IMPLICIT NONE
  !
  INTEGER, INTENT(IN) :: dm
  REAL(DP), INTENT(IN) :: diff_thr, x_qe(dm), x_lxc(dm)
  REAL(DP), INTENT(IN), OPTIONAL :: x_ud_qe, x_ud_lxc
  LOGICAL :: is_it_out, is_it_out_ud
  !
  is_it_out = ANY(ABS(x_qe(1:dm)-x_lxc(1:dm)) > diff_thr)
  !
  IF (PRESENT(x_ud_qe)) THEN
    is_it_out_ud =  ABS(x_ud_qe-x_ud_lxc) > diff_thr
    is_it_out = ANY( (/ is_it_out, is_it_out_ud /) )
  ENDIF
  !
END FUNCTION
!
!------------------------------------------------------------------------
FUNCTION is_dit_out( diff_thr, dx_qe, dx_lxc )
  !----------------------------------------------------------------------
  !
  IMPLICIT NONE
  !
  REAL(DP), INTENT(IN) :: diff_thr, dx_qe(ns,ns), dx_lxc(ns,ns)
  REAL(DP) :: dxc_diff(np)
  LOGICAL :: is_dit_out
  !
  dxc_diff(1) = ABS(dx_qe(1,1)-dx_lxc(1,1))
  IF ( POLARIZED ) THEN
    dxc_diff(2) = ABS(dx_qe(2,1)-dx_lxc(2,1))
    dxc_diff(3) = ABS(dx_qe(2,2)-dx_lxc(2,2))
  ENDIF
  !
  is_dit_out = ANY(dxc_diff(:) > diff_thr)
  !
END FUNCTION
!
!
END PROGRAM xclib_test
!
!
!------------------------------------------------------------------------
FUNCTION calc_perc_diff( thr, x_qe, x_lxc )
  !----------------------------------------------------------------------
  !! Calculates difference between qe and libxc quantities in percentage.
  !
  IMPLICIT NONE
  !
  REAL(8), INTENT(IN) :: thr
  REAL(8), INTENT(IN) :: x_qe, x_lxc
  REAL(8) :: calc_perc_diff
  !
  REAL(8) :: perc_diff
  !
  perc_diff = -1.d0
  !
  IF ( ABS(x_qe)<10.d0*thr .AND. ABS(x_qe-x_lxc)<10.d0*thr ) RETURN
  IF ( ABS(x_qe)==0.d0 .AND. ABS(x_qe-x_lxc)>thr ) calc_perc_diff = 100.d0
  IF ( ABS(x_qe)>thr ) calc_perc_diff = ABS( (x_qe-x_lxc)/x_qe )*100.d0
  !
  RETURN
  !
END FUNCTION calc_perc_diff
