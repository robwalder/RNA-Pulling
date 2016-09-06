#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include ":ChopRNAPulls"
#include "::Force Ramp Utilities:BoxCarAveraging"
#include "::Force Ramp Utilities:SelectFR"


Function InitRNAAnalysis()
	// Make new data folders 
	NewDataFolder/O root:RNAPulling:Analysis
	NewDataFolder/O root:RNAPulling:Analysis:RampAnalysis
	
	// Load waves for first time RNA Pulling program ran
	LoadAllWavesForIndex(0)
	
	// Set RNAAnalysis Parms Path
	String PathIn=FunctionPath("")
	NewPath/Q/O RNAAnalysisParms ParseFilePath(1, PathIn, ":", 1, 0) +"Parms"
	
	// Load Settings Wave
	SetDataFolder root:RNAPulling:Analysis
	LoadWave/H/Q/O/P=RNAAnalysisParms "AnalysisSettings.ibw"	
	SetDataFolder root:RNAPulling:Analysis:RampAnalysis
	LoadWave/H/Q/O/P=RNAAnalysisParms "RampFitSettings.ibw"	

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
	
	// Determine the number of times the rna pulling program ran
	Wave Settings=root:RNAPulling:Analysis:Settings
	Wave/T SettingsStr=root:RNAPulling:Analysis:SettingsStr
 	AnalysisSettings[%NumSteps]=NumStepsOrRamps(Settings,SettingsStr)
	
	// Load the first ramp/step on the for the first time the RNA pulling program ran
	LoadRorS(0,0)
	
	// Make Unfold and Refold Ramp Settings Waves
	Wave RampFitSettings=root:RNAPulling:Analysis:RampAnalysis:RampFitSettings
	SetDataFolder root:RNAPulling:Analysis:RampAnalysis
	Duplicate/O RampFitSettings, UnfoldRFFitSettings, RefoldRFFitSettings

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
	String RefoldSettingsName=RampDF+"RefoldSettingsName_"+num2str(MasterIndex)
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
		UnfoldStartFraction=0.25
	EndIf
	If(ParamIsDefault(UnfoldEndFraction))
		UnfoldEndFraction=0.25
	EndIf
	If(ParamIsDefault(RefoldStartFraction))
		RefoldStartFraction=0.25
	EndIf
	If(ParamIsDefault(RefoldEndFraction))
		RefoldEndFraction=0.25
	EndIf
	
	Wave UnfoldSettings=$RampDF+"UnfoldRFFitSettings_"+num2str(MasterIndex)
	Wave RefoldSettings=$RampDF+"RefoldSettingsName_"+num2str(MasterIndex)
	
	Variable NumRamps=DimSize(UnfoldSettings,1)
	Variable RampIndex=0
	LoadRorS(MasterIndex,RampIndex)
	Wave ForceWave=$RNAAnalysisDF+"RorSForce"
	Wave ForceWave_smth=$RNAAnalysisDF+"RorSForce_smth"
	Wave RNAPullingSettings=$RNAAnalysisDF+"Settings"
	For(RampIndex=0;RampIndex<NumRamps;RampIndex+=1)
		LoadRorS(MasterIndex,RampIndex)
		GuessRFFitSettings(UnfoldSettings,RefoldSettings,ForceWave,ForceWave_smth,RNAPullingSettings,UnfoldStartFraction=UnfoldStartFraction,UnfoldEndFraction=UnfoldEndFraction,RefoldStartFraction=RefoldStartFraction,RefoldEndFraction=RefoldEndFraction)
	EndFor
	
End

// Guess RF Fit Settings for a single, individual ramp.
Function GuessRFFitSettings(UnfoldSettings,RefoldSettings,ForceWave,ForceWave_smth,RNAPullingSettings,[UnfoldStartFraction,UnfoldEndFraction,RefoldStartFraction,RefoldEndFraction])
	Wave UnfoldSettings,RefoldSettings,ForceWave,ForceWave_smth,RNAPullingSettings
	Variable UnfoldStartFraction,UnfoldEndFraction,RefoldStartFraction,RefoldEndFraction
	String RFName
	If(ParamIsDefault(UnfoldStartFraction))
		UnfoldStartFraction=0.25
	EndIf
	If(ParamIsDefault(UnfoldEndFraction))
		UnfoldEndFraction=0.25
	EndIf
	If(ParamIsDefault(RefoldStartFraction))
		RefoldStartFraction=0.25
	EndIf
	If(ParamIsDefault(RefoldEndFraction))
		RefoldEndFraction=0.25
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
	
	// Fit a line to the 4 main segments associated with unfolded and refolded states
	Wave LRFitUnfold1=LR(ForceWave_smth,StartTime,UnfoldStartFraction*UnfoldTime,LRFitName="LRFitUnfold1")
	Wave LRFitUnfold2=LR(ForceWave_smth,StartUnfoldFit2,UnfoldEndFraction*UnfoldTime,LRFitName="LRFitUnfold2")
	Wave LRFitRefold1=LR(ForceWave_smth,TurnAroundTime,RefoldStartFraction*RefoldTime,LRFitName="LRFitRefold1")
	Wave LRFitRefold2=LR(ForceWave_smth,StartRefoldFit2,RefoldEndFraction*RefoldTime,LRFitName="LRFitRefold2")
	
	// Set Unfold Fit Settings
	UnfoldSettings[%RampStartTime]=StartTime
	UnfoldSettings[%RampEndTime]=TurnAroundTime
	UnfoldSettings[%Fit1StartTime]=StartTime
	UnfoldSettings[%Fit1EndTime]=EndUnfoldFit1
	UnfoldSettings[%Fit2StartTime]=StartUnfoldFit2
	UnfoldSettings[%Fit2EndTime]=TurnAroundTime
	UnfoldSettings[%Fit1LR]=LRFitUnfold1[%LoadingRate]
	UnfoldSettings[%Fit1YIntercept]=LRFitUnfold1[%YIntercept]
	UnfoldSettings[%Fit2LR]=LRFitUnfold2[%LoadingRate]
	UnfoldSettings[%Fit2YIntercept]=LRFitUnfold2[%YIntercept]
	// Set Refold Fit Settings
	RefoldSettings[%RampStartTime]=TurnAroundTime
	RefoldSettings[%RampEndTime]=EndTime
	RefoldSettings[%Fit1StartTime]=TurnAroundTime
	RefoldSettings[%Fit1EndTime]=EndRefoldFit1
	RefoldSettings[%Fit2StartTime]=StartRefoldFit2
	RefoldSettings[%Fit2EndTime]=EndTime
	RefoldSettings[%Fit1LR]=LRFitRefold1[%LoadingRate]
	RefoldSettings[%Fit1YIntercept]=LRFitRefold1[%YIntercept]
	RefoldSettings[%Fit2LR]=LRFitRefold2[%LoadingRate]
	RefoldSettings[%Fit2YIntercept]=LRFitRefold2[%YIntercept]
	
End

Function RFbyPullingSpeed([TargetDF])
	String TargetDF
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:"
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

Function RFMultipleRamps(RNAMasterIndex,[TargetDF,LoadWaves])
	Variable RNAMasterIndex
	String TargetDF
	Variable LoadWaves
	If(ParamIsDefault(LoadWaves))
		LoadWaves=0
	EndIf
	If(ParamIsDefault(TargetDF))
		TargetDF="root:RNAPulling:Analysis:"
	EndIf
	
	Wave Settings=$TargetDF+"Settings"
	Wave/T SettingsStr=$TargetDF+"SettingsStr"
	
	// Load all waves into analysis directory
	If(LoadWaves)
		LoadAllWavesForIndex(RNAMasterIndex)
	EndIf
	Variable NumRamps=NumStepsOrRamps(Settings,SettingsStr)
	Variable RampIndex=0

	// Set Wave references
	Wave ForceWave=$TargetDF+"ForceRorS"
	Wave ForceWave_smth=$TargetDF+"ForceRorS_smth"
	
	// Make Waves RF waves
	Make/O/N=(NumRamps) $TargetDF+"UnfoldRF_"+num2str(RNAMasterIndex)
	Make/O/N=(NumRamps) $TargetDF+"UnfoldRFTime_"+num2str(RNAMasterIndex)
	Make/O/N=(NumRamps) $TargetDF+"RefoldRF_"+num2str(RNAMasterIndex)
	Make/O/N=(NumRamps) $TargetDF+"RefoldRFTime_"+num2str(RNAMasterIndex)
	Wave UnfoldRF=$TargetDF+"UnfoldRF_"+num2str(RNAMasterIndex)
	Wave UnfoldRFTime=$TargetDF+"UnfoldRFTime_"+num2str(RNAMasterIndex)
	Wave RefoldRF=$TargetDF+"RefoldRF_"+num2str(RNAMasterIndex)
	Wave RefoldRFTime=$TargetDF+"RefoldRFTime_"+num2str(RNAMasterIndex)
	SetDataFolder $TargetDF
	// Find rupture force for every ramp speed
	For(RampIndex=0;RampIndex<NumRamps;RampIndex+=1)
		LoadRorS(RNAMasterIndex,RampIndex)
		DetermineRuptureForce(ForceWave,ForceWave_smth,Settings)
		Wave UnfoldingRF=$TargetDF+"UnfoldingRF"
		Wave RefoldingRF=$TargetDF+"RefoldingRF"
		UnfoldRF[RampIndex]=UnfoldingRF[%RuptureForce]
		UnfoldRFTime[RampIndex]=UnfoldingRF[%RuptureTime]
		RefoldRF[RampIndex]=RefoldingRF[%RuptureForce]
		RefoldRFTime[RampIndex]=RefoldingRF[%RuptureTime]
		
	EndFor
End

Function/Wave DetermineRuptureForce(ForceWave,ForceWave_smth,RNAPullingSettings,[LRStartFraction,LREndFraction,LRFitName,RFStatsName,RFName])
	Wave ForceWave,ForceWave_smth,RNAPullingSettings
	Variable LRStartFraction,LREndFraction
	String LRFitName,RFStatsName,RFName
	If(ParamIsDefault(LRStartFraction))
		LRStartFraction=0.25
	EndIf
	If(ParamIsDefault(LREndFraction))
		LREndFraction=0.25
		
	EndIf
	If(ParamIsDefault(LRFitName))
		LRFitName="LRFit"
	EndIf
	If(ParamIsDefault(RFStatsName))
		RFStatsName="RFStats"
	EndIf
	If(ParamIsDefault(RFName))
		RFName="RFName"
	EndIf
	
	// Determine start and stop to all time intervals for analysis
	Variable NumPts=DimSize(ForceWave,0)
	Variable StartTime=pnt2x(ForceWave,0)
	Variable EndTime=pnt2x(ForceWave,NumPts)-RNAPullingSettings[%DwellTime]
	Variable FractionInUnfold=0.5
	Variable TurnAroundTime=FractionInUnfold*(EndTime-StartTime)+StartTime
	Variable UnfoldTime=TurnAroundTime-StartTime
	Variable RefoldTime=EndTime-TurnAroundTime
	Variable EndUnfoldFit1=StartTime+LRStartFraction*UnfoldTime
	Variable StartUnfoldFit2=TurnAroundTime-LREndFraction*UnfoldTime
	Variable EndRefoldFit1=TurnAroundTime+LREndFraction*RefoldTime
	Variable StartRefoldFit2=EndTime-LRStartFraction*RefoldTime
	
	// Fit a line to the 4 main segments associated with unfolded and refolded states
	Wave LRFitUnfold1=LR(ForceWave_smth,StartTime,LRStartFraction*UnfoldTime,LRFitName="LRFitUnfold1")
	Wave LRFitUnfold2=LR(ForceWave_smth,StartUnfoldFit2,LREndFraction*UnfoldTime,LRFitName="LRFitUnfold2")
	Wave LRFitRefold1=LR(ForceWave_smth,TurnAroundTime,LREndFraction*RefoldTime,LRFitName="LRFitRefold1")
	Wave LRFitRefold2=LR(ForceWave_smth,StartRefoldFit2,LRStartFraction*RefoldTime,LRFitName="LRFitRefold2")
	
	// Do the initial estimate of RF
	Wave UnfoldingRF=EstimateRF(ForceWave_smth,LRFitUnfold1[%LoadingRate],LRFitUnfold1[%YIntercept],StartTime,TurnAroundTime,RFStatsName="UnfoldingRF",FirstLastTarget="Last")
	Wave RefoldingRF=EstimateRF(ForceWave_smth,LRFitRefold1[%LoadingRate],LRFitRefold1[%YIntercept],TurnAroundTime,EndTime,RFStatsName="RefoldingRF",FirstLastTarget="Last")
	
	// Now estimate start of the other states
	Wave UnfoldingRF2=EstimateRF(ForceWave_smth,LRFitUnfold2[%LoadingRate],LRFitUnfold2[%YIntercept],StartTime,TurnAroundTime,RFStatsName="UnfoldingRF2",FirstLastTarget="First")
	Wave RefoldingRF2=EstimateRF(ForceWave_smth,LRFitRefold2[%LoadingRate],LRFitRefold2[%YIntercept],TurnAroundTime,EndTime,RFStatsName="RefoldingRF2",FirstLastTarget="First")
	
	// Now check for consistency
	Variable UnfoldIsGood=UnfoldingRF2[%RuptureTime]>UnfoldingRF[%RuptureTime]
	Variable RefoldIsGood=REfoldingRF2[%RuptureTime]>RefoldingRF[%RuptureTime]
	
	If(!UnfoldIsGood)
		EstimateRF(ForceWave_smth,LRFitUnfold1[%LoadingRate],LRFitUnfold1[%YIntercept],StartTime,TurnAroundTime,RFStatsName="UnfoldingRF",FirstLastTarget="Target",TargetCrossing=UnfoldingRF2[%RuptureTime])
	EndIf
	
	If(!RefoldIsGood)
		EstimateRF(ForceWave_smth,LRFitRefold1[%LoadingRate],LRFitRefold1[%YIntercept],TurnAroundTime,EndTime,RFStatsName="RefoldingRF",FirstLastTarget="Target",TargetCrossing=RefoldingRF2[%RuptureTime])
	EndIF
	
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
	
	Wave TargetDefV=$(TargetDF+"DefV")
	String RNAPullInfo=Note(TargetDefV)
	String FRName=StringByKey("\rNearestForcePull",RNAPullInfo,"=",";\r")
	
	ApplyFuncsToForceWaves("SaveForceAndSep(Force_Ret,Sep_Ret,TargetFolder=\""+TargetDF+"\",NewName=\"Selected\")",FPList=FRName)
	Wave SelectedForce_Ret=root:RNAPulling:Analysis:SelectedForce_Ret
	Wave SelectedSep_Ret=root:RNAPulling:Analysis:SelectedSep_Ret
	
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
		ForceOffset=FRUOffsets[%$FRName][%Offset_Force]
		SepOffset=FRUOffsets[%$FRName][%Offset_Sep]
	EndIf
	FastOp RorSForce=(ForceOffset)-(VtoF)*RorSForce
	FastOp SelectedForce_Ret=(ForceOffset)-SelectedForce_Ret
	
	String ZSensorInfo=note(RorSSep)
	Variable ZSens=-1*str2num(StringByKey("\rZLVDTSens",ZSensorInfo,"=",";\r"))
	Variable InverseK=1/SpringConstant
	FastOp RorSSep=(ZSens)*RorSSep-(InverseK)*RorSForce-(SepOffset)
	FastOp	SelectedSep_Ret=SelectedSep_Ret-(SepOffset)

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
		BoxCarAndDecimateFR(RorSForce_Smth,RorSSep_Smth,BoxCarNumber,DecimationFactor)
	EndIF

End



Window RNAAnalysisPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(999,70,1222,559) as "RNA Analysis"
	SetDrawLayer UserBack
	DrawLine 4,256,189,256
	DrawLine 4,151,190,151
	DrawLine 4,45,190,45
	DrawText 4,64,"RNA Pull Info"
	DrawText 4,169,"Filtering"
	DrawText 4,277,"Ramp Analysis"
	DrawLine 4,375,189,375
	DrawText 4,400,"Step Analysis"
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
	SetVariable BoxCarAverage,pos={4,181},size={131,16},proc=RNAAnalysisSetVarProc,title="Box Car Average"
	SetVariable BoxCarAverage,value= root:RNAPulling:Analysis:AnalysisSettings[%BoxCarAverage]
	SetVariable Decimation,pos={4,202},size={131,16},proc=RNAAnalysisSetVarProc,title="Decimation"
	SetVariable Decimation,value= root:RNAPulling:Analysis:AnalysisSettings[%Decimation]
	Button ApplyFilterButton,pos={4,225},size={131,20},proc=RNAAnalysisButtonProc,title="Apply Filter"
	Button ApplyFilterButton,fColor=(61440,61440,61440)
	Button RuptureForceAnalysisButton,pos={4,327},size={121,18},proc=RNAAnalysisButtonProc,title="RF for This Master Index"
	Button RuptureForceAnalysisButton,fColor=(61440,61440,61440)
	Button RFbyVelocityButton,pos={4,348},size={121,18},proc=RNAAnalysisButtonProc,title="RF by Velocity"
	Button RFbyVelocityButton,fColor=(61440,61440,61440)
	SetVariable PullingVelocitySV,pos={4,130},size={149,16},proc=RNAAnalysisSetVarProc,title="Pulling Velocity"
	SetVariable PullingVelocitySV,format="%.2W1Pm/s"
	SetVariable PullingVelocitySV,limits={-inf,inf,0},value= root:RNAPulling:Analysis:Settings[%RetractVelocity],noedit= 1
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
	Wave RSFilterSettings=root:RNAPulling:Analysis:RSFilterSettings

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
				break
				case "SubIndex":
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
				break
				case "BoxCarAverage":
					RSFilterSettings[AnalysisSettings[%MasterIndex]][0]=AnalysisSettings[%BoxCarAverage]
				break
				case "Decimation":
					RSFilterSettings[AnalysisSettings[%MasterIndex]][1]=AnalysisSettings[%Decimation]
				
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

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			StrSwitch(ControlName)
				case "ApplyFilterButton":
					MakeSmoothedRorS(AnalysisSettings[%MasterIndex])
					LoadRorS(AnalysisSettings[%MasterIndex],AnalysisSettings[%SubIndex])
				break
				case "RuptureForceAnalysisButton":
					RFMultipleRamps(AnalysisSettings[%MasterIndex])
				break			
				case "RFbyVelocityButton":
					RFbyPullingSpeed()
				break			
				
			EndSwitch
			
		
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
