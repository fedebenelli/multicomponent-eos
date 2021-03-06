module test_pr
    use constants
    use cubic_eos, only: pr
    use testdrive, only : new_unittest, unittest_type, error_type, check

    implicit none

    private
    public :: collect_pr

contains
    
    type(pr) function PengRobinson(name, ac, b, tc, pc, w, k)
        character(len=:), allocatable :: name
        real(wp), optional :: ac !! Critical atractive parameter
        real(wp), optional :: b !! Repulsive parameter
        real(wp), optional :: tc !! Critical temperature
        real(wp), optional :: pc ! Critical pressure
        real(wp), optional :: w !! Accentric factor
        real(wp), optional :: k !! Atractive parameter constant

        if (present(tc) .and. present(pc) .and. present(w)) then
            PengRobinson = pr(name, 0, 0, tc, pc, w, 0)
            call PengRobinson%get_params()
        else if (present(ac) .and. present(b) .and. present(k)) then
            PengRobinson = pr(name, ac, b, 0, 0, 0, k)
            call PengRobinson%get_critical_constants()
        end if
    end function

    subroutine collect_pr(testsuite)
      type(unittest_type), allocatable, intent(out) :: testsuite(:)

      testsuite = [ &
        new_unittest("peng robinson delta1", test_del1_definition), &
        new_unittest("peng robinson attractive", test_attractive_parameter), &
        new_unittest("peng robinson get parameters", test_get_params), &
        new_unittest("peng robinson get critical constants", test_get_critical_constants) &
        ]
    end subroutine collect_pr


    subroutine test_get_params(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: name
        type(pr) :: compound
        real(wp) :: real_values(3), calc_values(3)

       

        name = "methane"
        compound = PengRobinson(name, tc=191.15_wp, pc=46.41_wp, w=0.0115_wp)

        call compound%get_params()

        real_values = [2.488, 0.0266, 0.3923]
        calc_values = [compound%ac, compound%b, compound%k]

        call check(error, maxval(abs(real_values - calc_values)) > errmax)

        if (allocated(error)) return

    end subroutine test_get_params


    subroutine test_get_critical_constants(error)
        type(error_type), allocatable, intent(out) :: error
        character(len=:), allocatable :: name
        type(pr) :: compound
        real(wp) :: real_values(3), calc_values(3)

        name = "methane"
        compound = PengRobinson(name, ac=2.4885_wp, b=0.02664_wp, k=0.3923_wp)
        call compound%get_critical_constants()

        real_values = [191.1554, 46.4135, 0.0115]
        calc_values = [compound%tc, compound%pc, compound%w]

        call check(error, maxval(abs(real_values - calc_values)) > errmax)

        if (allocated(error)) return

    end subroutine test_get_critical_constants


    subroutine test_attractive_parameter(error)
        type(error_type), allocatable, intent(out) :: error
        type(pr) :: compound1, compound2, compound3, compounds(3)
        real(wp) :: a_values(3), real_values(3)
        integer :: i

        real_values = [2282.1884, 17672.3093, 3373.5233]

        compound1 = pr("methane", 1, 2, 3, 4, 5, 6)
        compound2 = pr("nitrogen", 7, 8, 9, 10, 11, 12)
        compound3 = pr("ethane", 9, 5, 2, 15, 1, 2)

        compounds = [compound1, compound2, compound3]

        do i = 1, 3
            call compounds(i)%a_t(250._wp)
            a_values(i) = compounds(i)%a
        end do

        call check(error, maxval(abs(a_values - real_values)) > ERRMAX)

        if (allocated(error)) return
    end subroutine test_attractive_parameter


    subroutine test_del1_definition(error)
        type(error_type), allocatable, intent(out) :: error
        type(pr) :: compound

        compound = pr("methane", 1, 2, 3, 4, 5, 6)

        call check(error, abs(1.0_wp + sqrt(2.0_wp) - compound%del1) < errmax)
        if (allocated(error)) return
    end subroutine test_del1_definition
end module


program main
    use, intrinsic :: iso_fortran_env, only : error_unit
    use testdrive, only : run_testsuite, new_testsuite, testsuite_type
    use test_pr, only: collect_pr

    implicit none

    integer :: stat, is
    type(testsuite_type), allocatable :: testsuites(:)
    character(len=*), parameter :: fmt = '("#", *(1x, a))'

    stat = 0

    testsuites = [&
        new_testsuite("test_pr", collect_pr) &
        ]

    do is = 1, size(testsuites)
        write(error_unit, fmt) "Testing:", testsuites(is)%name
        call run_testsuite(testsuites(is)%collect, error_unit, stat)
    end do

    if (stat > 0) then
        write(error_unit, '(i0, 1x, a)') stat, "test(s) failed!"
        error stop
    end if
end program main
