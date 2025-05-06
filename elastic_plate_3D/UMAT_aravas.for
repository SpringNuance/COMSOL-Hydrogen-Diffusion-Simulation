C*** JANUARY 27 2025
C*** DAMAGE MODEL WITH HYDROGEN EFFECTS
C*** CODE DEVELOPED AT UNIVERSITY OF THESSALY (UTH)
C***
C*** STRESS ANALYSIS WITH HYDROGEN DIFFUSION CODE FOR
C***
C*** ----CASE (A)----
C***
C*** 4-NODE PLANE-STRAIN ELEMENTS CPE4T WITH FULL INTEGRATION (2 x 2 GAUSS POINTS) OR
C*** 8-NODE 3D ELEMENTS C3D8T WITH WITH FULL INTEGRATION (2 x 2 x 2 GAUSS POINTS)
C***
C*** ----CASE (B)----
C***
C*** 4-NODE PLANE-STRAIN ELEMENTS CPE4RT WITH 1 GAUSS POINTS OR
C*** 8-NODE 3D ELEMENTS C3D8RT WITH 1 GAUSS POINTS
C*** WITH ENHANCED HOURGLASS CONTROL
C***
C*** NOTICE FOR PARALLELIZATION:
C***
C*** MUTEXES ARE USED IN THE CODE AT PLACES INVOLVING READING/WRITING
C*** OF GLOBAL ARRAYS IN ORDER TO MAKE THE CODE THREAD SAFE FOR PARALLEL
C*** EXECUTION 
C*** WOKS ONLY WITH mp_mode=threads (NOT mpi WHICH IS THE DEFAULT) 
C
C***********************************************************************
C
      module ktransfer
C
      implicit none
C
C Model Parameters
C      
C kxdim       =   Problem's dimension (2 in 2D, 3 in 3D problems)
C kxmtrx      =   Auxialiary integer to define dimensions of DELTA etc. (4 in 2D, 6 in 3D problems)
C kxnodel     =   Nodes per element (4 in 4-node, 8 in 8-node elements)
C kxelpernode =   Max number of elements belonging to a node (allocate a large enough number) 
C kxelem      =   Largest element label in the model (may skip between numbers)
C kxnode      =   Largest node label in the model (may skip between numbers)
C ktotalnodes =   Total number of nodes in the model
C ktotalel    =   Total number of elements in the model
C ngaus       =   Number of Gauss integration points 
C
C
C------------------------- ALWAYS CHECK BEFORE RUNNING ------------------------------------
C------------------------------------------------------------------------------------------
C NOTICE 1: Full Integration Elements:    2D Quad --> ngaus=4                             |
C                                         3D Hex  --> ngaus=8                             |
C                                                                                         |
C           Reduced Integration Elements: 2D Quad --> ngaus=1                             |
C                                         3D Hex  --> ngaus=1                             |
C                                                                                         |
C NOTICE 2: 2D ELEMENTS: kxmtrx = 4                                                       |               
C           3D ELEMENTS: kxmtrx = 6                                                       |
C                                                                                         |
C NOTICE 3: Flags for 1 or 2-way coupling and plasticity damage are in KYCURVE subroutine |
C           Change depending on problem                                                   |
C                                                                                         |
C NOTICE 4: Flag for Rate-Dependency activation/deactivation in KRATEFCN subroutine       |
C           Change depending on problem                                                   |
C------------------------------------------------------------------------------------------
C
C
      integer kxdim, kxnodel, kxelpernode, kxelem, kxnode, kxmtrx,
     +        ngaus, ktotalnodes, ktotalel 
C
      parameter( kxdim       =     2,
     +           kxmtrx      =     4,
     +           kxnodel     =     4,
     +           kxelpernode =    10,
     +           kxelem      = 18000,
     +           kxnode      = 20000,
     +           ktotalnodes = 18361,
     +           ktotalel    = 18000,
     +           ngaus       =     1  )
C
      real*8  PELEM(kxelem,ngaus),PNODAL(kxnode),
     +        GRADP(kxelem,ngaus,kxdim),coorT(kxnode,kxdim),
     +        coor0(kxnode,kxdim),ADETJEL(kxelem,kxnodel)
C
C*** For 3D problems : real*8 DELTA(6),AIMX(6,6),AJMX(6,6),AKMX(6,6),CEL(6,6)      
C*** For 2D problems : real*8 DELTA(4),AIMX(4,4),AJMX(4,4),AKMX(4,4),CEL(4,4)
C      
      real*8  DELTA(kxmtrx),AIMX(kxmtrx,kxmtrx),AJMX(kxmtrx,kxmtrx),
     +        AKMX(kxmtrx,kxmtrx),CEL(kxmtrx,kxmtrx)
      integer IELCONN(kxelem,kxnodel),INODETOEL(kxnode,kxelpernode,2),
     +        ITERMTX(kxelem,ngaus)
C
      end module
C
C***********************************************************************
C
      subroutine uexternaldb(lop,lrestart,time,dtime,kstep,kinc)
C
C*** Is called once
C    at the beginning of the analysis,
C    at the beginning of each increment,
C    at the end of each increment, and
C    at the end of the analysis.
C    Is also called once at the beginning of a restart analysis.
C
      use ktransfer
      include 'aba_param.inc' ! implicit real*8(a-h o-z)
      include 'SMAAspUserSubroutines.hdr'
      dimension time(2)
C
      kmaxel      = kxelem 
      kmaxnodes   = kxnode
C
C***  Start of the analysis
C***  Initialize variables
      if (lop.eq.0) then 
C      
C***  Initialize Mutexes
        call MutexInit( 1 )      
        call MutexInit( 2 )      
        call MutexInit( 3 )      
        call MutexInit( 4 )
        call MutexInit( 5 )
        call MutexInit( 6 )
        call MutexInit( 7 ) 
        call MutexInit( 8 ) 
        call MutexInit( 9 ) 
        call MutexInit( 10 ) 
        call MutexInit( 11 )
        call MutexInit( 12 )
C
        call MutexLock(1)   ! lock Mutex #1
        PELEM  = 0.D0
        PNODAL = 0.D0
        GRADP  = 0.D0
        call MutexUnlock(1) ! unlock Mutex #1
      end if 
C
C***  Start of the step
      if (lop.eq.5) then
C     find which elements a node belongs to
        call MutexLock(2)   ! lock Mutex #2
        CALL KNODETOELCON(kmaxel,kmaxnodes)
        call MutexUnlock(2) ! unlock Mutex #2
      end if
C
C***  Start of increment
      if (lop.eq.1) then        
        call MutexLock(11)   ! lock Mutex #1
        ITERMTX = 0
        call MutexUnlock(11) ! unlock Mutex #1
      end if
C
C***  End of increment
      if (lop.eq.2) then
        call MutexLock(3)   ! lock Mutex #3
C       calculate detJ for all nodes in all elements
        CALL KDETJEL(kmaxel)
C       calculate nodal pressures
        CALL KPNODAL(kmaxel,kmaxnodes)
        call MutexUnlock(3) ! unlock Mutex #3
      end if
C
      NDI = 3 
      NSHR = 1
      IF (kxdim.gt.2) NSHR = 3
      NTENS = NDI + NSHR
C
C***  Start of analysis (lop=0) OR beginning of restart analysis (lop=4)
      if (lop.eq.0. or .lop.eq.4) then
        call MutexLock(4)   ! lock Mutex #4
C       define unit tensors
        DELTA = 0.D0
        DO I=1,NDI
          DELTA(I) = 1.D0
        ENDDO
C
        AIMX = 0.D0
        DO I=1,NDI
          AIMX(I,I) = 1.D0
        ENDDO
        DO I=NDI+1,NTENS
          AIMX(I,I) = 0.5D0
        ENDDO
C
        AJMX = 0.D0
        AUX = 1.D0/3.D0
        DO I=1,NDI
        DO J=1,NDI
          AJMX(I,J) = AUX
        ENDDO
        ENDDO
C
        DO I=1,NTENS
        DO J=1,NTENS
          AKMX(I,J) = AIMX(I,J) - AJMX(I,J)
        ENDDO
        ENDDO
        call MutexUnlock(4) ! unlock Mutex #4
      end if
C
      end
C
C*********************************************************************** 
C
      SUBROUTINE KNODETOELCON(kmaxel,kmaxnodes)
C
C*** For each node in the mesh,
C    finds the elements the node belongs to and
C    stores data in array INODETOEL, which is globally available
C
      use ktransfer      
      include 'aba_param.inc'
C      
      CHARACTER(len=256) OUTDIR, AELREAD, AELWRITE, ANDREAD, ANDWRITE,
     +                   ANELWRITE
C      
C*** Utility subroutine that returns current output directory
C*** (current as opposed to scratch)      
      CALL GETOUTDIR(OUTDIR,LENOUTDIR)
C
      IELCONN=0
      AELREAD = TRIM(OUTDIR)//'\elements'
      OPEN(UNIT=105,FILE=AELREAD,STATUS='UNKNOWN')
C*** Read element connectivities
      READ(105,*)
      READ(105,*)
      DO i=1,ktotalel
        READ(105,*) IELEM,(IELCONN(IELEM,m),m=1,kxnodel)
      END DO
      CLOSE(105)
C
C*** Find the elements each node belongs to
      INODETOEL = 0
      DO IELEM = 1,kmaxel
        IF (IELCONN(IELEM,1).NE.0) THEN
          DO INODE=1,kxnodel
            KNODE = IELCONN(IELEM,INODE)
            L = INODETOEL(KNODE,1,1) + 1
            INODETOEL(KNODE,1,1) = L         ! Upgrade the number of elements KNODE belongs to
            INODETOEL(KNODE,1 + L,1) = IELEM ! Next element that KNODE belongs to is added to column 1+L
            INODETOEL(KNODE,1 + L,2) = INODE ! Local node number of KNODE in element added above stored in 3rd dimension of INODETOEL
          END DO          
        END IF    
      ENDDO
C      
      END
C 
C***********************************************************************
C    
      SUBROUTINE KDETJEL(kmaxel)
C
C*** For each element in the mesh, calculates detJ at each node of the element
C    and stores it in array ADETJEL. These values are then used to calculate
C    nodal pressures using weighted element pressures based on "element area"
C    converging to the specific node
C
      use ktransfer      
      include 'aba_param.inc'
      DIMENSION X(kxnodel),Y(kxnodel),Z(kxnodel)
      DIMENSION AJ(kxdim,kxdim),DN(kxdim,kxnodel)
      DIMENSION XINODE(kxnodel),ETANODE(kxnodel),ZETANODE(kxnodel)
C
C*** Element nodal coordinates (�i,�i) (or (�i,�i,�i) in 3D elements) in natural space
C
      IF (kxdim.eq.2) THEN  ! 2D Element
        XINODE(1) = -1.D0;  ETANODE(1) = -1.D0;
        XINODE(2) =  1.D0;  ETANODE(2) = -1.D0;
        XINODE(3) =  1.D0;  ETANODE(3) =  1.D0;
        XINODE(4) = -1.D0;  ETANODE(4) =  1.D0;
      END IF
      IF (kxdim.gt.2) THEN  ! 3D Element
        XINODE(1) = -1.D0;  ETANODE(1) = -1.D0;  ZETANODE(1) = -1.D0;
        XINODE(2) =  1.D0;  ETANODE(2) = -1.D0;  ZETANODE(2) = -1.D0; 
        XINODE(3) =  1.D0;  ETANODE(3) =  1.D0;  ZETANODE(3) = -1.D0; 
        XINODE(4) = -1.D0;  ETANODE(4) =  1.D0;  ZETANODE(4) = -1.D0; 
        XINODE(5) = -1.D0;  ETANODE(5) = -1.D0;  ZETANODE(5) = 1.D0; 
        XINODE(6) =  1.D0;  ETANODE(6) = -1.D0;  ZETANODE(6) = 1.D0; 
        XINODE(7) =  1.D0;  ETANODE(7) =  1.D0;  ZETANODE(7) = 1.D0; 
        XINODE(8) = -1.D0;  ETANODE(8) =  1.D0;  ZETANODE(8) = 1.D0; 
      END IF
C
      DO IEL=1,kmaxel    ! Do loop over all element labels
C
C*** Global coordinates (x,y) (or (x,y,z) in 3D elements) of point (node) under consideration
C
        X=0.D0; Y=0.D0;
        IF (kxdim.gt.2) Z=0.D0
        DO INEL=1,kxnodel
          KNODE = IELCONN(IEL,INEL)
          X(INEL) = coorT(KNODE,1)
          Y(INEL) = coorT(KNODE,2)
          IF (kxdim.gt.2) Z(INEL) = coorT(KNODE,3)
        END DO
C
        DO JN=1,kxnodel  ! Do loop over all nodes of element IEL 
C
C*** Natural Coordinates (�,�) (or (�,�,�) in 3D elements) of point (node) under consideration
C
          XI=XINODE(JN); ETA=ETANODE(JN)
          IF (kxdim.gt.2) ZETA=ZETANODE(JN)  
C
C*** Calculate [N'] at (�,�) (or (�,�,�) in 3D elements)
C
          IF (kxdim.eq.2) THEN  ! 2D Element
            AUX = 1.D0/4.D0
            DO I=1,4
              DN(1,I) = AUX*XINODE(I)*(1.D0 + ETANODE(I)*ETA)
              DN(2,I) = AUX*ETANODE(I)*(1.D0 + XINODE(I)*XI)
            END DO
          END IF
          IF (kxdim.gt.2) THEN  ! 3D Element
            AUX = 1.D0/8.D0
            DO I=1,8
              DN(1,I) = AUX*XINODE(I)*(1.D0 + ETANODE(I)*ETA)*
     +                                  (1.D0 + ZETANODE(I)*ZETA)
              DN(2,I) = AUX*ETANODE(I)*(1.D0 + XINODE(I)*XI)*
     +                                  (1.D0 + ZETANODE(I)*ZETA)
              DN(3,I) = AUX*ZETANODE(I)*(1.D0 + XINODE(I)*XI)*
     +                                  (1.D0 + ETANODE(I)*ETA)
            END DO
          END IF
C
C*** Calculate [J]=[dx_j/d�_i] and det[J] at (�,�) (or (�,�,�) in 3D elements)
C
          IF (kxdim.eq.2) THEN  ! 2D Element
            AJ = 0.D0
            DO I=1,4
              AJ(1,1) = AJ(1,1) + DN(1,I)*X(I)
              AJ(1,2) = AJ(1,2) + DN(1,I)*Y(I)
              AJ(2,1) = AJ(2,1) + DN(2,I)*X(I)
              AJ(2,2) = AJ(2,2) + DN(2,I)*Y(I)
            END DO
            ADETJ = AJ(1,1)*AJ(2,2) - AJ(2,1)*AJ(1,2)
          END IF
          IF (kxdim.gt.2) THEN  ! 3D Element
            AJ = 0.D0
            DO I=1,8
              AJ(1,1) = AJ(1,1) + DN(1,I)*X(I)
              AJ(1,2) = AJ(1,2) + DN(1,I)*Y(I)
              AJ(1,3) = AJ(1,3) + DN(1,I)*Z(I)
C
              AJ(2,1) = AJ(2,1) + DN(2,I)*X(I)
              AJ(2,2) = AJ(2,2) + DN(2,I)*Y(I)
              AJ(2,3) = AJ(2,3) + DN(2,I)*Z(I)
C
              AJ(3,1) = AJ(3,1) + DN(3,I)*X(I)
              AJ(3,2) = AJ(3,2) + DN(3,I)*Y(I)
              AJ(3,3) = AJ(3,3) + DN(3,I)*Z(I)
            END DO
            ADETJ = AJ(1,1)*(AJ(2,2)*AJ(3,3) - AJ(3,2)*AJ(2,3))
     +        - AJ(1,2)*(AJ(2,1)*AJ(3,3) - AJ(3,1)*AJ(2,3))
     +        + AJ(1,3)*(AJ(2,1)*AJ(3,2) - AJ(3,1)*AJ(2,2))
          END IF
C
C*** Store detJ for node JN of element IEL in global array ADETJEL          
C
          ADETJEL(IEL,JN) = ADETJ 
C
        END DO  ! Do loop over all nodes in IEL Ends
      END DO    ! Do loop over all element labels Ends
C
      END
C 
C***********************************************************************
C
      SUBROUTINE KPNODAL(kmaxel,kmaxnodes)
C
C*** Calculates average nodal pressure values
C
      use ktransfer      
      include 'aba_param.inc'
C
      DO INODE=1,kmaxnodes
        N=INODETOEL(INODE,1,1)
        IF (N.NE.0) THEN ! N/=0 means that node INODE exists and belongs to N elements
          SUMPJ = 0.D0
          SUMJ = 0.D0
          DO I=2,1+N ! Loop to calculate nodal pressure at the existing node INODE
            IELEMENT = INODETOEL(INODE,I,1)  ! Element label of Ith element INODE belongs to
            NODEOFEL = INODETOEL(INODE,I,2)  ! Local node number of node label INODE in Ith element 
            ADETI = ADETJEL(IELEMENT,NODEOFEL) ! detJ for node INODE in Ith element
            SUMEL = 0.D0
            DO J=1,ngaus ! For element IELEMENT, loop over all ngaus to calc. avg. pressure of element
              SUMEL= SUMEL + PELEM(IELEMENT,J)
            END DO
            SUMEL = SUMEL/(1.D0*ngaus)
            SUMPJ = SUMPJ + SUMEL*ADETI
            SUMJ  = SUMJ + ADETI
          END DO
          PNODAL(INODE) = SUMPJ/SUMJ
        END IF
      ENDDO
C
      END
C
C***********************************************************************
C
      SUBROUTINE UFIELD(FIELD,KFIELD,NSECPT,KSTEP,KINC,TIME,NODE,
     + COORDS,TEMP,DTEMP,NFIELD)
C
C*** USER SUBROUTINE used just to read current nodal coordinates
C
      use ktransfer
      include 'aba_param.inc'
      include 'SMAAspUserSubroutines.hdr'
C
      DIMENSION FIELD(NSECPT,NFIELD),TIME(2),COORDS(3),
     + TEMP(NSECPT),DTEMP(NSECPT)
C
      call MutexLock(5)   ! lock Mutex #5
      coorT(NODE,1)=COORDS(1)
      coorT(NODE,2)=COORDS(2)
      IF (kxdim.gt.2) coorT(NODE,3)=COORDS(3)
      call MutexUnlock(5) ! unlock Mutex #5
C
      END
C
C***********************************************************************   
C
      SUBROUTINE KGRADP2D(NOEL,X,Y,PELNODAL,NPT)
C
C*** Calculates pressure gradient at (�,�) for 2-D isoparametric
C    4-node quadrilateral element
C
      use ktransfer      
      include 'aba_param.inc'
      DIMENSION GRADPR(2),X(4),Y(4),PELNODAL(4)
      DIMENSION AJ(2,2),AJINV(2,2),DN(2,4),BMTRX(2,4)
      DIMENSION XINODE(4),ETANODE(4)
C
C*** Gauss point coordinates (�,�) based on NPT under consideration
C

      IF (ngaus.eq.1) THEN ! Reduced Integration
        XI=0.D0; ETA=0.D0 
      ELSE ! Full Integration
        ONE=1.D0; SR3 = DSQRT(3.D0);
        IF     (NPT==1) THEN; XI=-ONE/SR3; ETA=-ONE/SR3
        ELSEIF (NPT==2) THEN; XI= ONE/SR3; ETA=-ONE/SR3
        ELSEIF (NPT==3) THEN; XI=-ONE/SR3; ETA= ONE/SR3
        ELSEIF (NPT==4) THEN; XI= ONE/SR3; ETA= ONE/SR3
        END IF
      END IF
C
C*** Element nodal coordinates (�i,�i) 
C
      XINODE(1) = -1.D0;  ETANODE(1) = -1.D0;
      XINODE(2) =  1.D0;  ETANODE(2) = -1.D0;
      XINODE(3) =  1.D0;  ETANODE(3) =  1.D0;
      XINODE(4) = -1.D0;  ETANODE(4) =  1.D0;
C
C*** Calculate [N'] at (�,�)
C
      DO I=1,4
        DN(1,I) = (1.D0/4.D0)*XINODE(I)*(1.D0 + ETANODE(I)*ETA)
        DN(2,I) = (1.D0/4.D0)*ETANODE(I)*(1.D0 + XINODE(I)*XI)
      END DO      
C
C*** Calculate [J]=[dx_j/d�_i] and det[J] at (�,�)
C
      AJ = 0.D0
      DO I=1,4
        AJ(1,1) = AJ(1,1)+ DN(1,I)*X(I)
        AJ(1,2) = AJ(1,2)+ DN(1,I)*Y(I)
        AJ(2,1) = AJ(2,1)+ DN(2,I)*X(I)
        AJ(2,2) = AJ(2,2)+ DN(2,I)*Y(I)
      END DO
      ADETJ = AJ(1,1)*AJ(2,2) - AJ(2,1)*AJ(1,2)
C
C*** Calculate [J]^(-1) at (�,�)
C
      AJINV(1,1) =   AJ(2,2)/ADETJ
      AJINV(2,2) =   AJ(1,1)/ADETJ
      AJINV(1,2) = - AJ(1,2)/ADETJ
      AJINV(2,1) = - AJ(2,1)/ADETJ
C
C*** Calculate {gradp}=[J]^(-1).[N'].{PN}  at (�,�)
C
      CALL KMULT(AJINV,DN,BMTRX,2,2,4)
      CALL KMULT(BMTRX,PELNODAL,GRADPR,2,4,1)
C
      GRADP(NOEL,NPT,1)= GRADPR(1)
      GRADP(NOEL,NPT,2)= GRADPR(2)
C
      END
C
C***********************************************************************
C
      SUBROUTINE KGRADP3D(NOEL,X,Y,Z,PELNODAL,NPT)
C
C*** Calculates pressure gradient at (�,�,�) for 3-D isoparametric
C    8-node brick element
C
      use ktransfer      
      include 'aba_param.inc'
      DIMENSION GRADPR(3),X(8),Y(8),Z(8),PELNODAL(8)
      DIMENSION AJ(3,3),AJINV(3,3),DN(3,8),BMTRX(3,8)
      DIMENSION XINODE(8),ETANODE(8),ZETANODE(8)
C
C*** Gauss point coordinates (�,�,�) based on NPT under consideration
C
      IF (ngaus.eq.1) THEN ! Reduced Integration
        XI=0.D0; ETA=0.D0; ZETA=0.D0; 
      ELSE ! Full Integration
        ONE=1.D0; SR3 = DSQRT(3.D0);
        IF     (NPT==1) THEN; XI=-ONE/SR3; ETA=-ONE/SR3; ZETA=-ONE/SR3;
        ELSEIF (NPT==2) THEN; XI= ONE/SR3; ETA=-ONE/SR3; ZETA=-ONE/SR3;
        ELSEIF (NPT==3) THEN; XI=-ONE/SR3; ETA= ONE/SR3; ZETA=-ONE/SR3;
        ELSEIF (NPT==4) THEN; XI= ONE/SR3; ETA= ONE/SR3; ZETA=-ONE/SR3;
        ELSEIF (NPT==5) THEN; XI=-ONE/SR3; ETA=-ONE/SR3; ZETA= ONE/SR3;
        ELSEIF (NPT==6) THEN; XI= ONE/SR3; ETA=-ONE/SR3; ZETA= ONE/SR3;
        ELSEIF (NPT==7) THEN; XI=-ONE/SR3; ETA= ONE/SR3; ZETA= ONE/SR3;
        ELSEIF (NPT==8) THEN; XI= ONE/SR3; ETA= ONE/SR3; ZETA= ONE/SR3;
        END IF
      END IF
C
C*** Element nodal coordinates (�i,�i,�i) 
C
      XINODE(1) = -1.D0;  ETANODE(1) = -1.D0;  ZETANODE(1) = -1.D0;
      XINODE(2) =  1.D0;  ETANODE(2) = -1.D0;  ZETANODE(2) = -1.D0; 
      XINODE(3) =  1.D0;  ETANODE(3) =  1.D0;  ZETANODE(3) = -1.D0; 
      XINODE(4) = -1.D0;  ETANODE(4) =  1.D0;  ZETANODE(4) = -1.D0; 
C
      XINODE(5) = -1.D0;  ETANODE(5) = -1.D0;  ZETANODE(5) = 1.D0; 
      XINODE(6) =  1.D0;  ETANODE(6) = -1.D0;  ZETANODE(6) = 1.D0; 
      XINODE(7) =  1.D0;  ETANODE(7) =  1.D0;  ZETANODE(7) = 1.D0; 
      XINODE(8) = -1.D0;  ETANODE(8) =  1.D0;  ZETANODE(8) = 1.D0; 
C
C*** Calculate [N'] at (�,�,�)
C
      AUX = 1.D0/8.D0
      DO I=1,8
        DN(1,I) = AUX*XINODE(I)*(1.D0 + ETANODE(I)*ETA)*
     +            (1.D0 + ZETANODE(I)*ZETA)
        DN(2,I) = AUX*ETANODE(I)*(1.D0 + XINODE(I)*XI)*
     +            (1.D0 + ZETANODE(I)*ZETA)
        DN(3,I) = AUX*ZETANODE(I)*(1.D0 + XINODE(I)*XI)*
     +            (1.D0 + ETANODE(I)*ETA)
      END DO      
C
C*** Calculate [J]=[dx_j/d�_i] and det[J] at (�,�,�)
C
      AJ = 0.D0
      DO I=1,8
        AJ(1,1) = AJ(1,1)+ DN(1,I)*X(I)
        AJ(1,2) = AJ(1,2)+ DN(1,I)*Y(I)
        AJ(1,3) = AJ(1,3)+ DN(1,I)*Z(I)
C
        AJ(2,1) = AJ(2,1)+ DN(2,I)*X(I)
        AJ(2,2) = AJ(2,2)+ DN(2,I)*Y(I)
        AJ(2,3) = AJ(2,3)+ DN(2,I)*Z(I)
C
        AJ(3,1) = AJ(3,1)+ DN(3,I)*X(I)
        AJ(3,2) = AJ(3,2)+ DN(3,I)*Y(I)
        AJ(3,3) = AJ(3,3)+ DN(3,I)*Z(I)
      END DO
C
C*** Calculate [J]^(-1) at (�,�,�)
C
      CALL KINV3X3(AJ,AJINV)
C
C*** Calculate {gradp}=[J]^(-1).[N'].{PN}  at (�,�,�)
C
      CALL KMULT(AJINV,DN,BMTRX,3,3,8)
      CALL KMULT(BMTRX,PELNODAL,GRADPR,3,8,1)
C
      GRADP(NOEL,NPT,1)= GRADPR(1)
      GRADP(NOEL,NPT,2)= GRADPR(2)
      GRADP(NOEL,NPT,3)= GRADPR(3)
C
      END      
C



C***********************************************************************
C
      SUBROUTINE DISP(U,KSTEP,KINC,TIME,NODE,NOEL,JDOF,COORDS)
C
C*** SUBROUTINE TO IMPOSE MODE-I DISPLACEMENT ELASTIC SOLUTION 
C*** TO OUTER LAYER BOUNDARY NODES. 
C
      use ktransfer
      INCLUDE 'ABA_PARAM.INC'
C
      DIMENSION U(3),TIME(3),COORDS(3)
C
      E   = 828.D0
      ANU = 0.3D0
      G   = E/(2.D0*(1.D0+ANU))
      AK  = 3.D0-4.D0*ANU
      PI  = 4.D0*DATAN(1.D0)
C
C*** READ AND STORE INITIAL COORDINATES
C
      IF (KSTEP.EQ.1.AND.KINC.EQ.1) THEN
        coor0(NODE,1) = COORDS(1)
        coor0(NODE,2) = COORDS(2)
        IF (kxdim.gt.2) THEN
          coor0(NODE,3) = COORDS(3)
        END IF
      END IF      
C
C    SIF = MODE I STRESS INTENSITY FACTOR K_I
C*** Set SIFMAX equal to final normalized load
C*** Set TMAX equal to the total analysis time
      SIFMAX=40.115d0;  TMAX=32.5d0
      SIF = TIME(2)*SIFMAX/TMAX
C
      X1  = coor0(NODE,1)
      X2  = coor0(NODE,2)
      R   = DSQRT(X1*X1+X2*X2)
      TH  = DATAN2(X2,X1)
      IF (TH.LT.0.D0) TH = TH + PI
C
C*** FIRST TERM OF DISPLACEMENT FIELD (SIF-K_I TERM)
C
      AUX1 = 0.5D0*SIF/(G*DSQRT(2.D0*PI))
      IF (JDOF.EQ.1) U(1) = AUX1*DSQRT(R)*(AK - DCOS(TH))*DCOS(0.5D0*TH)
      IF (JDOF.EQ.2) U(1) = AUX1*DSQRT(R)*(AK - DCOS(TH))*DSIN(0.5D0*TH)
C
      END
C
C***********************************************************************
C
