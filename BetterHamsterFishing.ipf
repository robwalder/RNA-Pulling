#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1.0
// Rob's hack of the hamster fishing proc from asylum.  
// Gives you a controllable data aqusition by clicking the outer wheel left.



Function CloseHamsterFishing()

	DoWindow/K FishingGraph
	DoWindow/K FishingPanel
	RemoveUserFunc("HamsterFishing")
End //CloseHamsterFishing

Menu "Hamster Fishing"
	"Initialize Hamster Fishing", InitHamsterFishing()
	"Close Hamster Fishing", CloseHamsterFishing()
End


function InitHamsterFishing()		//makes all of the needed waves
	
	InitDataCapture()  // This is for Rob's data capture function
	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:Packages:MFP3D:Force
	
	variable/G HamSens, FishMax, FishMin, DefaultFishMax, DefaultFishMin, FishingSetpoint		//make the global variables
	HamSens = 0.01
	If (GV("MicroscopeID") == cMicroscopeCypher)
		DefaultFishMax = 2.5						//Cyphers have a small Z LVDT range
		DefaultFishMin = -2.5
	else
		DefaultFishMax = 6
		DefaultFishMin = -6
	endif
	FishMax = DefaultFishMax
	FishMin = DefaultFishMin

	Make/O/N=128 DisplayFishDeflection, DisplayFishLVDT, DisplayScale, DisplayColor	//make the waves
	DisplayScale = 2								//most of the markers will be size 2
	DisplayScale[0,10] = 4-p/5					//the first 11 are bigger
	DisplayColor = limit(p*10/128,5,10)		//as they get older they fade out
	MakeFishingPanel()					//make the panel
	MakeFishingGraph()					//make the graph
//	ARCheckFunc("ARUserCallbackMasterCheck_1",1)
	ARCheckFUnc("ARUserCallbackForceDoneCheck_1",1)		//we will use this to start fishing back up after doing a force curve
	PDS("ARUserCallbackForceDone","FishingFunc(\"ResumeFishing\")")		//resume fishing
	
	SetDataFolder SavedDataFolder
end //InitHamsterFishing

// Rob's data capture function
Function InitDataCapture()
	NewDataFolder/O root:HamsterData
	NewDataFolder/O root:HamsterData:SavedData

	Make/O/N=5 root:HamsterData:DataCaptureSettings
	Wave DataCaptureSettings=root:HamsterData:DataCaptureSettings
	SetDimLabel 0,0, SampleRate, DataCaptureSettings
 	SetDimLabel 0,1, Duration, DataCaptureSettings
 	SetDimLabel 0,2, Iteration, DataCaptureSettings
 	SetDimLabel 0,3, FastCapture, DataCaptureSettings
 	
 	DataCaptureSettings={50000,5,0,0}

End


Function FishingFunc(ctrlName)
	String ctrlName

	variable error = 0			//check for td errors
	NVAR FishingSetpoint = root:Packages:MFP3D:Force:FishingSetpoint

	strswitch (ctrlName)
		case "StartFishing":		//we want to fish
			Button StartFishing, win=FishingPanel,title="Stop",rename=StopFishing		//rename the button for stopping
			error += td_WriteString("StatusCallback%Hamster","HamsterFishing()")		//change the hamster callback
		case "ResumeFishing":		//don't rename the button, and the hamster callback is still set
			//set up the feedback loop read the current LVDT value so it won't click. Use just the integral gain.
			error += ir_SetPISLoop(2,"Always,Never","ZSensor",NaN,0,10^GV("ZIGain"),0,"Height",-inf,inf)
			PV("LowNoise",1)			//this keeps the noisy update of the sum from happening
			FishingSetpoint = td_ReadValue("PIDSLoop.2.Setpoint")		//see where the setpoint currently is
			BackgroundInfo
			if (V_flag)				//if there is a background task, kill it
				KillBackground
			endif
			SetBackground FishingBackground()			//set to fish
			CtrlBackground start,period=4,noburst=1		//start the background to 15Hz
			ARCheckFunc("ARUserCallbackMasterCheck_1",1)
			break
			
		case "StopFishing":			//time to stop
			ARCheckFunc("ARUserCallbackMasterCheck_1",0)
			Button StopFishing, win=FishingPanel,title="Start",rename=StartFishing	//reset the button to start
			error += td_WriteString("StatusCallback%Hamster","HamsterCheck()")			//reset the hamster callback to stock
			KillBackground												//kill the current background
			StartMeter("")												//restart the meter
		case "PauseFishing":						//just pausing while a force curve runs
			error += ir_StopPISLoop(2)									//stop the feedback loop
			PV("LowNoise",0)							//bring on the noise, this has to be set to 0 or SinglePullFromMenu won't run
			break
		
	endswitch
	if (error)			//there was a td error
		print "Error total "+num2str(error)+" in FishingFunc"		//print out the error total
	endif

End //FishingFunc

function FishingBackground()			//runs in the background during fishing and updates the data
	
	UpdateMeter()					//the normal meter function
	wave/Z DisplayFishDeflection = root:Packages:MFP3D:Force:DisplayFishDeflection
	if (!WaveExists(DisplayFishDeflection))
		InitHamsterFishing()
		wave/Z DisplayFishDeflection = root:Packages:MFP3D:Force:DisplayFishDeflection
		if (!WaveExists(DisplayFishDeflection))
			return(1)
		endif
	endif
	wave DisplayFishLVDT = root:Packages:MFP3D:Force:DisplayFishLVDT
//	NVAR Amplitude = root:Packages:MFP3D:Meter:Amplitude				//not all of these are used, yet
	Wave RMR = root:Packages:MFP3D:Meter:ReadMeterRead
//	NVAR Z = root:Packages:MFP3D:Meter:Z
//	NVAR Phase = root:Packages:MFP3D:Meter:Phase
	
	Rotate 1, DisplayFishDeflection, DisplayFishLVDT			//rotate the waves
	DisplayFishDeflection[0] = RMR[%Deflection]				//this value was already captured by UpdateMeter
	DisplayFishLVDT[0] = td_ReadValue("ZSensor")				//grab the Z LVDT value
	
	return 0
end //FishingBackground

Function FishingBoxFunc(ctrlName,checked)		//takes care of the Fishing panel boxes
	String ctrlName
	Variable checked
	
	DoWindow FishingGraph			//no need to do anything if there is no fishing graph
	if (V_flag == 0)
		return 0
	endif
	
	NVAR FishMax = root:Packages:MFP3D:Force:FishMax
	NVAR FishMin = root:Packages:MFP3D:Force:FishMin
	NVAR DefaultFishMax = root:Packages:MFP3D:Force:DefaultFishMax
	NVAR DefaultFishMin = root:Packages:MFP3D:Force:DefaultFishMin
	if (checked)							//we want to lock the axes
		wave DisplayFishDeflection = root:Packages:MFP3D:Force:DisplayFishDeflection
		wave DisplayFishLVDT = root:Packages:MFP3D:Force:DisplayFishLVDT
		WaveStats/Q DisplayFishDeflection			//check the wave limits
		SetAxis/W=FishingGraph left V_min, V_max 		//set the left axis
		WaveStats/Q DisplayFishLVDT				//check the other wave limits
		SetAxis/W=FishingGraph bottom V_max, V_min		//set the bottom axis
		FishMax = V_max								//this will keep the fishing on the graph
		FishMin = V_min
	else										//we want auto scale
		SetAxis/A/W=FishingGraph left				//auto scale the left
		SetAxis/A/R/W=FishingGraph bottom			//auto scale the bottom reversed
		FishMax = DefaultFishMax						//reset the limits
		FishMin = DefaultFishMin
	endif

End //FishingBoxFunc

Function FishingSetVarFunc(ctrlName,varNum,varStr,varName) : SetVariableControl	//doesn't actually do anything at the moment
	String ctrlName
	Variable varNum
	String varStr
	String varName

End

function MakeFishingPanel()
	Execute "FishingPanel()"
	
End //MakeFishingPanel

function HamsterFishing()		//this function deals with the output from the hamster

//	variable switches = td_ReadValue("Switch%Hamster")		//grab the switch setting
	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	wave HamsterParms = root:Packages:MFP3D:InfoBlocks:HamsterParms
	variable clickRing = MVW[%HasClickRing][%Value]
	td_ReadGroup("Hamster",HamsterParms)
	variable clicks = -HamsterParms[%Clicks]
	variable switches = HamsterParms[%Switch]
	variable degrees = HamsterParms[%Degrees]
	variable startDist
//print degrees	
			
	if (clickRing)					//ARC II has a click ring
		if (clicks > 0)					//bit 1 means switch up

			Wave DataCaptureSettings=root:HamsterData:DataCaptureSettings
			Variable DecimationFactor=Floor(50000/DataCaptureSettings[%SampleRate])
			Variable RealSampleRate=50000/DecimationFactor
			Variable NumPoints=DataCaptureSettings[%Duration]*RealSampleRate
			Variable CaptureError=0
			
			Make/O/N=(Numpoints) root:HamsterData:ZSensorV,root:HamsterData:DefV
			Wave ZSensorV=root:HamsterData:ZSensorV
			Wave DefV=root:HamsterData:DefV
			print "Getting Data Now"
			IR_XSetInWavePair(0,"14","Deflection",DefV,"Cypher.LVDT.Z",ZSensorV,"DataCaptureCallback()",DecimationFactor)
			
			ControlInfo/W=FishingPanel FastCaptureCB
			If(V_value)
				CaptureError+=td_WV("Cypher.Capture.0.rate",2) // Sets sample rate to 5 MHz
				Make/O/N=0 root:HamsterData:DefVFast
				Variable FastCaptureLength=Floor(5e6*DataCaptureSettings[%Duration])
				CaptureError+=td_WV("Cypher.Capture.0.length",FastCaptureLength) // Sets number of points for 5 MHz rate and user defined duration time
				CaptureError+=td_WS("Cypher.Capture.0.trigger","Now") // Starts fast capture NOW!
				
			EndIf
			
			CaptureError+=td_WS("Event.14","Once")
			
			If(CaptureError>0)
				Print "Error in hamster data capture code: "+num2str(CaptureError)
			EndIf
			
			return 0
//		
		elseif (clicks < 0)
			FishingFunc("PauseFishing")
			startDist = GV("ZPiezoSens")*td_ReadValue("Height")*1e6
			ForceSetVarFunc("StartDistSetVar_2",startDist,num2str(startDist)+"u","")
			SinglePullFromMenu()
			//			SinglePullFromMenu("SingleForce_2")

			return 0			//do no more
		endif

	elseif (switches)		
		if (2 & switches)					//bit 1 means switch up
			ControlInfo/W=FishingPanel AxesLock	//make sure the box exists
			if (V_flag)
				if (V_value)					//do the opposite of the current setting
					CheckBox AxesLock, win=FishingPanel, value=0	//uncheck the box
					FishingBoxFunc("AxesLock",0)						//unlock the graph
				else
					CheckBox AxesLock, win=FishingPanel, value=1	//check the box
					FishingBoxFunc("AxesLock",1)						//lock the graph
				endif
			endif
		else
			FishingFunc("PauseFishing")
			startDist = GV("ZPiezoSens")*td_ReadValue("Height")*1e6
			ForceSetVarFunc("StartDistSetVar_2",startDist,num2str(startDist)+"u","")
			SinglePullFromMenu()
			//SinglePullFromMenu("SingleForce_2")

		endif
		return 0
	endif

//	variable degrees = td_ReadValue("Degrees%Hamster")				//check the degrees
	if (degrees == 0)											//no degrees, no work
		return 0
	endif
	NVAR HamSens = root:Packages:MFP3D:Force:HamSens
	NVAR FishingSetpoint = root:Packages:MFP3D:Force:FishingSetpoint
	NVAR FishMax = root:Packages:MFP3D:Force:FishMax
	NVAR FishMin = root:Packages:MFP3D:Force:FishMin
	
	FishingSetpoint = limit(FishingSetpoint+degrees*HamSens/3600,FishMin,FishMax)	//change the setpoint, keeping it within limits
	td_WriteValue("PIdSLoop.2.Setpoint",FishingSetpoint)			//actually change the setpoint
	
end //HamsterFishing

function MakeFishingGraph()			//make the graph if it doesn't exist
	
	String GraphStr = "FishingGraph"
	DoWindow/F $GraphStr
	if (V_flag)
		return 0
	endif
	
	String fldrSav= GetDataFolder(1)
	SetDataFolder root:packages:MFP3D:Force:
	Display/K=1/N=$GraphStr/W=(308.4,141.2,703.8,348.8) DisplayFishDeflection vs DisplayFishLVDT as "Fishing Graph"
	ModifyGraph/W=$GraphStr mode=3
	ModifyGraph/W=$GraphStr marker=19
	ModifyGraph/W=$GraphStr rgb=(0,0,0)
	ModifyGraph/W=$GraphStr msize=2
	ModifyGraph/W=$GraphStr zmrkSize(DisplayFishDeflection)={DisplayScale,1,10,1,10}		//make the wave change size and color as the points age
	ModifyGraph/W=$GraphStr zColor(DisplayFishDeflection)={DisplayColor,*,10,Grays}
	SetAxis/A/R/W=$GraphStr bottom
	SetDataFolder fldrSav
End //MakeFishingGraph

// Data Capture Callback
// Saves the daat in saved data folder of hamster data folder.  Does this everytime you run the data capture.
Function DataCaptureCallback()
	Wave ZSensorV=root:HamsterData:ZSensorV
	Wave DefV=root:HamsterData:DefV
	Wave DataCaptureSettings=root:HamsterData:DataCaptureSettings
	String CorrectionIteration=num2str(DataCaptureSettings[%Iteration])

	note/K DefV "K="+num2str(GV("SpringConstant"))+";"
	note DefV "Invols="+num2str(GV("InvOLS"))+";"
	note DefV "Date="+date()+";"
	note DefV "Time="+time()+";"
	note DefV "NearestForcePull="+PreviousForceRamp()+";"
	note DefV "Iteration="+CorrectionIteration+";"

	note/K ZSensorV "ZLVDTSens="+num2str(GV("ZLVDTSens"))+";"
	note ZSensorV "ZLVDTOffset="+num2str(GV("ZLVDTOffset"))+";"
	note ZSensorV "Date="+date()+";"
	note ZSensorV "Time="+time()+";"
	note ZSensorV "NearestForcePull="+PreviousForceRamp()+";"
	note ZSensorV "Iteration="+CorrectionIteration+";"


	Duplicate/O DefV, $("root:HamsterData:SavedData:DefV_"+num2str(DataCaptureSettings[%Iteration]))
	Duplicate/O ZSensorV, $("root:HamsterData:SavedData:ZSensorV_"+num2str(DataCaptureSettings[%Iteration]))
	Duplicate/O DataCaptureSettings, $("root:HamsterData:SavedData:DataCaptureSettings_"+num2str(DataCaptureSettings[%Iteration]))
	DataCaptureSettings[%Iteration]+=1
	print "Done Getting Data"

end //DataCaptureCallback


Window FishingPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(443,81,662,407) as "Fishing Panel"
	Button StopFishing,pos={10,10},size={50,20},proc=FishingFunc,title="Stop"
	CheckBox AxesLock,pos={10,40},size={68,14},proc=FishingBoxFunc,title="Lock Axes"
	CheckBox AxesLock,value= 0
	SetVariable HamSensSetVar,pos={10,70},size={110,18},proc=FishingSetVarFunc
	SetVariable HamSensSetVar,font="Arial",fSize=12
	SetVariable HamSensSetVar,value= root:packages:MFP3D:Force:HamSens
	CheckBox FastCaptureCB,pos={2,229},size={84,14},title="Fast Capture?",value= 1
	SetVariable HamsterSampleRate,pos={2,124},size={131,16},proc=FishingSetVarFunc,title="Sample Rate"
	SetVariable HamsterSampleRate,format="%.1W1PHz"
	SetVariable HamsterSampleRate,limits={1,50000,1},value= root:HamsterData:DataCaptureSettings[%SampleRate]
	TitleBox ClickLeft,pos={1,94},size={204,21},title="Move hamster wheel left for data capture."
	SetVariable HamsterDuration,pos={2,150},size={119,16},proc=FishingSetVarFunc,title="Duration"
	SetVariable HamsterDuration,format="%.1W1Ps"
	SetVariable HamsterDuration,limits={0,500,0.1},value= root:HamsterData:DataCaptureSettings[%Duration]
	SetVariable HamsterIteration,pos={2,176},size={119,16},proc=FishingSetVarFunc,title="Iteration"
	SetVariable HamsterIteration,limits={0,inf,1},value= root:HamsterData:DataCaptureSettings[%Iteration]
	Button ReadFastCaptureFishing,pos={3,252},size={115,21},proc=FishFastCaptureButtonProc,title="Read Fast Capture"
	TitleBox FastCapture,pos={3,198},size={109,21},title="Fast Capture Settings"
	CheckBox SaveDiskCB,pos={7,285},size={77,14},title="Save to disk",value= 1
	CheckBox SaveMemoryCB,pos={8,306},size={94,14},title="Save to memory",value= 1
EndMacro

Function FastDataCaptureCallback()
	Wave DefVFast=root:HamsterData:DefVFast
	Wave DataCaptureSettings=root:HamsterData:DataCaptureSettings
	String CorrectionIteration=num2str(DataCaptureSettings[%Iteration]-1)
	note/K DefVFast "K="+num2str(GV("SpringConstant"))+";"
	note DefVFast "Invols="+num2str(GV("InvOLS"))+";"
	note DefVFast "Date="+date()+";"
	note DefVFast "Time="+time()+";"
	note DefVFast "NearestForcePull="+PreviousForceRamp()+";"
	note DefVFast "Iteration="+CorrectionIteration+";"

	ControlInfo/W=FishingPanel SaveMemoryCB
	If(V_value)
		Duplicate/O DefVFast, $("root:HamsterData:SavedData:DefVFast_"+CorrectionIteration)
	EndIf
	ControlInfo/W=FishingPanel SaveDiskCB
	If(V_value)
		Print "Saving Fast Capture to Disk"
		String PathName="C:Users:Asylum User:Desktop:Rob:FastCaptureData:"+DateStringForSave()
		String SaveName= DateStringForSave()+"_"+TimeStringForSave()+"_"+"HamsterFastCapture_"+CorrectionIteration+".pxp"
		NewPath/O/C/Q/Z FastCapturePath,PathName
		//Save/C/P=FastCapturePath DefVFast as SaveName
		SetDataFolder root:HamsterData
		SaveData/L=1/Q/P=FastCapturePath SaveName
		
	EndIf
	
	print "Done Getting Fast Capture Data"

end //DataCaptureCallback

Function FishFastCaptureButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Wave DefVFast=root:HamsterData:DefVFast
			Print "Reading Fast Capture Data"
			td_readcapture("Cypher.Capture.0",DefVFast,"FastDataCaptureCallback()")
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function/S PreviousForceRamp()
	SVAR gBaseName = root:Packages:MFP3D:Main:Variables:BaseName
	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	Variable Suffix = MVW[%BaseSuffix][0]-1
	String CurrentIterationStr
	sprintf CurrentIterationStr, "%04d", Suffix

	String RampName=gBaseName+CurrentIterationStr
	Return RampName

end

Function/S DateStringForSave()
	String ARDate=ARU_Date()
	Return StringFromList(0, ARDate,"-")[2,3]+StringFromList(1, ARDate,"-")+StringFromList(2, ARDate,"-")
End

Function/S TimeStringForSave()
	String TimeString=Time()
	Return StringFromList(0, TimeString,":")+StringFromList(1, TimeString,":")+StringFromList(1,StringFromList(2, TimeString,":")," ")
End
