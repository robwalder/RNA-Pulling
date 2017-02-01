#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include ":ChopRNAPulls"
#include "::Force-Ramp-Utilities:BoxCarAveraging"
#include "::Force-Ramp-Utilities:SelectFR"
#include "::AR-Data:MeasurementTimeline"



Function InitRNAAnalysis()
	// Make new data folders 
	NewDataFolder/O root:RNAPulling:Analysis
	NewDataFolder/O root:RNAPulling:Analysis:RampAnalysis
	
	
	// Set RNAAnalysis Parms Path
	String PathIn=FunctionPath("")
	NewPath/Q/O RNAAnalysisParms ParseFilePath(1, PathIn, ":", 1, 0) +"Parms"
	
	// Load Settings Wave
	SetDataFolder root:RNAPulling:Analysis
	LoadWave/H/Q/O/P=RNAAnalysisParms "AnalysisSettings.ibw"	
	SetDataFolder root:RNAPulling:Analysis:RampAnalysis
	LoadWave/H/Q/O/P=RNAAnalysisParms "RampFitSettings.ibw"	
	LoadWave/H/Q/O/P=RNAAnalysisParms "RampAnalysisSettings.ibw"	

	// Adjust Analysis Settings Wave
	Wave AnalysisSettings=root:RNAPulling:Analysis:AnalysisSettings
	AnalysisSettings=1
	Wave LastRNAPullSettings=root:RNAPulling:RNAPullingSettings
	AnalysisSettings[%NumRNAPulls]=LastRNAPullSettings[%Iteration]
	
	// Make filtering settings wave
	Make/O/N=(AnalysisSettings[%NumRNAPulls],2) root:RNAPulling:Analysis:RSFilterSettings
	Wave RSFilterSettings=root:RNAPulling:Analysis:RSFilterSettings
	RSFilterSettings=1
	SetDimLabel 1,0, BoxCarNum, RSFilterSettings
 	SetDimLabel 1,1, Decimation, RSFilterSettings
	// Make filtering settings wave
	Make/O/N=(AnalysisSettings[%NumRNAPulls]) root:RNAPulling:Analysis:RSForceOffset,root:RNAPulling:Analysis:RSSepOffset
	InitRNAPullingOffsets()
	// Determine the number of times the rna pulling program ran
	Wave Settings=root:RNAPulling:Analysis:Settings
	Wave/T SettingsStr=root:RNAPulling:Analysis:SettingsStr
 	AnalysisSettings[%NumSteps]=NumStepsOrRamps(Settings,SettingsStr)
	// Load waves for first time RNA Pulling program ran
	LoadAllWavesForIndex(0)
	
	// Load the first ramp/step on the for the first time the RNA pulling program ran
	LoadRorS(0,0)
	
	// Make Unfold and Refold Ramp Settings Waves
	Wave RampFitSettings=root:RNAPulling:Analysis:RampAnalysis:RampFitSettings
	SetDataFolder root:RNAPulling:Analysis:RampAnalysis
	Duplicate/O RampFitSettings, UnfoldRFFitSettings, RefoldRFFitSettings

End

Function InitRNAPullingOffsets()
	Wave RSForceOffset=root:RNAPulling:Analysis:RSForceOffset
	Wave RSSepOffset=root:RNAPulling:Analysis:RSSepOffset	
		
	Variable NumRS=DimSize(RSForceOffset,0)
	Variable RSCounter=0
	For(RSCounter=0;RSCounter<NumRS;RSCounter+=1)
		If(WaveExists($"root:FRU:preprocessing:Offsets"))
			Wave/T SettingsStr=$"root:RNAPulling:SavedData:SettingsStr"+num2str(RSCounter)
			String FRName=SettingsStr[%NearestForcePull]
			Wave FRUOffsets=root:FRU:preprocessing:Offsets
			RSForceOffset[RSCounter]=FRUOffsets[%$FRName][%Offset_Force]
			RSSepOffset[RSCounter]=FRUOffsets[%$FRName][%Offset_Sep]
		EndIf
	EndFor
End

// Use this function on handle (also known as bridge) constructs to estimate the psf as a function of force
Function EstimatePSFCurrentMI(MasterIndex,StartStep,EndStep,[RNAAnalysisDF])
	Variable MasterIndex,StartStep,EndStep
	String RNAAnalysisDF
	
	If(ParamIsDefault(RNAAnalysisDF))
		RNAAnalysisDF="root:RNAPulling:Analysis:"
	EndIf
	
	Wave ForceWave_smth=$RNAAnalysisDF+"ForceRorS_Smth"
	Variable NumSteps=EndStep-StartStep
	Make/O/N=(NumSteps) $RNAAnalysisDF+"PSF_Force",$RNAAnalysisDF+"PSF_Width"
	Wave PSF_Force=$RNAAnalysisDF+"PSF_Force"
	Wave PSF_Width=$RNAAnalysisDF+"PSF_Width"
	Variable StepCounter=StartStep
	For(StepCounter=StartStep;StepCounter<EndStep+1;StepCounter+=1)
		LoadRorS(MasterIndex,StepCounter)
		WaveStats/Q ForceWave_smth
		Variable Counter=StepCounter-StartStep
		PSF_Force[Counter]=V_avg
		PSF_Width[Counter]=V_sdev
	EndFor
	Display PSF_Width vs PSF_Force
      CurveFit/M=2/W=0 line, PSF_Width/X=PSF_Force/D	
End

Function UpdateNFPFromTimeline()
	 InitRNAPullingOffsets()
	 Wave RSForceOffset=root:RNAPulling:Analysis:RSForceOffset
	Wave RSSepOffset=root:RNAPulling:Analysis:RSSepOffset	
		
	Variable NumRS=DimSize(RSForceOffset,0)
	Variable RSCounter=0
	
	For(RSCounter=0;RSCounter<NumRS;RSCounter+=1)
		String Name="RNAPulling"+num2str(RSCounter)
		String NFP=NearestARForceRamp(Name)
		Wave/T SettingsStr=$"root:RNAPulling:SavedData:SettingsStr"+num2str(RSCounter)
		SettingsStr[%NearestForcePull]=NFP
		Wave FRUOffsets=root:FRU:preprocessing:Offsets
		UpdateRNAPullingOffsets(RSCounter,FRUOffsets[%$NFP][%Offset_Force],FRUOffsets[%$NFP][%Offset_Sep])
	EndFor

End

Function UpdateRNAPullingOffsets(MasterIndex,NewForceOffset,NewSepOffset,[RampDF])
	Variable MasterIndex,NewForceOffset,NewSepOffset
	String RampDF
	If(ParamIsDefault(RampDF))
		RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf

	Wave RSForceOffset=root:RNAPulling:Analysis:RSForceOffset
	Wave RSSepOffset=root:RNAPulling:Analysis:RSSepOffset	
	
	If(!(NewForceOffset==RSForceOffset[MasterIndex]))
		// Adjust Ramp fits and rupture forces if we have them.
		If(RFAnalysisQ(MasterIndex))
			Variable ForceDiff=+NewForceOffset-RSForceOffset[MasterIndex]
			// First update y-intercept for fits
			Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
			Wave RefoldSettings=$RampDF+"RefoldRFFitSettings_"+num2str(MasterIndex)
			Variable NumRamps=DimSize(UnfoldSettings,1)
			Variable RampCounter=0
			For(RampCounter=0;RampCounter<NumRamps;RampCounter+=1)
				UnfoldSettings[%Fit1YIntercept][RampCounter]+=ForceDiff
				UnfoldSettings[%Fit2YIntercept][RampCounter]+=ForceDiff
				RefoldSettings[%Fit1YIntercept][RampCounter]+=ForceDiff
				RefoldSettings[%Fit2YIntercept][RampCounter]+=ForceDiff
			EndFor
			// Now update the rupture forces
			Wave UnfoldRF=$RampDF+"UnfoldRF_"+num2str(MasterIndex)
			Wave RefoldRF=$RampDF+"RefoldRF_"+num2str(MasterIndex)
			UnfoldRF+=ForceDiff
			RefoldRF+=ForceDiff

		EndIf
		RSForceOffset[MasterIndex]=NewForceOffset

	EndIf
	If(NewSepOffset!=RSSepOffset[MasterIndex])
		RSSepOffset[MasterIndex]=NewSepOffset
	EndIf
End
// Init a rupture force analysis for a given master index
Function InitRFAnalysis(MasterIndex,[LoadWaves,RNAAnalysisDF,RampDF])
	Variable MasterIndex,LoadWaves
	String RNAAnalysisDF,RampDF
	
	If(ParamIsDefault(LoadWaves))
		LoadWaves=0
	EndIf
	If(ParamIsDefault(RNAAnalysisDF))
		RNAAnalysisDF="root:RNAPulling:Analysis:"
	EndIf
	If(ParamIsDefault(RampDF))
		RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf
	
	If(LoadWaves)
		LoadAllWavesForIndex(MasterIndex)
	EndIf
	
	// Initial guesses on ramp analysis for this master index
	// Get Wave Paths
	Wave UnfoldRFFitSettings=$RampDF+"UnfoldRFFitSettings"
	String UnfoldSettingsName=RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
	String RefoldSettingsName=RampDF+"RefoldRFFitSettings_"+num2str(MasterIndex)
	Duplicate/O UnfoldRFFitSettings,$UnfoldSettingsName,$RefoldSettingsName
	Wave UnfoldSettings=$UnfoldSettingsName
	Wave RefoldSettings=$RefoldSettingsName
	// How many ramps for this master index
	Wave Settings=$RNAAnalysisDF+"Settings"
	Wave/T SettingsStr=$RNAAnalysisDF+"SettingsStr"
 	Variable NumRamps=NumStepsOrRamps(Settings,SettingsStr)
	// Resize the settings wave for the master index with the number of ramps
	Redimension/N=(-1,NumRamps) UnfoldSettings 	
	Redimension/N=(-1,NumRamps) RefoldSettings 	
	
	// Do first pass at rupture force analysis for unfolding and refolding
	// Guess the RF fits settings for all ramps in this master index
	GuessRFFitSettingsMI(MasterIndex)
	// Estimate RF for all unfold and refold events in this master index
	MeasureRFByMI(MasterIndex,"BothRuptures")
End

Function RFAnalysisQ(MasterIndex,[RampDF])

	Variable MasterIndex
	String RampDF
	
	If(ParamIsDefault(RampDF))
		RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf
	
	String RampAnalysisName=RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
	Return WaveExists($RampAnalysisName)
End

// Show the ramp analysis for a given ramp
Function DisplayRampAnalysis(MasterIndex,RampIndex,[LoadWaves,RNAAnalysisDF,RampDF,LoadFitSettings])

	Variable MasterIndex,RampIndex,LoadWaves,LoadFitSettings
	String RNAAnalysisDF,RampDF
	
	If(ParamIsDefault(LoadWaves))
		LoadWaves=0
	EndIf
	If(ParamIsDefault(RNAAnalysisDF))
		RNAAnalysisDF="root:RNAPulling:Analysis:"
	EndIf
	If(ParamIsDefault(RampDF))
		RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf
	If(ParamIsDefault(LoadFitSettings))
		LoadFitSettings=1
	EndIf
	If(LoadWaves)
		LoadAllWavesForIndex(MasterIndex)
	 	LoadRorS(MasterIndex,RampIndex)
	EndIf

	Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
	Wave RefoldSettings=$RampDF+"RefoldRFFitSettings_"+num2str(MasterIndex)
	Wave UnfoldRFFitSettings=$RampDF+"UnfoldRFFitSettings"
	Wave RefoldRFFitSettings=$RampDF+"RefoldRFFitSettings"
	Wave ForceRorS=$RNAAnalysisDF+"ForceRorS"
	Wave ForceRorS_Smth=$RNAAnalysisDF+"ForceRorS_Smth"
	If(LoadFitSettings)
		UnfoldRFFitSettings=UnfoldSettings[p][RampIndex] 
		RefoldRFFitSettings=RefoldSettings[p][RampIndex] 
	 	
	EndIf
	
	Duplicate/O/R=(UnfoldRFFitSettings[%Fit1StartTime],UnfoldRFFitSettings[%Fit2EndTime]) ForceRorS_Smth $RampDF+"UnfoldFit1"
	Duplicate/O/R=(UnfoldRFFitSettings[%Fit1StartTime],UnfoldRFFitSettings[%Fit2EndTime]) ForceRorS_Smth $RampDF+"UnfoldFit2"
	Duplicate/O/R=(RefoldRFFitSettings[%Fit1StartTime],RefoldRFFitSettings[%Fit2EndTime]) ForceRorS_Smth $RampDF+"RefoldFit1"
	Duplicate/O/R=(RefoldRFFitSettings[%Fit1StartTime],RefoldRFFitSettings[%Fit2EndTime]) ForceRorS_Smth $RampDF+"RefoldFit2"
	Wave UnfoldFit1=$RampDF+"UnfoldFit1"
	Wave UnfoldFit2=$RampDF+"UnfoldFit2"
	Wave RefoldFit1=$RampDF+"RefoldFit1"
	Wave RefoldFit2=$RampDF+"RefoldFit2"
	UnfoldFit1=UnfoldRFFitSettings[%Fit1LR]*x+UnfoldRFFitSettings[%Fit1YIntercept]
	UnfoldFit2=UnfoldRFFitSettings[%Fit2LR]*x+UnfoldRFFitSettings[%Fit2YIntercept]
	RefoldFit1=RefoldRFFitSettings[%Fit1LR]*x+RefoldRFFitSettings[%Fit1YIntercept]
	RefoldFit2=RefoldRFFitSettings[%Fit2LR]*x+RefoldRFFitSettings[%Fit2YIntercept]
	WaveStats/Q ForceRorS
	Variable MaxForce=V_max
	Variable MinForce=V_min
	
	SetDataFolder $RampDF
	Make/O/N=2 UnfoldFit1Start,UnfoldFit1End,UnfoldFit2Start,UnfoldFit2End,RefoldFit1Start,RefoldFit1End,RefoldFit2Start,RefoldFit2End,ForceMinMax,RF,RFTime
	ForceMinMax={MaxForce,MinForce}
	UnfoldFit1Start=UnfoldRFFitSettings[%Fit1StartTime]
	UnfoldFit1End=UnfoldRFFitSettings[%Fit1EndTime]
	UnfoldFit2Start=UnfoldRFFitSettings[%Fit2StartTime]
	UnfoldFit2End=UnfoldRFFitSettings[%Fit2EndTime]
	RefoldFit1Start=RefoldRFFitSettings[%Fit1StartTime]
	RefoldFit1End=RefoldRFFitSettings[%Fit1EndTime]
	RefoldFit2Start=RefoldRFFitSettings[%Fit2StartTime]
	RefoldFit2End=RefoldRFFitSettings[%Fit2EndTime]
	
	Wave UnfoldRFMI=$RampDF+"UnfoldRF_"+num2str(MasterIndex)
	Wave UnfoldRFTimeMI=$RampDF+"UnfoldRFTime_"+num2str(MasterIndex)
	Wave RefoldRFMI=$RampDF+"RefoldRF_"+num2str(MasterIndex)
	Wave RefoldRFTimeMI=$RampDF+"RefoldRFTime_"+num2str(MasterIndex)
	
	RF={UnfoldRFMI[RampIndex],RefoldRFMI[RampIndex]}
	RFTime={UnfoldRFTimeMI[RampIndex],RefoldRFTimeMI[RampIndex]}
	DoWindow/F RNARampAnalysis
	If(V_flag==0)
		Display/K=1/N=RNARampAnalysis ForceRorS
		AppendToGraph/C=(0,15872,65280)  ForceRorS_smth
		ModifyGraph rgb(ForceRorS)=(48896,59904,65280)
		AppendToGraph/C=(0,0,0)  UnfoldFit1
		AppendToGraph/C=(0,0,0)  UnfoldFit2
		AppendToGraph/C=(0,0,0)  RefoldFit1
		AppendToGraph/C=(0,0,0)  RefoldFit2
		AppendToGraph/C=(0,0,0)  ForceMinMax vs UnfoldFit1Start
		AppendToGraph/C=(0,0,0)  ForceMinMax vs UnfoldFit1End
		AppendToGraph/C=(0,0,0)  ForceMinMax vs UnfoldFit2Start
		AppendToGraph/C=(0,0,0)  ForceMinMax vs UnfoldFit2End
		AppendToGraph/C=(0,0,0)  ForceMinMax vs RefoldFit1Start
		AppendToGraph/C=(0,0,0)  ForceMinMax vs RefoldFit1End
		AppendToGraph/C=(0,0,0)  ForceMinMax vs RefoldFit2Start
		AppendToGraph/C=(0,0,0)  ForceMinMax vs RefoldFit2End
		
		AppendToGraph/C=(65000,0,0)  RF vs RFTime
		ModifyGraph mode(RF)=3,marker(RF)=42
		Label left "Force (pN)"
		ModifyGraph tickUnit=1
		SetWindow RNARampAnalysis hook(RNADisplayHook)=RNADisplayHookFunction
	EndIf

End

Function RNADisplayHookFunction(s)
	STRUCT WMWinHookStruct &s
	
	Variable hookResult = 0	// 0 if we do not handle event, 1 if we handle it.
	Wave AnalysisSettings=root:RNAPulling:Analysis:AnalysisSettings
	String RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	String RNAAnalysisDF="root:RNAPulling:Analysis:"
	Wave UnfoldRFFitSettings=$RampDF+"UnfoldRFFitSettings"
	Wave RefoldRFFitSettings=$RampDF+"RefoldRFFitSettings"
	Wave RF=$RampDF+"RF"
	Wave RFTime=$RampDF+"RFTime"
	If(RFAnalysisQ(AnalysisSettings[%MasterIndex]))
		Wave UnfoldRFMI=$RampDF+"UnfoldRF_"+num2str(AnalysisSettings[%MasterIndex])
		Wave UnfoldRFTimeMI=$RampDF+"UnfoldRFTime_"+num2str(AnalysisSettings[%MasterIndex])
		Wave RefoldRFMI=$RampDF+"RefoldRF_"+num2str(AnalysisSettings[%MasterIndex])
		Wave RefoldRFTimeMI=$RampDF+"RefoldRFTime_"+num2str(AnalysisSettings[%MasterIndex])
		Wave RampAnalysisSettings=$RampDF+"RampAnalysisSettings"
		Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(AnalysisSettings[%MasterIndex])
		Wave RefoldSettings=$RampDF+"RefoldRFFitSettings_"+num2str(AnalysisSettings[%MasterIndex])
	EndIf
	Wave ForceRorS=$RNAAnalysisDF+"ForceRorS"
	Wave ForceRorS_Smth=$RNAAnalysisDF+"ForceRorS_Smth"
	Wave Settings=$RNAAnalysisDF+"Settings"
	
	Variable LeftClick=(s.eventmod & 2^0)!=0
	Variable RightClick=(s.eventmod & 2^4)!=0
	Variable ControlButton=(s.eventmod & 2^3)!=0
	Variable ShiftButton=(s.eventmod & 2^1)!=0
	Variable MouseTime=AxisValFromPixel("RNARampAnalysis","bottom",s.mouseloc.h)
	Variable MouseForce=AxisValFromPixel("RNARampAnalysis","left",s.mouseloc.v)

	switch(s.eventCode)
		case 3:	// Mouse down event
			
			If(LeftClick&&ControlButton)
				Variable NewUnfoldRF=MouseTime*UnfoldRFFitSettings[%Fit1LR]+UnfoldRFFitSettings[%Fit1YIntercept]
				RF[0]=NewUnfoldRF
				RFTime[0]=MouseTime
				UnfoldRFMI[AnalysisSettings[%SubIndex]]=NewUnfoldRF
				UnfoldRFTimeMI[AnalysisSettings[%SubIndex]]=MouseTime
				hookResult=1
			EndIf
			If(RightClick&&ControlButton)
				Variable NewRefoldRF=MouseTime*RefoldRFFitSettings[%Fit1LR]+RefoldRFFitSettings[%Fit1YIntercept]
				RF[1]=NewRefoldRF
				RFTime[1]=MouseTime
				RefoldRFMI[AnalysisSettings[%SubIndex]]=NewRefoldRF
				RefoldRFTimeMI[AnalysisSettings[%SubIndex]]=MouseTime
				hookResult=1
			EndIf
		break				
		case 11:					// Keyboard event
			switch (s.keycode)
				case 28: // Left Arrow
					AnalysisSettings[%SubIndex]-=1
					If(AnalysisSettings[%SubIndex]<0)
						AnalysisSettings[%SubIndex]=0
					EndIf
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
					DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
					hookResult = 1				
					break
				case 29: // Right Arrow
					AnalysisSettings[%SubIndex]+=1
					If(AnalysisSettings[%SubIndex]>=AnalysisSettings[%NumSteps])
						AnalysisSettings[%SubIndex]=AnalysisSettings[%NumSteps]-1
					EndIf
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
					DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
					hookResult = 1
					break
				case 30: // Up Arrow
					hookResult = 1
					break
				case 31:  // Down Arrow
					hookResult = 1
					break			
			endswitch
		break
		case 22:					// Mouse Wheel
			If(!ControlButton&&!ShiftButton)
				AnalysisSettings[%SubIndex]+=s.wheelDy
				If(AnalysisSettings[%SubIndex]<0)
					AnalysisSettings[%SubIndex]=0
				EndIf
				If(AnalysisSettings[%SubIndex]>=AnalysisSettings[%NumSteps])
					AnalysisSettings[%SubIndex]=AnalysisSettings[%NumSteps]-1
				EndIf
				LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
				DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
				hookResult = 1
			EndIf				
			If(ControlButton||ShiftButton)
				
				Variable UnfoldTime=UnfoldRFFitSettings[%RampEndTime]-UnfoldRFFitSettings[%RampStartTime]
				Variable RefoldTime=RefoldRFFitSettings[%RampEndTime]-RefoldRFFitSettings[%RampStartTime]
				// Determine which interval we are trying to change and then change it by 5% of the ramp interval
				Variable UnfoldChange=s.wheelDy*(0.02*UnfoldTime)
				Variable RefoldChange=s.wheelDY*(0.02*UnfoldTime)

				If((MouseTime>UnfoldRFFitSettings[%Fit1StartTime])&&(MouseTime<UnfoldRFFitSettings[%Fit1EndTime]))
					If(ControlButton)
						UnfoldRFFitSettings[%Fit1StartTime]+=UnfoldChange
					Else
						UnfoldRFFitSettings[%Fit1EndTime]+=UnfoldChange
					EndIf
					
				EndIf
				If((MouseTime>UnfoldRFFitSettings[%Fit2StartTime])&&(MouseTime<UnfoldRFFitSettings[%Fit2EndTime]))
					If(ControlButton)
						UnfoldRFFitSettings[%Fit2StartTime]+=UnfoldChange
					Else
						UnfoldRFFitSettings[%Fit2EndTime]+=UnfoldChange
					EndIf
					
				EndIf
				If((MouseTime>RefoldRFFitSettings[%Fit1StartTime])&&(MouseTime<RefoldRFFitSettings[%Fit1EndTime]))
					If(ControlButton)
						RefoldRFFitSettings[%Fit1StartTime]+=RefoldChange
					Else
						RefoldRFFitSettings[%Fit1EndTime]+=RefoldChange
					EndIf
					
				EndIf
				If((MouseTime>RefoldRFFitSettings[%Fit2StartTime])&&(MouseTime<RefoldRFFitSettings[%Fit2EndTime]))
					If(ControlButton)
						RefoldRFFitSettings[%Fit2StartTime]+=RefoldChange
					Else
						RefoldRFFitSettings[%Fit2EndTime]+=RefoldChange
					EndIf
					
				EndIf
				
				ApplyRFFit(UnfoldRFFitSettings,RefoldRFFitSettings,ForceRorS)
				Variable NumSettings=DimSize(UnfoldRFFitSettings,0)
				Variable SettingsCounter=0
				For(SettingsCounter=0;SettingsCounter<NumSettings;SettingsCounter+=1)
					UnfoldSettings[SettingsCounter][AnalysisSettings[%SubIndex]]=UnfoldRFFitSettings[SettingsCounter]
					RefoldSettings[SettingsCounter][AnalysisSettings[%SubIndex]]=RefoldRFFitSettings[SettingsCounter]
				EndFor
				MeasureBothRF(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],"BothRuptures",LoadWaves=1)
				DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
				hookResult = 1
			Endif
		break
	endswitch

	return hookResult	// If non-zero, we handled event and Igor will ignore it.
End

Function MeasureRFByMI(MasterIndex,Method,[LoadWaves,RNAAnalysisDF,RampDF])

	Variable MasterIndex,LoadWaves
	String RNAAnalysisDF,RampDF,Method
	
	If(ParamIsDefault(LoadWaves))
		LoadWaves=0
	EndIf
	If(ParamIsDefault(RNAAnalysisDF))
		RNAAnalysisDF="root:RNAPulling:Analysis:"
	EndIf
	If(ParamIsDefault(RampDF))
		RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf
	
	Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
	Wave RefoldSettings=$RampDF+"RefoldRFFitSettings_"+num2str(MasterIndex)
	Wave UnfoldRFFitSettings=$RampDF+"UnfoldRFFitSettings"
	Wave RefoldRFFitSettings=$RampDF+"RefoldRFFitSettings"

	If(LoadWaves)
		LoadAllWavesForIndex(MasterIndex)
	EndIf
	
	Wave Settings=$RNAAnalysisDF+"Settings"
	Wave/T SettingsStr=$RNAAnalysisDF+"SettingsStr"
 	Variable NumRamps=NumStepsOrRamps(Settings,SettingsStr)
	Make/O/N=(NumRamps) $RampDF+"UnfoldRF_"+num2str(MasterIndex)
	Make/O/N=(NumRamps) $RampDF+"UnfoldRFTime_"+num2str(MasterIndex)
	Make/O/N=(NumRamps) $RampDF+"RefoldRF_"+num2str(MasterIndex)
	Make/O/N=(NumRamps) $RampDF+"RefoldRFTime_"+num2str(MasterIndex)
 	Variable RampCounter=0
 	For(RampCounter=0;RampCounter<NumRamps;RampCounter+=1)
	 	LoadRorS(MasterIndex,RampCounter)
 		MeasureBothRF(MasterIndex,RampCounter,Method,LoadWaves=1,RNAAnalysisDF=RNAAnalysisDF,RampDF=RampDF)
 	EndFor

End

Function MeasureBothRF(MasterIndex,RampIndex,Method,[LoadWaves,RNAAnalysisDF,RampDF])
	Variable MasterIndex,RampIndex,LoadWaves
	String RNAAnalysisDF,RampDF,Method

	If(ParamIsDefault(RampDF))
		RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf
	
	Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
	Wave RefoldSettings=$RampDF+"RefoldRFFitSettings_"+num2str(MasterIndex)
	Wave UnfoldRFFitSettings=$RampDF+"UnfoldRFFitSettings"
	Wave RefoldRFFitSettings=$RampDF+"RefoldRFFitSettings"

	If(ParamIsDefault(LoadWaves))
		LoadWaves=0
	EndIf
	If(ParamIsDefault(RNAAnalysisDF))
		RNAAnalysisDF="root:RNAPulling:Analysis:"
	EndIf
	
	If(LoadWaves)
		//LoadAllWavesForIndex(MasterIndex)
		UnfoldRFFitSettings=UnfoldSettings[p][RampIndex]
		RefoldRFFitSettings=RefoldSettings[p][RampIndex]
	EndIf
	Wave ForceWave=$RNAAnalysisDF+"ForceRorS"
	Wave ForceWave_smth=$RNAAnalysisDF+"ForceRorS_Smth"
	
	Wave UnfoldRFMI=$RampDF+"UnfoldRF_"+num2str(MasterIndex)
	Wave UnfoldRFTimeMI=$RampDF+"UnfoldRFTime_"+num2str(MasterIndex)
	Wave RefoldRFMI=$RampDF+"RefoldRF_"+num2str(MasterIndex)
	Wave RefoldRFTimeMI=$RampDF+"RefoldRFTime_"+num2str(MasterIndex)

	If(StringMatch("TargetTime",Method))
		ApplyRFFit(UnfoldRFFitSettings,RefoldRFFitSettings,ForceWave)
		Duplicate/O MeasureRF(ForceWave_smth,UnfoldRFFitSettings,Method=Method,TargetRuptureTime=UnfoldRFTimeMI[RampIndex]) $RampDF+"UnfoldRF"
		Duplicate/O MeasureRF(ForceWave_smth,RefoldRFFitSettings,Method=Method,TargetRuptureTime=RefoldRFTimeMI[RampIndex]) $RampDF+"RefoldRF"
		Variable NumSettings=DimSize(UnfoldRFFitSettings,0)
		Variable SettingsCounter=0
		For(SettingsCounter=0;SettingsCounter<NumSettings;SettingsCounter+=1)
			UnfoldSettings[SettingsCounter][RampIndex]=UnfoldRFFitSettings[SettingsCounter]
			RefoldSettings[SettingsCounter][RampIndex]=RefoldRFFitSettings[SettingsCounter]
		EndFor

	Else
		Duplicate/O MeasureRF(ForceWave_smth,UnfoldRFFitSettings,Method=Method) $RampDF+"UnfoldRF"
		Duplicate/O MeasureRF(ForceWave_smth,RefoldRFFitSettings,Method=Method)	 $RampDF+"RefoldRF"
	EndIf
	Wave UnfoldRF=$RampDF+"UnfoldRF"
	Wave RefoldRF=$RampDF+"RefoldRF"
		
	UnfoldRFMI[RampIndex]=UnfoldRF[%RuptureForce]
	UnfoldRFTimeMI[RampIndex]=UnfoldRF[%RuptureTime]
	RefoldRFMI[RampIndex]=RefoldRF[%RuptureForce]
	RefoldRFTimeMI[RampIndex]=RefoldRF[%RuptureTime]
	
End

Function/Wave MeasureRF(ForceWave_smth,RFFitSettings,[Method,TargetRuptureTime])
	Wave ForceWave_smth,RFFitSettings
	String Method
	Variable TargetRuptureTime
	
	If(ParamIsDefault(Method))
		Method="JustFirstRupture"
	EndIf
	If(ParamIsDefault(TargetRuptureTime))
		TargetRuptureTime=0
	EndIf
	
	If(StringMatch(Method,"TargetTime"))
		// Now estimate start of the other state
		Wave RF1=EstimateRF(ForceWave_smth,RFFitSettings[%Fit1LR],RFFitSettings[%Fit1YIntercept],RFFitSettings[%Fit1StartTime],RFFitSettings[%RampEndTime],RFStatsName="RF1",FirstLastTarget="TargetTime",TargetTime=TargetRuptureTime)
	Else
		Wave RF1=EstimateRF(ForceWave_smth,RFFitSettings[%Fit1LR],RFFitSettings[%Fit1YIntercept],RFFitSettings[%Fit1StartTime],RFFitSettings[%RampEndTime],RFStatsName="RF1",FirstLastTarget="Last")		
	EndIF

		// Do the initial estimate of RF
		
	If(StringMatch(Method,"BothRuptures"))
		// Now estimate start of the other state
		Wave RF2=EstimateRF(ForceWave_smth,RFFitSettings[%Fit2LR],RFFitSettings[%Fit2YIntercept],RFFitSettings[%RampStartTime],RFFitSettings[%Fit2EndTime],RFStatsName="RF2",FirstLastTarget="First")
		
		// Now check for consistency
		Variable RFIsGood=RF2[%RuptureTime]>RF1[%RuptureTime]
		
		If(!RFIsGood)
			EstimateRF(ForceWave_smth,RFFitSettings[%Fit1LR],RFFitSettings[%Fit1YIntercept],RFFitSettings[%Fit1StartTime],RFFitSettings[%RampEndTime],RFStatsName="RF1",FirstLastTarget="Target",TargetCrossing=RF2[%RuptureTime])
		EndIf
	EndIF
	
	Return RF1
	
End

// Guess RF fit settings for all ramps of a given master index
Function GuessRFFitSettingsMI(MasterIndex,[UnfoldStartFraction,UnfoldEndFraction,RefoldStartFraction,RefoldEndFraction,RampDF,RNAAnalysisDF])
	Variable MasterIndex,UnfoldStartFraction,UnfoldEndFraction,RefoldStartFraction,RefoldEndFraction
	String RNAAnalysisDF,RampDF
	
	If(ParamIsDefault(RNAAnalysisDF))
		RNAAnalysisDF="root:RNAPulling:Analysis:"
	EndIf
	If(ParamIsDefault(RampDF))
		RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf
	If(ParamIsDefault(UnfoldStartFraction))
		UnfoldStartFraction=0.5
	EndIf
	If(ParamIsDefault(UnfoldEndFraction))
		UnfoldEndFraction=0.2
	EndIf
	If(ParamIsDefault(RefoldStartFraction))
		RefoldStartFraction=0.2
	EndIf
	If(ParamIsDefault(RefoldEndFraction))
		RefoldEndFraction=0.5
	EndIf
	Wave UnfoldRFFitSettings=$RampDF+"UnfoldRFFitSettings"
	Wave RefoldRFFitSettings=$RampDF+"RefoldRFFitSettings"

	Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
	Wave RefoldSettings=$RampDF+"RefoldRFFitSettings_"+num2str(MasterIndex)
	
	Variable NumRamps=DimSize(UnfoldSettings,1)
	Variable RampIndex=0
	LoadRorS(MasterIndex,RampIndex)
	Wave ForceWave=$RNAAnalysisDF+"ForceRorS"
	Wave ForceWave_smth=$RNAAnalysisDF+"ForceRorS_Smth"
	Wave RNAPullingSettings=$RNAAnalysisDF+"Settings"
	For(RampIndex=0;RampIndex<NumRamps;RampIndex+=1)
		LoadRorS(MasterIndex,RampIndex)
		GuessRFFitSettings(UnfoldRFFitSettings,RefoldRFFitSettings,ForceWave,ForceWave_smth,RNAPullingSettings,UnfoldStartFraction=UnfoldStartFraction,UnfoldEndFraction=UnfoldEndFraction,RefoldStartFraction=RefoldStartFraction,RefoldEndFraction=RefoldEndFraction)
		Variable NumSettings=DimSize(UnfoldRFFitSettings,0)
		Variable SettingsCounter=0
		For(SettingsCounter=0;SettingsCounter<NumSettings;SettingsCounter+=1)
			UnfoldSettings[SettingsCounter][RampIndex]=UnfoldRFFitSettings[SettingsCounter]
			RefoldSettings[SettingsCounter][RampIndex]=RefoldRFFitSettings[SettingsCounter]
		EndFor
	EndFor
	
End

Function ApplyRFFit(UnfoldSettings,RefoldSettings,ForceWave)
	Wave UnfoldSettings,RefoldSettings,ForceWave
	
	// Fit a line to the 4 main segments associated with unfolded and refolded states
	Wave LRFitUnfold1=LR(ForceWave,UnfoldSettings[%Fit1StartTime],UnfoldSettings[%Fit1EndTime],LRFitName="LRFitUnfold1",SpecifyEndTime=1)
	Wave LRFitUnfold2=LR(ForceWave,UnfoldSettings[%Fit2StartTime],UnfoldSettings[%Fit2EndTime],LRFitName="LRFitUnfold2",SpecifyEndTime=1)
	Wave LRFitRefold1=LR(ForceWave,RefoldSettings[%Fit1StartTime],RefoldSettings[%Fit1EndTime],LRFitName="LRFitRefold1",SpecifyEndTime=1)
	Wave LRFitRefold2=LR(ForceWave,RefoldSettings[%Fit2StartTime],RefoldSettings[%Fit2EndTime],LRFitName="LRFitRefold2",SpecifyEndTime=1)
	// Set Unfold Fit Settings
	UnfoldSettings[%Fit1LR]=LRFitUnfold1[%LoadingRate]
	UnfoldSettings[%Fit1YIntercept]=LRFitUnfold1[%YIntercept]
	UnfoldSettings[%Fit2LR]=LRFitUnfold2[%LoadingRate]
	UnfoldSettings[%Fit2YIntercept]=LRFitUnfold2[%YIntercept]
	// Set Refold Fit Settings
	RefoldSettings[%Fit1LR]=LRFitRefold1[%LoadingRate]
	RefoldSettings[%Fit1YIntercept]=LRFitRefold1[%YIntercept]
	RefoldSettings[%Fit2LR]=LRFitRefold2[%LoadingRate]
	RefoldSettings[%Fit2YIntercept]=LRFitRefold2[%YIntercept]

End

// Guess RF Fit Settings for a single, individual ramp.
Function GuessRFFitSettings(UnfoldSettings,RefoldSettings,ForceWave,ForceWave_smth,RNAPullingSettings,[UnfoldStartFraction,UnfoldEndFraction,RefoldStartFraction,RefoldEndFraction])
	Wave UnfoldSettings,RefoldSettings,ForceWave,ForceWave_smth,RNAPullingSettings
	Variable UnfoldStartFraction,UnfoldEndFraction,RefoldStartFraction,RefoldEndFraction
	
	If(ParamIsDefault(UnfoldStartFraction))
		UnfoldStartFraction=0.5
	EndIf
	If(ParamIsDefault(UnfoldEndFraction))
		UnfoldEndFraction=0.2
	EndIf
	If(ParamIsDefault(RefoldStartFraction))
		RefoldStartFraction=0.25
	EndIf
	If(ParamIsDefault(RefoldEndFraction))
		RefoldEndFraction=0.5
	EndIf
	
	// Determine start and stop to all time intervals for analysis
	Variable NumPts=DimSize(ForceWave,0)
	Variable StartTime=pnt2x(ForceWave,0)
	Variable EndTime=pnt2x(ForceWave,NumPts)-RNAPullingSettings[%DwellTime]
	Variable FractionInUnfold=0.5  // This only works for equal velocities.  Might need to fix later for different unfold/refold ramp speeds. 
	Variable TurnAroundTime=FractionInUnfold*(EndTime-StartTime)+StartTime
	Variable UnfoldTime=TurnAroundTime-StartTime
	Variable RefoldTime=EndTime-TurnAroundTime
	Variable EndUnfoldFit1=StartTime+UnfoldStartFraction*UnfoldTime
	Variable StartUnfoldFit2=TurnAroundTime-UnfoldEndFraction*UnfoldTime
	Variable EndRefoldFit1=TurnAroundTime+RefoldStartFraction*RefoldTime
	Variable StartRefoldFit2=EndTime-RefoldEndFraction*RefoldTime
	
	// Set Unfold Fit Settings
	UnfoldSettings[%RampStartTime]=StartTime
	UnfoldSettings[%RampEndTime]=TurnAroundTime
	UnfoldSettings[%Fit1StartTime]=StartTime
	UnfoldSettings[%Fit1EndTime]=EndUnfoldFit1
	UnfoldSettings[%Fit2StartTime]=StartUnfoldFit2
	UnfoldSettings[%Fit2EndTime]=TurnAroundTime
	// Set Refold Fit Settings
	RefoldSettings[%RampStartTime]=TurnAroundTime
	RefoldSettings[%RampEndTime]=EndTime
	RefoldSettings[%Fit1StartTime]=TurnAroundTime
	RefoldSettings[%Fit1EndTime]=EndRefoldFit1
	RefoldSettings[%Fit2StartTime]=StartRefoldFit2
	RefoldSettings[%Fit2EndTime]=EndTime
	
	// Do fit with settings and save fit parameters to settings wave
	ApplyRFFit(UnfoldSettings,RefoldSettings,ForceWave)
End

Function RFbyPullingSpeed([TargetDF])
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf

	SetDataFolder $TargetDF
	String UnfoldingWaves=WaveList("UnfoldRF_*", ";","")
	String RefoldingWaves=WaveList("RefoldRF_*", ";","")
	Variable NumRamps=ItemsInList(UnfoldingWaves)
	Make/O/N=(NumRamps) UnfoldingSpeed,UnfoldingIndex,RefoldingSpeed
	Variable RampCounter=0
	For(RampCounter=0;RampCounter<NumRamps;RampCounter+=1)
		String CurrentRampWave=StringFromList(RampCounter,UnfoldingWaves)
		Variable MasterIndex=NumberByKey("UnfoldRF", CurrentRampWave, "_")
		UnfoldingIndex[RampCounter]=MasterIndex
		Wave Settings=$"root:RNAPulling:SavedData:"+"Settings"+num2str(MasterIndex)
		UnfoldingSpeed[RampCounter]=Settings[%RetractVelocity]
		RefoldingSpeed[RampCounter]=Settings[%ApproachVelocity]
	EndFor
	GetUniqueValues(UnfoldingSpeed,OutputWaveName="UniqueUnfoldVelocities")
	GetUniqueValues(RefoldingSpeed,OutputWaveName="UniqueRefoldVelocities")
	Wave UniqueUnfoldVelocities
	Wave UniqueRefoldVelocities
	Variable NumUniqueV=DimSize(UniqueUnfoldVelocities,0)
	Variable UniqueVCounter=0
	For(UniqueVCounter=0;UniqueVCounter<NumUniqueV;UniqueVCounter+=1)
		Make/N=0/O $TargetDF+"AllUnfoldRF_"+num2str(Floor(UniqueUnfoldVelocities[UniqueVCounter]*1e9))+"nmps"
		Make/N=0/O $TargetDF+"AllRefoldRF_"+num2str(Floor(UniqueRefoldVelocities[UniqueVCounter]*1e9))+"nmps"
	EndFor	
	For(RampCounter=0;RampCounter<NumRamps;RampCounter+=1)
		Variable UnfoldV=UnfoldingSpeed[RampCounter]
		Variable RefoldV=RefoldingSpeed[RampCounter]
		Wave AllUnfoldRF=$TargetDF+"AllUnfoldRF_"+num2str(Floor(UnfoldV*1e9))+"nmps"
		Duplicate/O $TargetDF+"AllUnfoldRF_"+num2str(Floor(UnfoldV*1e9))+"nmps",TempUnfold
		Wave AllRefoldRF=$TargetDF+"AllRefoldRF_"+num2str(Floor(RefoldV*1e9))+"nmps"
		Duplicate/O $TargetDF+"AllRefoldRF_"+num2str(Floor(RefoldV*1e9))+"nmps",TempRefold
		Wave CurrentUnfoldRF=$StringFromList(RampCounter,UnfoldingWaves)
		Wave CurrentRefoldRF=$StringFromList(RampCounter,RefoldingWaves)
		Concatenate/NP/O {TempUnfold,CurrentUnfoldRF}, $TargetDF+"AllUnfoldRF_"+num2str(Floor(UnfoldV*1e9))+"nmps"
		Concatenate/NP/O {TempRefold,CurrentRefoldRF}, $TargetDF+"AllRefoldRF_"+num2str(Floor(RefoldV*1e9))+"nmps"
	EndFor	
	
End

// Function calculate mean rupture force of RNA ramps.
Function RNAMeanRF([Mode,TargetDF])
	String Mode,TargetDF
	
	If(ParamIsDefault(Mode))
		Mode="ByRampSpeed"
	EndIf

	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:RampAnalysis:"
	EndIf
	SetDataFolder $TargetDF
	String UnfoldingWaves,RefoldingWaves
	StrSwitch(Mode)
		case "ByIndex":
			UnfoldingWaves=WaveList("UnfoldRF_*", ";","")
			RefoldingWaves=WaveList("RefoldRF_*", ";","")
		break
		case "ByRampSpeed":
			UnfoldingWaves=WaveList("AllUnfoldRF_*", ";","")
			RefoldingWaves=WaveList("AllRefoldRF_*", ";","")
		break
	EndSwitch
	Variable NumWaves=ItemsInList(UnfoldingWaves)
	Variable WaveCounter=0
	
	Make/O/D/N=(NumWaves) $"RFError"+Mode,$"UFError"+Mode,$"UF"+Mode,$"RF"+Mode,$"RF"+Mode+"Velocity",$"RF"+Mode+"TimeToLastCFR"
	Wave UnfoldForce=$"UF"+Mode
	Wave RefoldForce=$"RF"+Mode
	Wave UnfoldForceError=$"UFError"+Mode
	Wave RefoldForceError=$"RFError"+Mode
	Wave Velocity=$"RF"+Mode+"Velocity"
	Wave TimeToLastCFR=$"RF"+Mode+"TimeToLastCFR"
	For(WaveCounter=0;WaveCounter<NumWaves;WaveCounter+=1)
		SetDataFolder $TargetDF
		Wave CurrentUnfoldRF=$StringFromList(WaveCounter,UnfoldingWaves)
		Wave CurrentRefoldRF=$StringFromList(WaveCounter,RefoldingWaves)
		WaveStats/Q CurrentUnfoldRF
		UnfoldForce[WaveCounter]=V_avg
		UnfoldForceError[WaveCounter]=V_sdev
		WaveStats/Q CurrentRefoldRF
		RefoldForce[WaveCounter]=V_avg
		RefoldForceError[WaveCounter]=V_sdev
		StrSwitch(Mode)
			case "ByIndex":
				Variable Index=Nan
				sscanf StringFromList(WaveCounter,UnfoldingWaves), "UnfoldRF_%f", Index
				Wave Settings=$"root:RNAPulling:SavedData:Settings"+num2str(Index)
				Velocity[WaveCounter]=Settings[%RetractVelocity]
				TimeToLastCFR[WaveCounter]=TimeSincePreviousCFR("RNAPulling"+num2str(Index))
			break
			case "ByRampSpeed":
				Variable CurrentPullingSpeed=Nan
				sscanf StringFromList(WaveCounter,UnfoldingWaves), "AllUnfoldRF_%f", CurrentPullingSpeed

				Velocity[WaveCounter]=CurrentPullingSpeed	
				TimeToLastCFR[WaveCounter]=NaN
			break
		EndSwitch

	EndFor
	

End

Function LoadRorS(MasterIndex,RSIndex,[TargetDF])
	Variable MasterIndex,RSIndex
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:"
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

// Get an individual ramp or step from the RNA Pulling data
Function GetIndividualRoS(MasterIndex,RSIndex,DefV,ZSensor,ZSetPoint,RNAPullingSettings,RNAPullingSettingsStr,[DefVName,ZSensorName])
	Variable MasterIndex,RSIndex
	Wave DefV,ZSensor,RNAPullingSettings,ZSetPoint
	Wave/T RNAPullingSettingsStr
	String DefVName,ZSensorName
	
	If(ParamIsDefault(DefVName))
		DefVName="root:RNAPulling:Analysis:DefVRorS"
	EndIf

	If(ParamIsDefault(ZSensorName))
		ZSensorName="root:RNAPulling:Analysis:ZSensorRorS"
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

Function AllRNADisplays([TargetDF])
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:"
	EndIf

	DisplayRNAPull("ForceVsSep",TargetDF=TargetDF)
	DisplayRNAPull("ForceVsSep_RorS",TargetDF=TargetDF)
	DisplayRNAPull("ForceRorS",TargetDF=TargetDF)
	DisplayRNAPull("RorSForce",TargetDF=TargetDF)
End

Function DisplayRNAPull(DisplayType,[TargetDF])
	
	String DisplayType,TargetDF
	
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:"
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
	EndSwitch

End

Function/Wave GetRNAWave(MasterIndex,WhichWave)
	Variable MasterIndex
	String WhichWave
	String NamePrefix="root:RNAPulling:SavedData:"
	String TargetWaveName=NamePrefix+WhichWave+num2str(MasterIndex)
	Wave TargetWave=$TargetWaveName
	
	Return TargetWave
	
End

Function LoadAllWavesForIndex(MasterIndex,[TargetDF])
	Variable MasterIndex
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:"
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
	Wave SelectedForce_Ret=root:RNAPulling:Analysis:SelectedForce_Ret
	Wave SelectedSep_Ret=root:RNAPulling:Analysis:SelectedSep_Ret
	LoadCorrectedFR(SelectedForce_Ret,SelectedSep_Ret,FRName)
	
	Duplicate/O$(TargetDF+"DefV"), $(TargetDF+"RorSForce")
	Duplicate/O$(TargetDF+"ZSensor"),  $(TargetDF+"RorSSep")
	Wave RorSForce=$(TargetDF+"RorSForce")
	Wave RorSSep= $(TargetDF+"RorSSep")
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
	Wave RSForceOffset=root:RNAPulling:Analysis:RSForceOffset
	Wave RSSepOffset=root:RNAPulling:Analysis:RSSepOffset	
	ForceOffset=RSForceOffset[MasterIndex]
	SepOffset=RSSepOffset[MasterIndex]
		
	FastOp RorSForce=(ForceOffset)-(VtoF)*RorSForce
	
	String ZSensorInfo=note(RorSSep)
	Variable ZSens=-1*str2num(StringByKey("\rZLVDTSens",ZSensorInfo,"=",";\r"))
	Variable InverseK=1/SpringConstant
	Variable InverseKFO=InverseK*ForceOffset-SepOffset
	FastOp RorSSep=(InverseKFO)+(ZSens)*RorSSep-(InverseK)*RorSForce//+(SepOffset)

	MakeSmoothedRorS(MasterIndex,TargetDF=TargetDF)	
End

Function MakeSmoothedRorS(MasterIndex,[TargetDF])
	Variable MasterIndex
	String TargetDF
	
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:"
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
	
	If(WaveExists($(TargetDF+"RSFilterSettings")))
		Wave RSFilterSettings=$(TargetDF+"RSFilterSettings")
		BoxCarNumber=RSFilterSettings[MasterIndex][0]
		DecimationFactor=RSFilterSettings[MasterIndex][1]
	EndIf
	If(BoxCarNumber>1)
		BoxCarAndDecimateFR(RorSForce_Smth,RorSSep_Smth,BoxCarNumber,DecimationFactor,SmoothMode="SavitzkyGolay")
	EndIF

End



Window RNAAnalysisPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1221,111,1444,799) as "RNA Analysis"
	SetDrawLayer UserBack
	DrawLine 4,256,189,256
	DrawLine 4,151,190,151
	DrawLine 4,45,190,45
	DrawText 4,64,"RNA Pull Info"
	DrawText 4,169,"Filtering"
	DrawText 4,277,"Ramp Analysis"
	DrawLine 2,502,187,502
	DrawText 2,527,"Step Analysis"
	SetVariable MasterIndex,pos={4,2},size={131,16},proc=RNAAnalysisSetVarProc,title="Master Index"
	SetVariable MasterIndex,value= root:RNAPulling:Analysis:AnalysisSettings[%MasterIndex]
	SetVariable SubIndex,pos={4,21},size={131,16},proc=RNAAnalysisSetVarProc,title="Ramp/Step Index"
	SetVariable SubIndex,value= root:RNAPulling:Analysis:AnalysisSettings[%SubIndex]
	SetVariable ExperimentType,pos={4,65},size={160,16},title="Experiment Type"
	SetVariable ExperimentType,value= root:RNAPulling:Analysis:SettingsStr[%CurrentMode]
	SetVariable SubIndex1,pos={4,107},size={149,16},proc=RNAAnalysisSetVarProc,title="Number of Ramp/Step"
	SetVariable SubIndex1,limits={-inf,inf,0},value= root:RNAPulling:Analysis:AnalysisSettings[%NumSteps],noedit= 1
	SetVariable NearestForcePull,pos={4,86},size={175,16},title="Nearest Force Pull"
	SetVariable NearestForcePull,value= root:RNAPulling:Analysis:SettingsStr[%NearestForcePull]
	SetVariable BoxCarAverage,pos={4,180},size={132,16},proc=RNAAnalysisSetVarProc,title="Box Car Average"
	SetVariable BoxCarAverage,value= root:RNAPulling:Analysis:AnalysisSettings[%BoxCarAverage]
	SetVariable Decimation,pos={4,202},size={131,16},proc=RNAAnalysisSetVarProc,title="Decimation"
	SetVariable Decimation,value= root:RNAPulling:Analysis:AnalysisSettings[%Decimation]
	Button ApplyFilterButton,pos={4,225},size={131,20},proc=RNAAnalysisButtonProc,title="Apply Filter"
	Button ApplyFilterButton,fColor=(61440,61440,61440)
	Button RuptureForceAnalysisButton,pos={2,434},size={121,18},proc=RNAAnalysisButtonProc,title="RF for This Master Index"
	Button RuptureForceAnalysisButton,fColor=(61440,61440,61440)
	Button RFbyVelocityButton,pos={2,475},size={121,18},proc=RNAAnalysisButtonProc,title="RF by Velocity"
	Button RFbyVelocityButton,fColor=(61440,61440,61440)
	SetVariable PullingVelocitySV,pos={4,130},size={149,16},proc=RNAAnalysisSetVarProc,title="Pulling Velocity"
	SetVariable PullingVelocitySV,format="%.2W1Pm/s"
	SetVariable PullingVelocitySV,limits={-inf,inf,0},value= root:RNAPulling:Analysis:Settings[%RetractVelocity],noedit= 1
	Button InitRFAnalysis,pos={2,282},size={140,18},proc=RNAAnalysisButtonProc,title="Init RF for This Master Index"
	Button InitRFAnalysis,fColor=(61440,61440,61440)
	Button RFAnalysisRampButton,pos={2,413},size={121,18},proc=RNAAnalysisButtonProc,title="RF for This Ramp"
	Button RFAnalysisRampButton,fColor=(61440,61440,61440)
	SetVariable UnfoldFit1Fraction,pos={2,307},size={140,16},proc=RNAAnalysisSetVarProc,title="Unfold Fit1 Fraction"
	SetVariable UnfoldFit1Fraction,limits={0,1,0.05},value= root:RNAPulling:Analysis:RampAnalysis:RampAnalysisSettings[%UnfoldFit1Fraction]
	SetVariable UnfoldFit2Fraction,pos={2,327},size={140,16},proc=RNAAnalysisSetVarProc,title="Unfold Fit2 Fraction"
	SetVariable UnfoldFit2Fraction,limits={0,1,0.05},value= root:RNAPulling:Analysis:RampAnalysis:RampAnalysisSettings[%UnfoldFit2Fraction]
	SetVariable RefoldFit1Fraction,pos={2,347},size={140,16},proc=RNAAnalysisSetVarProc,title="Refold Fit1 Fraction"
	SetVariable RefoldFit1Fraction,limits={0,1,0.05},value= root:RNAPulling:Analysis:RampAnalysis:RampAnalysisSettings[%RefoldFit1Fraction]
	SetVariable RefoldFit2Fraction,pos={2,367},size={140,16},proc=RNAAnalysisSetVarProc,title="Refold Fit2 Fraction"
	SetVariable RefoldFit2Fraction,limits={0,1,0.05},value= root:RNAPulling:Analysis:RampAnalysis:RampAnalysisSettings[%RefoldFit2Fraction]
	Button ApplyFractionToMI,pos={2,387},size={119,18},proc=RNAAnalysisButtonProc,title="Apply Fractions to MI"
	Button ApplyFractionToMI,fColor=(61440,61440,61440)
	Button RedoRFAnalysis,pos={4,454},size={121,18},proc=RNAAnalysisButtonProc,title="RF for MI (Same Fit)"
	Button RedoRFAnalysis,fColor=(61440,61440,61440)
	Button EstimatePSF,pos={9,573},size={121,18},proc=RNAAnalysisButtonProc,title="Estimate PSF(F)"
	Button EstimatePSF,fColor=(61440,61440,61440)
	SetVariable StartStep,pos={9,528},size={132,16},proc=RNAAnalysisSetVarProc,title="Start Step"
	SetVariable StartStep,value= _NUM:0
	SetVariable EndStep,pos={10,548},size={131,16},proc=RNAAnalysisSetVarProc,title="End Step"
	SetVariable EndStep,value= _NUM:15
EndMacro

Function RNAAnalysisSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	Wave AnalysisSettings=root:RNAPulling:Analysis:AnalysisSettings
	Wave Settings=root:RNAPulling:Analysis:Settings
	Wave/T SettingsStr=root:RNAPulling:Analysis:SettingsStr
	Wave DefV=root:RNAPulling:Analysis:DefV
	Wave ZSensor=root:RNAPulling:Analysis:ZSensor
	Wave ZSetPoint=root:RNAPulling:Analysis:ZSetPoint
	Wave RorSForce=root:RNAPulling:Analysis:RorSForce
	Wave RorSSep=root:RNAPulling:Analysis:RorSSep
	Wave ForceWave=root:RNAPulling:Analysis:ForceRorS
	Wave ForceWave_smth=root:RNAPulling:Analysis:ForceRorS_smth
	Wave RSFilterSettings=root:RNAPulling:Analysis:RSFilterSettings
	String RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	Wave UnfoldRFFitSettings=$RampDF+"UnfoldRFFitSettings"
	Wave RefoldRFFitSettings=$RampDF+"RefoldRFFitSettings"
	Wave RampAnalysisSettings=$RampDF+"RampAnalysisSettings"

	If(RFAnalysisQ(AnalysisSettings[%MasterIndex]))
		Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(AnalysisSettings[%MasterIndex])
		Wave RefoldSettings=$RampDF+"RefoldRFFitSettings_"+num2str(AnalysisSettings[%MasterIndex])
	EndIf

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String ControlName=sva.ctrlName
			
			StrSwitch(ControlName)
				case "MasterIndex":
					AnalysisSettings[%BoxCarAverage]=RSFilterSettings[AnalysisSettings[%MasterIndex]][0]
					AnalysisSettings[%Decimation]=RSFilterSettings[AnalysisSettings[%MasterIndex]][1]
				
					AnalysisSettings[%SubIndex]=0
					LoadAllWavesForIndex(dval)
				 	AnalysisSettings[%NumSteps]=NumStepsOrRamps(Settings,SettingsStr)
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])	
					AllRNADisplays()				
					If(RFAnalysisQ(AnalysisSettings[%MasterIndex]))
						DisplayRampAnalysis(AnalysisSettings[%MasterIndex],0,LoadFitSettings=1)
					Else
						DoWindow/F RNARampAnalysis
						If(V_flag==1)
							KillWindow RNARampAnalysis
						EndIf
					EndIf
				break
				case "SubIndex":
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
					If(RFAnalysisQ(AnalysisSettings[%MasterIndex]))
						DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
					EndIf
				break
				case "BoxCarAverage":
					RSFilterSettings[AnalysisSettings[%MasterIndex]][0]=AnalysisSettings[%BoxCarAverage]
				break
				case "Decimation":
					RSFilterSettings[AnalysisSettings[%MasterIndex]][1]=AnalysisSettings[%Decimation]
				
				break
				case "UnfoldFit1Fraction":
				case "UnfoldFit2Fraction":
				case "RefoldFit1Fraction":
				case "RefoldFit2Fraction":
					If(RFAnalysisQ(AnalysisSettings[%MasterIndex]))
						DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
					EndIf
					GuessRFFitSettings(UnfoldRFFitSettings,RefoldRFFitSettings,ForceWave,ForceWave_smth,Settings,UnfoldStartFraction=RampAnalysisSettings[%UnfoldFit1Fraction],UnfoldEndFraction=RampAnalysisSettings[%UnfoldFit2Fraction],RefoldStartFraction=RampAnalysisSettings[%RefoldFit1Fraction],RefoldEndFraction=RampAnalysisSettings[%RefoldFit2Fraction])
					Variable NumSettings=DimSize(UnfoldRFFitSettings,0)
					Variable SettingsCounter=0
					For(SettingsCounter=0;SettingsCounter<NumSettings;SettingsCounter+=1)
						UnfoldSettings[SettingsCounter][AnalysisSettings[%SubIndex]]=UnfoldRFFitSettings[SettingsCounter]
						RefoldSettings[SettingsCounter][AnalysisSettings[%SubIndex]]=RefoldRFFitSettings[SettingsCounter]
					EndFor
					MeasureBothRF(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],"BothRuptures",LoadWaves=1)
					DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
				break
				
			
			EndSwitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function RNAAnalysisButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ControlName=ba.ctrlname
	Wave AnalysisSettings=root:RNAPulling:Analysis:AnalysisSettings
	String RampDF="root:RNAPulling:Analysis:RampAnalysis:"
	Wave RampAnalysisSettings=$RampDF+"RampAnalysisSettings"

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			StrSwitch(ControlName)
				case "InitRFAnalysis":
					InitRFAnalysis(AnalysisSettings[%MasterIndex])
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
				break
				case "ApplyFilterButton":
					MakeSmoothedRorS(AnalysisSettings[%MasterIndex])
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
				break
				case "RedoRFAnalysis":
					MeasureRFByMI(AnalysisSettings[%MasterIndex],"TargetTime")
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])					
				break
				case "RuptureForceAnalysisButton":
					MeasureRFByMI(AnalysisSettings[%MasterIndex],"BothRuptures")
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
				break			
				case "RFbyVelocityButton":
					RFbyPullingSpeed()
				break			
				case "ApplyFractionToMI":
					GuessRFFitSettingsMI(AnalysisSettings[%MasterIndex],UnfoldStartFraction=RampAnalysisSettings[%UnfoldFit1Fraction],UnfoldEndFraction=RampAnalysisSettings[%UnfoldFit2Fraction],RefoldStartFraction=RampAnalysisSettings[%RefoldFit1Fraction],RefoldEndFraction=RampAnalysisSettings[%RefoldFit2Fraction])
					MeasureRFByMI(AnalysisSettings[%MasterIndex],"BothRuptures")
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
					DisplayRampAnalysis(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex],LoadFitSettings=1)
				break			
				case "EstimatePSF":
					ControlInfo/W=RNAAnalysisPanel StartStep
					Variable StartStep=V_value
					ControlInfo/W=RNAAnalysisPanel EndStep
					Variable EndStep=V_value
					EstimatePSFCurrentMI(AnalysisSettings[%MasterIndex],StartStep,EndStep)
				break
			EndSwitch
			
		
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
