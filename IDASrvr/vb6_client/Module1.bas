Attribute VB_Name = "Module1"
Private Type COPYDATASTRUCT
    dwFlag As Long
    cbSize As Long
    lpData As Long
End Type

 Public Const GWL_WNDPROC = (-4)
 Public Const WM_COPYDATA = &H4A
 Global lpPrevWndProc As Long
 Global subclassed_hwnd As Long
 Global IDA_HWND As Long
 Global ResponseBuffer As String
 
 Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (hpvDest As Any, hpvSource As Any, ByVal cbCopy As Long)
 Private Declare Function CallWindowProc Lib "user32" Alias "CallWindowProcA" (ByVal lpPrevWndFunc As Long, ByVal hwnd As Long, ByVal msg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
 Private Declare Function SetWindowLong Lib "user32" Alias "SetWindowLongA" (ByVal hwnd As Long, ByVal nIndex As Long, ByVal dwNewLong As Long) As Long
 Private Declare Function SendMessage Lib "user32" Alias "SendMessageA" (ByVal hwnd As Long, ByVal wMsg As Long, ByVal wParam As Long, lParam As Any) As Long
 Declare Function IsWindow Lib "user32" (ByVal hwnd As Long) As Long
 Private Declare Function RegisterWindowMessage Lib "user32" Alias "RegisterWindowMessageA" (ByVal lpString As String) As Long
 Private Declare Function SendMessageTimeout Lib "user32" Alias "SendMessageTimeoutA" (ByVal hwnd As Long, ByVal msg As Long, ByVal wParam As Long, ByVal lParam As Long, ByVal fuFlags As Long, ByVal uTimeout As Long, lpdwResult As Long) As Long
 Private Const HWND_BROADCAST = &HFFFF&

 Private IDASRVR_BROADCAST_MESSAGE As Long
 Public Servers As New Collection
 
 Public Sub Hook(hwnd As Long)
     subclassed_hwnd = hwnd
     lpPrevWndProc = SetWindowLong(subclassed_hwnd, GWL_WNDPROC, AddressOf WindowProc)
     IDASRVR_BROADCAST_MESSAGE = RegisterWindowMessage("IDA_SERVER")
     FindActiveIDAWindows
 End Sub

 Function FindActiveIDAWindows() As Long
     Dim ret As Long
     'so a client starts up, it gets the message to use (system wide) and it broadcasts a message to all windows
     'looking for IDASrvr instances that are active. It passes its command window hwnd as wParam
     'IDASrvr windows will receive this, and respond to the HWND with the same IDASRVR message as a pingback
     'sending thier command window hwnd as the lParam to register themselves with the clients.
     'clients track these hwnds.
     
     Form1.List2.AddItem "Broadcasting message looking for IDASrvr instances msg= " & IDASRVR_BROADCAST_MESSAGE
     SendMessageTimeout HWND_BROADCAST, IDASRVR_BROADCAST_MESSAGE, subclassed_hwnd, 0, 0, 1000, ret
     
     ValidateActiveIDAWindows
     FindActiveIDAWindows = Servers.Count
     
 End Function

 Function ValidateActiveIDAWindows()
     On Error Resume Next
     Dim x
     For Each x In Servers 'remove any that arent still valid..
        If IsWindow(x) = 0 Then
            Servers.Remove "hwnd:" & x
        End If
     Next
 End Function
 
 Public Sub Unhook()
     Dim Temp As Long
     Temp = SetWindowLong(subclassed_hwnd, GWL_WNDPROC, lpPrevWndProc)
 End Sub

 Function WindowProc(ByVal hw As Long, ByVal uMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
     
     If uMsg = IDASRVR_BROADCAST_MESSAGE Then
        If IsWindow(lParam) = 1 Then
            If Not KeyExistsInCollection(Servers, "hwnd:" & lParam) Then
                Servers.Add lParam, "hwnd:" & lParam
                Form1.List2.AddItem "New IDASrvr registering itself hwnd= " & lParam
            End If
        End If
     End If
     
     If uMsg = WM_COPYDATA Then RecieveTextMessage lParam
     WindowProc = CallWindowProc(lpPrevWndProc, hw, uMsg, wParam, lParam)
     
 End Function

Function KeyExistsInCollection(c As Collection, val As String) As Boolean
    On Error GoTo nope
    Dim t
    t = c(val)
    KeyExistsInCollection = True
 Exit Function
nope: KeyExistsInCollection = False
End Function

Private Sub RecieveTextMessage(lParam As Long)
   
    Dim CopyData As COPYDATASTRUCT
    Dim Buffer(1 To 2048) As Byte
    Dim Temp As String
    Dim lpData As Long
    Dim sz As Long
    Dim tmp() As Byte
    ReDim tmp(30)
    
    CopyMemory CopyData, ByVal lParam, Len(CopyData)
    
    If CopyData.dwFlag = 3 Then
    
        CopyMemory tmp(0), ByVal lParam, Len(CopyData)
        'Text1 = HexDump(tmp, Len(CopyData))
        
        lpData = CopyData.lpData
        sz = CopyData.cbSize
        
        CopyMemory Buffer(1), ByVal lpData, sz
        Temp = StrConv(Buffer, vbUnicode)
        Temp = Left$(Temp, InStr(1, Temp, Chr$(0)) - 1)
        'heres where we work with the intercepted message
        Form1.List2.AddItem "Recv(" & Temp & ")"
        Form1.List2.AddItem ""
        ResponseBuffer = Temp
    End If
     
End Sub

Sub SendCMD(msg As String, Optional ByVal hwnd As Long)
    Dim cds As COPYDATASTRUCT
    Dim buf(1 To 255) As Byte
    
    If hwnd = 0 Then hwnd = IDA_HWND
    
    ResponseBuffer = Empty
    Form1.List2.AddItem "SendingCMD(hwnd=" & hwnd & ", msg=" & msg & ")"
    
    Call CopyMemory(buf(1), ByVal msg, Len(msg))
    cds.dwFlag = 3
    cds.cbSize = Len(msg) + 1
    cds.lpData = VarPtr(buf(1))
    i = SendMessage(hwnd, WM_COPYDATA, subclassed_hwnd, cds)
    'since SendMessage is syncrnous if the command has a response it will be received before this returns..
    
End Sub

Function SendCmdRecvText(cmd As String, Optional ByVal hwnd As Long) As String
    SendCMD cmd, hwnd
    SendCmdRecvText = ResponseBuffer
End Function

Function SendCmdRecvLong(cmd As String, Optional ByVal hwnd As Long) As Long
    SendCMD cmd, hwnd
    On Error Resume Next
    SendCmdRecvLong = CLng(ResponseBuffer)
End Function

