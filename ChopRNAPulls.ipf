#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Function NumStepsOrRamps(Settings,SettingsStr)
	Wave Settings
	Wave/T SettingsStr
	
	StrSwitch(SettingsStr[%CurrentMode])
		Case "LocalRamp":
			Variable TimePerRamp=Settings[%Distance]/Settings[%ApproachVelocity]+Settings[%Distance]/Settings[%RetractVelocity]+Settings[%DwellTime]
			//  Setup parms for loop
			Return Floor(Settings[%TotalTime]/TimePerRamp)
			
		break
		Case "Steps":
			Return Settings[%NumSteps]
		break
	EndSwitch
	
	
End

Function GetRamp(RNASettings, ForceOrZSensorData)
	Wave RNASettings,ForceOrZSensorData
	
	Variable PointsPerRamp=Floor(RNASettings[%SamplingRate]*(RNASettings[%Distance]/RNASettings[%Velocity]))*2
	String UnfoldName=NameOfWave(ForceOrZSensorData)+"_U_"
	String RefoldName=NameOfWave(ForceOrZSensorData)+"_R_"
	
	Variable Counter=0
	Variable NumRamps=Floor(RNASettings[%TotalTime]/(RNASettings[%Distance]/RNASettings[%Velocity]*2))
	For(Counter=0;Counter<NumRamps;Counter+=1)
		Variable StartUIndex=Counter*PointsPerRamp
		Variable EndUindex=(Counter+0.5)*PointsPerRamp
		Variable StartFIndex=EndUIndex+1
		Variable EndFIndex=(Counter+1)*PointsPerRamp-1
		String UnfoldWaveName=UnfoldName+num2str(Counter)
		String RefoldWaveName=RefoldName+num2str(Counter)
		Duplicate/O/R=[StartUIndex,EndUIndex] ForceOrZSensorData, $UnfoldWaveName
		Duplicate/O/R=[StartFIndex,EndFIndex] ForceOrZSensorData, $RefoldWaveName
	EndFor
End

Function GetRampSectionTime(RNAPullingSettings,Index,Section,[StartOrEnd])
	Wave RNAPullingSettings
	Variable Index
	String Section,StartOrEnd
	
	If(ParamIsDefault(StartOrEnd))
		StartOrEnd="Start"
	EndIf
	Variable RetractRampTime=RNAPullingSettings[%Distance]/RNAPullingSettings[%RetractVelocity]
	Variable ApproachRampTime=RNAPullingSettings[%Distance]/RNAPullingSettings[%ApproachVelocity]
	Variable DwellTime=RNAPullingSettings[%DwellTime]
	Variable StartTime=GetRampStartTime(RNAPullingSettings,Index)
	Variable EndTime=GetRampStartTime(RNAPullingSettings,Index)+RetractRampTime
	
	StrSwitch(Section)
		case "Unfolding":
		break
		case "Refolding":
			StartTime+=RetractRampTime
			EndTime=(StartTime+ApproachRampTime)
		break
		case "Dwell":
			StartTime+=(RetractRampTime+ApproachRampTime)
			EndTime=(StartTime+ApproachRampTime+DwellTime)
		break
		case "RefoldingAndDwell":
			StartTime+=(RetractRampTime)
			EndTime=(StartTime+ApproachRampTime+DwellTime)
		break
		case "All":
			EndTime=(StartTime+RetractRampTime+ApproachRampTime+DwellTime)
		break

	EndSwitch
	Variable ReportTime=0
	StrSwitch(StartOrEnd)
		case "Start":
			ReportTime=StartTime
		break
		case "End":
			ReportTime= EndTime
		break
	EndSwitch
	
	Return ReportTime

End

Function GetStepOrRampST(MasterIndex,RampOrStepIndex)
	Variable MasterIndex,RampOrStepIndex
	String SettingsWaveName="root:RNAPulling:SavedData:Settings"+num2str(MasterIndex)
	String SettingsStrWaveName="root:RNAPulling:SavedData:SettingsStr"+num2str(MasterIndex)
	If(WaveExists($SettingsWaveName))
		Wave RNAPullingSettings=$SettingsWaveName
		Wave/T RNAPullingSettingsStr=$SettingsStrWaveName
		Return GetRNAStartTime(RNAPullingSettings,RNAPullingSettingsStr,RampOrStepIndex)
	EndIf
	
End

Function GetRNAStartTime(RNAPullingSettings,RNAPullingSettingsStr,Index)
	Wave RNAPullingSettings
	Wave/T RNAPullingSettingsStr
	Variable Index
	
	StrSwitch(RNAPullingSettingsStr[%CurrentMode])
		case "LocalRamp":
			Return GetRampStartTime(RNAPullingSettings,Index)
		break
		case "Steps":
			Return GetStepStartTime(RNAPullingSettings,Index)
		break
	Endswitch		
		
End


Function GetRampStartTime(RNAPullingSettings,Index)
	Wave RNAPullingSettings
	Variable Index
	Variable TimePerRamp=RNAPullingSettings[%Distance]/RNAPullingSettings[%ApproachVelocity]+RNAPullingSettings[%Distance]/RNAPullingSettings[%RetractVelocity]+RNAPullingSettings[%DwellTime]
	//  Setup parms for loop
	Variable NumRamps=Floor(RNAPullingSettings[%TotalTime]/TimePerRamp)
	
	If(Index>=0&&Index<NumRamps)
		Variable StartTime=Index*TimePerRamp
		
		Return StartTime
	Else
		Print "Invalid ramp index"
	EndIF

End

Function GetStepStartTime(RNAPullingSettings,Index)
	Wave RNAPullingSettings
	Variable Index
	Variable TimePerRamp=RNAPullingSettings[%Distance]/RNAPullingSettings[%ApproachVelocity]+RNAPullingSettings[%Distance]/RNAPullingSettings[%RetractVelocity]+RNAPullingSettings[%DwellTime]
	//  Setup parms for loop
	Variable NumSteps=RNAPullingSettings[%NumSteps]
	If(Index>=0&&Index<NumSteps)
		Variable StartTime=Index*RNAPullingSettings[%TimePerStep]
		Return StartTime
	Else
		Print "Invalid step index"
	EndIF

End