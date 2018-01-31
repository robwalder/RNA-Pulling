#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0
#include ":ChopRNAPulls"
#pragma ModuleName = RNAViewer


Static Function/Wave FinalAllIterations([SavedDataDF])
	String SavedDataDF
	If(ParamIsDefault(SavedDataDF))
		SavedDataDF="root:RNAPulling:SavedData:"
	EndIf
	
	SetDataFolder $SavedDataDF
	String AllDefV=WaveList("DefV*",";","")
	Variable NumDefV=ItemsInList(AllDefV)
	Make/O/N=(NumDefV) Iterations
	Variable Counter=0
	String RawWaveName="DefV"
	String IterationString="0"
	For(Counter=0;Counter<NumDefV;Counter+=1)
		RawWaveName=StringFromList(Counter,AllDefV)
		IterationString=RawWaveName[4,strlen(RawWaveName)]
		Iterations[Counter]=str2num(IterationString)
	EndFor
	
	Return Iterations
End

Static Function FindMinIteration()
	Wave Iterations=FinalAllIterations()
	Return WaveMin(Iterations)
End

Static Function FindMaxIteration()
	Wave Iterations=FinalAllIterations()
	Return WaveMax(Iterations)
End