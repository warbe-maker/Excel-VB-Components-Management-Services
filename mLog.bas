Attribute VB_Name = "mLog"
Option Explicit

Private sService        As String
Private sServicedItem   As String
Private sFile           As String

Private Property Get LogFile() As File
    Dim fso As New FileSystemObject
    Set LogFile = fso.GetFile(sFile)
    Set fso = Nothing
End Property

Public Property Let ServiceProvided( _
                     Optional ByVal svp_by_wb As Workbook, _
                     Optional ByVal svp_for_wb As Workbook, _
                     Optional ByVal svp_new_log As Boolean = True, _
                              ByVal svp_name As String)
    sService = svp_by_wb.name & " > " & svp_name
    sFile = mMe.ServicesLogFile(svp_for_wb)
    
    If Not svp_new_log Then
        '~~ Write a service delimiter when this is not a new log but only a new provided service
        mFile.Txt(ft_file:=sFile _
                , ft_append:=Not svp_new_log _
                 ) = Format$(Now(), "YY-MM-DD hh:mm:ss") & " =========================================== "
    End If
    mFile.Txt(ft_file:=sFile _
            , ft_append:=Not svp_new_log _
             ) = Format$(Now(), "YY-MM-DD hh:mm:ss") & " Service: " & sService & " for: " & svp_for_wb.name
End Property

Public Property Let ServicedItem(ByVal s As String)
    sServicedItem = "Serviced item: " & s
End Property

Public Property Let Action(ByVal s As String)
' -------------------------------------------
' Appen an Action line to the log file.
' -------------------------------------------
    mFile.Txt(ft_file:=sFile _
            , ft_append:=True _
             ) = Format$(Now(), "YY-MM-DD hh:mm:ss") & " " & sServicedItem & ": " & s
End Property

Private Sub Class_Initialize()
    
    Dim fso As New FileSystemObject
    
    sFile = ThisWorkbook.Path & "\" & fso.GetBaseName(ThisWorkbook.FullName) & ".log"
    With fso
        If Not .FileExists(sFile) Then .CreateTextFile (sFile)
    End With
    Set fso = Nothing
    
End Sub

