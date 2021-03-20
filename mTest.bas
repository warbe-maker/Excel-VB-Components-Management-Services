Attribute VB_Name = "mTest"
Option Explicit
Option Private Module
' -------------------------------------------------------
' Standard module mTest
'                 Provides the means to test the services
'                 of the CompMan AddIn Workbook.
'
' W. Rauschenberger Berlin, Jan 2021
' -------------------------------------------------------
Private Const TEST_CHANGE = "' Test code change"

Private cTest   As clsTestService
Private cComp   As New clsComp
Private wbTest  As Workbook
Private wbSrc   As Workbook
Private wbTrgt  As Workbook
Private vbc     As VBComponent
Private vbcm    As CodeModule

Private Property Get RenewService() As String
    RenewService = AddInInstanceName & "!mRenew.ByImport"
End Property

Private Property Get UpdateClonesService() As String
    UpdateClonesService = AddInInstanceName & "!mUpdate.RawClones"
End Property

Public Sub Cleanup(Optional ByVal exp_file As String = vbNullString, _
                    Optional ByRef vbc As VBComponent = Nothing)
        
    If exp_file <> vbNullString Then
        With New FileSystemObject
            If .FileExists(exp_file) Then .DeleteFile exp_file
        End With
    End If
    
    If Not vbc Is Nothing Then
        With vbc.CodeModule
            If .Lines(1, 1) = TEST_CHANGE Then .DeleteLines 1, 1
            While Len(.Lines(1, 1)) = 0
                .DeleteLines 1.1
            Wend
        End With
    End If
    
    If Not cComp Is Nothing Then Set cComp = Nothing
    If Not vbcm Is Nothing Then Set vbcm = Nothing
    If Not vbc Is Nothing Then Set vbc = Nothing
    On Error Resume Next: wbTest.Close SaveChanges:=False
    On Error Resume Next: wbSrc.Close SaveChanges:=False
    On Error Resume Next: wbTrgt.Close SaveChanges:=False

End Sub

Private Function ErrSrc(ByVal sProc As String) As String
    ErrSrc = "mTest" & "." & sProc
End Function

Private Function MaxCompLength(ByRef wb As Workbook) As Long
    Dim vbc As VBComponent
    If lMaxCompLength = 0 Then
        For Each vbc In wb.VBProject.VBComponents
            MaxCompLength = mBasic.Max(MaxCompLength, Len(vbc.Name))
        Next vbc
    End If
End Function

Public Sub Regression()
' -----------------------------------------------------------------
'
' -----------------------------------------------------------------
    Const PROC = "Regression"
    
    Set cTest = New clsTestService
    cTest.Regression = True
    
    mErH.BoP ErrSrc(PROC)
    Test_01_KindOfComp
    mErH.EoP ErrSrc(PROC)
    
End Sub
  
Public Sub Test_SynchTargetWithSource()
' ---------------------------------------------------------------------
' Attention: This test preserves the target Workbook by a backup before
' and a restore after the synch test. The target Workbook thus will not
' show the synch result unless the terst procedire is stopped.
' ---------------------------------------------------------------------
    Const PROC = ""
    
    On Error GoTo eh
    Dim sSource     As String
    Dim sTarget     As String
    Dim BkpFolder   As String
    
    sTarget = "E:\Ablage\Excel VBA\DevAndTest\Test-Sync-Target-Project\Test_Sync_Target.xlsb"
    sSource = "E:\Ablage\Excel VBA\DevAndTest\Test-Sync-Source-Project\Test_Sync_Source.xlsb"
       
    If mService.SyncTargetWithSource(wb_target:=mCompMan.WbkGetOpen(sTarget) _
                                   , wb_source_name:=sSource _
                                   , bkp_folder:=BkpFolder _
                                    ) _
    Then
        ' -----------------------------------------------------------------
        Stop ' last chance to see the synch result in the target Workbook !
        '    ' traget Workbook will be restored as test Workbook
        ' -----------------------------------------------------------------
    End If
    '~~ The backup is no longer reqired
    If BkpFolder <> vbNullString Then
        ' A backup had been made by the service which is noew restored
        mCompMan.WbkGetOpen(sTarget).Close SaveChanges:=False
        mSync.SyncTargetRestore BkpFolder, sTarget
        Application.EnableEvents = False ' The open service UpdateRawClones would start with a new log-file otherwise
        mCompMan.WbkGetOpen sTarget
        Application.EnableEvents = True
    End If
    
xt: Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Sub Test_01_KindOfComp()
    Const PROC = "Test_01_KindOfComp"

    Dim wb      As Workbook
    Dim fso     As New FileSystemObject
    Dim cComp   As clsComp
    Dim sComp   As String
    
    Set wb = mCompMan.WbkGetOpen(fso.GetParentFolderName(ThisWorkbook.Path) & "\File\File.xlsm")

    sComp = "mFile"
    Set cComp = Nothing
    Set cComp = New clsComp
    With cComp
        Set .Wrkbk = wb
        Set .VBComp = wb.VBProject.VBComponents(sComp)
        Debug.Assert .KindOfComp() = enKindOfComp.enRawClone
    End With

    sComp = "fMsg"
    Set cComp = Nothing
    Set cComp = New clsComp
    With cComp
        Set .Wrkbk = wb
        Set .VBComp = wb.VBProject.VBComponents(sComp)
        Debug.Assert .KindOfComp() = enRawClone
    End With
    
    sComp = "mTest"
    Set cComp = Nothing
    Set cComp = New clsComp
    With cComp
        Set .Wrkbk = wb
        Set .VBComp = wb.VBProject.VBComponents(sComp)
        Debug.Assert .KindOfComp() = enInternal
    End With
    
xt: wb.Close SaveChanges:=False
    Set cComp = Nothing
    Set fso = Nothing
    Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Sub Test_10_ExportChangedComponents()
    Const PROC = "Test_ExportChangedComponents"
    
    mErH.BoP ErrSrc(PROC)
    mCompMan.ExportChangedComponents ThisWorkbook
    mErH.EoP ErrSrc(PROC)
    
End Sub

Public Sub Test_Log()
    Const PROC = "Test_Log"
    
    On Error GoTo eh
    Dim fso         As New FileSystemObject
    Dim cLog        As New clsLog
    
    With cLog
        Set .ServicedWrkbk(sw_new_log:=True) = ThisWorkbook
        .Service = ErrSrc(PROC)
        .ServicedItem = " <component-name> "
        .Entry = "Tested"
        mMsg.Box msg_title:="Test-Log:" _
               , msg:=mFile.Txt(ft_file:=.LogFile.Path) _
               , msg_monospaced:=True
        If fso.FileExists(.LogFile.Path) Then fso.DeleteFile .LogFile.Path
    End With
    
xt: Set cLog = Nothing
    Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: GoTo xt
    End Select

End Sub

Public Sub Test_Refs()
    
    Dim ref As Reference

    For Each ref In ThisWorkbook.VBProject.References
        With ref
            If InStr(.Description, "Applications Extensibility") <> 0 Then
                Debug.Print .Description
                Debug.Print .GUID
                Debug.Print "Major=" & .Major
                Debug.Print "Minor=" & .Minor
                Debug.Print TypeName(.GUID)
            End If
            If InStr(.Description, "Scripting Runtime") <> 0 Then
                Debug.Print .Description
                Debug.Print .GUID
                Debug.Print "Major=" & .Major
                Debug.Print "Minor=" & .Minor
                Debug.Print TypeName(.GUID)
            End If
        End With
    Next ref
    
End Sub

Public Sub Test_RenewComp(ByVal rnc_exp_file_full_name, _
                          ByVal rnc_comp_name As String, _
                          ByRef rnc_wb As Workbook)
' --------------------------------------------------------
' This test procedure is exclusively performed by the
' AddIn instance. It is run by the Development instance
' with: Application.Run _
'       AddInInstanceName & "!mTest.TestRenewComp" _
'       , <export-file-full-name> _
'       , <comp-name> _
'       , <wrkbk> _
'       , False ' new log file
'
' --------------------------------------------------------
    Const PROC = "Test_RenewComp"
    
    Dim cLog        As New clsLog
    Dim cComp       As New clsComp
    Dim wbActive    As Workbook
    Dim wbTemp      As Workbook
    
    If mMe.IsDevInstnc Then GoTo xt
    
    Set cLog.ServicedWrkbk(sw_new_log:=True) = ThisWorkbook
    cLog.Service = PROC
    
    With cComp
        .CompName = rnc_comp_name
        cLog.ServicedItem = .VBComp
        
        If .Wrkbk Is ActiveWorkbook Then
            Set wbActive = ActiveWorkbook
            Set wbTemp = Workbooks.Add ' Activates a temporary Workbook
            cLog.Entry = "Active Workbook de-activated by creating a temporary Workbook"
        End If
            
        mRenew.ByImport rn_wb:=.Wrkbk _
                      , rn_comp_name:=.CompName _
                      , rn_exp_file_full_name:=rnc_exp_file_full_name
    End With
    
xt: If Not wbTemp Is Nothing Then
        wbTemp.Close SaveChanges:=False
        cLog.Entry = "Temporary created Workbook closed without save"
        Set wbTemp = Nothing
        If Not ActiveWorkbook Is wbActive Then
            wbActive.Activate
            cLog.Entry = "De-activated Workbook '" & wbActive.Name & "' re-activated"
            Set wbActive = Nothing
        Else
            cLog.Entry = "Workbook '" & wbActive.Name & "' re-activated by closing the temporary created Workbook"
        End If
    End If
    Set cComp = Nothing
    Set cLog = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: GoTo xt
    End Select
End Sub

Public Sub Test_RenewComp_0_Regression()
    Const PROC = ""
    
    On Error GoTo eh
    If mMe.IsAddinInstnc Then Exit Sub
    
    mErH.EoP ErrSrc(PROC)
'    Test_RenewComp_1a_Standard_Module_ExpFile_Remote "mFile", repeat:=1
'    Test_RenewComp_1b_Standard_Module_ExpFile_Local "mFile", repeat:=1
'    Test_RenewComp_2_Class_Module_ExpFile_Local "clsLog", repeat:=2
'    Test_RenewComp_3a_UserForm_ExpFile_Local "fMsg", repeat:=1
    Test_RenewComp_3b_UserForm_ExpFile_Remote "fMsg", repeat:=1

xt: mErH.EoP ErrSrc(PROC)
    Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Sub Test_RenewComp_1a_Standard_Module_ExpFile_Remote( _
            ByVal test_comp_name As String, _
   Optional ByVal repeat As Long = 1)
' ----------------------------------------------------------------------------
' This is a kind of "burn-in" test in order to prove that a Standard Module
' can be renewed by the re-import of an Export-File.
' The test asserts that a Workbook is able to renew its own VBA code provided
' it is not active when it is done.
' ----------------------------------------------------------------------------
    Const PROC          As String = "Test_RenewComp_1a_UserForm_ExpFile_Remote"
    
    On Error GoTo eh
    Dim cComp           As New clsComp
    Dim i               As Long
    Dim sExpFile        As String
    Dim flExport        As File
    
    If mMe.IsAddinInstnc Then Exit Sub
    If mMe.IsDevInstnc Then
        If mMe.AddInInstncWrkbkIsOpen Then
            ' ---------------------------------
            '~~ Arguments for the Run:
            '~~ rc_exp_file_full_name As String
            '~~ rc_comp_name As String
            '~~ rc_wb As Workbook
            '~~ -------------------------------
            mErH.BoP ErrSrc(PROC)
            With cComp
                Set .Wrkbk = ThisWorkbook
                .CompName = test_comp_name
                            
                '~~ ------------------------------------------------------
                '~~ Second test with the selection of a remote Export-File
                '~~ ------------------------------------------------------
                If mFile.SelectFile(sel_init_path:=cComp.ExpFilePath _
                                  , sel_filters:="*" & cComp.ExpFileExtension _
                                  , sel_filter_name:="bas-Export-Files" _
                                  , sel_title:="Select an Export-File for the renewal of the component '" & .CompName & "'!" _
                                  , sel_result:=flExport) _
                Then sExpFile = flExport.Path
                For i = 1 To repeat
                    Application.Run RenewService _
                                  , .Wrkbk _
                                  , .CompName _
                                  , .ExpFilePath
                Next i
            End With
            mErH.EoP ErrSrc(PROC)
        End If
    End If
    
xt: Set cComp = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Sub Test_RenewComp_1b_Standard_Module_ExpFile_Local( _
            ByVal test_comp_name As String, _
   Optional ByVal repeat As Long = 1)
' ----------------------------------------------------------------------------
' This is a kind of "burn-in" test in order to prove that a Standard Module
' can be renewed by the re-import of an Export-File.
' The test asserts that a Workbook is able to renew its own VBA code provided
' it is not active when it is done.
' ----------------------------------------------------------------------------
    Const PROC = "Test_RenewComp_1b_Standard_Module_EXPFILE_Local"
    
    On Error GoTo eh
    Dim cComp   As New clsComp
    Dim i       As Long
    
    If mMe.IsAddinInstnc Then Exit Sub
    If mMe.IsDevInstnc Then
        If mMe.AddInInstncWrkbkIsOpen Then
            ' ---------------------------------
            '~~ Arguments for the Run:
            '~~ rc_exp_file_full_name As String
            '~~ rc_comp_name As String
            '~~ rc_wb As Workbook
            '~~ -------------------------------
            mErH.BoP ErrSrc(PROC)
            With cComp
                Set .Wrkbk = ThisWorkbook
                .CompName = test_comp_name
            
                For i = 1 To repeat
                    Application.Run RenewService _
                                  , .Wrkbk _
                                  , .CompName _
                                  , .ExpFilePath
                Next i
            End With
            mErH.EoP ErrSrc(PROC)
        End If
    End If
    
xt: Set cComp = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub Test_RenewComp_2_Class_Module_ExpFile_Local( _
            ByVal test_comp_name As String, _
   Optional ByVal repeat As Long = 1)
' ----------------------------------------------------------------------------
' This is a kind of "burn-in" test in order to prove that a Standard Module
' can be renewed by the re-import of an Export-File.
' The test asserts that a Workbook is able to renew its own VBA code provided
' it is not active when it is done.
' ----------------------------------------------------------------------------
    Const PROC = "Test_RenewComp_2_Class_Module_ExpFile_Local"
    
    On Error GoTo eh
    Dim cComp   As New clsComp
    Dim i       As Long
    
    If mMe.IsAddinInstnc Then Exit Sub
    If mMe.IsDevInstnc Then
        If mMe.AddInInstncWrkbkIsOpen Then
            ' ---------------------------------
            '~~ Arguments for the Run:
            '~~ rc_exp_file_full_name As String
            '~~ rc_comp_name As String
            '~~ rc_wb As Workbook
            '~~ -------------------------------
            mErH.BoP ErrSrc(PROC)
            With cComp
                Set .Wrkbk = ThisWorkbook
                .CompName = test_comp_name
            
                For i = 1 To repeat
                    Application.Run RenewService _
                                  , .Wrkbk _
                                  , .CompName _
                                  , .ExpFilePath
                Next i
            End With
            mErH.EoP ErrSrc(PROC)
        End If
    End If
    
xt: Set cComp = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub Test_RenewComp_3a_UserForm_ExpFile_Local( _
            ByVal test_comp_name As String, _
   Optional ByVal repeat As Long = 1)
' ----------------------------------------------------------------------------
' This is a kind of "burn-in" test in order to prove that a Standard Module
' can be renewed by the re-import of an Export-File.
' The test asserts that a Workbook is able to renew its own VBA code provided
' it is not active when it is done.
' ----------------------------------------------------------------------------
    Const PROC          As String = "Test_RenewComp_3a_UserForm_ExpFile_Local"
    
    On Error GoTo eh
    Dim cComp           As New clsComp
    Dim i               As Long
    Dim sExpFile        As String
    
    If mMe.IsAddinInstnc Then Exit Sub
    If mMe.IsDevInstnc Then
        If mMe.AddInInstncWrkbkIsOpen Then
            ' ---------------------------------
            '~~ Arguments for the Run:
            '~~ rc_exp_file_full_name As String
            '~~ rc_comp_name As String
            '~~ rc_wb As Workbook
            '~~ -------------------------------
            mErH.BoP ErrSrc(PROC)
            With cComp
                Set .Wrkbk = ThisWorkbook
                .CompName = test_comp_name
            
                '~~ -------------------------------------------------
                '~~ First test with the components origin Export-File
                '~~ -------------------------------------------------
                sExpFile = .ExpFilePath ' the component's origin export file
                For i = 1 To repeat
                    Application.Run RenewService _
                                  , .Wrkbk _
                                  , .CompName _
                                  , .ExpFilePath
                Next i
            End With
        End If
    End If
    
xt: Set cComp = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub Test_RenewComp_3b_UserForm_ExpFile_Remote( _
            ByVal test_comp_name As String, _
   Optional ByVal repeat As Long = 1)
' ----------------------------------------------------------------------------
' This is a kind of "burn-in" test in order to prove that a Standard Module
' can be renewed by the re-import of an Export-File.
' The test asserts that a Workbook is able to renew its own VBA code provided
' it is not active when it is done.
' ----------------------------------------------------------------------------
    Const PROC          As String = "Test_RenewComp_3b_UserForm_ExpFile_Remote"
    
    On Error GoTo eh
    Dim cComp           As New clsComp
    Dim i               As Long
    Dim sExpFile        As String
    Dim flExport        As File
    
    If mMe.IsAddinInstnc Then Exit Sub
    If mMe.IsDevInstnc Then
        If mMe.AddInInstncWrkbkIsOpen Then
            ' ---------------------------------
            '~~ Arguments for the Run:
            '~~ rc_exp_file_full_name As String
            '~~ rc_comp_name As String
            '~~ rc_wb As Workbook
            '~~ -------------------------------
            mErH.BoP ErrSrc(PROC)
            With cComp
                Set .Wrkbk = ThisWorkbook
                .CompName = test_comp_name
                            
                '~~ ------------------------------------------------------
                '~~ Second test with the selection of a remote Export-File
                '~~ ------------------------------------------------------
                If mFile.SelectFile(sel_init_path:=cComp.ExpFilePath _
                                  , sel_filters:="*" & cComp.ExpFileExtension _
                                  , sel_filter_name:="UserForm" _
                                  , sel_title:="Select an Export-File for the renewal of the component '" & .CompName & "'!" _
                                  , sel_result:=flExport) _
                Then sExpFile = flExport.Path
                For i = 1 To repeat
                    Application.Run RenewService _
                                  , .Wrkbk _
                                  , .CompName _
                                  , .ExpFilePath
                Next i
            End With
            mErH.EoP ErrSrc(PROC)
        End If
    End If
    
xt: Set cComp = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Sub Test_UpdateRawClones()
    Const PROC  As String = "Test_UpdateRawClones"
    
    On Error GoTo eh
    Dim lMaxCompLen As Long
    
    If mMe.IsAddinInstnc Then Exit Sub
    If mMe.IsDevInstnc Then
        If mMe.AddInInstncWrkbkIsOpen Then
            lMaxCompLen = MaxCompLength(wb:=ThisWorkbook)
            ' ---------------------------------
            '~~ Arguments for the Run:
            '~~ uc_wb As Workbook
            '~~ uc_comp_max_len As Long
            '~~ uc_service As String
            '~~ -------------------------------
            mErH.BoP ErrSrc(PROC)
            Application.Run UpdateClonesService _
                          , lMaxCompLen _
                          , cLog.Service
            mErH.EoP ErrSrc(PROC)
        End If
    End If
    
xt: Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Sub Test_BasicConfig()

    If Not mMe.BasicConfig Then
        Debug.Print "Basic configuration invalid!"
    End If
    
End Sub
