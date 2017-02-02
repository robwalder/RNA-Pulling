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
	Execute/Q "RNAWLCPanel()"
End

Function/Wave WLCFitDNAHandles(Force,Sep,[Lp,Lc,Kmod,Offset,])
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
	NewPanel /W=(1299,85,1599,285) as "RNA WLC"
EndMacro
