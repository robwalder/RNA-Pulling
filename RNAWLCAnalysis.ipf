#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0
#include "::Force-Spectroscopy-Models:WLCFits" version>=1.2
#include "::Force-Spectroscopy-Models:CLSpace" version>=1.1

Function InitRNAWLCAnalysis([ShowGUI])
	Variable ShowGUI
	If(ParamIsDefault(ShowGUI))
		ShowGUI=1
	EndIF
	
	// Make new data folders 
	NewDataFolder/O root:RNAPulling:Analysis:RNAWLCAnalysis
	NewDataFolder/O root:RNAPulling:Analysis:RNAWLCAnalysis:SavedData
	SetDataFolder root:RNAPulling:Analysis:RNAWLCAnalysis
	
	// Set RNAWLCAnalysis Parms Path
	String PathIn=FunctionPath("")
	NewPath/Q/O RNAWLCAnalysisParms ParseFilePath(1, PathIn, ":", 1, 0) +"Parms"
	
	// Load Settings Wave
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "DNAHandleFitSettings.ibw"	
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "DNAHandleFitSettingsStr.ibw"	
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "RNACLSettings.ibw"	
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "RNACLSettingsStr.ibw"	
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "RNAWLCFitSettings.ibw"	
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "RNAWLCFitSettingsStr.ibw"	
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "RNAHMMSettings.ibw"	
	LoadWave/H/Q/O/P=RNAWLCAnalysisParms "RNAHMMSettingsStr.ibw"	
	
	// Load RNA WLC Panel
	If(ShowGUI)
		Execute/Q "RNAWLCPanel()"
	EndIf
End

Function/Wave WLCFitDNAHandles(Force,Sep,[Lp,Lc,Kmod,Offset])
	Wave Force,Sep
	Variable Lp,Lc,Kmod,Offset
	If(ParamIsDefault(Lp))
		Lp=45e-9
	EndIf
	If(ParamIsDefault(Lc))
		Lc=66e-9
	EndIf
	If(ParamIsDefault(Kmod))
		Kmod=100e-12
	EndIf
	If(ParamIsDefault(Offset))
		Offset=10e-9
	EndIf
	WLCFit(Force,Sep,"ExtensibleWLC",CLGuess=Lc,PLGuess=Lp,StretchModulus=Kmod,Offset=Offset,HoldPL=1,HoldCL=1,HoldStretchModulus=1,HoldOffset=0)
	Wave WLC_Coeff
	Return WLC_Coeff
End

Function/Wave MakeDNAHandleExt(Force,WLC_Coeffs,[DNAExt_LowerBound,DNAExtName])
	Wave Force,WLC_Coeffs
	Variable DNAExt_LowerBound
	String DNAExtName
	If(ParamIsDefault(DNAExtName))
		DNAExtName="root:RNACLAnalysis:DNAExt"
	EndIf
	If(ParamIsDefault(DNAExt_LowerBound))
		DNAExt_LowerBound=0
	EndIf

	Duplicate/O Force, $DNAExtName
	Wave DNAExt=$DNAExtName
	DNAExt=ExtensibleWLCHighForce(WLC_Coeffs,Force[p])
	// If contour length is less than a certain lowerbound or nan then set it equal to the lower bound.
	// This prevents DNA extension from blowing up at lower force.	
	DNAExt=DNAExt[p]<DNAExt_LowerBound||numtype(DNAExt[p])==2?DNAExt_LowerBound : DNAExt[p]
	
	Return DNAExt
End

Function/Wave MakeRNAExt(Force, Ext, DNAExt,[RNAExtName])

	Wave Force,Ext, DNAExt
	String RNAExtName
	If(ParamIsDefault(RNAExtName))
		RNAExtName="root:RNACLAnalysis:RNAExt"
	EndIf
	Duplicate/O Ext, RNAExtension
	RNAExtension=Ext-DNAExt
	Return RNAExtension
End

Function/Wave MakeRNALcWave(Force,RNAExt,[Lp,RNACL_LowerBound,RNACLName])
	Wave Force,RNAExt
	Variable Lp,RNACL_LowerBound
	String RNACLName
	If(ParamIsDefault(RNACL_LowerBound)) // Default lower bound of the contour length  is -2 nm
		RNACL_LowerBound=-2e-9
	EndIf
	If(ParamIsDefault(Lp)) // Default RNA persistence length is 1 nm
		Lp=1e-9
	EndIf
	If(ParamIsDefault(RNACLName))
		RNACLName="root:RNACLAnalysis:RNACL"
	EndIf
	MakeContourLengthWave(Force,RNAExt,PersistenceLength=Lp,CLName=RNACLName,MoleculeType="None",Threshold=5e-12)
	Wave RNACLWave=$RNACLName
	// If contour length is less than a certain lowerbound or nan then set it equal to the lower bound.
	// This prevents RNACL from blowing up at lower force.
	RNACLWave=RNACLWave[p]<RNACL_LowerBound||numtype(RNACLWave[p])==2?RNACL_LowerBound : RNACLWave[p]
	Return RNACLWave
End

Function SaveCurrentRNAWLC(SaveName)
	String SaveName
	
	String DataFolderName="root:RNAPulling:Analysis:RNAWLCAnalysis:"+SaveName
	String TargetDataFolderName="root:RNAPulling:Analysis:RNAWLCAnalysis:"
	
	SetDataFolder $TargetDataFolderName
	String WaveNames = WaveList("*", ";" ,"" )
	NewDataFolder/O $DataFolderName
	
	Variable NumWavesToCopy=ItemsInList(WaveNames, ";")
	Variable Counter=0
	For(Counter=0;Counter<NumWavesToCopy;Counter+=1)
		String CurrentWaveName=TargetDataFolderName+StringFromList(Counter, WaveNames)
		String NewWaveName=DataFolderName+":"+StringFromList(Counter, WaveNames)
		Duplicate/O $CurrentWaveName,$NewWaveName
	EndFor

End

Function LoadSavedRNAWLC(SaveName)
	String SaveName
	
	String SaveDataFolderName="root:RNAPulling:Analysis:RNAWLCAnalysis:"+SaveName
	String TargetDataFolderName="root:RNAPulling:Analysis:RNAWLCAnalysis:"
	
	SetDataFolder $TargetDataFolderName
	KillWaves/A/Z

	SetDataFolder $SaveDataFolderName
	String WaveNames = WaveList("*", ";" ,"" )
	
	Variable NumWavesToCopy=ItemsInList(WaveNames, ";")
	Variable Counter=0
	For(Counter=0;Counter<NumWavesToCopy;Counter+=1)
		String CurrentWaveName=SaveDataFolderName+StringFromList(Counter, WaveNames)
		String NewWaveName=TargetDataFolderName+":"+StringFromList(Counter, WaveNames)
		Duplicate/O $CurrentWaveName,$NewWaveName
	EndFor

End

Window RNAWLCPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1388,65,1857,894) as "RNA WLC"
	SetDrawLayer UserBack
	DrawLine 6,234,444,234
	SetDrawEnv fsize= 14
	DrawText 9,26,"DNA Handles WLC Fit"
	DrawLine 13,491,451,491
	SetDrawEnv fsize= 14
	DrawText 10,252,"RNA WLC Fit"
	SetDrawEnv fsize= 14
	DrawText 12,509,"RNA Contour Length Space"
	SetDrawEnv fsize= 14
	DrawText 11,658,"State Identification with Hidden Markov Model"
	DrawLine 12,640,450,640
	SetVariable DNAHandleForceWaveName,pos={7,35},size={351,16},title="Force Wave"
	SetVariable DNAHandleForceWaveName,value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettingsStr[%Force]
	SetVariable StartValue,pos={6,74},size={150,16},title="Start Value"
	SetVariable StartValue,format="%.2W1Ps"
	SetVariable StartValue,limits={0,inf,1},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%StartFitX]
	SetVariable StopValue,pos={7,95},size={150,16},title="Stop Value"
	SetVariable StopValue,format="%.2W1Ps"
	SetVariable StopValue,limits={0,inf,1},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%EndFitX]
	Button DNAHandleFitLimitsButton,pos={164,93},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button DNAHandleFitLimitsButton,fColor=(61440,61440,61440)
	SetVariable DNAHandleSepWaveName,pos={7,54},size={351,16},title="Sep Wave"
	SetVariable DNAHandleSepWaveName,value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettingsStr[%Ext]
	Button DNAHandleForceButton,pos={366,31},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button DNAHandleForceButton,fColor=(61440,61440,61440)
	Button DNAHandleSepButton,pos={366,53},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button DNAHandleSepButton,fColor=(61440,61440,61440)
	SetVariable DNAHandleForceWaveName1,pos={9,261},size={351,16},title="Force Wave"
	SetVariable DNAHandleForceWaveName1,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettingsStr[%Force]
	SetVariable StartValue1,pos={8,300},size={150,16},title="Start Value"
	SetVariable StartValue1,format="%.2W1Ps"
	SetVariable StartValue1,limits={0,inf,1},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%StartFitX]
	SetVariable StopValue1,pos={9,321},size={150,16},title="Stop Value"
	SetVariable StopValue1,format="%.2W1Ps"
	SetVariable StopValue1,limits={0,inf,1},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%EndFitX]
	Button RNAFitRangeButton,pos={166,319},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button RNAFitRangeButton,fColor=(61440,61440,61440)
	SetVariable DNAHandleSepWaveName1,pos={9,280},size={351,16},title="Sep Wave"
	SetVariable DNAHandleSepWaveName1,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettingsStr[%Ext]
	Button RNAForceButton,pos={368,257},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button RNAForceButton,fColor=(61440,61440,61440)
	Button RNASepButton,pos={368,279},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button RNASepButton,fColor=(61440,61440,61440)
	SetVariable RNAFitIndex,pos={8,352},size={150,16},title="RNA Fit Index"
	SetVariable RNAFitIndex,value= _NUM:0
	Button NewRNAFitButton,pos={168,350},size={72,20},proc=RNAWLCAnalysisButtonProc,title="New RNA Fit"
	Button NewRNAFitButton,fColor=(61440,61440,61440)
	Button DeleteRNAFitButton,pos={252,350},size={87,21},proc=RNAWLCAnalysisButtonProc,title="Delete RNA Fit"
	Button DeleteRNAFitButton,fColor=(61440,61440,61440)
	SetVariable DNAHandleForceWaveName2,pos={12,518},size={351,16},title="Force Wave"
	SetVariable DNAHandleForceWaveName2,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettingsStr[%Force]
	SetVariable RNAExtWave,pos={13,578},size={351,16},title="RNA Ext"
	SetVariable RNAExtWave,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettingsStr[%RNAExt]
	Button RNACLForceButton,pos={371,514},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button RNACLForceButton,fColor=(61440,61440,61440)
	SetVariable RNACLWave,pos={13,599},size={351,16},title="RNA CL"
	SetVariable RNACLWave,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettingsStr[%RNACL]
	Button RNACLSepButton,pos={371,536},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button RNACLSepButton,fColor=(61440,61440,61440)
	SetVariable DNAHandleLcGuess,pos={9,147},size={150,16},title="Lc Guess"
	SetVariable DNAHandleLcGuess,format="%.1W1Pm"
	SetVariable DNAHandleLcGuess,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%LcGuess_DNA]
	SetVariable DNAHandleLpGuess,pos={10,126},size={150,16},title="Lp Guess"
	SetVariable DNAHandleLpGuess,format="%.1W1Pm"
	SetVariable DNAHandleLpGuess,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%LpGuess_DNA]
	SetVariable DNAHandleOffsetGuess,pos={9,190},size={150,16},title="Offset Guess"
	SetVariable DNAHandleOffsetGuess,format="%.1W1Pm"
	SetVariable DNAHandleOffsetGuess,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%OffsetGuess_DNA]
	SetVariable DNAHandleKmodGuess,pos={9,168},size={150,16},title="Kmod Guess"
	SetVariable DNAHandleKmodGuess,format="%.1W1PN"
	SetVariable DNAHandleKmodGuess,limits={0,inf,1e-11},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%KmodGuess_DNA]
	SetVariable DNAHandleLp,pos={271,128},size={150,16},title="Lp",format="%.1W1Pm"
	SetVariable DNAHandleLp,limits={-inf,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%Lp_DNA]
	SetVariable DNAHandleLc,pos={271,149},size={150,16},title="Lc",format="%.1W1Pm"
	SetVariable DNAHandleLc,limits={-inf,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%Lc_DNA]
	SetVariable DNAHandleKmod,pos={271,170},size={150,16},title="Kmod"
	SetVariable DNAHandleKmod,format="%.1W1PN"
	SetVariable DNAHandleKmod,limits={-inf,inf,1e-11},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%Kmod_DNA]
	SetVariable DNAHandleOffset,pos={271,192},size={150,16},title="Offset"
	SetVariable DNAHandleOffset,format="%.1W1Pm"
	SetVariable DNAHandleOffset,limits={-inf,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings[%Offset_DNA]
	CheckBox DNAHandleHoldLp,pos={196,128},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox DNAHandleHoldLp,value= 1
	CheckBox DNAHandleHoldLc,pos={196,148},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox DNAHandleHoldLc,value= 1
	CheckBox DNAHandleHoldKmod,pos={196,169},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox DNAHandleHoldKmod,value= 0
	CheckBox DNAHandleHoldOffset,pos={196,190},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox DNAHandleHoldOffset,value= 0
	SetVariable RNAWLC_DNAHandleLc,pos={4,404},size={115,16},title="DNA Lc"
	SetVariable RNAWLC_DNAHandleLc,format="%.1W1Pm"
	SetVariable RNAWLC_DNAHandleLc,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Lc_DNA]
	SetVariable RNAWLC_DNAHandleOffset,pos={4,447},size={131,16},title="DNA Offset"
	SetVariable RNAWLC_DNAHandleOffset,format="%.1W1Pm"
	SetVariable RNAWLC_DNAHandleOffset,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Offset_DNA]
	SetVariable RNAWLC_DNAHandleKmod,pos={4,425},size={138,16},title="DNA Kmod"
	SetVariable RNAWLC_DNAHandleKmod,format="%.1W1PN"
	SetVariable RNAWLC_DNAHandleKmod,limits={0,inf,1e-11},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Kmod_DNA]
	SetVariable RNAWLCLp,pos={365,385},size={94,16},title="Lp",format="%.1W1Pm"
	SetVariable RNAWLCLp,limits={-inf,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Lp_RNA]
	SetVariable RNAWLCLc,pos={365,407},size={94,16},title="Lc",format="%.1W1Pm"
	SetVariable RNAWLCLc,limits={-inf,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Lc_RNA]
	SetVariable RNAWLCKmod,pos={365,427},size={93,16},title="Kmod",format="%.1W1PN"
	SetVariable RNAWLCKmod,limits={-inf,inf,1e-11},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Kmod_RNA]
	SetVariable RNAWLCOffset,pos={365,448},size={91,16},title="Offset"
	SetVariable RNAWLCOffset,format="%.1W1Pm"
	SetVariable RNAWLCOffset,limits={-inf,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Offset_RNA]
	CheckBox RNAWLCHoldLp,pos={290,385},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox RNAWLCHoldLp,value= 1
	CheckBox RNAWLCHoldLc,pos={290,405},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox RNAWLCHoldLc,value= 1
	CheckBox RNAWLCHoldKmod,pos={290,426},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox RNAWLCHoldKmod,value= 1
	CheckBox RNAWLCHoldOffset,pos={290,447},size={40,14},proc=RNAWLCAnalysisCheckProc,title="Hold"
	CheckBox RNAWLCHoldOffset,value= 1
	SetVariable RNAWLC_DNAHandleLp,pos={5,384},size={112,16},title="DNA Lp"
	SetVariable RNAWLC_DNAHandleLp,format="%.1W1Pm"
	SetVariable RNAWLC_DNAHandleLp,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Lp_DNA]
	SetVariable RNAWLCLcGuess,pos={151,404},size={115,16},title="Lc Guess"
	SetVariable RNAWLCLcGuess,format="%.1W1Pm"
	SetVariable RNAWLCLcGuess,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%LcGuess_RNA]
	SetVariable RNAWLCOffsetGuess,pos={151,447},size={131,16},title="Offset Guess"
	SetVariable RNAWLCOffsetGuess,format="%.1W1Pm"
	SetVariable RNAWLCOffsetGuess,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%Offset_RNA]
	SetVariable RNAWLCKmodGuess,pos={151,425},size={138,16},title="Kmod Guess"
	SetVariable RNAWLCKmodGuess,format="%.1W1PN"
	SetVariable RNAWLCKmodGuess,limits={0,inf,1e-11},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%KmodGuess_RNA]
	SetVariable RNAWLCLpGuess,pos={152,384},size={112,16},title="Lp Guess"
	SetVariable RNAWLCLpGuess,format="%.1W1Pm"
	SetVariable RNAWLCLpGuess,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings[%LpGuess_RNA]
	Button DoDNAHandleFit,pos={161,211},size={105,20},proc=RNAWLCAnalysisButtonProc,title="Do DNA Handle Fit"
	Button DoDNAHandleFit,fColor=(61440,61440,61440)
	Button DoRNAFit,pos={153,467},size={105,20},proc=RNAWLCAnalysisButtonProc,title="Do RNA Fit"
	Button DoRNAFit,fColor=(61440,61440,61440)
	Button DoRNACL,pos={13,618},size={117,20},proc=RNAWLCAnalysisButtonProc,title="Do RNA Lc Transform"
	Button DoRNACL,fColor=(61440,61440,61440)
	SetVariable RNACL_DNAExt,pos={13,559},size={351,16},title="DNA Ext"
	SetVariable RNACL_DNAExt,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettingsStr[%DNAExt]
	SetVariable RNACL_Ext,pos={12,537},size={351,16},title="Ext Wave"
	SetVariable RNACL_Ext,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettingsStr[%Ext]
	Button InitRNAFit,pos={41,468},size={105,20},proc=RNAWLCAnalysisButtonProc,title="Init RNA Fit"
	Button InitRNAFit,fColor=(61440,61440,61440)
	SetVariable RNACL_LPSV,pos={368,565},size={98,16},title="RNA Lp"
	SetVariable RNACL_LPSV,format="%.1W1Pm"
	SetVariable RNACL_LPSV,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettings[%Lp_RNA]
	SetVariable TargetWave_HMM,pos={15,665},size={351,16},title="Target Wave"
	SetVariable TargetWave_HMM,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettingsStr[%Target]
	Button RNAExtWave_HMM,pos={13,726},size={117,20},proc=RNAWLCAnalysisButtonProc,title="RNA Ext Wave"
	Button RNAExtWave_HMM,fColor=(61440,61440,61440)
	Button RNACLWave_HMM,pos={135,725},size={117,20},proc=RNAWLCAnalysisButtonProc,title="RNA CL Wave"
	Button RNACLWave_HMM,fColor=(61440,61440,61440)
	SetVariable StateCount_HMM,pos={16,749},size={112,16},title="State Count"
	SetVariable StateCount_HMM,limits={0,inf,1},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettings[%StateCount]
	SetVariable ModeCount_HMM,pos={15,769},size={115,16},title="Mode Count"
	SetVariable ModeCount_HMM,limits={0,inf,1},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettings[%ModeCount]
	SetVariable RNAWLC_DNAHandleKmod1,pos={137,748},size={138,16},title="Drift Guess"
	SetVariable RNAWLC_DNAHandleKmod1,format="%.1W1Pm"
	SetVariable RNAWLC_DNAHandleKmod1,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettings[%DriftGuess]
	SetVariable NoiseGuess_HMM,pos={137,769},size={131,16},title="Noise Guess"
	SetVariable NoiseGuess_HMM,format="%.1W1Pm"
	SetVariable NoiseGuess_HMM,limits={0,inf,1e-09},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettings[%NoiseGuess]
	SetVariable TransitionProb_HMM,pos={279,746},size={138,16},title="Transition Prob"
	SetVariable TransitionProb_HMM,limits={0,1,0.1},value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettings[%TransitionProb]
	Button DoHMM,pos={17,790},size={117,20},proc=RNAWLCAnalysisButtonProc,title="Do HMM Fit"
	Button DoHMM,fColor=(61440,61440,61440)
	SetVariable OutputDF_HMM,pos={15,683},size={351,16},title="Output Data Folder"
	SetVariable OutputDF_HMM,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettingsStr[%OutputDataFolder]
	SetVariable OutputName_HMM,pos={17,703},size={351,16},title="Output Name"
	SetVariable OutputName_HMM,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettingsStr[%OutputName]
EndMacro
  
Function RNAWLCAnalysisButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ControlName=ba.ctrlname
	
	Wave DNAHandleFitSettings=root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings
	Wave/T DNAHandleFitSettingsStr=root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettingsStr
	Wave RNAWLCFitSettings=root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings
	Wave/T RNAWLCFitSettingsStr=root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettingsStr
	Wave RNACLSettings=root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettings
	Wave/T RNACLSettingsStr=root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettingsStr
	Wave RNAHMMSettings=root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettings
	Wave/T RNAHMMSettingsStr=root:RNAPulling:Analysis:RNAWLCAnalysis:RNAHMMSettingsStr

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
				StrSwitch(ControlName)
					case "DoDNAHandleFit":
						Wave DNAHandleForce=$DNAHandleFitSettingsStr[%Force]
						Wave DNAHandleExt=$DNAHandleFitSettingsStr[%Ext]
						Duplicate/O/R=(DNAHandleFitSettings[%StartFitX],DNAHandleFitSettings[%EndFitX]) DNAHandleForce, DNAHandleForceSegment
						Duplicate/O/R=(DNAHandleFitSettings[%StartFitX],DNAHandleFitSettings[%EndFitX]) DNAHandleExt, DNAHandleExtSegment
						WLCFit(DNAHandleForceSegment,DNAHandleExtSegment,"ExtensibleWLC",CLGuess=DNAHandleFitSettings[%LcGuess_DNA],PLGuess=DNAHandleFitSettings[%LpGuess_DNA],StretchModulus=DNAHandleFitSettings[%KModGuess_DNA],Offset=DNAHandleFitSettings[%OffsetGuess_DNA],HoldPL=DNAHandleFitSettings[%HoldLp_DNA],HoldCL=DNAHandleFitSettings[%HoldLc_DNA],HoldStretchModulus=DNAHandleFitSettings[%HoldKmod_DNA],HoldOffset=DNAHandleFitSettings[%HoldOffset_DNA])
						Wave WLC_Coeff
						DNAHandleFitSettings[%Lc_DNA]=WLC_Coeff[1]
						DNAHandleFitSettings[%Lp_DNA]=WLC_Coeff[0]
						DNAHandleFitSettings[%Kmod_DNA]=WLC_Coeff[2]
						DNAHandleFitSettings[%Offset_DNA]=WLC_Coeff[3]
						RNAWLCFitSettings[%Lc_DNA]=WLC_Coeff[1]
						RNAWLCFitSettings[%Lp_DNA]=WLC_Coeff[0]
						RNAWLCFitSettings[%Kmod_DNA]=WLC_Coeff[2]
						RNAWLCFitSettings[%Offset_DNA]=WLC_Coeff[3]
						
						WLCGuide("ExtensibleWLC",DNAHandleFitSettings[%Lc_DNA],DNAHandleFitSettings[%Lp_DNA],ForceWaveName="DNAHandleForceGuide",SepWaveName="DNAHandleSepGuide",Offset=DNAHandleFitSettings[%Offset_DNA],StretchModulus=DNAHandleFitSettings[%Kmod_DNA],MaxForce=30e-12)

					break
					case "InitRNAFit":
						Make/O/N=4 DNAWLC_Coeff
						Wave DNAWLC_Coeff=DNAWLC_Coeff
						DNAWLC_Coeff[0]=DNAHandleFitSettings[%Lp_DNA]
						DNAWLC_Coeff[1]=DNAHandleFitSettings[%Lc_DNA]
						DNAWLC_Coeff[2]=DNAHandleFitSettings[%Kmod_DNA]
						DNAWLC_Coeff[3]=DNAHandleFitSettings[%Offset_DNA]
						Wave Ext=$RNAWLCFitSettingsStr[%Ext]
						Wave Force=$RNAWLCFitSettingsStr[%Force]
						Duplicate/O Force, $RNAWLCFitSettingsStr[%DNAExt]
						Wave DNAExtension=MakeDNAHandleExt(Force,DNAWLC_Coeff,DNAExtName=RNAWLCFitSettingsStr[%DNAExt],DNAExt_LowerBound=WaveMin(Ext))
						
						MakeRNAExt(Force, Ext, DNAExtension,RNAExtName=RNAWLCFitSettingsStr[%RNAExt])
					
					break
					case "DoRNAFit":
						Wave RNAExtension=$RNAWLCFitSettingsStr[%RNAExt]
						Wave RNAForce=$RNAWLCFitSettingsStr[%Force]
						Duplicate/O/R=(RNAWLCFitSettings[%StartFitX],RNAWLCFitSettings[%EndFitX]) RNAExtension, RNAExtensionSegment
						Duplicate/O/R=(RNAWLCFitSettings[%StartFitX],RNAWLCFitSettings[%EndFitX]) RNAForce, RNAForceSegment

						WLCFit(RNAForceSegment,RNAExtensionSegment,"WLC",CLGuess=RNAWLCFitSettings[%LcGuess_RNA],PLGuess=RNAWLCFitSettings[%LpGuess_RNA],StretchModulus=RNAWLCFitSettings[%KMod_RNA],Offset=RNAWLCFitSettings[%OffsetGuess_RNA],HoldPL=RNAWLCFitSettings[%HoldLp_RNA],HoldCL=RNAWLCFitSettings[%HoldLc_RNA],HoldStretchModulus=RNAWLCFitSettings[%HoldKmod_RNA],HoldOffset=RNAWLCFitSettings[%HoldOffset_RNA])
						Wave WLC_Coeff
						RNAWLCFitSettings[%Lc_RNA]=WLC_Coeff[1]
						RNAWLCFitSettings[%Lp_RNA]=WLC_Coeff[0]
						
						WLCGuide("WLC",RNAWLCFitSettings[%Lc_RNA],RNAWLCFitSettings[%Lp_RNA],ForceWaveName="RNAForceGuide",SepWaveName="RNASepGuide",Offset=RNAWLCFitSettings[%Offset_RNA],StretchModulus=RNAWLCFitSettings[%Kmod_RNA],MaxForce=30e-12)
						
					break
					case "DoRNACL":
						Make/O/N=4 DNAWLC_Coeff
						Wave DNAWLC_Coeff=DNAWLC_Coeff
						DNAWLC_Coeff[0]=DNAHandleFitSettings[%Lp_DNA]
						DNAWLC_Coeff[1]=DNAHandleFitSettings[%Lc_DNA]
						DNAWLC_Coeff[2]=DNAHandleFitSettings[%Kmod_DNA]
						DNAWLC_Coeff[3]=DNAHandleFitSettings[%Offset_DNA]
						Wave Ext=$RNACLSettingsStr[%Ext]
						Wave Force=$RNACLSettingsStr[%Force]
						Duplicate/O Force, $RNACLSettingsStr[%DNAExt]
						Wave DNAExtension=MakeDNAHandleExt(Force,DNAWLC_Coeff,DNAExtName=RNACLSettingsStr[%DNAExt],DNAExt_LowerBound=WaveMin(Ext))
						Wave RNAExtension=MakeRNAExt(Force, Ext, DNAExtension,RNAExtName=RNACLSettingsStr[%RNAExt])
						MakeRNALcWave(Force,RNAExtension,Lp=RNACLSettings[%Lp_RNA],RNACLName=RNACLSettingsStr[%RNACL])
						
					break
					case "DoHMM":
						SetDataFolder $RNAHMMSettingsStr[%OutputDataFolder]
						Wave Target=$RNAHMMSettingsStr[%Target]
						Duplicate/O Target,HMMTarget				
						HMMTarget*=1e9
						DriftMarkovFit(HMMTarget, RNAHMMSettings[%StateCount],  RNAHMMSettings[%ModeCount],  RNAHMMSettings[%DriftGuess]*1e9, RNAHMMSettings[%NoiseGuess]*1e9, RNAHMMSettings[%TransitionProb],10)
					break
					case "NewRNAFitButton":
					break
					case "DeleteRNAFitButton":
					break
					case "DNAHandleForceButton":
					case "DNAHandleSepButton":
					case "DNAHandleFitLimitsButton":
					case "RNAForceButton":
					case "RNASepButton":
					case "RNAFitRangeButton":
					case "RNACLForceButton":
					case "RNACLSepButton":
						// Get x values and wave name for wave with cursors on it..
						Variable StartX=xcsr(A)
						Variable EndX=xcsr(B)
						String TargetWaveName=GetWavesDataFolder(CsrWaveRef(A),2)
						String TargetXWaveName=GetWavesDataFolder(CsrXWaveRef(A),2)
						StrSwitch(ControlName)
							case "DNAHandleForceButton":
								DNAHandleFitSettingsStr[%Force]=TargetWaveName
								DNAHandleFitSettingsStr[%Ext]=TargetXWaveName								
							break
							case "DNAHandleSepButton":
								DNAHandleFitSettingsStr[%Ext]=TargetWaveName
							break
							case "DNAHandleFitLimitsButton":
								DNAHandleFitSettings[%StartFitX]=StartX
								DNAHandleFitSettings[%EndFitX]=EndX
							break
							case "RNAForceButton":
								RNAWLCFitSettingsStr[%Force]=TargetWaveName
								RNAWLCFitSettingsStr[%Ext]=TargetXWaveName								
							break
							case "RNASepButton":
								RNAWLCFitSettingsStr[%Ext]=TargetWaveName								
							break
							case "RNAFitRangeButton":
								RNAWLCFitSettings[%StartFitX]=StartX
								RNAWLCFitSettings[%EndFitX]=EndX
							break
							case "RNACLForceButton":
								RNACLSettingsStr[%Force]=TargetWaveName
								RNACLSettingsStr[%Ext]=TargetXWaveName								
							break
							case "RNACLSepButton":
								RNACLSettingsStr[%Ext]=TargetWaveName														
							break
						
						EndSwitch
					break
					
				EndSwitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function RNAWLCAnalysisCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	Wave DNAHandleFitSettings=root:RNAPulling:Analysis:RNAWLCAnalysis:DNAHandleFitSettings
	Wave RNAWLCFitSettings=root:RNAPulling:Analysis:RNAWLCAnalysis:RNAWLCFitSettings
	String ControlName=cba.ctrlname

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
				StrSwitch(ControlName)
					case "DNAHandleHoldLp":
						DNAHandleFitSettings[%HoldLp_DNA]=checked
					break
					case "DNAHandleHoldLc":
						DNAHandleFitSettings[%HoldLc_DNA]=checked
					break
					case "DNAHandleHoldKmod":
						DNAHandleFitSettings[%HoldKmod_DNA]=checked
					break
					case "DNAHandleHoldOffset":
						DNAHandleFitSettings[%HoldOffset_DNA]=checked
					break
					case "RNAWLCHoldLp":
						RNAWLCFitSettings[%HoldLp_RNA]=checked
					break
					case "RNAWLCHoldLc":
						RNAWLCFitSettings[%HoldLc_RNA]=checked
					break
					case "RNAWLCHoldKmod":
						RNAWLCFitSettings[%HoldKmod_RNA]=checked
					break
					case "RNAWLCHoldOffset":
						RNAWLCFitSettings[%HoldOffset_RNA]=checked
					break
				
				EndSwitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
