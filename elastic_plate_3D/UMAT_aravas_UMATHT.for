C***********************************************************************      
C
      SUBROUTINE KCT(CT,CTOR,dCTdEP,dCTdCL,CTT,THETAL,THETAT,EBAR,CL,
     1 PROPS,NPROPS,DTIME)
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
      THETATOR = AKT*THETAL/(1.D0 + AKT*THETAL - THETAL) ! ORIANI (used simplify version of 1 - thetaL approx 1)
      CTOR     = ALPHA*THETATOR*ANT                      ! ORIANI
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