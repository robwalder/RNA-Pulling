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
	NewPanel /W=(1303,177,1804,694) as "RNA WLC"
	SetDrawLayer UserBack
	DrawLine 6,229,444,229
	SetDrawEnv fsize= 14
	DrawText 9,26,"DNA Handles WLC Fit"
	DrawLine 6,376,444,376
	SetDrawEnv fsize= 14
	DrawText 10,252,"RNA WLC Fit"
	SetDrawEnv fsize= 14
	DrawText 5,400,"RNA Contour Length Space"
	SetVariable DNAHandleForceWaveName,pos={7,35},size={351,16},title="Force Wave"
	SetVariable DNAHandleForceWaveName,value= root:EquilibriumELR:GetWaveSettingsStr[%EquilibriumWaveName]
	SetVariable StartValue,pos={6,74},size={150,16},title="Start Value"
	SetVariable StartValue,value= root:EquilibriumELR:GetWaveSettings[%StartX]
	SetVariable StopValue,pos={7,95},size={150,16},title="Stop Value"
	SetVariable StopValue,value= root:EquilibriumELR:GetWaveSettings[%EndX]
	Button FromCursors,pos={164,93},size={72,20},proc=GetWaveFromGraphButtonProc,title="From Cursors"
	Button FromCursors,fColor=(61440,61440,61440)
	SetVariable DNAHandleSepWaveName,pos={7,54},size={351,16},title="Sep Wave"
	SetVariable DNAHandleSepWaveName,value= root:EquilibriumELR:GetWaveSettingsStr[%EquilibriumWaveName]
	Button FromCursors1,pos={366,31},size={72,20},proc=GetWaveFromGraphButtonProc,title="From Cursors"
	Button FromCursors1,fColor=(61440,61440,61440)
	Button FromCursors2,pos={366,53},size={72,20},proc=GetWaveFromGraphButtonProc,title="From Cursors"
	Button FromCursors2,fColor=(61440,61440,61440)
	SetVariable DNAHandleForceWaveName1,pos={9,261},size={351,16},title="Force Wave"
	SetVariable DNAHandleForceWaveName1,value= root:EquilibriumELR:GetWaveSettingsStr[%EquilibriumWaveName]
	SetVariable StartValue1,pos={8,300},size={150,16},title="Start Value"
	SetVariable StartValue1,value= root:EquilibriumELR:GetWaveSettings[%StartX]
	SetVariable StopValue1,pos={9,321},size={150,16},title="Stop Value"
	SetVariable StopValue1,value= root:EquilibriumELR:GetWaveSettings[%EndX]
	Button FromCursors3,pos={166,319},size={72,20},proc=GetWaveFromGraphButtonProc,title="From Cursors"
	Button FromCursors3,fColor=(61440,61440,61440)
	SetVariable DNAHandleSepWaveName1,pos={9,280},size={351,16},title="Sep Wave"
	SetVariable DNAHandleSepWaveName1,value= root:EquilibriumELR:GetWaveSettingsStr[%EquilibriumWaveName]
	Button FromCursors4,pos={368,257},size={72,20},proc=GetWaveFromGraphButtonProc,title="From Cursors"
	Button FromCursors4,fColor=(61440,61440,61440)
	Button FromCursors5,pos={368,279},size={72,20},proc=GetWaveFromGraphButtonProc,title="From Cursors"
	Button FromCursors5,fColor=(61440,61440,61440)
	SetVariable RNAFitIndex,pos={8,352},size={150,16},title="RNA Fit Index"
	SetVariable RNAFitIndex,value= root:EquilibriumELR:GetWaveSettings[%EndX]
	Button NewRNAFitButton,pos={168,350},size={72,20},proc=GetWaveFromGraphButtonProc,title="New RNA Fit"
	Button NewRNAFitButton,fColor=(61440,61440,61440)
	Button DeleteRNAFitButton,pos={252,350},size={87,21},proc=GetWaveFromGraphButtonProc,title="Delete RNA Fit"
	Button DeleteRNAFitButton,fColor=(61440,61440,61440)
	SetVariable DNAHandleForceWaveName2,pos={4,409},size={351,16},title="Force Wave"
	SetVariable DNAHandleForceWaveName2,value= root:EquilibriumELR:GetWaveSettingsStr[%EquilibriumWaveName]
	SetVariable RNAExtWave,pos={4,428},size={351,16},title="RNA Ext"
	SetVariable RNAExtWave,value= root:EquilibriumELR:GetWaveSettingsStr[%EquilibriumWaveName]
	Button FromCursors6,pos={363,405},size={72,20},proc=GetWaveFromGraphButtonProc,title="From Cursors"
	Button FromCursors6,fColor=(61440,61440,61440)
	SetVariable RNACLWave,pos={4,449},size={351,16},title="RNA CL"
	SetVariable RNACLWave,value= root:EquilibriumELR:GetWaveSettingsStr[%EquilibriumWaveName]
EndMacro
