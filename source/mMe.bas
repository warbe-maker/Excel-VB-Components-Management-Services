Attribute VB_Name = "mMe"
Option Explicit
Option Private Module
' ---------------------------------------------------------------------------
' Standard Module mMe       Services for the self management like the relation
'                           between the Component Management AddIn instance
'                           and the development instance.
'
' Public services:
' - CompManAddinIsOpen  Returns True when the AddIn instance Workbook is
'                           open
' - CompManAddinFolder        Get/Let the configured path for the AddIn instance
'                           of this Workbook
' - CfgAsserted             Returns True when the required properties (paths)
'                           are configured and exist
' - ControlItemRenewAdd     Used when the development and test instance
'                           Workbook is opened to add a RenewAddIn control
'                           item to the "Add-Ins" poupup menu.
' - ControlItemRenewRemove  Used when the development and test instance
'                           Workbook is closed.
' - RenewAddIn              Called via the RenewAddIn control item in the
'                           "Add-Ins" popup menu or executed via the
'                           VBE when the code of the Addin had been modified
'                           in its Development instance Workbook.
' - UpdateRawClones         Exclusively performed fro within the Development
'                           instance Workbook to update its own used Clone
'                           Components of which the Raw code has changed. This
'                           service only runs provided the Addin instance
'                           Workbook is open (see RenewAddIn service).
' - ServicedRootFolder      When the AddIn is open and not  p a u s e d the
'                           Workbook_Open service 'UpdateRawClones' and the
'                           Workbook_BeforeSave service 'ExportChangedComponents'
'                           will be executed for Workbooks calling them under
'                           the two additional preconditions:
'                           1. The Conditional Compile Argument CompMan = 1"
'                           2. The Workbook is located in the configured
'                              'Serviced Development Root'
' Uses Common Components:
' - mFile                   Get/Let PrivateProperty value service
' - mWrkbk                  GetOpen and Opened service
' - mMsg                    Dsply, Box, and Buttons service used by the
'                           RenewAddin,  Renew_1_ConfirmConfig service
'
' Requires:
' W. Rauschenberger, Berlin Nov 2020
' ---------------------------------------------------------------------------
Public Const COMPMAN_ADMIN_FOLDER_NAME      As String = "\CompManAdmin\"
Public Const FOLDER_SERVICED                As String = "Serviced-By-CompMan folder"

Private Const FOLDER_ADDIN                  As String = "CompMan-Addin folder"
Private Const SECTION_BASE_CONFIG           As String = "BaseConfiguration"
Private Const VNAME_SERVICED_ROOT           As String = "VBDevProjectsRoot"
Private Const VNAME_COMPMAN_ADDIN_FOLDER    As String = "CompManAddInPath"
Private Const VNAME_COMPMAN_ADDIN_PAUSED    As String = "CompManAddInPaused"
Private Const ADDIN_WORKBOOK_EXTENSION      As String = "xlam"      ' Extension may depend on Excel version
Private Const DEVLP_WORKBOOK_EXTENSION      As String = "xlsb"      ' Extension may depend on Excel version

Private wbDevlp         As Workbook
Private wbSource        As Workbook                     ' This development instance as the renew source
Private wbTarget        As Workbook                     ' The Addin instance as renew target
Private bSucceeded      As Boolean
Private bAllRemoved     As Boolean
Private dctAddInRefs    As Dictionary
Private lRenewStep      As Long
Private sRenewAction    As String

Public Property Get CompManAddinFullName() As String
    CompManAddinFullName = AddInPath & DBSLASH & CompManAddinName
End Property

Public Property Get CompManAddinName() As String
    With New FileSystemObject
        CompManAddinName = .GetBaseName(ThisWorkbook.FullName) & "." & ADDIN_WORKBOOK_EXTENSION
    End With
End Property
    
Private Property Get AddInPath() As String
    AddInPath = mMe.CompManAddinFolder
End Property

Public Property Get CompManAddinPaused() As Boolean
    Dim s As String
    s = Value(pp_section:=SECTION_BASE_CONFIG, pp_value_name:=VNAME_COMPMAN_ADDIN_PAUSED)
    If s = vbNullString Then
        CompManAddinPaused = False
    Else
        CompManAddinPaused = VBA.CBool(s)
    End If
End Property

Public Property Let CompManAddinPaused(ByVal b As Boolean)
    Value(pp_section:=SECTION_BASE_CONFIG, pp_value_name:=VNAME_COMPMAN_ADDIN_PAUSED) = b
    With New FileSystemObject
        .CopyFile CompManCfgFileName, CompManAddinFolder & COMPMAN_ADMIN_FOLDER_NAME & .GetFileName(CompManCfgFileName)
    End With
End Property

Private Property Get ADDIN_FORMAT() As XlFileFormat ' = ... needs adjustment when the above is changed
    ADDIN_FORMAT = xlOpenXMLAddIn
End Property

Private Property Get CompManCfgFileName() As String
' -----------------------------------------------------------------------
' Note: Whenever the CompMan configuration changes this is done by the
'       CompMan-Development-Instance-Workbook which copies it immediately
'       to the Addin's subfolder CompManAdmin. This way the configuration
'       is available for the CompMan-Development-Instance-Workbook without
'       knowing the location it is finally copied to.
' ------------------------------------------------------------------------
    Dim fso As New FileSystemObject
    Select Case fso.GetExtensionName(ThisWorkbook.name)
        Case "xlam"
            '~~ When the CompMan-Addin requests the CompMan.cfg file
            '~~ it is the one which resides in the 'CompManAdmin' sub-folder
            CompManCfgFileName = ThisWorkbook.Path & COMPMAN_ADMIN_FOLDER_NAME & "CompMan.cfg"
        Case "xlsb"
            '~~ When the CompMan-Development-Instance-Workbook requests the CompMan.cfg file
            '~~ it is the one which resides in its own Workbook folder
            CompManCfgFileName = ThisWorkbook.Path & "\CompMan.cfg"
    End Select
    Set fso = Nothing
End Property

Private Property Get CompManAdminFolder(ByVal compman_addin_folder As String) As String
' -------------------------------------------------------------------------------------
' Attention: The CompManAdminFolder may change when the CompManAddinFolder is changed!
' -------------------------------------------------------------------------------------
    CompManAdminFolder = compman_addin_folder & COMPMAN_ADMIN_FOLDER_NAME
End Property

Public Property Get CompManAddinFolder() As String
    CompManAddinFolder = Value(pp_section:=SECTION_BASE_CONFIG, pp_value_name:=VNAME_COMPMAN_ADDIN_FOLDER)
End Property

Public Property Let CompManAddinFolder(ByVal s As String)
    Const PROC = "CompManAddinFolder-Let"
    
    On Error GoTo eh
    Dim fso         As New FileSystemObject
    Dim sCfgFile    As String: sCfgFile = CompManCfgFileName
    
    Value(pp_section:=SECTION_BASE_CONFIG, pp_value_name:=VNAME_COMPMAN_ADDIN_FOLDER) = s
    fso.CopyFile sCfgFile, s & COMPMAN_ADMIN_FOLDER_NAME & fso.GetFileName(sCfgFile)
    
xt: Set fso = Nothing
    Exit Property

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Property

Public Property Get DevInstncFullName() As String
Dim fso As New FileSystemObject
    DevInstncFullName = ServicedRootFolder & DBSLASH _
                          & fso.GetBaseName(DevInstncName) & DBSLASH _
                          & DevInstncName
End Property

Public Property Get DevInstncName() As String
    With New FileSystemObject
        DevInstncName = .GetBaseName(ThisWorkbook.FullName) & "." & DEVLP_WORKBOOK_EXTENSION
    End With
End Property

Private Property Get DEVLP_FORMAT() As XlFileFormat  ' = .xlsb ! may require adjustment when the above is changed
    DEVLP_FORMAT = xlExcel12
End Property

Public Property Get IsAddinInstnc() As Boolean
    With New FileSystemObject
        IsAddinInstnc = .GetExtensionName(ThisWorkbook.FullName) = "xlam"
    End With
End Property

Public Property Get IsDevInstnc() As Boolean
    With New FileSystemObject
        IsDevInstnc = .GetExtensionName(ThisWorkbook.FullName) = "xlsb"
    End With
End Property

Private Sub RenewFinalResult()
    If bSucceeded Then
        mMe.RenewLogAction = "Successful!"
        RenewLogResult("Successful! The Addin '" & CompManAddinName & "' has been renewed by the development instance '" & DevInstncName & "'") = "Passed"
    Else
        mMe.RenewLogAction = "Not Successful!"
        mMe.RenewLogResult("Renewing the Addin '" & CompManAddinName & "' by the development instance '" & DevInstncName & "' failed!") = "Failed"
    End If
End Sub

Public Property Let RenewLogAction(ByVal la_action As String)
    lRenewStep = lRenewStep + 1
    sRenewAction = la_action
    wsAddIn.LogRenewStep rn_action:=sRenewAction
End Property

Public Property Let RenewLogResult( _
                    Optional ByVal la_result_text As String = vbNullString, _
                             ByVal la_result As String)
    wsAddIn.LogRenewStep rn_result:=la_result, rn_action:=la_result_text
End Property

Public Property Get RenewStep() As Long:    RenewStep = lRenewStep: End Property

Public Property Let RenewStep(ByVal l As Long)
'    If l = 0 Then wsAddIn.RenewStepLogClear
    lRenewStep = l
End Property

Public Property Get ServicedRootFolder() As String
    ServicedRootFolder = Value(pp_section:=SECTION_BASE_CONFIG, pp_value_name:=VNAME_SERVICED_ROOT)
End Property

Public Property Let ServicedRootFolder(ByVal s As String)
    Value(pp_section:=SECTION_BASE_CONFIG, pp_value_name:=VNAME_SERVICED_ROOT) = s
    With New FileSystemObject
        .CopyFile CompManCfgFileName, mMe.CompManAddinFolder & COMPMAN_ADMIN_FOLDER_NAME & .GetFileName(CompManCfgFileName)
    End With
End Property

Private Property Get Value( _
           Optional ByVal pp_section As String, _
           Optional ByVal pp_value_name As String) As Variant
    
    Value = mFile.Value(pp_file:=CompManCfgFileName _
                      , pp_section:=pp_section _
                      , pp_value_name:=pp_value_name _
                       )
End Property

Private Property Let Value( _
           Optional ByVal pp_section As String, _
           Optional ByVal pp_value_name As String, _
                    ByVal pp_value As Variant)
    mFile.Value(pp_file:=CompManCfgFileName _
              , pp_section:=pp_section _
              , pp_value_name:=pp_value_name _
               ) = pp_value
End Property

Public Property Get xlAddInFormat() As Long:            xlAddInFormat = ADDIN_FORMAT:                                       End Property

Public Property Get xlDevlpFormat() As Long:            xlDevlpFormat = DEVLP_FORMAT:                                       End Property

Private Property Get CompManAddinIsSetup() As Boolean
' ------------------------------------------------------------
' Returns True when the CompMan-AddIn is configured and exists
' in the configured folder.
' ------------------------------------------------------------
    With New FileSystemObject
        If mMe.CompManAddinFolder <> vbNullString _
        Then CompManAddinIsSetup = .FileExists(mMe.CompManAddinFolder & "\" & CompManAddinName)
    End With

End Property

Public Sub DisplayStatus(Optional ByVal keep_renew_steps_result As Boolean = False)
    Const PROC = "DisplayStatus"
    
    On Error GoTo eh
    wsAddIn.CurrentStatus = vbNullString
    If mMe.CompManAddinIsSetup Then
        If Not mMe.CompManAddinIsOpen Then
            '~~ AddIn is setup but currently not open. It will be opened either when a Workbook
            '~~ referring to it is openend or when it is renewed.
            
            '~~ Renew steps log
            wsAddIn.CurrentStatus = mBasic.Spaced("not open!") & vbLf & _
                                    "(will be opened with Setup/Renew or by a Workbook opened which refers to it)"
            '~~ AddIn paused status
            wsAddIn.CompManAddInPausedStatus = _
            "The CompMan-AddIn is  s e t u p  but currently  n o t  o p e n !" & vbLf & _
            "(Renew or a Workbook opened which refers to it will open it)"
        Else ' AddIn is setup and open
            wsAddIn.CurrentStatus = "Setup/Renewed and  " & mBasic.Spaced("open!")
            If mMe.CompManAddinPaused = True Then
                wsAddIn.CurrentStatus = mBasic.Spaced("paused!")
                wsAddIn.CompManAddInPausedStatus = _
                "The 'CompMan-Addin' is currently  p a u s e d ! The Workbook_Open service 'UpdateRawClones' " & _
                "and the Workbook_BeforeSave service 'ExportChangedComponents' will be bypassed " & _
                "until the Addin is 'continued' again!"
            Else
                wsAddIn.CurrentStatus = mBasic.Spaced("active!")
                wsAddIn.CompManAddInPausedStatus = _
                "The 'CompMan-AddIn' is currently  a c t i v e !  The services 'UpdateRawClones' and 'ExportChangedComponents'" & vbLf & _
                "will be available for Workbooks calling them under the following preconditions: " & vbLf & _
                "1. The Workbook is located in the configured 'Serviced-Development-Root-Folder' which currently is:" & vbLf & _
                "   '" & mMe.ServicedRootFolder & "'" & vbLf & _
                "2. The Workbook is the only one in its parent folder" & vbLf & _
                "3. The Workbook is not a restored version" & vbLf & vbLf & _
                "Note: When the VBProject has a Reference to 'CompMan' the Addin would automatically be opened with it." & vbLf & _
                "      Otherwise this Development-Instance-Workbook needs to be opened and Setup/Renew must be performed."
            End If
        End If
    Else ' not or no longer (properly) setup
        wsAddIn.CurrentStatus = mBasic.Spaced("not setup!") & vbLf & _
                                "(Setup/Renew must be performed to configure and setup the 'CompMan-Addin'"
        wsAddIn.CompManAddInPausedStatus = _
        "The CompMan-Addin is currently  n o t  s e t u p !" & vbLf & vbLf & _
        "Renew is required to establish the Addin. The Addin, once established, will subsequently be opened when:" & vbLf & _
        "- a Workbook is opened which refers to it" & vbLf & _
        "- this Addin-Development-Instance-Workbook is opened and Setup/Renew is performed"
    End If

    If Not WinMergeIsInstalled Then
        wsAddIn.CurrentStatus = "'WinMerge' is  " & mBasic.Spaced("not installed!") & vbLf & "(services will be denied)"
    End If

xt: Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Sub CompManAddinContinue()
    mService.Continue
End Sub

Private Function CompManAddinWrkbkExists() As Boolean
    Dim fso As New FileSystemObject
    CompManAddinWrkbkExists = fso.FileExists(CompManAddinFullName)
End Function

Public Function CompManAddinIsOpen() As Boolean
    Const PROC = "CompManAddinIsOpen"
    
    On Error GoTo eh
    Dim i As Long
    
    CompManAddinIsOpen = False
    For i = 1 To Application.AddIns2.Count
        If Application.AddIns2(i).name = CompManAddinName Then
            On Error Resume Next
            Set wbTarget = Application.Workbooks(CompManAddinName)
            CompManAddinIsOpen = Err.Number = 0
            GoTo xt
        End If
    Next i
    
xt: Exit Function

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Function

Public Sub CompManAddinPause()
    mService.Pause
End Sub

Private Sub DevInstncWorkbookClose()
    Const PROC = "DevInstncWorkbookClose"
    
    On Error GoTo eh

    mMe.RenewLogAction = "Close 'Development-Instance-Workbook' (" & DevInstncName & ")"
    
    On Error Resume Next
    wbDevlp.Activate
    wbDevlp.Close False
    If Err.Number <> 0 _
    Then mMe.RenewLogResult("Closing the 'Development-Instance-Workbook' (" & DevInstncName & ") failed with:" & vbLf & _
                            "(" & Err.Description & ")" _
                           ) = "Failed" _
    Else mMe.RenewLogResult() = "Passed"
xt: Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub DevInstncWorkbookDelete()
    Const PROC = "DevInstncWorkbookDelete"
    
    On Error GoTo eh
    Dim fso As New FileSystemObject
    
    mMe.RenewLogAction = "Delete the 'Development-Instance-Workbook' (" & DevInstncName & ")"
    
    With fso
        If .FileExists(DevInstncFullName) Then
            On Error Resume Next
            .DeleteFile DevInstncFullName
            If Err.Number = 0 _
            Then mMe.RenewLogResult() = "Passed" _
            Else mMe.RenewLogResult("Deleting the 'Development-Instance-Workbook' (" & DevInstncName & ") failed with:" & vbLf & _
                                    "(" & Err.Description & ")" _
                                   ) = "Failed"
        Else
            mMe.RenewLogResult() = "Passed"
        End If
    End With

xt: Set fso = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Function DevInstncWorkbookExists() As Boolean
Dim fso As New FileSystemObject
    DevInstncWorkbookExists = fso.FileExists(DevInstncFullName)
End Function

Private Function ErrSrc(ByVal sProc As String) As String
    ErrSrc = "mMe" & "." & sProc
End Function

Public Sub RenewAddIn()
' -----------------------------------------------------------
' Renews the code of the Addin instance of this Workbook with
' this Workbook's code by displaying a detailed result of the
' whole RenewAddIn process.
' Note: It cannot be avoided that this procedure is available
'       also in the Addin instance. However, its execution is
'       limited to this Workbook's development instance.
' -----------------------------------------------------------
    Const PROC = "RenewAddIn"
    
    On Error GoTo eh
    RenewStep = 0

    Application.EnableEvents = False
    bSucceeded = False
                            
    '~~ Get the CompMan base configuration confirmed or changed
    If Not Renew_0_ConfirmConfig Then GoTo xt
                         
    '~~ Assert the Renew service is performed from within the development instance Workbbok
    '~~ Note that the distinction of the instances requires the above basic configuration confirmed
    If Not Renew_1_DevInstnc Then GoTo xt
    
    '~~ Assert no Workbooks are open referring to the Addin
    Renew_2_SaveAndRemoveAddInReferences
    If Not bAllRemoved Then GoTo xt

    '~~ Assure the current version of the Addin's development instance has been saved
    '~~ Note: Unconditionally saving the Workbook does an incredible trick:
    '~~       The un-unstalled and IsAddin=False Workbook is released from the Application
    '~~       and no longer considered "used"
    Renew_3_DevInstncWorkbookSave
    wbSource.Activate
          
    '~~ Attempt to turn Addin to "IsAddin=False", uninstall and close it
    If CompManAddinIsOpen Then
        Renew_4_Set_IsAddin_ToFalse wbTarget
        If Not Renew_5_CloseAddinInstncWorkbook Then GoTo xt
    End If
    
    '~~ Attempt to delete the Addin Workbook file
    If Not Renew_6_DeleteAddInInstanceWorkbook Then GoTo xt
        
    '~~ Attempt to save the development instance as Addin
    If Not Renew_7_SaveDevInstncWorkbookAsAddin Then GoTo xt
    
    '~~ Saving the development instance as Addin may also open the Addin.
    '~~ So if not already open it is re-opened and thus re-activated
    If Not Renew_8_OpenAddinInstncWorkbook Then GoTo xt
        
    '~~ Re-instate references to the Addin which had been removed
    Renew_9_RestoreReferencesToAddIn
    
    bSucceeded = True
    
xt: RenewFinalResult
    
    Application.ScreenUpdating = False
    mMe.DisplayStatus True
    Application.ScreenUpdating = True
    
    Application.EnableEvents = False
    wbSource.Save
    wbSource.Activate
    Application.EnableEvents = True
    
    Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Public Function BasicConfig( _
             Optional ByVal bc_sync_confirm_info As Boolean = False) As Boolean
' -------------------------------------------------------------------
' Returns TRUE when the 'Basic Configuration', i.e. the Addin-Folder
' and the Serviced-Root-Folder are configured, existing, and correct.
' When bc_sync_confirm_info is True a configuration confirmation dialog is
' displayed. The dialog is also displayed when the basic configu-
' ration is invalid.
' -----------------------------------------------------------------
    Const PROC                  As String = "BasicConfig"
    Const BTTN_CFG_CONFIRMED    As String = "Confirmed"
    Const BTTN_TERMINATE_CFG    As String = "Terminate the configuration"
    
    On Error GoTo eh
    Dim sBttnAddin      As String: sBttnAddin = "Configure/change" & vbLf & vbLf & FOLDER_ADDIN & vbLf & " "
    Dim sBttnSrvcd      As String: sBttnSrvcd = "Configure/change" & vbLf & vbLf & FOLDER_SERVICED & vbLf & " "
    
    Dim fso                         As New FileSystemObject
    Dim sMsg                        As TypeMsg
    Dim sReply                      As String
    Dim sCompManAddinFolder         As String
    Dim sServicedRootFolder         As String
    Dim CompManAddinFolderIsValid   As Boolean
    Dim ServicedRootFolderIsValid   As Boolean
    Dim cllButtons                  As Collection
    
    sServicedRootFolder = mMe.ServicedRootFolder
    '~~ In case an AltStartupFolder is configured and not identical with the current configured CompMan-Addin-Folder
    '~~ the current AltStartUpPath is displayed for being configured also as the CompMan-Addin-Folder because there
    '~~ can be only one location for all Workbooks which should be opened when Excel starts.
    If Application.AltStartupPath <> vbNullString And VBA.StrComp(mMe.CompManAddinFolder, Application.AltStartupPath, vbTextCompare) <> 0 _
    Then sCompManAddinFolder = Application.AltStartupPath _
    Else sCompManAddinFolder = mMe.CompManAddinFolder

    While (Not ServicedRootFolderIsValid Or Not CompManAddinFolderIsValid) Or (bc_sync_confirm_info And sReply <> BTTN_CFG_CONFIRMED)
        
        '~~ Verification of the current Serviced-Root-Folder
        If sServicedRootFolder = vbNullString Then
            sServicedRootFolder = mBasic.Spaced("not yet configured!")
        ElseIf Not fso.FolderExists(sServicedRootFolder) Then
            sServicedRootFolder = sServicedRootFolder & mBasic.Spaced(":invalid!") & "  (not or no longer existing)"
        Else
            ServicedRootFolderIsValid = True
        End If
        
        '~~ Verification of the current S of the CompMan-Addin-Location
        If sCompManAddinFolder = vbNullString Then
            sCompManAddinFolder = mBasic.Spaced("not yet configured!")
        ElseIf Not fso.FolderExists(sCompManAddinFolder) Then
            sCompManAddinFolder = sCompManAddinFolder & mBasic.Spaced(":invalid!") & "  (not or no longer existing)"
        ElseIf InStr(sCompManAddinFolder, sServicedRootFolder) <> 0 Then
            sCompManAddinFolder = sCompManAddinFolder & mBasic.Spaced(":invalid!") & "  (folder must not be a subfolder of the Serviced-Root-Folder)"
        Else
            CompManAddinFolderIsValid = True
        End If
    
        If CompManAddinFolderIsValid And ServicedRootFolderIsValid And Not bc_sync_confirm_info Then GoTo xt
        
        With sMsg
            With .Section(1)
                .Label.Text = FOLDER_SERVICED & ":"
                .Label.FontBold = True
                With .Text
                    .Text = sServicedRootFolder
                    .FontColor = rgbBlue
                    .FontBold = True
                    .Monospaced = True
                End With
            End With
            With .Section(2)
                .Label.Text = FOLDER_ADDIN & ":"
                .Label.FontBold = True
                With .Text
                    .Text = sCompManAddinFolder
                    .FontColor = rgbBlue
                    .FontBold = True
                    .Monospaced = True
                End With
            End With
            With .Section(3).Text
                .FontSize = 8.5
                .Text = "- Must not be identical with the " & FOLDER_SERVICED & vbLf & _
                        "  or any of its subfolders." & vbLf & vbLf & _
                        "- For Workbooks 'outside' this folder (i.e. productive) an 'export' or" & vbLf & _
                        "  an 'update' service will not be applied."
            End With
            With .Section(4)
                If bc_sync_confirm_info _
                Then .Text.Text = "Please confirm the above 'Basic CompMan Configuration'." _
                Else .Text.Text = "Please configure/complete the 'Basic CompMan Configuration'."
            End With
        End With
        '~~ Buttons preparation
        If Not ServicedRootFolderIsValid Or Not CompManAddinFolderIsValid _
        Then Set cllButtons = mMsg.Buttons(sBttnSrvcd, sBttnAddin, vbLf, BTTN_TERMINATE_CFG) _
        Else Set cllButtons = mMsg.Buttons(BTTN_CFG_CONFIRMED, vbLf, sBttnSrvcd, sBttnAddin)
        
        sReply = mMsg.Dsply(dsply_title:="Basic configuration of the Component Management (CompMan Addin)" _
                          , dsply_msg:=sMsg _
                          , dsply_buttons:=cllButtons _
                           )
        Select Case sReply
            Case sBttnAddin
                Do
                    sCompManAddinFolder = mBasic.SelectFolder("Select the obligatory 'CompMan-Addin-Folder'")
                    If sCompManAddinFolder <> vbNullString Then Exit Do
                Loop
                bc_sync_confirm_info = True
            Case sBttnSrvcd
                Do
                    sServicedRootFolder = mBasic.SelectFolder("Select the obligatory 'CompMan-Serviced-Root-Folder'")
                    If sServicedRootFolder <> vbNullString Then Exit Do
                Loop
                bc_sync_confirm_info = True
                '~~ The change of the serviced root folder may have resulted in
                '~~ a (formerly invalid) now valid again Add-in folder
                sCompManAddinFolder = Split(sCompManAddinFolder, ": ")(0)
            
            Case BTTN_CFG_CONFIRMED: bc_sync_confirm_info = False
            Case BTTN_TERMINATE_CFG: GoTo xt
                
        End Select
        
    Wend ' Loop until the confirmed or configured basic configuration is correct
    
xt: If CompManAddinFolderIsValid Then
        If VBA.StrComp(mMe.CompManAddinFolder, sCompManAddinFolder, vbTextCompare) <> 0 Then
            '~~ The configured CompMan-Addin-Folder has changed to another location.
            '~~ The CompManAdminFolder has to be copied before the new configuration can be saved
            fso.MoveFolder CompManAdminFolder(mMe.CompManAddinFolder), CompManAdminFolder(sCompManAddinFolder)
        End If
        '~~ The admin folder is now at its possibly new location and the information can be stored into the config file
        mMe.CompManAddinFolder = sCompManAddinFolder
        Application.AltStartupPath = sCompManAddinFolder
        TrustThisFolder FolderPath:=sCompManAddinFolder
    End If
    If ServicedRootFolderIsValid Then mMe.ServicedRootFolder = sServicedRootFolder
    BasicConfig = ServicedRootFolderIsValid And CompManAddinFolderIsValid
    With fso
        .CopyFile CompManCfgFileName, mMe.CompManAddinFolder & COMPMAN_ADMIN_FOLDER_NAME & .GetFileName(CompManCfgFileName)
    End With
    Set fso = Nothing
    Exit Function

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Function

Private Function Renew_1_DevInstnc() As Boolean
    mMe.RenewLogAction = "Assert this 'Setup/Renew' service is executed from the 'Development-Instance-Workbook'"
    Renew_1_DevInstnc = IsDevInstnc()
    If Not Renew_1_DevInstnc _
    Then mMe.RenewLogResult("The 'RenewAddIn' service had not been executed from within the development instance Workbook (" & DevInstncName & ")!" _
                           ) = "Failed" _
    Else mMe.RenewLogResult = "Passed"
End Function

Private Function Renew_0_ConfirmConfig() As Boolean
    mMe.RenewLogAction = "Assert 'CompMan's Basic Configuration'"
    Renew_0_ConfirmConfig = BasicConfig(bc_sync_confirm_info:=True)
    If Renew_0_ConfirmConfig _
    Then mMe.RenewLogResult = "Passed" _
    Else mMe.RenewLogResult = "Failed"
End Function

Private Sub Renew_2_SaveAndRemoveAddInReferences()
' ----------------------------------------------------------------
' - Allows the user to close any open Workbook which refers to the
'   Addin, which definitly hinders the Addin from being re-newed.
' - Returns TRUE when the user closed all open Workbboks.
' ----------------------------------------------------------------
    Const PROC = "Renew_2_SaveAndRemoveAddInReferences"
    
    On Error GoTo eh
    Dim dct         As Dictionary
    Dim v           As Variant
    Dim wb          As Workbook
    Dim ref         As Reference
    Dim sWbs        As String
    Dim bOneRemoved As Boolean
    Dim fso         As New FileSystemObject

    mMe.RenewLogAction = "Save and remove references to the Addin from open Workbooks"
    
    With Application
        Set dct = mWrkbk.Opened ' Returns a Dictionary with all open Workbooks in any application instance
        Set dctAddInRefs = New Dictionary
        For Each v In dct
            Set wb = dct.Item(v)
            For Each ref In wb.VBProject.References
                If InStr(ref.name, fso.GetBaseName(CompManAddinName)) <> 0 Then
                    dctAddInRefs.Add wb, ref
                    sWbs = wb.name & ", " & sWbs
                End If
            Next ref
        Next v
        
        For Each v In dctAddInRefs
            Set wb = v
            Set ref = dctAddInRefs(v)
            wb.VBProject.References.Remove ref
            bOneRemoved = True
        Next v
        bAllRemoved = True
    End With
    
    If bOneRemoved Then
        sWbs = Left(sWbs, Len(sWbs) - 2)
        mMe.RenewLogResult() = "Passed"
    Else
        mMe.RenewLogResult(sRenewAction & vbLf & "None of the open Workbook's VBProject had a 'Reference' to the 'CompMan-Addin'" _
                          ) = "Passed"
    End If
    
xt: Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub Renew_3_DevInstncWorkbookSave()
    Const PROC = "Renew_3_DevInstncWorkbookSave"
    
    On Error GoTo eh
    mMe.RenewLogAction = "Save the 'Development-Instance-Workbook' (" & DevInstncName & ")"
    
    Set wbSource = Application.Workbooks(DevInstncName)
    wbSource.Save
    wbSource.Activate
    mMe.RenewLogResult() = "Passed"

xt: Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub Renew_4_Set_IsAddin_ToFalse(ByRef wb As Workbook)
    Const PROC = "Renew_4_Set_IsAddin_ToFalse"
    
    On Error GoTo eh

    mMe.RenewLogAction = "Set the 'IsAddin' property of the 'CompMan-Addin' to FALSE"
    
    If wb.IsAddin = True Then
        wb.IsAddin = False
        mMe.RenewLogResult() = "Passed"
    Else
        mMe.RenewLogResult("The 'IsAddin' property of the 'ComMan-Addin' was already set to FALSE" _
                          ) = "Passed"
    End If
    
xt:     Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Function Renew_5_CloseAddinInstncWorkbook() As Boolean
' ------------------------------------------------------------
' Returns True when the Addin has successfully been closed.
' ------------------------------------------------------------
    Const PROC = "Renew_5_CloseAddinInstncWorkbook"
    
    mMe.RenewLogAction = "Close the 'CompMan-Addin'"
    On Error Resume Next
    wbSource.Activate
    wbTarget.Close False
    Renew_5_CloseAddinInstncWorkbook = Err.Number = 0
    If Not Renew_5_CloseAddinInstncWorkbook _
    Then mMe.RenewLogResult("Closing the 'CompMan-Addin' (" & CompManAddinName & ") failed with:" & vbLf & _
                            "(" & Err.Description & ")" _
                           ) = "Failed" _
    Else mMe.RenewLogResult = "Passed"

xt: Exit Function

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Function

Private Function Renew_6_DeleteAddInInstanceWorkbook() As Boolean
' ---------------------------------------------------------------
' Returns True when the Addin instance Workbbook has been deleted
' ---------------------------------------------------------------
    Const PROC = "Renew_6_DeleteAddInInstanceWorkbook"
    
    On Error GoTo eh

    mMe.RenewLogAction = "Delete the 'CompMan-Addin' Workbook' (" & CompManAddinName & ")"
    With New FileSystemObject
        If .FileExists(CompManAddinFullName) Then
            On Error Resume Next
            .DeleteFile CompManAddinFullName
            Renew_6_DeleteAddInInstanceWorkbook = Err.Number = 0
            If Renew_6_DeleteAddInInstanceWorkbook _
            Then mMe.RenewLogResult = "Passed" _
            Else mMe.RenewLogResult("Deleting the 'CompMan-Addin' (" & CompManAddinName & ") failed with:" & vbLf & _
                                    "(" & Err.Description & ")" _
                                   ) = "Failed"
        Else
            Renew_6_DeleteAddInInstanceWorkbook = True
            mMe.RenewLogResult = "Passed"
        End If
    End With
    
xt: Exit Function

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Function

Private Function Renew_7_SaveDevInstncWorkbookAsAddin() As Boolean
' ----------------------------------------------------------------
' Returns True when the development instance Workbook has
' successfully saved as Addin.
' ----------------------------------------------------------------
    Const PROC = "Renew_7_SaveDevInstncWorkbookAsAddin"
    
    On Error GoTo eh
    mMe.RenewLogAction = "Save the 'Development-Instance-Workbook' (" & DevInstncName & ") as 'CompMan-Addin' (" & CompManAddinName & ")"
    
    With Application
        If Not CompManAddinWrkbkExists Then
            '~~ At this point the Addin must no longer exist at its location
            .EnableEvents = False
            On Error Resume Next
            wbSource.SaveAs CompManAddinFullName, FileFormat:=xlAddInFormat
            Renew_7_SaveDevInstncWorkbookAsAddin = Err.Number = 0
            If Not Renew_7_SaveDevInstncWorkbookAsAddin _
            Then mMe.RenewLogResult("Save Development instance as Addin instance failed!" _
                                   ) = "Failed" _
            Else mMe.RenewLogResult() = "Passed"
            .EnableEvents = True
        Else ' file still exists
            mMe.RenewLogResult("Setup/Renew of the 'CompMan-Addin' as copy of the 'Development-Instance-Workbook' failed" _
                              ) = "Failed"
        End If
    End With
    
xt: Exit Function

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Function

Private Function Renew_8_OpenAddinInstncWorkbook() As Boolean
' -----------------------------------------------------------
' Returns True when the Addin instance Workbook has success-
' fully been opened.
' -----------------------------------------------------------
    Const PROC = "Renew_8_OpenAddinInstncWorkbook"
    
    On Error GoTo eh
    Dim wb              As Workbook
    Dim sBaseAddinName  As String
    Dim sBaseDevName    As String
    
    If Not CompManAddinIsOpen Then
        If CompManAddinWrkbkExists Then
            mMe.RenewLogAction = "Re-open the 'CompMan-Addin' (" & CompManAddinName & ")"
            On Error Resume Next
            Set wb = Application.Workbooks.Open(CompManAddinFullName)
            If Err.Number = 0 Then
                With New FileSystemObject
                    sBaseAddinName = .GetBaseName(wb.name)
                    sBaseDevName = .GetBaseName(ThisWorkbook.name)
                    wb.VBProject.name = sBaseAddinName
                End With
                mMe.RenewLogResult() = "Passed"
                Renew_8_OpenAddinInstncWorkbook = True
            Else
                mMe.RenewLogResult("(Re)opening the 'CompMan-Addin' (" & CompManAddinName & ") failed with:" & vbLf & _
                                   "(" & Err.Description & ")" _
                                  ) = "Failed"
            End If
        End If
    End If

xt: Exit Function

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Function

Private Sub Renew_9_RestoreReferencesToAddIn()
    Const PROC = "Renew_9_RestoreReferencesToAddIn"
    
    On Error GoTo eh
    Dim v               As Variant
    Dim wb              As Workbook
    Dim sWbs            As String
    Dim bOneRestored    As Boolean
    
    mMe.RenewLogAction = "Restore all saved 'References' to the 'CompMan-Addin' in open Workbooks"
    
    For Each v In dctAddInRefs
        Set wb = v
        wb.VBProject.References.AddFromFile CompManAddinFullName
        sWbs = wb.name & ", " & sWbs
        bOneRestored = True
    Next v
    
    If bOneRestored Then
        sWbs = Left(sWbs, Len(sWbs) - 2)
        mMe.RenewLogResult() = "Passed"
    Else
        mMe.RenewLogResult(sRenewAction & vbLf & "Restoring 'References' did not find any saved to restore" _
                          ) = "Passed"
    End If
    
xt: Exit Sub
    
eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub SaveAddinInstncWorkbookAsDevlp()
    Const PROC = "SaveAddinInstncWorkbookAsDevlp"

    On Error GoTo eh
    Dim fso As New FileSystemObject
    
    With Application
        If Not DevInstncWorkbookExists Then
            '~~ At this point the Development instance Workbook must no longer exist at its location
            .EnableEvents = False
            mMe.RenewLogAction = "Save the 'CompMan-Addin' (" & CompManAddinName & ") as 'Development-Instance-Workbook' (" & DevInstncName & ")"
            
            On Error Resume Next
            wbAddIn.SaveAs DevInstncFullName, FileFormat:=xlDevlpFormat, ReadOnlyRecommended:=False
            
            If Not mCompMan.WbkIsOpen(io_name:=DevInstncName) _
            Then Stop _
            Else wbDevlp.VBProject.name = fso.GetBaseName(DevInstncName)
            
            If Err.Number <> 0 Then
                mMe.RenewLogResult("Saving the 'CompMan-Addin' (" & CompManAddinName & ") as 'Development-Instance-Workbook' (" & DevInstncName & ") failed!" _
                                  ) = "Failed"
            Else
                mMe.RenewLogResult() = "Passed"
            End If
            .EnableEvents = True
        Else ' file still exists
            mMe.RenewLogResult("Saving the 'CompMan-Addin' (" & CompManAddinName & ") as 'Development-Instance-Workbook' (" & DevInstncName & ") failed!" _
                              ) = "Failed"
        End If
    End With

xt: Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Sub

Private Sub TrustThisFolder(Optional ByVal FolderPath As String, _
                            Optional ByVal TrustNetworkFolders As Boolean = False, _
                            Optional ByVal sDescription As String)
' ---------------------------------------------------------------------------
' Add a folder to the 'Trusted Locations' list so that your project's VBA can
' open Excel files without raising errors like "Office has detected a problem
' with this file. To help protect your computer this file cannot be opened."
' Ths function has been implemented to fail silently on error: if you suspect
' that users don't have permission to assign 'Trusted Location' status in all
' locations, reformulate this as a function returning True or False
'
' Nigel Heffernan January 2015
'
' Based on code published by Daniel Pineault in DevHut.net on June 23, 2010:
' www.devhut.net\2010\06\23\vbscript-createset-trusted-location-using-vbscript\
' **** **** **** ****  THIS CODE IS IN THE PUBLIC DOMAIN  **** **** **** ****
' UNIT TESTING:
'
' 1:    Reinstate the commented-out line 'Debug.Print sSubKey & vbTab & sPath
' 2:    Open the Immediate Window and run this command:
'           TrustThisFolder "Z:\", True, True, "The user's home directory"
' 3:    If  "Z:\"  is already in the list, choose another folder
' 4:    Repeat step 2 or 3: the folder should be listed in the debug output
' 5:    If it isn't listed, disable the error-handler and record any errors
' -----------------------------------------------------------------------------
    Const PROC = "TrustThisFolder"
    Const HKEY_CURRENT_USER = &H80000001
    
    On Error GoTo eh
    Dim sKeyPath            As String
    Dim oRegistry           As Object
    Dim sSubKey             As String
    Dim oSubKeys            As Variant   ' type not specified. After it's populated, it can be iterated
    Dim oSubKey             As Variant   ' type not specified.
    Dim bSubFolders         As Boolean
    Dim bNetworkLocation    As Boolean
    Dim iTrustNetwork       As Long
    Dim sPath               As String
    Dim i                   As Long
    Dim fso                 As New FileSystemObject
    
    bSubFolders = True
    bNetworkLocation = False

    With fso
        If FolderPath = "" Then
            FolderPath = .GetSpecialFolder(2).Path
            If sDescription = "" Then
                sDescription = "The user's local temp folder"
            End If
        End If
    End With

    If Right(FolderPath, 1) <> "\" Then
        FolderPath = FolderPath & "\"
    End If

    sKeyPath = ""
    sKeyPath = sKeyPath & "SOFTWARE\Microsoft\Office\"
    sKeyPath = sKeyPath & Application.Version
    sKeyPath = sKeyPath & "\Excel\Security\Trusted Locations\"
     
    Set oRegistry = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & "." & "\root\default:StdRegProv")
    '~~ Note: not the usual \root\cimv2  for WMI scripting: the StdRegProv isn't in that folder
    oRegistry.EnumKey HKEY_CURRENT_USER, sKeyPath, oSubKeys
    
    For Each oSubKey In oSubKeys
        sSubKey = CStr(oSubKey)
        oRegistry.GetStringValue HKEY_CURRENT_USER, sKeyPath & "\" & sSubKey, "Path", sPath
        If sPath = FolderPath Then
            Exit For
        End If
    Next oSubKey
    
    If sPath <> FolderPath Then
        If IsNumeric(Replace(sSubKey, "Location", "")) _
        Then i = CLng(Replace(sSubKey, "Location", "")) + 1 _
        Else i = UBound(oSubKeys) + 1
        
        sSubKey = "Location" & CStr(i)
        
        If TrustNetworkFolders Then
            iTrustNetwork = 1
            oRegistry.GetDWORDValue HKEY_CURRENT_USER, sKeyPath, "AllowNetworkLocations", iTrustNetwork
            If iTrustNetwork = 0 Then
                oRegistry.SetDWORDValue HKEY_CURRENT_USER, sKeyPath, "AllowNetworkLocations", 1
            End If
        End If
        
        oRegistry.CreateKey HKEY_CURRENT_USER, sKeyPath & "\" & sSubKey
        oRegistry.SetStringValue HKEY_CURRENT_USER, sKeyPath & "\" & sSubKey, "Path", FolderPath
        oRegistry.SetStringValue HKEY_CURRENT_USER, sKeyPath & "\" & sSubKey, "Description", sDescription
        oRegistry.SetDWORDValue HKEY_CURRENT_USER, sKeyPath & "\" & sSubKey, "AllowSubFolders", 1

    End If

xt: Set fso = Nothing
    Set oRegistry = Nothing
    Exit Sub

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOptResumeErrorLine: Stop: Resume
        Case mErH.DebugOptResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: GoTo xt
    End Select
End Sub

Private Sub StartupPath()
    Debug.Print Application.StartupPath
    Application.AltStartupPath = mMe.CompManAddinFolder
    Debug.Print Application.AltStartupPath
    
End Sub
