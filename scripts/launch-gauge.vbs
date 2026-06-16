' Context Gauge — silent launcher (no console window)
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

root = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))
exe = root & "\src-tauri\target\release\context-gauge.exe"
If Not objFSO.FileExists(exe) Then
    exe = root & "\src-tauri\target\debug\context-gauge.exe"
End If

' Check if already running
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
Set colProcesses = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'context-gauge.exe'")

If colProcesses.Count = 0 Then
    If objFSO.FileExists(exe) Then
        objShell.Run """" & exe & """", 0, False
    End If
End If

' Also write idle state if requested
If WScript.Arguments.Count > 0 Then
    state = WScript.Arguments(0)
    tempDir = objShell.ExpandEnvironmentStrings("%TEMP%")
    gaugeFile = tempDir & "\claude-context-gauge.json"

    remaining = 100
    If objFSO.FileExists(gaugeFile) Then
        On Error Resume Next
        Set file = objFSO.OpenTextFile(gaugeFile, 1)
        content = file.ReadAll
        file.Close
        ' Simple parse: find "remaining":number
        pos = InStr(content, """remaining"":")
        If pos > 0 Then
            numStr = Mid(content, pos + 13)
            numEnd = InStr(numStr, ",")
            If numEnd = 0 Then numEnd = InStr(numStr, "}")
            If numEnd > 0 Then
                remaining = Int(CDbl(Left(numStr, numEnd - 1)))
            End If
        End If
        On Error GoTo 0
    End If

    data = "{""remaining"":" & remaining & ",""status"":""" & state & """,""timestamp"":""" & Now & """}"
    Set file = objFSO.CreateTextFile(gaugeFile, True)
    file.Write data
    file.Close
End If
