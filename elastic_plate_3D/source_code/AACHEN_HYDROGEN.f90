!====================================================================
!          Program for mechanical loading and hydrogen diffusion 
!          Mechanical model: standard Hooke's law elasticity 
!                            isotropic Von Mises plasticity
!          Hydrogen diffusion model: Fick's second law
!          Damage model: None. 
!          Deformation affects hydrogen diffusion but not vice versa
!          This is the basis model that users can use to extend to more complex damage model
!          by Nguyen Xuan Binh
!          binh.nguyen@aalto.fi
!          July 2024, Abaqus 2023
!          DO NOT DISTRIBUTE WITHOUT AUTHOR'S PERMISSION
!====================================================================

    ! State variables  
    ! UMAT statv
    ! 1 to 6: sig11, sig22, sig33, sig12, sig13, sig23
    ! 7 to 12: stran11, stran22, stran33, stran12, stran13, stran23
    ! 13 to 18: eelas11, eelas22, eelas33, eelas12, eelas13, eelas23
    ! 19 to 24: eplas11, eplas22, eplas33, eplas12, eplas13, eplas23
    ! "25, AR25_eqplas, AR25_eqplas   ", 
    ! "26, AR26_deqplas, AR26_deqplas   ",
    ! "27, AR27_sig_H, AR27_sig_H   ",
    ! "28, AR28_sig_vonMises, AR28_sig_vonMises   ",
    ! "29, AR29_sig_Tresca, AR29_sig_Tresca   ",
    ! "30, AR30_sig_P1, AR30_sig_P1   ",
    ! "31, AR31_sig_P2, AR31_sig_P2   ",
    ! "32, AR32_sig_P3, AR32_sig_P3   ",
    ! "33, AR33_triax, AR33_triax   ",
    ! "34, AR34_lode, AR34_lode   ",


    ! UMATHT statv
    ! "35, AR35_C_mol, AR35_C_mol   ",
    ! "36, AR36_CL_mol, AR36_CL_mol   ",
    ! "37, AR37_CT_mol, AR37_CT_mol   ",
    ! "38, AR41_C_wtppm, AR41_C_wtppm   ",
    ! "39, AR42_CL_wtppm, AR42_CL_wtppm   ",
    ! "40, AR43_CT_wtppm, AR43_CT_wtppm   ",
    ! "41, AR49_theta_coverage, AR49_theta_coverage   ",
    ! "42, AR50_k_HEHE, AR50_k_HEHE   ",


!***********************************************************************

! Include files

include "precision.f90"
include "userinputs.f90"
include "common_block.f90"
include "utilities.f90"
include "C3D8_element.f90"

!***********************************************************************

subroutine UEXTERNALDB(lop,lrestart,time,dtime,kstep,kinc)
    use precision
    use common_block
    use iso_module
    use iso_c_binding

    include 'aba_param.inc' 

    dimension time(2)
    
    integer :: iostat, element_ID, node_id, current_element_idx
    integer, dimension(nnode + 1) :: values

    character(len=256) :: line, outdir, aelread, aelwrite, andread, andwrite, anelwrite
    
    real(kind=dp) :: xi_node, eta_node, zeta_node, xi_int, eta_int, zeta_int, &
                     xi_int_corner, eta_int_corner, zeta_int_corner
    real(kind=dp), dimension(ninpt) :: N_inpt_to_local_knode
    real(kind=dp), dimension(nnode) :: N_node_to_local_kinpt
    real(kind=dp), dimension(ndim, nnode) :: N_grad_node_to_local_kinpt
    real(kind=dp), dimension(ndim, nnode) :: N_grad_node_to_local_knode
    
    real(kind=dp), dimension(ndim,ndim) :: xjac
    real(kind=dp), dimension(nnode) :: x_nodes_current_elem, y_nodes_current_elem, z_nodes_current_elem
    real(kind=dp) :: djac

    ! lop = 0 indicates that UEXTERNALDB is called at the start of the analysis
    
    if (lop == 0 .or. lop == 4) then

        ! Ensuring that only one thread is accessing the shared memory
        
        do klock = 1, 40
            call mutexInit(klock)
        end do
        
        call mutexLock(1)

        ! ========================================================
        ! Initialize all common matrixes as zeros
        ! ========================================================

        sig_H_all_elems_at_inpts = 0.0d0
        sig_H_all_elems_at_nodes = 0.0d0
        sig_H_at_nodes = 0.0d0
        sig_H_grad_all_elems_at_inpts = 0.0d0
        coords_all_inpts = 0.0d0
        coords_all_nodes = 0.0d0
        djac_all_elems_at_nodes = 0.0d0

        ! ========================================================
        ! BUILDING THE CONNECTIVITY MATRIX
        ! elems_to_nodes_matrix: (total_elems, nnode)
        ! nodes_to_elems_matrix: (total_nodes, nmax_elems, 2)
        ! ========================================================

        ! BEWARE: Make sure that the mesh txt file must not have any empty lines at the end

        call getoutdir(outdir, lenoutdir)
        aelread = trim(outdir) // '/processing_input/elements.inc'
        
        open(unit=10, file=aelread, status="old", action="read")

        ! Read once to skip the first line in the elements.inc file
        read(10, '(A)', iostat=iostat) line

        ! Read the file line by line and populate the nodes_to_elems_matrix
        do line_idx = 1, total_elems

            read(10, '(A)', iostat=iostat) line

            ! Convert commas to spaces
            do i = 1, len(line)
                if (line(i:i) == ',') line(i:i) = ' '
            end do

            ! Convert the line into integers
            read(line, *) values  ! Read the 9 values (element ID and 8 nodes)

            ! values(1) is element ID of C3D8 element
            ! values(2:nnode+1) are the node ID of the C3D8 element

            ! Populate the elems_to_nodes_matrix

            do knode = 2, nnode + 1 ! Looping over the 8 nodes
                element_ID = values(1)
                node_ID = values(knode)
                elems_to_nodes_matrix(element_ID, knode-1) = node_ID
            end do
        end do

        ! Close the file
        close(10)

        ! call pause(180)

        open(unit=10, file=aelread, status="old", action="read")

        ! Read once to skip the first line in the elements.inc file
        read(10, '(A)', iostat=iostat) line

        ! Initialize nodes_to_elems_matrix with 0 to indicate unused slots
        nodes_to_elems_matrix = 0
        num_elems_of_nodes_matrix = 0

        ! Read the file line by line and populate the nodes_to_elems_matrix
        do line_idx = 1, total_elems
        
            read(10, '(A)', iostat=iostat) line

            ! Convert commas to spaces
            do i = 1, len(line)
                if (line(i:i) == ',') line(i:i) = ' '
            end do

            ! Convert the line into integers
            read(line, *) values  ! Read the 9 values (element ID and 8 nodes)

            ! values(1) is element ID of C3D8 element
            ! values(2:nnode+1) are the node ID of the C3D8 element
            
            ! Populating the nodes_to_elems_matrix

            element_ID = values(1)
                
            ! Loop over each node in the current element
            do knode = 1, nnode  ! nnode is the number of nodes per element
                node_ID = elems_to_nodes_matrix(element_ID, knode)  ! Get the global node number

                num_elems_of_nodes_matrix(node_ID) = num_elems_of_nodes_matrix(node_ID) + 1
                kelem = num_elems_of_nodes_matrix(node_ID)  ! Get the current index for element containing this node

                ! Store the element ID and local node number in nodes_to_elems_matrix
                nodes_to_elems_matrix(node_ID, kelem, 1) = element_ID  ! Store the element ID
                nodes_to_elems_matrix(node_ID, kelem, 2) = knode  ! Store the local node number
            end do  ! End loop over nodes in the element

        end do

        ! Close the file
        close(10)

        ! ! Optional: print part of the matrix to verify
        ! do i = 10000, 10050  ! Print first 10 nodes for checking
        !     print *, 'Node', i, ': ', nodes_to_elems_matrix(i, 1:8, 1:2)
        !     print *, 'Number of elements: ', num_elems_of_nodes_matrix(i)
        ! end do

        ! call pause(180)

        ! ========================================================
        ! CALCULATING SHAPE FUNCTIONS AND THE SHAPE FUNCTION GRADIENT
        ! W.R.T LOCAL COORDINATES. THESE VALUES NEVER CHANGE DURING THE ANALYSIS
        ! all_N_inpt_to_local_knode: (nnode, ninpt)
        ! all_N_node_to_local_kinpt: (ninpt, nnode)
        ! all_N_grad_node_to_local_kinpt: (ninpt, ndim, nnode)
        ! ========================================================

        do knode = 1, nnode
            xi_node = xi_nodal_extra(knode)
            eta_node = eta_nodal_extra(knode)
            zeta_node = zeta_nodal_extra(knode)

            call calc_N_inpt_to_local_coords(xi_node, eta_node, zeta_node, N_inpt_to_local_knode)
            all_N_inpt_to_local_knode(knode, 1:ninpt) = N_inpt_to_local_knode
            !print *, 'N_inpt_to_local_knode: ', N_inpt_to_local_knode
        end do      

        do kinpt = 1, ninpt

            xi_int = xi_int_inter(kinpt)
            eta_int = eta_int_inter(kinpt)
            zeta_int = zeta_int_inter(kinpt)

            xi_int_corner = xi_int_extra(kinpt)
            eta_int_corner = eta_int_extra(kinpt)
            zeta_int_corner = zeta_int_extra(kinpt)

            call calc_N_node_to_local_coords(xi_int, eta_int, zeta_int, N_node_to_local_kinpt)
            all_N_node_to_local_kinpt(kinpt, 1:nnode) = N_node_to_local_kinpt(1:nnode)

            call calc_N_grad_node_to_local_coords(xi_int, eta_int, zeta_int, N_grad_node_to_local_kinpt)
            all_N_grad_node_to_local_kinpt(kinpt,1:ndim,1:nnode) = N_grad_node_to_local_kinpt(1:ndim,1:nnode)

        end do

        ! Populating the 4 matrices
        ! Populating the delta_tensor
        delta_tensor = 0.0d0
        do i = 1, ndim
            delta_tensor(i, i) = 1.0d0
        end do
        
        ! Populating the isotropic_tensor
        isotropic_tensor = 0.0d0
        do i = 1, ndim
            isotropic_tensor(i, i) = 1.0d0
        end do
        do i = ndim+1, ntensor
            isotropic_tensor(i, i) = 0.5d0
        end do

        ! Populating the hydrostatic_tensor
        hydrostatic_tensor = 0.0d0
        do i = 1, ndim
            do j = 1, ndim
                hydrostatic_tensor(i, j) = 1.0d0 / 3.0d0
            end do
        end do

        ! Populating the deviatoric_tensor
        deviatoric_tensor = 0.0d0
        do i = 1, ndim
            do j = 1, ndim
                deviatoric_tensor(i, j) = isotropic_tensor(i, j) - hydrostatic_tensor(i, j)
            end do
        end do

        ! Releasing the lock
        call mutexUnlock(1)

    end if

    ! lop = 2 indicates that UEXTERNALDB is called at the end of the current analysis increment
    
    if (lop == 2) then 

        call mutexLock(2)
        
        ! ========================================================
        ! Populating sig_H_all_elems_at_nodes(total_elems, nnode)
        ! by using N_inpt_to_local_knode to extrapolate from IPs to nodes
        ! ========================================================

        !print *, 'Populating sig_H_all_elems_at_nodes'

        do element_ID = 1, total_elems
            ! Loop over each node in the current element
            do knode = 1, nnode
                ! Initialize hydrostatic stress for the current node to zero
                sig_H_all_elems_at_nodes(element_ID, knode) = 0.0d0

                ! Compute the hydrostatic stress at the nodal point by summing the products
                do kinpt = 1, ninpt
                    sig_H_all_elems_at_nodes(element_ID, knode) = sig_H_all_elems_at_nodes(element_ID, knode) &
                        + all_N_inpt_to_local_knode(knode, kinpt) * sig_H_all_elems_at_inpts(element_ID, kinpt)
                end do
            end do
        end do

        ! ========================================================
        ! Populating djac_all_elems_at_nodes(total_elems, nnode)
        ! ========================================================

        !print *, 'Populating djac_all_elems_at_nodes'

        do element_ID = 1, total_elems
            
            do knode = 1,nnode
                !   Retrieve the node_ID of the current node in this element
                node_ID = elems_to_nodes_matrix(element_ID,knode)
                x_nodes_current_elem(knode) = coords_all_nodes(node_ID,1)
                y_nodes_current_elem(knode) = coords_all_nodes(node_ID,2)
                z_nodes_current_elem(knode) = coords_all_nodes(node_ID,3)
            end do

            ! Loop over each node in the current element
            do knode = 1, nnode

                ! Natural coordinates at the current node
                xi_node = xi_nodal_inter(knode)
                eta_node = eta_nodal_inter(knode)
                zeta_node = zeta_nodal_inter(knode)

                ! Calculate derivatives of shape function of nodal points 
                ! with respect to natural coordinates of themselves
                call calc_N_grad_node_to_local_coords(xi_node, eta_node, zeta_node, &
                                                      N_grad_node_to_local_knode)

                ! Initialize Jacobian matrix xjac to zero
                xjac = 0.0d0

                ! Calculate Jacobian matrix xjac at the current node
                do knode_inner = 1, nnode
                    xjac(1, 1) = xjac(1, 1) + N_grad_node_to_local_knode(1, knode_inner) * x_nodes_current_elem(knode_inner)
                    xjac(1, 2) = xjac(1, 2) + N_grad_node_to_local_knode(1, knode_inner) * y_nodes_current_elem(knode_inner)
                    xjac(1, 3) = xjac(1, 3) + N_grad_node_to_local_knode(1, knode_inner) * z_nodes_current_elem(knode_inner)
                    xjac(2, 1) = xjac(2, 1) + N_grad_node_to_local_knode(2, knode_inner) * x_nodes_current_elem(knode_inner)
                    xjac(2, 2) = xjac(2, 2) + N_grad_node_to_local_knode(2, knode_inner) * y_nodes_current_elem(knode_inner)
                    xjac(2, 3) = xjac(2, 3) + N_grad_node_to_local_knode(2, knode_inner) * z_nodes_current_elem(knode_inner)
                    xjac(3, 1) = xjac(3, 1) + N_grad_node_to_local_knode(3, knode_inner) * x_nodes_current_elem(knode_inner)
                    xjac(3, 2) = xjac(3, 2) + N_grad_node_to_local_knode(3, knode_inner) * y_nodes_current_elem(knode_inner)
                    xjac(3, 3) = xjac(3, 3) + N_grad_node_to_local_knode(3, knode_inner) * z_nodes_current_elem(knode_inner)
                end do

                ! Compute determinant of Jacobian matrix
                djac = xjac(1, 1) * (xjac(2, 2) * xjac(3, 3) - xjac(3, 2) * xjac(2, 3)) &
                     - xjac(1, 2) * (xjac(2, 1) * xjac(3, 3) - xjac(3, 1) * xjac(2, 3)) &
                     + xjac(1, 3) * (xjac(2, 1) * xjac(3, 2) - xjac(3, 1) * xjac(2, 2))

                ! Store djac for the current node in the element
                djac_all_elems_at_nodes(element_ID, knode) = djac
            end do
        end do

        !call pause(180)

        ! ========================================================
        ! Populating sig_H_at_nodes(total_nodes)
        ! Weighted average based on determinant of Jacobian
        ! ========================================================

        ! Initialize sig_H_at_nodes to zero
        sig_H_at_nodes = 0.0d0

        ! Loop over all nodes in the mesh
        do node_ID = 1, total_nodes
            num_elems_containing_node = num_elems_of_nodes_matrix(node_ID)

            !print *, 'Node ID: ', node_ID, 'Number of elements: ', num_elems_containing_node
            ! Initialize temporary variables for summing sig_H and djac
            sum_sig_H_djac = 0.0d0
            sum_djac = 0.0d0

            ! Loop over all elements that contain the current node
            do kelem = 1, num_elems_containing_node
                ! Get the element ID and local node number for this node
                element_ID = nodes_to_elems_matrix(node_ID, kelem, 1)
                local_knode = nodes_to_elems_matrix(node_ID, kelem, 2)

                ! Retrieve sig_H for the current element and node
                sig_H_knode = sig_H_all_elems_at_nodes(element_ID, local_knode)

                ! Retrieve djac for the current element and node
                djac_knode = djac_all_elems_at_nodes(element_ID, local_knode)

                ! Accumulate the weighted sum of sig_H and the sum of djac
                sum_sig_H_djac = sum_sig_H_djac + sig_H_knode * djac_knode
                sum_djac = sum_djac + djac_knode
            end do

            ! Compute the weighted average of sig_H for the current node
            if (sum_djac > 0.d0) then
                sig_H_at_nodes(node_ID) = sum_sig_H_djac / sum_djac
            else
                sig_H_at_nodes(node_ID) = 0.d0
            end if

        end do
        
        call mutexUnlock(2)
        
    end if

return
end


subroutine USDFLD(field,statev,pnewdt,direct,t,celent, &
    time,dtime,cmname,orname,nfield,nstatv,noel,npt,layer, &
    kspt,kstep,kinc,ndi,nshr,coord,jmac,jmatyp,matlayo,laccfla)
    
    use precision
    use common_block
    include 'aba_param.inc'

    character*80 cmname,orname
    character*3  flgray(15)
    dimension field(nfield),statev(nstatv),direct(3,3), &
              t(3,3),time(2)
    dimension array(100),jarray(100),jmac(*),jmatyp(*),coord(*)

    ! print *, 'USDFLD: noel = ', noel, 'npt = ', npt, 'kinc = ', kinc

    !     the dimensions of the variables array and jarray
    !     must be set equal to or greater than 15.
    !     Number 100 is arbitrary, which can accomodate lots of SDV

    ! user coding to define field and, if necessary, statev and pnewdt

    ! Example of how to use usdfld (not related to HE)
    ! ! absolute value of current strain:
    ! call GETVRM('LE',array,jarray,flgray,jrcd,jmac,jmatyp,matlayo,laccfla)
    ! eps = abs( array(1) )
    ! ! maximum value of strain up to this point in time:
    ! call GETVRM('SDV',array,jarray,flgray,jrcd,jmac,jmatyp,matlayo,laccfla)
    ! epsmax = array(1)
    ! ! use the maximum strain as a field variable
    ! field(1) = max(eps, epsmax)
    ! ! store the maximum strain as a SDV
    ! statev(1) = field(1)

    !  Compute the gradient of the hydrostatic stress  

    if (time(1) > 0) then
        call calc_sig_H_grad_all_elems_at_inpts(noel, npt, kinc)
    end if 

return
end

! *****************************************************************
! UFIELD reads current nodal coordinates for all NPs
! *****************************************************************

subroutine UFIELD(field, kfield, nsecpt, kstep, kinc, time, node, &
                  coords, temp, dtemp, nfield)
    use precision
    use common_block
    include 'aba_param.inc'
   
    dimension field(nsecpt,nfield), time(2), coords(3), &
              temp(nsecpt), dtemp(nsecpt)

    ! print *, 'UFIELD: node = ', node, 'coords = ', coords

    ! IMPORTANT: coords in this subroutine is NP coordinates, not IP coordinates
    ! like the one in UMAT and UMATHT

    ! Lock Mutex #5 to ensure safe writing to shared memory
    !call mutexInit(5)
    call mutexLock(5)

    ! Assign the current nodal coordinates to coords_all_nodes
    coords_all_nodes(node, 1) = coords(1)
    coords_all_nodes(node, 2) = coords(2)
    coords_all_nodes(node, 3) = coords(3)

    ! Unlock Mutex #5
    call mutexUnlock(5)

return
end



subroutine calc_sig_H_grad_all_elems_at_inpts(noel, kinpt, kinc)

    use precision
    use iso_module
    use common_block

    integer :: noel, kinc, jelem, knode, kinpt, node_ID, idim, jdim
    real(kind=dp), dimension(nnode) :: N_node_to_local_kinpt, sig_H_noel_at_nodes
    real(kind=dp), dimension(ndim,nnode) :: N_grad_node_to_local_kinpt, N_grad_node_to_global_kinpt
    real(kind=dp), dimension(ndim,ndim) :: xjac, xjac_inv
    real(kind=dp), dimension(ndim) :: sig_H_grad_noel_at_kinpt

    ! Extract the hydrostatic stress at nodal points
    ! which is extrapolated from the integration points in UEXTERNALDB

    ! Professor Aravas approach
    do knode = 1, nnode
        node_ID = elems_to_nodes_matrix(noel, knode)
        sig_H_noel_at_nodes(knode) = sig_H_at_nodes(node_ID)
    end do
            
    N_node_to_local_kinpt = all_N_node_to_local_kinpt(kinpt, 1:nnode)

    N_grad_node_to_local_kinpt = all_N_grad_node_to_local_kinpt(kinpt, 1:ndim, 1:nnode)

    xjac = 0.d0

!   Compute the Jacobian matrix (xjac)
    do knode = 1, nnode
        do idim = 1, ndim
            do jdim = 1, ndim
                node_ID = elems_to_nodes_matrix(noel, knode)
                xjac(jdim, idim) = xjac(jdim, idim) + &
                    N_grad_node_to_local_kinpt(jdim, knode) * &
                        coords_all_nodes(node_ID, idim)
            end do  
        end do
    end do

    !   Calculate the determinant of the Jacobian matrix (djac)
    djac =  xjac(1,1)*xjac(2,2)*xjac(3,3)+xjac(2,1)*xjac(3,2)*xjac(1,3) &
            + xjac(3,1)*xjac(2,3)*xjac(1,2)-xjac(3,1)*xjac(2,2)*xjac(1,3) &
            - xjac(2,1)*xjac(1,2)*xjac(3,3)-xjac(1,1)*xjac(2,3)*xjac(3,2)
    
    xjac_inv(1,1)=(xjac(2,2)*xjac(3,3)-xjac(2,3)*xjac(3,2))/djac
    xjac_inv(1,2)=(xjac(1,3)*xjac(3,2)-xjac(1,2)*xjac(3,3))/djac
    xjac_inv(1,3)=(xjac(1,2)*xjac(2,3)-xjac(1,3)*xjac(2,2))/djac
    xjac_inv(2,1)=(xjac(2,3)*xjac(3,1)-xjac(2,1)*xjac(3,3))/djac
    xjac_inv(2,2)=(xjac(1,1)*xjac(3,3)-xjac(1,3)*xjac(3,1))/djac
    xjac_inv(2,3)=(xjac(1,3)*xjac(2,1)-xjac(1,1)*xjac(2,3))/djac
    xjac_inv(3,1)=(xjac(2,1)*xjac(3,2)-xjac(2,2)*xjac(3,1))/djac
    xjac_inv(3,2)=(xjac(1,2)*xjac(3,1)-xjac(1,1)*xjac(3,2))/djac
    xjac_inv(3,3)=(xjac(1,1)*xjac(2,2)-xjac(1,2)*xjac(2,1))/djac
    
    if (djac < 0.d0) then ! negative or zero jacobian
        write(7,*) 'WARNING: element', jelem, 'has neg. Jacobian'
    endif

!   Compute the derivatives of shape functions with respect to global coordinates (B_deriv_global)
    N_grad_node_to_global_kinpt = matmul(xjac_inv, N_grad_node_to_local_kinpt)

    sig_H_grad_noel_at_kinpt = matmul(N_grad_node_to_global_kinpt, sig_H_noel_at_nodes) ! shape (3, 8) * shape (8) = shape (3)

    sig_H_grad_all_elems_at_inpts(noel, kinpt, :) = sig_H_grad_noel_at_kinpt

return
end

! This is isotropic von Mises plasticity model
! Note: flow curve in the props should appear at the end of props. 
! If there is any non flow curve props behind the flow curve, you must move
! it before_flow_props_idx index in the props array.

!***********************************************************************

subroutine UMAT(stress,statev,ddsdde,sse,spd,scd,rpl,ddsddt, &
    drplde,drpldt,stran,dstran,time,dtime,temp2,dtemp,predef,dpred, &
    cmname,ndi,nshr,ntens,nstatv,props,nprops,coords,drot,pnewdt, &
    celent,dfgrd0,dfgrd1,noel,npt,layer,kspt,jstep,kinc)

    use precision
    use common_block
    !use ieee_arithmetic
    include 'aba_param.inc' 

    character*8 cmname
    dimension stress(ntens),statev(nstatv),ddsdde(ntens,ntens), &
        ddsddt(ntens),drplde(ntens),stran(ntens),dstran(ntens), &
        time(2),predef(1),dpred(1),props(nprops),coords(3),drot(3,3), &
        dfgrd0(3,3),dfgrd1(3,3),jstep(4)
    
    real(kind=dp) :: E, nu, lambda, mu, eqplas, deqplas, rhs 
    real(kind=dp) :: syield, syiel0, sig_vonMises, sig_H, sig_P1, sig_P2, sig_P3, sig_Tresca
    real(kind=dp) :: effective_mu, effective_lambda, effective_hard    

    real(kind=dp) :: eelas(ntens), eplas(ntens), flow(ntens), stress_copy(ntens)
    real(kind=dp) :: hard(3), old_stress(ntens), old_eplas(ntens)
    real(kind=dp) :: sig_principal_unsorted(ndim), sig_principal_sorted(ndim)
    real(kind=dp) :: sig_principal_dir(ndim, ndim)
    real(kind=dp) :: invariant_p, invariant_q, invariant_r, triaxiality, lode_norm
    real(kind=dp) :: sig_principal_1, sig_principal_2, sig_principal_3
    real(kind=dp), parameter :: toler = 1e-12
    real(kind=dp), parameter :: newton = 100
    integer :: k_newton

    ! LOCAL ARRAYS
    ! ----------------------------------------------------------------
    ! EELAS - ELASTIC STRAINS
    ! EPLAS - PLASTIC STRAINS
    ! FLOW - DIRECTION OF PLASTIC FLOW
    ! ----------------------------------------------------------------
    
    ! ----------------------------------------------------------------
    ! UMAT FOR ISOTROPIC ELASTICITY AND ISOTROPIC MISES PLASTICITY
    ! CANNOT BE USED FOR PLANE STRESS
    ! ----------------------------------------------------------------
    ! PROPS(before_mech_props_idx+1) - E
    ! PROPS(before_mech_props_idx+2) - NU
    ! PROPS(before_flow_props_idx+1:nprops) - SYIELD AN HARDENING DATA
    ! props(before_flow_props_idx+1) - syiel0, 
    ! props(before_flow_props_idx+2) - eqpl0, 
    ! props(before_flow_props_idx+3) - syiel1, 
    ! props(before_flow_props_idx+4) - eqpl1, ...
    ! and props(nprops-1) - syield_N, props(nprops) - eqplas_N
    ! CALLS UHARD FOR CURVE OF YIELD STRESS VS. PLASTIC STRAIN
    ! ----------------------------------------------------------------

    ! material properties

    ! print *, 'UMAT: noel = ', noel, 'npt = ', npt, 'kinc = ', kinc

    sfd = props(1)         ! Scaling factor
    E = props(2)           ! Young's modulus 
    nu = props(3)          ! Poisson's ratio 
    
    ! print *, 'E = ', E
    ! print *, 'nu = ', nu
    !eelas(1:ntens) = statev(eelas_start_idx:eelas_end_idx)
    !eplas(1:ntens) = statev(eplas_start_idx:eplas_end_idx)
    eqplas = statev(eqplas_idx)
    deqplas = 0.0d0
    old_stress = stress
    old_eplas = eplas

    call rotsig(statev(eelas_start_idx), drot, eelas, 2, ndi, nshr)
    call rotsig(statev(eplas_start_idx), drot, eplas, 2, ndi, nshr)

    ! Lame's parameters
    mu = E/(2.0d0 * (1.0d0 + nu))  ! Shear modulus
    lambda = E*nu/((1.0d0 + nu) * (1.0d0 - 2.0d0 * nu)) ! Lame's first constant


    ! initialize as 0
    ddsdde = 0.0d0 ! Their unit is Pa
    
    do i = 1, ndi
        do j = 1, ndi
            ddsdde(j, i) = lambda
        end do 
        ddsdde(i,i) = lambda + 2.0d0 * mu
    end do 

    ! Shear contribution
    do i = ndi + 1, ntens
        ddsdde(i,i) = mu
    end do 

    !    Calculate predictor stress and elastic strain
    stress = stress + matmul(ddsdde,dstran)

    eelas = eelas + dstran

    ! Calculate equivalent von Mises stress
    
    sig_vonMises = (stress(1) - stress(2))**2.0d0 + &
                   (stress(2) - stress(3))**2.0d0 + &
                   (stress(3) - stress(1))**2.0d0 + &
                    6.0d0 * (stress(4)**2.0d0 + stress(5)**2.0d0 + stress(6)**2.0d0)

    sig_vonMises = sqrt(sig_vonMises/2.0d0)
    
    ! get yield stress from the specified hardening curve
    ! nvalue equal to number of points on the hardening curve
    
    nvalue = (nprops - before_flow_props_idx) / 2

    ! print *, 'nvalue = ', nvalue ! 100
    ! print *, 'before_flow_props_idx = ', before_flow_props_idx ! 40
    
    call UHARD(syiel0, hard, eqplas, &
                                statev, nvalue, props(before_flow_props_idx + 1))
    

    ! Determine if active yielding

    if (sig_vonMises > (1.0d0 + toler) * syiel0) then

        ! actively yielding
        ! separate the hydrostatic from the deviatoric stress
        ! calculate the flow direction

        sig_H = (stress(1) + stress(2) + stress(3))/3.0d0
        flow(1:ndi) = (stress(1:ndi) - sig_H)/sig_vonMises
        flow(ndi+1:ntens) = stress(ndi+1:ntens)/sig_vonMises
        
        ! solve for equivalent von Mises stress and equivalent plastic strain increment 
        ! using Newton-Raphson iteration

        syield = syiel0
        deqplas = 0.0d0
        do k_newton = 1, newton
            rhs = sig_vonMises - (3.0d0 * mu * deqplas) - syield
            deqplas = deqplas + rhs / ((3.0d0 * mu) + hard(1))

            call UHARD(syield, hard, eqplas + deqplas, &
                        statev, nvalue, props(before_flow_props_idx + 1))
                                
            if (abs(rhs) < toler * syiel0) exit
        end do

        if (k_newton == newton) write(7,*) 'WARNING: plasticity loop failed'

        ! Update stresses, elastic and plastic strains
 
        stress(1:ndi) = flow(1:ndi) * syield + sig_H
        eplas(1:ndi) = eplas(1:ndi) + 3.0d0/2.0d0 * flow(1:ndi) * deqplas
        eelas(1:ndi) = eelas(1:ndi) - 3.0d0/2.0d0 * flow(1:ndi) * deqplas
        
        stress(ndi + 1:ntens) = flow(ndi + 1:ntens) * syield
        eplas(ndi + 1:ntens) = eplas(ndi + 1:ntens) + 3.0d0 * flow(ndi + 1:ntens) * deqplas
        eelas(ndi + 1:ntens) = eelas(ndi + 1:ntens) - 3.0d0 * flow(ndi + 1:ntens) * deqplas

        ! Finally, we update the equivalent plastic strain
        eqplas = eqplas + deqplas

        ! Calculate the plastic strain energy density
        ! psi_plas = deqplas * (syiel0 + syield) / 2.d0

        do i=1,ntens
            spd = spd + (stress(i)+old_stress(i)) * (eplas(i) - old_eplas(i))/2.0d0
        end do

        ! Formulate the jacobian (material tangent)   

        ! effective shear modulus
        effective_mu = mu * syield / sig_vonMises 

        ! effective Lame's constant
        effective_lambda = (E/(1.0d0 - 2.0d0 * nu) - 2.0d0 * effective_mu)/3.0d0 

        ! effective hardening modulus
        effective_hard = 3.0d0 * mu * hard(1)/(3.0d0 * mu + hard(1)) - 3.0d0 * effective_mu 

        do i = 1, ndi
            do j = 1, ndi
                ddsdde(j,i) = effective_lambda
            end do
            ddsdde(i,i) = 2.0d0 * effective_mu + effective_lambda
        end do

        do i = ndi + 1, ntens
            ddsdde(i,i) = effective_mu
        end do

        do i = 1, ntens
            do j = 1, ntens
                ddsdde(j,i) = ddsdde(j,i) + effective_hard * flow(j) * flow(i)
            end do
        end do
    endif

    ! Recalculate the stress
    sig_vonMises = (stress(1) - stress(2))**2.0d0 + &
                   (stress(2) - stress(3))**2.0d0 + &
                   (stress(3) - stress(1))**2.0d0 + &
                    6.0d0 * (stress(4)**2.0d0 + stress(5)**2.0d0 + stress(6)**2.0d0)

    sig_vonMises = sqrt(sig_vonMises/2.0d0)

    sig_H = (stress(1) + stress(2) + stress(3))/3.0d0

    call calc_stress_invariants(stress, ntens, invariant_p, invariant_q, invariant_r)
    call calc_triaxiality(invariant_p, invariant_q, triaxiality)
    call calc_normalized_lode(invariant_r, invariant_q, lode_norm)
    
    ! Abaqus library function to calculate principal stresses

    call sprind(stress_copy,sig_principal_unsorted,sig_principal_dir,1,ndi,nshr)
    call sort_descending(sig_principal_unsorted, sig_principal_sorted, ndim)

    sig_P1 = sig_principal_sorted(1)
    sig_P2 = sig_principal_sorted(2)
    sig_P3 = sig_principal_sorted(3)

    sig_Tresca = (sig_P1 - sig_P3)/2.0d0

    ! Update coords at integration points

    coords_all_inpts(noel, npt, 1) = coords(1)
    coords_all_inpts(noel, npt, 2) = coords(2)
    coords_all_inpts(noel, npt, 3) = coords(3)

    ! update state variables
    
    statev(sig_start_idx:sig_end_idx) = stress(1:ntens)
    statev(stran_start_idx:stran_end_idx) = stran(1:ntens)
    statev(eelas_start_idx:eelas_end_idx) = eelas(1:ntens)
    statev(eplas_start_idx:eplas_end_idx) = eplas(1:ntens)
    statev(eqplas_idx) = eqplas
    statev(deqplas_idx) = deqplas
    statev(sig_H_idx) = sig_H
    statev(sig_vonMises_idx) = sig_vonMises
    statev(sig_Tresca_idx) = sig_Tresca
    statev(sig_P1_idx) = sig_P1
    statev(sig_P2_idx) = sig_P2
    statev(sig_P3_idx) = sig_P3
    statev(triax_idx) = triaxiality
    statev(lode_idx) = lode_norm

    ! Update the sig_H_all_elems_at_inpts
    sig_H_all_elems_at_inpts(noel, npt) = sig_H

return
end

!***********************************************************************

subroutine UHARD(syield, hard, eqplas, statev, nvalue, table)

    use precision
    include 'aba_param.inc'

    character*80 cmname
    dimension hard(3),statev(*),table(2, nvalue)
    
    ! set yield stress to last value of table, hardening to zero
    
    syield = table(1, nvalue)
    hard(1) = 0.d0

    ! if more than one entry, search table
    
    if (nvalue > 1) then
        do k1 = 1, nvalue - 1
            eqpl1 = table(2, k1 + 1)
            if (eqplas < eqpl1) then
                eqpl0 = table(2, k1)
                if (eqpl1 <= eqpl0) then
                    write(7,*) 'error - plastic strain must be entered in ascending order'
                end if

                ! current yield stress and hardening

                deqpl = eqpl1 - eqpl0
                syiel0 = table(1, k1)
                syiel1 = table(1, k1 + 1)
                dsyiel = syiel1 - syiel0
                hard(1) = dsyiel/deqpl
                syield = syiel0 + (eqplas - eqpl0) * hard(1)
                exit
            endif
        end do
    endif

return
end


!***********************************************************************

subroutine UMATHT(u,dudt,dudg,flux,dfdt,dfdg, &
    statev,temp,dtemp,dtemdx,time,dtime,predef,dpred, &
    cmname,ntgrd,nstatv,props,nprops,coords,pnewdt, &
    noel,npt,layer,kspt,kstep,kinc)

    use precision
    use common_block
    inCLude 'aba_param.inc'

    character(len=80) :: cmname
    dimension dudg(ntgrd),flux(ntgrd),dfdt(ntgrd), &
      dfdg(ntgrd,ntgrd),statev(nstatv),dtemdx(ntgrd), &
      time(2),predef(1),dpred(1),props(nprops),coords(3)
    
    ! This subroutine requires us to update u, dudt, dudg, flux, dfdt, dfdg, and possibly statev, pnewdt
    
    
    ! Define all real for all variables used 
    real(kind=dp) :: R, T, VH, DL, DL0, WB_L, sfd
    real(kind=dp) :: avogadro, NL, alpha_dis, alpha_gb, alpha_carb, NT_dis, NT_gb, NT_carb
    real(kind=dp) :: WB_dis, WB_gb, WB_carb, beta_BCC, beta_FCC, a_lattice_BCC, a_lattice_FCC
    real(kind=dp) :: gamma, rho_d0, theta_coverage, k_HEDE
    real(kind=dp) :: CL_mol_old, dCL_mol, CL_mol, CL, K_dis, K_gb, K_carb
    real(kind=dp) :: burgers_vector, inverse_burgers_vector, beta, NL_mol
    real(kind=dp) :: thetaL, temp_dis, thetaT_dis, temp_gb, thetaT_gb, temp_carb, thetaT_carb
    real(kind=dp) :: eqplas, rho_d, NT_dis_mol, CT_dis, CT_dis_mol
    real(kind=dp) :: dC_mol_dNT_dis_mol, dNT_dis_deqplas
    real(kind=dp) :: part_CT_dis_mol_part_CL_mol, part_CT_gb_mol_part_CL_mol, part_CT_carb_mol_part_CL_mol
    real(kind=dp) :: total_dCT_mol_dCL_mol, dC_mol_dCL_mol, deqplas
    real(kind=dp) :: C_mol, CT_mol, CT_gb, CT_gb_mol, CT_carb, CT_carb_mol
    real(kind=dp), allocatable :: alpha_array(:), NT_array(:), WB_T_array(:), K_array(:), thetaT_array(:)
    integer :: ntrap, equilibrium_equation, dis_trap_mode, temperature_mode, coefficient_formula, crystal_structure
    
    sfd = props(1) ! Scaling factor to prevent "zero heat flux" numerical issues. Default is 1.0d0
    crystal_structure = props(2)  ! (1 - BCC, 2 - FCC)
    a_lattice_BCC = props(3)  ! Lattice parameter for BCC (m)
    a_lattice_FCC = props(4)  ! Lattice parameter for FCC (m)
    beta_BCC = props(5)  ! Number of hydrogen atoms in each BCC lattice site (dimless)
    beta_FCC = props(6)  ! Number of hydrogen atoms in each FCC lattice site (dimless)
    R = props(7)  ! Universal gas constant (N*m)/(mol*K)
    temperature_mode = props(8)  ! (1 - constant | 2 - predefined field)
    T = props(9)  ! Temperature (K)
    VH = props(10)  ! Partial molar volume (m^3/mol)
    coefficient_formula = props(11)  ! (1 - using DL directly | 2 - using DL = DL0 * exp(-WB_L/RT))
    DL = props(12)  ! Diffusion coefficient (m^2/s)
    DL0 = props(13)  ! Pre-exponentiation factor for diffusion coefficient (m^2/s)
    WB_L = props(14)  ! Activation energy for jumping between lattice sites (N*m/mol)
    NL = props(15)  ! Number of solvent metal atoms per unit volume (1/m^3)
    avogadro = props(16)  ! Avogadro’s constant (1/mol)
    delta_g_b0 = props(17)  ! Gibbs free energy difference (N*m/mol)
    ntrap = props(18)  ! Number of trap types (0 - no traps, 1 - dislocation, 2 - 5 for additional trap types)
                    ! You can have as many traps as you want by defining alpha, NT and WB at the end of the UMATHT props
    equilibrium_equation = props(19)  ! (1 - Oriani's equation | 2 - McNabb-Foster’s equation)
    dis_trap_mode = props(20)  ! (1 - Kumnick & Krom | 2 - Sofronis & Dadfarnia)
    gamma = props(21)  ! Fitting parameter in Dadfarnia et al. (1/m^2)
    rho_d0 = props(22)  ! Dislocation density for annealed material (1/m^2)
    alpha_dis = props(23)  ! Number of interstitial sites per trap site (dislocations)
    WB_dis = props(24)  ! Binding energy of hydrogen to dislocations (N*m/mol)
    trap_start_idx = 25

    ! print *, 'crystal_structure = ', crystal_structure
    ! print *, 'a_lattice_BCC = ', a_lattice_BCC
    ! print *, 'a_lattice_FCC = ', a_lattice_FCC
    ! print *, 'beta_BCC = ', beta_BCC
    ! print *, 'beta_FCC = ', beta_FCC
    ! print *, 'R = ', R
    ! print *, 'temperature_mode = ', temperature_mode
    ! print *, 'T = ', T
    ! print *, 'VH = ', VH
    ! print *, 'coefficient_formula = ', coefficient_formula
    ! print *, 'DL = ', DL
    ! print *, 'DL0 = ', DL0
    ! print *, 'WB_L = ', WB_L
    ! print *, 'NL = ', NL
    ! print *, 'avogadro = ', avogadro
    ! print *, 'delta_g_b0 = ', delta_g_b0
    ! print *, 'ntrap = ', ntrap
    ! print *, 'equilibrium_equation = ', equilibrium_equation
    ! print *, 'dis_trap_mode = ', dis_trap_mode
    ! print *, 'gamma = ', gamma
    ! print *, 'rho_d0 = ', rho_d0
    ! print *, 'alpha_dis = ', alpha_dis
    ! print *, 'WB_dis = ', WB_dis
    ! pause(180)

    

    ! Casting all flags to integer
    crystal_structure = int(crystal_structure)
    temperature_mode = int(temperature_mode)
    coefficient_formula = int(coefficient_formula)
    ntrap = int(ntrap)
    equilibrium_equation = int(equilibrium_equation)
    dis_trap_mode = int(dis_trap_mode)


    ! THE UNIT FOR HYDROGEN CONCENTRATION is mol/m^3
    ! It is marked by the suffix _mol in the variable name
    ! We can convert it to 1/m^3 by multiplying with Avogadro's number, which does not have any suffix
    ! Example: CL_mol = CL / avogadro or CL (1/m^3) = CL_mol (mol/m^3) * avogadro (1/mol)

    CL_mol_old = temp ! (mol/m^3)
    dCL_mol = dtemp ! (mol/m^3)
    CL_mol = CL_mol_old + dCL_mol ! (mol/m^3)

    CL = CL_mol * avogadro ! (1/m^3)

    ! using predefined field for temperature
    if (temperature_mode == 2) then
        T = predef(1) + dpred(1)	  
    end if	  

    ! using the Arrhenius equation for the diffusion coefficient
    if (coefficient_formula == 2) then
        DL = DL0 * dexp(-WB_L / (R * T))
    end if

    ! slip occurs along the plane of the shortest Burgers vector
    if (abs(crystal_structure - 1.0d0) <= crystal_tol) then ! BCC crystal structure
        beta = beta_BCC ! beta is taken to be 6 for BCC as indirect
                        ! evidence indicates tetrahedral site occupancy rather than 
                        ! octahedral site occupancy at room temperature in alpha-iron
        ! slip is assumed to occur along the {110} plane and ⟨111⟩ direction
        burgers_vector = (dsqrt(3.0d0)/2.0d0) * a_lattice_BCC ! (m) 
        inverse_burgers_vector = 1.0d0/burgers_vector ! (1/m)
    elseif (abs(crystal_structure - 2.0d0) <= crystal_tol) then ! FCC crystal structure
        beta = beta_FCC ! beta is taken to be 1 for FCC, resulting from the more favourable 
                        ! octahedral site occupancy (beta = 2 for tetrahedral)
        ! slip occurs along the closed packed plane {111} and slip direction ⟨110⟩
        burgers_vector = (dsqrt(2.0d0)/2.0d0) * a_lattice_FCC ! (m)
        inverse_burgers_vector = 1.0d0/burgers_vector ! (1/m)
    end if

    NL_mol = NL / avogadro ! (mol/m^3) = (1/m^3) / (1/mol)
    thetaL = CL / (beta * NL) ! dimless = (1/m^3) / (dimless * 1/m^3)
    
    ! If ntrap = 0, only lattice H is considered
    ! If ntrap = 1, dislocation trap is always prioritized, using either Kumnick & Krom or Sofronis & Dadfarnia
    ! Other trap types are only considered when ntrap >= 2

    ! For each trap type, we extract alpha, NT, and WB. Then we calculate K and thetaT
    ! thetaT / (1 - thetaT) = K * thetaL / (1 - thetaL)
    ! However if thetaL << 1  then 
    ! thetaT / (1 - thetaT) = K * thetaL

    ! Now handling the trapping parameters as arrays
    allocate(alpha_array(ntrap-1), NT_array(ntrap-1), WB_T_array(ntrap-1), K_array(ntrap-1), thetaT_array(ntrap-1))

    if (ntrap >= 1) then
        K_dis = dexp(-WB_dis / (R * T))  ! Arrhenius reaction rate constant for dislocation trap
        ! Finding theta_trap based on Oriani equilibrium theory
        ! which results in a Fermi-Dirac relation
        temp_dis = K_dis * thetaL / (1.0d0 - thetaL) ! (dimless)
        thetaT_dis = temp_dis / (1.0d0 + temp_dis) ! (dimless)
    end if

    if (ntrap >= 2) then
        ! Remember that fortran array count from 1
        do i = 1, ntrap - 1
            alpha_array(i) = props(trap_start_idx + (i-1) * 3) ! Alpha for trap type i
            NT_array(i) = props(trap_start_idx + (i-1) * 3 + 1)  ! Trap density for trap type i
            WB_T_array(i) = props(trap_start_idx + (i-1) * 3 + 2)  ! Binding energy of hydrogen for trap type i
            ! (dimless) = exp( - (J/mol) / (J/(mol K) * K))
            K_array(i) = dexp(-WB_T_array(i) / (R * T))  ! Arrhenius reaction rate constant for trap type i
            temp_trap = K_array(i) * thetaL / (1.0d0 - thetaL) ! (dimless)
            thetaT_array(i) = temp_trap / (1.0d0 + temp_trap) ! (dimless)
        end do
    end if


    
    eqplas = statev(eqplas_idx) ! (dimless) equivalent plastic strain

    if (ntrap >= 1) then
        if (dis_trap_mode == 1) then ! Krom et al. (in sites/m^3), developed from Kumnick & Johnson 
            NT_dis = 10.d0 ** (23.26d0 - 2.33d0 * dexp(-5.5d0 * eqplas)) 
            dNT_dis_mol_deqplas = (29.5d0 * dexp(-5.5d0 * eqplas) * NT_dis ) / avogadro
        
        elseif (dis_trap_mode == 2) then ! Dadfarnia et al.
            
            if (eqplas < 0.5d0) then
                rho_d = rho_d0 + eqplas * gamma ! rho_d unit is 1/m^2 = 1/m^2 + dimless * 1/m^2
                NT_dis = inverse_burgers_vector * rho_d ! (1/m^3)
                dNT_dis_mol_deqplas = (inverse_burgers_vector * gamma) / avogadro ! mol/m^3 = (1/m * 1/m^2) / (1/mol)
                     
            elseif (eqplas >= 0.5) then
                rho_d = 1.0d16 ! (1/m^2)
                NT_dis = inverse_burgers_vector * rho_d ! (1/m^3)
                dNT_dis_mol_deqplas = 0.0d0
            endif
        end if

        CT_dis = alpha_dis * thetaT_dis * NT_dis ! (1/m^3)
        CT_dis_mol = CT_dis / avogadro ! (mol/m^3)
        ! dimless = dimless * mol/m^3 / (dimless * mol/m^3 + dimless * mol/m^3)
        dC_mol_dNT_dis_mol = (K_dis * CL_mol)/(K_dis * CL_mol + beta * NL_mol) 
        ! du2 in emilio umatht is dC_mol_dNT_dis_mol * dNT_dis_mol_deqplas * deqplas
        
    end if
    
    total_dCT_mol_dCL_mol = 0.0d0
    
    if (ntrap >= 1) then
        NT_dis_mol = NT_dis / avogadro
        part_CT_dis_mol_part_CL_mol = (NT_dis_mol * K_dis * NL_mol * beta)/ &
                                ((K_dis * CL_mol + NL_mol * beta)**2.0d0)
        ! (dimless) = (mol/m^3 * dimless * mol/m^3 * dimless) / ((dimless * mol/m^3 + mol/m^3 * dimless)**2)
        total_dCT_mol_dCL_mol = total_dCT_mol_dCL_mol + &
                                        part_CT_dis_mol_part_CL_mol
    end if
    
    if (ntrap >= 2) then
        do i = 1, ntrap - 1
            NT_i_mol = NT_array(i) / avogadro
            K_i = K_array(i)
            part_CT_i_mol_part_CL_mol = (NT_i_mol * K_i * NL_mol * beta)/ &
                                        ((K_i * CL_mol + NL_mol * beta)**2.0d0)
            total_dCT_mol_dCL_mol = total_dCT_mol_dCL_mol + &
                                        part_CT_i_mol_part_CL_mol
        end do
    end if

    ! Finally, we update all the variables in UMATHT
    ! dC_mol_dCL_mol = part_CL_mol_part_CL_mol + part_CT_mol_part_CL_mol
    !                              = 1 + total_dCT_mol_dCL_mol

    dC_mol_dCL_mol = 1.0d0 + total_dCT_mol_dCL_mol	
    
    ! dC_mol_dCL_mol is dudt
    dudt = dC_mol_dCL_mol
    
    deqplas = statev(deqplas_idx) ! (dimless) equivalent plastic strain increment

    ! (mol/m^3) = (mol/m^3) + (dimless * mol/m^3) + (dimless * mol/m^3 * dimless)
    if (ntrap == 0) then
        u = u + dC_mol_dCL_mol * dCL_mol
    elseif (ntrap >= 1) then
        u = u + dC_mol_dCL_mol * dCL_mol &
            + dC_mol_dNT_dis_mol * dNT_dis_mol_deqplas * deqplas
    end if

    dfdg = 0.0d0

    do kdim = 1, ntgrd
        ! Update the flux
        ! J_m = DL * Cbar_L * grad sigma_H / (R * T) - DL * grad Cbar_L
        grad_CL_mol_kdim = dtemdx(kdim) ! = (mol/m^3) / m = (mol/m^4)

        flux(kdim) = DL * CL_mol * VH * sig_H_grad_all_elems_at_inpts(noel, npt, kdim) / (R * T) &
                - DL * grad_CL_mol_kdim
        
        ! dudg is partial (Cbar_total) / partial (grad Cbar L), which is supposed to be 0
        dudg(kdim) = 0.0d0

        ! partial J_m / partial (Cbar_L) = (DL * VH) / (R * T) * grad_sigma_H(i)
        dfdt(kdim) = (DL * VH * sig_H_grad_all_elems_at_inpts(noel, npt, kdim)) / (R * T) 
        
        ! Update dudg
        dfdg(kdim,kdim) = -DL ! = - m^2/s
    end do

    ! store the concentration in each trap, in all traps and in traps and lattice

    CT_mol = 0.0d0
    
    if (ntrap >= 1) then
        CT_mol = CT_mol + CT_dis_mol
    end if

    if (ntrap >= 2) then
        do i = 1, ntrap - 1
            CT_i = alpha_array(i) * thetaT_array(i) * NT_array(i) ! (1/m^3)
            CT_i_mol = CT_i / avogadro ! (mol/m^3)
            CT_mol = CT_mol + CT_i_mol
        end do
    end if
            
    C_mol = CL_mol + CT_mol

    ! Some unit conversion
    C_molfrac = C_mol * conversion_mol_to_molfrac
    C_wtppm = C_mol * conversion_mol_to_wtppm
    CL_wtppm = CL_mol * conversion_mol_to_wtppm
    CT_wtppm = CT_mol * conversion_mol_to_wtppm

    ! Hydrogen coverage factor (dimless - used in CZM model)
    theta_coverage = C_molfrac / (C_molfrac + exp(-delta_g_b0 /(R * T))) 

    ! Factor decreasing cohesive strength, based on HEDE mechanism
    k_HEDE = 1.0d0 - 1.0467d0 * theta_coverage + 0.1687d0 * theta_coverage ** 2.0d0

    ! Finally, we multiply all variables with the scaling factor sfd
    ! to prevent the error "There is zero heat flux every where"
    u = u * sfd
    dudt = dudt * sfd
    dudg = dudg * sfd
    flux = flux * sfd
    dfdt = dfdt * sfd
    dfdg = dfdg * sfd

    statev(C_mol_idx) = C_mol
    statev(CL_mol_idx) = CL_mol
    statev(CT_mol_idx) = CT_mol
    statev(C_wtppm_idx) = C_wtppm
    statev(CL_wtppm_idx) = CL_wtppm
    statev(CT_wtppm_idx) = CT_wtppm
    statev(theta_coverage_idx) = theta_coverage
    statev(k_HEHE_idx) = k_HEDE
return
end


subroutine UVARM(uvar,direct,t,time,dtime,cmname,orname, &
    nuvarm,noel,npt,layer,kspt,kstep,kinc,ndi,nshr,coord, &
    jmac,jmatyp,matlayo,laccfla)
    
    use precision
    use common_block
    include 'aba_param.inc'
!
    character*80 cmname,orname
    character*3 flgray(1000)
    dimension uvar(nuvarm),direct(3,3),t(3,3),time(2)
    dimension array(1000),jarray(1000),jmac(*),jmatyp(*),coord(*)

    integer :: iostat, element_ID, node_id, current_element_idx
    integer, dimension(11) :: values

    character(len=512) :: line, outdir, aelread, aelwrite, andread, andwrite, anelwrite

    !     the dimensions of the variables flgray, array and jarray
    !     must be set equal to or greater than 15.
    !     Number 1000 is arbitrary, which can accomodate lots of SDV

    ! print *, 'UVARM: noel = ', noel, 'npt = ', npt, 'kinc = ', kinc
    ! call pause(180)
    ! Variables to Be Defined
    ! uvar(nuvarm)
    ! An array containing the user-defined output variables. 
    ! These are passed in as the values at the beginning of the increment 
    ! and must be returned as the values at the end of the increment.
    
    call GETVRM('SDV',array,jarray,flgray,jcrd,jmac,jmatyp,matlayo,laccfla)
    
    ! Choose only a subset of SDV to output
    ! If we output all SDV the odb file would be extremely heavy

    ! Manually define which sdv to be output
    ! Please refer to processing_input/depvar.xlsx for the list of chosen SDV
    
    uvar(1) = array(eqplas_idx) 
    uvar(2) = array(sig_H_idx)
    uvar(3) = array(sig_vonMises_idx)
    uvar(4) = array(sig_Tresca_idx)
    uvar(5) = array(sig_P1_idx)
    uvar(6) = array(triax_idx)
    uvar(7) = array(lode_idx)
    uvar(8) = array(C_mol_idx)
    uvar(9) = array(CL_mol_idx)
    uvar(10) = array(CT_mol_idx)
    !uvar(10) = array(C_wtppm_idx)
    !uvar(11) = array(CL_wtppm_idx)
    !uvar(12) = array(CT_wtppm_idx)
    !uvar(13) = array(rho_d_idx)
    !uvar(14) = array(theta_coverage_idx)
    !uvar(15) = array(k_HEHE_idx)
    
return
end

