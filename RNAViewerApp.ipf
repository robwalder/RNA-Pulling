#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0
#include ":ChopRNAPulls"
#include "::Force-Ramp-Utilities:BoxCarAveraging"
#include ":RNAViewer"

#pragma ModuleName = RNAViewerApp


Static Function Init([InstallDF,ShowGUI])
	String InstallDF
	Variable ShowGUI
	
	If(ParamIsDefault(ShowGUI))
		ShowGUI=1
	EndIF
	If(ParamIsDefault(InstallDF))
		InstallDF="root:RNAViewer"
	EndIF
	String SettingsDF=InstallDF+":Settings"
	
	NewDataFolder/O/S $InstallDF
	NewDataFolder/O/S $SettingsDF

	// Set HMM Parms Path
	String PathIn=FunctionPath("")
	NewPath/Q/O RNAViewer ParseFilePath(1, PathIn, ":", 1, 0) +"Parms"
	LoadWave/H/Q/O/P=RNAViewer "RNAViewer_Settings.ibw"	
	LoadWave/H/Q/O/P=RNAViewer "RNAViewer_SettingsStr.ibw"	
	
	// Set initial values for viewer settings
	Wave RNAViewer_Settings
	Variable MinIndex=RNAViewer#FindMinIteration()
	Variable MaxIndex=RNAViewer#FindMaxIteration()
	RNAViewer_Settings[%MinIteration]=MinIndex
	RNAViewer_Settings[%MaxIteration]=MaxIndex
	RNAViewer_Settings[%MasterIndex]=MinIndex
	RNAViewer_Settings[%SubIndex]=0
	
	// Set up offsets and filters
	SetDataFolder $SettingsDF
	Make/O/N=(MaxIndex) ForceOffset,SepOffset
	Make/O/N=(MaxIndex,2) FilterSettings
	FilterSettings=1
	SetDimLabel 1,0, BoxCarNum, FilterSettings
 	SetDimLabel 1,1, Decimation, FilterSettings
	InitRNAPullingOffsets()
	
	// Load initial waves for first rna pull
	LoadMasterIndex(MinIndex)
	LoadRorS(MinIndex,0)
	
	// Load RNA viewer Panel
	If(ShowGUI)
		Execute/Q "RNAViewerPanel()"
	EndIf

End

Static Function MakeOffsetWaves()
	SetDataFolder root:RNAViewer:Settings
	Make/O/N=(RNAViewer#FindMaxIteration()) ForceOffset, SepOffset
End

Static Function UpdateOffsetWaves()
	Wave ForceOffset=root:RNAViewer:Settings:ForceOffset
	Wave SepOffset=root:RNAViewer:Settings:SepOffset
	
	Redimension/N=(RNAViewer#FindMaxIteration()) ForceOffset, SepOffset
End

Static Function InitRNAPullingOffsets([StartIndex])
	Variable StartIndex
	Wave RNAViewer_Settings=root:RNAViewer:Settings:RNAViewer_Settings
	If(ParamIsDefault(StartIndex))
		StartIndex=RNAViewer_Settings[%MinIteration]
	EndIf
	Wave ForceOffset=root:RNAViewer:Settings:ForceOffset
	Wave SepOffset=root:RNAViewer:Settings:SepOffset	
		
	Variable NumRS=RNAViewer#FindMaxIteration()
	Variable RSCounter=StartIndex
	For(RSCounter=StartIndex;RSCounter<NumRS;RSCounter+=1)
		If(WaveExists($"root:FRU:preprocessing:Offsets"))
			Wave/T SettingsStr=$"root:RNAPulling:SavedData:SettingsStr"+num2str(RSCounter)
			String FRName=SettingsStr[%NearestForcePull]
			Wave FRUOffsets=root:FRU:preprocessing:Offsets
			ForceOffset[RSCounter]=FRUOffsets[%$FRName][%Offset_Force]
			SepOffset[RSCounter]=FRUOffsets[%$FRName][%Offset_Sep]
		EndIf
	EndFor
End

Static Function UpdateRNAPullingOffsets(MasterIndex,NewForceOffset,NewSepOffset,[RampDF])
	Variable MasterIndex,NewForceOffset,NewSepOffset
	String RampDF
	If(ParamIsDefault(RampDF))
		RampDF="root:RNAViewer:"
	EndIf

	Wave RSForceOffset=root:RNAViewer:Settings:ForceOffset
	Wave RSSepOffset=root:RNAViewer:Settings:SepOffset	
	
	If(!(NewForceOffset==RSForceOffset[MasterIndex]))
		// Adjust Ramp fits and rupture forces if we have them.
		RSForceOffset[MasterIndex]=NewForceOffset
	EndIf
	If(NewSepOffset!=RSSepOffset[MasterIndex])
		RSSepOffset[MasterIndex]=NewSepOffset
	EndIf
End
Static Function/Wave GetRNAWave(MasterIndex,WhichWave)
	Variable MasterIndex
	String WhichWave
	String NamePrefix="root:RNAPulling:SavedData:"
	String TargetWaveName=NamePrefix+WhichWave+num2str(MasterIndex)
	Wave TargetWave=$TargetWaveName
	
	Return TargetWave
	
End

Static Function LoadMasterIndex(MasterIndex,[TargetDF])
	Variable MasterIndex
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAViewer:"
	EndIf
	
	Duplicate/O GetRNAWave(MasterIndex,"DefV") $(TargetDF+"DefV")
	Duplicate/O GetRNAWave(MasterIndex,"ZSensor") $(TargetDF+"ZSensor")
	Duplicate/O GetRNAWave(MasterIndex,"Settings") $(TargetDF+"Settings")
	Duplicate/T/O GetRNAWave(MasterIndex,"SettingsStr") $(TargetDF+"SettingsStr")
	Duplicate/O GetRNAWave(MasterIndex,"ZSetPoint") $(TargetDF+"ZSetPoint")
	
	Wave/T SettingsStr=$(TargetDF+"SettingsStr")
	Wave TargetDefV=$(TargetDF+"DefV")
	String RNAPullInfo=Note(TargetDefV)
	String FRName=SettingsStr[%NearestForcePull]//StringByKey("\rNearestForcePull",RNAPullInfo,"=",";\r")
	
	// Changed this to the "extension" curve, since this typically happens right after the measurement. 
	// Allows better visualization of force offset and should be useful for doing "integrate" work energy analysis.
	ApplyFuncsToForceWaves("SaveForceAndSep(Force_Ext,Sep_Ext,TargetFolder=\""+TargetDF+"\",NewName=\"Selected\")",FPList=FRName)
	Wave SelectedForce_Ret=root:RNAViewer:SelectedForce_Ret
	Wave SelectedSep_Ret=root:RNAViewer:SelectedSep_Ret
	LoadCorrectedFR(SelectedForce_Ret,SelectedSep_Ret,FRName)
	
	Duplicate/O$(TargetDF+"DefV"), $(TargetDF+"RorSForce")
	Duplicate/O$(TargetDF+"ZSensor"),  $(TargetDF+"RorSSep"), $(TargetDF+"Extension")
	Wave RorSForce=$(TargetDF+"RorSForce")
	Wave RorSSep= $(TargetDF+"RorSSep")
	Wave Extension=$(TargetDF+"Extension")
	String DefVInfo=note(RorSForce)
	Variable SpringConstant=str2num(StringByKey("K",DefVInfo,"=",";\r"))
	Variable Invols=str2num(StringByKey("\rInvols",DefVInfo,"=",";\r"))
	Variable VtoF=SpringConstant*Invols
	Variable ForceOffset=0
	Variable SepOffset=0
	If(WaveExists($"root:FRU:preprocessing:Offsets"))
		Wave FRUOffsets=root:FRU:preprocessing:Offsets
		UpdateRNAPullingOffsets(MasterIndex,FRUOffsets[%$FRName][%Offset_Force],FRUOffsets[%$FRName][%Offset_Sep])
	EndIf
	Wave RSForceOffset=root:RNAViewer:Settings:ForceOffset
	Wave RSSepOffset=root:RNAViewer:Settings:SepOffset	
	ForceOffset=RSForceOffset[MasterIndex]
	SepOffset=RSSepOffset[MasterIndex]
		
	FastOp RorSForce=(ForceOffset)-(VtoF)*RorSForce
	
	String ZSensorInfo=note(RorSSep)
	Variable ZSens=-1*str2num(StringByKey("\rZLVDTSens",ZSensorInfo,"=",";\r"))
	Variable InverseK=1/SpringConstant
	Variable InverseKFO=InverseK*ForceOffset-SepOffset
	FastOp RorSSep=(InverseKFO)+(ZSens)*RorSSep-(InverseK)*RorSForce//+(SepOffset)
	FastOp Extension=(ZSens)*Extension//+(SepOffset)
	Variable ExtensionOffset=Wavemin(Extension)
	FastOp Extension=Extension-(ExtensionOffset)	
	MakeSmoothedRorS(MasterIndex,TargetDF=TargetDF)	
End

Static Function MakeStartEndIndexRorS(MasterIndex,ZSetPoint,RNAPullingSettings,RNAPullingSettingsStr,[StartIndexName,EndIndexName,UnfoldStartName,UnfoldEndName,RefoldStartName,RefoldEndName])
	Variable MasterIndex
	Wave ZSetPoint,RNAPullingSettings
	Wave/T RNAPullingSettingsStr
	String StartIndexName,EndIndexName,UnfoldStartName,UnfoldEndName,RefoldStartName,RefoldEndName
		If(ParamIsDefault(StartIndexName))
		StartIndexName="root:RNAViewer:StartIndex"
	EndIf

	If(ParamIsDefault(EndIndexName))
		EndIndexName="root:RNAViewer:EndIndex"
	EndIf
	If(ParamIsDefault(UnfoldStartName))
		UnfoldStartName="root:RNAViewer:UnfoldStart"
	EndIf
	If(ParamIsDefault(UnfoldEndName))
		UnfoldEndName="root:RNAViewer:UnfoldEnd"
	EndIf
	If(ParamIsDefault(RefoldStartName))
		RefoldStartName="root:RNAViewer:RefoldStart"
	EndIf
	If(ParamIsDefault(RefoldEndName))
		RefoldEndName="root:RNAViewer:RefoldEnd"
	EndIf
	
	Variable RSIndex=0
	Variable NumRS=NumStepsOrRamps(RNAPullingSettings,RNAPullingSettingsStr)
	Make/O/D/N=(NumRS) $StartIndexName,$EndIndexName,$UnfoldStartName,$UnfoldEndName,$RefoldStartName,$RefoldEndName
	Wave StartIndex=$StartIndexName
	Wave EndIndex=$EndIndexName
	Wave UnfoldStart=$UnfoldStartName
	Wave UnfoldEnd=$UnfoldEndName
	Wave RefoldStart=$RefoldStartName
	Wave RefoldEnd=$RefoldEndName
	
	
	For(RSIndex=0;RSIndex<NumRS;RSIndex+=1)
	
		StrSwitch(RNAPullingSettingsStr[%CurrentMode])
			case "LocalRamp":
				Variable TotalTime=deltax(ZSetPoint)*DimSize(ZSetPoint,0)
				Variable TimePerRamp=TotalTime/NumStepsOrRamps(RNAPullingSettings,RNAPullingSettingsStr)
				StartIndex[RSIndex]=RSIndex*TimePerRamp
				EndIndex[RSIndex]=(RSIndex+1)*TimePerRamp
				UnfoldStart[RSIndex]=RSIndex*TimePerRamp
				UnfoldEnd[RSIndex]=(RSIndex+0.5)*TimePerRamp
				RefoldStart[RSIndex]=(RSIndex+0.5)*TimePerRamp
				RefoldEnd[RSIndex]=(RSIndex+1)*TimePerRamp
			break
			case "Steps":
				StartIndex[RSIndex]=GetStepStartTime(RNAPullingSettings,RSIndex)
				EndIndex[RSIndex]=StartIndex+RNAPullingSettings[%TimePerStep]
				UnfoldStart[RSIndex]=NaN
				UnfoldEnd[RSIndex]=NaN
				RefoldStart[RSIndex]=NaN
				RefoldEnd[RSIndex]=NaN
				
			break
	EndSwitch
	EndFor

	

End

Static Function MakeSmoothedRorS(MasterIndex,[TargetDF])
	Variable MasterIndex
	String TargetDF
	
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAViewer:"
	EndIf
	
	// Make Smoothed version of ramps or steps
	Wave RorSForce=$(TargetDF+"RorSForce")
	Wave RorSSep= $(TargetDF+"RorSSep")
	
	Duplicate/O RorSForce, $(TargetDF+"RorSForce_Smth")
	Duplicate/O RorSSep, $(TargetDF+"RorSSep_Smth")
	
	Wave RorSForce_Smth=$(TargetDF+"RorSForce_Smth")
	Wave RorSSep_Smth=$(TargetDF+"RorSSep_Smth")
	
	Variable BoxCarNumber=0
	Variable DecimationFactor=0
	String SettingsDF=TargetDF+"Settings:"
	
	If(WaveExists($(SettingsDF+"FilterSettings")))
		Wave RSFilterSettings=$(SettingsDF+"FilterSettings")
		BoxCarNumber=RSFilterSettings[MasterIndex][0]
		DecimationFactor=RSFilterSettings[MasterIndex][1]
	EndIf
	If(BoxCarNumber>1)
		BoxCarAndDecimateFR(RorSForce_Smth,RorSSep_Smth,BoxCarNumber,DecimationFactor,SmoothMode="SavitzkyGolay")
	EndIF

End

Static Function LoadRorS(MasterIndex,RSIndex,[TargetDF])
	Variable MasterIndex,RSIndex
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAViewer:"
	EndIf
	Wave Settings=$TargetDF+"Settings"
	Wave/T SettingsStr=$TargetDF+"SettingsStr"
	Wave DefV=$TargetDF+"DefV"
	Wave ZSensor=$TargetDF+"ZSensor"
	Wave ZSetPoint=$TargetDF+"ZSetPoint"
	Wave RorSForce=$TargetDF+"RorSForce"
	Wave RorSSep=$TargetDF+"RorSSep"
	String ForcePath=TargetDF+"ForceRorS"
	String SepPath=TargetDF+"SepRorS"
	Wave RorSForce_smth=$TargetDF+"RorSForce_smth"
	Wave RorSSep_smth=$TargetDF+"RorSSep_smth"
	String ForcesmthPath=TargetDF+"ForceRorS_smth"
	String SepsmthPath=TargetDF+"SepRorS_smth"
	
	GetIndividualRoS(MasterIndex,RSIndex,DefV,ZSensor,ZSetPoint,Settings,SettingsStr)
	GetIndividualRoS(MasterIndex,RSIndex,RorSForce,RorSSep,ZSetPoint,Settings,SettingsStr,DefVName=ForcePath,ZSensorName=SepPath)
	GetIndividualRoS(MasterIndex,RSIndex,RorSForce_smth,RorSSep_smth,ZSetPoint,Settings,SettingsStr,DefVName=ForcesmthPath,ZSensorName=SepsmthPath)
End

Static Function NormalColorDisplays()
	DoWindow/F RNAAnalysis_RorS_FvsS
	ModifyGraph zColor(ForceRorS_smth)=0
	ModifyGraph rgb(ForceRorS_Smth)=(0,15872,65280)
	DoWindow/F RNAAnalysis_RorS_F
	ModifyGraph zColor(ForceRorS_smth)=0
	ModifyGraph rgb(ForceRorS_Smth)=(0,15872,65280)
	
	Wave RorSForce_Smth=root:RNAViewer:RorSForce_Smth
	DoWindow/F RNAAnalysis_RorSForce
	ModifyGraph zColor(RorSForce_Smth)=0
	ModifyGraph rgb(RorSForce_Smth)=(0,15872,65280)

End

Static Function ColorDisplaysByWave(ColorWave,[UpdateMain])
	Wave ColorWave
	Variable UpdateMain
	If(ParamIsDefault(UpdateMain))
		UpdateMain=1
	EndIF
	
	If(!WaveExists(ColorWave))
		Return 0
	EndIf
	
	Wave ForceRorS_Smth=root:RNAViewer:ForceRorS_Smth
	Wave RorSForce_Smth=root:RNAViewer:RorSForce_Smth
	Wave Sep=root:RNAViewer:RorSSep_Smth
	Wave SmoothAll=root:RNAViewer:RorSForce_Smth
	WaveStats/Q ForceRorS_Smth
	Variable StartTime=pnt2x(ForceRorS_Smth,V_startRow)
	Variable EndTime=pnt2x(ForceRorS_Smth,V_endRow)
	Variable StartTargetP=x2pnt(SmoothAll,StartTime)
	Variable EndTargetP=x2pnt(SmoothAll,EndTime)
	
	DoWindow/F RNAAnalysis_RorS_FvsS
	ModifyGraph zColor(ForceRorS_Smth)={ColorWave[StartTargetP,EndTargetP],*,*,Rainbow16,0}
	SetWindow RNAAnalysis_RorS_FvsS hook(ChangeStateHook)=RNAViewerApp#StateEditHookFunction

	DoWindow/F RNAAnalysis_RorS_F
	ModifyGraph zColor(ForceRorS_Smth)={ColorWave[StartTargetP,EndTargetP],*,*,Rainbow16,0}
	SetWindow RNAAnalysis_RorS_F hook(ChangeStateHook)=RNAViewerApp#StateEditHookFunction
	
	If(UpdateMain)
		Wave RorSForce_Smth=root:RNAViewer:RorSForce_Smth
		DoWindow/F RNAAnalysis_RorSForce
		ModifyGraph zColor(RorSForce_Smth)={ColorWave,*,*,Rainbow16,0}
	EndIf
	Return 1
End

Static Function SetStateByXFRange(StateWave,NewState,StartX,EndX,StartF,EndF)
	Wave StateWave
	Variable NewState,StartX,EndX,StartF,EndF
	
	Wave ForceRorS_Smth=root:RNAViewer:ForceRorS_Smth
	Wave SepRorS_Smth=root:RNAViewer:SepRorS_Smth
	
	Wave RorSForce_Smth=root:RNAViewer:RorSForce_Smth
	Wave Sep=root:RNAViewer:RorSSep_Smth
	Wave SmoothAll=root:RNAViewer:RorSForce_Smth
	WaveStats/Q ForceRorS_Smth
	Variable StartTime=pnt2x(ForceRorS_Smth,V_startRow)
	Variable EndTime=pnt2x(ForceRorS_Smth,V_endRow)
	Variable StartTargetP=x2pnt(SmoothAll,StartTime)
	Variable EndTargetP=x2pnt(SmoothAll,EndTime)
	
	Duplicate/O RorSForce_Smth, ForceInRange,SepInRange,PinRange,InRangeForThisRorS
	ForceInRange=(RorSForce_Smth>=StartF)&&(RorSForce_Smth<=EndF)
	SepInRange=(Sep>=StartX)&&(Sep<=EndX)
	PinRange=(p>=StartTargetP)&&(p<=EndTargetP)
	InRangeForThisRorS=ForceInRange&&SepInRange&&PinRange
	
	StateWave=InRangeForThisRorS[p]==1 ? NewState : StateWave[p]
End

Static Function SetStateBytFRange(StateWave,NewState,StartX,EndX,StartF,EndF)
	Wave StateWave
	Variable NewState,StartX,EndX,StartF,EndF
	
	Wave ForceRorS_Smth=root:RNAViewer:ForceRorS_Smth
	
	Wave RorSForce_Smth=root:RNAViewer:RorSForce_Smth
	Wave SmoothAll=root:RNAViewer:RorSForce_Smth
	WaveStats/Q ForceRorS_Smth
	Variable StartTime=pnt2x(ForceRorS_Smth,V_startRow)
	Variable EndTime=pnt2x(ForceRorS_Smth,V_endRow)
	Variable StartTargetP=x2pnt(SmoothAll,StartTime)
	Variable EndTargetP=x2pnt(SmoothAll,EndTime)
	
	Duplicate/O RorSForce_Smth, ForceInRange,TimeInRange,PinRange,InRangeForThisRorS
	ForceInRange=(RorSForce_Smth>=StartF)&&(RorSForce_Smth<=EndF)
	TimeInRange=(pnt2x(RorSForce_Smth,p)>=StartX)&&(pnt2x(RorSForce_Smth,p)<=EndX)
	PinRange=(p>=StartTargetP)&&(p<=EndTargetP)
	InRangeForThisRorS=ForceInRange&&TimeInRange&&PinRange
	
	StateWave=InRangeForThisRorS[p]==1 ? NewState : StateWave[p]
End

Static Function StateEditHookFunction(s)
	STRUCT WMWinHookStruct &s
	Variable hookResult = 0	// 0 if we do not handle event, 1 if we handle it.
	Variable ControlButton=(s.eventmod & 2^3)!=0
	Variable ShiftButton=(s.eventmod & 2^1)!=0
	
	// handle event
	switch(s.eventCode)
		case 11: // Keyboard event
		//If(ControlButton)
		//print "control"
			switch (s.keycode)
				case 48: // 0
				case 49: // 1
				case 50: // 2
				case 51: // 3
				case 52: // 4
				case 53: // 5
				case 54: // 6
				case 55: // 7
					GetMarquee left, bottom
					print "yes"
					If(V_flag)
						Variable NewState=s.keycode-48
						Variable StartX=V_left
						Variable EndX=V_right
						Variable StartF=V_bottom
						Variable EndF=V_top
						Wave/T RNAViewer_SettingsStr=root:RNAViewer:Settings:RNAViewer_SettingsStr
						Wave StateWave=$RNAViewer_SettingsStr[%ColorWave]
						StrSwitch(S_marqueeWin)
							case "RNAAnalysis_RorS_FvsS": 
								SetStateByXFRange(StateWave,NewState,StartX,EndX,StartF,EndF)
							break
							case "RNAAnalysis_RorS_F":
								SetStateBytFRange(StateWave,NewState,StartX,EndX,StartF,EndF)
							break
						EndSwitch
							
					EndIf
					hookResult=1
			endswitch // s.keycode

		break // number codes
		case 22:					// Mouse Wheel
				Wave RNAViewerSettings=root:RNAViewer:Settings:RNAViewer_Settings
				RNAViewerSettings[%SubIndex]+=s.wheelDy
				DoAction("SubIndex")
				hookResult = 1
		break // mouse wheel

	EndSwitch // event codes
	Return hookResult
End

Static Function SplitRamp()
	
	Wave Force=root:RNAViewer:ForceRorS_smth
	Wave Extension=root:RNAViewer:SepRorS_smth
	Wave RawForce=root:RNAViewer:ForceRorS
	Wave RawExtension=root:RNAViewer:SepRorS
	Wave Settings=root:RNAViewer:Settings
	Wave ForceTOS=root:RNAViewer:SelectedForce_Ret 
	Wave ExtensionTOS=root:RNAViewer:SelectedSep_Ret
	
	Variable NumPts=DimSize(Force,0)
	Variable RawNumPts=DimSize(RawForce,0)
	
	String ForceName="root:RNAViewer:ForceRorS_smth"
	String ExtensionName="root:RNAViewer:SepRorS_smth"
	
	Duplicate/O/R=[0,Floor(NumPts/2)] Force, $ForceName+"_Ext"
	Wave ForceExt= $ForceName+"_Ext"
	Duplicate/O/R=[Floor(NumPts/2)+1,NumPts] Force, $ForceName+"_Ret"
	Wave ForceRet= $ForceName+"_Ret"
	Duplicate/O/R=[0,Floor(NumPts/2)] Extension, $ExtensionName+"_Ext"
	Wave ExtensionExt= $ExtensionName+"_Ext"
	Duplicate/O/R=[Floor(NumPts/2)+1,NumPts] Extension, $ExtensionName+"_Ret"
	Wave ExtensionRet= $ExtensionName+"_Ret"
	
	ForceName="root:RNAViewer:ForceRorS"
	ExtensionName="root:RNAViewer:SepRorS"

	Duplicate/O/R=[0,Floor(RawNumPts/2)] RawForce, $ForceName+"_Ext"
	Wave ForceRawExt= $ForceName+"_Ext"
	Duplicate/O/R=[0,Floor(RawNumPts/2)] RawExtension, $ExtensionName+"_Ext"
	Wave ExtensionRawExt= $ExtensionName+"_Ext"
	Duplicate/O/R=[Floor(RawNumPts/2)+1,RawNumPts] RawForce, $ForceName+"_Ret"
	Wave ForceRawRet= $ForceName+"_Ret"
	Duplicate/O/R=[Floor(RawNumPts/2)+1,RawNumPts] RawExtension, $ExtensionName+"_Ret"
	Wave ExtensionRawRet= $ExtensionName+"_Ret"

End

// Get an individual ramp or step from the RNA Pulling data
Static Function GetIndividualRoS(MasterIndex,RSIndex,DefV,ZSensor,ZSetPoint,RNAPullingSettings,RNAPullingSettingsStr,[DefVName,ZSensorName])
	Variable MasterIndex,RSIndex
	Wave DefV,ZSensor,RNAPullingSettings,ZSetPoint
	Wave/T RNAPullingSettingsStr
	String DefVName,ZSensorName
	
	If(ParamIsDefault(DefVName))
		DefVName="root:RNAViewer:DefVRorS"
	EndIf

	If(ParamIsDefault(ZSensorName))
		ZSensorName="root:RNAViewer:ZSensorRorS"
	EndIf
	
	Variable StartIndex,EndIndex=0
	StrSwitch(RNAPullingSettingsStr[%CurrentMode])
		case "LocalRamp":
			Variable TotalTime=deltax(ZSetPoint)*DimSize(ZSetPoint,0)
			Variable TimePerRamp=TotalTime/NumStepsOrRamps(RNAPullingSettings,RNAPullingSettingsStr)
			StartIndex=RSIndex*TimePerRamp
			EndIndex=(RSIndex+1)*TimePerRamp
		break
		case "Steps":
			StartIndex=GetStepStartTime(RNAPullingSettings,RSIndex)
			EndIndex=StartIndex+RNAPullingSettings[%TimePerStep]
			
		break
	EndSwitch
	Duplicate/O/R=(StartIndex,EndIndex) DefV, $DefVName
	Duplicate/O/R=(StartIndex,EndIndex) ZSensor, $ZSensorName	
End

Static Function AllRNADisplays([TargetDF])
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAViewer:"
	EndIf

	DisplayRNAPull("ForceVsSep",TargetDF=TargetDF)
	DisplayRNAPull("ForceVsSep_RorS",TargetDF=TargetDF)
	DisplayRNAPull("ForceRorS",TargetDF=TargetDF)
	DisplayRNAPull("RorSForce",TargetDF=TargetDF)
	DisplayRNAPull("SplitRamp",TargetDF=TargetDF)
End


Static Function DisplayRNAPull(DisplayType,[TargetDF])
	
	String DisplayType,TargetDF
	
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAViewer:"
	EndIf
	
	Wave DefV=$TargetDF+"DefV"
	Wave ZSensor=$TargetDF+"ZSensor"
	Wave SelectedForce_Ret=$TargetDF+"SelectedForce_Ret"
	Wave SelectedSep_Ret=$TargetDF+"SelectedSep_Ret"
	Wave RorSForce=$TargetDF+"RorSForce"
	Wave RorSSep=$TargetDF+"RorSSep"
	Wave RorSForce_smth=$TargetDF+"RorSForce_smth"
	Wave RorSSep_smth=$TargetDF+"RorSSep_smth"
	Wave ForceRorS=$TargetDF+"ForceRorS"
	Wave SepRorS=$TargetDF+"SepRorS"
	Wave ForceRorS_smth=$TargetDF+"ForceRorS_smth"
	Wave SepRorS_smth=$TargetDF+"SepRorS_smth"

	StrSwitch(DisplayType)
		case "ForceVsSep":
			DoWindow/F RNAAnalysis_ForceVsSep
			If(V_flag==0)
				Display/K=1/N=RNAAnalysis_ForceVsSep RorSForce vs RorSSep
				AppendToGraph SelectedForce_Ret vs SelectedSep_Ret
				ModifyGraph rgb(RorSForce)=(48896,59904,65280)
				AppendToGraph/C=(0,15872,65280)  RorSForce_smth vs RorSSep_smth
				
				Label left "Force (pN)"
				Label bottom "Extension (nm)"		
			EndIf
		break
		case "ForceVsSep_RorS":
			DoWindow/F RNAAnalysis_RorS_FvsS
			If(V_flag==0)
				Display/K=1/N=RNAAnalysis_RorS_FvsS ForceRorS vs  SepRorS
				ModifyGraph rgb(ForceRorS)=(48896,59904,65280)
				AppendToGraph/C=(0,15872,65280)  ForceRorS_smth vs SepRorS_smth
				
				Label left "Force (pN)"
				Label bottom "Extension (nm)"
				ModifyGraph tickUnit=1
			EndIf
		break
		case "ForceRorS":
			DoWindow/F RNAAnalysis_RorS_F
			If(V_flag==0)
				Display/K=1/N=RNAAnalysis_RorS_F ForceRorS
				AppendToGraph/C=(0,15872,65280)  ForceRorS_smth
				ModifyGraph rgb(ForceRorS)=(48896,59904,65280)

				Label left "Force (pN)"
				ModifyGraph tickUnit=1
			EndIf
		break
		case "RorSForce":
			DoWindow/F RNAAnalysis_RorSForce
			If(V_flag==0)
				Display/K=1/N=RNAAnalysis_RorSForce  RorSForce
				AppendToGraph/C=(0,15872,65280)  RorSForce_smth
				ModifyGraph rgb(RorSForce)=(48896,59904,65280)

				Label left "Force (pN)"
				ModifyGraph tickUnit=1
			EndIf
		break
		case "SplitRamp":
			String ForceName="root:RNAViewer:ForceRorS_smth"
			String ExtensionName="root:RNAViewer:SepRorS_smth"
			
			Wave ForceExt= $ForceName+"_Ext"
			Wave ForceRet= $ForceName+"_Ret"
			Wave ExtensionExt= $ExtensionName+"_Ext"
			Wave ExtensionRet= $ExtensionName+"_Ret"
			
			ForceName="root:RNAViewer:ForceRorS"
			ExtensionName="root:RNAViewer:SepRorS"
		
			Wave ForceRawExt= $ForceName+"_Ext"
			Wave ExtensionRawExt= $ExtensionName+"_Ext"
			Wave ForceRawRet= $ForceName+"_Ret"
			Wave ExtensionRawRet= $ExtensionName+"_Ret"
			Wave ForceTOS=root:RNAViewer:SelectedForce_Ret 
			Wave ExtensionTOS=root:RNAViewer:SelectedSep_Ret
			
			Duplicate/O ForceTOS, $ForceName+"_TOS"
			Wave ForceTOS= $ForceName+"_TOS"
			Duplicate/O ExtensionTOS, $ExtensionName+"_TOS"
			Wave ExtensionROS= $ExtensionName+"_TOS"
			Variable DoWeHaveTheWaves=WaveExists(ForceRawExt)
			DoWindow/F RNAViewer_SplitRamp

			If(V_flag==0)
				Display/K=1/N=RNAViewer_SplitRamp ForceRawExt vs ExtensionRawExt
				AppendToGraph ForceRawRet vs ExtensionRawRet
				AppendToGraph ForceExt vs ExtensionExt
				AppendToGraph ForceRet vs ExtensionRet
				AppendToGraph ForceTOS vs ExtensionROS
				ModifyGraph rgb($NameOfWave(ForceRawExt))=(48896,59904,65280)
				ModifyGraph rgb($NameOfWave(ForceRawRet))=(55000,65280,55000)
				ModifyGraph rgb($NameOfWave(ForceExt))=(0,15872,65280)
				ModifyGraph rgb($NameOfWave(ForceRet))=(0,37000,0)
				ModifyGraph muloffset={1000000000,1000000000000}
			EndIf
		break
	EndSwitch

End

Function ConcatenateAllSplitRamps()
	SetDataFolder root:RNAViewer
	Wave RNAViewer_Settings=root:RNAViewer:Settings:RNAViewer_Settings
	Variable Counter=0
	Variable NumRamps=RNAViewer_Settings[%NumSteps]
	Make/O/N=0 Unfold_Force,Unfold_Sep,Refold_Force,Refold_Sep
	Wave ForceRorS_smth_Ext
	Wave ForceRorS_smth_Ret
	Wave SepRorS_smth_Ext
	Wave SepRorS_smth_Ret
	For(Counter=0;Counter<NumRamps;Counter+=1)
		RNAViewer_Settings[%SubIndex]=Counter
		DoAction("SubIndex")
		Duplicate/O Unfold_Force, Unfold_F_Temp
		Duplicate/O Unfold_Sep, Unfold_S_Temp
		Duplicate/O Refold_Force, Refold_F_Temp
		Duplicate/O Refold_Sep, Refold_s_Temp
		Concatenate/O/NP {Unfold_F_Temp,ForceRorS_smth_Ext}, Unfold_Force
		Concatenate/O/NP {Unfold_S_Temp,SepRorS_smth_Ext}, Unfold_Sep
		Concatenate/O/NP {Refold_F_Temp,ForceRorS_smth_Ret}, Refold_Force
		Concatenate/O/NP {Refold_s_Temp,SepRorS_smth_Ret}, Refold_Sep
	EndFor
	String ExperimentSettingsNote=Note(ForceRorS_smth_Ext)
	Note Unfold_Force, ExperimentSettingsNote
	Note Unfold_Sep, ExperimentSettingsNote
	Note Refold_Force, ExperimentSettingsNote
	Note Refold_Sep, ExperimentSettingsNote
End

Static Function DoAction(Action)
	String Action
	Wave RNAViewer_Settings=root:RNAViewer:Settings:RNAViewer_Settings
	Wave/T RNAViewer_SettingsStr=root:RNAViewer:Settings:RNAViewer_SettingsStr
	Wave FilterSettings=root:RNAViewer:Settings:FilterSettings
	Wave Settings=root:RNAViewer:Settings
	Wave/T SettingsStr=root:RNAViewer:SettingsStr
	Wave ZSetPoint=root:RNAViewer:ZSetPoint
	
	
	SetDataFolder root:RNAViewer
	StrSwitch(Action)
		case "MasterIndex":
		RNAViewer_Settings[%ColorByWave]=0

		RNAViewer_Settings[%BoxCarAverage]=FilterSettings[RNAViewer_Settings[%MasterIndex]][0]
		RNAViewer_Settings[%Decimation]=FilterSettings[RNAViewer_Settings[%MasterIndex]][1]
	
		RNAViewer_Settings[%SubIndex]=0
		LoadMasterIndex(RNAViewer_Settings[%MasterIndex])
	 	RNAViewer_Settings[%NumSteps]=NumStepsOrRamps(Settings,SettingsStr)
		LoadRorS(RNAViewer_Settings[%MasterIndex],RNAViewer_Settings[%SubIndex])	
		StrSwitch(SettingsStr[%CurrentMode])
			case "LocalRamp":
				SplitRamp()
			break
			case "Steps":
			break
		EndSwitch

		AllRNADisplays()	
		NormalColorDisplays()
	
		MakeStartEndIndexRorS(RNAViewer_Settings[%MasterIndex],ZSetPoint,Settings,SettingsStr)		
		
	break
	case "SubIndex":
		LoadRorS(RNAViewer_Settings[%MasterIndex],RNAViewer_Settings[%SubIndex])
		If(RNAViewer_Settings[%ColorByWave])
			Wave ColorWave=$RNAViewer_SettingsStr[%ColorWave]
			ColorDisplaysByWave(ColorWave)
		EndIf
		
		StrSwitch(SettingsStr[%CurrentMode])
			case "LocalRamp":
				SplitRamp()
			break
			case "Steps":
			break
		EndSwitch
		
	break
	case "BoxCarAverage":
		FilterSettings[RNAViewer_Settings[%MasterIndex]][0]=RNAViewer_Settings[%BoxCarAverage]
	break
	case "Decimation":
		FilterSettings[RNAViewer_Settings[%MasterIndex]][1]=RNAViewer_Settings[%Decimation]
	break
	case "ApplyFilterButton":
		MakeSmoothedRorS(RNAViewer_Settings[%MasterIndex])
		LoadRorS(RNAViewer_Settings[%MasterIndex],RNAViewer_Settings[%SubIndex])
	break
	case "EditRorSStates":
		
	break

EndSwitch

	
End


Window RNAViewerPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1636,68,1840,382) as "Local Ramp and Step Viewer"
	SetDrawLayer UserBack
	DrawLine 4,151,190,151
	DrawLine 4,45,190,45
	DrawText 4,64,"Pull Info"
	DrawText 4,169,"Filtering"
	DrawLine 5,256,191,256
	SetVariable MasterIndex,pos={4,2},size={131,16},proc=RNAViewerApp#SetVarProc,title="Master Index"
	SetVariable MasterIndex,limits={0,inf,1},value= root:RNAViewer:Settings:RNAViewer_Settings[%MasterIndex]
	SetVariable SubIndex,pos={4,21},size={131,16},proc=RNAViewerApp#SetVarProc,title="Ramp/Step Index"
	SetVariable SubIndex,limits={0,inf,1},value= root:RNAViewer:Settings:RNAViewer_Settings[%SubIndex]
	SetVariable ExperimentType,pos={4,65},size={160,16},title="Experiment Type"
	SetVariable ExperimentType,value= root:RNAViewer:SettingsStr[%CurrentMode]
	SetVariable SubIndex1,pos={4,107},size={149,16},proc=RNAViewerApp#SetVarProc,title="Number of Ramp/Step"
	SetVariable SubIndex1,limits={-inf,inf,0},value= root:RNAViewer:Settings:RNAViewer_Settings[%NumSteps],noedit= 1
	SetVariable NearestForcePull,pos={4,86},size={175,16},title="Nearest Force Pull"
	SetVariable NearestForcePull,value= root:RNAViewer:SettingsStr[%NearestForcePull]
	SetVariable BoxCarAverage,pos={4,180},size={132,16},proc=RNAViewerApp#SetVarProc,title="Box Car Average"
	SetVariable BoxCarAverage,value= root:RNAViewer:Settings:RNAViewer_Settings[%BoxCarAverage]
	SetVariable Decimation,pos={4,202},size={131,16},proc=RNAViewerApp#SetVarProc,title="Decimation"
	SetVariable Decimation,value= root:RNAViewer:Settings:RNAViewer_Settings[%Decimation]
	Button ApplyFilterButton,pos={4,225},size={131,20},proc=RNAViewerApp#ButtonProc,title="Apply Filter"
	Button ApplyFilterButton,fColor=(61440,61440,61440)
	SetVariable PullingVelocitySV,pos={4,130},size={149,16},proc=RNAViewerApp#SetVarProc,title="Pulling Velocity"
	SetVariable PullingVelocitySV,format="%.2W1Pm/s"
	SetVariable PullingVelocitySV,limits={-inf,inf,0},value= root:RNAViewer:Settings[%RetractVelocity],noedit= 1
	CheckBox ColorbyWave,pos={8,265},size={95,14},proc=RNAViewerApp#CheckProc,title="Color By Wave?"
	CheckBox ColorbyWave,value= 0
	SetVariable ColorWave,pos={10,291},size={160,16},title="Color Wave"
	SetVariable ColorWave,value= root:RNAViewer:Settings:RNAViewer_SettingsStr[%ColorWave]
EndMacro


Static Function SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String ControlName=sva.ctrlName
			DoAction(ControlName)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
	
Static Function ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ControlName=ba.ctrlname

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			DoAction(ControlName)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Static Function CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	Wave Settings=root:RNAViewer:Settings:RNAViewer_Settings
	Wave/T SettingsStr=root:RNAViewer:Settings:RNAViewer_SettingsStr
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			Settings[%ColorByWave]=checked
			If(checked)
				Wave ColorWave=$SettingsStr[%ColorWave]
				ColorDisplaysByWave(ColorWave)

			Else
				NormalColorDisplays()
				SetWindow RNAAnalysis_RorS_FvsS hook(ChangeStateHook)=$""
				SetWindow RNAAnalysis_RorS_F hook(ChangeStateHook)=$""

			EndIf
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
