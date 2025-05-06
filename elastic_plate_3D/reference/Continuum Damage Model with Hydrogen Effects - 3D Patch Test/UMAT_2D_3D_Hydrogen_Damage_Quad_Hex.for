C*** AUGUST 15 2024
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
C           Change dependning on problem                                                  |
C------------------------------------------------------------------------------------------
C
C
      integer kxdim, kxnodel, kxelpernode, kxelem, kxnode, kxmtrx,
     +        ngaus, ktotalnodes, ktotalel 
C
      parameter( kxdim       =     3,
     +           kxmtrx      =     6,
     +           kxnodel     =     8,
     +           kxelpernode =    10,
     +           kxelem      =     7,
     +           kxnode      =    16,
     +           ktotalnodes =    16,
     +           ktotalel    =     7,
     +           ngaus       =     8  )
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
      integer IELCONN(kxelem,kxnodel),INODETOEL(kxnode,kxelpernode,2)
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
C*** Element nodal coordinates (îi,çi) (or (îi,çi,æi) in 3D elements) in natural space
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
C*** Natural Coordinates (î,ç) (or (î,ç,æ) in 3D elements) of point (node) under consideration
C
          XI=XINODE(JN); ETA=ETANODE(JN)
          IF (kxdim.gt.2) ZETA=ZETANODE(JN)  
C
C*** Calculate [N'] at (î,ç) (or (î,ç,æ) in 3D elements)
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
C*** Calculate [J]=[dx_j/dî_i] and det[J] at (î,ç) (or (î,ç,æ) in 3D elements)
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
C*** Calculates pressure gradient at (î,ç) for 2-D isoparametric
C    4-node quadrilateral element
C
      use ktransfer      
      include 'aba_param.inc'
      DIMENSION GRADPR(2),X(4),Y(4),PELNODAL(4)
      DIMENSION AJ(2,2),AJINV(2,2),DN(2,4),BMTRX(2,4)
      DIMENSION XINODE(4),ETANODE(4)
C
C*** Gauss point coordinates (î,ç) based on NPT under consideration
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
C*** Element nodal coordinates (îi,çi) 
C
      XINODE(1) = -1.D0;  ETANODE(1) = -1.D0;
      XINODE(2) =  1.D0;  ETANODE(2) = -1.D0;
      XINODE(3) =  1.D0;  ETANODE(3) =  1.D0;
      XINODE(4) = -1.D0;  ETANODE(4) =  1.D0;
C
C*** Calculate [N'] at (î,ç)
C
      DO I=1,4
        DN(1,I) = (1.D0/4.D0)*XINODE(I)*(1.D0 + ETANODE(I)*ETA)
        DN(2,I) = (1.D0/4.D0)*ETANODE(I)*(1.D0 + XINODE(I)*XI)
      END DO      
C
C*** Calculate [J]=[dx_j/dî_i] and det[J] at (î,ç)
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
C*** Calculate [J]^(-1) at (î,ç)
C
      AJINV(1,1) =   AJ(2,2)/ADETJ
      AJINV(2,2) =   AJ(1,1)/ADETJ
      AJINV(1,2) = - AJ(1,2)/ADETJ
      AJINV(2,1) = - AJ(2,1)/ADETJ
C
C*** Calculate {gradp}=[J]^(-1).[N'].{PN}  at (î,ç)
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
C*** Calculates pressure gradient at (î,ç,æ) for 3-D isoparametric
C    8-node brick element
C
      use ktransfer      
      include 'aba_param.inc'
      DIMENSION GRADPR(3),X(8),Y(8),Z(8),PELNODAL(8)
      DIMENSION AJ(3,3),AJINV(3,3),DN(3,8),BMTRX(3,8)
      DIMENSION XINODE(8),ETANODE(8),ZETANODE(8)
C
C*** Gauss point coordinates (î,ç,æ) based on NPT under consideration
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
C*** Element nodal coordinates (îi,çi,æi) 
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
C*** Calculate [N'] at (î,ç,æ)
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
C*** Calculate [J]=[dx_j/dî_i] and det[J] at (î,ç,æ)
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
C*** Calculate [J]^(-1) at (î,ç,æ)
C
      CALL KINV3X3(AJ,AJINV)
C
C*** Calculate {gradp}=[J]^(-1).[N'].{PN}  at (î,ç,æ)
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
      SUBROUTINE KYCURVE(YIELD,H,HC,DD,EBAR,CL,EXPO,E0,SIG0,PROPS,
     + NPROPS,ETA,AVGETA,AVGTHETA,PS1,PDDT,AIDDT,EBART,AIDD,PDD,SYI,
     + EPCL,SC,C1,C2,C3,C4,ETAC,GF,D1,D2,D3,D4,DFLAG,AIFT,AIF,FFLAG,
     + DCRT,DCR,CTT,DTIME,IWR,IOUT,DDH,SYD,DCOMB)
C
C*** COMPUTES FLOW STRESS WITH DAMAGE SY AND
C    ITS DERIVATIVES (H, HC CAPITAL) WRT EBARP AND CL
C
      INCLUDE 'ABA_PARAM.INC'
      DIMENSION PROPS(NPROPS)
C
      IHYDRO = 0 ! INTEGER FLAG FOR HYDROGEN EFFECT ON SY (1 -> 2-WAY COUPLING && 0 -> 1-WAY COUPLING)
      IPLDMG = 1 ! INTEGER FLAG FOR PLASTICITY DAMAGE     (1 -> DAMAGE ACTIVE  && 0 -> NO PLASTICITY DAMAGE)
C
      CALL KCT(CT,dCTdEP,dCTdCL,CTT,THETAL,THETAT,EBAR,CL,PROPS,
     + NPROPS,DTIME)
      CTOTAL = CL + CT
      DCDEP = DCTDEP
C
      CH1 = 8.D0
      CH2 = 50.D0
      XI  = 0.1D0
C      
      IF (CTOTAL.LE.CH1) THEN
        DDH  = 0.D0
        F    = 1.D0 - DDH
        DFDC = 0.D0 
      END IF
      IF (CTOTAL.GT.CH2) THEN
        DDH  = 1.D0 - XI
        F    = 1.D0 - DDH
        DFDC = 0.D0 
      END IF
      IF (CTOTAL.GT.CH1.AND.CTOTAL.LE.CH2) THEN
        DDH  = (1.D0-XI)*(CTOTAL-CH1)/(CH2-CH1)
        F    = 1.D0 - DDH
        DFDC = -(1.D0-XI)/(CH2-CH1)  
      END IF
C
      IF (IHYDRO.NE.1) THEN ! 1-WAY COUPLING
        F    = 1.D0
        DFDC = 0.D0
        DDH  = 0.D0
      END IF
C
C*** CALCULATE SYIELD, h, hC FOR THE UNDAMAGED MATERIAL
C    
      AFITA = 0.3850D0
      AFITB = 9.5341D0
      EBAR1 = 0.179D0
      IF (EBAR.GT.EBAR1) THEN
        AUX     = SIG0*( 1.31513D0 + 0.66615D0*(EBAR-0.179D0) )   ! SIGMASMALL
        AUX2    = SIG0*0.66615D0                                  ! DSIGMASMALLDEBARP
      ELSE
        AUX     = SIG0*(1.D0+AFITA*(1.D0-DEXP(-AFITB*EBAR)))  ! SIGMASMALL
        AUX2    = SIG0*AFITA*AFITB*DEXP(-AFITB*EBAR)          ! DSIGMASMALLDEBARP
      END IF     
      SYUNDMG = F*AUX
      HUNDMG  = DFDC*DCDEP*AUX + F*AUX2
      HCUNDMG = DFDC*AUX
C
C*** CALCULATE SYIELD, H, HC WITH DAMAGE
C 
       CALL KDAMAGE(DD,DDAMDEBAR,SYUNDMG,EBAR,ETA,AVGETA,AVGTHETA,
     + PS1,PDDT,AIDDT,EBART,AIDD,PDD,SYI,EPCL,SC,C1,C2,C3,C4,ETAC,GF,D1,
     + D2,D3,D4,DFLAG,AIFT,AIF,FFLAG,DCRT,DCR,IPLDMG,IHYDRO,DDH,DCOMB,
     + IWR,IOUT)
C
      SYD   = (1.D0 - DD)*AUX
      YIELD = (1.D0 - DD)*SYUNDMG
      H  = (1.D0 - DD)*HUNDMG - DDAMDEBAR*SYUNDMG
      HC = (1.D0 - DD)*HCUNDMG  
C 
      END
C
C***********************************************************************      
C
      SUBROUTINE KCT(CT,dCTdEP,dCTdCL,CTT,THETAL,THETAT,EBAR,CL,PROPS,
     1 NPROPS,DTIME)
C
C*** computes C_T, theta_L, theta_T and
C    its derivatives wrt ebar^p and C_L
C
      INCLUDE 'ABA_PARAM.INC'
      DIMENSION PROPS(NPROPS)
C
C     read constants
      AKT    = PROPS(9)
      ALPHA  = PROPS(10)
      ANL    = PROPS(11)
      BETA   = PROPS(12)
      ALFREQ = PROPS(27)
C
      THETAL = CL/(BETA*ANL)
      CALL KNT(ANT,DANTDE,EBAR,PROPS,NPROPS)
C
      AUX    = 1.D0 + (1.D0 + AKT*THETAL)*ALFREQ*DTIME
      CT     = (CTT + ALPHA*AKT*THETAL*ANT*ALFREQ*DTIME)/AUX
      IF (CT.LT.0.D0) CT=0.D0
      THETAT = CT/(ALPHA*ANT)
C
C*** find dCTdCL and dCTdEP
      AUX1   = (AKT*ALFREQ*DTIME)/(BETA*ANL)
      AUX2   = 1.D0 + (1.D0 + AKT*THETAL)*ALFREQ*DTIME
C
      dCTdCL = -AUX1*(CTT - ALPHA*ANT*(1.D0 + ALFREQ*DTIME))/(AUX2*AUX2)
      dCTdEP = ((ALPHA*AKT*THETAL*ALFREQ*DTIME)/AUX2)*DANTDE      
C
      END
C
C***********************************************************************      
C
      SUBROUTINE KNT(ANT,DANTDE,EBAR,PROPS,NPROPS)
C
C*** computes N_T and its derivative wrt ebar^p
C
      INCLUDE 'ABA_PARAM.INC'
      DIMENSION PROPS(NPROPS)
C      
C*** TAHA & SOFRONIS FITTING (2001)
C
      C0 = PROPS(6)
      AA = 23.26D0; BB = 2.33D0; CC = 5.5D0
      AUX    = DEXP(-CC*EBAR)
      ANT    = ( 10**(AA - BB*AUX) )/C0
      DANTDE = BB*CC*DLOG(10.D0)*AUX*ANT
C
      END
C
C***********************************************************************
C
      SUBROUTINE UMATHT(U,DUDT,DUDG,FLUX,DFDT,DFDG,
     1 STATEV,TEMP,DTEMP,DTEMDX,TIME,DTIME,PREDEF,DPRED,
     2 CMNAME,NTGRD,NSTATV,PROPS,NPROPS,COORDS,PNEWDT,
     3 NOEL,NPT,LAYER,KSPT,KSTEP,KINC)
C
C*** UMATHT is called AFTER UMAT (if a UMAT exists in the analysis)
C
      use ktransfer
      INCLUDE 'ABA_PARAM.INC'
      include 'SMAAspUserSubroutines.hdr'
C
      CHARACTER*80 CMNAME
      DIMENSION DUDG(NTGRD),FLUX(NTGRD),DFDT(NTGRD),
     1 DFDG(NTGRD,NTGRD),STATEV(NSTATV),DTEMDX(NTGRD),
     2 TIME(2),PREDEF(1),DPRED(1),PROPS(NPROPS),COORDS(3)
C
C      
      IWR=0
      IOUT=7 !IOUT=7 WRITES ON THE .msg FILE
C      IF (NOEL.EQ.100.AND.NPT.EQ.1) IWR=1
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) '----------------------------'       
        WRITE(IOUT,*) 'CALCULATIONS IN UMATHT BEGIN'
        WRITE(IOUT,*) '----------------------------'   
        WRITE(IOUT,*) 'KSTEP, KINC'
        WRITE(IOUT,1002) KSTEP,KINC
        WRITE(IOUT,*) 'STEP-TIME, TOTAL-TIME, DTIME'
        WRITE(IOUT,1001) TIME(1),TIME(2),DTIME
        WRITE(IOUT,*) 'NOEL,NPT'
        WRITE(IOUT,1002) NOEL,NPT
        WRITE(IOUT,*) 'NTGRD'
        WRITE(IOUT,1002) NTGRD
      END IF
C      
      CLT   = TEMP
      DCL   = DTEMP
      CL    = CLT + DCL
C
      IF (CL.LT.1.D-6)  THEN
        CL=1.D-6
        IF (IWR.NE.0) THEN
          WRITE(6,*) 'CL NEGATIVE'
          WRITE(6,*) 'NOEL, NPT, KSTEP, KINC'
          WRITE(6,1002) NOEL,NPT,KSTEP,KINC
        END IF
      END IF
C
      EBAR  = STATEV(1)
      CT    = STATEV(4)
      RHO   = STATEV(23)
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'CLT, DCL, CL, CT, EBAR'
        WRITE(IOUT,1001) CLT, DCL, CL, CT, EBAR
      END IF
C
      D     = PROPS(7)
      VH    = PROPS(8)
      AKT   = PROPS(9)
      ALPHA = PROPS(10)
      ANL   = PROPS(11)
      BETA  = PROPS(12)
      SFD   = PROPS(28)
C
      if (TIME(2).EQ.0.D0) then   
        call MutexInit( 6 )
        call MutexInit( 7 )
      end if
C
C*** NEED TO ACCOUNT FOR INITIAL CL   
C
      IF (KSTEP.EQ.1.AND.KINC.EQ.1) THEN
        CL0 = CLT
        STATEV(8) = CL0
      END IF
C
C*** CALCULATE INTERNAL ENERGY PER UNIT MASS  
C
      CL0 = STATEV(8)
      U = (CL - CL0)/RHO
C
C*** CALCULATE DERIVATIVES OF U
C
      DUDT = 1.D0/RHO
      DUDG = 0.D0
C
      AUX1 = D*VH
      AUX  = AUX1*CL
      call MutexLock(6)   ! lock Mutex #6
      DO I=1,NTGRD
        FLUX(I) = -D*DTEMDX(I) + AUX*GRADP(NOEL,NPT,I)
      ENDDO
C
      DO I=1,NTGRD
        DFDT(I) = AUX1*GRADP(NOEL,NPT,I)
      ENDDO
      call MutexUnlock(6) ! unlock Mutex #6
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'U, DUDT'
        WRITE(IOUT,1001) U, DUDT
        WRITE(IOUT,*) 'DUDG(I)'
        WRITE(IOUT,1001) (DUDG(J),J=1,NTGRD)        
        WRITE(IOUT,*) 'FLUX(I)'
        WRITE(IOUT,1001) (FLUX(J),J=1,NTGRD)
        WRITE(IOUT,*) 'DFDT(I)'
        WRITE(IOUT,1001) (DFDT(J),J=1,NTGRD)
      END IF
C      
      DFDG = 0.D0
      DO I=1,NTGRD
        DFDG(I,I) = -D
      ENDDO
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'DFDG'
        DO I=1,NTGRD
          WRITE(IOUT,1001) (DFDG(I,J),J=1,NTGRD)
        END DO
      END IF
C
      CALL KNT(ANT,DANTDE,EBAR,PROPS,NPROPS)
      THETAL  = CL/(BETA*ANL)
      THETAT  = CT/(ALPHA*ANT)
C
C*** change order of magnitude of heat equation to avoid zero heat flux in solver
C*** default value of SFD = 1.D0 in cases where we have no zero heat flux in solver
      U    = U*SFD
      DUDT = DUDT*SFD
      DUDG = DUDG*SFD
      FLUX = FLUX*SFD
      DFDT = DFDT*SFD
      DFDG = DFDG*SFD
C
C*** update state variables
      STATEV(3) = CL
      call MutexLock(7)   ! lock Mutex #7
      STATEV(5) = GRADP(NOEL,NPT,1)
      STATEV(6) = GRADP(NOEL,NPT,2)
      call MutexUnlock(7) ! unlock Mutex #7
      STATEV(7) = CL + CT
      STATEV(21) = U
      STATEV(24) = THETAL
      STATEV(25) = THETAT
C
 1001 FORMAT(1P8E13.5)
 1002 FORMAT(10I5)
      END
C
C***********************************************************************
C
      SUBROUTINE UMAT(STRESS,STATEV,DDSDDE,SSE,SPD,SCD,
     + RPL,DDSDDT,DRPLDE,DRPLDT,
     + STRAN,DSTRAN,TIME,DTIME,TEMP,DTEMP,PREDEF,DPRED,CMNAME,
     + NDI,NSHR,NTENS,NSTATV,PROPS,NPROPS,COORDS,DROT,PNEWDT,
     + CELENT,DFGRD0,DFGRD1,NOEL,NPT,LAYER,KSPT,KSTEP,KINC)
C
C
C*** UMAT is called before UMATHT (if a UMATHT is used in the analysis)
C
C     DAMAGE MODEL WITH HYDROGEN EFFECTS.
C     If EXPO>50, then perfect plasticity is assumed.
C
C
      use ktransfer
      INCLUDE 'ABA_PARAM.INC'
      include 'SMAAspUserSubroutines.hdr'
      CHARACTER*8 CMNAME
C
      DIMENSION STRESS(NTENS),STATEV(NSTATV),
     + DDSDDE(NTENS,NTENS),DDSDDT(NTENS),DRPLDE(NTENS),
     + STRAN(NTENS),DSTRAN(NTENS),TIME(2),PREDEF(1),DPRED(1),
     + PROPS(NPROPS),COORDS(3),DROT(3,3),DFGRD0(3,3),DFGRD1(3,3),
     + AUXF(3,3),DEBARDE(NTENS)
C
C*** For 2D problems : QMX(4,4)
C*** For 3D problems : QMX(6,6)
C
      DIMENSION QMX(kxmtrx,kxmtrx)
C      
      DIMENSION DEDEV(6),SDEVT(6),SEL(6),SDEV(6),AN(6),STRESST(6),
     + AA(6)
C
      DIMENSION DETENS(3,3),DE(6),DROTTRAN(3,3),R(3,3)
C      
      DIMENSION xc(kxnodel),yc(kxnodel),zc(kxnodel),pn(kxnodel)
C
C*** STATE VARIABLES
C
C STATEV(1)  = EBAR     (EQUIVALENT PLASTIC STRAIN)
C STATEV(2)  = YFLAG    (0 = ELASTICITY,   1 = PLASTICITY)
C STATEV(3)  = CL       (LATTICE HYDROGEN CONCENTRATION - COMES FROM SOLUTION OF THERMAL PROBLEM)
C STATEV(4)  = CT       (TRAP HYDROGEN CONCENTRATION)
C STATEV(5)  = GRADPX   (X-COMPONENT OF PRESSURE GRADIENT GRADP)
C STATEV(6)  = GRADPY   (Y-COMPONENT OF PRESSURE GRADIENT GRADP)
C STATEV(7)  = CL + CT  (TOTAL HYDROGEN CONCENTRATION)
C STATEV(8)  = CL0      (INITIAL LATTICE CONCENTRATION USED FOR THE CALCULATION OF U)
C STATEV(9)  = DD       (DUCTILE DAMAGE VARIABLE)
C STATEV(10) = AIDD     (DUCTILE DAMAGE INDICATOR - 1 = DD HAS INITIATED)
C STATEV(11) = DFLAG    (FLAG FOR DUCTILE DAMAGE INIATION - 1 = DD HAS INITIATED)
C STATEV(12) = AIF      (FAILURE INDICATOR - 1 = COMPLETE FAILURE HAS OCCURED)
C STATEV(13) = FFLAG    (FLAG FOR FAILURE - 0 = COMPLETE FAILURE HAS OCCURED)
C STATEV(14) = SYI      (YIELD STRESS AT FAILURE)
C STATEV(15) = ETA      (STRESS TRIAXIALITY)
C STATEV(16) = THETADEG (LODE ANGLE IN DEGREES)
C STATEV(17) = QETA     (INCREMENTAL STRESS TRIAXIALITY - USED FOR CALCULATION OF AVGETA)   
C STATEV(18) = QTHETA   (INCREMENTAL LODE ANGLE - USED FOR CALCULATION OF AVGTHETA)
C STATEV(19) = DCR      (CRITICAL VALUE FOR DUCTILE DAMAGE PARAMETER)
C STATEV(20) = PDD      (=DD)
C STATEV(21) = U        (INTERNAL ENERGY, STORED IN UMATHT)
C STATEV(22) = YIELD    (FLOW STRESS FOR DAMAGED MATERIAL - YIELD = (1-DD)*SYUNDMG)
C STATEV(23) = RHO      (CURRENT DENSITY)
C STATEV(24) = THETAL   (RATIO OF THE OCCUPIED LATTICE SITES TO THE TOTAL AVAILABLE)
C STATEV(25) = THETAT   (RATIO OF THE OCCUPIED TRAP SITES TO THE TOTAL AVAILABLE)
C STATEV(26) = DDH      (HYDROGEN DAMAGE)
C STATEV(27) = AMU      (CHEMICAL POTENTIAL)
C STATEV(28) = SYD      (PLASTICITY DAMAGE FACTOR (1-DD)*SIGMAYSMALL IN FLOW STRESS)
C STATEV(29) = DCOMB    (TOTAL DAMAGE DUE TO COMBINED DAMAGE MECHANISMS)
C
C STATEV (3), (5)-(8), (21) & (24), (25) are updated in UMATHT
C
C
C*** PROPERTIES:
C      
C PROPS(1)  = YOUNG'S MODULUS (E)
C PROPS(2)  = POISSON'S RATIO (ANU)
C PROPS(3)  = INITIAL YIELD STRESS (SIG0)
C PROPS(4)  = HARDENING EXPONENT (EXPO)
C PROPS(5)  = SIG0/E
C PROPS(6)  = NORMALIZING CONCENTRATION (C0)
C PROPS(7)  = LATTICE DIFUSION CONSTANT (D)
C PROPS(8)  = PARTIAL MOLAR VOLUME OF HYDROGEN (VH)
C PROPS(9)  = EQUILIBRIUM CONSTANT (KT)
C PROPS(10) = H ATOMS/TRAP (ALPHA)
C PROPS(11) = NUMBER OF HOST ATOMOS/LATTICE VOLUME (ANL)      
C PROPS(12) = NILS PER HOST ATOM (BETA)
C PROPS(13) = CONSTANT LAMBDA   
C PROPS(14) = CLEAVAGE PLASTIC STRAIN (EPCL)
C PROPS(15) = CRITICAL CLEAVAGE STRESS (SC)
C PROPS(16) - PROPS(19) = CONSTANTS FOR EPI (C1-C4)
C PROPS(20) = CRITICAL STRESS TRIAXIALITY (ETAC)
C PROPS(21) = MATERIAL PARAMETER GF
C PROPS(22) - PROPS(25) = CONSTANTS FOR DCR (C1-C4)
C PROPS(26) = INITIAL DENSITY RHO0
C PROPS(27) = HYDROGEN JUMP FREQUENCY (ALFREQ)
C PROPS(28) = SCALE FACTOR FOR DIFFUSION PROBLEM IN CASE OF ZERO HEAT FLUX (SFD - DEFAULT=1.D0)
C
      IWR=0
      IOUT=7 !IOUT=7 WRITES ON THE .msg FILE
C      IF (NOEL.EQ.100.AND.NPT.EQ.1) IWR=1
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) '----------------------------'  
        WRITE(IOUT,*) ' CALCULATIONS IN UMAT BEGIN'
        WRITE(IOUT,*) '----------------------------'  
        WRITE(IOUT,*) ' KSTEP, KINC'
        WRITE(IOUT,1002) KSTEP,KINC
        WRITE(IOUT,*) ' STEP-TIME, TOTAL-TIME, DTIME'
        WRITE(IOUT,1001) TIME(1),TIME(2),DTIME
        WRITE(IOUT,*) ' NOEL, NPT'
        WRITE(IOUT,1002) NOEL,NPT
      END IF
C
      PI = 4.D0*DATAN(1.D0)
C
      E       = PROPS(1)
      ANU     = PROPS(2)
      SIG0    = PROPS(3)
      EXPO    = PROPS(4)
      E0      = PROPS(5)
      C0      = PROPS(6)
      VH      = PROPS(8)
      AKT     = PROPS(9)
      ALPHA   = PROPS(10)
      ANL     = PROPS(11)
      BETA    = PROPS(12)
      ALAMBDA = PROPS(13)
      EPCL    = PROPS(14)
      SC      = PROPS(15)
      C1      = PROPS(16)
      C2      = PROPS(17)
      C3      = PROPS(18)
      C4      = PROPS(19)
      ETAC    = PROPS(20)
      GF      = PROPS(21)
      D1      = PROPS(22)
      D2      = PROPS(23)
      D3      = PROPS(24)
      D4      = PROPS(25)
      RHO0    = PROPS(26)
      SFD     = PROPS(28)
      P00     = PROPS(29)
      AMU0    = PROPS(30)
C      
      G    = E/(2.D0*(1.D0+ANU))
      AK   = E/(3.D0*(1.D0-2.D0*ANU))
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*)   'E,ANU,SIG0,EXPO,E0,C0,ANL,ALAMBDA'
        WRITE(IOUT,1001) E,ANU,SIG0,EXPO,E0,C0,ANL,ALAMBDA
        WRITE(IOUT,*)   'G,AK'
        WRITE(IOUT,1001) G,AK
      END IF
C
      EBART    = STATEV(1)
      YFLAG    = STATEV(2)
      CLT      = STATEV(3)
      CTT      = STATEV(4)
      AIDDT    = STATEV(10) 
      DFLAG    = STATEV(11)
      AIFT     = STATEV(12) 
      FFLAG    = STATEV(13)
      SYI      = STATEV(14)
      ETAT     = STATEV(15)
      THETADEGT= STATEV(16)
      THETARADT= THETADEGT*PI/180.D0
      QETAT    = STATEV(17)
      QTHETAT  = STATEV(18)
      DCRT     = STATEV(19)
      PDDT     = STATEV(20)
      DCOMBT   = STATEV(29)
C
      CLT = TEMP
      DCL = DTEMP
      CL = CLT + DCL
C
      IF (CL.LT.1.D-6)  THEN
        CL=1.D-6
        IF (IWR.NE.0) THEN
          WRITE(6,*) 'CL NEGATIVE'
          WRITE(6,*) 'NOEL, NPT, KSTEP, KINC'
          WRITE(6,1002) NOEL,NPT,KSTEP,KINC
        END IF
      END IF
C
C         
C*** Provision in order to avoid storing random values at the end of the increment for these variables
C*** In KDAMAGE there might be cases where these are not updated in certain if statements
C
      DCOMB = DCOMBT
      PDD   = PDDT
      DD    = PDD
      AIF   = AIFT
      AIDD  = AIDDT
      DDAMDEBAR = 0.D0
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'EBART, YFLAG, CLT, CTT'
        WRITE(IOUT,1001) EBART, YFLAG, CLT, CTT
      END IF
C
C*** stresses at start of increment
      STRESST = STRESS
C
C*** remove Hughes-Winget rotation
      DROTTRAN = TRANSPOSE(DROT)
      CALL KROTSTRS(STRESST,DROTTRAN,QMX,NTENS)
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'STRESSES WITH HUGHES-WINGET ROTATION REMOVED'
        WRITE(IOUT,1001) (STRESST(I), I=1,NTENS)
      END IF
C
C*** CALCULATE MAXIMUM STRESS AND AVGETA, AVGTHETA
C
      CALL KPRINCIPAL(STRESST,PS1,NDI,NSHR,NTENS)
C
      THETABART = -(6.D0*THETARADT)/PI
C
      IF (EBART.NE.0.D0) THEN
        AVGETA = QETAT/EBART
        AVGTHETA = QTHETAT/EBART
      ELSE
        AVGETA = 0.D0
        AVGTHETA = 0.D0
      END IF
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'PRINCIPAL STRESS 1'
        WRITE(IOUT,1001) PS1
        WRITE(IOUT,*) 'AVGETA, AVGTHETA'
        WRITE(IOUT,1001) AVGETA, AVGTHETA
      END IF 
C
      IF (KINC.EQ.1) THEN
C*** form elastic stiffness
        Z1 = 2.D0*G
        Z2 = 3.D0*AK
        DO I=1,NTENS
        DO J=1,NTENS
          CEL(I,J) = Z1*AKMX(I,J) + Z2*AJMX(I,J)
        END DO
        END DO
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'CEL'
          DO I=1,NTENS
            WRITE(IOUT,1001) (CEL(I,J),J=1,NTENS)
          END DO
        END IF
      END IF
C
      IF (KSTEP.EQ.1.AND.KINC.EQ.1) THEN
C*** form c_0
        EBAR0 = 0.D0
        CALL KNT(ANT,DANTDE,EBAR0,PROPS,NPROPS)
        CLT   = STATEV(3)
        CTT   = (ALPHA*ANT)/(1.D0 + (BETA*ANL)/(AKT*CLT)) ! CT Calculated from Steady State Value Here
        STATEV(4) = CTT
      END IF
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'DFGRD0'
        DO I=1,3
          WRITE(IOUT,1001) (DFGRD0(I,J),J=1,3)
        ENDDO
        WRITE(IOUT,*) 'DFGRD1'
        DO I=1,3
          WRITE(IOUT,1001) (DFGRD1(I,J),J=1,3)
        ENDDO
      END IF
C
C*** CALCULATE CURRENT DENSITY RHO
C
      AUXF  = DFGRD1
      AJDET = AUXF(1,1)*(AUXF(2,2)*AUXF(3,3) - AUXF(3,2)*AUXF(2,3))
     +      - AUXF(1,2)*(AUXF(2,1)*AUXF(3,3) - AUXF(3,1)*AUXF(2,3))
     +      + AUXF(1,3)*(AUXF(2,1)*AUXF(3,2) - AUXF(3,1)*AUXF(2,2))
      RHO = RHO0/AJDET
C
      AUX = 0.D0
      DO I=1,3
      DO J=1,3
        AUX = AUX + DABS(DFGRD1(I,J)-DFGRD0(I,J))
      END DO
      END DO
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'norm |DFGRD1-DFGRD0|'
        WRITE(IOUT,1001) AUX
      END IF
      IF (AUX.NE.0.D0) GOTO 29
C
C
C
C
C
C*** DE=0 needs only DDSDDE and DDSDDT, DRPLDE, DRPLDT
C
      IF (YFLAG.EQ.0) THEN
C*** ELASTICITY
        DDSDDE = CEL
        DO I=1,NTENS
          DDSDDT(I) = 0.D0
          DO J=1,NTENS
            DDSDDE(I,J) = DDSDDE(I,J) + STRESST(I)*DELTA(J)
          ENDDO
        ENDDO
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'DEMAG=0, ELASTIC DDSDDE'
          DO I=1,NTENS
            WRITE(IOUT,1001) (DDSDDE(I,J),J=1,NTENS)
          ENDDO
          WRITE(IOUT,*) 'DEMAG=0, ELASTIC DDSDDT'
          WRITE(IOUT,1001) (DDSDDT(I),I=1,NTENS)
        END IF
C
        CALL KCT(CT,dCTdEP,dCTdCL,CTT,THETAL,THETAT,EBART,CL,PROPS,
     + NPROPS,DTIME)
        DRPLDT = -dCTdCL/DTIME
        DRPLDE = 0.D0
        RPL    = -(CT - CTT)/DTIME 
C
C*** change order of magnitude of heat equation to avoid zero heat flux in solver
C*** default value of SFD = 1.D0 in cases where we have no zero heat flux in solver
        DRPLDT = DRPLDT*SFD
        DRPLDE = DRPLDE*SFD
        RPL    = RPL*SFD
C
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'DEMAG=0, ELASTIC DRPLDE'
          WRITE(IOUT,1001) (DRPLDE(I),I=1,NTENS)
          WRITE(IOUT,*) 'DEMAG=0, ELASTIC DRPLDT'
          WRITE(IOUT,1001) DRPLDT
          WRITE(IOUT,*) 'DEMAG=0, RPL'
          WRITE(IOUT,1001) RPL     
        END IF
C
      ELSE
C
C*** PLASTICITY
        CALL KINVAR(STRESST,PT,SBAR,NDI,NSHR,NTENS)
        AUX = 1.5D0/SBAR
        CALL KVDEV(STRESST,SDEV,NDI,NSHR,NTENS)
        DO I=1,NTENS
          AN(I) = AUX*SDEV(I)
        END DO
C
        EBAR = EBART
        CALL KYCURVE(YIELD,H,HC,DD,EBAR,CLT,EXPO,E0,SIG0,PROPS,NPROPS,
     + ETAT,AVGETA,AVGTHETA,PS1,PDDT,AIDDT,EBART,AIDD,PDD,SYI,EPCL,SC,
     + C1,C2,C3,C4,ETAC,GF,D1,D2,D3,D4,DFLAG,AIFT,AIF,FFLAG,DCRT,DCR,
     + CTT,DTIME,IWR,IOUT,DDH,SYD,DCOMB)
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'EBART, YIELD, HT, HCT, DD, DDH, DCOMB'
          WRITE(IOUT,1001) EBART, YIELD, H, HC, DD, DDH, DCOMB
        END IF
C
        CALL KCT(CT,dCTdEP,dCTdCL,CTT,THETAL,THETAT,EBAR,CL,PROPS,
     + NPROPS,DTIME)
        AEL = 3.D0*G + H + HC*dCTdEP
        DO I=1,NTENS
          AA(I) = (2.D0*G*AN(I))/AEL
        END DO
        AB  = (HC*(1.D0 + dCTdCL))/AEL
C
        DO I=1,NTENS
        DO J=1,NTENS
          DDSDDE(I,J) = CEL(I,J) - 2.D0*G*AN(I)*AA(J)
        END DO
        END DO
        DO I=1,NTENS
        DO J=1,NTENS
          DDSDDE(I,J) = DDSDDE(I,J) + STRESST(I)*DELTA(J)
        ENDDO
        ENDDO
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'DEMAG=0, PLASTIC DDSDDE'
          DO I=1,NTENS
            WRITE(IOUT,1001) (DDSDDE(I,J),J=1,NTENS)
          ENDDO
        END IF
C
        DO I=1,NTENS
          DDSDDT(I) = 2.D0*G*AB*AN(I)
        END DO
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'DEMAG=0, PLASTIC DDSDDT'
          WRITE(IOUT,1001) (DDSDDT(I),I=1,NTENS)
        END IF
C
        DEBARDCL = -AB
        DO I=1,NTENS
          DEBARDE(I) = AA(I)
        END DO
        DRPLDT = -(dCTdCL + dCTdEP*DEBARDCL)/DTIME
        DO I=1,NTENS
          DRPLDE(I) = -(dCTdEP*DEBARDE(I))/DTIME
        END DO
        RPL    = -(CT - CTT)/DTIME 
C
C*** change order of magnitude of heat equation to avoid zero heat flux in solver
C*** default value of SFD = 1.D0 in cases where we have no zero heat flux in solver
        DRPLDT = DRPLDT*SFD
        DRPLDE = DRPLDE*SFD
        RPL    = RPL*SFD
C
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'DEMAG=0, PLASTIC DRPLDE'
          WRITE(IOUT,1001) (DRPLDE(I),I=1,NTENS)
          WRITE(IOUT,*) 'DEMAG=0, PLASTIC DRPLDT'
          WRITE(IOUT,1001) DRPLDT
          WRITE(IOUT,*) 'DEMAG=0, RPL'
          WRITE(IOUT,1001) RPL     
        END IF
C
      END IF
C
      GOTO 9999
C
C
C
C
C
C
 29   CONTINUE
C
C*** INTEGRATE ELASTOPLASTIC EQUATIONS
C
C*** Calculate pressure gradient
C
      xc=0.D0
      yc=0.D0
      zc=0.D0
C        
      IF (TIME(1).GT.0.D0) THEN
        call MutexLock(8)   ! lock Mutex #8
        DO inode=1,kxnodel
          xc(inode) = coorT(IELCONN(noel,inode),1)
          yc(inode) = coorT(IELCONN(noel,inode),2)
          IF (kxdim.gt.2) zc(inode) = coorT(IELCONN(noel,inode),3)
        ENDDO
        DO i=1,kxnodel
          pn(i) = PNODAL(IELCONN(noel,i))
        ENDDO
        IF (kxdim.eq.2) THEN
            CALL KGRADP2D(noel,xc,yc,pn,npt)
        ELSE
            CALL KGRADP3D(noel,xc,yc,zc,pn,npt)
        END IF
        call MutexUnlock(8) ! unlock Mutex #8
      END IF
C
C*** find logarithmic strain tensor DETENS and
C    rotation tensor R associated with the increment
      CALL KELOGR(DFGRD0,DFGRD1,DETENS,R)
      DEKK = DETENS(1,1) + DETENS(2,2) + DETENS(3,3)
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'LOGARITHMIC STRAIN TENSOR DETENS'
        DO I=1,3
          WRITE(IOUT,1001) (DETENS(I,J),J=1,3)
        ENDDO
        WRITE(IOUT,*) 'DEKK'
        WRITE(IOUT,1001) DEKK
        WRITE(IOUT,*) 'ROTATION TENSOR R'
        DO I=1,3
          WRITE(IOUT,1001) (R(I,J),J=1,3)
        ENDDO
      END IF
C
      CALL KTTOV(DETENS,DE,NDI,NSHR,NTENS)
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'DE VECTOR (TENSOR SHEAR COMPONENTS)'
        WRITE(IOUT,1001) (DE(I),I=1,NTENS)
      END IF
C
      DEMAG = 0.D0
      DO I=1,NDI
        DEMAG = DEMAG + DE(I)*DE(I)
      END DO
      DO I=1,NSHR
        DEMAG = DEMAG + 2.D0*DE(NDI+I)*DE(NDI+I)
      END DO
      DEMAG = DSQRT(2.D0*DEMAG/3.D0)
      DETOL = DEMAG*1.D-6
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'DEMAG'
        WRITE(IOUT,1001) DEMAG
        WRITE(IOUT,*) 'DETOL'
        WRITE(IOUT,1001) DETOL
      END IF
C
C*** find p and sigma_e at the start of the increment
      CALL KINVAR(STRESST,PT,SBART,NDI,NSHR,NTENS)
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'EBART, PT, SBART'
        WRITE(IOUT,1001) EBART, PT, SBART
      END IF
C
      DP = AK*DEKK
      P  = PT + DP
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'DP, P'
        WRITE(IOUT,1001) DP, P
      END IF
C
      CALL KVDEV(STRESST,SDEVT,NDI,NSHR,NTENS)
      CALL KVDEV(DE,DEDEV,NDI,NSHR,NTENS)
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'DEDEV'
        WRITE(IOUT,1001) (DEDEV(I),I=1,NTENS)
        WRITE(IOUT,*) 'SDEVT'
        WRITE(IOUT,1001) (SDEVT(I),I=1,NTENS)
      END IF
C
      DO I=1,NTENS
        SEL(I) = SDEVT(I) + 2.D0*G*DEDEV(I)
      END DO
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'SEL'
        WRITE(IOUT,1001) (SEL(I),I=1,NTENS)
      END IF
C
      CALL KINVAR(SEL,P0,QEL,NDI,NSHR,NTENS)
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'QEL'
        WRITE(IOUT,1001) QEL
      END IF
C
C*** check for yielding
      EBAR = EBART
      CALL KYCURVE(YIELD,H,HC,DD,EBAR,CL,EXPO,E0,SIG0,PROPS,NPROPS,
     + ETAT,AVGETA,AVGTHETA,PS1,PDDT,AIDDT,EBART,AIDD,PDD,SYI,EPCL,SC,
     + C1,C2,C3,C4,ETAC,GF,D1,D2,D3,D4,DFLAG,AIFT,AIF,FFLAG,DCRT,DCR,
     + CTT,DTIME,IWR,IOUT,DDH,SYD,DCOMB)
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'EBART, YIELD, H, HC, DD, DDH, DCOMB'
        WRITE(IOUT,1001) EBART, YIELD, H, HC, DD, DDH, DCOMB
      END IF
      IF (QEL.LE.YIELD) GOTO 1000  ! elastic increment
      IF (QEL.GT.YIELD) GOTO 2000  ! plastic increment
C
C
C
C
C
C*** ELASTICITY
C
 1000 CONTINUE
      IF (IWR.NE.0) WRITE(IOUT,*) 'ELASTICITY'
      STRESS = SEL
      DO I=1,NDI
        STRESS(I) = STRESS(I) + P
      END DO
C
      call MutexLock(9) ! lock Mutex #9
      PELEM(NOEL,NPT)=P
      call MutexUnlock(9) ! unlock Mutex #9
C
C***  rotate stresses
      CALL KROTSTRS(STRESS,R,QMX,NTENS)
      CALL KSLODE(ETA,THETADEG,STRESS,SIG0,NDI,NTENS)
C      
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'STRESS'
        WRITE(IOUT,1001) (STRESS(I),I=1,NTENS)
        WRITE(IOUT,*) 'THETA AFTER ROTATION IN DEGREES'
        WRITE(IOUT,1001) XLODE
      END IF
C
      CALL KCT(CT,dCTdEP,dCTdCL,CTT,THETAL,THETAT,EBART,CL,PROPS,
     + NPROPS,DTIME)
C
*** calculate chemical potential for visualization purposes
      AMU = AMU0 + DLOG(CL) - (P - P00)*VH
C
C*** update state variables
      STATEV(2)  = 0.D0
      STATEV(4)  = CT
      STATEV(9)  = DD       
      STATEV(10) = AIDD     
      STATEV(11) = DFLAG   
      STATEV(12) = AIF      
      STATEV(13) = FFLAG    
      STATEV(14) = SYI      
      STATEV(15) = ETA     
      STATEV(16) = THETADEG
      STATEV(19) = DCR
      STATEV(20) = PDD
      STATEV(22) = YIELD
      STATEV(23) = RHO
      STATEV(26) = DDH
      STATEV(27) = AMU
      STATEV(28) = SYD
      STATEV(29) = DCOMB
C
C*** update energies
      SSE = QEL*QEL/(6.D0*G) + P*P/(2.D0*AK)
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'ELASTIC STRAIN ENERGY'
        WRITE(IOUT,1001) SSE
      END IF
C
C*** elastic Jacobian
      DDSDDE = CEL
      DO I=1,NTENS
        DDSDDT(I) = 0.D0
        DO J=1,NTENS
          DDSDDE(I,J) = DDSDDE(I,J) + STRESS(I)*DELTA(J)
        ENDDO
      ENDDO
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'ELASTIC DDSDDE'
        DO I=1,NTENS
          WRITE(IOUT,1001) (DDSDDE(I,J),J=1,NTENS)
        END DO
        WRITE(IOUT,*) 'ELASTIC DDSDDT'
        WRITE(IOUT,1001) (DDSDDT(I),I=1,NTENS)
      END IF
C
      RPL    = -(CT - CTT)/DTIME 
      DRPLDT = -dCTdCL/DTIME
      DRPLDE = 0.D0
C
C*** change order of magnitude of heat equation to avoid zero heat flux in solver
C*** default value of SFD = 1.D0 in cases where we have no zero heat flux in solver
      DRPLDT = DRPLDT*SFD
      DRPLDE = DRPLDE*SFD
      RPL    = RPL*SFD
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'ELASTIC DRPLDE'
        WRITE(IOUT,1001) (DRPLDE(I),I=1,NTENS)
        WRITE(IOUT,*) 'ELASTIC DRPLDT'
        WRITE(IOUT,1001) DRPLDT
        WRITE(IOUT,*) 'RPL'
        WRITE(IOUT,1001) RPL     
      END IF
C
      GOTO 8888
C
C
C
C
C
C*** PLASTICITY
C
 2000 CONTINUE
      IF (IWR.NE.0) WRITE(IOUT,*) 'PLASTICITY'
C
C*** determine DEBAR
      EBAR = EBART
      CALL KYCURVE(YIELD,H,HC,DD,EBAR,CL,EXPO,E0,SIG0,PROPS,NPROPS,
     + ETAT,AVGETA,AVGTHETA,PS1,PDDT,AIDDT,EBART,AIDD,PDD,SYI,EPCL,SC,
     + C1,C2,C3,C4,ETAC,GF,D1,D2,D3,D4,DFLAG,AIFT,AIF,FFLAG,DCRT,DCR,
     + CTT,DTIME,IWR,IOUT,DDH,SYD,DCOMB)
      DEBAR = (QEL - YIELD)/(3.D0*G + H)
      EBAR  = EBART + DEBAR
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'FIRST ESTIMATE FOR DEBAR, EBAR'
        WRITE(IOUT,1001) DEBAR,EBAR
      END IF
C
C***  Newton loop for DEBAR
      TOL = SIG0*1.D-4
      DO ILOOP=1,20
        CALL KYCURVE(YIELD,H,HC,DD,EBAR,CL,EXPO,E0,SIG0,PROPS,NPROPS,
     + ETAT,AVGETA,AVGTHETA,PS1,PDDT,AIDDT,EBART,AIDD,PDD,SYI,EPCL,SC,
     + C1,C2,C3,C4,ETAC,GF,D1,D2,D3,D4,DFLAG,AIFT,AIF,FFLAG,DCRT,DCR,
     + CTT,DTIME,IWR,IOUT,DDH,SYD,DCOMB)
        FQ = QEL - 3.D0*G*DEBAR - YIELD
        IF (DABS(FQ).LT.TOL) GOTO 2011
        FP = - 3.D0*G - H
        DDE = - FQ/FP
        DEBAR = DEBAR + DDE
        EBAR = EBART + DEBAR
        IF (IWR.NE.0) THEN
          WRITE(IOUT,*) 'FQ, FP'
          WRITE(IOUT,1001) FQ, FP
        END IF
      END DO
      WRITE(IOUT,*) 'NEWTON LOOP DOES NOT CONVERGE. PNEWDT SET TO 0.5.'
      WRITE(IOUT,*) 'NOEL, NPT, KSTEP, KINC'
      WRITE(IOUT,1002) NOEL,NPT,KSTEP,KINC
      PNEWDT = 0.5D0
      RETURN
C
 2011 CONTINUE
      IF (IWR.NE.0)THEN
        WRITE(IOUT,*) 'NEWTON ITERATIONS FOR DE = ', ILOOP 
        WRITE(IOUT,*) 'DEBAR, EBAR'
        WRITE(IOUT,1001) DEBAR, EBAR
      END IF
C
      AUX = 1.5D0/QEL
      DO I=1,NTENS
        AN(I) = AUX*SEL(I)
      END DO
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'AN'
        WRITE(IOUT,1001) (AN(I),I=1,NTENS)
      END IF
C
      DO I=1,NTENS
        SDEV(I) = SEL(I) - 2.D0*G*DEBAR*AN(I)
      END DO
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'SDEV'
        WRITE(IOUT,1001) (SDEV(I),I=1,4)
      END IF
C
      call MutexLock(10) ! lock Mutex #10
      PELEM(NOEL,NPT)=P
      call MutexUnlock(10) ! unlock Mutex #10
C
      STRESS = SDEV
      DO I=1,NDI
        STRESS(I) = STRESS(I) + P
      END DO
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'STRESS'
        WRITE(IOUT,1001) (STRESS(I),I=1,NTENS)
      END IF
C
C*** rotates stresses and "nornal" tensor AN
      CALL KROTSTRS(STRESS,R,QMX,NTENS)
      CALL KROTSTRS(AN,    R,QMX,NTENS)
      CALL KSLODE(ETA,THETADEG,STRESS,SIG0,NDI,NTENS)
      THETARAD = THETADEG*PI/180.D0
      THETABAR = -(6.D0*THETARAD)/PI
      QETA    = QETAT + 0.5D0*(ETA + ETAT)*(EBAR-EBART)
      QTHETA  = QTHETAT + 0.5D0*(THETABAR + THETABART)*(EBAR-EBART)
C      
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'ROTATED STRESS VECTOR'
        WRITE(IOUT,1001) (STRESS(I),I=1,NTENS)
        WRITE(IOUT,*) 'ROTATED AN VECTOR'
        WRITE(IOUT,1001) (AN(I),I=1,NTENS)
      END IF
C
      CALL KCT(CT,dCTdEP,dCTdCL,CTT,THETAL,THETAT,EBAR,CL,PROPS,
     + NPROPS,DTIME)
C
*** calculate chemical potential for visualization purposes
      AMU = AMU0 + DLOG(CL) - (P - P00)*VH
C
C*** update state variables
      STATEV(1)  = EBAR
      STATEV(2)  = 1.D0
      STATEV(4)  = CT
      STATEV(9)  = DD      
      STATEV(10) = AIDD    
      STATEV(11) = DFLAG    
      STATEV(12) = AIF      
      STATEV(13) = FFLAG   
      STATEV(14) = SYI   
      STATEV(15) = ETA      
      STATEV(16) = THETADEG 
      STATEV(17) = QETA       
      STATEV(18) = QTHETA
      STATEV(19) = DCR
      STATEV(20) = PDD
      STATEV(22) = YIELD
      STATEV(23) = RHO
      STATEV(26) = DDH
      STATEV(27) = AMU
      STATEV(28) = SYD
      STATEV(29) = DCOMB
C
C*** update energies
      SSE = YIELD*YIELD/(6.D0*G) + P*P/(2.D0*AK)
      SPD = SPD + 0.5D0*(SBART + YIELD)*DEBAR
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*)'ELASTIC STRAIN ENERGY, PLASTIC DISSIPATION'
        WRITE(IOUT,1001) SSE,SPD
      END IF
C
C*** plastic Jacobians
      IF (IWR.NE.0) WRITE(IOUT,*) 'PLASTIC JACOBIANS'
C
      AEL = 3.D0*G + H + HC*dCTdEP
      DO I=1,NTENS
        AA(I) = (2.D0*G*AN(I))/AEL
      END DO
      AB  = (HC*(1.D0 + dCTdCL))/AEL
C
      AUX = 4.D0*G*G*DEBAR/QEL
      DO I=1,NTENS
      DO J=1,NTENS
        DDSDDE(I,J) = CEL(I,J) - 2.D0*G*AN(I)*AA(J) -
     +                AUX*( 1.5D0*AKMX(I,J) - AN(I)*AN(J) )
      END DO
      END DO
      DO I=1,NTENS
      DO J=1,NTENS
        DDSDDE(I,J) = DDSDDE(I,J) + STRESST(I)*DELTA(J)
      ENDDO
      ENDDO
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'PLASTIC DDSDDE'
        DO I=1,NTENS
          WRITE(IOUT,1001) (DDSDDE(I,J),J=1,NTENS)
        ENDDO
      END IF
C
      DO I=1,NTENS
        DDSDDT(I) = 2.D0*G*AB*AN(I)
      END DO
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'PLASTIC DDSDDT'
        WRITE(IOUT,1001) (DDSDDT(I),I=1,NTENS)
      END IF
C
      DEBARDCL = -AB
      DO I=1,NTENS
        DEBARDE(I) = AA(I)
      END DO
      DRPLDT = -(dCTdCL + dCTdEP*DEBARDCL)/DTIME
      DO I=1,NTENS
        DRPLDE(I) = -(dCTdEP*DEBARDE(I))/DTIME
      END DO
      RPL    = -(CT - CTT)/DTIME 
C
C*** change order of magnitude of heat equation to avoid zero heat flux in solver
C*** default value of SFD = 1.D0 in cases where we have no zero heat flux in solver
      DRPLDT = DRPLDT*SFD
      DRPLDE = DRPLDE*SFD
      RPL    = RPL*SFD
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*) 'PLASTIC DRPLDE'
        WRITE(IOUT,1001) (DRPLDE(I),I=1,NTENS)
        WRITE(IOUT,*) 'PLASTIC DRPLDT'
        WRITE(IOUT,1001) DRPLDT
        WRITE(IOUT,*) 'RPL'
        WRITE(IOUT,1001) RPL     
      END IF
C
C
C
C
C
 8888 CONTINUE
C
C
C
C
 9999 CONTINUE
C
 1001 FORMAT(1P8E13.5)
 1002 FORMAT(10I5)
      END
C
C***********************************************************************
C
      SUBROUTINE KINVAR(S,P,Q,NDI,NSHR,NTENS)
C
C*** computes hydrosratic stress P and von Mises equivalent stress Q
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
      DIMENSION S(NTENS),SDEV(6)
C
      P = 0.D0
      DO I=1,NDI
        P = P + S(I)
      END DO
      P = P/3.D0
C
      SDEV(1:NTENS) = S(1:NTENS)
      DO I=1,NDI
        SDEV(I) = SDEV(I) - P
      END DO
      AUX = 0.D0
      DO I=1,NDI
        AUX = AUX + SDEV(I)*SDEV(I)
      END DO
      DO I=NDI+1,NTENS
        AUX = AUX + 2.D0*SDEV(I)*SDEV(I)
      END DO
      Q = DSQRT(1.5D0*AUX)
C
      END
C
C***********************************************************************
C
      SUBROUTINE KINV3X3(A,AINV)
C
C*** inverts 3x3 matrix
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
      DIMENSION A(3,3),AINV(3,3)
C
      DET=  A(1,1)*(A(2,2)*A(3,3) - A(3,2)*A(2,3))
     +    - A(1,2)*(A(2,1)*A(3,3) - A(3,1)*A(2,3))
     +    + A(1,3)*(A(2,1)*A(3,2) - A(3,1)*A(2,2))
C
      AINV(1,1) = (A(2,2)*A(3,3) - A(2,3)*A(3,2))/DET
      AINV(1,2) =-(A(1,2)*A(3,3) - A(3,2)*A(1,3))/DET
      AINV(1,3) = (A(1,2)*A(2,3) - A(2,2)*A(1,3))/DET
      AINV(2,1) =-(A(2,1)*A(3,3) - A(3,1)*A(2,3))/DET
      AINV(2,2) = (A(1,1)*A(3,3) - A(3,1)*A(1,3))/DET
      AINV(2,3) =-(A(1,1)*A(2,3) - A(2,1)*A(1,3))/DET
      AINV(3,1) = (A(2,1)*A(3,2) - A(3,1)*A(2,2))/DET
      AINV(3,2) =-(A(1,1)*A(3,2) - A(3,1)*A(1,2))/DET
      AINV(3,3) = (A(1,1)*A(2,2) - A(2,1)*A(1,2))/DET
C
      END
C
C***********************************************************************
C
      SUBROUTINE KTTOV(T,V,NDI,NSHR,NTENS)
C
C*** converts tensor T (3x3) to vector V (NTENSx1)
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
      DIMENSION T(3,3),V(1)
C
      DO I=1,NDI
        V(I) = T(I,I)
      END DO
      DO I=1,NSHR
        IF (I.EQ.1) AUX = T(1,2)
        IF (I.EQ.2) AUX = T(1,3)
        IF (I.EQ.3) AUX = T(2,3)
        V(NDI+I) = AUX
      END DO
C
      END
C
C***********************************************************************
C
      SUBROUTINE KVDEV(A,ADEV,NDI,NSHR,NTENS)
C
C*** computes deviatoric part of tensor A in vector form (NTENSx1)
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
      DIMENSION A(NTENS),ADEV(NTENS)
C
      P = 0.D0
      DO I=1,NDI
        P = P + A(I)
      END DO
      P = P/3.D0
C
      ADEV(1:NTENS) = A(1:NTENS)
      DO I=1,NDI
        ADEV(I) = ADEV(I) - P
      END DO
C
      END
C
C***********************************************************************
C
      SUBROUTINE KMULT(A,B,C,L,M,N)
C
C*** computes product of two matrices C = A*B
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
      DIMENSION A(L,M),B(M,N),C(L,N)
C
      DO I=1,L
      DO J=1,N
        AUX = 0.D0
        DO K=1,M
          AUX = AUX + A(I,K)*B(K,J)
        END DO
        C(I,J) = AUX
      END DO
      END DO
C
      END
C
C***********************************************************************
C
      SUBROUTINE KROTSTRS(STRESS,R,QMX,NTENS)
C
C*** rotates stresses by rotation tensor R(3,3)
C    STRESS is stored in vector form (NTENSx1)
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
      DIMENSION STRESS(NTENS),R(3,3),QMX(NTENS,NTENS),AUX(6)
C
      QMX = 0.D0
      DO I=1,3
      DO J=1,3
        QMX(I,J) = R(I,J)**2
      ENDDO
      ENDDO
C
      QMX(1,4) = 2.D0*R(1,1)*R(1,2)
      QMX(2,4) = 2.D0*R(2,1)*R(2,2)
      QMX(3,4) = 2.D0*R(3,1)*R(3,2)
C
      QMX(4,1) = R(1,1)*R(2,1)
      QMX(4,2) = R(1,2)*R(2,2)
      QMX(4,3) = R(1,3)*R(2,3)
C
      QMX(4,4) = R(1,2)*R(2,1) + R(2,2)*R(1,1)
      IF (NTENS.EQ.4) GOTO 99
C
      QMX(1,5)=2.D0*R(1,1)*R(1,3)
      QMX(1,6)=2.D0*R(1,2)*R(1,3)
C
      QMX(2,5)=2.D0*R(2,1)*R(2,3)
      QMX(2,6)=2.D0*R(2,2)*R(2,3)
C
      QMX(3,5)=2.D0*R(3,1)*R(3,3)
      QMX(3,6)=2.D0*R(3,2)*R(3,3)
C
      QMX(4,5)=R(1,3)*R(2,1) + R(1,1)*R(2,3)
      QMX(4,6)=R(1,3)*R(2,2) + R(1,2)*R(2,3)
C
      QMX(5,1)=R(1,1)*R(3,1)
      QMX(5,2)=R(1,2)*R(3,2)
      QMX(5,3)=R(1,3)*R(3,3)
      QMX(5,4)=R(1,2)*R(3,1) + R(1,1)*R(3,2)
      QMX(5,5)=R(1,3)*R(3,1) + R(1,1)*R(3,3)
      QMX(5,6)=R(1,3)*R(3,2) + R(1,2)*R(3,3)
C
      QMX(6,1)=R(2,1)*R(3,1)
      QMX(6,2)=R(2,2)*R(3,2)
      QMX(6,3)=R(2,3)*R(3,3)
      QMX(6,4)=R(2,2)*R(3,1) + R(2,1)*R(3,2)
      QMX(6,5)=R(2,3)*R(3,1) + R(2,1)*R(3,3)
      QMX(6,6)=R(2,3)*R(3,2) + R(2,2)*R(3,3)
C
 99   CONTINUE
C
      CALL KMULT(QMX,STRESS,AUX,NTENS,NTENS,1)
      STRESS(1:NTENS) = AUX(1:NTENS)
C
      END
C
C***********************************************************************
C
      SUBROUTINE KELOGR(DFGRD0,DFGRD1,DETENS,R)
C
C*** computes the logarithmic strain tensor DETENS (3x3) and
C    rotation R tensor (3x3) associated with the increment
C    DETENS has tensor shear components (as opposed to engineering shear components)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION DFGRD0(3,3),DFGRD1(3,3),DETENS(3,3),R(3,3),WORK(6)
      DIMENSION DFGINV(3,3),DF(3,3),DFT(3,3),CC(3,3),PS(3),ANN(3,3),
     + UINV(3,3)
C
      CALL KINV3X3(DFGRD0,DFGINV)
C
      CALL KMULT(DFGRD1,DFGINV,DF,3,3,3)
C
C*** exact calculation of logarithmic strain tensor associated with DF
C
      DFT = TRANSPOSE(DF)
      CALL KMULT(DFT,DF,CC,3,3,3)
      WORK(1) = CC(1,1)
      WORK(2) = CC(2,2)
      WORK(3) = CC(3,3)
      WORK(4) = CC(1,2)
      WORK(5) = CC(1,3)
      WORK(6) = CC(2,3)
      CALL SPRIND(WORK,PS,ANN,1,3,3)
C
C*** rearrange eigenvalues PS and eigenvectors ANN so that PS(1) >= PS(2) >= PS(3)
      CALL KEKARRANGE(PS,ANN)
C
      DO I=1,3
        PS(I) = DSQRT(PS(I))
      END DO
C
      DO I=1,3
      DO J=1,3
        DETENS(I,J) = DLOG(PS(1))*ANN(1,I)*ANN(1,J) +
     +                DLOG(PS(2))*ANN(2,I)*ANN(2,J) +
     +                DLOG(PS(3))*ANN(3,I)*ANN(3,J)
C
        UINV(I,J)   = ANN(1,I)*ANN(1,J)/PS(1) +
     +                ANN(2,I)*ANN(2,J)/PS(2) +
     +                ANN(3,I)*ANN(3,J)/PS(3)
      END DO
      END DO
C
      CALL KMULT(DF,UINV,R,3,3,3)
C
      RETURN
      END
C
C***********************************************************************
C
      SUBROUTINE KEKARRANGE(PS,ANN)
C
C*** rearranges eigenvalues PS and eigenvectors ANN so that PS(1) > PS(2) > PS(3)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION PS(3),ANN(3,3),PSC(3),ANNC(3,3)
C
      PSC = PS
      ANNC = ANN
C
      IF (PS(1).GE.PS(2).AND.PS(2).GE.PS(3)) THEN
        IMAX = 1
        IINT = 2
        IMIN = 3
        GOTO 999
      END IF
C
      IF (PS(1).GE.PS(3).AND.PS(3).GE.PS(2)) THEN
        IMAX = 1
        IINT = 3
        IMIN = 2
        GOTO 999
      END IF
C
      IF (PS(2).GE.PS(1).AND.PS(1).GE.PS(3)) THEN
        IMAX = 2
        IINT = 1
        IMIN = 3
        GOTO 999
      END IF
C
      IF (PS(2).GE.PS(3).AND.PS(3).GE.PS(1)) THEN
        IMAX = 2
        IINT = 3
        IMIN = 1
        GOTO 999
      END IF
C
      IF (PS(3).GE.PS(1).AND.PS(1).GE.PS(2)) THEN
        IMAX = 3
        IINT = 1
        IMIN = 2
        GOTO 999
      END IF
C
      IF (PS(3).GE.PS(2).AND.PS(2).GE.PS(1)) THEN
        IMAX = 3
        IINT = 2
        IMIN = 1
        GOTO 999
      END IF
C
 999  CONTINUE
      PS(1) = PSC(IMAX)
      PS(2) = PSC(IINT)
      PS(3) = PSC(IMIN)
      DO I=1,3
        ANN(1,I) = ANNC(IMAX,I)
        ANN(2,I) = ANNC(IINT,I)
      END DO
C
C***  ANN3 = ANN1 x ANN2 (cross product, right-handed triad)
      ANN(3,1) =   ANN(1,2)*ANN(2,3) - ANN(2,2)*ANN(1,3)
      ANN(3,2) = -(ANN(1,1)*ANN(2,3) - ANN(2,1)*ANN(1,3))
      ANN(3,3) =   ANN(1,1)*ANN(2,2) - ANN(2,1)*ANN(1,2)
C
      END
C
C***********************************************************************
C
      SUBROUTINE KDAMAGE(DD,DDAMDEBAR,YIELD,EBAR,ETA,AVGETA,AVGTHETA,
     + PS1,PDDT,AIDDT,EBART,AIDD,PDD,SYI,EPCL,SC,C1,C2,C3,C4,ETAC,GF,D1,
     + D2,D3,D4,DFLAG,AIFT,AIF,FFLAG,DCRT,DCR,IPLDMG,IHYDRO,DDH,DCOMB,
     + IWR,IOUT)
C
C*** SUBROUTINE TO CHECK DIFFERENT KINDS OF DAMAGE AT THE MATERIAL POINT
C*** AIDD: INDICATOR FOR DUCTILE DAMAGE INITIATION (1: DUCTILE DAMAGE STARTS)
C*** AIF:  INDICATOR FOR COMPLETE LOAD-CARRYING CAPACITY LOSS
C
      INCLUDE 'ABA_PARAM.INC'
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*)
        WRITE(IOUT,*)'ENTERS KDAMAGE'
        WRITE(IOUT,*)'FLAG FOR PLASTICTY DAMAGE IPLDMG:'
        WRITE(IOUT,1002) IPLDMG
        WRITE(IOUT,*)'AIDDT,PDDT,EBAR,EBART'
        WRITE(IOUT,1001) AIDDT,PDDT,EBAR,EBART
        WRITE(IOUT,*)'C1,C2,C3,C4,D1,D2,D3,D4,SYI,GF'
        WRITE(IOUT,1001) C1,C2,C3,C4,D1,D2,D3,D4,SYI,GF
      END IF
C
      IF (IPLDMG.NE.1) THEN ! NO PLASTICITY DAMAGE (DD=0)
        AIDD = AIDDT 
        AIF  = AIFT
        PDD  = PDDT
        DD   = PDD
        DCR  = DCRT
        DDAMDEBAR = 0.D0
        GOTO 33000
      END IF
C
      IF (EBAR.LE.1.D-3.OR.FFLAG.EQ.0.D0) THEN
        AIDD = AIDDT 
        AIF  = AIFT
        PDD  = PDDT
        DD   = PDD
        DCR  = DCRT
        DDAMDEBAR = 0.D0
        GOTO 33000 
      END IF
C
C*** CALCULATE FUNCTIONS EPI AND DCR
C
      AUXEP = (C1*DEXP(-C2*AVGETA)-C3*DEXP(-C4*AVGETA))*AVGTHETA**2 + 
     +        C3*DEXP(-C4*AVGETA)
      IF (AVGETA.GT.ETAC) THEN
       EPI = AUXEP
      ELSE
       EPI = 1000.D0
      END IF
C
      AUXDD = (D1*DEXP(-D2*AVGETA)-D3*DEXP(-D4*AVGETA))*AVGTHETA**2 + 
     +        D3*DEXP(-D4*AVGETA)
      IF (AVGETA.GT.ETAC) THEN
       DCR = AUXDD
      ELSE
       DCR = 1000.D0
      END IF
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*)'AUXEP,EPI,AUXDD,DCR'
        WRITE(IOUT,1001) AUXEP,EPI,AUXDD,DCR
      END IF
C
C*** DAMAGE CHECKS BEGIN
C
C
C*** CHECK 1: CLEAVAGE FAILURE
C
      IF (EBAR.GE.EPCL.AND.PS1.GE.SC) THEN
        AIF  = 1.D0
        AIDD = 1.D0 
        FFLAG = 0.D0
        PDD = 0.995D0
        DD = PDD
        DDAMDEBAR = 0.D0
        GOTO 33000
      END IF
C
C*** CHECK 2: DUCTILE DAMAGE INITIATION
C
      AIDD = AIDDT + (EBAR - EBART)/EPI
      IF (AIDD.GE.1.D0.AND.DFLAG.NE.1.D0)  THEN
        SYI = YIELD
        DFLAG = 1.D0
      END IF
      IF (AIDD.GT.1.D0) THEN
        AIDD = 1.D0
      END IF
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*)'AIDD,SYI,DFLAG'
        WRITE(IOUT,1001) AIDD,SYI,DFLAG
      END IF
C
C*** CHECK 3: DAMAGE EVOLUTION AND DUCTILE DAMAGE FAILURE
C      
      IF (DFLAG.EQ.1.D0) THEN
        IF (ETA.GT.ETAC) THEN
          PDD = PDDT + SYI*(EBAR-EBART)/GF
          DD  = PDD
          AIF = AIFT + (PDD-PDDT)/DCR
          DDAMDEBAR = SYI/GF
        ELSE
          PDD = PDDT
          DD  = PDD
          AIF = AIFT
          DDAMDEBAR = 0.D0  
        END IF
      END IF
      IF (AIF.GE.1.D0) THEN
        AIF = 1.D0
        PDD = PDDT
        DD  = PDD
        DDAMDEBAR = 0.D0
        FFLAG = 0.D0
      END IF
C
      IF (DD.GT.0.995D0) THEN
        DD = 0.995D0
        DDAMDEBAR = 0.D0
      END IF
C
      IF (IWR.NE.0) THEN
        WRITE(IOUT,*)'AIDD,DFLAG,AIF,FFLAG,DD,DDAMDEBAR,PDD,DCR'
        WRITE(IOUT,1001) AIDD,DFLAG,AIF,FFLAG,DD,DDAMDEBAR,PDD,DCR
      END IF
C
33000 CONTINUE
C
C*** CHECK 4: IF BOTH MECHANISMS ARE ACTIVE CHECK FOR COMBINED DAMAGE FAILURE
C
      DCOMB = 1.D0 - (1.D0 - DD)*(1.D0 - DDH)
      DCOMBCRIT = 0.8D0
      IF (IPLDMG.EQ.1.AND.IHYDRO.EQ.1) THEN
        IF (DCOMB.GE.DCOMBCRIT) THEN
          FFLAG = 0.D0
        END IF
      END IF
C      
 1001 FORMAT(1P8E13.5)
 1002 FORMAT(10I5)
      END      
C
C***********************************************************************
C
      SUBROUTINE KPRINCIPAL(STRESS,PS1,NDI,NSHR,N)
C
      INCLUDE 'ABA_PARAM.INC'
C
      DIMENSION STRESS(N),PS(3),ANN(3,3)
C
      CALL SPRIND(STRESS,PS,ANN,1,3,1)
C
      CALL KEKARRANGE(PS,ANN)
C
      PS1 = PS(1)
C
      END
C
C***********************************************************************
C
      SUBROUTINE KSLODE(XS,XLODE,STRESS,SIG0,NDI,NTENS)
C
C*** CALCULATES STRESS TRIAXIALITY AND LODE ANGLE (IN DEGREES)
C
      INCLUDE 'ABA_PARAM.INC'
      DIMENSION STRESS(NTENS),STRESSD(NTENS)
C     
      PI = 4.D0*DATAN(1.D0)
      SM=(STRESS(1)+STRESS(2)+STRESS(3))/3.D0
      SIGNSM=1.D0
      IF (DABS(SM).GT.0.D0) SIGNSM=SM/DABS(SM)
C
      DO I=1,NDI
        STRESSD(I)=STRESS(I)-SM
      ENDDO            
      DO I=NDI+1,NTENS
        STRESSD(I)=STRESS(I)
      ENDDO
      SUM=0.D0
      DO I=1,NDI
        SUM=SUM+STRESSD(I)*STRESSD(I)
      ENDDO
      DO I=NDI+1,NTENS
        SUM=SUM+2.D0*STRESSD(I)*STRESSD(I)
      ENDDO
      SEQ=DSQRT(1.5D0*SUM)
C
      S11=STRESSD(1)
      S22=STRESSD(2)
      S33=STRESSD(3)
      S12=STRESSD(4)
C
      DET=0.D0
      DET=S33*(S11*S22-S12**2.D0)
      IF (NTENS.GT.4) THEN
       S13=STRESSD(5)
       S23=STRESSD(6)
       DET=-(S13**2*S22)+2*S12*S13*S23-S11*S23**2-S12**2*S33+S11*S22*S33
      END IF
C      
      XLODE=0.D0
      ALODE=0.D0
      TINY = 1.D-5*SIG0
      IF (SEQ.GT.TINY) THEN
        XS=SM/SEQ
        ALODE=-(27.D0*DET)/(2.D0*(SEQ**3.D0))
        IF (DABS(ALODE)-1.D0.GT.0.D0) THEN
          IF (ALODE.LT.-1.D0) THEN
             ALODE=-1.D0
          ELSE IF (ALODE.GT.1.D0) THEN   
             ALODE=1.D0
          END IF   
        END IF      
        XLODE=(1.D0/3.D0)*DASIN(ALODE)*(180.D0/PI)
      ELSE ! IF SEQ=0 THEN:  XLODE=UNDETERMINATE AND XS=+-INFINITY OR UNDETERMINATE (IF ALSO P=0)
        XS = 0.D0
        XLODE = 0.D0
      END IF
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