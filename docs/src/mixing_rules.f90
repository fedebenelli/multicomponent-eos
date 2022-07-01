module mixing_rules
   !! Module that contains the available mixing rules to be used.
   use constants
   implicit none

   type :: kij_constant
      !! \[K_ij\] constant type
      real(wp), allocatable :: kij(:, :) !! \[K_ij\] matrix
   contains
      procedure :: get_kij => kij_const
   end type

   type, extends(kij_constant) :: kij_exp_t
      !! Kij with temperature dependance according to the equation:
      !! \[ K_{ij}(T) = K_{ij\infty} + K_{ij0} e^{-T/T^*} \]
      !! The parameters of the equation are obtained from the mixture module.
      real(wp), allocatable :: dkijdt(:, :) !! \[K_ij\] matrix
      real(wp), allocatable :: dkij2dt2(:, :) !! \[K_ij\] matrix
      real(wp), allocatable :: kij_0(:, :) !! Exponential
      real(wp), allocatable :: kij_inf(:, :) !! K_ij at infinite Temperature
      real(wp), allocatable :: T_star(:, :) !! Reference temperature
   contains
      procedure :: get_kij => kij_tdep
   end type

   type :: lij_constant
      !! Constant \[l_{ij}\]
      real(wp), allocatable :: lij(:, :) !! \[l_{ij}\] values
   contains
      procedure :: get_lij => lij_const
   end type lij_constant

contains

   subroutine kij_tdep(self, T, kij, dkijdt, dkij2dt2)
      implicit none
      class(kij_exp_t) :: self
      real(wp), intent(in) :: T !! Temperature

      real(wp), allocatable, intent(out) :: kij(:, :) !! Binary interaction parameter matrix
      real(wp), allocatable, intent(out) :: dkijdt(:, :) !! Binary interaction parameter first derivative with T matrix
      real(wp), allocatable, intent(out) :: dkij2dt2(:, :) !! Binary interaction parameter second derivative with T matrix

      real(wp), allocatable :: kij_inf(:, :), kij_0(:, :), T_star(:, :)
      integer :: nc, sp(2)

      kij_0 = self%kij_0
      kij_inf = self%kij_inf
      T_star = self%T_star

      sp = shape(self%kij_0)
      nc = sp(1)

      allocate (kij(nc, nc))
      allocate (dkijdt(nc, nc))
      allocate (dkij2dt2(nc, nc))

      kij = kij_inf + kij_0*exp(-T/T_star)
      dkijdt = -kij_0/T_star*exp(-T/T_star)
      dkij2dt2 = kij_0/T_star**2*exp(-T/T_star)

      self%kij = kij
      self%dkijdt = dkijdt
      self%dkij2dt2 = dkij2dt2
   end subroutine kij_tdep

   subroutine kij_const(self, T, kij, dkijdt, dkij2dt2)
      class(kij_constant) :: self
      real(wp), intent(in) :: T !! Temperature

      real(wp), allocatable, intent(out) :: kij(:, :) !! Binary interaction parameter matrix
      real(wp), allocatable, intent(out) :: dkijdt(:, :) !! Binary interaction parameter first derivative with T matrix
      real(wp), allocatable, intent(out) :: dkij2dt2(:, :) !! Binary interaction parameter second derivative with T matrix

      kij = self%kij
      dkijdt = 0*kij
      dkij2dt2 = 0*kij
   end subroutine kij_const

   subroutine lij_const(self, T, lij)
      class(lij_constant) :: self
      real(wp), intent(in) :: T !! Temperature
      real(wp), allocatable, intent(out) :: lij(:, :) !! Binary repulsive parameter matrix

      lij = self%lij
   end subroutine lij_const

   subroutine quadratic(nc, a, b, kij, dadt, da2dt2, dkijdt, dkij2dt2, lij, aij, daijdt, daij2dt2, bij)
      !! Classic quadratic mixing rules.
      integer, intent(in) :: nc !! Number of components
      real(wp), intent(in) :: a(nc) !! Atractive parameter at working temperature
      real(wp), intent(in) :: b(nc) !! Repulsive parameter
      real(wp), intent(in) :: kij(nc, nc) !! Kij matrix
      real(wp), intent(in) :: dadt(nc) !! First derivative with T
      real(wp), intent(in) :: da2dt2(nc) !! Second derivative with T
      real(wp), intent(in) :: dkijdt(nc, nc) !! Kij matrix first derivative
      real(wp), intent(in) :: dkij2dt2(nc, nc) !! Kij matrix second derivative
      real(wp), intent(in) :: lij(nc, nc) !! Lij matrix

      real(wp), intent(out) :: aij(nc, nc) !! Binary atractive parameters matrix
      real(wp), intent(out) :: daijdt(nc, nc) !! First derivative with T
      real(wp), intent(out) :: daij2dt2(nc, nc) !! Second derivative with T
      real(wp), intent(out) :: bij(nc, nc) !! Repulse parameter matrix

      integer :: i, j

      do i = 1, nc
         aij(i, i) = a(i)
         daijdT(i, i) = dadT(i)
         daij2dT2(i, i) = da2dT2(i)
         do j = 1, nc
            aij(j, i) = sqrt(a(i)*a(j))*(1 - kij(j, i))
            aij(i, j) = aij(j, i)

            daijdt(j, i) = (1 - Kij(j, i))*(sqrt(a(i)/a(j))*dadT(j) + sqrt(a(j)/a(i))*dadT(i))/2 &
                           - dkijdt(j, i)*sqrt(a(j)*a(i))
            daijdt(i, j) = daijdT(j, i)

            daij2dt2(j, i) = (1 - Kij(j, i))*(dadt(j)*dadt(i)/sqrt(a(i)*a(j)) &
                             + sqrt(a(i)/a(j))*(da2dt2(j) - dadt(j)**2/(2*a(j))) &
                             + sqrt(a(j)/a(i))*(da2dt2(i) - dadt(i)**2/(2*a(i))))/2 &
                             - dkijdt(j, i)*(a(j)*dadt(i) + a(i)*dadt(j))/sqrt(a(j)*a(i)) &
                             - dkij2dt2(j, i)*sqrt(a(j)*a(i))
            daij2dT2(i, j) = daij2dT2(j, i)

            bij(i, j) = (1 - lij(i, j))*(b(i) + b(j))/2
            bij(j, i) = bij(i, j)
         end do
      end do
   end subroutine quadratic
end module mixing_rules
