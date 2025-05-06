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