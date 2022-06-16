module cubic_eos
   !! Module that encompass the calculations of the residual Helmholtz energy
   !! and related properties like fugacity coefficents.
   use constants
   implicit none

   type :: ceos
      real(8) :: ac
      real(8) :: b
      real(8) :: tc
      real(8) :: pc
      real(8) :: k
      real(8) :: v
      real(8) :: t
      real(8) :: a
      real(8) :: dadt
      real(8) :: da2dt2
      contains
         procedure :: a_t => a_parameter
   end type ceos

   type, extends(ceos) :: pr
      real(8) :: del1 = 1
   end type pr
   
   type, extends(ceos) :: srk
      real(8) :: del1 = 1 + sqrt(2.d0)
   end type srk

   type, extends(ceos) :: rkpr
      real(8) :: del1 = 1 + sqrt(2.d0)
   end type rkpr

contains

   subroutine a_parameter(self, T)
      class(ceos) :: self
      real(8), intent(in) :: T !! Temperature where to calculate 

      real(8) :: Tr
      real(8) :: ac, k, Tc

      select type (self)
      class is (rkpr)
         Tc = self%Tc
         ac = self%ac
         k = self%k
         Tr = T/Tc

         self%a = ac*(3/(2 + Tr))**k
         self%dadT = -k*self%a/Tc/(2 + Tr)
         self%da2dT2 = -(k + 1)*self%dadT/Tc/(2 + Tr)

      class is (ceos)
         Tc = self%Tc
         ac = self%ac
         k = self%k
         Tr = T/Tc
         self%a = ac*(1 + k*(1 - sqrt(Tr)))**2
         self%dadT = ac*k*(k - (k + 1)/sqrt(Tr))/Tc
         self%da2dT2 = ac*k*(k + 1)/(2*Tc**2*Tr**1.5)
      end select
   end subroutine a_parameter

   subroutine aTder(&
       nc, ac, tc, k, &
       T, &
       a, dadT, dadT2&
      )
      !! Calculate the atractive parameter at T temperature.
      !! the subroutine will read the mixture's model and based on that
      !! will use the corresponding rule.
      use mixture, only: nmodel

      integer, intent(in) :: nc !! Number of components
      real(wp), intent(in) :: ac(nc) !! Critical atractive parameter 
      real(wp), intent(in) :: tc(nc) !! Critical temperatures
      real(wp), intent(in) :: k(nc) !! Accentric factor related constant
      
      real(wp), intent(in) :: T !! Temperature

      real(wp), intent(out) :: a(nc)  !! Atractive parameter at T
      real(wp), intent(out) :: dadT(nc) !! First deritvative with T
      real(wp), intent(out) :: dadT2(nc)  !! Second derivative with T

      real(wp) :: Tr(nc) ! Reduced temperature

      Tr = T/Tc
      if (nmodel <= 2) then
         ! SRK and PR
         a = ac*(1 + k*(1 - sqrt(Tr)))**2
         dadT = ac*k*(k - (k + 1)/sqrt(Tr))/Tc
         dadT2 = ac*k*(k + 1)/(2*Tc**2*Tr**1.5)
      else if (nmodel == 3) then
         ! RKPR EOS
         a = ac*(3/(2 + Tr))**k
         dadT = -k*a/Tc/(2 + Tr)
         dadT2 = -(k + 1)*dadT/Tc/(2 + Tr)
      end if
   end subroutine aTder

   subroutine aijTder(T, aij, daijdT, daij2dT2)
        !! Calculate the binary atractive term matrix
      use mixture, only: nc, ntdep, kij, kij_0, lij, ncomb
      use mixing_rules, only: quadratic
      implicit none

      real(wp), intent(in) :: T !! Temperature

      real(wp), intent(out) :: aij(nc, nc) !! Atractive binary terms matrix
      real(wp), intent(out) :: daijdT(nc, nc) !! Atractive binary terms matrix first derivative with temperature
      real(wp), intent(out) :: daij2dT2(nc, nc) !! Atractive binary terms matrix second derivative with temperature

      real(wp) :: dkijdt(nc, nc), dkij2dt2(nc, nc) ! kij T derivatives
      real(wp) :: a(nc), dadT(nc), da2dT2(nc) ! Atractive parameter and T derivatives
      real(wp) :: b(nc), bij(nc, nc) ! Repulsive parameter (just to use as input in subroutine)

      b = 0  ! Here only the aij for the mixture, so there is no need to use the real b

      select case (ntdep)
      case (1)
         ! Kij exponential temperature dependance
         call kij_tdep(T, kij, dkijdt, dkij2dt2)
      case default
         kij = kij_0
         dkijdt = 0
         dkij2dt2 = 0
      end select

      ! Calculate pure compound atractive parameters at T
      call aTder(T, a, dadT, da2dT2)

      ! Apply combining rule
      select case (ncomb)
      case default
         call quadtratic(nc, a, b, kij, dadt, da2dt2, dkijdt, dkij2dt2, &
                         lij, aij, daijdt, daij2dt2, bij)
      end select
   end subroutine aijTder

   subroutine amixTnder(nc, T, n, a, dadni, da2dniT2, da2dnij2, dadT, da2dT2)
      integer, intent(in) :: nc !! Number of components
      real(wp), intent(in) :: T !! Temperature
      real(wp), intent(in) :: n(nc) !! Matrix with number of moles

      real(wp), intent(out) :: a !! Mixture atractive parameter
      real(wp), intent(out) :: dadni(nc) !! Atractive parameter first derivative with number of moles
      real(wp), intent(out) :: da2dniT2(nc) !! Atractive parameter second derivative with moles and Tempeature
      real(wp), intent(out) :: da2dnij2(nc, nc) !! Atractive parameter second derivative with number of moles

      real(wp), intent(out) :: dadT(nc) !! Atractive parameter first derivative with Tempeature
      real(wp), intent(out) :: da2dT2(nc) !! Atractive parameter first derivative with Tempeature

      real(wp) :: aij(nc, nc), daijdT(nc, nc), daijdT2(nc, nc)
      real(wp) :: aux, aux2
      integer :: i, j

      ! TODO: An already calculated aij matrix could be the input
      call aijTder(T, aij, daijdT, daijdT2)

      a = 0.0_wp
      dadT = 0.0_wp
      da2dT2 = 0.0_wp

      do i = 1, nc
         aux = 0.0_wp
         aux2 = 0.0_wp
         dadni(i) = 0.0_wp
         da2dniT2(i) = 0.0_wp
         do j = 1, nc
            dadni(i) = dadni(i) + 2*n(j)*aij(i, j)
            da2dniT2(i) = da2dniT2(i) + 2*n(j)*daijdT(i, j)
            da2dnij2(i, j) = 2*aij(i, j)

            aux = aux + n(j)*aij(i, j)
            aux2 = aux2 + n(j)*daijdT2(i, j)
         end do
         a = a + n(i)*aux
         dadT = dadT + n(i)*da2dniT2(i)/2
         da2dT2 = da2dT2 + n(i)*aux2
      end do
   end subroutine amixTnder

   subroutine d1nder(nc, n, d1, d1_mix, dD1dni, dD12dnij2)
      integer, intent(in) :: nc !! Number of components.
      real(wp), intent(in) :: n(nc) !! Array of mole numbers for each component.
      real(wp), intent(in) :: d1(nc) !! Array of delta 1 parameters for each component.
      real(wp), intent(out) :: d1_mix !! ??
      real(wp), intent(out) :: dD1dni(nc) !! delta1 parameter first derivative with composition.
      real(wp), intent(out) :: dD12dnij2(nc, nc) !! delta1 parameter second derivative with composition.

      integer :: i, j
      real(wp) :: totn ! Total number of moles

      d1_mix = 0.0_wp

      d1_mix = sum(n*d1)

      totn = sum(n)
      d1_mix = d1_mix/totn
      dD1dni = (d1 - d1_mix)/totn

      do i = 1, nc
         
         do j = 1, nc
            dD12dnij2(i, j) = (2.0_wp*d1_mix - d1(i) - d1(j))/totn**2
         end do
      end do
   end subroutine d1nder

   subroutine Bnder(nc, n, bij, B_mix, dBdni, dB2dnij2)
      integer, intent(in) :: nc
      real(wp), intent(in) :: n(nc)
      real(wp), intent(in) :: bij(nc, nc)

      real(wp), intent(out) :: B_mix
      real(wp), intent(out) :: dBdni(nc)
      real(wp), intent(out) :: dB2dnij2(nc, nc)

      real(wp) :: totn, aux(nc)
      integer :: i, j

      totn = sum(n)
      B_mix = 0.0_wp
      aux = 0.0_wp

      do i = 1, nc
         do j = 1, nc
            aux(i) = aux(i) + n(j)*bij(i, j)
         end do
         B_mix = B_mix + n(i)*aux(i)
      end do

      B_mix = B_mix/totn

      do i = 1, nc
         dBdni(i) = (2*aux(i) - B_mix)/totn
         do j = 1, i
            dB2dnij2(i, j) = (2*bij(i, j) - dBdni(i) - dBdni(j))/totn
            dB2dnij2(j, i) = dB2dnij2(i, j)
         end do
      end do
   end subroutine Bnder
end module cubic_eos
