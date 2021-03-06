VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsStats"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit
' -----------------------------------
' Class Module clsStats
' CompMan services statistics
' ----------------------------------
Private aCount() As Long
Private lMaxLen As Long

Public Sub Clear()
    ReDim aCount(0)
    aCount(0) = 0
End Sub

Public Property Get AlignedValue(ByVal sic As siCounter) As String
    Dim v       As Variant
    Dim Value   As Long
    
    If lMaxLen = 0 Then
        For Each v In aCount
            lMaxLen = Max(lMaxLen, Len(CStr(v)))
        Next v
    End If
    
    Value = Me.Total(sic)
    If sic = sic_non_doc_mod_total Then
        Value = Me.Total(sic_comps_total) - Me.Total(sic_sheets_total) - 1
    End If
    
    AlignedValue = mBasic.Align(CStr(Value), lMaxLen, AlignRight)
End Property

Public Property Get Total(Optional ByVal sic As siCounter) As Long
    If UBound(aCount) < sic Then Total = 0 Else Total = aCount(sic)
End Property

Public Sub Count( _
  Optional ByVal c_sic As siCounter, _
  Optional ByVal c_value As Long = 1)
' ----------------------------------
' Adds the (value) to the array
' aCount under the index (c_sic).
' ----------------------------------
    If UBound(aCount) < c_sic Then
        ReDim Preserve aCount(c_sic)
    End If
    aCount(c_sic) = aCount(c_sic) + c_value
End Sub

Private Sub Class_Initialize()
    Clear
End Sub
