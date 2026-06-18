'#Reference {420B2830-E718-11CF-893D-00A0C9054228}#1.0#0#C:\Windows\System32\scrrun.dll#Microsoft Scripting Runtime#Scripting
Option Explicit

Private Sub Application_PostNCCreate(doc As FeatureCAM.MFGDocument, _
            ByVal nc_file_name As String, ByVal macro_file_cnt As Long, _
            ByVal macro_file_names As Variant)

    Dim extension_index As Integer, temp_file_name As String
    nc_file_name = UCase(nc_file_name)
    extension_index = InStrRev(nc_file_name, ".TXT")
    temp_file_name = Left$(nc_file_name, extension_index - 1) + ".tmp"

    Open nc_file_name For Input As #1
    Open temp_file_name For Output As #2

    Dim tool_list_word As String, found_tool_word As Boolean
    Dim buffer As String, i As Integer

    tool_list_word = "(TOOL-LIST)"
    found_tool_word = False

    Dim Stri As String
    Dim seq_cnt As Long
    Dim seq_act As Boolean
    Dim Block_Inc As Double
    Dim Block_Str As Double

    Block_Inc = doc.Application.PostOptionsTurn.BlockIncr
    Block_Str = doc.Application.PostOptionsTurn.BlockStart

    If Not (Block_Inc = 0 And Block_Str = 0) Then
        seq_act = True
    End If

    ' -----------------------------
    ' READ HEADER / FIND TOOL LIST
    ' -----------------------------
    Do
        Line Input #1, buffer
        buffer = UCase(buffer)

        ' SAFE sequence extraction
        If (Left(buffer, 1) = "N") And seq_act Then
            Dim spcPos As Integer
            spcPos = InStr(buffer, " ")

            If spcPos > 2 Then
                Stri = Mid(buffer, 2, spcPos - 2)
            Else
                Stri = ""
            End If
        End If

        If (InStrRev(buffer, tool_list_word) = 0) Then
            Print #2, buffer
        Else
            found_tool_word = True

            ' SAFE conversion (no crash)
            If IsNumeric(Stri) Then
                seq_cnt = CLng(Stri)
            Else
                seq_cnt = Block_Str   ' fallback start
            End If

            Exit Do
        End If

        i = i + 1
    Loop While i < 30

    ' -----------------------------
    ' TOOL LIST OUTPUT
    ' -----------------------------
    Dim Tl_Mp As FMToolMap
    Dim Tl_Mp_2 As FMToolMap2
    Dim Cmt_Chr_S As String, Cmt_Chr_E As String
    Dim post_name As String
    Dim seq As String

    Set doc = ActiveDocument

    post_name = doc.Application.PostOptionsTurn.CncFileName
    post_name = Mid(post_name, InStrRev(post_name, "\") + 1, Len(post_name) - InStrRev(post_name, "\"))

    Dim post_upper As String
post_upper = UCase(post_name)
    ' KEEP EXISTING CONTROLLER LOGIC
   If InStr(post_upper, "PHILLIPS") > 0 Then
    Cmt_Chr_S = "("
    Cmt_Chr_E = ")"

   ElseIf InStr(post_upper, "MAZAK-INTEGREX-I") > 0 Then
    Cmt_Chr_S = "("
    Cmt_Chr_E = ")"
   Else
    Cmt_Chr_S = "; "
    Cmt_Chr_E = ""
   End If

    If seq_act Then
        seq_cnt = seq_cnt + Block_Inc
        seq = "N" & CStr(seq_cnt) & " "
    Else
        seq = CStr(seq_cnt + Block_Inc)   ' FIXED (was string concat)
    End If

    If InStr(post_upper, "MAZAK-INTEGREX-I") > 0 Then
    	Print #2, Cmt_Chr_S & "TOOLING" & Cmt_Chr_E
    Else
		Print #2, seq & Cmt_Chr_S & "TOOLING" & Cmt_Chr_E
End If
    For Each Tl_Mp In doc.ToolMaps
        Set Tl_Mp_2 = Tl_Mp

        If Not Tl_Mp_2.ToolReservedInCribButNotUsed Then

            If seq_act Then
                seq_cnt = seq_cnt + 1
                seq = "N" & CStr(seq_cnt) & " "
            End If

          If InStr(post_upper, "MAZAK-INTEGREX-I") > 0 Then

    ' Mazak format
    Print #2, Cmt_Chr_S & "T" & _
        CStr$(Tl_Mp_2.ToolNumber) & " - " & _
        UCase(Tl_Mp_2.Tool.Name) & Cmt_Chr_E

Else

    ' Default (Siemens / Philips etc)
    Print #2, seq & Cmt_Chr_S & "TURRET POSITION " & _
        CStr$(Tl_Mp_2.ToolNumber) & " = " & _
        UCase(Tl_Mp_2.Tool.Name) & Cmt_Chr_E

End If

        End If
    Next
' -----------------------------
    ' REMAINDER OF FILE
    ' -----------------------------
    While Not EOF(1)
        Line Input #1, buffer

        ' If it's the Mazak post, do a clean pass-through (No truncation/N-numbering)
        If InStr(post_upper, "MAZAK-INTEGREX-I") > 0 Then
            Print #2, buffer
        Else
            ' KEEP EXISTING LOGIC FOR SIEMENS / PHILIPS
            If seq_act And (buffer <> "") And _
               (InStr(buffer, "F_END") = 0) And _
               (InStr(buffer, ";#SM;*RO*") = 0) Then

                seq_cnt = seq_cnt + Block_Inc
                seq = "N" & CStr(seq_cnt) & " "

                If InStr(buffer, " ") > 0 Then
                    Print #2, seq & Right(buffer, Len(buffer) - InStr(buffer, " "))
                Else
                    Print #2, seq & buffer
                End If
            Else
                Print #2, buffer
            End If
        End If
    Wend

    Close #1
    Close #2

    If found_tool_word Then
        Kill nc_file_name
        FileCopy temp_file_name, nc_file_name
        Kill temp_file_name
    Else
        Kill temp_file_name
    End If

End Sub
