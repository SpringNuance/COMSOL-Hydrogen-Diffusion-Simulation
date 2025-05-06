
! C3D8/C3D8T element

!*****************************************************************
!  8-node     8---------------7
!  brick     /|              /|       zeta (positive)
!           / |  x 7   x 8  / |       
!          5---------------6  |       |     eta (positive)
!          |  | x 5   x 6  |  |       |   /
!          |  |            |  |       |  /
!          |  4------------|--3       | /
!          | /   x 3   x 4 | /        |/
!          |/   x 1   x 2  |/         O--------- xi (positive)
!          1---------------2           origin at cube center
!          
!         Outer number is nodal points
!         Inner number marked with x is integration points
!
!*****************************************************************

module iso_module

    use precision
    use common_block
    real(kind=dp), parameter :: coord_inter = 1.0d0
    real(kind=dp), parameter :: int_inter = 1.0d0 / sqrt(3.0d0)
    real(kind=dp), parameter :: coord_extra = sqrt(3.0d0)
    real(kind=dp), parameter :: int_extra = 1.0d0
    
    ! weight is the IP weight for their shape function contribution
    real(kind=dp), parameter :: weight(ninpt) = (/1.d0, 1.d0, 1.d0, 1.d0, 1.d0, 1.d0, 1.d0, 1.d0/)
    
    ! Interpolating coordinates (nodal to int)
    
    ! Isoparametric coordinates for nodal points in hexahedral 3D element
    real(kind=dp), parameter :: xi_nodal_inter(nnode)   = (/ -coord_inter,  coord_inter,  coord_inter, -coord_inter, &
                                                             -coord_inter,  coord_inter,  coord_inter, -coord_inter /)
    real(kind=dp), parameter :: eta_nodal_inter(nnode)  = (/ -coord_inter, -coord_inter,  coord_inter,  coord_inter, &
                                                             -coord_inter, -coord_inter,  coord_inter,  coord_inter /)
    real(kind=dp), parameter :: zeta_nodal_inter(nnode) = (/ -coord_inter, -coord_inter, -coord_inter, -coord_inter, &
                                                              coord_inter,  coord_inter,  coord_inter,  coord_inter /)

    ! Isoparametric coordinates for integration points in hexahedral 3D element
    real(kind=dp), parameter :: xi_int_inter(ninpt)     = (/ -int_inter,  int_inter, -int_inter,  int_inter, &
                                                             -int_inter,  int_inter, -int_inter,  int_inter /)
    real(kind=dp), parameter :: eta_int_inter(ninpt)    = (/ -int_inter, -int_inter,  int_inter,  int_inter, &
                                                             -int_inter, -int_inter,  int_inter,  int_inter /)
    real(kind=dp), parameter :: zeta_int_inter(ninpt)   = (/ -int_inter, -int_inter, -int_inter, -int_inter, &
                                                              int_inter,  int_inter,  int_inter,  int_inter /)

    ! Extrapolating coordinates (int to nodal)

    ! Isoparametric coordinates for nodal points in hexahedral 3D element
    real(kind=dp), parameter :: xi_nodal_extra(nnode)   = (/ -coord_extra,  coord_extra,  coord_extra, -coord_extra, &
                                                             -coord_extra,  coord_extra,  coord_extra, -coord_extra /)
    real(kind=dp), parameter :: eta_nodal_extra(nnode)  = (/ -coord_extra, -coord_extra,  coord_extra,  coord_extra, &
                                                             -coord_extra, -coord_extra,  coord_extra,  coord_extra /)
    real(kind=dp), parameter :: zeta_nodal_extra(nnode) = (/ -coord_extra, -coord_extra, -coord_extra, -coord_extra, &
                                                              coord_extra,  coord_extra,  coord_extra,  coord_extra /)

    ! Isoparametric coordinates for integration points in hexahedral 3D element
    real(kind=dp), parameter :: xi_int_extra(ninpt)   = (/ -int_extra,  int_extra, -int_extra,  int_extra, &
                                                           -int_extra,  int_extra, -int_extra,  int_extra /)
    real(kind=dp), parameter :: eta_int_extra(ninpt)  = (/ -int_extra, -int_extra,  int_extra,  int_extra, &
                                                           -int_extra, -int_extra,  int_extra,  int_extra /)
    real(kind=dp), parameter :: zeta_int_extra(ninpt) = (/ -int_extra, -int_extra, -int_extra, -int_extra, &
                                                            int_extra,  int_extra,  int_extra,  int_extra /)

end module iso_module

subroutine calc_N_inpt_to_local_coords(xi_coord, eta_coord, zeta_coord, N_inpt_to_local_coords)
    ! Calculate the shape function at the nodal points
    ! xi_coord, eta_coord, zeta_coord: Isoparametric coordinates of the nodal points

    use precision
    use common_block
    real(kind=dp), dimension(ninpt) :: N_inpt_to_local_coords
    real(kind=dp) :: xi_coord, eta_coord, zeta_coord

    !   shape functions
    N_inpt_to_local_coords(1) = 0.125d0 * (1.d0 - xi_coord) * (1.d0 - eta_coord) * (1.d0 - zeta_coord)
    N_inpt_to_local_coords(2) = 0.125d0 * (1.d0 + xi_coord) * (1.d0 - eta_coord) * (1.d0 - zeta_coord)
    N_inpt_to_local_coords(3) = 0.125d0 * (1.d0 - xi_coord) * (1.d0 + eta_coord) * (1.d0 - zeta_coord)
    N_inpt_to_local_coords(4) = 0.125d0 * (1.d0 + xi_coord) * (1.d0 + eta_coord) * (1.d0 - zeta_coord)
    N_inpt_to_local_coords(5) = 0.125d0 * (1.d0 - xi_coord) * (1.d0 - eta_coord) * (1.d0 + zeta_coord)
    N_inpt_to_local_coords(6) = 0.125d0 * (1.d0 + xi_coord) * (1.d0 - eta_coord) * (1.d0 + zeta_coord)
    N_inpt_to_local_coords(7) = 0.125d0 * (1.d0 - xi_coord) * (1.d0 + eta_coord) * (1.d0 + zeta_coord)
    N_inpt_to_local_coords(8) = 0.125d0 * (1.d0 + xi_coord) * (1.d0 + eta_coord) * (1.d0 + zeta_coord)

return
end

subroutine calc_N_node_to_local_coords(xi_coord, eta_coord, zeta_coord, &
                                       N_node_to_local_coords)
    ! Calculate the shape function at the integration points
    ! xi_coord, eta_coord, zeta_coord: Isoparametric coordinates of the integration points

    use precision
    use common_block    
    real(kind=dp), dimension(nnode) :: N_node_to_local_coords 
    real(kind=dp) :: xi_coord, eta_coord, zeta_coord

    !   shape functions
    N_node_to_local_coords(1)=0.125d0 * (1.d0 - xi_coord) * (1.d0 - eta_coord) * (1.d0 - zeta_coord)
    N_node_to_local_coords(2)=0.125d0 * (1.d0 + xi_coord) * (1.d0 - eta_coord) * (1.d0 - zeta_coord)
    N_node_to_local_coords(3)=0.125d0 * (1.d0 + xi_coord) * (1.d0 + eta_coord) * (1.d0 - zeta_coord)
    N_node_to_local_coords(4)=0.125d0 * (1.d0 - xi_coord) * (1.d0 + eta_coord) * (1.d0 - zeta_coord)
    N_node_to_local_coords(5)=0.125d0 * (1.d0 - xi_coord) * (1.d0 - eta_coord) * (1.d0 + zeta_coord)
    N_node_to_local_coords(6)=0.125d0 * (1.d0 + xi_coord) * (1.d0 - eta_coord) * (1.d0 + zeta_coord)
    N_node_to_local_coords(7)=0.125d0 * (1.d0 + xi_coord) * (1.d0 + eta_coord) * (1.d0 + zeta_coord)
    N_node_to_local_coords(8)=0.125d0 * (1.d0 - xi_coord) * (1.d0 + eta_coord) * (1.d0 + zeta_coord)

return
end

subroutine calc_N_grad_node_to_local_coords(xi_coord, eta_coord, zeta_coord, &
                                            N_grad_node_to_local_coords)
    !
    ! Calculate the shape function derivative at the integration points
    ! Basically derivatives of calc_N_node_to_local_coords
    ! N_grad_node_to_local_coords: (ndim, nnode)
    ! xi_coord, eta_coord, zeta_coord: Isoparametric coordinates of the integration points

    use precision
    use common_block
    real(kind=dp), dimension(ndim, nnode) :: N_grad_node_to_local_coords
    real(kind=dp) :: xi_coord, eta_coord, zeta_coord

    !   derivative d(Ni)/d(xi_coord)
    N_grad_node_to_local_coords(1, 1) = -0.125d0 * (1.d0 - eta_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(1, 2) =  0.125d0 * (1.d0 - eta_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(1, 3) =  0.125d0 * (1.d0 + eta_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(1, 4) = -0.125d0 * (1.d0 + eta_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(1, 5) = -0.125d0 * (1.d0 - eta_coord) * (1.d0 + zeta_coord)
    N_grad_node_to_local_coords(1, 6) =  0.125d0 * (1.d0 - eta_coord) * (1.d0 + zeta_coord)
    N_grad_node_to_local_coords(1, 7) =  0.125d0 * (1.d0 + eta_coord) * (1.d0 + zeta_coord)
    N_grad_node_to_local_coords(1, 8) = -0.125d0 * (1.d0 + eta_coord) * (1.d0 + zeta_coord)

    !     derivative d(Ni)/d(eta_coord)
    N_grad_node_to_local_coords(2, 1) = -0.125d0 * (1.d0 - xi_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(2, 2) = -0.125d0 * (1.d0 + xi_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(2, 3) =  0.125d0 * (1.d0 + xi_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(2, 4) =  0.125d0 * (1.d0 - xi_coord) * (1.d0 - zeta_coord)
    N_grad_node_to_local_coords(2, 5) = -0.125d0 * (1.d0 - xi_coord) * (1.d0 + zeta_coord)
    N_grad_node_to_local_coords(2, 6) = -0.125d0 * (1.d0 + xi_coord) * (1.d0 + zeta_coord)
    N_grad_node_to_local_coords(2, 7) =  0.125d0 * (1.d0 + xi_coord) * (1.d0 + zeta_coord)
    N_grad_node_to_local_coords(2, 8) =  0.125d0 * (1.d0 - xi_coord) * (1.d0 + zeta_coord)

    !     derivative d(Ni)/d(zeta_coord)
    N_grad_node_to_local_coords(3, 1) = -0.125d0 * (1.d0 - xi_coord) * (1.d0 - eta_coord)
    N_grad_node_to_local_coords(3, 2) = -0.125d0 * (1.d0 + xi_coord) * (1.d0 - eta_coord)
    N_grad_node_to_local_coords(3, 3) = -0.125d0 * (1.d0 + xi_coord) * (1.d0 + eta_coord)
    N_grad_node_to_local_coords(3, 4) = -0.125d0 * (1.d0 - xi_coord) * (1.d0 + eta_coord)
    N_grad_node_to_local_coords(3, 5) =  0.125d0 * (1.d0 - xi_coord) * (1.d0 - eta_coord)
    N_grad_node_to_local_coords(3, 6) =  0.125d0 * (1.d0 + xi_coord) * (1.d0 - eta_coord)
    N_grad_node_to_local_coords(3, 7) =  0.125d0 * (1.d0 + xi_coord) * (1.d0 + eta_coord)
    N_grad_node_to_local_coords(3, 8) =  0.125d0 * (1.d0 - xi_coord) * (1.d0 + eta_coord)

return
end