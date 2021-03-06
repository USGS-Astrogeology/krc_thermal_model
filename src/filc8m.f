C_Titl  filc8m.f  Common /FILCOM/ for file names and other strings
        CHARACTER*80 FINPUT  ! input file
     & ,FOUT     ! spooled printer file
     & ,FDISK    ! type 5x data output
     & ,FDIRA    ! direct access data output
     & ,FFAR     ! far-field temperatures input
     & ,FVALB    ! Seasonal Albedo
     & ,FVTAU    ! Seasonal opacity
     & ,FZONE    ! Depth zone table
     & ,FMOON    ! Satellite and eclipse
        CHARACTER*20 TITONE     ! title for each one-point line
        CHARACTER*12 VERSIN     ! version number
        COMMON /FILCOM/ FINPUT,FOUT,FDISK,FDIRA,FFAR,FVALB,FVTAU
     & ,FZONE,FMOON,TITONE,VERSIN
C_Hist   85oct14  Hugh_Kieffer  97feb12 increase string length
C 2002mar01 HK increase string length from 60
C 2006sep09 HK Add FVALB,FVTAU
C 2009may10 HK Add TITONE
C 2013jan30 HK Add VERSIN
C 2016feb11 HK Add FZONE,FMOON 
C 2016may12 HK Add FDIRA,FFAR  Rename from filc33.f
C_End___________________________________________________________________________
  
