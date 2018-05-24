!
! Copyright (C) 2002-2011 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#define DIMS2D(my_array) lbound(my_array,1):ubound(my_array,1),lbound(my_array,2):ubound(my_array,2)
!=----------------------------------------------------------------------------=!
   MODULE gvect_gpum
!=----------------------------------------------------------------------------=!
     USE kinds, ONLY :  DP

     IMPLICIT NONE
     SAVE
     !
     REAL(DP), ALLOCATABLE, TARGET :: gg_d(:)
     REAL(DP), ALLOCATABLE, TARGET :: g_d(:, :)
     !
#if defined(__CUDA)
     attributes (DEVICE) :: gg_d, g_d

     LOGICAL :: gg_ood = .false.    ! used to flag out of date variables
     LOGICAL :: gg_d_ood = .false.    ! used to flag out of date variables
     LOGICAL :: g_ood = .false.    ! used to flag out of date variables
     LOGICAL :: g_d_ood = .false.    ! used to flag out of date variables
     !
#endif
     CONTAINS
     !
     SUBROUTINE using_gg(intento)
         !
         ! intento is used to specify what the variable will  be used for :
         !  0 -> in , the variable needs to be synchronized but won't be changed
         !  1 -> inout , the variable needs to be synchronized AND will be changed
         !  2 -> out , NO NEED to synchronize the variable, everything will be overwritten
         !
         USE gvect, ONLY : gg
         implicit none
         INTEGER, INTENT(IN) :: intento
#if defined(__CUDA)
         INTEGER :: intento_
         intento_ = intento
         !
         IF (gg_ood) THEN
             IF (.not. allocated(gg_d)) THEN
                CALL errore('using_gg_d', 'PANIC: sync of gg from gg_d with unallocated array. Bye!!', 1)
                stop
             END IF
             IF (.not. allocated(gg)) THEN
                IF (intento_ /= 2) THEN
                   print *, "WARNING: sync of gg with unallocated array and intento /= 2? Changed to 2!"
                   intento_ = 2
                END IF

                ! IF (intento_ > 0)    gg_d_ood = .true.
             END IF
             IF (intento_ < 2) THEN
                print *, "Really copied gg D->H"
                gg = gg_d
             END IF
             gg_ood = .false.
         ENDIF
         IF (intento_ > 0)    gg_d_ood = .true.
#endif
     END SUBROUTINE using_gg
     !
     SUBROUTINE using_gg_d(intento)
         !
         USE gvect, ONLY : gg
         implicit none
         INTEGER, INTENT(IN) :: intento
#if defined(__CUDA)
         !
         IF (.not. allocated(gg)) THEN
             IF (intento /= 2) print *, "WARNING: sync of gg_d with unallocated array and intento /= 2?"
             IF (allocated(gg_d)) DEALLOCATE(gg_d)
             gg_d_ood = .false.
             RETURN
         END IF
         ! here we know that gg is allocated, check if size is 0 
         IF ( SIZE(gg) == 0 ) THEN
             print *, "Refusing to allocate 0 dimensional array gg_d. If used, code will crash."
             RETURN
         END IF
         !
         IF (gg_d_ood) THEN
             IF ( allocated(gg_d) .and. (SIZE(gg_d)/=SIZE(gg))) deallocate(gg_d)
             IF (.not. allocated(gg_d)) ALLOCATE(gg_d, MOLD=gg)  ! this copy may be avoided
             IF (intento < 2) THEN
                print *, "Really copied gg H->D"
                gg_d = gg
             END IF
             gg_d_ood = .false.
         ENDIF
         IF (intento > 0)    gg_ood = .true.
#else
         CALL errore('using_gg_d', 'Trying to use device data without device compilated code!', 1)
#endif
     END SUBROUTINE using_gg_d
     !
     SUBROUTINE using_g(intento)
         !
         ! intento is used to specify what the variable will  be used for :
         !  0 -> in , the variable needs to be synchronized but won't be changed
         !  1 -> inout , the variable needs to be synchronized AND will be changed
         !  2 -> out , NO NEED to synchronize the variable, everything will be overwritten
         !
         USE gvect, ONLY : g
         implicit none
         INTEGER, INTENT(IN) :: intento
#if defined(__CUDA)
         INTEGER :: intento_
         intento_ = intento
         !
         IF (g_ood) THEN
             IF (.not. allocated(g_d)) THEN
                CALL errore('using_g_d', 'PANIC: sync of g from g_d with unallocated array. Bye!!', 1)
                stop
             END IF
             IF (.not. allocated(g)) THEN
                IF (intento_ /= 2) THEN
                   print *, "WARNING: sync of g with unallocated array and intento /= 2? Changed to 2!"
                   intento_ = 2
                END IF

                ! IF (intento_ > 0)    g_d_ood = .true.
             END IF
             IF (intento_ < 2) THEN
                print *, "Really copied g D->H"
                g = g_d
             END IF
             g_ood = .false.
         ENDIF
         IF (intento_ > 0)    g_d_ood = .true.
#endif
     END SUBROUTINE using_g
     !
     SUBROUTINE using_g_d(intento)
         !
         USE gvect, ONLY : g
         implicit none
         INTEGER, INTENT(IN) :: intento
#if defined(__CUDA)
         !
         IF (.not. allocated(g)) THEN
             IF (intento /= 2) print *, "WARNING: sync of g_d with unallocated array and intento /= 2?"
             IF (allocated(g_d)) DEALLOCATE(g_d)
             g_d_ood = .false.
             RETURN
         END IF
         ! here we know that g is allocated, check if size is 0 
         IF ( SIZE(g) == 0 ) THEN
             print *, "Refusing to allocate 0 dimensional array g_d. If used, code will crash."
             RETURN
         END IF
         !
         IF (g_d_ood) THEN
             IF ( allocated(g_d) .and. (SIZE(g_d)/=SIZE(g))) deallocate(g_d)
             IF (.not. allocated(g_d)) ALLOCATE(g_d, MOLD=g)  ! this copy may be avoided
             IF (intento < 2) THEN
                print *, "Really copied g H->D"
                g_d = g
             END IF
             g_d_ood = .false.
         ENDIF
         IF (intento > 0)    g_ood = .true.
#else
         CALL errore('using_g_d', 'Trying to use device data without device compilated code!', 1)
#endif
     END SUBROUTINE using_g_d
     !     
     SUBROUTINE deallocate_gvect_gpu
       IF( ALLOCATED( gg_d ) ) DEALLOCATE( gg_d )
       IF( ALLOCATED( g_d ) ) DEALLOCATE( g_d )
     END SUBROUTINE deallocate_gvect_gpu
!=----------------------------------------------------------------------------=!
   END MODULE gvect_gpum
!=----------------------------------------------------------------------------=!