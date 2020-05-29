    !> --------------------------------------------------------------------------
    !> @file: iceStorageFunc.f90
    !> @brief: functions to calculate the geometry of the storage tank 
    !> and immersed heat exchangers
    !> @author SPF institut fur SolarTechnik 
    !> @author D.Carbonell,W.Lodge
    !> @date 10/08/2012.
    !> @todo change HX newton solver for a gauss seidel. I thinks in this case it may be faster. Check it
    !> --------------------------------------------------------------------------

    module iceStoreFunc

    use physProp
    use TrnsysFunctions

    implicit none

    !Specification. Write here global parameters that can be used inside the module

    contains        

    ! ===========================================================================
    !>@brief: calculateGeo : calculate geometry of the storage tank and of 
    !>the immersed heat exchanger.
    !>@param  iceStore : ice Storage structure 
    !>@return iceStore with filled geometry
    ! ===========================================================================

    subroutine calculateGeo(iceStore,immersedHx)

    use spfGlobalConst
    use iceStoreConst
    use iceStoreDef
    use hxModule

    implicit none                

    type(iceStoreStruct), intent(inout),target :: iceStore  
    type(hxStruct), intent(inout) :: immersedHx(nIHX)

    integer :: nCv, nHx
    double precision, pointer:: LTank, VTank, HTank, WTank,  rhoWater, dy             
    double precision , pointer :: H(:), M(:), A(:), areaTop(:), areaBot(:)      
    double precision :: totalExternalArea,crossSection        
    character (len=maxMessageLength) :: MyMessage

    !double precision :: minV,maxV
    !>------------------------------
    !> internal data
    !>------------------------------

    integer :: i,j,k,count,iHx
    double precision :: diameter,aboveHx,belowHx

    !>---------------------------------
    !> access to struct ice Store data
    !>---------------------------------

    nCv = iceStore%nCv; nHx = iceStore%nHx                                              
    LTank => iceStore%LTank
    VTank => iceStore%VTank; HTank => iceStore%HTank; WTank => iceStore%WTank
    dy => iceStore%dy        

    rhoWater => iceStore%rhoWater

    H => iceStore%H; M => iceStore%M; A => iceStore%A; 
    areaBot => iceStore%areaBot; areaTop => iceStore%areaTop

    !>-------------------------------------------------------------
    !>Compute geometryFields: height, mass, and surface areas
    !>-------------------------------------------------------------

    dy = HTank / nCv                
    iceStore%vcly(1) = 0

    do i=2,nCv+1
        !y(i) = HTank - ((nCv - i + 1) * dy)
        iceStore%vcly(i) = iceStore%vcly(i-1)+dy
        !print *,' y(',i,')= ',y(i),' dy ',dy
    enddo

    !as a consequence y(nCv+1) = HTank

    do i=1,nCv
        H(i) = iceStore%vcly(i+1) - iceStore%vcly(i)  
        iceStore%nody(i) = 0.5*(iceStore%vcly(i+1) + iceStore%vcly(i))

        !Automatic (equal) size nodes [m]   
        !iceStore%Htank / iceStore%nCv  
    enddo                          

!    iceStore%nCvInHxs = 0

    do i=1,iceStore%nCv            
        ! if the lower part of the CV is above ice heat exchanger
        if(iceStore%vcly(i)>=iceStore%heightIceHx) then                
            iceStore%iceFrac(i)   = iceStore%maxIceFrac
            iceStore%isHxLayerRatio(i) = 0.0d0

            ! if the upper part of the CV is below the ice heat exchanger    
        else if(iceStore%vcly(i+1)<=iceStore%heightIceHx) then                
            iceStore%iceFrac(i) = iceStore%maxIceFracIceLayer
           ! iceStore%nCvInHxs = iceStore%nCvInHxs +1                
            iceStore%isHxLayerRatio(i) = 1.0d0
            !iceStore%iceFrac(i) = iceStore%maxIceFrac
            ! the heat exchanger is inside the CV 
        else                
            !aboveHx = (iceStore%vcly(i+1) - iceStore%heightIceHx)/H(i)
            !belowHx = (H(i)-aboveHx)/H(i)
            aboveHx = (iceStore%vcly(i+1)  - iceStore%heightIceHx)/H(i)
            belowHx = (iceStore%heightIceHx- iceStore%vcly(i))/H(i)
            iceStore%iceFrac(i) = iceStore%maxIceFrac*aboveHx + iceStore%maxIceFracIceLayer*belowHx
  !          iceStore%nCvInHxs = iceStore%nCvInHxs + belowHx !is not an integer then !!!
            iceStore%isHxLayerRatio(i) = belowHx 
        endif                            
    enddo

    if(iceStore%tankGeometry==0) then

        LTank = VTank / (HTank * WTank)                                          
        iceStore%iceThickMax = LTank/2.d0 ! because we use 2 times the area DC ERROR Jan 2015

        totalExternalArea = 2.0d0*WTank*HTank + 2.0d0*LTank*HTank + 2.0d0*LTank*WTank

        !> Area exchange with the surrounding for heat losses/gains calculation
        !DO FOR ONLY 1CV !!!!

        iceStore%areaTopSurface = WTank * LTank
        iceStore%areaBotSurface = WTank * LTank

        do i = 1,nCv

            A(i)=((2 * WTank) + (2 * LTank)) * H(i)

            ! Area between store layers  = cross sectional area

            areaBot(i)   = WTank*LTank
            areaTop(i)   = WTank*LTank
            
            iceStore%vTankCv(i)   = WTank * LTank * H(i)

        enddo

        areaBot(1) = 0.d0
        if(nCv>1) then
            areaTop(nCv) = 0.d0          
        endif

        !so now A(1) and A(nCV) do not account for top and bottom losses
        !A(nCv) =  A(nCv) + WTank * LTank            
        !A(1)   =  A(1) + WTank * LTank 

    elseif(iceStore%tankGeometry==1) then

        ! HTank is the height and V the volume            

        diameter = sqrt(4*VTank/(pi*HTank))                        
        crossSection = pi*diameter**2/4.0d0
        !VTank = crossSection*HTank
        iceStore%iceThickMax = diameter  
        totalExternalArea = 2*crossSection + pi*diameter*HTank

        if(nCv==1) then
            areaBot(1) = 0.0 ! we need this for oneDimensionalCalculation areaRef. 
            areaTop(1) = crossSection
            iceStore%vTankCv(1) = VTank
            A(1) =pi*diameter*HTank + 2.0*crossSection
        else                    
            do i=1,nCv                
                A(i) = pi*diameter*dy
                areaBot(i) = crossSection
                areaTop(i) = crossSection
                iceStore%vTankCv(i)   = VTank/nCv
            enddo    

            areaBot(1) = 0.d0
            areaTop(nCv) = 0.d0

            iceStore%areaTopSurface=crossSection
            iceStore%areaBotSurface=crossSection

            ! so now A(1) and A(nCV) do not account for top and bottom losses
            !   A(1) = A(1) + crossSection     ! bottom surface exchange with ambient
            !   A(nCv) = A(nCv) + crossSection ! top surface exchange with ambient
        endif

    else
        write(MyMessage,'("calculateGe TANK GEOMETRY NOT IMPLEMENTED")') iceStore%tankGeometry
        call Messages(-1,Trim(MyMessage),'FATAL', iceStore%iUnit,iceStore%iType)      

    endif    

    if(iceStore%verboseLevel>=1) then
        if(abs(sum(A(1:nCv))+iceStore%areaTopSurface+iceStore%areaBotSurface-totalExternalArea)>1e-10) then            
            write(MyMessage,'("calculateGeo ERROR IN EXTERNAL AREAS sumA=",f" ExtArea=",f)') (sum(A(1:nCv))+iceStore%areaTopSurface+iceStore%areaBotSurface,totalExternalArea)
            call Messages(-1,Trim(MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType) 

            !write(myScreenUnit,*) ' ERROR IN EXTERNAL AREAS sumA=',sum(A(1:nCv))+iceStore%areaTopSurface+iceStore%areaBotSurface,' extArea=',totalExternalArea
            !call FoundBadParameter(1,'Fatal','ERROR IN EXTERNAL AREAS sumA=',sum(A(1:nCv))+iceStore%areaTopSurface+iceStore%areaBotSurface,' extArea=',totalExternalArea)
        endif    
    endif

    !<--------------Calculation of UA--------------------------

    do i=1,nCv                
        iceStore%UALoss(i) = iceStore%ULoss(i)*A(i)
        if(i==1) then
            iceStore%UALoss(i) = iceStore%UALoss(i)+iceStore%ULossBot*iceStore%areaBotSurface
        else if(i==nCv) then
            iceStore%UALoss(i) = iceStore%UALoss(i)+iceStore%ULossTop*iceStore%areaTopSurface
        endif

    enddo   
  
    iceStore%volumeTop  = VTank *(1d0-iceStore%heightIceHx/HTank) ! the volume on top of the heat exchangers
    iceStore%volumeBot  = VTank - iceStore%volumeTop   

    ! calculate the vol of water for each Cv 

    call calculateMassOfWater(iceStore,immersedHx)                             

    iceStore%VTankEff = sum(iceStore%volWater(1:nCv))        

    

    end subroutine calculateGeo

subroutine initializeMassOfIce(iceStore,immersedHx)

    use spfGlobalConst
    use iceStoreConst
    use iceStoreDef
    use hxModule

    implicit none                

    type(iceStoreStruct), intent(inout),target :: iceStore  
    type(hxStruct), intent(inout) :: immersedHx(nIHX)
    integer :: iHx,k,j,cvWithHx
    double precision :: maxIceCv,iceMassHxCv,massLeft,sumFactorsAllHx, iceAdded,&
                        iceLeft,r,usedIcePerCv
    double precision, allocatable :: factorCv(:)
    integer :: error,nCvWithHx,nHxInsideCv,hxUsed
    
    ! Distribute the inital kg of ice in the layers

    if(iceStore%iceFloatingIni>0.0) then           
            
        !only floating ice. 
        if(iceStore%meltCrit<1) then
            iceStore%iceFloating   = iceStore%iceFloatingIni
            iceStore%iceFloatingOld = iceStore%iceFloating      
            call reDistributeIce(iceStore)
        else
            ! ice on hx.                        
            !count = 0
            !do iHx=1,iceStore%nHx                                         
            !    if(immersedHx(iHx)%numberOfCv>0) then
            !        count  = count+1
            !    endif
            !enddo
            
            allocate(factorCv(iceStore%nCv),stat=error)
            
            iceLeft = iceStore%iceFloatingIni
            
            nCvWithHx = 0
            
            !Loop for all hx and Cv to see how many Cv have ahx in
            
            do j=1,iceStore%nCv
                cvWithHx=0
                do iHx=1,iceStore%nHx
                    if(immersedHx(iHx)%numberOfCv>0) then
                        do k=1,immersedHx(iHx)%numberOfCv 
                            if(immersedHx(iHx)%factorHxToTank(k,j)>0.) then 
                                cvWithHx=1  !we could break the loop here
                            endif
                        end do
                    end if                    
                end do
                nCvWithHx=nCvWithHx+cvWithHx
            end do
            
            usedIcePerCv = iceLeft/nCvWithHx                          
            
            do j=1,iceStore%nCv                            
            
                maxIceCv    = iceStore%rhoWater*iceStore%maxIceFrac*(iceStore%VTank/iceStore%nCv-iceStore%vHxCv(j))
                cvWithHx = 0
                
                do iHx=1,iceStore%nHx
                    if(immersedHx(iHx)%numberOfCv>0) then
                        do k=1,immersedHx(iHx)%numberOfCv 
                            if(immersedHx(iHx)%factorHxToTank(k,j)>0.) then 
                                cvWithHx=1  !we could break the loop here
                            endif
                        end do
                    end if                    
                end do
                
                if(cvWithHx) then
                    
                   
                    nHxInsideCv = 0
                    do iHx=1,iceStore%nHx
                        hxUsed = 0
                        if(immersedHx(iHx)%numberOfCv>0) then                     
                            do k=1,immersedHx(iHx)%numberOfCv    
                                hxUsed=1
                            enddo
                        endif
                        nHxInsideCv=nHxInsideCv+hxUsed
                    enddo
                    
                    do iHx=1,iceStore%nHx
                        if(immersedHx(iHx)%numberOfCv>0) then    
                            do k=1,immersedHx(iHx)%numberOfCv        
                                
                                if(immersedHx(iHx)%factorHxToTank(k,j) > 0.) then 
                            
                                    r = immersedHx(iHx)%factorHxToTank(k,j)/nHxInsideCv
                                    iceAdded = min(iceLeft,usedIcePerCv*r) ! I divide equally by hx in each Cv.
                                    immersedHx(iHx)%iceMassCv(k) = immersedHx(iHx)%iceMassCv(k) + iceAdded
                                    immersedHx(iHx)%volIceCv(k)  = immersedHx(iHx)%iceMassCv(k)/iceStore%rhoIce/immersedHx(iHx)%nParallelHx                               
                                    iceLeft = iceLeft - iceAdded
                                endif
                            enddo                                              
                        endif                         
                    enddo
                                        
                endif                                                                                                                                                                                                                                                     
                        
            enddo
            
            ! initialize thickness from mass in each Hx cv
            
            do iHx=1,iceStore%nHx
                if(immersedHx(iHx)%numberOfCv>0) then    
                    do k=1,immersedHx(iHx)%numberOfCv
                        if(immersedHx(iHx)%geometry==PLATE) then                            
                            immersedHx(iHx)%iceThickCv(k) = immersedHx(iHx)%iceMassCv(k)/(immersedHx(iHx)%dA*iceStore%rhoIce)
                        elseif(immersedHx(iHx)%geometry==COIL) then
                            
                            immersedHx(iHx)%dOutIce(k)  = sqrt(4.0*immersedHx(iHx)%volIceCv(k)/pi/immersedHx(iHx)%dL+immersedHx(iHx)%dOut**2)
                        endif
                    enddo
                    immersedHx(iHx)%iceMass = sum(immersedHx(iHx)%iceMassCv(1:immersedHx(iHx)%numberOfCv))  
                endif
            enddo                                   
                        
            massLeft = iceStore%iceFloatingIni - sum(immersedHx(1:iceStore%nHx)%iceMass)
            
            if(massLeft>1e-4) then   

                !from top to bottom
                do j=iceStore%nCv,1,-1                                  
                                        
                    if(massLeft/(iceStore%rhoIce*iceStore%volWater(j))> iceStore%maxIceFrac) then                           
                        iceStore%iceFloatMass(j) = iceStore%maxIceFrac*iceStore%vTankMinusHxCv(j)*iceStore%rhoIce
                        massLeft                 = massLeft - iceStore%iceFloatMass(j)
                    else
                        iceStore%iceFloatMass(j) = massLeft
                        massLeft = 0.0d0
                    endif                      
                    
                enddo   
            else if (massLeft < -1e-6) then   
                write(iceStore%MyMessage,'("initializeMassOfIce. massLeft < 0 =")') massLeft
                call Messages(-1,Trim(iceStore%MyMessage),'FATAL', iceStore%iUnit,iceStore%iType) 
            endif
                
            call calculateQFromHxToStorage(iceStore,immersedHx)
            
            deallocate(factorCv,stat=error)
            
        endif
        
        call calculateMassOfIce(iceStore) 
        call calculateMassOfWater(iceStore,immersedHx) !readjust         
        call checkStorageStatus(iceStore,immersedHx)                                
    endif                          
    
    
end subroutine initializeMassOfIce
    
    ! ===========================================================================
    !> @brief: Calculates the geomertry of the storage and immersed heat exchanger 
    !> @param  iceStore : ice Storage structure 
    !> @param  Tinit : initial temperature
    !> @param  nCv : number of tank CV
    !> @return iceStore with initialized variables
    ! ===========================================================================

    subroutine initialize(iceStore,Tinit)

    use iceStoreConst
    use iceStoreDef

    implicit none                

    type(iceStoreStruct), intent(inout), target :: iceStore  
    double precision, intent(in) :: Tinit(:)

    integer :: i, j, nCv

    nCv = iceStore%nCv 
!    iceStore%nCvInHxs = 0.0d0

    ! Here the inputs still not readed, so we do not know nHx

    !nCv = iceStore%nCv; nHx = iceStore%nHx

    !if (simtime.lt.(time0+dt/2)) then DO THIS OUTSIDE THE FUNCTION
    !         Set initial conditions:
!    iceStore%addNodalLossCoef = 0
    iceStore%noticeFound = 0


    iceStore%itIceStore = 1
    iceStore%itStore = 1
    iceStore%itTrnsys = 1
    iceStore%itDtTrnsys = 1           

    do i=1,nCv      

        iceStore%T(i)    = Tinit(i)
        iceStore%Told(i) = Tinit(i)            

        if(Tinit(i)<0.0) then
            write(iceStore%MyMessage,'("Initial water temperature below 0=",f" for Cv=",d)') Tinit(i),i
            call Messages(-1,Trim(iceStore%MyMessage),'FATAL', iceStore%iUnit,iceStore%iType)                
        end if

    enddo
    
    iceStore%sumQIce      = 0.0d0        
    iceStore%qFused       = 0.0d0
    iceStore%fusedIceFloatMass = 0.0d0
    iceStore%imbalance = 0.0d0

    iceStore%iceFloatingOld      = 0.0d0
    iceStore%iceTotalMass      = 0.0d0
    iceStore%iceTotalMassOld      = 0.0d0
    iceStore%iceFloating         = 0.0d0        
!    iceStore%hxMode           = 0
    iceStore%tFreeze          = 0.0d0
    iceStore%tSubcool         = 0.0d0
    iceStore%tBoil            = 100.0d0

    iceStore%tStoreAv         = 0.0d0
    iceStore%dy               = 0.0d0
    iceStore%e0               = 0.0d0
    iceStore%e1               = 0.0d0

    iceStore%timeInHours   = 0.0d0
    iceStore%dtsec    = 0.0d0

    iceStore%tankGeometry = 0 ! 0 is a box, 1 a cilynder                
!    iceStore%arrangmentHx = 0
    iceStore%checkParameters = 1

    iceStore%iceIsReleased = 0

    iceStore%tEnvTop = 0.0d0
    iceStore%tEnvBot = 0.0d0
    iceStore%UlossTop = 0.0d0
    iceStore%UlossBot = 0.0d0
    iceStore%areaTopSurface = 0.0d0      
    iceStore%areaBotSurface = 0.0d0

    iceStore%storeFull         = 0
    iceStore%storeTotallyFull  = 0        
    iceStore%iceThickMax       = 0d0
    iceStore%volumeTop         = 0d0          
    iceStore%heightIceHx       = 0d0

    iceStore%maxIceFracIceLayer = 0.0d0
    iceStore%errorStorageLoop    = 0.0d0
    iceStore%errorIceStorageLoop = 0.0d0

    iceStore%RaMeltingFloat = 0.0d0
    iceStore%NuMeltingFloat = 0.0d0
    
    iceStore%deIceIsPossible = 1 !
    iceStore%iceHx = 0.0
    
    iceStore%xBetweenPipes = 0.0
    iceStore%yBetweenPipes = 0.0
    
    iceStore%iceBlockGrowingMode = 0
    
end subroutine initialize

subroutine useOldTimeStep(iceStore,immersedHx)

    use iceStoreConst
    use iceStoreDef
    use hxModule
    
    implicit none                

    type(iceStoreStruct), intent(inout), target :: iceStore  
    type(hxStruct), intent(inout), target :: immersedHx(nIHX)

    integer :: nCv, nHx, i, iHx !, iceModeIsActive, nCvHx, iceOnHxCv               

    nCv = iceStore%nCv; nHx = iceStore%nHx        

    iceStore%iceTotalMass = iceStore%iceTotalMassOld
    iceStore%iceFloating  = iceStore%iceFloatingOld  
    
    do i=1,nCv

        iceStore%T(i) = iceStore%Told(i)    
        iceStore%iceFloatMass(i) = iceStore%iceFloatMassOld(i)
        iceStore%volWater(i) = iceStore%volWaterOld(i) 
        iceStore%iceMassHxCv(i) = iceStore%iceMassHxCvOld(i) 
    enddo

    do iHx=1,iceStore%nHx

        if(immersedHx(iHx)%isUsed) then
                
            
            immersedHx(iHx)%iceThickMelt = immersedHx(iHx)%iceThickMeltOld
            immersedHx(iHx)%iceThick     = immersedHx(iHx)%iceThickOld
            immersedHx(iHx)%iceThickIn   = immersedHx(iHx)%iceThickInOld
            
            immersedHx(iHx)%iceMass = immersedHx(iHx)%iceMassOld
            
            do i=1,immersedHx(iHx)%numberOfCv 
            
                immersedHx(iHx)%tIce(i) = immersedHx(iHx)%tIce0(i)                
                !immersedHx(iHx)%t0(i) = 0.5*(immersedHx(iHx)%t(i)+immersedHx(iHx)%t(i+1)) ! T is at the cv faces, while t0 is at the center                       
                immersedHx(iHx)%volIceCv(i) = immersedHx(iHx)%volIceCvOld(i)    
                immersedHx(iHx)%iceMassCv(i) = immersedHx(iHx)%iceMassCvOld(i) 
                
                if(immersedHx(iHx)%geometry==PLATE) then                
                    
                   
                    
                    immersedHx(iHx)%iceThickCv(i) = immersedHx(iHx)%iceThickCvOld(i) 
                    immersedHx(iHx)%iceThickInCv(i) = immersedHx(iHx)%iceThickInCvOld(i)    
                    immersedHx(iHx)%iceThickMeltCv(i) = immersedHx(iHx)%iceThickMeltCvOld(i)                     
                    
                elseif(immersedHx(iHx)%geometry==COIL) then
                
                    immersedHx(iHx)%dEqCv(i) = immersedHx(iHx)%dEqCvOld(i)
                                
                   
                
                    immersedHx(iHx)%dOutIce(i) = immersedHx(iHx)%dOutIceOld(i)    
                    immersedHx(iHx)%dInIce(i) = immersedHx(iHx)%dInIceOld(i)  
                    if(immersedHx(iHx)%dInIce(i)>immersedHx(iHx)%dOutIce(i)) then
                    iceStore%dummy=1
                    endif
                    immersedHx(iHx)%dOutMeltIce(i) = immersedHx(iHx)%dOutMeltIceOld(i)
                endif
                
            enddo
           
        endif
        
    end do

    
   
                

end subroutine useOldTimeStep 
        
    ! ===========================================================================
    !> @brief: called once in all calculation at the first time step ??
    !> @param  iceStore iceStoreStruct 
    !> @return iceStore with udated time step variables
    ! =========================================================================== 

    subroutine updateTimeStep(iceStore,immersedHx)

    use iceStoreConst
    use iceStoreDef
    use hxModule
    use hxFunc
    
    implicit none                

    type(iceStoreStruct), intent(inout), target :: iceStore  
    type(hxStruct), intent(inout), target :: immersedHx(nIHX)

    integer :: nCv, nHx, i, iHx,notpossible !, iceModeIsActive, nCvHx, iceOnHxCv               
    double precision :: dummy=0.0
    nCv = iceStore%nCv; nHx = iceStore%nHx        

    iceStore%iceTotalMassOld =  iceStore%iceTotalMass
    iceStore%iceFloatingOld  = iceStore%iceFloating    
    
    do i=1,nCv
        iceStore%Told(i)        = iceStore%T(i)
        iceStore%iceFloatMassOld(i)  = iceStore%iceFloatMass(i)
        iceStore%volWaterOld(i) = iceStore%volWater(i)
        iceStore%iceMassHxCvOld(i) =iceStore%iceMassHxCv(i) 
    enddo

    if(iceStore%ItDtTrnsys==5168) then
            iceStore%dummy = 1
    endif
    
    
    do iHx=1,iceStore%nHx

        if(immersedHx(iHx)%isUsed) then
                
            
            immersedHx(iHx)%iceThickMeltOld = immersedHx(iHx)%iceThickMelt
            immersedHx(iHx)%iceThickOld     = immersedHx(iHx)%iceThick   
            immersedHx(iHx)%iceThickInOld   = immersedHx(iHx)%iceThickIn
            
            immersedHx(iHx)%iceMassOld      = immersedHx(iHx)%iceMass
            
            do i=1,immersedHx(iHx)%numberOfCv 
            
                immersedHx(iHx)%tIce0(i)        = immersedHx(iHx)%tIce(i)                
                immersedHx(iHx)%t0(i)           = 0.5*(immersedHx(iHx)%t(i)+immersedHx(iHx)%t(i+1)) ! T is at the cv faces, while t0 is at the center                       
                immersedHx(iHx)%volIceCvOld(i)  = immersedHx(iHx)%volIceCv(i)
                immersedHx(iHx)%iceMassCvOld(i) = immersedHx(iHx)%iceMassCv(i)
                immersedHx(iHx)%tWall0(i)       = immersedHx(iHx)%tWall(i)
                immersedHx(iHx)%tStore0(i)      = immersedHx(iHx)%tStore(i)                               
                
                if(immersedHx(iHx)%geometry==PLATE) then                
               
                    !if(immersedHx(iHx)%iceThickCv(i)<=1e-8 .and. immersedHx(iHx)%iceThickInCv(i)>1e-8) then
                    !   notpossible=1
                    !endif
                     
                    !RESET STAFF IS MOVED WHEN THE TIME STEP HAS CONVERGED !!
                    !If inner ice layer has reacehd the melted one, then we reset them
                    
                    if(immersedHx(iHx)%resetIceThickInCv(i) == 1) immersedHx(iHx)%iceThickInCv(i) = 0.0d0 !reset because of melting
                    if(immersedHx(iHx)%resetIceThickInAndMeltCv(i) == 1) then !reset becasue IceThicCvIn gets in contact with melted ice. 
                        !if(immersedHx(iHx)%iceThickInCv(i)>=immersedHx(iHx)%iceThickMeltCv(i)) then
                        immersedHx(iHx)%iceThickInCv(i)   = 0.0
                        immersedHx(iHx)%iceThickMeltCv(i) = 0.0
                    endif
                    
                    immersedHx(iHx)%iceThickCvOld(i)     = immersedHx(iHx)%iceThickCv(i)
                    immersedHx(iHx)%iceThickInCvOld(i)   = immersedHx(iHx)%iceThickInCv(i)
                    immersedHx(iHx)%iceThickMeltCvOld(i) = immersedHx(iHx)%iceThickMeltCv(i)                   
                    
                    !if(immersedHx(iHx)%iceThickMeltCv(i)>0 .and.  immersedHx(iHx)%iceThickCv(i)==0) immersedHx(iHx)%iceThickMeltCv(i)=0
                    
                elseif(immersedHx(iHx)%geometry==COIL) then
                
                    immersedHx(iHx)%dEqCvOld(i)          = immersedHx(iHx)%dEqCv(i)
                    
                    !This is true when we melt and the DinIce>=, then we add dIn to dOut and 
                    !we have to reset dIn to zero here.
                    
                    if(immersedHx(iHx)%resetDInIceToZero(i) == 1) then
                        immersedHx(iHx)%dInIce(i)      = immersedHx(iHx)%dOut                        
                    endif
                    
                    !CHECK THIS !!!!!!!!!!!!!!!!!
                    if(abs(immersedHx(iHx)%dInIce(i)-immersedHx(iHx)%dOutMeltIce(i))<1e-15 .and. immersedHx(iHx)%dOutIce(i)>(immersedHx(iHx)%dOut+1e-10)) then
                        immersedHx(iHx)%dInIce(i)      = immersedHx(iHx)%dOut
                        immersedHx(iHx)%dOutMeltIce(i) = immersedHx(iHx)%dOut
                    endif
                    
                    
                    
                    !If melted ice layer has reached the outer one, then we reset them
                    if(abs(immersedHx(iHx)%dOutIce(i)-immersedHx(iHx)%dOutMeltIce(i))<1e-15 .and. immersedHx(iHx)%dOutIce(i)>(immersedHx(iHx)%dOut+1e-10)) then
                        immersedHx(iHx)%dOutIce(i)     = immersedHx(iHx)%dInIce(i) ! Melt reaches dOut and we set Dout to Din if exist
                        immersedHx(iHx)%dOutMeltIce(i) = immersedHx(iHx)%dOut
                        immersedHx(iHx)%dInIce(i)      = immersedHx(iHx)%dOut
                    endif
                    
                    !If inner ice layer has reached the melted one, then we reset them
                    
                    
                    immersedHx(iHx)%dOutIceOld(i)        = immersedHx(iHx)%dOutIce(i)
                    immersedHx(iHx)%dInIceOld(i)         = immersedHx(iHx)%dInIce(i)
                    immersedHx(iHx)%dOutMeltIceOld(i)    = immersedHx(iHx)%dOutMeltIce(i)
                    !
                    if(immersedHx(iHx)%dInIce(i)>immersedHx(iHx)%dOutIce(i)) then
                        iceStore%dummy=1
                    endif
                    if(immersedHx(iHx)%dOutMeltIce(i)>immersedHx(iHx)%dOutIce(i)) then
                        iceStore%dummy=1
                    endif
                    if(immersedHx(iHx)%dInIce(i)>immersedHx(iHx)%dOutMeltIce(i)) then
                        iceStore%dummy=1
                    endif
                endif
                
               
    
                call checkHeatExchangerMass(iceStore,immersedHx(iHx),dummy,i,200)
            enddo
           
        endif
        
    end do

    
    

     if(iceStore%sumQHx>0. .and. iceStore%iceFloating>iceStore%iceFloatingOld .and. iceStore%iceIsReleased ==0) then
        write(iceStore%MyMessage,'("Heating Store and floating ice growing !!!")') 
        call Messages(-1,Trim(iceStore%MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType)  
     endif
     
   
                

    end subroutine updateTimeStep 



    ! ===========================================================================
    !> @brief mix : Mix the storage tank CV when the density gradient is negative
    ! ------------------------------------------------------------------
    !> @param  n : number of CV 
    !> @param  M : mass flow vector [kg/s]
    !> @param  T : temperature vector [K]
    ! ------------------------------------------------------------------
    !> @return: T : Mixed T storage tank CV temperatures [K]
    ! ===========================================================================                     

    subroutine mixUp(iceStore,ii)

    use iceStoreDef

    integer :: nCv,i,j,iteMax
    integer, intent(in) :: ii
    double precision,pointer :: T(:),M(:)
    type(iceStoreStruct), intent(inout), target :: iceStore 
    double precision :: ts,xs

    T => iceStore%T
    M => iceStore%M
    nCv = iceStore%nCv        
    j=ii       
    ts=T(j)*M(j)
    xs=M(j)

    do while((ts/xs)>T(j+1))
        ts=ts+T(j+1)*M(j+1)
        xs=M(j+1)+xs                       
        if (j==(nCv-1)) then                       
            j=j+1                        
            goto 22
        endif                                            
        j = j+1                            
    enddo                   

22  do i=ii,j
        T(i)=ts/xs                    
    enddo  

    end subroutine mixUp

    subroutine mixDown(iceStore,ii)

    use iceStoreDef

    integer :: nCv,i,j
    integer, intent(in) :: ii
    double precision,pointer :: T(:),M(:)
    type(iceStoreStruct), intent(inout), target :: iceStore 
    double precision :: ts,xs,tsOverXs


    T => iceStore%T
    M => iceStore%M
    nCv = iceStore%nCv                    
    j = ii
    ts=T(j)*M(j)
    xs=M(j)

    tsOverXs = ts/xs

    do while(tsOverXs>T(j-1))

        ts=ts+T(j-1)*M(j-1)
        xs=M(j-1)+xs                       
        if (j==2) then                       
            j=j-1                  
            goto 11
        endif                                            
        j = j-1                            
    enddo            

11  do i=ii,j,-1
        T(i)=ts/xs                
    enddo  

    end subroutine mixDown

    subroutine reversionEliminationAlgorithm(iceStore)

    use iceStoreDef
    use physProp
    use Trnsysfunctions

    type(iceStoreStruct), intent(inout), target :: iceStore    
    integer :: nCv
    double precision,pointer :: T(:)    
    double precision :: tFlip,precision
    integer :: i,iteMax,ite
    logical isTinverted

    T => iceStore%T
    !M => iceStore%M
    nCv = iceStore%nCv

    isTinverted=.true.
    iteMax = 100
    ite = 0
    tFlip = iceStore%tFlip
    precision = 1e-4

    !if(iceStore%verboseLevel==4) write (myScreenUnit,*) 'DEGUB TYPE 860 ICE STORAGE : MIXING TIME ',iceStore%timeInSeconds/3600.

    do while (isTinverted == .true. .and. ite<=iteMax)

        isTinverted=.false.       	     	                		       

        do i=1,nCv-1		

            if((T(i)-precision)>T(i+1) .and. T(i)>tFlip) then
                isTinverted= .true.    
                call mixUp(iceStore,i)
                exit
            else if ((T(i)+precision)<T(i+1) .and. T(i)<tFlip) then     
                isTinverted= .true.    
                call mixDown(iceStore,i+1)                
                exit
            endif            
        enddo        

        ite = ite+1

    enddo

    !check 

    do i=1,nCv-1     
        if((T(i)-precision)>T(i+1) .and. T(i)>tFlip) then       
            !write(myScreenUnit,*) ' Mixing algorithm is not working in upstream mode'            
            write(iceStore%MyMessage,'("Mixing algorithm is not working in upstream mode")') 
            call Messages(-1,Trim(iceStore%MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType) 
        else if  ((T(i)+precision)<T(i+1) .and. T(i)<tFlip) then                  
            !write(myScreenUnit,*) ' Mixing algorithm is not working in downstream mode'              
            write(iceStore%MyMessage,'("Mixing algorithm is not working in downstream mode")') 
            call Messages(-1,Trim(iceStore%MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType) 
        endif    
    enddo    


end subroutine reversionEliminationAlgorithm

subroutine calculateQFromHxToStorage(iceStore,immersedHx)   
    
        use hxModule
        use iceStoreDef
    
        implicit none
        
        type(hxStruct), intent(inout) :: immersedHx(nIHX)
        type(iceStoreStruct), intent(inout) :: iceStore  
       
        double precision :: sumQsen,qSumSenHx,sumQlat,qSumLatHx,& ! to check heat flows 
                            qSen,qLat,iceMass,sumIceMassHx,iceMassHx,sumQIceAcum,qIceAcum,qIceAcumHx
        integer :: iHx,n, j
        
      
        !< Sensible heat 
        
        !call calculateQvFromHX(immersedHx,iceStore) ! qv from all Hx. Calculated iceStore%qhx
                                              
        sumQsen = 0.0
        sumQLat = 0.0
        sumIceMassHx = 0.0
        sumQIceAcum = 0.0
        
        do iHx=1,iceStore%nHx
            if(immersedHx(iHx)%isUsed) then
                do n=1,iceStore%nCv 
                    
                    qSen = 0.0
                    qLat = 0.0
                    iceMass = 0.0
                    qIceAcum = 0.0
                    
                    do j=1,immersedHx(iHx)%numberOfCv                                       
                     
                        qSen = qSen - (immersedHx(iHx)%qHxCv(j)+immersedHx(iHx)%qAcumIceCv(j))*immersedHx(iHx)%factorHxToTank(j,n)      !including all parallel hx       
                        qLat = qLat + immersedHx(iHx)%qIceCv(j)*immersedHx(iHx)%factorHxToTank(j,n)                     
                        iceMass = iceMass + immersedHx(iHx)%iceMassCv(j)*immersedHx(iHx)%factorHxToTank(j,n)  
                        !We should check here is the Cv of water is already full of ice. In principle this should be considered by blocking the Cv of the hx, but
                        !it could be that part of a hx is inside this Cv of water and it is not blocked becasue it is only a part of the whole hx cv
                        
                        qIceAcum = qIceAcum + immersedHx(iHx)%qAcumIceCv(j)
                                                
                    end do
                
                    !This includes all parallel Hx's
                
                    iceStore%qhx(iHx,n)    = qSen
                    iceStore%qIceCv(iHx,n) = qLat                    
                    iceStore%iceMassHx(iHx,n) = iceMass
                    
                    iceStore%qIceAcumCv(iHx,n) = qIceAcum
                
                    sumQsen = sumQsen + iceStore%qhx(iHx,n) 
                    sumQlat = sumQlat + iceStore%qIceCv(iHx,n)
                    sumIceMassHx = sumIceMassHx + iceStore%iceMassHx(iHx,n)
                    sumQIceAcum = iceStore%qIceAcumCv(iHx,n)
                    
                enddo
            endif
            
        end do
                
       
        if(1) then           
        
            qSumSenHx = 0.0   
            qSumLatHx = 0.0 
            qIceAcumHX = 0.0
            iceMassHX = 0.0
            
            do iHx=1,iceStore%nHx
                qSumSenHx = qSumSenHx + immersedHx(iHx)%qHxToTnk - immersedHx(iHx)%qAcumIce
                qSumLatHx = qSumLatHx + immersedHx(iHx)%qIce  
                iceMassHx = iceMassHx + immersedHx(iHx)%iceMass
                qIceAcumHX = qIceAcumHX + immersedHx(iHx)%qAcumIce
            enddo   
            
            if(abs(qIceAcumHx-sumQIceAcum)>1e-8) then                     
                write(iceStore%myMessage,*) 'ERROR in passing sensible Qice Diff=',abs(qIceAcumHx-sumQIceAcum),'  qIceAcumHx=',qIceAcumHx,' sumQIceAcum=',sumQIceAcum
                call messages(-1,trim(iceStore%myMessage),'warning',iceStore%iUnit,iceStore%iType)
            endif  
            
                   
             if(abs(iceMassHx-sumIceMassHx)>1e-8) then                     
                write(iceStore%myMessage,*) 'ERROR in passing ice mass Diff=',abs(iceMassHx-sumIceMassHx),'  iceMassHx=',iceMassHx,' sumIceMassHx=',sumIceMassHx                  
                call messages(-1,trim(iceStore%myMessage),'warning',iceStore%iUnit,iceStore%iType)
             endif  
             
            ! In theory this should be exactly zero. We should double check why is low but not 0
            if(abs(qSumSenHx-sumQsen)>1e-8) then                     
                write(iceStore%myMessage,*) 'ERROR in passing sensible heat Diff=',abs(qSumSenHx-sumQsen),' QsenTank=',sumQsen,' sumQHxSen=',qSumSenHx                     
                call messages(-1,trim(iceStore%myMessage),'warning',iceStore%iUnit,iceStore%iType)
            endif            
            
             if(abs(qSumLatHx-sumQlat)>1e-8) then                     
                write(iceStore%myMessage,*) 'ERROR in passing latent heat Diff=',abs(qSumLatHx-sumQlat),' QlatTank=',sumQlat,' sumQHxLat=',qSumLatHx                     
                call messages(-1,trim(iceStore%myMessage),'warning',iceStore%iUnit,iceStore%iType)
             endif 
             
             
        endif
        
end subroutine calculateQFromHxToStorage
     
subroutine reCalculateMIceFromOutsideMelting(iceStore,immersedHx)
    
    use hxModule
    use iceStoreDef  

    use TrnsysConstants   
    
    implicit none
    
    type(hxStruct), intent(inout) :: immersedHx(nIHX)    
    type(iceStoreStruct), intent(inout) :: iceStore 
    double precision :: iceMassHxToCvStore,qFusedHxCv, volInner, volOuter, iceMassMelted
    integer :: j,k,i,correct  
    
    correct = 0   
    
      do j=1,iceStore%nHx   
                
        immersedhx(j)%iceMassMeltedOutside = 0.0
          
        iceMassHxToCvStore = 0.0
                
        if(immersedHx(j)%isUsed) then        
            
            do k=1,immersedHx(j)%numberOfCv                                         
                                                   
                iceMassMelted = sum(immersedhx(j)%iceMassMeltedOutsideCv(k,1:iceStore%nCv))
                
                immersedhx(j)%iceMassMeltedOutside = immersedhx(j)%iceMassMeltedOutside + iceMassMelted
                
                if(iceMassMelted>0.) then  
                                       
                    correct = 1                                       
                    
                    immersedhx(j)%iceMassCv(k)  = max(immersedhx(j)%iceMassCv(k)-iceMassMelted,0.0)                      
                    if(immersedhx(j)%iceMassCv(k)>200.) then
                        iceStore%dummy=1
                    endif
                    immersedHx(j)%volIceCv(k)   = immersedHx(j)%iceMassCv(k)/(immersedHx(j)%nParallelHx*iceStore%rhoIce)
                        
                    if(immersedHx(j)%geometry==PLATE) then
                        ! I use iceOld because if I use ice it is changed for each iteration in one time step
                        ! and iceOld = ice in this case because no ice formed or melted is on.                                                                                                                                                    
                        immersedHx(j)%iceThickCv(k) = immersedHx(j)%iceMassCv(k)/(immersedHx(j)%area/immersedHx(j)%numberOfCv*iceStore%rhoIce)
                        
                    else                            
                           
                        volInner = pi*immersedHx(j)%dL*(immersedHx(j)%dInIce(k)**2-immersedHx(j)%dOut**2)/4.0
                                                        
                        if(immersedHx(j)%volIceCv(k) >= volInner) then ! We only melt the outer layer
                            volOuter = immersedHx(j)%volIceCv(k) - volInner
                            immersedHx(j)%dOutIce(k) = sqrt(volOuter*4.0/pi/immersedHx(j)%dL+immersedHx(j)%dOutMeltIce(k)**2)
                            if(immersedHx(j)%dInIce(k)>immersedHx(j)%dOutIce(k) .and. immersedHx(j)%resetDinIceToZero(k)==0) then
                                iceStore%dummy=1
                            endif 
                            if(abs(immersedHx(j)%dOutIce(k)-immersedHx(j)%dOut)<1e-10) then
                                iceStore%dummy=1
                            endif
                            
                        else                                                               
                                
                            if(abs(immersedHx(j)%dInIce(k)-immersedHx(j)%dOutMeltIce(k))<1e-10) then
                                    
                                write(iceStore%MyMessage,'("DinIce reached dOutMelt. Be careful of convergence")') 
                                call Messages(-1,Trim(iceStore%MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType)  
                                    
                                ! We melt all the outer layer and not the inner layer
                                ! So we have to correct and reduce the qMelt. Otherwise we would nned to melt the dInIce and becasue
                                ! this function is called each iteration can be dangerous. Switching form one if to another.
                                !immersedHx(j)%dInIce(k) = immersedHx(j)%dOut
                                !immersedHx(j)%dOutMeltIce(k) = immersedHx(j)%dOut
                                
                            else                                                                                            
                                write(iceStore%MyMessage,'("Melted more ice than existed in the outer layer")') 
                                call Messages(-1,Trim(iceStore%MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType)    
                            endif
                                
                            !immersedHx(j)%dOutIce(k) = sqrt(immersedHx(j)%volIceCv(k)*4.0/pi/immersedHx(j)%dL+immersedHx(j)%dOutMeltIce(k)**2)
                                
                        endif                                                                                                               
                    endif   !plate,cil
                endif !if iceMassMlete >0
                
                !iceMassHxToCvStore = iceMassHxToCvStore + immersedHx(j)%iceMassCv(k)*immersedHx(j)%factorHxToTank(k,i) 
                
            enddo !k = 1, k  = nHxCv
            
            immersedHx(j)%iceMass  = sum(immersedHx(j)%iceMassCv(1:immersedHx(j)%numberOfCv))       
            
            
            if(immersedHx(j)%geometry==PLATE) then
                immersedHx(j)%iceThick = sum(immersedHx(j)%iceThickCv(1:immersedHx(j)%numberOfCv))/immersedHx(j)%numberOfCv
            endif
            
            !This is usually calculated in QhxtoStorage, but since we are changing iceMassHx here we need to pass the information again
            !iceStore%iceMassHx(j,i) = iceMassHxToCvStore
          
        endif !if hx=j is used  
      enddo !j = 1 j = nHx                                                                                                       
   ! enddo ! i=1 i = nCv
        
    if(correct) then
        
        !calculation of iceMassHx(j,i) from iceMassCv
        call calculateQFromHxToStorage(iceStore,immersedHx)
        
        do i=1,iceStore%nCv                        
          iceStore%iceMassHxCv(i) = 0.0
          do j=1,iceStore%nHx                                               
            if(immersedHx(j)%isUsed) then        
                iceStore%iceMassHxCv(i) = iceStore%iceMassHxCv(i) + iceStore%iceMassHx(j,i) 
            endif
          enddo
          iceStore%iceTotalMassCv(i) = iceStore%iceFloatMass(i)+iceStore%iceMassHxCv(i)
        enddo               
        call calculateMassOfIce(iceStore)
    endif
    
    
     
end subroutine reCalculateMIceFromOutsideMelting

    
    ! ===========================================================================
    !> @brief: postProcess : calculate some post processing task for each time 
    !> iteration
    ! ------------------------------------------------------------------
    !> @param iceStore : type iceStoreStruct
    ! ------------------------------------------------------------------
    !> @return qloss, sink, and sources inside iceStore structure
    ! ===========================================================================                                            

    subroutine postProcessDti(iceStore,immersedHx)

        use iceStoreConst
        use iceStoreDef 

        implicit none                
        
        type(iceStoreStruct), intent(inout), target :: iceStore                                        
        type(hxStruct), intent(inout), target :: immersedHx(nIHX)
        integer :: iHx,nHxCv,i,j, dummy
        
        if(iceStore%recalculateInDti==1) call reCalculateMIceFromOutsideMelting(iceStore,immersedHx)    
        
        call checkBalances(iceStore,immersedHx)                        
            
        if(iceStore%itDtTrnsys>=29853) then
            dummy=1
        end if 
        do j=1,iceStore%nCv
            if(iceStore%volWater(j)<0.) then            
                iceStore%storeTotallyFull = 1                 
                write(iceStore%MyMessage,*) 'calculateMassOfWater NEGATIVE WATER VOLUME= ',iceStore%volWater(j),' in Cv=',j
                call messages(-1,trim(iceStore%MyMessage),'NOTICE',iceStore%iUnit,iceStore%iType)                  
            endif
        enddo
        
        do iHx=1,iceStore%nHx            
            
            if(immersedHx(iHx)%isUSed) then
                
                nHxCv = immersedHx(iHx)%numberOfCv                                    
            
                !do i=1,nHxCv
                !    immersedHx(iHx)%tFilm(i) = 0.75*immersedHx(iHx)%tWall(i)+0.25*immersedHx(iHx)%tStore(i)                                            
                !enddo
            
                immersedHx(iHx)%tWallAv  = sum(immersedHx(iHx)%tFilm(1:nHxCv))/nHxCv            
                immersedHx(iHx)%tFluidAv = sum(immersedHx(iHx)%t(1:nHxCv+1))/(nHxCv+1)
            
            endif
            
        enddo

    end subroutine postProcessDti

    

    subroutine checkBalances(iceStore,immersedHx)

    use iceStoreDef
    use hxModule
    
    implicit none                

    type(iceStoreStruct), intent(inout), target :: iceStore  
    type(hxStruct), intent(inout), target :: immersedHx(nIHX)  
    
    double precision :: resIceLayer,qSumHx,qFusion, totalArea ! resGlobal
    integer :: iHx, nCv, i, j, nHx, checkAll
    !double precision :: qhx,qacum,qloss,qf,resCv, 
    double precision :: volIce,volWater, sumArea, volIceHx,qLatentCalc,qAcumIce,qDiff
    logical :: avoid=.false.

    nCv = iceStore%nCv; nHx = iceStore%nHx

    !> global balance in the heat store
    
    !- iceStore%qAcumHx
    
    iceStore%sumQIceAcum = sum(immersedHx(1:nIHx)%qAcumIce)    
    
    iceStore%imbalance   = iceStore%sumQHx - iceStore%qAcumStore  - iceStore%sumQLoss  - iceStore%qFused + iceStore%sumQIce !+ iceStore%sumQIceAcum
    
    qLatentCalc = (iceStore%iceTotalMass - iceStore%iceTotalMassOld)*iceStore%H_pc/iceStore%dtsec
   
    qDiff       = abs(iceStore%sumQIce- iceStore%qFused-qLatentCalc-iceStore%sumQIceAcum)
   
    if(qDiff>1e-7 .and. iceStore%verboseLevel>=2) then
        write(iceStore%MyMessage,*) 'Latent heat DtIte=',iceStore%itDtTrnsys,' qIce= ',iceStore%sumQIce,' qFused=',iceStore%qFused,' QLat=',qLatentCalc,' qAcumIce=',iceStore%sumQIceAcum,' qDiff=',qDiff
        call messages(-1,trim(iceStore%MyMessage),'NOTICE',iceStore%iUnit,iceStore%iType)
       
    endif      
        
    if(iceStore%imbalance>1) then
         write(iceStore%MyMessage,*) 'IMBALANCE DtIte=', iceStore%imbalance  
    endif
    
    end subroutine checkBalances

    ! ===========================================================================
    !> @brief: reDistributeIce : Distribute the total floating ice from
    !  top to bottom. Used also for first time step to reDistribute initial 
    !  block of floating ice. Temperaturea are also rearranged if iceIsReleased
    ! ------------------------------------------------------------------
    !> @param iceStore : type iceStoreStruct
    ! ------------------------------------------------------------------
    !> @return iceFloating(i), T(i)
    ! ===========================================================================      
    
    subroutine reDistributeIce(iceStore)
    
        use spfGlobalConst
        use hxModule
        use iceStoreDef
    
        implicit none    
        
        type(iceStoreStruct), intent(inout), target :: iceStore
        integer :: nCv, j
        double precision :: iceLeft,fusedKgIce, kgMovedFromTopLayer, volOneLayer, &
                            iceMassHxCv, maxFrac
        
        !> Redistribute the mass of deatached ice in the store 
        ! We distribute the ice from top to bottom. We only allow some ice for each layer
        ! because the deatached ice can not fill all the volume        
        ! We redistribute all the ice using the iceFloating value, but we may have an imbalance in each layer
        ! if we move the ice without affecting the temperature left in the liquid CV.                
    
        if(iceStore%deIceIsPossible) then 
            
            iceLeft = iceStore%iceFloating
            nCv = iceStore%nCv
            !totalFloatingIceInHx = 0.0d0
    
            if(iceStore%iceFloating>0.d0) then   

                !from top to bottom
                do j=nCv,1,-1                                  
                    
                    volOneLayer = iceStore%volWater(j) !iceStore%VTankEff/iceStore%nCv
                     
                    ! it can happen due high initial Mass of ice in the storage that we put ice layers 
                    ! in the bottom part of the storage where hx are present and that is not good.
    
                    if(iceStore%iceMassHxCv(j)>0.) then
                        maxFrac = iceStore%maxIceFracIceLayer
                    else
                        maxFrac = iceStore%maxIceFrac
                    endif
                    
                    if(iceLeft/(iceStore%rhoIce*volOneLayer)>maxFrac) then   
                        !iceStore%iceFloatMass(j) = maxFrac*volOneLayer*iceStore%rhoIce
                        iceStore%iceFloatMass(j) = maxFrac*iceStore%vTankMinusHxCv(j)*iceStore%rhoIce
                        iceLeft                  = iceLeft - iceStore%iceFloatMass(j)
                    else
                        iceStore%iceFloatMass(j) = iceLeft
                        iceLeft = 0.0d0
                    endif                      
                    !totalFloatingIceInHx = totalFloatingIceInHx*iceStore%isHxLayerRatio(j)
                enddo     
            else
                iceStore%iceFloatMass(1:nCv) = 0.0
            endif  
    
            if(iceStore%verboseLevel>=1) then
                if(abs(sum(iceStore%iceFloatMass(1:nCv))-iceStore%iceFloating)>1e-10) then
                    write(iceStore%MyMessage,'("reDistribute WRONG SUM sum(iceMass)=",f" iceFloating=",f)') sum(iceStore%iceFloatMass(1:nCv)),iceStore%iceFloating  
                    call Messages(-1,Trim(iceStore%MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType)                       
                endif            
            endif
    
        endif !if de-ice is possible
        
        ! Rearrange water layers. If we move some ice layers up, the water will go down with the upper temperature
        ! and it will mix with the bottom layer
    
        if(iceStore%iceIsReleased) then
            do j=2,nCv                
                fusedKgIce = iceStore%qFusedFloatCv(j) *  iceStore%dtsec / iceStore%H_pc
                kgMovedFromTopLayer = iceStore%iceFloatMass(j) - (iceStore%iceFloatMassOld(j) - fusedKgIce)
                if(kgMovedFromTopLayer > 0.0) then  
                    iceStore%T(j-1) = (iceStore%T(j-1)*iceStore%M(j-1)+iceStore%T(j)*kgMovedFromTopLayer)/(iceStore%M(j-1)+kgMovedFromTopLayer)     
                    kgMovedFromTopLayer = kgMovedFromTopLayer
                endif
            enddo
        endif
        
    
    end subroutine reDistributeIce
    
    ! ===========================================================================
    !> @brief: check if storage is full (de-ice not possible) or if it is comeletly full
    !  which means that the ice storage is bypassed        
    ! ------------------------------------------------------------------
    !> @param iceStore : type iceStoreStruct
    ! ------------------------------------------------------------------
    !> @return iceFloating, ice, melt, storeFull, fusedIceFloatMass, qFused
    ! ===========================================================================      

    subroutine checkStorageStatus(iceStore,immersedHx)
    
        use spfGlobalConst
        use hxModule
        use iceStoreDef
    
        implicit none                
    
        type(iceStoreStruct), intent(inout), target :: iceStore
        type(hxStruct), intent(inout), target :: immersedHx(nIHX)
    
        !double precision :: volOneLayer
        integer :: iHx,i,iStore,nHx,iceIsBlock,allCvAreBlocked 
        double precision :: volAvailable,volIce,volHx,volFree, totalIceMassInHx  
        
        !calculate of floatingIceInHx
    
        totalIceMassInHx = 0.0
    
        do iHx=1,iceStore%nHx
            totalIceMassInHx = totalIceMassInHx + immersedHx(iHx)%iceMass
        end do
    
        !iceStore%iceTotalMass = iceStore%iceFloating + totalIceMassInHx
    
        volIce = iceStore%iceFloating/iceStore%rhoIce !m3 Ice 
        volHx  = totalIceMassInHx/iceStore%rhoIce
 
 !>====================================================
 !> Calculation storeFull = de-ice is blocked but still ice can be formed
 !>====================================================
 
        volAvailable = iceStore%volumeTop*iceStore%maxIceFrac+(iceStore%volumeBot-iceStore%vTankMinusHx)*iceStore%maxIceFracIceLayer                    
        ! This is only floating ICE 
        volFree = volAvailable-volIce
   
        if(volFree<=0) then            
            iceStore%storeFull = 1           
        else
            iceStore%storeFull = 0                
        endif             
         
        do i=1,iceStore%nCv
            
            if(iceStore%volWater(i)<(1.0-iceStore%iceFrac(i))*iceStore%vTankMinusHxCv(i)+0.001) then        
               
                if(iceStore%storeCvBlocked(i) ==0 .and. iceStore%verboseLevel>=2) then
                    write(iceStore%MyMessage,*) 'Vr=',(iceStore%vTankMinusHxCv(i)-iceStore%volWater(i))/iceStore%vTankMinusHxCv(i),' in HX Cvs above limit =',iceStore%iceFrac(i),' in CV=',i            
                    call Messages(-1,Trim(iceStore%MyMessage),'NOTICE', iceStore%iUnit,iceStore%iType)                
                end if                
                iceStore%storeCvBlocked(i) = 1               
                               
            else if( iceStore%storeCvBlocked(i) == 1 .and.  iceStore%volWater(i)>(1.0-iceStore%iceFrac(i)*0.99)*iceStore%vTankMinusHxCv(i)+0.001) then
                iceStore%storeCvBlocked(i) = 0                           
            endif     
           
        enddo
        
        ! this part block the Cv's of the Hx that are concerned with the Cv of the storage which is blcoked.
        ! the problem is that it blocks the whole Cv even that half of it is in the next store Cv which is not blocked.
        ! TO BE DONE 
        
        iceStore%storeTotallyFull = 0
        allCvAreBlocked = 1
        
        do nHx=1,iceStore%nHx
            if(immersedHx(nHx)%isUsed) then   
                do iHx=1,immersedHx(nHx)%numberOfCv 
                    immersedHx(nHx)%hxCvBlocked(iHx) = 0
                enddo
            endif
        enddo
         
        do iStore=1,iceStore%nCv            
            do nHx=1,iceStore%nHx
                if(immersedHx(nHx)%isUsed) then                        
                    do iHx=1,immersedHx(nHx)%numberOfCv    
                        ! I dont block a Hx cv is only a small part of it belongs to a store Cv that is bloced, otherwise we might block a Hx Cv that 90% is on a Cv with still ice capacity
                        ! However this might cause negative water volume in the other CV. This needs to be controlled !!!!
                        if(immersedHx(nHx)%factorHxToTank(iHx,iStore)>0.1) then 
                            
                            if(iceStore%storeCvBlocked(iStore)==1) then
                                immersedHx(nHx)%hxCvBlocked(iHx) = 1
                            elseif(immersedHx(nHx)%phiOverlap(iHx)<1e-15 .and. immersedHx(nHx)%geometry==PLATE) then
                                immersedHx(nHx)%hxCvBlocked(iHx) = 1
                            elseif(immersedHx(nHx)%phiOverlap(iHx)>=(2.0*pi-1e-20) .and. immersedHx(nHx)%geometry==COIL) then
                                immersedHx(nHx)%hxCvBlocked(iHx) = 1
                            else
                                !immersedHx(nHx)%hxCvBlocked(iHx) = 0 We cant do this because we unlock CV's after being locked before
                                allCvAreBlocked = 0
                            endif
                        endif
                        
                        if(immersedHx(nHx)%geometry==COIL) then
                            if (immersedHx(nHx)%dOutMeltIce(iHx)>(immersedHx(nHx)%dOut+1e-15)) then
                                immersedHx(nHx)%hxCvBlocked(iHx) = 0
                            endif
                        else if (immersedHx(nHx)%geometry==PLATE) then
                            if(immersedHx(nHx)%iceThickMeltCv(iHx)>1e-15) then
                                immersedHx(nHx)%hxCvBlocked(iHx) = 0
                            endif
                        endif
                        
                    enddo
                endif
            enddo           
        enddo

        if(allCvAreBlocked==1 .and.  (volIce+volHx)/iceStore%VTank < iceStore%maxIceFrac) then
            iceStore%iceBlockGrowingMode = 1
        else
            iceStore%iceBlockGrowingMode = 0
        endif
        
        icestore%storeTotallyFull = allCvAreBlocked

        
    end subroutine checkStorageStatus
    
    !Only used for flat heat exchangers 
    subroutine releaseIce(iceStore,immersedHx)
    
        use spfGlobalConst
        use iceStoreDef
        use hxModule
    
        implicit none                
    
        type(iceStoreStruct), intent(inout), target :: iceStore       
        type(hxStruct), intent(inout), target :: immersedHx(nIHX)
    
        double precision ::addedIce, totalIceInLayer,freeKgForFloatingIce,allowedKg,allowedVol      
        integer :: iHx, i     
        !debug !!
        !double precision :: iceFloat, iceFloatOld, sumQhx, iceReleased
    
        addedIce = 0.d0
    
        ! Only one time every time step. 
        ! If we do not do this every iteration we decrease the value of iceFloating         
    
        totalIceInLayer = iceStore%iceFloating
            
        !>----------------------------------------------
        !> If the ice layer melt, we calculate the 
        !> new iceFloating in the store and it is redistributed 
        !> as a function of iceFracMax
        !>----------------------------------------------
    
        iceStore%iceIsReleased = 0
    
        allowedVol = iceStore%volumeTop*iceStore%maxIceFrac+(iceStore%VTank-iceStore%volumeTop)*iceStore%maxIceFracIceLayer
        allowedKg  = iceStore%rhoIce*allowedVol             
        
        
        if(sum(immersedHx(1:iceStore%nHx)%iceThickMelt)>0.0d0) then !only with flat plate we allow to deatach.                                
                
            do iHx=1,iceStore%nHx
    
                !>-------------------------------------------      
                !> So we have to consider all the parallel hx 
                !>-------------------------------------------                                                     
    
                !Ice layers are not allowed to be released until we melt the ice to avoid storeFull=1                                                
                    
                if (immersedHx(iHx)%geometry==0 .and. (immersedHx(iHx)%iceThickMelt/immersedHx(iHx)%nParallelHx > iceStore%meltCrit .or. iceStore%mechanicalDeIce==1) .and. iceStore%storeFull==0) then                
    
                    ! The kg able to be deatached and that can float. The rest will stay on the heat exchangers
                    
                    freeKgForFloatingIce  = allowedKg-iceStore%iceFloating
    
                    !>------------------------------------------------------
                    !> There is still room for more ice --> release ice-layer
                    !>--------------------------------------------------------    
    
                    if(freeKgForFloatingIce>0.0) then
    
                        iceStore%iceIsReleased = 1
    
                        !>------------------------------------            
                        !> The ice-layer separates from the HX
                        !>------------------------------------                                                            
    
                        addedIce =  min(immersedHx(iHx)%iceMass,freeKgForFloatingIce)
    
                        totalIceInLayer = totalIceInLayer + addedIce
    
                        if(iceStore%verboseLevel>=1) then                                
                            if(totalIceInLayer<0.d0)  then                                                                                   
                                write(iceStore%MyMessage,'("releaseIce ICE MASS IS NEGATIVE for hx=",d" iceFloating=",f" iceFloatingOld=",f" iceThick=",f)') iHx,addedIce,iceStore%iceFloatingOld,immersedHx(iHx)%iceThick
                                call Messages(-1,Trim(iceStore%MyMessage),'NOTICE',iceStore%iUnit,iceStore%iType)                                      
                            endif
                        endif   
    
                        iceStore%iceFloating  = totalIceInLayer                  
                        immersedHx(iHx)%iceThickMelt   = 0.0d0 
    
                        !Be carefull. This function must be called only once each time step iteration
                        
                        if(freeKgForFloatingIce>=immersedHx(iHx)%iceMass) then
                            immersedHx(iHx)%iceThick = 0.0d0                                    
                        else
                            immersedHx(iHx)%iceThick = (immersedHx(iHx)%iceMass - addedIce) / (immersedHx(iHx)%area * iceStore%rhoIce)                            
                        endif
    
                        do i=1,immersedHx(iHx)%numberOfCv
                            immersedHx(iHx)%iceThickCv(i) = immersedHx(iHx)%iceThick/immersedHx(iHx)%numberOfCv
                            immersedHx(iHx)%iceMassCv(i)  = immersedHx(iHx)%iceThickCv(i)*immersedHx(iHx)%area*iceStore%rhoIce/immersedHx(iHx)%numberOfCv
                        enddo
                        
                        immersedHx(iHx)%iceMass = sum(immersedHx(iHx)%iceMassCv(1:immersedHx(iHx)%numberOfCv))  
                            
                    endif
                endif
            enddo
        endif
   
        !if(iceStore%iceFloating > iceStore%iceFloatingOld .and. iceStore%sumQhx > 10.) then
        !    iceFloat    = iceStore%iceFloating
        !    iceFloatOld = iceStore%iceFloatingOld
        !    sumQhx      = iceStore%sumQhx
        !    iceReleased = iceStore%iceIsReleased*1.0
        !    i = 0
        !end if
    
    
    end subroutine releaseIce

    subroutine calculateMassOfIce(iceStore)
    
    use iceStoreDef
    
    implicit none
    
    type(iceStoreStruct), intent(inout), target :: iceStore
    integer :: i,nCv,j 
    double precision :: fusedKgIce
   
    nCv = iceStore%nCv
    
    iceStore%fusedIceFloatMass = 0.0
    
    ! ice of mass for each control volume        
    
    iceStore%iceFloating = 0.0
    iceStore%iceHx       = 0.0
    iceStore%iceTotalMass = 0.0
                
    do i=1,nCv            
        
        iceStore%iceMassHxCv(i) = 0.
        
        if(iceStore%qFusedFloatCv(i)>0.0) then                                                     
            ! The kg melted f of kg existent
            fusedKgIce = iceStore%qFusedFloatCv(i) *  iceStore%dtsec / iceStore%H_pc                                                
            iceStore%iceFloatMass(i)   = iceStore%iceFloatMassOld(i) - fusedKgIce                        
            iceStore%fusedIceFloatMass = iceStore%fusedIceFloatMass + fusedKgIce                            
        endif    
        
        do j=1,iceStore%nHx
            iceStore%iceMassHxCv(i) = iceStore%iceMassHxCv(i) + iceStore%iceMassHx(j,i)            
        end do 
        
        iceStore%iceTotalMassCv(i) = iceStore%iceFloatMass(i)+iceStore%iceMassHxCv(i)
        
        iceStore%iceFloating  = iceStore%iceFloating  + iceStore%iceFloatMass(i)
        iceStore%iceHx        = iceStore%iceHx        + iceStore%iceMassHxCv(i)
        iceStore%iceTotalMass = iceStore%iceTotalMass + iceStore%iceTotalMassCv(i)
        
    enddo
    
    iceStore%massIceFrac   =  iceStore%iceTotalMass/(iceStore%VTank*iceStore%rhoWater)                                
    iceStore%massIceFracHx =  iceStore%iceTotalMass/(iceStore%VTankEff*iceStore%rhoWater)  
    
    end subroutine calculateMassOfIce
    !
    subroutine calculateMassOfWater(iceStore,immersedHx)
    
    use iceStoreDef
    use hxModule
    
    implicit none
    
    type(iceStoreStruct), intent(inout), target :: iceStore
    type(hxStruct), intent(inout), target :: immersedHx(nIHX)
    
    double precision ::  volIceInHx, volHx, rho, volIce, volWaterInitial
    
    integer :: i,j, nCv, nHx, iHx
    integer :: dummy
    
    nCv = iceStore%nCv
    nHx = iceStore%nHx
    
    do j=1,nCv                    
    
        volIceInHx = 0.d0                   
        
        !if(old==1) then
        !    do iHx=1,nHx       
        !        if(immersedHx(iHx)%isUsed) then
        !            do i=1,immersedHx(iHx)%numberOfCv
        !                volIceInHx = volIceInHx +immersedHx(iHx)%iceMassCv(i)*immersedHx(iHx)%factorHxToTank(i,j)/iceStore%rhoIce                
        !            end do                         
        !        end if
        !    enddo
        !else
        !    volIceInHx =  iceStore%iceMassHxCv(j)/iceStore%rhoIce
        !end if
        
        !< The first part is the ice attached to the heat exchanger and the second is the deatached ice
    
        volIce = iceStore%iceMassHxCv(j)/iceStore%rhoIce + iceStore%iceFloatMass(j) /iceStore%rhoIce
        volWaterInitial =iceStore%vTankCv(j) - iceStore%vHxCv(j)
        
        if(volIce*0.99 > volWaterInitial*iceStore%iceFrac(j)) then !DC-OCT-2018
            dummy=1
        endif
        
        iceStore%volWater(j) = volWaterInitial  - volIce     
             
        if(iceStore%constantPhysicalProp) then
            rho = iceStore%rhoWater
        else
            rho = getRhoWater(iceStore%T(j))
        endif
        
        iceStore%M(j) = iceStore%volWater(j)*rho
    
    enddo
    
    end subroutine calculateMassOfWater  
    !
subroutine postProcessIte(iceStore,immersedHx)

    use physProp
    use iceStoreDef
    use hxModule

    implicit none                

    type(iceStoreStruct), intent(inout), target :: iceStore  
    type(hxStruct), intent(inout), target :: immersedHx(nIHX) 

    integer :: nCv, nHx 
    double precision , pointer :: qloss(:),  UAloss(:),  Tenv(:), &
    M(:),T(:), alphaEff, iceFloatMass(:)   ! qhx(:,:),U(:,:)

    double precision TBoil, cpWater, rhoWater, dtsec, Tfreeze, kEff, tAvCv,rho,cp,&
                     qMeltFromBulkWater
    ! internal variables
    integer :: i,j,k,iHx

    ! Asingnations to iceStore structure

    nCv   = iceStore%nCv; nHx = iceStore%nHx        
    qloss => iceStore%qloss; UAloss => iceStore%UAloss
    Tenv  => iceStore%Tenv; M => iceStore%M !; qhx => iceStore%qhx
    !S => iceStore%S;
    T => iceStore%T !; U => iceStore%
    TBoil   = iceStore%TBoil; cpWater = iceStore%cpWater; rhoWater= iceStore%rhoWater       
    Tfreeze = iceStore%Tfreeze; iceFloatMass => iceStore%iceFloatMass       
    kEff = iceStore%kEff             

    alphaEff=> iceStore%alphaEff                                  
    
    !> Calculate the total energy provided by the heat exchangers    

    iceStore%sumQHx = 0.    
    iceStore%sumQHx = sum(immersedHx(1:nHx)%qHxToTnk)-sum(immersedHx(1:nHx)%qAcumIce)
      
    iceStore%qAcumHx = 0.0        
    iceStore%qAcumHx = sum(immersedHx(1:nHx)%qAcum)
   
    !> Calculate LOSS to the ENVIRONMENT.

   ! qloss(1:nCv) = UAloss(1:nCv) * (T(1:nCv) - Tenv(1:nCv)) ! TEnv has been affected to include Tup and TBottom as UA.                            
    iceStore%sumQLoss = sum(qloss(1:nCv))

    !> Storage tank acumulated energy

    iceStore%qAcumStore = 0.d0       
    iceStore%tStoreAv = 0.0d0

    qMeltFromBulkWater = 0.0
    
    iceStore%qFused  = 0.0        
    
    do i=1,nCv

        !qMeltFromBulkWater =  qMeltFromBulkWater + iceStore%qFusedFloatCv(i) + iceStore%qFusedHxCv(i)                              
        
        iceStore%qFused = iceStore%qFused + iceStore%qFusedFloatCv(i) + iceStore%qFusedHxCv(i)
        
        !> Calculate LOSS to the ENVIRONMENT.
        qloss(i) = UAloss(i) * (T(i) - Tenv(i))
        
        if(iceStore%constantPhysicalProp) then
            cp = cpWater
            rho = rhoWater
        else
            rho= getRhoWater(iceStore%T(i))
            cp= getCpWater(iceStore%T(i))     
        endif
        
        iceStore%qAcumStore = iceStore%qAcumStore  + rho*cp*iceStore%volWater(i)*(T(i)-iceStore%Told(i))/iceStore%dtsec 

        tAvCv = (T(i) * M(i) + iceStore%Tfreeze * iceFloatMass(i))/ ( M(i) + iceFloatMass(i) )

        iceStore%tStoreAv = iceStore%tStoreAv + tAvCv/nCv       

        !iceStore%iceMassHxCv(i) = 0.0
        !
        !do j=1,iceStore%nHx
        !    iceStore%iceMassHxCv(i) = iceStore%iceMassHxCv(i) + iceStore%iceMassHx(j,i)            
        !end do         
        !
        !iceStore%iceTotalMassCv(i) = iceStore%iceFloatMass(i)+iceStore%iceMassHxCv(i)        
        
    enddo                             
      
    if(iceStore%tStoreAv>immersedHx(1)%tFluidIn) then
        iceStore%sumQIce = 0. 
    endif
    
    call calculateMassOfIce(iceStore)             
    
    iceStore%sumQIce = 0.        
    iceStore%sumQIce = sum(immersedHx(1:nHx)%qIce) 
    
    
end subroutine postProcessIte

    !> for heating it will give a positive number for cooling a negative number


    subroutine setMemoryIceStorage(iceStore)

        use iceStoreDef

        implicit none

        integer :: nCv, i, j, error
        type(iceStoreStruct), intent(inout), target :: iceStore                  

        nCv = iceStore%nCv

        if(nCv<1) then
            call FoundBadParameter(1,'Fatal','setMemory FATAL error nCv<1')     
        endif    

        allocate(iceStore%T(nCv),stat=error)
        allocate(iceStore%Told(nCv),stat=error)

        allocate(iceStore%Tenv(nCv),stat=error)
        allocate(iceStore%M(nCv),stat=error)
        allocate(iceStore%H(nCv),stat=error)  
        allocate(iceStore%A(nCv),stat=error)
        allocate(iceStore%volWater(nCv),stat=error)
        allocate(iceStore%volWaterOld(nCv),stat=error)
        allocate(iceStore%vTankCv(nCv),stat=error)
        allocate(iceStore%Uloss(nCv),stat=error)
        allocate(iceStore%UAloss(nCv),stat=error)
        allocate(iceStore%areaBot(nCv),stat=error)
        allocate(iceStore%areaTop(nCv),stat=error)
        allocate(iceStore%qLoss(nCv),stat=error)   
        allocate(iceStore%iceFloatMass(nCv),stat=error)    
        allocate(iceStore%iceFloatMassOld(nCv),stat=error)
        allocate(iceStore%qFusedFloatCv(nCv),stat=error)
        allocate(iceStore%qFusedHxCv(nCv),stat=error) !DC 14.01.2015
        allocate(iceStore%tIteStore(nCv),stat=error)
        allocate(iceStore%tIteGlobal(nCv),stat=error)
        allocate(iceStore%iceFrac(nCv),stat=error)
        allocate(iceStore%isHxLayerRatio(nCv),stat=error) !DC 16.01.2015
    !    allocate(iceStore%QvIte(nCv),stat=error)
        allocate(iceStore%nody(nCv),stat=error)
        allocate(iceStore%iceMassHxCv(nCv),stat=error)
        allocate(iceStore%iceMassHxCvOld(nCv),stat=error)
        allocate(iceStore%iceTotalMassCv(nCv),stat=error)

        allocate(iceStore%vHxCv(nCv),stat=error)
        allocate(iceStore%vTankMinusHxCv(nCv),stat=error)        
        allocate(iceStore%storeCvBlocked(nCv),stat=error)
        ! nCv+1 !!
        allocate(iceStore%vcly(nCv+1),stat=error)

        !2D
  
       allocate(iceStore%qhx(nIHx,nCv),stat=error) 
       allocate(iceStore%qIceCv(nIHx,nCv),stat=error)
       allocate(iceStore%qIceAcumCv(nIHx,nCv),stat=error)
       allocate(iceStore%iceMassHx(nIHx,nCv),stat=error) !DC 14.01.2015  

       do i=1,nCv
       
        iceStore%TEnv(i)    = 0.0d0
        iceStore%M(i)         = 0.0d0
        iceStore%H(i)         = 0.0d0
        iceStore%A(i)         = 0.0d0
        iceStore%Uloss(i)     = 0.0d0
        iceStore%UAloss(i)    = 0.0d0
        iceStore%qloss(i)     = 0.0d0                           
        iceStore%iceFloatMass(i)   = 0.0d0 

        iceStore%iceFloatMassOld(i) = 0.0d0 
        iceStore%volWater(i)   = 0.0d0
        iceStore%volWaterOld(i)= 0.0d0
        iceStore%qFusedFloatCv(i)   = 0.0d0
        iceStore%qFusedHxCv(i)   = 0.0d0 !DC 14-01-15
        iceStore%vTankCv(i)    = 0.0d0
        iceStore%iceFrac(i)     = 0.0d0
        iceStore%iceMassHxCv(i)     = 0.0d0
        iceStore%iceMassHxCvOld(i)     = 0.0d0
        iceStore%iceTotalMassCv(i)     = 0.0d0
    
     
        iceStore%areaBot(i) = 0.0d0
        iceStore%areaTop(i) = 0.0d0                   
        iceStore%isHxLayerRatio(i) = 0.0d0
        
        iceStore%storeCvBlocked(i) = 0
        
        do j=1,nIHX
            iceStore%qhx(j,i) = 0.0 
            iceStore%qIceCv(j,i) = 0.0 
            iceStore%qIceAcumCv(j,i) = 0.0  
            iceStore%iceMassHx(j,i) = 0.0  
        end do
        
     enddo
    
    end subroutine setMemoryIceStorage


    subroutine setMemoryOneDStruct(oneD,nCv)

    use iceStoreDef

    implicit none

    integer, intent(in) :: nCv
    integer :: error,i
    type(oneDStruct), intent(inout), target :: oneD

    oneD%nCv = nCv

    allocate(oneD%U(nCv),stat=error)
    allocate(oneD%RhoCpDxOverDt(nCv),stat=error)
    allocate(oneD%Qv(nCv),stat=error)   
    allocate(oneD%QvOld(nCv),stat=error)
    allocate(oneD%LambdaOverDx(nCv-1),stat=error)
    allocate(oneD%UFuse(nCv),stat=error)
    allocate(oneD%ScDx(nCv),stat=error)
    allocate(oneD%SpDx(nCv),stat=error)

    do i=1,nCv
        oneD%U(i)=0.0
        oneD%RhoCpDxOverDt(i)=0.0
        oneD%Qv(i)=0.0       
        oneD%QvOld(i)=0.0
        if(i<nCv) oneD%LambdaOverDx(i)=0.0
        oneD%U(i) = 0.0
        oneD%UFuse(i)=0.0
        oneD%ScDx(i)=0.0
        oneD%SpDx(i)=0.0
    end do

    end subroutine setMemoryOneDStruct

    subroutine setMemoryFreeOneDStruct(oneD)

    use iceStoreDef

    implicit none

    integer :: error
    type(oneDStruct), intent(inout), target :: oneD

    deallocate(oneD%U,stat=error)
    deallocate(oneD%RhoCpDxOverDt,stat=error)
    deallocate(oneD%Qv,stat=error)
    !deallocate(oneD%QvFromHx,stat=error)
    deallocate(oneD%QvOld,stat=error)
    deallocate(oneD%LambdaOverDx,stat=error)
    deallocate(oneD%UFuse,stat=error)
    deallocate(oneD%ScDx,stat=error)
    deallocate(oneD%SpDx,stat=error)

    end subroutine setMemoryFreeOneDStruct

    subroutine setMemoryFreeIceStorage(iceStore)

    use iceStoreDef

    implicit none

    type(iceStoreStruct), intent(inout), target :: iceStore
    integer error

    deallocate(iceStore%T,stat=error)
    deallocate(iceStore%Told,stat=error)

    deallocate(iceStore%Tenv,stat=error)
    deallocate(iceStore%M,stat=error)
    deallocate(iceStore%H,stat=error)  
    deallocate(iceStore%A,stat=error)
    deallocate(iceStore%volWater,stat=error)
    deallocate(iceStore%volWaterOld,stat=error)
    deallocate(iceStore%vTankCv,stat=error)
    deallocate(iceStore%Uloss,stat=error)
    deallocate(iceStore%UAloss,stat=error)
    deallocate(iceStore%areaBot,stat=error)
    deallocate(iceStore%areaTop,stat=error)
    deallocate(iceStore%qLoss,stat=error)

    !deallocate(iceStore%S,stat=error) ! to erase
    deallocate(iceStore%iceFloatMass,stat=error)        
    deallocate(iceStore%iceFloatMassOld,stat=error)
    deallocate(iceStore%qFusedFloatCv,stat=error)
    deallocate(iceStore%qFusedHxCv,stat=error) !DC 14.01.15
    deallocate(iceStore%tIteStore,stat=error)
    deallocate(iceStore%tIteGlobal,stat=error)
    deallocate(iceStore%iceFrac,stat=error)
!    deallocate(iceStore%QvIte,stat=error)
    deallocate(iceStore%isHxLayerRatio,stat=error) !DC 16.01.15
    
    deallocate(iceStore%iceMassHxCv,stat=error)
    deallocate(iceStore%iceMassHxCvOld,stat=error)
    deallocate(iceStore%iceTotalMassCv,stat=error)

    deallocate(iceStore%vHxCv,stat=error)
    deallocate(iceStore%vTankMinusHxCv,stat=error)     
    deallocate(iceStore%storeCvBlocked,stat=error)

    deallocate(iceStore%nody,stat=error)
    ! nCv+1 !!
    deallocate(iceStore%vcly,stat=error)

    !2D
   
    deallocate(iceStore%qhx,stat=error) 
    deallocate(iceStore%qIceCv,stat=error)
    deallocate(iceStore%qIceAcumCv,stat=error)
    deallocate(iceStore%iceMassHx,stat=error)  !DC 14.01.15
  

    end subroutine setMemoryFreeIceStorage

    ! subroutine getCorrectionFactorForConstrained(iceStore,oneImmersedHx)
    !     
    !     use iceStoreDef
    !  
    !     implicit none     
    !     
    !     type(iceStoreStruct), intent(inout), target :: iceStore        
    !     type(hxStruct), intent(inout) , target :: oneimmersedHx
    !    
    !     double precision :: dIce,AR,dCrit,iceForOneHx,dOut
    !     
    !     dOut = immersedHx%dOut
    !     
    !     iceForOneHX =  iceStore%ice(i)/immersedHx%nParallelHx
    !     dIce  = dOut + 2.*iceForOneHX
    !     ! DC-DO Thx is dOut?
    !     !dCrit = dOut + (iceStore%WTank-iceStore%Thx(i)*immersedHx%nParallelHx)/immersedHx%nParallelHx
    !     dCrit = dOut + (iceStore%WTank-dOut*immersedHx%nParallelHx)/immersedHx%nParallelHx
    !     AR = max(1-4.*acos(dCrit/(dIce+1e-30))/pi,0.d0)
    !     iceStore%fConstrained = -1.441*AR + 2.455*AR**0.5 + dOut/(dCrit+1e-20)*(3.116*AR - 3.158*AR**0.5)
    !     
    ! end subroutine getCorrectionFactorForConstrained  

    double precision function getSecondOrder(a,b,c)

    implicit none 

    double precision, intent(in) :: a,b,c
    double precision :: sqTerm,pos,neg,sq

    sqTerm = b*b-(4.0*a*c)

    if(sqTerm<0.) then            
        getSecondOrder = 0.0d0            
    else        
        sq = sqTerm**0.5    
        pos = (-b + sq)/(2.*a)
        neg = (-b - sq)/(2.*a)    
        getSecondOrder = pos            
    endif

    end function getSecondOrder

    end module iceStoreFunc
