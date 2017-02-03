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

Function/Wave DNAHandleExt(Extension,WLC_Coeffs)
	Wave Extension,WLC_Coeffs
	Duplicate/O Extension, DNAExt
	DNAExt=ExtensibleWLCHighForce(WLC_Coeffs,x)
	Return DNAExt
End

Function/Wave RNAExt(Force, Ext, DNAExt)
	Wave Force,Ext, DNAExt
	Duplicate Ext, RNAExt
	RNAExt=Ext[p]-DNAExt(Force[p])
	Return RNAExt
End

Function/Wave RNACL(Force,RNAExt,[Lp,RNACLName])
	Wave Force,RNAExt
	Variable Lp
	String RNACLName
	If(ParamIsDefault(Lp)) // Default RNA persistence length is 1nm
		Lp=1e-9
	EndIf
	If(ParamIsDefault(RNACLName))
		RNACLName="root:RNACLAnalysis:RNACL"
	EndIf
	MakeContourLengthWave(Force,RNAExt,PersistenceLength=Lp,CLName=RNACLName,MoleculeType="None")
	Wave RNACLWave=$RNACLName
	Return RNACLWave
End

Window RNAWLCPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1254,68,1723,703) as "RNA WLC"
	SetDrawLayer UserBack
	DrawLine 6,229,444,229
	SetDrawEnv fsize= 14
	DrawText 9,26,"DNA Handles WLC Fit"
	DrawLine 14,485,452,485
	SetDrawEnv fsize= 14
	DrawText 10,252,"RNA WLC Fit"
	SetDrawEnv fsize= 14
	DrawText 13,509,"RNA Contour Length Space"
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
	SetVariable RNAExtWave,pos={12,537},size={351,16},title="RNA Ext"
	SetVariable RNAExtWave,value= root:RNAPulling:Analysis:RNAWLCAnalysis:RNACLSettingsStr[%RNAExt]
	Button RNACLForceButton,pos={371,514},size={72,20},proc=RNAWLCAnalysisButtonProc,title="From Cursors"
	Button RNACLForceButton,fColor=(61440,61440,61440)
	SetVariable RNACLWave,pos={12,558},size={351,16},title="RNA CL"
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
	CheckBox RNAWLCHoldLc,value= 0
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
EndMacro

Function RNAWLCAnalysisButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function RNAWLCAnalysisCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
