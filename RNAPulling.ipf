#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=2.1
#include "::Force-Ramp:ForceRamp" version>=2
#include "::General-Igor-Utilities:WaveDimNote" version>=1
#include ":BetterHamsterFishing" version>=1
#include "::Centering:CenteredForcePulls" version>=9
#include "::Cypher-Utilities:ClosedLoopMotion"

// For version 2.1
// Moved DoClosedLoopZMotion to ClosedLoopMotion
// Also adding in reset to same starting position after a touch off the surface ramp.

Menu "RNA Pulling"
	"Initialize RNA Pulling", InitRNAPulling()
End

Function InitRNAPulling()

	NewDataFolder/O root:RNAPulling
	NewDataFolder/O root:RNAPulling:SavedData
	SetDataFolder root:RNAPulling
	
	// Setup paths to parm and recipe directories on the hard drive
	String PathIn=FunctionPath("")
	
	NewPath/Q/O RNAPullingParms ParseFilePath(1, PathIn, ":", 1, 0) +"Parms"

	LoadWave/H/Q/O/P=RNAPullingParms "RNAPullingSettings.ibw"	
	LoadWave/H/Q/O/P=RNAPullingParms "RNAPullingStrSettings.ibw"	
	LoadWave/H/Q/O/P=RNAPullingParms "RNATouchOffSurface.ibw"	
	LoadWave/H/Q/O/P=RNAPullingParms "RNATouchOffSurfaceStr.ibw"	

	DoWindow RNAPullingPanel
	If(!V_flag)
		Execute "RNAPullingPanel()"
	EndIf
	// Start Hamster fishing program
	InitHamsterFishing()
	// Start Centering program
	InitializeCFP()
	
End



Function DoRNAPull(OperationMode,RNAPullingSettings,RNAPullingStrSettings)
	String OperationMode
	Wave RNAPullingSettings
	Wave/T RNAPullingStrSettings
	Variable Distance=RNAPullingSettings[%Distance]
	Variable ApproachVelocity=RNAPullingSettings[%ApproachVelocity]
	Variable RetractVelocity=RNAPullingSettings[%RetractVelocity]
	Variable DwellTime=RNAPullingSettings[%DwellTime]
	Variable TotalTime=RNAPullingSettings[%TotalTime]
	Variable StepDistance=RNAPullingSettings[%StepDistance]
	Variable TimePerStep=RNAPullingSettings[%TimePerStep]
	Variable NumSteps=RNAPullingSettings[%NumSteps]
	Variable SampleRate=RNAPullingSettings[%SamplingRate]
	String DeflectionWaveName=RNAPullingStrSettings[%DeflectionWaveName]
	String ZSensorWaveName=RNAPullingStrSettings[%ZSensorWaveName]
	String ZSetPointWaveName=RNAPullingStrSettings[%ZSetPointWaveName]
	String Callback=RNAPullingStrSettings[%Callback]
	RNAPullingStrSettings[%NearestForcePull]=LastForceRamp()
	Variable DecimationFactor=Floor(50000/SampleRate)
	SampleRate=50000/DecimationFactor
	RNAPullingSettings[%SamplingRate]=SampleRate
	RNAPullingSettings[%DecimationFactor]=DecimationFactor
	Variable FastCaptureTotalTime=TotalTime

	strswitch(OperationMode)
		case "LocalRamp":
			RNAPullingStrSettings[%CurrentMode]="LocalRamp"
			LocalRampWaves(Distance,RetractVelocity,ApproachVelocity,DwellTime,TotalTime,SampleRate=SampleRate,DeflectionWaveName=DeflectionWaveName,ZSensorWaveName=ZSensorWaveName,ZSetPointWaveName=ZSetPointWaveName)
		break
		case "Steps":
			RNAPullingStrSettings[%CurrentMode]="Steps"
			LocalStepWaves(StepDistance,TimePerStep,NumSteps,SampleRate=SampleRate,DeflectionWaveName=DeflectionWaveName,ZSensorWaveName=ZSensorWaveName,ZSetPointWaveName=ZSetPointWaveName)
			FastCaptureTotalTime=TimePerStep*NumSteps
		break
	EndSwitch
 	
 	Variable CurrentPosition=td_rv("Cypher.LVDT.Z")
	 RNAPullingSettings[%StartPosition]=CurrentPosition
	 // Negative to make wave move away from surface and convert to z sensor volts
	Variable ZLVDTSens=-1/GV("ZLVDTSens")
	Wave ZSensorSetPoint=$ZSetPointWaveName
	Duplicate/O ZSensorSetPoint, root:RNAPulling:ZSensorSetPointTemp
	Wave ZSensorSetPointTemp=root:RNAPulling:ZSensorSetPointTemp
	Variable StartPosition=CurrentPosition-RNAPullingSettings[%StartZOffset]*ZLVDTSens
	FastOp ZSensorSetPoint=(ZLVDTSens)*ZSensorSetPointTemp+(StartPosition)
	Wave Deflection=$DeflectionWaveName
	Wave ZSensor=$ZSensorWaveName
	DoClosedLoopZMotion(ZSensorSetPoint,Deflection,ZSensor,DecimationFactor=DecimationFactor,Callback=Callback)
	DoRNAFastCapture(FastCaptureTotalTime)
	
End

Function DoRNAFastCapture(Duration)
	Variable Duration
	Variable CaptureError
	CaptureError+=td_WV("Cypher.Capture.0.rate",2) // Sets sample rate to 5 MHz
	Make/O/N=0 root:RNAPulling:DefVFast
	Variable FastCaptureLength=Floor(5e6*Duration)
	CaptureError+=td_WV("Cypher.Capture.0.length",FastCaptureLength) // Sets number of points for 5 MHz rate and user defined duration time
	CaptureError+=td_WS("Cypher.Capture.0.trigger","Now") // Starts fast capture NOW!
	CaptureError+=td_WS("Event.14","Once")
	
	If(CaptureError>0)
		Print "Error in RNA fast capture code: "+num2str(CaptureError)
	EndIf


End
Function ReadRNAFastCapture([SaveToMemory,SaveToDisk])
	Variable SaveToMemory,SaveToDisk
	Wave DefVFast=root:RNAPulling:DefVFast
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings
	Wave/T RNAPullingStrSettings=root:RNAPulling:RNAPullingStrSettings
	String CorrectionIteration=num2str(RNAPullingSettings[%Iteration]-1)
	If(ParamIsDefault(SaveToMemory))
		SaveToMemory=0
	EndIF
	If(ParamIsDefault(SaveToDisk))
		SaveToDisk=1
	EndIF

	String NoteForRNAPullingWaves=StandardCypherWaveNote()+WaveDimValuesToString(RNAPullingSettings)+WaveDimTextToString(RNAPullingStrSettings)
	note/K DefVFast NoteForRNAPullingWaves

	If(SaveToMemory)
		Duplicate/O DefVFast, $("root:RNAPulling:SavedData:DefVFast_"+CorrectionIteration)
	EndIf
	ControlInfo/W=FishingPanel SaveDiskCB
	If(SaveToDisk)
		Print "Saving Fast Capture to Disk"
		String PathName="C:Users:Asylum User:Desktop:Rob:FastCaptureData:"+DateStringForSave()
		String SaveName= DateStringForSave()+"_"+TimeStringForSave()+"_"+"RNAPullingFastCapture_"+CorrectionIteration+".pxp"
		NewPath/O/C/Q/Z FastCapturePath,PathName
		//Save/C/P=FastCapturePath DefVFast as SaveName
		SetDataFolder root:RNAPulling
		SaveData/L=1/Q/P=FastCapturePath SaveName
		
	EndIf
	
	print "Done Getting Fast Capture Data"


End




Function LocalRampWaves(Distance,RetractVelocity,ApproachVelocity,DwellTime,TotalTime,[ZSetPointDecimation,SampleRate,DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName])
	Variable Distance,RetractVelocity,ApproachVelocity,DwellTime,TotalTime,SampleRate,ZSetPointDecimation
	String DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName
	
	If(ParamIsDefault(SampleRate))
		SampleRate=50000
	EndIf
	If(ParamIsDefault(ZSetPointDecimation))
		ZSetPointDecimation=100
	EndIf
	If(ParamIsDefault(DeflectionWaveName))
		DeflectionWaveName="root:RNAPulling:DefV"
	EndIf
	If(ParamIsDefault(ZSensorWaveName))
		ZSensorWaveName="root:RNAPulling:ZSensor"
	EndIf
	If(ParamIsDefault(ZSetPointWaveName))
		ZSetPointWaveName="root:RNAPulling:ZSensorSetPoint"
	EndIf
	// Time per ramp includes time to move out and back
	Variable TimePerRamp=Distance/ApproachVelocity+Distance/RetractVelocity+DwellTime
	//  Setup parms for loop
	Variable NumRamps=Floor(TotalTime/TimePerRamp)

	TriangleWaveWithPause(Distance,RetractVelocity,ApproachVelocity,DwellTime,OutWaveName=ZSetPointWaveName,DecimationFactor=ZSetPointDecimation,NumCycles=NumRamps)
	Variable TotalPoints=TimePerRamp*NumRamps*SampleRate

	Make/O/N=(TotalPoints) $DeflectionWaveName,$ZSensorWaveName
End

Function TriangleWaveWithPause(Distance,RetractVelocity,ApproachVelocity,DwellTime,[OutWaveName,DecimationFactor,NumCycles])
	Variable Distance,ApproachVelocity,RetractVelocity,DwellTime
	String OutWaveName
	Variable DecimationFactor,NumCycles
	
	If(ParamIsDefault(OutWaveName))
		OutWaveName="root:RNAPulling:TriangleWave"
	EndIf
	If(ParamIsDefault(DecimationFactor))
		DecimationFactor=1
	EndIf
	If(ParamIsDefault(NumCycles))
		NumCycles=1
	EndIf
	
	Variable SampleRate=50000/DecimationFactor
	Variable NumPointsRetract=Floor((Distance/RetractVelocity)*SampleRate)
	Variable NumPointsApproach=Floor((Distance/ApproachVelocity)*SampleRate)
	Variable NumPointsDwell=Floor(DwellTime*SampleRate)
	Make/O/N=(NumPointsRetract) RetractWave
	Make/O/N=(NumPointsApproach) ApproachWave
	Make/O/N=(NumPointsDwell) DwellWave
	
	RetractWave=RetractVelocity*p/SampleRate
	ApproachWave=-ApproachVelocity*p/SampleRate+RetractWave[NumPointsRetract-1]
	DwellWave=RetractWave[0]
	
	Concatenate/NP/O {RetractWave,ApproachWave,DwellWave}, $OutWaveName
	SetScale/P x 0,1/SampleRate,"s", $OutWaveName
	If(NumCycles>1)
		Variable Counter=0
		Wave RealTriangle=$OutWaveName
		Duplicate/O RealTriangle, TempTriangle
		For(Counter=1;Counter<NumCycles;Counter+=1)
			Concatenate/NP {TempTriangle},RealTriangle
		EndFor
		KillWaves TempTriangle
		
	EndIf
	
	KillWaves ApproachWave,RetractWave,DwellWave
End


Function LocalStepWaves(StepDistance,TimePerStep,NumSteps,[ZSetPointDecimation,SampleRate,DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName])
	Variable StepDistance,TimePerStep,NumSteps,SampleRate,ZSetPointDecimation
	String DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName

	If(ParamIsDefault(SampleRate))
		SampleRate=50000
	EndIf
	If(ParamIsDefault(ZSetPointDecimation))
		ZSetPointDecimation=100
	EndIf
	If(ParamIsDefault(DeflectionWaveName))
		DeflectionWaveName="root:RNAPulling:DefV"
	EndIf
	If(ParamIsDefault(ZSensorWaveName))
		ZSensorWaveName="root:RNAPulling:ZSensor"
	EndIf
	If(ParamIsDefault(ZSetPointWaveName))
		ZSetPointWaveName="root:RNAPulling:ZSensorSetPoint"
	EndIf

	Variable TimePerPointSetPoint=ZSetPointDecimation/50000
	Variable PointsPerStepSetPoint=Floor(TimePerStep/TimePerPointSetPoint)
	Variable TotalPointsSetPoint=NumSteps*PointsPerStepSetPoint
	
	Variable DecimationFactor=Floor(50000/SampleRate)
	Variable TimePerPoint=DecimationFactor/50000
	Variable PointsPerStep=Floor(TimePerStep/TimePerPoint)
	Variable TotalPoints=NumSteps*PointsPerStep

	
	Make/O/N=(TotalPointsSetPoint) $ZSetPointWaveName
	Make/O/N=(TotalPoints) $DeflectionWaveName,$ZSensorWaveName
	Wave Deflection=$DeflectionWaveName
	Wave ZSensor=$ZSensorWaveName
	Wave ZSensorSetPoint=$ZSetPointWaveName
	
	ZSensorSetPoint=Floor(p/PointsPerStepSetPoint)*StepDistance
	SetScale/P x 0,TimePerPointSetPoint,"s", ZSensorSetPoint
	
End

Function RNAPullingCallback()
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings
	Wave/T RNAPullingStrSettings=root:RNAPulling:RNAPullingStrSettings
	
	String DeflectionWaveName=RNAPullingStrSettings[%DeflectionWaveName]
	String ZSensorWaveName=RNAPullingStrSettings[%ZSensorWaveName]
	String ZSetPointWaveName=RNAPullingStrSettings[%ZSetPointWaveName]
	String SavedDataDirectory="root:RNAPulling:SavedData:"
	String IterationString=num2str(RNAPullingSettings[%Iteration])
	String DeflectionSaveName=SavedDataDirectory+"DefV"+IterationString
	String ZSensorSaveName=SavedDataDirectory+"ZSensor"+IterationString
	String ZSetPointSaveName=SavedDataDirectory+"ZSetPoint"+IterationString
	String SettingsSaveName=SavedDataDirectory+"Settings"+IterationString
	String SettingsStrSaveName=SavedDataDirectory+"SettingsStr"+IterationString
	
	Wave DefV=$DeflectionWaveName
	Wave ZSensorV=$ZSensorWaveName
	Wave ZSensorSetPoint=$ZSetPointWaveName
	String NoteForRNAPullingWaves=StandardCypherWaveNote()+WaveDimValuesToString(RNAPullingSettings)+WaveDimTextToString(RNAPullingStrSettings)
	note/K DefV NoteForRNAPullingWaves
	note/K ZSensorV NoteForRNAPullingWaves
	note/K ZSensorSetPoint NoteForRNAPullingWaves

	Duplicate/O $DeflectionWaveName $DeflectionSaveName
	Duplicate/O $ZSensorWaveName $ZSensorSaveName
	Duplicate/O $ZSetPointWaveName $ZSetPointSaveName
	Duplicate/O RNAPullingSettings $SettingsSaveName
	Duplicate/O RNAPullingStrSettings $SettingsStrSaveName

	If(RNAPullingSettings[%TOSAfterRampStep])
		Wave RNATouchOffSurface=root:RNAPulling:RNATouchOffSurface
		Wave/T RNATouchOffSurfaceStr=root:RNAPulling:RNATouchOffSurfaceStr
		RNATouchOffSurfaceStr[%Callback]="RNATOSAfterRampStepCallback()"
		DoForceRamp(RNATouchOffSurface,RNATouchOffSurfaceStr)

	Else
		NextRNAPullIteration()
	EndIf


End

Function NextRNAPullIteration()
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings
	Wave/T RNAPullingStrSettings=root:RNAPulling:RNAPullingStrSettings

	RNAPullingSettings[%Iteration]+=1
	RNAPullingStrSettings[%CurrentMode]="None"
	RNABeep()
	RNAPullingSettings[%TOSIteration]=0

End

Function RNAPullingButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ButtonName=ba.CtrlName
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings
	Wave/T RNAPullingStrSettings=root:RNAPulling:RNAPullingStrSettings
	Wave RNATouchOffSurface=root:RNAPulling:RNATouchOffSurface
	Wave/T RNATouchOffSurfaceStr=root:RNAPulling:RNATouchOffSurfaceStr
	
	String OperationMode=""
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			StrSwitch(ButtonName)
				case "LocalRampsButton":
					OperationMode="LocalRamp"
					DoRNAPull(OperationMode,RNAPullingSettings,RNAPullingStrSettings)
				break
				case "StepsButton":
					OperationMode="Steps"
					DoRNAPull(OperationMode,RNAPullingSettings,RNAPullingStrSettings)
				break
				case "DisplayRNAPull":
					Display root:RNAPulling:DefV vs root:RNAPulling:ZSensor
					Display root:RNAPulling:DefV
				break
				case "StopRNAPull":
					td_stop()
				break
				case "DoTouchOffSurface":
					DoForceRamp(RNATouchOffSurface,RNATouchOffSurfaceStr)
				break
				case "TOSSettings":
					MakeForceRampPanel(RNATouchOffSurface,RNATouchOffSurfaceStr)
				break
				case "ResetTOSCounterButton":
					RNAPullingSettings[%TOSIteration]=0
				break
				case "GoToStartPosition":
					MoveToZPositionClosedLoop(RNAPullingSettings[%StartPosition])
				break
				case "SR1K":
					RNAPullingSettings[%SamplingRate]=1000			
				break
				case "SR50K":
					RNAPullingSettings[%SamplingRate]=50000
				break
				case "RNAReadFastCapture":
					Wave DefVFast=root:RNAPulling:DefVFast
					Print "Reading Fast Capture Data"
					td_readcapture("Cypher.Capture.0",DefVFast,"ReadRNAFastCapture()")

				break
				
			EndSwitch
			
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function RNAPullingSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	String SVName=sva.CtrlName

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Window RNAPullingPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(550,463,942,830) as "RNA Pulling"
	SetDrawLayer UserBack
	DrawLine 10,200,382,200
	DrawLine 170,8,170,199
	Button LocalRampsButton,pos={9,168},size={87,23},proc=RNAPullingButtonProc,title="Do Local Ramps"
	Button LocalRampsButton,fColor=(61440,61440,61440)
	Button StepsButton,pos={188,118},size={87,23},proc=RNAPullingButtonProc,title="Do Steps"
	Button StepsButton,fColor=(61440,61440,61440)
	SetVariable RampDistanceSV,pos={11,9},size={144,16},proc=RNAPullingSetVarProc,title="Ramp Distance"
	SetVariable RampDistanceSV,format="%.1W1Pm"
	SetVariable RampDistanceSV,limits={1e-09,3e-06,5e-09},value= root:RNAPulling:RNAPullingSettings[%Distance]
	SetVariable RampVelocitySV,pos={11,35},size={144,16},proc=RNAPullingSetVarProc,title="Unfold Velocity"
	SetVariable RampVelocitySV,format="%.1W1Pm/s"
	SetVariable RampVelocitySV,limits={0,0.0001,1e-09},value= root:RNAPulling:RNAPullingSettings[%RetractVelocity]
	SetVariable RampTotalTimeSV,pos={11,115},size={144,16},proc=RNAPullingSetVarProc,title="Ramp Total Time"
	SetVariable RampTotalTimeSV,format="%.1W1Ps"
	SetVariable RampTotalTimeSV,limits={0,1000,1},value= root:RNAPulling:RNAPullingSettings[%TotalTime]
	SetVariable StepDistanceSV1,pos={185,9},size={144,16},proc=RNAPullingSetVarProc,title="Step Distance"
	SetVariable StepDistanceSV1,format="%.1W1Pm"
	SetVariable StepDistanceSV1,limits={0,1e-08,2.5e-10},value= root:RNAPulling:RNAPullingSettings[%StepDistance]
	SetVariable TimePerStepSV,pos={185,35},size={144,16},proc=RNAPullingSetVarProc,title="Time per step"
	SetVariable TimePerStepSV,format="%.1W1Ps"
	SetVariable TimePerStepSV,limits={0,1000,1},value= root:RNAPulling:RNAPullingSettings[%TimePerStep]
	SetVariable NumStepsSV,pos={185,62},size={144,16},proc=RNAPullingSetVarProc,title="Number of Steps"
	SetVariable NumStepsSV,limits={1,100,1},value= root:RNAPulling:RNAPullingSettings[%NumSteps]
	SetVariable SamplingRateSV,pos={11,141},size={144,16},proc=RNAPullingSetVarProc,title="Sample Rate"
	SetVariable SamplingRateSV,format="%.1W1PHz"
	SetVariable SamplingRateSV,limits={1,50000,1000},value= root:RNAPulling:RNAPullingSettings[%SamplingRate]
	SetVariable SamplingRateSV1,pos={185,89},size={144,16},proc=RNAPullingSetVarProc,title="Sample Rate"
	SetVariable SamplingRateSV1,format="%.1W1PHz"
	SetVariable SamplingRateSV1,limits={1,50000,1000},value= root:RNAPulling:RNAPullingSettings[%SamplingRate]
	SetVariable RefoldVelocitySV,pos={11,62},size={144,16},proc=RNAPullingSetVarProc,title="Refold Velocity"
	SetVariable RefoldVelocitySV,format="%.1W1Pm/s"
	SetVariable RefoldVelocitySV,limits={0,0.0001,1e-09},value= root:RNAPulling:RNAPullingSettings[%ApproachVelocity]
	SetVariable DwelllTimeSV,pos={11,88},size={144,16},proc=RNAPullingSetVarProc,title="Dwell Time"
	SetVariable DwelllTimeSV,format="%.1W1Ps"
	SetVariable DwelllTimeSV,limits={0,1000,1},value= root:RNAPulling:RNAPullingSettings[%DwellTime]
	SetVariable IterationSV,pos={10,241},size={144,16},proc=RNAPullingSetVarProc,title="Iteration"
	SetVariable IterationSV,limits={0,50000,1},value= root:RNAPulling:RNAPullingSettings[%Iteration]
	SetVariable ZStartOffsetSV,pos={9,265},size={144,16},proc=RNAPullingSetVarProc,title="Z Start Position"
	SetVariable ZStartOffsetSV,format="%.1W1PV"
	SetVariable ZStartOffsetSV,limits={-10,10,0.001},value= root:RNAPulling:RNAPullingSettings[%StartPosition]
	Button DoTouchOffSurface,pos={177,209},size={100,23},proc=RNAPullingButtonProc,title="Touch Off Surface"
	Button DoTouchOffSurface,fColor=(61440,61440,61440)
	Button TOSSettings,pos={284,209},size={100,23},proc=RNAPullingButtonProc,title="TOS Settings"
	Button TOSSettings,fColor=(61440,61440,61440)
	Button StopRNAPulling,pos={10,208},size={50,23},proc=RNAPullingButtonProc,title="Stop"
	Button StopRNAPulling,fColor=(61440,61440,61440)
	Button DisplayRNAPull,pos={66,208},size={100,23},proc=RNAPullingButtonProc,title="Display RNA Pull"
	Button DisplayRNAPull,fColor=(61440,61440,61440)
	SetVariable TOSIterationSV,pos={286,239},size={96,16},proc=RNAPullingSetVarProc,title="TOS Iteration"
	SetVariable TOSIterationSV,limits={1,50000,1},value= root:RNAPulling:RNAPullingSettings[%TOSIteration]
	Button ResetTOSCounterButton,pos={178,238},size={100,23},proc=RNAPullingButtonProc,title="Reset TOS Counter"
	Button ResetTOSCounterButton,fColor=(61440,61440,61440)
	CheckBox TOSAfterRampStep,pos={178,269},size={127,14},proc=RNAPullingCheckProc,title="TOS after Ramp/Steps"
	CheckBox TOSAfterRampStep,value= 0
	Button GoToStartPosition,pos={7,287},size={145,24},proc=RNAPullingButtonProc,title="Go To Start Position"
	Button GoToStartPosition,fColor=(61440,61440,61440)
	CheckBox ReturnToStartPosition,pos={180,293},size={176,14},proc=RNAPullingCheckProc,title="Return to Start Position after TOS"
	CheckBox ReturnToStartPosition,value= 0
	Button SR1K,pos={175,172},size={53,22},proc=RNAPullingButtonProc,title="1 KHz"
	Button SR1K,fColor=(61440,61440,61440)
	Button SR50K,pos={232,172},size={53,22},proc=RNAPullingButtonProc,title="50 KHz"
	Button SR50K,fColor=(61440,61440,61440)
	Button RNAReadFastCapture,pos={5,320},size={145,24},proc=RNAPullingButtonProc,title="Read Fast Capture"
	Button RNAReadFastCapture,fColor=(61440,61440,61440)
EndMacro

Function/S LastForceRamp()
	SVAR gBaseName = root:Packages:MFP3D:Main:Variables:BaseName
	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	Variable Suffix = MVW[%BaseSuffix][0]-1
	String CurrentIterationStr
	sprintf CurrentIterationStr, "%04d", Suffix

	String RampName=gBaseName+CurrentIterationStr
	Return RampName

end

Function RNABeep()
	Beep
End

Function RNATouchOffSurfaceCallback()
	Wave DefV=root:RNAPulling:DefV_TOS
	Wave ZSensor=root:RNAPulling:ZSensor_TOS
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings

	String SaveName="TOS_"+num2str(RNAPullingSettings[%Iteration])+"_"
	SaveAsAsylumForceRamp(SaveName,RNAPullingSettings[%TOSIteration],DefV,ZSensor)
	
	RNABeep()
	RNAPullingSettings[%TOSIteration]+=1
	If(RNAPullingSettings[%ReturnToStartPosition])
		MoveToZPositionClosedLoop(RNAPullingSettings[%StartPosition])
	EndIf
	
End

Function RNATOSAfterRampStepCallback()
	Wave/T RNATouchOffSurfaceStr=root:RNAPulling:RNATouchOffSurfaceStr
	RNATouchOffSurfaceStr[%Callback]="RNATouchOffSurfaceCallback()"
	RNATouchOffSurfaceCallback()
	NextRNAPullIteration()	
End

Function RNAPullingCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			String ParmToChange=cba.ctrlName
			RNAPullingSettings[%$ParmToChange]=Checked
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
