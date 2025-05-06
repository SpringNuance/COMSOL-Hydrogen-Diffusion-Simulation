!***********************************************************************

module common_block
    use precision
    use userinputs
    implicit none

    real(kind=dp), parameter :: molar_mass_H = 1.00784d0 ! g/mol
    real(kind=dp), parameter :: molar_mass_Fe = 55.845d0 ! g/mol
    real(kind=dp), parameter :: ratio_molar_mass_Fe_H = 55.415d0
    real(kind=dp), parameter :: density_metal = 7900.0d0 ! kg/m^3
    ! CL_wtppm = (CL_mol * molar_mass_H) / (density_metal * 1.d-03)
    real(kind=dp), parameter :: conversion_mol_to_wtppm = 0.127574683544d0 ! wtppm
    ! CL_molfrac = (CL_wtppm * 1.d-6) * (ratio_molar_mass_Fe_H)
    real(kind=dp), parameter :: conversion_wtppm_to_molfrac = 55.4105d-6 ! molfrac 
    ! Inverse of conversion_wtppm_to_mol
    real(kind=dp), parameter :: conversion_wtppm_to_mol = 7.838545801d0 ! mol
    real(kind=dp), parameter :: conversion_mol_to_molfrac = 7.068977d-6 ! molfrac
    real(kind=dp), parameter :: pi = 3.14159d0 ! dimless
    real(kind=dp), parameter :: inv_pi = 1.0d0 / 3.14159d0 ! dimless
    real(kind=dp), parameter :: half = 1.0d0 / 2.0d0 ! dimless
    real(kind=dp), parameter :: third = 1.0d0 / 3.0d0 ! dimless
    real(kind=dp), parameter :: fourth = 1.0d0 / 4.0d0 ! dimless
    real(kind=dp), parameter :: sixth = 1.0d0 / 6.0d0 ! dimless
    real(kind=dp), parameter :: three_half = 3.0d0 / 2.0d0 ! dimless
    real(kind=dp), parameter :: sqrt_three_half = dsqrt(3.0d0 / 2.0d0) ! dimless
    real(kind=dp), parameter :: two_third = 2.0d0 / 3.0d0 ! dimless
    real(kind=dp), parameter :: sqrt_two_third = dsqrt(2.0d0 / 3.0d0) ! dimless
    real(kind=dp), parameter :: nine_half = 9.0d0 / 2.0d0 ! dimless


    integer, parameter :: ndim = 3 ! Number of spatial dimensions
    integer, parameter :: ninpt = 8 ! Number of integration points (IP) in the element
    integer, parameter :: nnode = 8 ! Number of nodes in the element
    integer, parameter :: ntensor = 6 ! Number of Voigt notation stress/strain components
    integer, parameter :: nmax_elems = 20 ! Maximum number of elements that a node can have

    ! Technically, nmax_elems is 10 for C3D8 mesh
    ! However we are uncertain what could be maximum number of elements that a node can have
    ! So we just set it to large number to be safe
    
    ! First dim: number of nodes on the mesh
    ! Second dim: maximum number of elements that contains the node in the first dim
    ! In meshing algorithm in FEA softwares lie Abaqus that used hexahedral, nmax_elems is proven to be 8
    ! Third dim: first value tells the element ID that contains this node
    !            second value tells the ith position of the node in this element ID
    ! When this node does not have nmax_elems containing it, all others are padded with 0

    ! Example: Lets say element of ID 10, 20, 30, 40 contains node of ID 7
    !          In element 10, node 7 is at position 1
    !          In element 20, node 7 is at position 6
    !          In element 30, node 7 is at position 3
    !          In element 40, node 7 is at position 5

    ! Then nodes_to_elems_matrix(7, 1, 1) = 10
    !      nodes_to_elems_matrix(7, 1, 2) = 1
    !      nodes_to_elems_matrix(7, 2, 1) = 20
    !      nodes_to_elems_matrix(7, 2, 2) = 6
    !      nodes_to_elems_matrix(7, 3, 1) = 30
    !      nodes_to_elems_matrix(7, 3, 2) = 3
    !      nodes_to_elems_matrix(7, 4, 1) = 40
    !      nodes_to_elems_matrix(7, 4, 2) = 5
    !      nodes_to_elems_matrix(7, 5:8, 1:2) = 0

    integer :: nodes_to_elems_matrix(total_nodes, nmax_elems, 2) !

    integer :: num_elems_of_nodes_matrix(total_nodes) ! Number of elements that contain the node
    
    ! First dim: number of elements in the mesh
    ! Second dim: number of nodes in the element
    ! Since all elements must have 8 nodes, it does not need to be padded
    ! The nodes are also in their correct order as well from knode to 1 to 8
    
    integer :: elems_to_nodes_matrix(total_elems, nnode)

    ! Shape function for all IP in the local isoparametric coordinate
    ! Given values at nodal points, this matrix will give the values at IP (interpolation)
    ! This is helpful for calculating values at IPs from the DoF values defined at nodal points 
    real(kind=dp) :: all_N_inpt_to_local_knode(nnode, ninpt)
    
    ! Shape function for all nodes in the local isoparametric coordinate
    ! Given values at IPs, this matrix will give the values at nodal points (extrapolation)
    ! This is helpful for calculating values at nodal points from values defined at IPs
    ! Such as hydrostatic stress gradient or for visualization
    real(kind=dp) :: all_N_node_to_local_kinpt(ninpt, nnode)
    
    ! Gradient of all_N_node_to_local_kinpt
    real(kind=dp) :: all_N_grad_node_to_local_kinpt(ninpt, ndim, nnode)
    
    ! This matrix keeps tract of all sig_H at IPs for all elements as computed from UMAT
    real(kind=dp) :: sig_H_all_elems_at_inpts(total_elems, ninpt)

    ! This matrix keeps track of extrapolated sig_H from IP onto nodal points for all elements
    real(kind=dp) :: sig_H_all_elems_at_nodes(total_elems, nnode)

    ! This matrix keeps track of the gradient of sig_H from IP onto nodal points for all elements
    real(kind=dp) :: sig_H_grad_all_elems_at_inpts(total_elems, ninpt, ndim)
    ! Finally, this matrix keeps track of the average sig_H at each node from the elements
    ! that contain the node. The average is weighted based on change of volume 
    ! (determinant of Jacobian matrix)

    real(kind=dp) :: sig_H_at_nodes(total_nodes) ! (total_nodes)

    ! This stores the IP coordinates at previous time step
    real(kind=dp) :: coords_all_inpts(total_elems, ninpt, ndim)

    ! This stores the nodal coordinates at previous time step
    real(kind=dp) :: coords_all_nodes(total_nodes, ndim)

    ! This stores the determinant of Jacobian matrix of all nodes based on coordinates of the previous time step
    real(kind=dp) :: djac_all_elems_at_nodes(total_elems, nnode)

    ! The matrix tensors
    ! kronecker-Delta tensor
    real(kind=dp) :: delta_tensor(ntensor, ntensor) ! DELTA in prof Aravas's code
    real(kind=dp) :: isotropic_tensor(ntensor, ntensor) ! AIMX in prof Aravas's code
    real(kind=dp) :: hydrostatic_tensor(ntensor, ntensor) ! AJMX in prof Aravas's code
    real(kind=dp) :: deviatoric_tensor(ntensor, ntensor) ! AKMX in prof Aravas's code

    save
    ! The save command is very important. 
    ! It allows the values to be stored and shared between subroutines 
    ! without resetting them to zero every time the subroutine is called

end module