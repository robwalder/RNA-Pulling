#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=0.9

Menu "RNA Pulling"
	"Initialize RNA Pulling", InitRNAPulling()
End

Function InitRNAPulling()
	NewDataFolder/O root:RNAPulling
	NewDataFolder/O root:RNAPulling:SavedData
	Make/O/N=10 root:RNAPulling:RNAPullingSettings
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings
	SetDimLabel 0,0, Distance, RNAPullingSettings
 	SetDimLabel 0,1, Velocity, RNAPullingSettings
 	SetDimLabel 0,2, TotalTime, RNAPullingSettings
 	SetDimLabel 0,3, StepDistance, RNAPullingSettings
 	SetDimLabel 0,4, TimePerStep, RNAPullingSettings
 	SetDimLabel 0,5, NumSteps, RNAPullingSettings
 	SetDimLabel 0,6, SamplingRate, RNAPullingSettings
 	SetDimLabel 0,7, DecimationFactor, RNAPullingSettings
 	SetDimLabel 0,8, Iteration, RNAPullingSettings
 	SetDimLabel 0,9, StartZPosition, RNAPullingSettings
 	
 	Variable CurrentPosition=GV("Cypher.LVDT.Z")
 	RNAPullingSettings={20e-9,10e-9,10,1e-9,1,10,50000,1,0,CurrentPosition}
	
	Make/T/O/N=6 root:RNAPulling:RNAPullingStrSettings
	Wave/T RNAPullingStrSettings=root:RNAPulling:RNAPullingStrSettings

	SetDimLabel 0,0, Callback, RNAPullingStrSettings
	SetDimLabel 0,1, CurrentMode, RNAPullingStrSettings
	SetDimLabel 0,2, DeflectionWaveName, RNAPullingStrSettings
	SetDimLabel 0,3, ZSensorWaveName, RNAPullingStrSettings
	SetDimLabel 0,4, ZSetPointWaveName, RNAPullingStrSettings
	SetDimLabel 0,5, NearestForcePull, RNAPullingStrSettings
	
	RNAPullingStrSettings={"RNAPullingCallback()","Waiting","DefV_0","ZSensor_0","ZSetPoint_0","NearestForcePull"}

	DoWindow RNAPullingPanel
	If(!V_flag)
		Execute "RNAPullingPanel()"
	EndIf

End


Function DoClosedLoopZMotion(ZSensorSetPoint,Deflection,ZSensor,[DecimationFactor,Callback])
	Wave ZSensorSetPoint,Deflection,ZSensor
	Variable DecimationFactor
	String Callback
	Variable Error	
		
	// Stop anything on the controller
	Error += td_stop()
	//  Setup z feedback loop, put in correct I value for PID loop.  
	Error +=	ir_SetPISLoop(0,"Always,Never","Cypher.LVDT.Z",ZSensorSetPoint[0],0, 5.768e4, 0,"ARC.Output.Z",-10,150)

	// Setup motion
	Error += td_xSetOutWave(0, "0,0", "PIDSLoop.0.Setpoint", ZSensorSetPoint,1)
	
	// Setup input waves for x,y,z and deflection.  After the motion is done, callback will execute
	Error += td_xSetInWavePair(0, "0,0", "Cypher.LVDT.Z", ZSensor, "Deflection", Deflection,Callback, DecimationFactor)

	// Do the motion
	Error +=td_WriteString("Event.0", "once")

	if (Error>0)
		print "Error in Closed Loop Z Sensor Motion ", Error
	endif
	
End

Function DoRNAPull(OperationMode,RNAPullingSettings,RNAPullingStrSettings)
	String OperationMode
	Wave RNAPullingSettings
	Wave/T RNAPullingStrSettings
	Variable Distance=RNAPullingSettings[%Distance]
	Variable Velocity=RNAPullingSettings[%Velocity]
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

	strswitch(OperationMode)
		case "LocalRamp":
			RNAPullingStrSettings[%CurrentMode]="LocalRamp"
			LocalRampWaves(Distance,Velocity,TotalTime,SampleRate=SampleRate,DeflectionWaveName=DeflectionWaveName,ZSensorWaveName=ZSensorWaveName,ZSetPointWaveName=ZSetPointWaveName)
		break
		case "Steps":
			RNAPullingStrSettings[%CurrentMode]="Steps"
			LocalStepWaves(StepDistance,TimePerStep,NumSteps,SampleRate=SampleRate,DeflectionWaveName=DeflectionWaveName,ZSensorWaveName=ZSensorWaveName)
		break
	EndSwitch
 	
 	Variable CurrentPosition=GV("Cypher.LVDT.Z")
	 RNAPullingSettings[%StartZPosition]=CurrentPosition

	Wave ZSensorSetPoint=$ZSetPointWaveName
	FastOp ZSensorSetPoint=-1*ZSensorSetPoint+(CurrentPosition)
	Wave Deflection=$DeflectionWaveName
	Wave ZSensor=$ZSensorWaveName
	DoClosedLoopZMotion(ZSensorSetPoint,Deflection,ZSensor,DecimationFactor=DecimationFactor,Callback=Callback)
End

Function LocalRampWaves(Distance,Velocity,TotalTime,[SampleRate,DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName])
	Variable Distance,Velocity,TotalTime,SampleRate
	String DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName
	
	If(ParamIsDefault(SampleRate))
		SampleRate=50000
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
	Variable TimePerRamp=Distance/Velocity*2
	// Num points per ramp.  
	Variable PointsPerRamp=Floor(SampleRate*(Distance/Velocity))*2
	Variable RampSlope=Distance/(PointsPerRamp/2)
	//  Setup parms for loop
	Variable NumRamps=Floor(TotalTime/TimePerRamp)
	Variable TotalPoints=NumRamps*PointsPerRamp
	Make/O/N=(TotalPoints) $DeflectionWaveName,$ZSensorWaveName,$ZSetPointWaveName
	Wave Deflection=$DeflectionWaveName
	Wave ZSensor=$ZSensorWaveName
	Wave ZSensorSetPoint=$ZSetPointWaveName
	
	Deflection = 0
	ZSensor = 0
	ZSensorSetPoint=TriangleWave(p,RampSlope,PointsPerRamp)	
End

Function TriangleWave(CurrentIndex,Slope,NumPointsPerTriangle)
	Variable CurrentIndex,Slope,NumPointsPerTriangle
	Variable WhichTriangle = Floor(CurrentIndex/NumPointsPerTriangle)
	Variable NormalizedIndex=CurrentIndex-WhichTriangle*NumPointsPerTriangle
	Variable GoingUp=NormalizedIndex<(NumPointsPerTriangle/2)
	Variable ReturnValue
	If(GoingUp)
		ReturnValue=Slope*NormalizedIndex
	Else
		ReturnValue=Slope*(-NormalizedIndex+NumPointsPerTriangle)
	EndIf
	Return ReturnValue

End //TriangleWave

Function LocalStepWaves(StepDistance,TimePerStep,NumSteps,[SampleRate,DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName])
	Variable StepDistance,TimePerStep,NumSteps,SampleRate
	String DeflectionWaveName,ZSensorWaveName,ZSetPointWaveName

	If(ParamIsDefault(SampleRate))
		SampleRate=50000
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

	
	Variable PointsPerStep=TimePerStep*SampleRate
	Variable TotalPoints=NumSteps*PointsPerStep
	
	Make/O/N=(TotalPoints) $DeflectionWaveName,$ZSensorWaveName,$ZSetPointWaveName
	Wave Deflection=$DeflectionWaveName
	Wave ZSensor=$ZSensorWaveName
	Wave ZSensorSetPoint=$ZSetPointWaveName
	
	Deflection = 0
	ZSensor = 0
	ZSensorSetPoint=Floor(p/PointsPerStep)*StepDistance	
	
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
	
	Duplicate/O $DeflectionWaveName $DeflectionSaveName
	Duplicate/O $ZSensorWaveName $ZSensorSaveName
	Duplicate/O $ZSetPointWaveName $ZSetPointSaveName
	Duplicate/O RNAPullingSettings $SettingsSaveName
	Duplicate/O RNAPullingStrSettings $SettingsStrSaveName
	RNAPullingSettings[%Iteration]+=1
	RNAPullingStrSettings[%CurrentMode]="None"

End

Function RNAPullingButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ButtonName=ba.CtrlName
	Wave RNAPullingSettings=root:RNAPulling:RNAPullingSettings
	Wave/T RNAPullingStrSettings=root:RNAPulling:RNAPullingStrSettings
	String OperationMode=""
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			StrSwitch(ButtonName)
				case "LocalRampsButton":
					OperationMode="LocalRamp"
				break
				case "StepsButton":
					OperationMode="Steps"
				break
			EndSwitch
			DoRNAPull(OperationMode,RNAPullingSettings,RNAPullingStrSettings)
			
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
	NewPanel /W=(970,115,1308,265) as "RNA Pulling"
	Button LocalRampsButton,pos={13,115},size={87,23},proc=RNAPullingButtonProc,title="Do Local Ramps"
	Button StepsButton,pos={182,115},size={87,23},proc=RNAPullingButtonProc,title="Do Steps"
	SetVariable RampDistanceSV,pos={13,9},size={144,16},proc=RNAPullingSetVarProc,title="Ramp Distance"
	SetVariable RampDistanceSV,format="%.1W1Pm"
	SetVariable RampDistanceSV,value= root:RNAPulling:RNAPullingSettings[%Distance]
	SetVariable RampVelocitySV,pos={13,35},size={144,16},proc=RNAPullingSetVarProc,title="Ramp Velocity"
	SetVariable RampVelocitySV,format="%.1W1Pm/s"
	SetVariable RampVelocitySV,limits={0,0.0001,1e-09},value= root:RNAPulling:RNAPullingSettings[%Velocity]
	SetVariable RampTotalTimeSV,pos={13,62},size={144,16},proc=RNAPullingSetVarProc,title="Ramp Total Time"
	SetVariable RampTotalTimeSV,format="%.1W1Ps"
	SetVariable RampTotalTimeSV,limits={0,1000,1},value= root:RNAPulling:RNAPullingSettings[%TotalTime]
	SetVariable StepDistanceSV1,pos={182,9},size={144,16},proc=RNAPullingSetVarProc,title="Step Distance"
	SetVariable StepDistanceSV1,format="%.1W1Pm"
	SetVariable StepDistanceSV1,limits={0,1e-08,1e-09},value= root:RNAPulling:RNAPullingSettings[%StepDistance]
	SetVariable TimePerStepSV,pos={182,35},size={144,16},proc=RNAPullingSetVarProc,title="Time per step"
	SetVariable TimePerStepSV,format="%.1W1Ps"
	SetVariable TimePerStepSV,limits={0,1000,1},value= root:RNAPulling:RNAPullingSettings[%TimePerStep]
	SetVariable NumStepsSV,pos={182,62},size={144,16},proc=RNAPullingSetVarProc,title="Number of Steps"
	SetVariable NumStepsSV,limits={1,100,1},value= root:RNAPulling:RNAPullingSettings[%NumSteps]
	SetVariable SamplingRateSV,pos={13,89},size={144,16},proc=RNAPullingSetVarProc,title="Sample Rate"
	SetVariable SamplingRateSV,format="%.1W1PHz"
	SetVariable SamplingRateSV,limits={1,50000,1000},value= root:RNAPulling:RNAPullingSettings[%SamplingRate]
	SetVariable SamplingRateSV1,pos={182,89},size={144,16},proc=RNAPullingSetVarProc,title="Sample Rate"
	SetVariable SamplingRateSV1,format="%.1W1PHz"
	SetVariable SamplingRateSV1,limits={1,50000,1000},value= root:RNAPulling:RNAPullingSettings[%SamplingRate]
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