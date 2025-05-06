subroutine kycurve(yield, h, hc, dd, ebar, cl, expo, e0, sig0, props, &
                   nprops, eta, avgeta, avgtheta, ps1, pddt, aiddt, ebart, &
                   aidd, pdd, syi, epcl, sc, c1, c2, c3, c4, etac, gf, &
                   d1, d2, d3, d4, dflag, aift, aif, fflag, dcrt, dcr, &
                   ctt, dtime, iwr, iout, ddh, syd, dcomb)

    use iso_fortran_env  ! Standard Fortran 90 module for precision
    implicit none

    ! Variable declarations
    integer, intent(in) :: nprops, iwr, iout
    real(kind=8), intent(in) :: dd, ebar, cl, expo, e0, sig0, dtime
    real(kind=8), intent(in) :: eta, avgeta, avgtheta, ps1, pddt, aiddt
    real(kind=8), intent(in) :: ebart, aidd, pdd, syi, epcl, sc
    real(kind=8), intent(in) :: c1, c2, c3, c4, etac, gf
    real(kind=8), intent(in) :: d1, d2, d3, d4, dcrt, dcr
    real(kind=8), intent(in) :: ctt
    real(kind=8), intent(out) :: yield, h, hc, ddh, syd, dcomb
    real(kind=8), intent(out) :: dflag, aift, aif, fflag
    real(kind=8), dimension(nprops), intent(in) :: props

    ! Local variables
    real(kind=8) :: ct, dctdep, dctdcl, thetal, thetat, ctotal, dcdep
    real(kind=8) :: aux, aux2, f, dfdc, ch1, ch2, xi
    real(kind=8) :: afita, afitb, ebar1
    real(kind=8) :: ddamdebar, syundmg, hundmg, hcundmg

    integer :: ihydro, ipldmg

    ! Flags for hydrogen effect and plasticity damage
    ihydro = 0  ! 1 for two-way coupling, 0 for one-way coupling
    ipldmg = 1  ! 1 for plasticity damage active, 0 for no damage

    ! Call function for hydrogen concentration effects
    call kct(ct, dctdep, dctdcl, ctt, thetal, thetat, ebar, cl, props, &
             nprops, dtime)

    ctotal = cl + ct
    dcdep = dctdep

    ! Define hydrogen softening thresholds
    ch1 = 8.0d0
    ch2 = 50.0d0
    xi = 0.1d0

    ! Hydrogen softening function
    if (ctotal <= ch1) then
        ddh = 0.0d0
        f = 1.0d0 - ddh
        dfdc = 0.0d0
    elseif (ctotal > ch2) then
        ddh = 1.0d0 - xi
        f = 1.0d0 - ddh
        dfdc = 0.0d0
    else
        ddh = (1.0d0 - xi) * (ctotal - ch1) / (ch2 - ch1)
        f = 1.0d0 - ddh
        dfdc = -(1.0d0 - xi) / (ch2 - ch1)
    end if

    ! If hydrogen effect is disabled, set neutral values
    if (ihydro /= 1) then
        f = 1.0d0
        dfdc = 0.0d0
        ddh = 0.0d0
    end if

    ! Compute undamaged yield stress and hardening
    afita = 0.3850d0
    afitb = 9.5341d0
    ebar1 = 0.179d0

    if (ebar > ebar1) then
        aux = sig0 * (1.31513d0 + 0.66615d0 * (ebar - 0.179d0))
        aux2 = sig0 * 0.66615d0
    else
        aux = sig0 * (1.0d0 + afita * (1.0d0 - exp(-afitb * ebar)))
        aux2 = sig0 * afita * afitb * exp(-afitb * ebar)
    end if

    syundmg = f * aux
    hundmg = dfdc * dcdep * aux + f * aux2
    hcundmg = dfdc * aux

    ! Compute yield stress and hardening with damage
    call kdamage(dd, ddamdebar, syundmg, ebar, eta, avgeta, avgtheta, &
                 ps1, pddt, aiddt, ebart, aidd, pdd, syi, epcl, sc, &
                 c1, c2, c3, c4, etac, gf, d1, d2, d3, d4, dflag, &
                 aift, aif, fflag, dcrt, dcr, ipldmg, ihydro, ddh, &
                 dcomb, iwr, iout)

    ! Compute final damaged yield stress
    syd = (1.0d0 - dd) * aux
    yield = (1.0d0 - dd) * syundmg
    h = (1.0d0 - dd) * hundmg - ddamdebar * syundmg
    hc = (1.0d0 - dd) * hcundmg

end subroutine kycurve


subroutine kdamage(dd, ddamdebar, yield, ebar, eta, avgeta, avgtheta, &
                   ps1, pddt, aiddt, ebart, aidd, pdd, syi, epcl, sc, &
                   c1, c2, c3, c4, etac, gf, d1, d2, d3, d4, dflag, &
                   aift, aif, fflag, dcrt, dcr, ipldmg, ihydro, ddh, dcomb, &
                   iwr, iout)

    implicit none

    ! Variable declarations
    integer, intent(in) :: ipldmg, ihydro, iwr, iout
    real(kind=8), intent(inout) :: dd, ddamdebar, yield, ebar, eta, avgeta, avgtheta
    real(kind=8), intent(inout) :: ps1, pddt, aiddt, ebart, aidd, pdd, syi, epcl, sc
    real(kind=8), intent(inout) :: c1, c2, c3, c4, etac, gf, d1, d2, d3, d4
    real(kind=8), intent(inout) :: dflag, aift, aif, fflag, dcrt, dcr, ddh, dcomb

    ! Local variables
    real(kind=8) :: auxep, epi, auxdd, dcombcrit
    real(kind=8) :: pdd_old, ddam_old

    ! Print debugging information if requested
    if (iwr /= 0) then
        write(iout, *)
        write(iout, *) 'enters kdamage'
        write(iout, *) 'flag for plasticity damage ipldmg:'
        write(iout, '(I5)') ipldmg
        write(iout, *) 'aiddt, pddt, ebar, ebart'
        write(iout, '(4E13.5)') aiddt, pddt, ebar, ebart
        write(iout, *) 'c1, c2, c3, c4, d1, d2, d3, d4, syi, gf'
        write(iout, '(10E13.5)') c1, c2, c3, c4, d1, d2, d3, d4, syi, gf
    end if

    ! No plasticity damage case
    if (ipldmg /= 1) then
        aidd = aiddt
        aif = aift
        pdd = pddt
        dd = pdd
        dcr = dcrt
        ddamdebar = 0.0d0
        return
    end if

    if (ebar <= 1.0d-3 .or. fflag == 0.0d0) then
        aidd = aiddt
        aif = aift
        pdd = pddt
        dd = pdd
        dcr = dcrt
        ddamdebar = 0.0d0
        return
    end if

    ! Compute functions epi and dcr
    auxep = (c1 * exp(-c2 * avgeta) - c3 * exp(-c4 * avgeta)) * avgtheta**2 + &
             c3 * exp(-c4 * avgeta)
    if (avgeta > etac) then
        epi = auxep
    else
        epi = 1000.0d0
    end if

    auxdd = (d1 * exp(-d2 * avgeta) - d3 * exp(-d4 * avgeta)) * avgtheta**2 + &
             d3 * exp(-d4 * avgeta)
    if (avgeta > etac) then
        dcr = auxdd
    else
        dcr = 1000.0d0
    end if

    if (iwr /= 0) then
        write(iout, *) 'auxep, epi, auxdd, dcr'
        write(iout, '(4E13.5)') auxep, epi, auxdd, dcr
    end if

    ! *** Damage Checks ***

    ! Check 1: Cleavage failure
    if (ebar >= epcl .and. ps1 >= sc) then
        aif = 1.0d0
        aidd = 1.0d0
        fflag = 0.0d0
        pdd = 0.995d0
        dd = pdd
        ddamdebar = 0.0d0
        return
    end if

    ! Check 2: Ductile damage initiation
    aidd = aiddt + (ebar - ebart) / epi
    if (aidd >= 1.0d0 .and. dflag /= 1.0d0) then
        syi = yield
        dflag = 1.0d0
    end if
    if (aidd > 1.0d0) then
        aidd = 1.0d0
    end if

    if (iwr /= 0) then
        write(iout, *) 'aidd, syi, dflag'
        write(iout, '(3E13.5)') aidd, syi, dflag
    end if

    ! Check 3: Damage evolution and ductile damage failure
    if (dflag == 1.0d0) then
        if (eta > etac) then
            pdd_old = pddt
            pdd = pdd_old + syi * (ebar - ebart) / gf
            dd = pdd
            aif = aift + (pdd - pdd_old) / dcr
            ddamdebar = syi / gf
        else
            pdd = pddt
            dd = pdd
            aif = aift
            ddamdebar = 0.0d0
        end if
    end if

    if (aif >= 1.0d0) then
        aif = 1.0d0
        pdd = pddt
        dd = pdd
        ddamdebar = 0.0d0
        fflag = 0.0d0
    end if

    if (dd > 0.995d0) then
        dd = 0.995d0
        ddamdebar = 0.0d0
    end if

    if (iwr /= 0) then
        write(iout, *) 'aidd, dflag, aif, fflag, dd, ddamdebar, pdd, dcr'
        write(iout, '(8E13.5)') aidd, dflag, aif, fflag, dd, ddamdebar, pdd, dcr
    end if

    ! Check 4: Combined damage failure
    dcomb = 1.0d0 - (1.0d0 - dd) * (1.0d0 - ddh)
    dcombcrit = 0.8d0

    if (ipldmg == 1 .and. ihydro == 1) then
        if (dcomb >= dcombcrit) then
            fflag = 0.0d0
        end if
    end if

end subroutine kdamage
