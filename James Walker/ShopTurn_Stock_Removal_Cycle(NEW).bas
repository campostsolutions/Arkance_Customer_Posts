'#Language "WWB-COM"

Option Explicit

Dim SR_X0 As Double
Dim SR_Z0 As Double
Dim SR_X1 As Double
Dim SR_Z1 As Double
Dim SR_D  As Double
Dim SR_UX As Double
Dim SR_UZ As Double

Dim udf_stock_removal 	 As FMUserFeatureRegister
Dim udfo_stock_removal 	 As FMUserOperationRegister

Private Sub AddIn_OnConnect(ByVal flags As FeatureCAM.tagFMAddInFlags)
	If Not Application.Documents.Count = 0 Then
		ActiveDocument.InvalidateToolpaths
	End If

	Set udf_stock_removal = Application.RegisterUserFeature( "StockRemoval", eST_Turning, "Stock Removal", eUDF_PickLocation)
	udf_stock_removal.AddDataDefinition ( "Ref. point X Rad [abs]", eUDT_None)
	SR_X0 = udf_stock_removal.AddDataDefinition ( "X0 = ", eUDT_PickX, 0, 0)
	udf_stock_removal.AddDataDefinition ( "Ref. point Z [inc]", eUDT_None)
	SR_Z0 = udf_stock_removal.AddDataDefinition ( "Z0 = ", eUDT_PositiveDouble, 0, 0)
	udf_stock_removal.AddDataDefinition ( "End pont X Rad [abs]", eUDT_None)
	SR_X1 = udf_stock_removal.AddDataDefinition ( "X1 = ", eUDT_PickX, 0, 0)
'	df_stock_removal.AddDataDefinition ( "End pont Z [abs]", eUDT_None)
'	SR_Z1 = udf_stock_removal.AddDataDefinition ( "Z1 = ", eUDT_PickZ, 0, 0)
	udf_stock_removal.AddDataDefinition ( "Maximum Infeed", eUDT_None)
	SR_D  = udf_stock_removal.AddDataDefinition ( "D = ", eUDT_Double, 0, 0)
	udf_stock_removal.AddDataDefinition ( "Finishing allowance in X", eUDT_None)
	SR_UX = udf_stock_removal.AddDataDefinition ( "UX", eUDT_Double, 0.000, 0.0004)
	udf_stock_removal.AddDataDefinition ( "Finishing allowance in Z", eUDT_None)
	SR_UZ = udf_stock_removal.AddDataDefinition ( "UZ", eUDT_Double, 0.005, 0.0004)

	Set udfo_stock_removal = Application.RegisterUserOperation("StockRemoval","Rough Face",eTG_TurnOD, eST_Turning)
	udfo_stock_removal.AddAttributeDefinition2(eAID_Priority)
	udfo_stock_removal.AddAttributeDefinition2(eAID_CannedXClear)
	udfo_stock_removal.AddAttributeDefinition2(eAID_CannedZClear)

End Sub

Private Sub AddIn_OnDisConnect(ByVal flags As FeatureCAM.tagFMAddInFlags)
	Set udf_stock_removal = Nothing
End Sub

Private Sub Application_UserFeatureVerify(Doc As FeatureCAM.FMDocument, UDF As FeatureCAM.FMUserFeature, valid As Variant, error_message As String)
	Dim oper As FMOperation
	Dim UDO As FMUserOperation
		Dim bore_max_z As Double
	Dim bore_min_z As Double
	Dim fast_feed  As Double
	Dim cut_feed   As Double
	Dim dwell_time As Double

	Dim X0 As Double
	Dim Z0 As Double
	Dim X1 As Double
'	Dim Z1 As Double
	Dim D  As Double
	Dim UX As Double
	Dim UZ As Double

	'valid = False

' backbore  ----------------------------------------------------

	If( UDF.RegisteredName = udf_stock_removal.Name) Then
		X0 = UDF.GetData( SR_X0 )
		Z0 = UDF.GetData( SR_Z0 )
		X1 = UDF.GetData( SR_X1 )
		D  = UDF.GetData( SR_D )
		UX = UDF.GetData( SR_UX )
		UZ = UDF.GetData( SR_UZ )

		Set UDO = UDF.AddUserOperation(udfo_stock_removal.Name, X0, Z0, X1, D, UX, UZ )
		UDO.SetAttribute(eAID_Priority,,1)

		valid = True

	End If

' ----------------------------------------------------

	If valid Then

		UDF.AddCrossSectionLinear( 0, X0)
		UDF.AddCrossSectionLinear( 0, X1)

	End If

End Sub

Private Sub Application_UserOperationDefaultTool(UDO As FeatureCAM.FMUserOperation, tool_name As String, valid As Variant, Crib As FeatureCAM.FMToolCrib)

	Dim tools As FMTools
	Dim tool As FMTool

	'handler for the tool selection for the UDOs
	If( UDO.RegisteredName = udfo_stock_removal.Name ) Then

		Set tools = Crib.TurningTools
		Dim LT As FMLatheTool

		For Each tool In tools
			Set LT = tool

			If LT.HolderOrientation = eTHO_SW And LT.InsertShape = eTIS_Dia_80 And LT.angle = 5 Then
				tool_name = tool.Name
			End If

		Next tool

		valid = True

	End If

End Sub

Private Sub Application_UserOperationFeedSpeed(UDO As FeatureCAM.FMUserOperation, feed As Double, speed As Double, valid As Variant)
	'handler to calculate the speed/feed of the operation
	Dim dia As Double

	If( UDO.RegisteredName = udfo_stock_removal.Name ) Then
		dia = UDO.GetArgument(0)
		UDO.TurnFeedSpeed( feed, speed, dia, eFSOT_TurnFace, False )
		valid = True
	End If

End Sub

Private Sub Application_UserOperationToolPath(UDO As FeatureCAM.FMUserOperation, valid As Variant)

	'handler to create the toolpaths for the UDO
	Dim CannnedX 	As Double, CannnedZ			As Double
	Dim XM			As Double, ZM				As Double
	Dim ZF			As Double, StpOv			As Double
	Dim clearence	As Double
	Dim Last_Cut	As Boolean

	Dim T	As String
	Dim F	As Double
	Dim V	As Double
	Dim X0	As Double
	Dim Z0	As Double
	Dim X1	As Double
	Dim Z1	As Double
	Dim D	As Double
	Dim UX	As Double
	Dim UZ	As Double
	Dim i		As Integer
	Dim TR 		As Double
i = 0

Dim UFeat As FeatureCAM.FMUserFeature

	If( UDO.RegisteredName = udfo_stock_removal.Name ) Then
		If ActiveDocument.Metric Then
			clearence = 1
		Else
			clearence = 0.0394
		End If

		CannnedX	= UDO.Attribute(eAID_CannedXClear)
		CannnedZ	= UDO.Attribute(eAID_CannedZClear)
		T  = Chr(34) & UDO.Tool.Name & Chr(34)
		If ActiveDocument.Metric Then
			If UDO.Attribute(eAID_TurnFeedUnit) = 323 Then
				F  = Round(UDO.Feed,2)
			Else
				F  = Round(UDO.Feed,0)
			End If
		Else
			If UDO.Attribute(eAID_TurnFeedUnit) = 323 Then
				F  = Round(UDO.Feed,4)
			Else
				F  = Round(UDO.Feed,2)
			End If
		End If
		V  = UDO.Speed
		X0 = UDO.GetArgument(0)
		Z0 = UDO.GetArgument(1)
		X1 = UDO.GetArgument(2)
		D  = UDO.GetArgument(3)
		UX = UDO.GetArgument(4)
		UZ = UDO.GetArgument(5)
		TR = TipRad(UDO.Tool,ActiveDocument.Metric)
'		MsgBox CStr(TR)

		UDO.Feature.GetFeatureLocation(,,,Z1)
		ZF = UZ + TR

		'====Convert D to a real value against overall length - Z finishing allowance====
		StpOv = RoundA(((Z0 - Z1)-UZ)/D)
		StpOv = ((Z0 - Z1)-UZ)/StpOv

		'====Positioning Tool====
		XM = X0 + CannnedX + TR
		ZM = Z0 + CannnedZ + TR
		UDO.AddRapidMove2( XM, 0, ZM) 'Rapid to canned clear in X0 (OD) & Z1 (Front of stock)

		ZM = Z0 + clearence + TR
		UDO.AddRapidMove2( XM, 0, ZM,,,True) 'Rapid to canned clear in X0 (OD) & Z1 (Front of stock)

		UDO.AddPostedText(SRC(T,F,V,X0,Z0,X1-TR,Z1,D,UX,UZ)) 'Output Stock Removal cycle

		ZM = Z0 + TR
		Do
			i = i + 1
'			If (ZM-D-(TR*2)) <= UZ Then' Interactive stepover cut from previous pos
			If ( Z0 - ( StpOv * i ) ) <= UZ Then' Calculated stepover cut from number of cuts previously generated.
				ZM = ZF
				Last_Cut = True
			Else
				ZM = Z0 + TR - ( StpOv * i )
			End If
			XM = X0 + clearence + TR
			UDO.AddLinearMove2( XM, 0, ZM,,,eUDOFT_SetFeedRate,,True) 'Feed in Z to cut position
			XM = X1
			UDO.AddLinearMove2( XM, 0, ZM,,,eUDOFT_SetFeedRate,,True) 'Feed down past part
			XM = XM + clearence
			ZM = ZM + clearence
			UDO.AddLinearMove2( XM, 0, ZM,,,eUDOFT_SetFeedRate,,True) 'Feed + in X & Z using clearence as distance
			If Not Last_Cut Then
				XM = X0 + clearence + TR
				UDO.AddRapidMove2( XM, 0, ZM,,,True)
			End If
		Loop Until Last_Cut = True Or i = 100

		' XM = X0 + clearence + TR
		ZM = Z0 + clearence + TR
		UDO.AddLinearMove( XM, 0, ZM)
		UDO.AddRapidMove( XM, 0, ZM) 'Rapid to canned clear in X0 (OD) & Z1 (Front of stock)

		valid = True

	End If
End Sub

Function TipRad( tool As FMTool, IsMet As Boolean ) As Double

		If TypeName(tool) = "IFMLatheTool" Then
			Dim Conv As Double, Dp As Integer
			Dim LT As FMLatheTool

			Set LT = tool

			If (IsMet = True) And (LT.Metric = False) Then
				Conv = 25.4
			ElseIf (IsMet = False) And (LT.Metric = True) Then
				Conv = (1/25.4)
			Else
				Conv = 1
			End If

			If IsMet Then
				Dp = 3
			Else
				Dp = 4
			End If

			TipRad = Round( LT.InsertTipRadius * Conv, Dp)
		End If

End Function

Function SRC(T As String, F As Double, V As Double, X0 As Double, Z0 As Double, X1 As Double, Z1 As Double, D As Double, UX As Double, UZ As Double) As String

	Dim SRC_Vars(31) As String

	SRC_Vars(0) =	T	'	Tl Name
	SRC_Vars(1) =	Chr(34) & Chr(34)	'	N/A
	SRC_Vars(2) =	"1"	'	Edge No
	SRC_Vars(3) =	CStr(F)	'	Feedrate
	SRC_Vars(4) =	"3"	'	N/A
	SRC_Vars(5) =	CStr(V)	'	Speed
	SRC_Vars(6) =	"2"	'	N/A
	SRC_Vars(7) =	"0"	'	N/A
	SRC_Vars(8) =	"1"	'	Roughing/Fin 1 = Rough 2=Finish
	SRC_Vars(9) =	"5"	'	Stock removal direction 0=LO NW 1=LO. NE 2=LO SW 3=LO. SE 4=FA. SE 5=FA. NE 6=FA. SW 7=FA. NW
	SRC_Vars(10) =	CStr(X0)	'	Ref. Point Ø
	SRC_Vars(11) =	"90"	'	90=absolute 91=inc
	SRC_Vars(12) =	CStr(Z0+Z1)	'	Ref. Point
	SRC_Vars(13) =	"90"	'	90=absolute 91=inc
	SRC_Vars(14) =	CStr(X1)	'	End pont X1 Ø
	SRC_Vars(15) =	"90"	'	90=absolute 91=inc
	SRC_Vars(16) =	CStr(Z1)	'	End pont Z1
	SRC_Vars(17) =	"90"	'	90=absolute 91=inc
	SRC_Vars(18) =	CStr(X0-X1)	'	overall radius dimension
	SRC_Vars(19) =	"91"	'	90=absolute 91=inc
	SRC_Vars(20) =	CStr(Z0-Z1)	'	overall length dimension
	SRC_Vars(21) =	"91"	'	90=absolute 91=inc
	SRC_Vars(22) =	"0"	'	5=a1/a2
	SRC_Vars(23) =	"0"	'	RAD OR CHAM 1
	SRC_Vars(24) =	"0"	'	RADIUS 2
	SRC_Vars(25) =	"0"	'	RADIUS 3
	SRC_Vars(26) =	CStr(D)	'	maximum infeed
	SRC_Vars(27) =	CStr(UX)	'	Finishing allowance in X
	SRC_Vars(28) =	CStr(UZ)	'	Finishing allowance in Z
	SRC_Vars(29) =	"0"	'	0=STK REM 1 1=STK REM 2 2=STK REM 3
	SRC_Vars(30) =	"90"	'	a1
	SRC_Vars(31) =	"90"	'	a2


SRC =	"*1("'	"F_ROUGH("
Dim i As Integer, n As Integer
i = 0
n = UBound(SRC_Vars)

Do
	If i = n Then
		SRC = SRC + SRC_Vars(i)
	Else
		SRC = SRC + SRC_Vars(i) & ","
	End If

	i=i+1
Loop Until i = n+1
SRC = SRC + ")"

End Function


Function RoundA( var As Double ) As Double
Dim a As Integer, b As Double
	a = Int(var)
	b = var - a

	If b < 0.5 Then
		RoundA = a
	Else
		RoundA = var+(1-b)
	End If
End Function
