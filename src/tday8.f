      SUBROUTINE TDAY8 (IQ,IRET)
C_Titl  TDAY  KRC day and layer computations
C_Vars  
      INCLUDE 'krcc8m.f'        ! has IMPLICIT NONE
      INCLUDE 'dayc8m.f'
      INCLUDE 'hatc8m.f'
      INCLUDE 'unic8m.f'        ! need  IOD1
      INCLUDE 'filc8m.f'        ! need  FLAYT
      INCLUDE 'porbc8m.f'       ! need  SJA
C_Args
      INTEGER*4 IQ   !in. 1=initialize (3=with table print)   2=day computations 
      INTEGER*4 IRET !out. 1=normal return   TDAY(2, 2=numerical blowup 
C   TDAY(1,  3=Some layer unstable  4=Too many Layers generated by zone table
                                
C_Calls   EVMONO38  READZONE  RNDEX  TDISK8  TPRINT8  TUN8
C_Lien
C No "SAVE" statement here; assumes that all the values from IQ=1 are held IQ=2 
C_Hist 2014mar10:29  Hugh_Kieffer (unless otherwise noted)   Derive from tday.f
C   Make  REAL*8  version    Convert all intrinsics
C 2014may31 Add call to TUN8(I15=101 to output layer temperatures every hour
C 2015dec24 First time-double no layer less than 4. FLAY now is the first 
C          physical layer. Minor:  print Changes.
C 2016feb06:mar15 Incorporate constant geothermal heatflow. 
C     Allow depth zone table.  Put print of layer table here to make it accurate.
C 2016may11 Option to use flat result for far-field of sloped models
C 2016jul02 Revise convergence safty factor step for 4 to 2
C 2016jul07 Accomodate non-lambertian albedo
C 2016dec08 Having doubling problems, Comments and rename one temporary variable
C_End6789012345678901234567890123456789012345678901234567890123456789012_4567890
C
      REAL*8 FA1(MAXN1), FA2(MAXN1), FA3(MAXN1),DTJ(MAXN1) ! each max # layers
      REAL*8 TAVE(MAXN1),DIFFI(MAXN1P)
      REAL*8 KJ(MAXN2)        ! bottom layer for calculations at each time step

      INTEGER*4 I,II,IH,IP,J,JJ,JJH,JJJ,JJP,JRSET,J3P1,K,KN
     & ,KM,N1P1,NZ
C
      REAL*8 ABRAD,AH,AP,ATMRAD,CPOG,DDZ,DELT,DFROST,DIFY,DSCAL
     &,DTAFAC,DTIM,DTIMI,DTM,EMTIR,FAC3,FAC3S,FAC4,FAC45,FAC5,FAC6
     &,FAC6F,FAC7,FAC8,FAC82,FAC9,FEFAC,FEMIT,FROEX,HEATA,HEATFM
     &,PERSEC,POWER,SHEATF,SNOW,TATM4,TBOTM,TFTEST,TGHF,TRSET
     &,TSUR,TSURM,TS3,TSUR4,ZD,FCJ
      REAL*8 TGLOB,DBOT, ZBOT
      REAL*8 QA,QB,QQ,Q3,Q4,Q5,Q6           ! temporary use
      LOGICAL LDAY              ! this will [normally] be the last iteration day
      LOGICAL LFROST            ! frost is present on the ground. 
      LOGICAL LRESET            ! it is permissable to do jump perturbation
      LOGICAL LATM              ! there is an atmosphere
      LOGICAL LGHF              ! continuous geothermal heat flow
      LOGICAL LWP               ! Print flag when IQ=3

C variables for k(T)
      REAL*8 FBI(MAXN1),FCI(MAXN1),FKI(MAXN1) ! layer factors
      REAL*8 KTT(MAXN1P)        ! thermal conductivity of each layer
      REAL*8 CTT(MAXN1P)        ! specific heat of each layer
      REAL*8 DENN(MAXN1P)       !   density of each layer
      REAL*8 FBK,FBKL,FA1J,FA3J ! temporary factors
      REAL*8 TOFF/220.D0/       ! TEMPERATURE SCALING
      REAL*8 TMUL/0.01D0/       ! TEMPERATURE SCALING
      INTEGER IK1,IK2,IK3,IK4   ! layer indices for kofT
      LOGICAL LALCON            ! all layers T-constant 
C Zone depth table and its processing
      REAL*8 ZCOND(MAXN1P),ZDEN(MAXN1P),ZDZ(MAXN1P),ZSPH(MAXN1P) ! zone values
      REAL*8 YCOND,YDEN,YDZ,YSPH ! values for one zone

      REAL*8 FLAYER,FLAD,FLAR ! statement function and its arguments
C function: Number of layers to reach arg1 if first is 1. and ratio is arg2  
      FLAYER(FLAD,FLAR)=DLOG(1.D0+FLAD*(FLAR-1.D0))/DLOG(FLAR) ! N LAYERS
C Variables for far flat: indicated by  LOPN3 true
      LOGICAL LSELF ! Not using far-field temperatures
C
      SAVE CTT,DENN,KTT,TOFF,TMUL,TGHF,LGHF
      SAVE IK1,IK2,IK3,IK4,LALCON,N1P1  ! ?? more
      SAVE FA1,FA2,FA3,FBI,FCI ! ?? more
C
      IF (IDB2.GE.5) WRITE(IOSP,*) 'TDAY IQ,J4=',IQ,J4,JJO
      IRET=1
      GOTO (100,200,100), IQ
C
C  I  (IQ = 1 or 3)
C Set up grid based upon nominal conductivity, then use T-dependant values
C in the time loops. Assumption here is that conductivity could depend on
C several variables, but that having all but T constant for a given case is 
C adequate.
C The convergence safety factor should be chosen to be adequate to cover 
C the conductivity variation.

 100  JRSET=NRSET
      IF (IIB.LE.-1) JRSET=999    ! never reset the lower boundary
      IF (JRSET.LT.1) JRSET=2
      LWP=IQ.EQ.3                ! do the stage 1 prints
C insure day loop does not go past next season
      IF (N5.GT.1) N3=MIN(MAX(N3,IDINT(DELJUL/PERIOD)),MAXN3-1)
      N1P1=N1+1                 ! lowest layer reset
      N1M1=N1-1                 ! lowest layer in spaced print
      NLW=1+(N1-3)/10           ! spacing of printed layers
      PERSEC = PERIOD * 86400.  ! get solar period in seconds
      DTIM=PERSEC/N2            ! size of one time step
      COND=SKRC**2/(DENS*SPHT)  ! conductivity
      DIFFU=COND/(DENS*SPHT)    ! diffusivity
      SCALE=DSQRT(DIFFU*PERSEC/PIVAL)
C Construct table of normalized relative layer sums
C Temporary use until done with layer construction of: 
C    DTJ = cumulative layer thickness to bottom of J'th physical layer 
      QA=1.D0                     ! thickness of normalized first layer
      DTJ(1)=1.D0
      DO J=2,N1                 ! compute geometric ratio series
        QA=QA*RLAY              ! thickness of each layer in units of D
        DTJ(J)=DTJ(J-1)+QA      ! depth to bottom of layer " " "
      ENDDO
C If user specified a total depth in diurnal units:
      IF (DEPTH.GE.1.D0) THEN    ! calculate  FLAY for bottom(n1) =  DEPTH
        FLAY=DEPTH/DTJ(N1-1)           ! first physical layer, scaled
      ENDIF
 
      TGLOB=(SOLCON*(1.D0-ALB)/(2.D0*PIVAL*SJA**2*EMIS*SIGSB))**0.25 ! Tg
C Compute Tg values here as may need 1 or 2 times. Last arg is scalar here
      CALL EVMONO38(CCKU,1,TGLOB,TOFF,TMUL, Q3) ! upper cond.
      CALL EVMONO38(CCPU,1,TGLOB,TOFF,TMUL, Q4) ! upper sp.heat
      CALL EVMONO38(CCKL,1,TGLOB,TOFF,TMUL, Q5) ! lower cond.
      CALL EVMONO38(CCPL,1,TGLOB,TOFF,TMUL, Q6) ! lower sp.heat      

      IK2=0                     ! no layers of upper Tdep material yet
      IK4=0                     ! " " lower "

      IF (LZONE) THEN           ! expect zone table
        NZ=MAXN1
        I=0
        IF (LWP) I=IOSP ! print the lines as read
        CALL READZONE (NZ, I, ZDZ,ZDEN,ZCOND,ZSPH) ! read zone table
        WRITE(IOPM,*)'return NZ= ',NZ
C        WRITE(IOPM,*) ZDZ
        IF (NZ.LT.3) THEN
          WRITE(IOSP,*)'Zone table ',FZONE,' has <3 zones, IGNORED %%%'
          LZONE=.FALSE. ! turn Zones off
        ENDIF
      ENDIF

      IF (LZONE) THEN           ! vvvvvvvvvvvvvv  Process zones

C     May have two zones of T-dep. materials
C  QA, QB     ! Thickness of current layer in D units and in meter
        DBOT=0.                 ! bottom of prior layer in D units
        ZBOT=0.                 ! bottom of prior layer in m
        QA=FLAY/RLAY          ! thickness in D units of the prior (virtual) layer
        LALCON=.TRUE.           ! will stay true only if no zone is Tdep
        J=1                     ! index of prior=virtual layer
        IF (IDB2.GE.3) WRITE(IOSP,*)'Zlay  K  J   DSCAL     DDZ'
     & ,'    FAC8   FAC82   FAC9       QQ II      QB'
C                      1  1  2    0.020   0.0015  0.0015
        IF (LWP) THEN
        WRITE(IOSP,'(a,f8.2)')'Zone Values are Tcon or at Tglob=',TGLOB
          WRITE(IOSP,*)'Zon I Lay   D___bottom___m thick_m'
     &   ,' Conductiv Density SphHeat  Diffusive  Inertia'
C         '  0.386E-01 1400.0  647.00 0.4266E-07   187.08
        ENDIF
        DO K=1,NZ        ! each zone, starting at top -v-v-v-v-v-v-v-v-v-v-v-v
          YDZ=ZDZ(K)        ! col 1: thickness in m
          YDEN=ZDEN(K)      ! col 2: density for this layer, or a code
          YCOND=ZCOND(K)    ! col 3: conductivity for this layer, or a code
          YSPH=ZSPH(K)      ! col 4: Specific Heat for this layer, may be revised

          IF (YCOND .GT. 0.) THEN ! actual conductivity
            IH=0                ! ensure does not trigger Tdep 
          ElSE                  !col 4 points to a material defined by params
            IH=INT(YSPH)       ! convert material code to whole number integer
            IF (IH.LE.1) THEN     ! 1= upper Tcon material
              YCOND=COND
              YSPH=SPHT
            ELSEIF (IH.EQ.2) THEN ! 2= lower Tcon material
              YCOND=COND2
              YSPH=SPHT2
            ELSEIF (IH.EQ.3) THEN ! 3= upper Tdep material
              YCOND=Q3        ! values at Tglob computed above
              YSPH=Q4         ! "
            ELSE                  ! 4= lower Tdep material
              YCOND=Q5
              YSPH=Q6
            ENDIF
          ENDIF

          IF (YDEN .LE. 0) THEN ! replace with input parameter
            IF (YDEN .GT. -1.5D0) THEN ! expect -1
              YDEN=DENS         ! upper material
            ELSE                ! or -2
              YDEN=DENS2        ! lower material
            ENDIF
          ENDIF

C          GOAL=FRLAY*RLAY ! layer thickness in D units increases by RLAY
          DIFY=YCOND/(YDEN*YSPH) ! local diffusivity
          DSCAL=DSQRT(DIFY*PERSEC/PIVAL) ! local diurnal scale
C Calculate the number of layers to use for this zone: II.  This is based on 
C approximating the scaled layer thickness versus scaled total depth profile 
C specified by FLAY and RLAY.
C Total depth so far in D units: DBOT
C     QA is last layer of prior zone in D units.  QB is in m
C     Here, QQ is the number of layers needed for the zone
C FAC8 , FAC82 and FAC9 are temporary use
          IF (K.LT.NZ) THEN     ! not the last zone
            DDZ=YDZ/DSCAL       ! zone thickness in D units
          ELSE                  ! last zone. fill out the number of layers
            DDZ=DTJ(N1-1)*FLAY-DBOT ! depth to go in D units
            YDZ=DDZ*DSCAL         ! and in m
          ENDIF
          IF (RLAY.LE.1.D0) THEN  ! all layers then same thickness
            QQ=DDZ/FLAY         ! number of layers needed for this zone
          ELSE 
            FAC8=FLAYER(DBOT/FLAY,RLAY) ! ideal number of layers so far 
            FAC82=FLAY*RLAY**FAC8 ! Goal thickness in D units of next layer
            FAC9=DDZ/FAC82       ! normalized sum for zone thickness
            QQ=FLAYER(FAC9,RLAY) ! number of layers needed for this zone
          ENDIF
          II=NINT(QQ)           ! round to integer number of layers
          IF (II.GT.N1-J) THEN 
            WRITE(IOSP,*)'Layers/zone > room left; reset from:',II
            II=N1-J             ! room left for all zones
          ENDIF
          IF (II.LT.1) II=1     ! ensure at least one layer
          QB=YDZ/DTJ(II)        ! thickness in m of first layer in this zone
          IF (IDB2.GE.3) WRITE(IOSP,'(a,2i3,6f8.3,i3,f8.4)')  
     &        'Zlay',K,J,DSCAL,DDZ,FAC8,FAC82,FAC9,QQ,II,QB
C       labels for print

          IF (IH.GE.3) THEN ! this zone is Tdep
            LALCON=.FALSE.      ! there is at least one Tdep material
            IF (IH.EQ.3) THEN   ! upper material
              IK1=J+1           !   index of first layer
              IK2=II            !   number of layers
            ELSE                ! lower material
              IK3=J+1           !   index of first layer
              IK4=II            !   number of layers
            ENDIF
          ENDIF
          WRITE(IOPM,*)'K,IH,LALCON=',K,IH,LALCON
          DO I=1,II             ! create layers within a zone
            J=J+1               ! increment index to this layer
            IF (J.GT.N1) THEN   ! would exceed allotted number of layers
              WRITE(IOERR,*)'TDAY: Exceeded allotted number of layers.'
              WRITE(IOSP,*)'TDAY:Exceeded allotted number of layers.'
              WRITE(IOSP,'(a,3i3,2f12.5)')'TDAY: Zone,I,II,ZBOT,DBOT=' 
     &             ,K,I,II,ZBOT,DBOT
              IRET=4            ! set return error flag
              GOTO 118
            ENDIF
            ZBOT=ZBOT+QB        ! Cumulative sum in m
            QA=QB/DSCAL         ! thickness in local D units
            DBOT=DBOT+QA        ! Cumulative sum in local D units
            BLAY(J)=QB          ! this and next 4 are into  R*8
            KTT(J)=YCOND        ! 
            CTT(J)=YSPH         ! specific heat
            DENN(J)=YDEN
            DIFFI(J)=YCOND/(YDEN*YSPH) ! layer diffusivity
            IF (LWP) WRITE(IOSP,111) K,I,J,DBOT,ZBOT,QB
     &      ,YCOND,YDEN,YSPH,DIFFI(J),SQRT(YCOND*YDEN*YSPH)
            QB=QB*RLAY          ! thickness in m of the next layer
          ENDDO                 ! layers within a zone
        ENDDO                   ! zones -^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^ 
 111    FORMAT(3I3,F9.3,F9.4,F8.4,G11.4,F7.1,F8.2,G11.4,F9.2)
 118    JJH=999                 ! surrogate for IC2, turn it off
C     Fill in the virtual layer 
        KTT(1)=KTT(2)
        CTT(1)=CTT(2)
        DENN(1)=DENN(2)
        BLAY(1)=BLAY(2)/RLAY 

      ELSE                      ! ---------------  No zone table

        JJH=IC2
C     IC2==JJH is index first of lower material
        IK1=1                   ! first of upper layers
        LALCON=.NOT. LKOFT
        IF (LKOFT) THEN 
          IK2=MIN0(N1+1,IC2-1)  ! number of upper layers
          IK3=IK2+1             ! first of lower layers
          IK4=N1+1-IK2          ! number of lower layers
        ENDIF

        DO J=1,N1P1
          IF (J.LT.IC2) THEN    ! upper material
            DENN(J)=DENS
            IF (IK2.GT.0) THEN  ! use Tg values
              KTT(J)=Q3
              CTT(J)=Q4
            ELSE                ! use input card values
              KTT(J)=COND
              CTT(J)=SPHT
            ENDIF
          ELSE                  ! lower material
            DENN(J)=DENS2
            IF (IK4.GT.0) THEN  ! use Tg values
              KTT(J)=Q5
              CTT(J)=Q6
            ELSE                ! use input card values
              KTT(J)=COND2
              CTT(J)=SPHT2
            ENDIF
          ENDIF
          DIFFI(J)=KTT(J)/(DENN(J)*CTT(J)) ! layer diffusivity
          K=1
          IF (LOCAL) K=J
          BLAY(J)= FLAY * RLAY**(J-2) * DSQRT(DIFFI(K)*PERSEC/PIVAL) ! thickness
D     write(*,*)'J,diffi,blay=',J,diffi(J),blay(J)
        ENDDO

      ENDIF                     ! ^^^^^^^^^^^^^^ zone / no zone
C----------------------------------
      IF (LWP) WRITE(IOSP,119) LZONE,LALCON,JJH,IK1,IK2,IK3,IK4
 119  FORMAT('LZONE,LALCON,JJH, IK1:4=',2L3,5I6)
C     
C     Print table of T-dependant inertias. 
C  Temporary use of >>>>>>>>  FBI,FCI,FKI,FA1,FA2,FAC7,FAC9 <<<<<<<
      IF (LWP .AND. .NOT. LALCON) THEN           !   k of  T section
        K=20                    ! firm-code number of lines in output table
        DO I=1,K
          FKI(I)=120.D0+10.D0*I     ! vector of temperatures
        ENDDO
        CALL EVMONO38(CCKU,K,FKI,TOFF,TMUL, FBI) ! upper conductivities
        CALL EVMONO38(CCKL,K,FKI,TOFF,TMUL, FCI) ! lower "
        CALL EVMONO38(CCPU,K,FKI,TOFF,TMUL, FA1) ! upper specific heat
        CALL EVMONO38(CCPL,K,FKI,TOFF,TMUL, FA2) ! lower "
        WRITE(IOSP,122) 'CCKU/L=',CCKU,CCKL
        WRITE(IOSP,122) 'CCPU/L=',CCPU,CCPL
 122    FORMAT(1X,A7,4G13.5,/,8X,4G13.5)
        WRITE(IOSP,'(a,f7.2)')'T-global=',TGLOB
        WRITE(IOSP,*)'   T     cond_SpHeat_UPPER_iner_Diffusivity'
     &                   ,'    cond_SpHeat_LOWER_iner_Diffusivity'
        DO I=1,K   ! print at each temperature
          QQ=DSQRT(FBI(I)*FA1(I)*DENS)  ! upper inertia
          QA=DSQRT(FCI(I)*FA2(I)*DENS2) ! lower inertia
          FAC7= FBI(I)/(DENS*FA1(I))    ! Upper diffusivity
          FAC9= FCI(I)/(DENS2*FA2(I))   ! Lower diffusivity
          WRITE(IOSP,120) FKI(I),FBI(I),FA1(I),QQ,FAC7
     &                          ,FCI(I),FA2(I),QA,FAC9
        ENDDO
 120    FORMAT(1X,F6.1,F9.5,2F8.2,g12.5,F10.5,2F8.2,g12.5)
 121    FORMAT(1X,A6,2F10.5,2F10.2)
C       Check that values agree at TOFF
        WRITE(IOSP,* )'          ConUp     ConLo     SphUp     SphLo' ! labels
        WRITE(IOSP,121 )'Input',COND,COND2,SPHT,SPHT2 ! inputs 
        WRITE(IOSP,121 )'@Toff',CCKU(1),CCKL(1),CCPU(1),CCPL(1) !  T-dep at TOFF
        WRITE(IOSP,121 )'@Tglb',Q3,Q5,Q4,Q6 !  " at T-global
      ENDIF
C
C  Calculate layer dependent factors
C  K=index of binary depth  N1K=bottom layer for binary  K
C             2000jan22
C  Allow doubling of time step at successive layers; but never more than a 
C factor of 2 between layers, and never a decrease in the time step with 
C increasing layers.
C  Thus, a single pass of increasing the time step downwards would suffice 
C except for the case of an increase of diffusivity at layer  IC2.
C  So, if  IC2 invoked, determine the time step increase that might be possible
C there, and do not allow higher layers to exceed this value.
C  If layer  IC2 is unstable, need to increase its thickness (and possibly lower
C layers) to insure stability.
C
C 2016 Feb 16
C If using zone table, there could be many discontinuities, so no point in
C checking for them. Compute the safety factor for each layer prior to any
C time doubling. Starting from the bottom layer, form the minimum safety 
C factor at each layer or below. Then from top down, apply time doubling.
C 2016 dec08 ZDZ, ZDEN, ZCOND and ZSPH arrays are available for reuse here

      KM= MIN(MAXBOT,IFIX(ALOG(FLOAT(N2))/ALOG(2.)+.001) ) -1
      XCEN(1)=-BLAY(1)/2.D0       ! x is depth to layer center, [cm]
      IF (ARC3.LT.0.8) WRITE(IOERR,*)'TDAY: WARNING, safety fac=',ARC3 
      IF (JJH .LE. N1-2) THEN   ! check safety at first lower layer
        QQ=BLAY(JJH)**2/(2.D0*DTIM* DIFFI(JJH)) ! safety factor
        IF (QQ .LT. ARC3) THEN    ! must increase layer thickness
          DO J=JJH,N1           ! set layer JJH just stable for local diffusivity
            BLAY(J)= RLAY**(J-JJH) * DSQRT(CONVF*2.D0*DTIM *DIFFI(J))
          ENDDO
          WRITE(IOSP,*)'Increased lower layers from safety of',QQ
        ENDIF
      ENDIF
      IF (IDB4.GE.2) WRITE(*,'(a,2I4,2f8.5,f10.3,e12.5)') 
     & 'KM,JJH,ARC3,CONVF,QQ,DTIM=',KM,JJH,ARC3,CONVF,QQ,DTIM
C
      SCONVG(1)=0.
      DO J=2,N1                 ! LAYER LOOP 1: compute safety factor
        XCEN(J)= XCEN(J-1)+ (BLAY(J)+BLAY(J-1))/2.D0 ! center depth
        SCONVG(J)=BLAY(J)**2/(2.D0*DTIM* DIFFI(J)) ! Safety factor
      ENDDO
C
      QQ=SCONVG(N1)             ! minimum safety factor at each layer or lower
      ZDZ(N1) = QQ              ! " " at each layer. Temporary use of  ZDZ  
      K=N1                      ! will be layer with lowest safety factor   
      DO J=N1-1,2,-1            ! LAYER LOOP 2: minimum here or below
        IF (SCONVG(J).LT.QQ) then 
          QQ= SCONVG(J)
          K=J
        ENDIF
        ZDZ(J) = QQ !  minimum safety factor at this layer or lower
        IF (IDB4.GE.2) WRITE(IOSP,'(i3,2f12.3)') J,SCONVG(J),ZDZ(J)
      ENDDO
      IF (QQ.LT. ARC3) THEN     ! Some layer unstable
        IRET=3                  ! error return if unstable
        WRITE (IOERR,137)K,SCONVG(K)
 137    FORMAT ('TDAY: UNSTABLE; Layer, factor =',I3,F8.4)
      ENDIF
C                   all the Qn are available for use
      K=0                       ! number of time doublings so far
      IH=0                      ! will hold total of layers*time
      KKK=N2                    ! current number of times steps per day 
      QA=1.D0                   ! effect on safety factor of K doublings
      DTIMI=DTIM                ! current time step
      DO J=2,N1                 ! LAYER LOOP 3: Assign time doubling
        IF (K.LT.KM .AND. J.GT.3 .AND. MOD(KKK,2).EQ.0 
     &    .AND. ZDZ(J).GT. 2.D0*QA*CONVF) THEN ! double time step for this layer
          DTIMI=2.*DTIMI        ! doubled time interval
          K=K+1                 ! have new binary interval
          N1K(K)=J-1            ! bottom layer of prior interval
          KKK=KKK/2          ! number of time steps for this and deeper layers
          QA=QA*2.              ! update doubling factor
        ENDIF
        IF (IRET.NE.1) WRITE(IOSP,'(A,I4,2G12.5,F8.1)')  ! something wrong
     &  'J,BLAY,SCONVG,QA',J,BLAY(J),SCONVG(J),QA        ! print all layers
        SCONVG(J)=SCONVG(J)/QA  ! safety after time doubling
        IH=IH+KKK               ! add timesteps at this depth
C for constant conductivity
        FCJ= 2.D0* DTIMI /(DENN(J)*CTT(J) * BLAY(J)**2) !
        FA1(J)=FCJ*KTT(J)/(1.D0+(BLAY(J+1)*KTT(J)/(BLAY(J)*KTT(J+1))))
        FA3(J)= (BLAY(J)/KTT(J) + BLAY(J+1)/KTT(J+1))
     &        / (BLAY(J)/KTT(J) + BLAY(J-1)/KTT(J-1))
        FA2(J)=-1.D0-FA3(J)
C T-dependent conductivity
        FBI(J)=  BLAY(J+1)/BLAY(J) ! 
        FCI(J)= 2.D0* DTIMI /(DENN(J) * BLAY(J)**2) !
      ENDDO                     ! end of layer loop
      IF (LWP) WRITE (IOSP,*)'Time-doubling fraction:'
     @ ,FLOAT(IH)/FLOAT((N1-1)*N2)
C
      KKK=K+1                   ! one larger than number of time doublings
      N1K(KKK)=N1
C set last layer for each time.  KJ(JJ)=K for  JJ time increment
      II=1                      ! spacing
      DO K=1,KKK                ! each doubling
        I=N1K(K)                ! bottom layer for that doubling
        DO JJ=II,N2,II          ! each time-step along current spacing
          KJ(JJ)=I              ! set the deepest layer to do
        ENDDO
        II=II+II                ! double the spacing
      ENDDO
      IF (IIB.GT.0) THEN ! Heat-flow flag and coefficient to be saved
        LGHF=.TRUE.
        TGHF=0.001D0*DFLOAT(IIB)*(BLAY(N1)+BLAY(N1P1))/(2.D0*KTT(N1))
        IF (LWP) WRITE(IOSP,'(a,i7,3g12.5)'),'IIB:TGHF='
     & ,IIB,BLAY(N1)+BLAY(N1P1),KTT(N1),TGHF
      ELSE
        LGHF=.FALSE.
      ENDIF
C     
      IF (IRET.LT.3 .AND. (IQ.EQ.1 .OR. (.NOT. LWP))) GOTO 9 ! skip layer table
C Print layer table. Use values that account for Tcon or Tdep @Tglobal
      I=2                       ! top physical layer
      QA=DENN(I)*CTT(I)         ! volume specific heat
      QB=KTT(I)/QA              ! diffusivity
      QQ=SQRT(QB*PERSEC/PIVAL)  ! local diurnal scale
      FAC9=SQRT(QA*KTT(I) )     ! inertia   Temp. use of FAC9 
      WRITE(IOSP,140) QA,QB,QQ,FAC9
C140  FORMAT ('Dens*Cp=',1PE10.3,'  Diffu.=',E10.3
C    &    ,'  Scale=',0PF10.4,'   Iner.=',F10.2)
 140  FORMAT (1PE10.3,'=Dens*Cp',E12.3,'=Diffu.'
     &    ,0PF12.4,'=Scale',F12.2,'=Inertia')
      IF (IC2.GE.3 .AND. IC2.LE.N1-1) THEN
        I=IC2                   ! top of lower material
        FAC7=XCEN(I)-BLAY(I)/2. ! depth to top of 2nd material  Temp. use FAC7 
        WRITE(IOSP,142) IC2,FAC7
 142    FORMAT(' Beginning at layer ',I3,'  At ',F11.4,' m.' )
        QA=DENN(I)*CTT(I)       ! volume specific heat
        QB=KTT(I)/QA            ! diffusivity
        QQ=SQRT(QB*PERSEC/PIVAL) ! local diurnal scale
        FAC9=SQRT(QA*KTT(I) )   ! inertia
        WRITE(IOSP,140) QA,QB,QQ,FAC9
      ENDIF
      WRITE(IOSP,145)
 145  FORMAT('         ___THICKNESS____    __CENTER_DEPTH__'
     &      ,'  Conductiv. Density Sp.Heat     Total Converg.'
     &      /' LAYER  D_scale     meter   D_scale     meter'
     &      ,'      W/m-K   kg/m^3   J/kg     kg/m^2  factor')
      DO 150 I=1,N1
        IF (I.EQ.1) THEN 
          FAC9=DSQRT(DIFFI(2)*PERSEC/PIVAL) ! local diurnal scalem use top layer
          QB=BLAY(I)/FAC9       ! layer thickness in local scale
          QQ=-QB/2.D0           ! position of layer center in local scale
          QA=0.                 ! cumulative columnar mass
        ELSE
          FAC9=DSQRT(DIFFI(I)*PERSEC/PIVAL) ! local diurnal scale
          QB = BLAY(I)/FAC9     ! thickness in units of local scale
C     cumulative center-depth in units of local scale
          QQ=QQ+FAC7+QB/2.D0    ! prior sum +1/2 prior layer + 1/2 this layer 
          QA=QA+BLAY(I)*DENN(I) ! cumulative columnar mass
        ENDIF
        FAC7=QB/2. ! 1/2 this layer 
 150    WRITE(IOSP,152) I,QB,BLAY(I),QQ,XCEN(I)
     & ,KTT(I),DENN(I),CTT(I),QA,SCONVG(I)
 152  FORMAT (I5,F10.4,F10.4,F10.4,F10.4,G11.4,F9.2,F8.2,F10.3,F8.3)
      WRITE(IOSP,154) QQ+FAC7,XCEN(N1)+BLAY(N1)/2. ! at bottom
 154  FORMAT (' Bottom',T26,F10.4,f10.4)
      WRITE(IOSP,156) (N1K(K),K=1,KKK)
 156  FORMAT (' Lower layer of time doubling: ',15I3)

      GOTO 9
C===========================================================================
C========================= day computations  (IQ = 2) ======================
C===========================================================================
C
 200  DTMJ(1)=-1.D0             ! RMS layer midnight T change from prior day
      LATM=PTOTAL.GT.1.D0       ! atmosphere present flag
      LDAY=N3.LE.1              ! normally false
      LRESET=.FALSE.            ! flag for reset of lower layers
      FAC3S = 1.D0-SALB         ! spherical absorption
      FAC4  = 1.D0+1.D0/RLAY
      FAC5  = SKYFAC*EMIS*SIGSB
      FAC45 = 4.D0*FAC5
      FAC6  = SKYFAC*EMIS
      FAC6F = SKYFAC*FEMIS      ! if frost
      FAC7  = KTT(2)/XCEN(2)    ! will be redone if not LALCON
      FEFAC = FEMIS/EMIS        ! adjust FARAD is frost present
C Following 5 used only with atmosphere.  EMTIR used only for fac8, and FAC8 
C used only with atmosphere. Ensure divisor CPOG is not zero
      FAC9=SIGSB*BETA           ! factor for downwelling hemispheric flux
      CPOG=ATMCP*(DMAX1(PRES, 1.D0)/GRAV) ! atmosphere:  D_Energy / d_T
      DTAFAC=DTIM/CPOG          ! dT=heat*dtafac
      EMTIR = DEXP(-TAUIR)      ! Zenith Infrared transmission of atm
      FAC82=1.D0-EMTIR          !  " absorption "
C If self heating, as before v3.4, factors are to the open sky
C If using fff, -- are hemisphere , --P are back-radiation from far ground
C SKYFAC is fractional normalized irradiance from the sky; 1.0 for flat
C SKYFAC is computed in TLATS and arrives thru KRCCOM
      IF (LOPN3) THEN           !F using fff
        FAC5  = EMIS*SIGSB      !F --X far (eXterior) factors are 0 for flat
        FAC45= 4.D0*FAC5        !F
      ENDIF                     !F
      LSELF=.NOT. LOPN3         !F self heating
      TSUR=TTJ(1)
      DO J=1,N1                 ! save  T each layer at start of first day
        TT1(J,1)=TTJ(J)
      ENDDO
C  TATMJ and  EFROST enter via  KRCCOM  
      FROEX = MAX (FROEXT,0.01) ! scale-mass for insolation attenuation
      FRO(1) = EFROST
      IF (LATM) THEN
        TFTEST=TFROST           ! frost test inside the 230 converegence loop
      ELSE                      ! no atm and no frost
        EFROST=0.
        TFTEST=0.        ! set lower than ever reached
        ATMRAD=0.
      ENDIF
      IF (EFROST.GT.0.) THEN    ! frost is present  kg/m^2
        LFROST = .TRUE.
        TSUR = TFNOW
        FEMIT = FEMIS*SIGSB*TFNOW**4 ! upward frost radiation
        FAC8=EMTIR*FEMIS        ! ground effective emissivity through atmosphere
      ELSE                      ! bare ground
        LFROST = .FALSE.
        FAC8=EMTIR*EMIS
      ENDIF
      FLOST=0.                  ! sum of lost frost
      LALCON = (IK2+IK4 .EQ. 0) ! all Tcon, not Tdep
      IF (IDB2.EQ.2) WRITE(IOSP,119) LZONE,LALCON,j5,IK1,IK2,IK3,IK4
C
C  *v*v*v*v*v*v*v*v*v*v*v*v*v* new day loop v*v*v*v*v*v*v*v*v*v*v*v
C
      DO 320 JJJ=1,N3
        J3P1=JJJ+1              ! the next day
        TBOTM=0.                ! zero sums that will be used on last day
        TSURM=0.
        HEATFM=0.
        IF (LDAY) THEN 
          LRESET=.FALSE.        ! must not use  TOUT for average on last day
          DO  J=1,N1
            TMIN(J)=TBLOW
            TMAX(J)=0.
          ENDDO
          IH = 1                ! saving "hour" count
          AH = DFLOAT(N2)/DFLOAT(N24) ! time steps between saving results
          JJH = AH+.5           ! round to time step of first saving
          IP = 1                ! printout "hour count"
          AP = DFLOAT(N2)/DFLOAT(NMHA) ! time steps between printing results
          JJP = AP+.5           ! time step of first "hourly" printout
        ENDIF
        IF (LRESET) THEN
          DO  J=2,N1
            TAVE(J)=0.
          ENDDO
        ENDIF
C     
C  +v+v+v+v+v+v+v+v+v+v+v+v+v+v+ new time loop +v+v+v+v+v+v+v+v+v+v+v+v+v+v+
C
        DO 270 JJ=JJO,N2        ! time step
          FAC3  = 1.D0-ALBJ(JJ)
C Set the boundary conditions
          TTJ(1)=TTJ(2)-FAC4*(TTJ(2)-TSUR) ! set virtual layer
          IF (LGHF) THEN         ! lower boundary condition
            TTJ(N1P1)=TTJ(N1)+TGHF ! geothermal heat-flow
          ELSE
            TTJ(N1P1)=TTJ(N1PIB) ! insulating or constant T
          ENDIF

          KN=KJ(JJ)             ! depth for this time interval
C
C  -v-v-v-v-v-v-v-v-v-v-v-v-v-v-v- layer loops v-v-v-v-v-v-v-v-v-v-v-v-v-
C     
          IF (LALCON) THEN      ! all layers T-con  --------------
            DO  J=2,KN
              DTJ(J)=FA1(J)* (TTJ(J+1)+FA2(J)*TTJ(J)+FA3(J)*TTJ(J-1)) ! diffusion
            ENDDO 
          ELSE                  ! some T-dep layer ----------------------
C Could here add logic to only compute layers that are used in this time step
            IF (IK2.GT.0) THEN      ! Upper material values
C     EVMONO38 loads arg2 output values into locations starting at last arg.
              CALL EVMONO38(CCKU,IK2,TTJ(IK1),TOFF,TMUL, KTT(IK1)) ! upper | k
              CALL EVMONO38(CCPU,IK2,TTJ(IK1),TOFF,TMUL, CTT(IK1)) !  zone | Cp
            ENDIF
            IF (IK4.GT.0) THEN      ! There are lower material layers
              CALL EVMONO38(CCKL,IK4,TTJ(IK3),TOFF,TMUL, KTT(IK3)) ! lower | k
              CALL EVMONO38(CCPL,IK4,TTJ(IK3),TOFF,TMUL, CTT(IK3)) !  zone | Cp
            ENDIF

            FBK=RLAY            ! F_B_i * F_k_i for virtual layer
            DO J=2,KN           ! kt
              FBKL=FBK          ! kt
              FBK= FBI(J)*KTT(J)/KTT(J+1) ! F_B_i * F_k_i 
              FA1J=FCI(J)*KTT(J)/(CTT(J)*(1.+FBK)) ! eq F1
              FA3J=(1.D0+FBK)/(1.D0+1.D0/FBKL) ! eq F3
              DTJ(J)=FA1J*(TTJ(J+1)-(1.D0+FA3J)*TTJ(J)+FA3J*TTJ(J-1)) ! diffusion
            ENDDO               ! kt
            FAC7=KTT(2)/XCEN(2)
          ENDIF                 !---------------------- 
C     - - - - - - - - - - - - -
          DO  J=2,KN
            TTJ(J)=TTJ(J) + DTJ(J) ! apply the delta-T
          ENDDO
C     
C     -^-^-^-^-^-^-^-^-^-^-^-^-^-^-^- end of layer loops ^-^-^-^-^-^-^-^-^-^-^

          IF (LOPN3) TATMJ= HARTA(JJ) !f use the fff atm
C 3 possible upper boundary conditions. 1) Atm with frost 2) Just Atm 3) No atm.
          II=0 !db newton iteration count
          IF (LFROST) THEN      !+-+-+-+ surface temperature is frost-buffered
            ATMRAD= FAC9*TATMJ**4 ! hemispheric downwelling  IR flux
            QA = AFNOW + (ALB-AFNOW)*DEXP(-EFROST/FROEX) ! albedo for frost layer
            SHEATF= FAC7*(TTJ(2)-TSUR) ! upward heatflow into the surface
C   unbalanced flux into surface
C FEMIT=FAC6F*SIGSB*TFNOW**4 is [[skyfac]]*Femis*sig*Tf^4
            POWER = (1.D0-QA)*ASOL(JJ) +(1.D0-QA)*SOLDIF(JJ) 
     &               + FAC6F*ATMRAD + SHEATF - FEMIT
C If fff, add back-radiation=(1-skyfac)*femis*emis_x*sig*Tfar^4
            IF (LOPN3) POWER=POWER+ FEFAC*FARAD(JJ)
            DFROST = -POWER/CFROST ! rate of frost formation or sublimation
            EFROST=EFROST + DFROST*DTIM ! amount on ground; kg*m**-2
            IF (EFROST.LE.0.) THEN ! reset to bare ground
              LFROST = .FALSE.
              EFROST = 0.
              FAC8=EMTIR*EMIS
            ENDIF
          ELSE                  !+-+-+-+ if no frost
            ABRAD=FAC3*ASOL(JJ)+FAC3S*SOLDIF(JJ) ! surface absorbed radiation
            IF (LATM) THEN 
              ATMRAD=FAC9*TATMJ**4 ! hemispheric downwelling IR flux
              ABRAD=ABRAD+FAC6*ATMRAD ! add absorbed amount
            ENDIF

 230        TS3=TSUR**3         ! bare ground
            II=II+1
            SHEATF= FAC7*(TTJ(2)-TSUR) ! upward heat flow to surface
            POWER = ABRAD + SHEATF - FAC5*TSUR*TS3 ! unbalanced flux
            IF (LOPN3) POWER=POWER+FARAD(JJ) ! fff only
            DELT = POWER / (FAC7+FAC45*TS3)
            TSUR=TSUR+DELT
            IF (MOD(II,10).EQ.0)WRITE(IOPM,*)J5,J4,JJJ,JJ,II,TSUR,DELT !db
            IF (TSUR.LE. 0. .OR. TSUR.GT.TBLOW) GOTO 340 ! instability test
            IF (ABS(DELT).GE.GGT) GOTO 230 ! fails convergence test

            IF (TSUR.LT.TFTEST) THEN ! reset to frost on ground. Never unless atm.
              LFROST = .TRUE.   ! turn frost flag on
              TSUR = TFNOW      ! set to local frost temperature
              FEMIT = FEMIS*SIGSB*TFNOW**4
              FAC8=EMTIR*FEMIS
            ENDIF             
          ENDIF                 !+-+-+-+ end no frost
C
          TSURM=TSURM+TSUR      ! sum over the day
          TBOTM=TBOTM+TTJ(N1)   ! "
          HEATFM=HEATFM+SHEATF  ! "
          IF (LRESET) THEN      ! accumulate average temperature at each layer
            DO  J=2,N1
              TAVE(J)=TAVE(J)+TTJ(J)
            ENDDO
          ENDIF
          TSUR4=TSUR**4
C
          IF (LATM .AND. LSELF) THEN  !v-v-v-v-v  Adjust atmosphere temperature
            TATM4=TATMJ**4
C 2002jul12  ADGR was downwelling  IR flux; becomes solar heating of atm
            HEATA=ADGR(JJ)+FAC9*(EMIS*TSUR4-2.*TATM4) ! net atm. heating flux
            TATMJ=TATMJ+HEATA*DTAFAC ! delta Atm Temp in 1 time step
          ENDIF                 !^-^-^-^-^
          IF (.NOT.LDAY) GOTO 270
C done only on the last day of a season
          TOUT(JJ)=TSUR         ! save surface temperatures at each time
          IF (JJ.EQ.JJH) THEN   !  JJH is next saving hour
            TTJ(1)=TSUR
            TSFH(IH)=TSUR       ! save hourly temperatures on last iteration
            IF (LATM) THEN      !v-v-v-v-v  with atmosphere
              TPFH(IH)=(FAC8*TSUR4+FAC82*TATM4)**0.25 ! planetary  
              TAF(IH,J4)=TATMJ  ! save Atm Temp.
              DOWNIR(IH,J4)=ATMRAD ! save downward IR flux
            ENDIF               !^-^-^-^-^
            DOWNVIS(IH,J4)=ASOL(JJ)+SOLDIF(JJ) ! downward coll.+diffuse solar flux
            DO J=1,N1           ! save extreme temperatures for each layer
C..     th(j,ih)=t(j)   ! save depth-time solution [th(maxn1,MAXNH]
              IF (TTJ(J).LT.TMIN(J)) TMIN(J)=TTJ(J)
              IF (TTJ(J).GT.TMAX(J)) TMAX(J)=TTJ(J)
            ENDDO
            IF (I15.EQ.101 .AND. J5.GE.JDISK) CALL TUN8(I15,2,IH,Q6) !special output
            IH = IH+1
            JJH = IH*AH+.5
          ENDIF
C
          IF (JJ.EQ.JJP) THEN   ! print "hourly" temperatures
            IF (LP3) WRITE(IOSP,260)IP,EFROST,TTJ(1)
     &        ,(TTJ(I),I=2,N1M1,NLW),TTJ(N1),TATMJ
 260        FORMAT (I7,F8.3,(12F8.1))
            IP = IP+1
            JJP = IP*AP+.5      ! time step of next print
          ENDIF
 270    CONTINUE                !^+^+^+^+^+^+^+^+^+^+^+ end of time loop ^+^+^+^
C
C  store results of day, calculate rms change
C
        IF (LATM .and. (TATMJ.LT.TATMIN)) THEN ! Tatm is below saturation T
          SNOW= (TATMIN-TATMJ)*CPOG/CFROST ! | snow formation  Kg/m^2
          IF (LFROST) THEN                 ! | in this time step
            EFROST=EFROST + SNOW ! let it fall to surface
          ELSE                   ! or
            FLOST=FLOST+ SNOW    ! record mass "lost" from system ??
          ENDIF
          TATMJ=TATMIN           ! keep atm. no colder that saturation
        ENDIF
C
        TTJ(1)=TSUR
        ZD=0.
        DO  J=1,N1              ! each layer
          ZD=ZD+(TTJ(J)-TT1(J,JJJ))**2 ! add square of diff from prior midnight
          TT1(J,J3P1)=TTJ(J)    ! save new midnight temperature
        ENDDO
        DTM=DSQRT(ZD/N1)         ! RMS change of layer temperatures in prior day
        DTMJ(J3P1)=DTM
        QQ=DFLOAT(N2+1-JJO)     ! temporary divisor: number of time steps this day
        TTS(J3P1)=TSURM/QQ      ! average surface T
        TTB(J3P1)=TBOTM/QQ      ! average bottom T
        HEAT1M=HEATFM/QQ        ! average upward heatflow into the surface
        IF (LATM) THEN          !v-v-v-v-v  with atmosphere
          TTA(J3P1)=TATMJ       ! final atm. temperature
          FRO(J3P1)=EFROST      ! final frost amount
        ENDIF                   !^-^-^-^-^
C
C  are we done?
C
        IF (LDAY.AND.(DTM.LE.DTMJ(JJJ) .OR. DTM.LE.DTMAX ! some convergence
     &        .OR. JJJ.GE.N3-1 )) GOTO 330 ! or end of season
        JJO=1
C
C  not yet - is next day the last?
C
        ZD = MAX(DTMJ(JJJ),1.D-6) ! yesterdays DTM:  temporary reuse of ZD
        IF (((DABS(1.-DTM/ZD).LE.DDT .OR. DTM.LE.DTMAX) 
     &        .AND. JJJ.GE.2) .OR. JJJ.EQ.N3-1) THEN !  initiate last day
          LDAY=.TRUE.
        ELSE                    ! not last day yet
          LDAY=.FALSE.
          IF (LRESET) THEN      ! reset lower temps to have
            TRSET=TTS(J3P1)-TTB(J3P1)
            DO  J=2,N1          !   same average
              TAVE(J)= TAVE(J)/N2 -TTS(J3P1) !
              IF (DRSET.NE.0.) THEN
                QQ=XCEN(J)/XCEN(N1)
                TTJ(J)=TTJ(J)+TRSET*(QQ+DRSET*QQ*(1.D0-QQ))
              ELSE
                TTJ(J)=TTJ(J)-TAVE(J) !   as  TSUR
              ENDIF
            ENDDO
            IF (LD17) WRITE(IOSP,'(I7,F8.3,F8.1,12F8.3)') !+
     &           JJJ,DTM,TTS(J3P1),(TAVE(I),I=2,N1M1,NLW),TAVE(N1) !+
          ENDIF
C  If it is the first season and enough iteration days have been done, then 
C may reset the lower layers on each successive day
          IF (J5.LE.1 .AND. JJJ.GE.JRSET) LRESET=.TRUE.
        ENDIF
 320  CONTINUE                  ! *^*^*^*^*^*^*^*^*^* end of day loop *^*^*^*^*
      IF (IDB2.EQ.2) WRITE(IOSP,119) LZONE,LALCON,j5,IK1,IK2,IK3,IK4
C
      JJJ=N3                    ! if loop finished, index value not guarenteed
 330  J3=JJJ                    ! reset the counter kept in common
      GOTO 9
C
 340  IRET=2                  !  blow-up. force a stop; print current conditions
      write(IOSP,*)'TDAY blowup: jj,jjj,j4,j5=',jj,jjj,j4,j5
      write(IOSP,*)'LRESET,LDAY,LOPN3,Tsur=',LRESET,LDAY,LOPN3,TSUR
      write(IOSP,*)'LATM,LFROST,LALCON,ABRAD=',LATM,LFROST,LALCON,ABRAD
      IF (LATM) write(IOSP,*)'atm items=',ATMRAD,LFROST,EFROST
      WRITE(IOSP,*)'FARAD,SHEATF,POW,DT=',FARAD(JJ),SHEATF,POWER,DELT
      TTJ(1)=TSUR
      J2=JJ
      J3=JJJ
      CALL TPRINT8 (7)           ! print message and  TTJ
      WRITE(IOSP,*) 'DELT,TATMJ,TBLOW=',DELT,TATMJ,TBLOW
      IF (J5.GE.JDISK) CALL TDISK8(2,I) ! write current season if valid
      CALL TPRINT8 (4)           ! print daily convergence
C
 9    IF (IDB2.GE.6) WRITE(IOSP,*) 'TDAYx'
      RETURN
C     
      END
