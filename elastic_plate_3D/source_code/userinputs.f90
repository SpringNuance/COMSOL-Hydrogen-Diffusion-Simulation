!***********************************************************************

module userinputs
    use precision
    implicit none

    ! THESE TWO VALUES ARE HARD-CODED
    ! YOU MUST CHANGE IT TO THE ACTUAL NUMBER OF ELEMENTS AND NODES IN .INP FILE
    ! YOU CAN USE PYTHON SCRIPTING TO CHANGE VALUES AS WELL

    integer, parameter :: total_elems = 3026 ! Storing the actual number of elements
    integer, parameter :: total_nodes = 4836 ! Storing the actual number of nodes

    ! Subset of SDVs indices that you want to output 
    integer, parameter :: uvar_indices(10) = (/1, 1, 1, 1, 1, 1, 1, 1, 1, 1/)
    
    ! Index of statev in UMAT
    integer, parameter :: sig_start_idx = 1 ! Starting index of the stress component in statev
    integer, parameter :: sig_end_idx = 6 ! Ending index of the strain component in statev
    integer, parameter :: stran_start_idx = 7 ! Starting index of the total strain component in statev
    integer, parameter :: stran_end_idx = 12 ! Ending index of the total strain component in statev
    integer, parameter :: eelas_start_idx = 13 ! Starting index of the elastic strain component in statev
    integer, parameter :: eelas_end_idx = 18 ! Ending index of the elastic strain component in statev
    integer, parameter :: eplas_start_idx = 19 ! Starting index of the plastic strain component in statev
    integer, parameter :: eplas_end_idx = 24 ! Ending index of the plastic strain component in statev
    integer, parameter :: eqplas_idx = 25 ! Index of the equivalent plastic strain in statev
    integer, parameter :: deqplas_idx = 26 ! Index of the increment of the equivalent plastic strain in statev
    integer, parameter :: sig_H_idx = 27 ! Index of the hydrogen concentration in statev
    integer, parameter :: sig_vonMises_idx = 28 ! Index of the equivalent von Mises stress in statev
    integer, parameter :: sig_Tresca_idx = 29 ! Index of the equivalent Tresca stress in statev
    integer, parameter :: sig_P1_idx = 30 ! Index of the first principal stress in statev
    integer, parameter :: sig_P2_idx = 31 ! Index of the second principal stress in statev
    integer, parameter :: sig_P3_idx = 32 ! Index of the third principal stress in statev
    integer, parameter :: triax_idx = 33 ! Index of the triaxiality in statev
    integer, parameter :: lode_idx = 34 ! Index of the Lode parameter in statev
    
    ! Index of statev in UMATHT
    integer, parameter :: C_mol_idx = 35 ! Index of the hydrogen concentration in mol in statev
    integer, parameter :: CL_mol_idx = 36 ! Index of the hydrogen concentration in lattice in mol in statev
    integer, parameter :: CT_mol_idx = 37 ! Index of the hydrogen concentration in trap in mol in statev
    integer, parameter :: C_wtppm_idx = 38 ! Index of the hydrogen concentration in wtppm in statev
    integer, parameter :: CL_wtppm_idx = 39 ! Index of the hydrogen concentration in lattice in wtppm in statev
    integer, parameter :: CT_wtppm_idx = 40 ! Index of the hydrogen concentration in trap in wtppm in statev
    integer, parameter :: theta_coverage_idx = 41 ! Index of the hydrogen surface coverage in statev
    integer, parameter :: k_HEHE_idx = 42 ! Index of the factor decreasing cohesive strength (HEDE)
    
    integer, parameter :: before_flow_props_idx = 8 ! Index of the first flow curve data in props in UMAT
    

end module