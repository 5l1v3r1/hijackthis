Attribute VB_Name = "modTranslation"
Option Explicit

Private Declare Function GetUserDefaultUILanguage Lib "kernel32.dll" () As Long
Private Declare Function GetSystemDefaultUILanguage Lib "kernel32.dll" () As Long
Private Declare Function GetSystemDefaultLCID Lib "kernel32.dll" () As Long
Private Declare Function GetUserDefaultLCID Lib "kernel32.dll" () As Long
Private Declare Function GetLocaleInfo Lib "kernel32.dll" Alias "GetLocaleInfoW" (ByVal lcid As Long, ByVal LCTYPE As Long, ByVal lpLCData As Long, ByVal cchData As Long) As Long

Private Const LOCALE_SENGLANGUAGE = &H1001&

Private sLines$(), bDontPrompt As Boolean

Public Translate(1000) As String        'language strings selected by user
Public TranslateNative(1000) As String  'default system language strings


Public Sub LoadLanguageSettings()
    With OSVer
        .LangDisplayCode = GetUserDefaultUILanguage Mod &H10000
        .LangDisplayName = GetLangNameByCultureCode(.LangDisplayCode)
    
        .LangSystemCode = GetSystemDefaultUILanguage Mod &H10000
        .LangSystemName = GetLangNameByCultureCode(.LangSystemCode)
    
        .LangNonUnicodeCode = GetSystemDefaultLCID Mod &H10000
        .LangNonUnicodeName = GetLangNameByCultureCode(.LangNonUnicodeCode)
    End With
End Sub

Public Sub LoadLanguage(lCode As Long, Force As Boolean)
    Dim HasSupportSlavian As Boolean
    
    LoadLanguageSettings
    
    'If the language for programs that do not support Unicode controls set such
    'that does not contain Cyrillic, we need to use the English localization
    HasSupportSlavian = IsSlavianCultureCode(OSVer.LangNonUnicodeCode)
    
    ' Force choosing of language: no checks for non-Unicode language settings
    If Force Then
        Select Case lCode
        Case &H419&, &H422&, &H423& 'Russian, Ukrainian, Belarusian
            LangRU
        Case &H409& 'English
            LoadDefaultLanguage
        Case Else
            LoadDefaultLanguage
        End Select
        
        ReloadLanguageNative    'force flag defined by command line keys mean that any text should consist of one particular language
        
    Else
        ' first load native system language strings for special purposes
    
        Select Case OSVer.LangDisplayCode
        Case &H419&, &H422&, &H423& 'Russian, Ukrainian, Belarusian
            If HasSupportSlavian Then
                LangRU
            Else
                LoadDefaultLanguage
            End If
        Case &H409& 'English
            LoadDefaultLanguage
        Case Else
            LoadDefaultLanguage
        End Select
    
        ReloadLanguageNative    'fill TranlateNative() array
    
        Select Case lCode 'OSVer.LangDisplayCode
        Case &H419&, &H422&, &H423& 'Russian, Ukrainian, Belarusian
            If HasSupportSlavian Then
                LangRU
            Else
                If Not bAutoLog Then MsgBoxW "Cannot set Russian language!" & vbCrLf & _
                    "First, you must set language for non-Unicode programs to Russian" & vbCrLf & _
                    "trought the Control panel -> system language settings.", vbCritical
                LoadDefaultLanguage
            End If
        Case &H409& 'English
            LoadDefaultLanguage
        Case Else
            LoadDefaultLanguage
        End Select
    End If
    
    ReloadLanguage  'fill Translate() array & replace text on forms
End Sub

Function IsSlavianCultureCode(CultureCode As Long) As Boolean ' languages with Cyrillic alphabet
    Select Case CultureCode
        Case &H419&, &H422&, &H423&, &H402&
            IsSlavianCultureCode = True
    End Select
End Function

Public Function IsRussianLangCode(CultureCode As Long) As Boolean
    Select Case CultureCode
        Case &H419&, &H422&, &H423&
            IsRussianLangCode = True
    End Select
End Function

Function GetLangNameByCultureCode(lcid As Long) As String
    Dim buf As String
    Dim lr  As Long
    buf = Space$(1000)
    lr = GetLocaleInfo(lcid, LOCALE_SENGLANGUAGE, StrPtr(buf), ByVal 1000&)
    If lr Then
        GetLangNameByCultureCode = Left$(buf, lr - 1)
    End If
End Function

Public Sub LoadLanguageFile(sFile$, Optional bSilent As Boolean = False)
    Dim i&, J&, ff%
    If sFile = vbNullString Then Exit Sub
    If Not FileExists(BuildPath(AppPath(), sFile)) Then Exit Sub
    ff = FreeFile()
    Open BuildPath(AppPath(), sFile) For Input As #ff
        sLines = Split(Input(FileLenW(BuildPath(AppPath(), sFile)), #ff), vbCrLf)
    Close #ff
    
    If bSilent = True Then bDontPrompt = True
    
    For i = 0 To UBound(sLines)
        For J = 0 To UBound(sLines)
            If Len(sLines(i)) >= 3 And Len(sLines(J)) >= 3 Then
                If Val(Left$(sLines(i), 3)) > 0 And i <> J Then
                    If Left$(sLines(i), 3) = Left$(sLines(J), 3) Then
                        'MsgBoxW "The language file '" & sFile & "' is invalid (ambiguous id numbers)." & vbCrLf & vbCrLf & sLines(i) & vbCrLf & sLines(J), vbExclamation
                        MsgBoxW Replace$(Translate(570), "[]", sFile) & vbCrLf & vbCrLf & sLines(i) & vbCrLf & sLines(J), vbExclamation
                        Exit Sub
                    End If
                End If
            End If
        Next J
    Next i
    
    ReloadLanguage
End Sub

'Public Function Translate$(iRes&)
'    Dim i As Long
'    On Error GoTo ErrorHandler:
'    For i = 0 To UBound(sLines)
'        If Len(sLines(i)) >= 3 Then
'            If Val(Left$(sLines(i), 3)) = iRes Then
'                Translate = Replace$(Mid$(sLines(i), 5), "\n", vbCrLf)
'                Exit For
'            End If
'        End If
'    Next i
'    Exit Function
'
'ErrorHandler:
'    ErrorMsg Err, "modLanguage_Translate", iRes
'    If inIDE Then Stop: Resume Next
'End Function

Private Sub ReloadLanguageNative()
    Dim i&, pos&, ID&
    For i = 0 To UBound(sLines)
        If Len(sLines(i)) >= 3 Then
            pos = InStr(sLines(i), "=")
            If pos <> 0 Then
                If IsNumeric(Left$(sLines(i), pos - 1)) Then
                    ID = Val(Left$(sLines(i), pos - 1))
                    If UBound(TranslateNative) >= ID Then
                        TranslateNative(ID) = Replace$(Mid$(sLines(i), pos + 1), "\n", vbCrLf, 1, -1, 1)
                    Else
                        MsgBoxW "Language string ID is out of maximum allowed. Please increase the bound of array first."
                    End If
                End If
            End If
        End If
    Next
End Sub

Private Sub ReloadLanguage()
    Dim i&, Translation$, pos&, ID&
    On Error GoTo ErrorHandler:
    
    For i = 0 To UBound(sLines)
        If Len(sLines(i)) >= 3 Then
            pos = InStr(sLines(i), "=")
            If pos <> 0 Then
                If IsNumeric(Left$(sLines(i), pos - 1)) Then
                    ID = Val(Left$(sLines(i), pos - 1))
                    If UBound(Translate) >= ID Then
                        Translate(ID) = Replace$(Mid$(sLines(i), pos + 1), "\n", vbCrLf, 1, -1, 1)
                    Else
                        MsgBoxW "Language string ID is out of maximum allowed. Please increase the bound of array first."
                    End If
                End If
            End If
        End If
    Next
    
    With frmMain
        For i = 0 To UBound(sLines)
            If Len(sLines(i)) >= 3 Then
                sLines(i) = Replace$(sLines(i), "\n", vbCrLf)
                Translation = Mid$(sLines(i), 5)
                Select Case Left$(sLines(i), 3)
                    Case "// ":
                    Case "000"
                        If Not bDontPrompt Then
                            'If MsgBoxW("Load file for language '" & mid$(sLines(i), 5) & "'?", vbYesNo + vbQuestion) = vbNo Then
                            '    Exit Sub
                            'End If
                        End If
                        bDontPrompt = False
                    
                    Case "001": .lblInfo(0).Caption = Translation
                    Case "004": .lblInfo(1).Caption = Translation
                    Case "009": .cmdMainMenu.Caption = Translation
                    Case "010": .fraScan.Caption = Translation
                    Case "011": .cmdScan.Caption = Translation
                    Case "012":
                    Case "013": .cmdFix.Caption = Translation
                    Case "014": .cmdInfo.Caption = Translation
                    Case "015": .fraOther.Caption = Translation
                    Case "016": .cmdHelp.Caption = Translation
                    Case "017":
                    Case "018": If Not .fraConfig.Visible Then .cmdConfig.Caption = Translation
                    Case "019": If .fraConfig.Visible Then .cmdConfig.Caption = Translation
                    Case "020": .cmdSaveDef.Caption = Translation
                    
                    Case "030": .fraHelp.Caption = Translation
                    
                    Case "040": .fraConfig.Caption = Translation
                    Case "041": .chkConfigTabs(0).Caption = Translation
                    Case "042": .chkConfigTabs(1).Caption = Translation
                    Case "043": .chkConfigTabs(2).Caption = Translation
                    Case "044": .chkConfigTabs(3).Caption = Translation
                    
                    Case "050": .chkAutoMark.Caption = Translation
                    Case "051": .chkBackup.Caption = Translation
                    Case "052": .chkConfirm.Caption = Translation
                    Case "053": .chkIgnoreSafe.Caption = Translation
                    Case "054": .chkLogProcesses.Caption = Translation
                    Case "055": .chkShowN00bFrame.Caption = Translation
                    Case "056": .chkConfigStartupScan.Caption = Translation
                    Case "058": .chkSkipErrorMsg.Caption = Translation
                    
                    Case "060": .lblConfigInfo(3).Caption = Translation
                    Case "061": .lblConfigInfo(0).Caption = Translation
                    Case "062": .lblConfigInfo(1).Caption = Translation
                    Case "063": .lblConfigInfo(2).Caption = Translation
                    Case "064": .lblConfigInfo(4).Caption = Translation
                    
                    Case "070": .lblConfigInfo(5).Caption = Translation
                    Case "071": .cmdConfigIgnoreDelSel.Caption = Translation
                    Case "072": .cmdConfigIgnoreDelAll.Caption = Translation
                    
                    Case "080": .lblConfigInfo(6).Caption = Translation
                    Case "081": .cmdConfigBackupRestore.Caption = Translation
                    Case "082": .cmdConfigBackupDelete.Caption = Translation
                    Case "083": .cmdConfigBackupDeleteAll.Caption = Translation
                    
                    Case "090": .lblConfigInfo(7).Caption = Replace(Translation, "[]", StartupListVer)
                    Case "091": .cmdStartupList.Caption = Translation
                    Case "092": .chkStartupListFull.Caption = Translation
                    Case "093": .chkStartupListComplete.Caption = Translation
                    
                    Case "100": .lblConfigInfo(16).Caption = Translation
                    Case "101": .cmdProcessManager.Caption = Translation
                    Case "102": .lblConfigInfo(12).Caption = Translation
                    Case "103": .cmdHostsManager.Caption = Translation
                    Case "104": .lblConfigInfo(13).Caption = Translation
                    Case "105": .cmdDelOnReboot.Caption = Translation
                    Case "106": .lblInfo(2).Caption = Translation
                    Case "107": .cmdDeleteService.Caption = Translation
                    Case "108": .lblInfo(6).Caption = Translation
                    Case "109": .cmdADSSpy.Caption = Translation
                    
                    Case "110": .lblInfo(5).Caption = Translation & " (ADS Spy v." & ADSspyVer & ")"
                    Case "112": .lblInfo(7).Caption = Translation
                    
                    Case "120": .lblConfigInfo(17).Caption = Translation
                    Case "121": .chkDoMD5.Caption = Translation
                    Case "122": .chkAdvLogEnvVars.Caption = Translation
                    
                    Case "130": .lblConfigInfo(22).Caption = Translation
                    'Case "131": .cmdLangLoad.Caption = Translation
                    'Case "132": .cmdLangReset.Caption = Translation
                    
                    Case "140": .lblConfigInfo(18).Caption = Translation
                    Case "141": .cmdCheckUpdate.Caption = Translation
                    'Case "142": .lblConfigInfo(10).Caption = Translation    '''''
                    Case "143": .lblConfigInfo(11).Caption = Translation
                    
                    Case "150": .cmdUninstall.Caption = Translation
                    'Case "151": .cmdUninstall.Caption = Translation
                    Case "152": .lblUninstallHJT.Caption = Translation
                    
                    Case "160": .fraN00b.Caption = Translation
                    Case "161": .lblInfo(4).Caption = Translation
                    Case "162": .cmdN00bLog.Caption = Translation
                    Case "163": .cmdN00bScan.Caption = Translation
                    Case "164": .cmdN00bBackups.Caption = Translation
                    Case "165": .cmdN00bTools.Caption = Translation
                    Case "166": .cmdN00bHJTQuickStart.Caption = Translation
                    'Case "167": .lblInfo(5).Caption = Translation       '''''
                    Case "168": .cmdN00bClose.Caption = Translation
                    Case "169": .chkShowN00b.Caption = Translation
                    Case "183": .lblInfo(9).Caption = Translation
                    
                    Case "170": .fraProcessManager.Caption = Translation
                    Case "171": .lblConfigInfo(8).Caption = Translation
                    Case "172": .chkProcManShowDLLs.Caption = Translation
                    Case "173": .cmdProcManKill.Caption = Translation
                    Case "174": .cmdProcManRefresh.Caption = Translation
                    Case "175": .cmdProcManRun.Caption = Translation
                    Case "176": .cmdProcManBack.Caption = Translation
                    Case "177": .lblProcManDblClick.Caption = Translation
                    
                                      
                    Case "209": .cmdUninstManUninstall.Caption = Translation
                    Case "210": .fraUninstMan.Caption = Translation
                    Case "211": .lblInfo(11).Caption = Translation
                    Case "212": .lblInfo(8).Caption = Translation
                    Case "213": .lblInfo(10).Caption = Translation
                    Case "214": .cmdUninstManDelete.Caption = Translation
                    Case "215": .cmdUninstManEdit.Caption = Translation
                    Case "216": .cmdUninstManOpen.Caption = Translation
                    Case "217": .cmdUninstManRefresh.Caption = Translation
                    Case "218": .cmdUninstManSave.Caption = Translation
                    Case "219": .cmdUninstManBack.Caption = Translation
                    Case "224": .cmdARSMan.Caption = Translation
                    
                    Case "270": .fraHostsMan.Caption = Translation
                    Case "271": .lblConfigInfo(14).Caption = Translation
                    Case "272": .cmdHostsManDel.Caption = Translation
                    Case "273": .cmdHostsManToggle.Caption = Translation
                    Case "274": .cmdHostsManOpen.Caption = Translation
                    Case "275": .cmdHostsManBack.Caption = Translation
                    Case "276": .lblConfigInfo(15).Caption = Translation
                    
                    Case "521": .cmdAnalyze.Caption = Translation
                    
                    Case "999": SetCharSet CInt(Translation)
                End Select
            End If
        Next i
    End With
    Exit Sub
ErrorHandler:
    If MsgBoxW("Invalid language file" & _
              IIf(err.Number > 0, " (" & err.Description & ") ", vbNullString) & _
              ". Reset to default (English)?", vbYesNo + vbExclamation) = vbYes Then
        LoadDefaultLanguage
        ReloadLanguage
    End If
    If inIDE Then Stop: Resume Next
End Sub

Public Sub LoadDefaultLanguage()
    Dim s$
    s = _
    "// main form" & vbCrLf & _
    "001=Welcome to HiJackThis. This program will generate a report of unusual items \n(files, registry modifications e.t.c.) in the most vulnerable areas of the operating system \ncommonly manipulated by malware as well as a good software." & vbCrLf & _
    "002=HiJackThis is already running." & vbCrLf & _
    "003=Warning!\n\nSince HiJackThis targets browser hijacking methods instead of actual browser hijackers, entries may appear in the scan list that are not hijackers. Be careful what you delete, some system utilities can cause problems if disabled.\nFor best results, ask spyware experts for help and show them your scan log. They will advise you what to fix and what to keep.\n\nSome adware-supported programs may cease to function if the associated adware is removed." & vbCrLf & _
    "004=Below are the results of the HiJackThis scan. Be careful what you delete with the 'Fix checked' button. Scan results do not determine whether an item is bad or not. The best thing to do is to 'AnalyzeThis' and show the log file to knowledgeable folks." & vbCrLf & _
    "// main screen" & vbCrLf & _
    "009=Main Menu" & vbCrLf & _
    "010=Scan && fix stuff" & vbCrLf & _
    "011=Scan" & vbCrLf & _
    "012=Save log" & vbCrLf & _
    "013=Fix checked" & vbCrLf & _
    "014=Info on selected item..." & vbCrLf & _
    "015=Other stuff" & vbCrLf & _
    "016=Info..." & vbCrLf & _
    "017=Back" & vbCrLf & _
    "018=Config..." & vbCrLf & _
    "019=Back" & vbCrLf & _
    "020=Add checked to ignorelist" & vbCrLf & _
    "021=Nothing selected! Continue?" & vbCrLf & _
    "022=You selected to fix everything HiJackThis has found. This could mean items important to your system will be deleted and the full functionality of your system will degrade.\n\nIf you aren't sure how to use HiJackThis, you should ask for help, not blindly fix things. Many 3rd party resources are available on the web that will gladly help you with your log.\n\nAre you sure you want to fix all items in your scan results?" & vbCrLf
    s = s & "023=Fix [] selected items? This will permanently delete and/or repair what you selected" & vbCrLf & _
    "024=unless you enable backups." & vbCrLf & _
    "025=This will set HiJackThis to ignore the checked items, unless they change. Continue?" & vbCrLf & _
    "026=Write access was denied to the location you specified. Try a different location please." & vbCrLf & _
    "027=The logfile has been saved to [].\nYou can open it in a text editor like Notepad." & vbCrLf & _
    "028=Unable to list running processes" & vbCrLf & _
    "029=Running processes" & vbCrLf & _
    "// help dialog" & vbCrLf & _
    "030=Help" & vbCrLf & _
    "// config tabs" & vbCrLf & _
    "040=Configuration" & vbCrLf & _
    "041=Main" & vbCrLf & _
    "042=Ignorelist" & vbCrLf & _
    "043=Backups" & vbCrLf & _
    "044=Misc Tools" & vbCrLf & _
    "// 'main' tab" & vbCrLf & _
    "050=Mark everything found for fixing after scan" & vbCrLf & _
    "051=Make backups before fixing items" & vbCrLf & _
    "052=Confirm fixing && ignoring of items (safe mode)" & vbCrLf & _
    "053=Ignore non-standard but safe domains in IE (e.g. msn.com, microsoft.com)" & vbCrLf
    s = s & "054=Include list of running processes in logfiles" & vbCrLf & _
    "055=Do not show intro frame at startup" & vbCrLf & _
    "056=Run HiJackThis scan at Windows startup and show results only if items are found" & vbCrLf & _
    "057=Are you sure you want to enable this option? \nHiJackThis is not a 'click & fix' program. Because it targets *general* hijacking methods, false positives are a frequent occurrence.\nIf you enable this option, you might disable programs or drivers you need. However, it is highly unlikely you will break your system beyond repair. So you should only enable this option if you know what you're doing!" & vbCrLf & _
    "058=Do not show error messages" & vbCrLf & _
    "060=Below URLs will be used when fixing hijacked/unwanted MSIE pages:" & vbCrLf & _
    "061=Default Start Page:" & vbCrLf & _
    "062=Default Search Page:" & vbCrLf & _
    "063=Default Search Assistant:" & vbCrLf & _
    "064=Default Search Customize:" & vbCrLf & _
    "// 'ignorelist' tab" & vbCrLf & _
    "070=The following items will be ignored when scanning:" & vbCrLf & _
    "071=Delete" & vbCrLf & _
    "072=Delete all" & vbCrLf & _
    "// 'backups' tab" & vbCrLf & _
    "080=This is your list of items that were backed up. You can restore them (causing HiJackThis to re-detect them unless you place them on the ignorelist) or delete them from here. (Antivirus programs may detect HiJackThis backups!)" & vbCrLf & _
    "081=Restore" & vbCrLf & _
    "082=Delete" & vbCrLf & _
    "083=Delete all" & vbCrLf & _
    "084=Are you sure you want to delete this backup?" & vbCrLf & _
    "085=Are you sure you want to delete these [] backups?" & vbCrLf
    s = s & "086=Restore this item?" & vbCrLf & _
    "087=Restore these [] items?" & vbCrLf & _
    "088=Are you sure you want to delete ALL backups?" & vbCrLf & _
    "// 'misc tools' tab" & vbCrLf & _
    "090=StartupList v.[]" & vbCrLf & _
    "091=Generate StartupList log" & vbCrLf & _
    "092=List also minor sections (full)" & vbCrLf & _
    "093=List empty sections (complete)" & vbCrLf & _
    "100=System tools" & vbCrLf & _
    "101=Process manager" & vbCrLf & _
    "102=Small process manager, working much like the Task Manager." & vbCrLf & _
    "103=Hosts file manager" & vbCrLf & _
    "104=Editor for the 'hosts' file." & vbCrLf & _
    "105=Delete a file on reboot..." & vbCrLf & _
    "106=If a file cannot be removed from memory, Windows can be setup to delete it when the system is restarted." & vbCrLf & _
    "107=Delete an Windows service..." & vbCrLf & _
    "108=Delete a Windows Service (O23).\nUSE WITH CAUTION!" & vbCrLf & _
    "109=ADS Spy" & vbCrLf & _
    "110=Scan for hidden data streams." & vbCrLf & _
    "111=Manage the items in the Add/Remove Software list." & vbCrLf
    s = s & "112=Open a utility to manage the items in the Add/Remove Software list." & vbCrLf & _
    "113=Enter the exact service name as it appears in the scan results, or the short name between brackets if that is listed.\nThe service needs to be stopped and disabled.\nWARNING! When the service is deleted, it cannot be restored!" & vbCrLf & _
    "114=Delete a Windows NT Service" & vbCrLf & _
    "115=Service '[]' was not found in the Registry.\nMake sure you entered the name of the service correctly." & vbCrLf & _
    "116=The service '[]' is enabled and/or running. Disable it first, using HiJackThis itself (from the scan results) or the Services.msc window." & vbCrLf & _
    "117=The following service was found:" & vbCrLf & _
    "118=Are you absolutely sure you want to delete this service?" & vbCrLf & _
    "120=Advanced settings (these will not be saved)" & vbCrLf & _
    "121=Calculate MD5 of files if possible" & vbCrLf & _
    "122=Include environment variables in logfile" & vbCrLf & _
    "140=Update check" & vbCrLf & _
    "141=Check for update online" & vbCrLf & _
    "142=" & vbCrLf & _
    "143=Use this proxy server (host:port) :" & vbCrLf & _
    "150=Uninstall HiJackThis" & vbCrLf & _
    "151=Uninstall HiJackThis && exit" & vbCrLf & _
    "152=Removes all Registry settings and exits." & vbCrLf
    s = s & "153=This will remove HiJackThis' settings from the Registry and exit. Note that you will have to delete the HiJackThis.exe file manually.\n\nContinue with uninstall?" & vbCrLf & _
    "// n00b screen" & vbCrLf & _
    "160=Main Menu" & vbCrLf & _
    "161=What would you like to do?" & vbCrLf & _
    "162=Do a system scan and save a logfile" & vbCrLf & _
    "163=Do a system scan only" & vbCrLf & _
    "164=List of Backups" & vbCrLf & _
    "165=Misc Tools" & vbCrLf & _
    "166=Online Guide" & vbCrLf & _
    "167=" & vbCrLf & _
    "168=None of above, just start the program" & vbCrLf & _
    "169=Do not show this menu again" & vbCrLf & _
    "183=Language:" & vbCrLf & _
    "// Process Manager" & vbCrLf & _
    "170=Process Manager" & vbCrLf & _
    "171=Running processes:" & vbCrLf & _
    "172=Show DLLs" & vbCrLf & _
    "173=Kill process" & vbCrLf & _
    "174=Refresh" & vbCrLf & _
    "175=Run.." & vbCrLf & _
    "176=Back" & vbCrLf
    s = s & "177=Double-click a file to view its properties" & vbCrLf & _
    "178=Loaded DLL libraries by selected process:" & vbCrLf & _
    "179=Are you sure you want to close the processes []?" & vbCrLf & _
    "180=Any unsaved data in it will be lost." & vbCrLf & _
    "181=Run" & vbCrLf & _
    "182=Type the name of a program, folder, document or Internet resource, and Windows will open it for you." & vbCrLf & _
    "184=You should select the process first you want to kill!" & vbCrLf & _
    "// Hosts file manager" & vbCrLf & _
    "270=Hosts file manager" & vbCrLf & _
    "271=Hosts file is located at" & vbCrLf & _
    "272=Delete line(s)" & vbCrLf & _
    "273=Toggle line(s)" & vbCrLf & _
    "274=Open in editor" & vbCrLf & _
    "275=Back" & vbCrLf & _
    "276=Note: changes to the hosts file take effect when you restart your browser." & vbCrLf & _
    "277=Attributes:" & vbCrLf & _
    "278=Lines:" & vbCrLf & _
    "// ADS Spy" & vbCrLf & _
    "190=ADS Spy" & vbCrLf & _
    "191=Quick scan (Windows base folder only)" & vbCrLf & _
    "192=Ignore safe system info streams" & vbCrLf & _
    "193=Calculate MD5 checksum of streams" & vbCrLf & _
    "194=What's this?" & vbCrLf
    s = s & "195=Help" & vbCrLf & _
    "196=Scan" & vbCrLf & _
    "197=Save log..." & vbCrLf & _
    "198=Remove selected" & vbCrLf & _
    "199=Back" & vbCrLf & _
    "200=Ready." & vbCrLf & _
    "201=Using ADS Spy is very easy: just click 'Scan', wait until the scan completes, then select the ADS streams you want to remove and click 'Remove selected'. If you are unsure which streams to remove, ask someone for help. Don't delete streams if you don't know what they are!\n\nThe three checkboxes are:\n\nQuick Scan: only scans the Windows folder. So far all known malware that uses ADS to hide itself, hides in the Windows folder. Unchecking this will make ADS Spy scan the entire system (i.e. all drives).\n\nIgnore safe system info streams: Windows, Internet Explorer and a few antivirus programs use ADS to store metadata for certain folders and files. These streams can safely be ignored, they are harmless.\n\nCalculate MD5 checksums of streams: For antispyware program development or antivirus analysis only.\n\nNote: the default settings of above three checkboxes should be fine for most people. There's no need to change any of them unless you are a developer or anti-malware expert." & vbCrLf & _
    "202=Abort" & vbCrLf & _
    "203=Scan aborted!" & vbCrLf & _
    "204=Scan complete." & vbCrLf & _
    "205=Alternate Data Streams (ADSs) are pieces of info hidden as metadata on files. They are not visible in Explorer and the size they take up is not reported by Windows. Recent browser hijackers started hiding their files inside ADSs, and very few anti-malware scanners detect this (yet).\nUse ADS Spy to find and remove these streams.\nNote: this app also displays legitimate ADS streams. Do not delete streams if you are not completely sure they are malicious!" & vbCrLf & _
    "// Uninstall Manager" & vbCrLf & _
    "209=Uninstall application" & vbCrLf & _
    "210=Add/Remove Programs Manager" & vbCrLf & _
    "211=Here you can see the list of programs in the Add/Remove Software list in the Control Panel. You can edit the uninstall command, or the record only or uninstall the program completely. Beware, restoring a deleted record or application is not possible!" & vbCrLf & _
    "212=Name:" & vbCrLf & _
    "213=Uninstall command:" & vbCrLf & _
    "214=Delete this entry" & vbCrLf & _
    "215=Edit uninstall command" & vbCrLf & _
    "216=Open Add/Remove Software list" & vbCrLf & _
    "217=Refresh list" & vbCrLf
    s = s & "218=Save list..." & vbCrLf & _
    "219=Back" & vbCrLf & _
    "220=Are you sure you want to delete this item from the list?" & vbCrLf & _
    "221=Enter the new uninstall command for this program" & vbCrLf & _
    "222=New uninstall string saved!" & vbCrLf & _
    "223=Are you sure, you want to uninstall " & vbCrLf & _
    "224=Uninstall manager" & vbCrLf & _
    "// Status during scan" & vbCrLf & _
    "230=IE Registry values" & vbCrLf & _
    "231=INI file values" & vbCrLf & _
    "232=Netscape/Mozilla homepage" & vbCrLf & _
    "233=O1 - Hosts file redirection" & vbCrLf & _
    "234=O2 - BHO enumeration" & vbCrLf & _
    "235=O3 - Toolbar enumeration" & vbCrLf & _
    "236=O4 - Registry && Start Menu autoruns" & vbCrLf & _
    "237=O5 - Control Panel: IE Options" & vbCrLf & _
    "238=O6 - Policies: IE Options menuitem" & vbCrLf & _
    "239=O7 - Policies: Regedit" & vbCrLf & _
    "240=O8 - IE contextmenu items enumeration" & vbCrLf & _
    "241=O9 - IE 'Tools' menuitems and buttons enumeration" & vbCrLf & _
    "242=O10 - Winsock LSP hijackers" & vbCrLf & _
    "243=O11 - Extra options groups in IE Advanced Options" & vbCrLf
    s = s & "244=O12 - IE plugins enumeration" & vbCrLf & _
    "245=O13 - DefaultPrefix hijack" & vbCrLf & _
    "246=O14 - IERESET.INF hijack" & vbCrLf & _
    "247=O15 - Trusted Zone enumeration" & vbCrLf & _
    "248=O16 - DPF object enumeration" & vbCrLf & _
    "249=O17 - DNS && DNS Suffix settings" & vbCrLf & _
    "250=O18 - Protocol && Filter enumeration" & vbCrLf & _
    "251=O19 - User stylesheet hijack" & vbCrLf & _
    "252=O20 - AppInit_DLLs Registry value" & vbCrLf & _
    "253=O21 - ShellServiceObjectDelayLoad Registry key" & vbCrLf & _
    "254=O22 - SharedTaskScheduler Registry key" & vbCrLf & _
    "255=O23 - NT Services" & vbCrLf & _
    "256=Completed!" & vbCrLf & _
    "257=O24 - ActiveX Desktop Components" & vbCrLf & _
    "258=O25 - WMI Event consumers" & vbCrLf & _
    "259=Making backup" & vbCrLf & _
    "// msgboxes and stuff in scan methods" & vbCrLf & _
    "300=For some reason your system denied write access to the Hosts file. If any hijacked domains are in this file, HiJackThis may NOT be able to fix this.\n\nIf that happens, you need to edit the file yourself. To do this, click Start, Run and type:\n\n   notepad []\n\nand press Enter. Find the line(s) HiJackThis reports and delete them. Save the file as 'hosts.' (with quotes), and reboot.\n\nFor Vista and above: simply, exit HiJackThis, right click on the HiJackThis icon, choose 'Run as administrator'." & vbCrLf & _
    "301=Your hosts file has invalid linebreaks and HiJackThis is unable to fix this. O1 items will not be displayed.\n\nClick OK to continue the rest of the scan." & vbCrLf & _
    "302=You have an particularly large amount of hijacked domains. It's probably better to delete the file itself then to fix each item (and create a backup).\n\nIf you see the same IP address in all the reported O1 items, consider deleting your Hosts file, which is located at [].\n\nWould you like to open its folder now?" & vbCrLf & _
    "303=HiJackThis could not write the selected changes to your hosts file. The probably cause is that some program is denying access to it, or that your user account doesn't have the rights to write to it." & vbCrLf & _
    "310=HiJackThis is about to remove a BHO and the corresponding file from your system. Close all Internet Explorer windows AND all Windows Explorer windows before continuing for the best chance of success." & vbCrLf & _
    "320=Unable to delete the file:\n[]\n\nThe file may be in use." & vbCrLf
    s = s & "321=Use Task Manager to shutdown the program" & vbCrLf & _
    "322=Use a process killer like ProcView to shutdown the program" & vbCrLf & _
    "323=and run HiJackThis again to delete the file." & vbCrLf & _
    "330=HiJackThis is about to remove a plugin from your system. Close all Internet Explorer windows before continuing for the best chance of success." & vbCrLf & _
    "340=It looks like you're running HiJackThis from a read-only device like a CD or locked floppy disk.If you want to make backups of items you fix, you must copy HiJackThis.exe to your hard disk first, and run it from there.\n\nIf you continue, you might get 'Path/File Access' errors." & vbCrLf & _
    "341=Launch from the archive is forbidden !\n\nMay I unzip to desktop for you ?" & vbCrLf & _
    "342=The file '[]' will be deleted by Windows when the system restarts." & vbCrLf & _
    "343=The service '[]'  has been marked for deletion." & vbCrLf & _
    "344=Unable to delete the service '[]'. Make sure the name is correct and the service is not running." & vbCrLf
    
    '"341=HiJackThis appears to have been started from a temporary folder. Since temp folders tend to be be emptied regularly, it's wise to copy HiJackThis.exe to a folder of its own, for instance C:\Program Files\HiJackThis.\nThis way, any backups that will be made of fixed items won't be lost.\n\nPlease quit HiJackThis and copy it to a separate folder first before fixing any items." & vbCrLf & _

    Dim Help$
    '// Help info
    
    '"* Trend Micro HiJackThis v" & App.Major & "." & App.Minor & "." & App.Revision & " *" & "\n" & _

    Help = "\n" & _
     AppVer & _
     "\n" & "\n" & "See bottom for version history." & "\n" & "\n"

    Help = Help & "The different sections of hijacking " & _
     "possibilities have been separated into the following groups." & "\n" & _
     "You can get more detailed information about an item " & _
     "by selecting it from the list of found items OR " & _
     "highlighting the relevant line below, and clicking " & _
     "'Info on selected item'." & "\n" & "\n" & _
     " R - Registry, StartPage/SearchPage changes" & "\n" & _
     "    R0 - Changed registry value" & "\n" & _
     "    R1 - Created registry value" & "\n" & _
     "    R2 - Created registry key" & "\n" & _
     "    R3 - Created extra registry value where only one should be" & "\n" & _
     " F - IniFiles, autoloading entries" & "\n" & _
     "    F0 - Changed inifile value" & "\n" & _
     "    F1 - Created inifile value" & "\n" & _
     "    F2 - Changed inifile value, mapped to Registry" & "\n" & _
     "    F3 - Created inifile value, mapped to Registry" & "\n"
    ' " N - Netscape/Mozilla StartPage/SearchPage changes" & "\n" & _
    ' "    N1 - Change in prefs.js of Netscape 4.x" & "\n" & _
    ' "    N2 - Change in prefs.js of Netscape 6" & "\n" & _
    ' "    N3 - Change in prefs.js of Netscape 7" & "\n" & _
    ' "    N4 - Change in prefs.js of Mozilla" & "\n"
    Help = Help & _
     " O - Other, several sections which represent:" & "\n" & _
     "    O1 - Hijack of Hosts / hosts.ics files, DNSApi" & "\n" & _
     "    O2 - Enumeration of existing MSIE BHO's" & "\n" & _
     "    O3 - Enumeration of existing MSIE toolbars" & "\n" & _
     "    O4 - Enumeration of suspicious autoloading Registry entries / msconfig disabled items" & "\n" & _
     "    O5 - Blocking of loading Internet Options in Control Panel" & "\n" & _
     "    O6 - Disabling of 'Internet Options' Main tab with Policies" & "\n" & _
     "    O7 - Disabling of Regedit with Policies" & "\n" & _
     "    O8 - Extra MSIE context menu items" & "\n"
    Help = Help & _
     "    O9 - Extra 'Tools' menuitems and buttons" & "\n" & _
     "    O10 - Breaking of Internet access by New.Net or WebHancer" & "\n" & _
     "    O11 - Extra options in MSIE 'Advanced' settings tab" & "\n" & _
     "    O12 - MSIE plugins for file extensions or MIME types" & "\n" & _
     "    O13 - Hijack of default URL prefixes" & "\n" & _
     "    O14 - Changing of IERESET.INF" & "\n" & _
     "    O15 - Trusted Zone Autoadd" & "\n" & _
     "    O16 - Download Program Files item" & "\n" & _
     "    O17 - Domain hijack / DHCP DNS" & "\n" & _
     "    O18 - Enumeration of existing protocols and filters" & "\n" & _
     "    O19 - User stylesheet hijack" & "\n" & _
     "    O20 - AppInit_DLLs autorun Registry value, Winlogon Notify Registry keys" & "\n" & _
     "    O21 - ShellServiceObjectDelayLoad (SSODL) autorun Registry key" & "\n" & _
     "    O22 - SharedTaskScheduler autorun Registry key" & "\n" & _
     "    O23 - Enumeration of Windows Services" & "\n" & _
     "    O24 - Enumeration of ActiveX Desktop Components" & "\n" & _
     "    O25 - WMI Event consumers" & "\n" & "\n"
     
    Help = Help & _
     "Command-line parameters:" & "\n" & _
     "* /autolog - automatically scan the system, save a logfile and open it" & "\n" & _
     "* /ihatewhitelists - ignore all internal whitelists" & "\n" & _
     "* /uninstall - remove all HiJackThis Registry entries, backups and quit" & "\n" & _
     "* /silentautolog - the same as /autolog, except with no required user intervention" & "\n" & _
     "* /startupscan - automatically scan the system (the same as button ""Do a system scan only"")" & "\n" & _
     "* /deleteonreboot ""c:\file.sys"" - delete the file specified after system rebooting"
    
    s = s & "400=" & Help & vbCrLf
    
    '// "R0"
    s = s & "401=A Registry value that has been changed " & _
            "from the default, resulting in a changed " & _
            "IE Search Page, Start Page, Search Bar Page " & _
            "or Search Assistant. \n\n" & _
            "(Action taken: Registry value is restored to preset URL.)" & vbCrLf
    '// "R1"
    s = s & "402=A Registry value that has been created " & _
            "and is not present in a default Windows " & _
            "install nor needed, possibly resulting in a " & _
            "changed IE Search Page, Start Page, Search Bar " & _
            "Page or Search Assistant.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "R2"
    s = s & "403=A Registry key that has been created " & _
            "and is not present in a default Windows " & _
            "install nor needed, possibly resulting in a " & _
            "changed IE Search Page, Start Page, Search Bar " & _
            "Page or Search Assistant.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
    '// "R3"
    s = s & "404=A Registry value that has been created " & _
            "in a key where only one value should be. Only " & _
            "is used for the URLSearchHooks regkey.\n\n" & _
            "(Action taken: Registry value is deleted, default URLSearchHook " & _
            "value is restored.)" & vbCrLf
    '// "F0"
    s = s & "405=An inifile value that has been changed " & _
            "from the default value, possibly resulting in " & _
            "program(s) loading at Windows startup. Often " & _
            "used to autostart a program that is even " & _
            "harder to disable.\n\n" & _
            "Default: Shell=explorer.exe \n" & _
            "Infected example: Shell=explorer.exe,openme.exe \n\n" & _
            "(Action taken: Default inifile value is restored.)" & vbCrLf
    '// "F1"
    s = s & "406=An inifile value that has been created " & _
            "and is not present in a default Windows " & _
            "install nor needed, possibly resulting in " & _
            "program(s) loading at Windows startup. Often " & _
            "used to autostart program(s) that are hard " & _
            "to disable. \n\n" & _
            "Default: run= OR load= \n" & _
            "Infected example: run=dialer.exe \n\n" & _
            "(Action taken: Inifile value is deleted.)" & vbCrLf
    '// "N1"
    s = s & "407=Netscape 4.x stores the browsers homepage " & _
            "the prefs.js file located in the user's Netscape " & _
            "directory. LOP.com has been known to change this " & _
            "value. \n\n" & _
            "(Action taken: Setting is restored to preset URL.)" & vbCrLf
    '// "N2", "N3", "N4"
    s = s & "408=%SHITBROWSER% stores the browser's homepage in " & _
            "prefs.js file located deep in the 'Application Data' " & _
            "folder. The default search engine is also stored " & _
            "in this file. LOP.com has been known to change the " & _
            "homepage URL. \n\n" & _
            "(Action taken: Setting is restored to preset URL.)" & vbCrLf
    '// "O1"
    s = s & "409=A change in the 'Hosts' system file " & _
            "Windows uses to lookup domain names before " & _
            "quering internet DNS servers, effectively " & _
            "making Windows believe that 'auto.search.msn" & _
            ".com' has a different IP than it really has " & _
            "and thus making IE open the wrong page when" & _
            "ever you enter an invalid domain name in the " & _
            "IE Address Bar. \n\n" & _
            "Infected example: 213.67.109.7" & vbTab & "auto.search.msn.com \n\n" & _
            "(Action taken: Line is deleted from hosts file.)" & vbCrLf
    '// "O2"
    s = s & "410=A BHO (Browser Helper Object) is a specially " & _
            "crafted program that integrates into IE, and " & _
            "has virtually unlimited access rights on your " & _
            "system. Though BHO's can be helpful (like the " & _
            "Google Toolbar), hijackers often use them for " & _
            "malicious purposes such as tracking your " & _
            "online behaviour, displaying popup ads etc. \n\n" & _
            "(Action taken: Registry key and CLSID key are deleted, BHO dll file is deleted.)" & vbCrLf
    '// "O3"
    s = s & "411=IE Toolbars are part of BHO's (Browser Helper " & _
            "Objects) like the Google Toolbar that are " & _
            "helpful, but can also be annoying and malicious " & _
            "by tracking your behaviour and displaying " & _
            "popup ads. \n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O4"
    s = s & "412=This part of the scan checks for several " & _
            "suspicious entries that autoload when Windows " & _
            "starts. Autoloading entries can load " & _
            "a Registry script, VB script or JavaScript" & _
            "file, possibly causing the IE Start Page, " & _
            "Search Page, Search Bar and Search Assistant " & _
            "to revert back to a hijacker's page after a " & _
            "system reboot. Also, a DLL file can be loaded " & _
            "that can hook into several parts of your system. \n\n" & _
            "Infected examples: \n\n" & _
            "regedit c:\windows\system\sp.tmp /s \n" & _
            "KERNEL32.VBS \n" & _
            "c:\windows\temp\install.js \n" & _
            "rundll32 C:\Program Files\NewDotNet\newdotnet4_5.dll,NewDotNetStartup \n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O5"
    s = s & "413=Modifying CONTROL.INI can cause Windows " & _
            "to hide certain icons in the Control Panel. " & _
            "Though originally meant to speed up loading of " & _
            "Control Panel and reducing clutter, it can be " & _
            "used by a hijacker to prevent access to the " & _
            "'Internet Options' window. \n\n" & _
            "Infected example: \n[don't load]\n" & _
            "inetcpl.cpl=yes OR inetcpl.cpl=no \n\n" & _
            "(Action taken: Line is deleted from Control.ini file.)" & vbCrLf
    '// "O6"
    s = s & "414=Disabling of the 'Internet Options' menu " & _
            "menu entry in the 'Tools' menu of IE is done " & _
            "by using Windows Policies. Normally used by " & _
            "administrators to restrict their users, it can " & _
            "be used by hijackers to prevent access to the " & _
            "'Internet Options' window.\n\n" & _
            "StartPage Guard also uses Policies to restrict " & _
            "homepage changes, done by hijackers.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O7"
    s = s & "415=Disabling of Regedit is done by using " & _
            "Windows Policies. Normally used by administrators " & _
            "to restrict their users, it can be used by " & _
            "hijackers to prevent access to the Registry editor." & _
            " This results in a message saying that your " & _
            "administrator has not given you privilege to use " & _
            "Regedit when running it.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O8"
    s = s & "416=Extra items in the context (right-click) menu " & _
            "can prove helpful or annoying. Some recent hijackers " & _
            "add an item to the context menu. The MSIE PowerTweaks " & _
            "Web Accessory adds several useful items, among which " & _
            """Highlight"", ""Zoom In/Out"", ""Links list"", """ & _
            "Images list"" and ""Web Search"".\n\n" & _
            "(Action taken: Registry key is deleted.)" & vbCrLf
            
    '// "O9"
    s = s & "417=Extra items in the MSIE 'Tools' menu and extra " & _
            "buttons in the main toolbar are usally present as " & _
            "branding (Dell Home button) or after system updates " & _
            "(MSN Messenger button) and rarely by hijackers. The " & _
            "MSIE PowerTweaks Web Accessory adds two menu items, " & _
            "being ""Add site to Trusted Zone"" and ""Add site to " & _
            "Restricted Zone"".\n\n" & _
            "(Action taken: Registry key is deleted.)" & vbCrLf
            
    '// "O10"
    s = s & "418=The Windows Socket system (Winsock) uses a list of " & _
            "providers for resolving DNS names (i.e. translating www." & _
            "microsoft.com into an IP address). This is called the Layered " & _
            "Service Provider (LSP). A few programs are capable of " & _
            "injecting their own (spyware) providers in the LSP. If files " & _
            "referenced by the LSP are " & _
            "missing or the 'chain' of providers is broken, none of the " & _
            "programs on your system can access the Internet. Removing " & _
            "references to missing files and repairing the chain will " & _
            "restore your Internet access.\nSo far, only a few " & _
            "programs use a Winsock hook.\n\n" & _
            "Note: This is a risky procedure. If it should fail, " & _
            "get LSPFix from http://www.cexx.org/lspfix.htm to repair the " & _
            "Winsock stack.\n\n" & _
            "(Action taken: none. Use LSPFix to modify the Winsock stack.)" & vbCrLf
            
    '// "O11" 'MSIE options group
    s = s & "419=The options in the 'Advanced' tab of MSIE options " & _
            "are stored in the Registry, and extra options can be " & _
            "added easily by creating extra Registry keys. Very " & _
            "rarely, spyware/hijackers add their own options there " & _
            "which are hard to remove. E.g. CommonName adds a section " & _
            "'CommonName' with a few options.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
            
    '// "O12" 'MSIE plugins
    s = s & "420=Plugins handle filetypes that aren't supported " & _
            "natively by MSIE. Common plugins handle Macromedia " & _
            "Flash, Acrobat PDF documents and Windows Media formats, " & _
            "enabling the browser to open these itself instead of " & _
            "launching a separate program. When hijackers or spyware " & _
            "add plugins for their filetypes, the danger exists that " & _
            "they get reinstalled if everything except the plugin has " & _
            "been removed, and the browser opens such a file.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
        
    '// "O13" 'DefaultPrefix
    s = s & "421=When you type an URL into MSIE's Address bar without " & _
            "the prefix (http://), it is automatically added when you " & _
            "hit Enter. This prefix is stored in the Registry, together " & _
            "with the default prefixes for FTP, Gopher and a few other " & _
            "protocols. When a hijacker changes these to the URL of his " & _
            "server, you always get redirected there when you forget to " & _
            "type the prefix. Prolivation uses this hijack.\n\n" & _
            "(Action taken: Registry value is restored to default data.)" & vbCrLf
            
    '// "O14" 'IERESET.INF
    s = s & "422=When you hit 'Reset Web Settings' on the 'Programs' tab " & _
            "of the MSIE Options dialog, your homepage, search page and a " & _
            "few other sites get reset to their defaults. These defaults are " & _
            "stored in C:\Windows\Inf\Iereset.inf. When a hijacker changes these " & _
            "to his own URLs, you get (re)infected rather than cured when you " & _
            "click 'Reset Web Settings'. SearchALot uses this hijack.\n\n" & _
            "(Action taken: Value in Inf file is restore to default data.)" & vbCrLf
        
    '// "O15" 'Trusted Zone Autoadd
    s = s & "423=Websites in the Trusted Zone (see Internet Options," & _
            "Security, Trusted Zone, Sites) are allowed to use normally " & _
            "dangerous scripts and ActiveX objects normal sites aren't " & _
            "allowed to use. Some programs will " & _
            "automatically add a site to the Trusted Zone without you " & _
            "knowing. Only a very few legitimate programs are known to do this " & _
            "(Netscape 6 is one of them) and a lot of browser hijackers" & _
            "add sites with ActiveX content to them.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
            
    '// "O16" 'Downloaded Program Files
    s = s & "424=The Download Program Files (DPF) folder in your " & _
            "Windows base folder holds various types of programs " & _
            "that were downloaded from the Internet. These programs " & _
            "are loaded whenever Internet Explorer is active." & _
            "Legitimate examples are the Java VM, Microsoft XML " & _
            "Parser and the Google Toolbar.\n" & _
            "Unfortunately, due to the lack security of IE, malicious " & _
            "sites let IE automatically download porn dialers, " & _
            "bogus plugins, ActiveX Objects etc to this folder, " & _
            "which haunt you with popups, huge phone bills, random " & _
            "crashes, browser hijackings and whatnot." & vbCrLf
        
    '// "O17" 'Domain hijack
    s = s & "425=Windows uses several registry values as a help " & _
            "to resolve domain names into IP addresses. Hijacking " & _
            "these values can cause all programs that use the Internet " & _
            "to be redirected to other pages for seemingly unknown " & _
            "reasons.\n" & _
            "New versions of Lop.com use this method, together with a " & _
            "(huge) list of cryptic domains.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
        
    '// "O18" 'Protocol & Filter
    s = s & "426=A protocol is a 'language' Windows uses to 'talk' " & _
            "to programs, servers or itself. Webservers use the " & _
            "'http:' protocol, FTP servers use the 'ftp:' protocol, " & _
            "Windows Explorer uses the 'file:' protocol. Introducing " & _
            "a new protocol to Windows or changing an existing one " & _
            "can burrow deep into how Windows handles files.\n" & _
            "CommonName and Lop.com both register a new protocol " & _
            "when installed (cn: and ayb:).\n\n" & _
            "The filters are content types accepted by Internet Explorer " & _
            "(and internally by Windows). If a filter exists for a content " & _
            "type, it passes through the file handling that content type " & _
            "first. Several variants of the CWS trojan add a text/html " & _
            "and text/plain filters, allowing them to hook all of the webpage " & _
            "content passed through Internet Explorer.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
            
    '// "O19" 'User stylesheet
    s = s & "427=IE has an option to use a user-defined stylesheet " & _
            "for all pages instead of the default one, to enable " & _
            "handicapped users to better view the pages.\n" & _
            "An especially vile hijacking method made by Datanotary " & _
            "has surfaced, which overwrites any stylesheet the user has " & _
            "setup and replaces it with one that causes popups, as well " & _
            "a system slowdown when typing or loading pages with many " & _
            "pictures.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
        
    '// "O20"  'AppInit_DLLs + WinLogon Notify subkeys
    s = s & "428=Files specified in the AppInit_DLLs Registry value " & _
            "are loaded very early in Windows startup and stay in memory " & _
            "until system shutdown. This way of loading a .dll is hardly " & _
            "ever used, except by trojans.\n" & _
            "The WinLogon Notify Registry subkeys load dll files into memory " & _
            "at about the same point in the boot process, keeping them " & _
            "loaded into memory until the session ends. Apart from several " & _
            "Windows system components, the programs VX2, ABetterInternet " & _
            "and Look2Me use this Registry key.\n" & _
            "Since both methods ensure the dll file stays loaded in " & _
            "memory the entire time, fixing this won't help if the dll " & _
            "puts back the Registry value or key immediately. In such cases, " & _
            "the use of the 'Delete file on reboot' function or KillBox is " & _
            "recommended to first delete the file.\n\n" & _
            "(Action taken for AppInit_DLLs: Registry value is cleared, but not deleted.)\n" & _
            "(Action taken for Winlogon Notify: Registry key is deleted." & vbCrLf
            
    '// "O21"  'ShellServiceObjectDelayLoad
    s = s & "429=This is an undocumented Registry key that contains a list " & _
            "of references to CLSIDs, which in turn reference .dll files " & _
            "that are then loaded by Explorer.exe at system startup. " & _
            "The .dll files stay in memory until Explorer.exe quits, which is " & _
            "achieved either by shutting down the system or killing the shell " & _
            "process.\n\n" & _
            "(Action taken: Registry value is deleted, CLSID key is deleted.)" & vbCrLf
            
    '// "O22"  'ScheduledTask
    s = s & "430=This is an undocumented Registry key that contains a list " & _
            "of CLSIDs, which in turn reference .dll files that are loaded " & _
            "by Explorer.exe at system startup. The .dll files stay in memory " & _
            "until Explorer.exe quits, which is achieved either by shutting " & _
            "down the system or killing the shell process.\n\n" & _
            "(Action taken: Registry value is deleted, CLSID key is deleted.)" & vbCrLf
            
    '// "O23" 'Windows Services
    s = s & "431=The 'Services' in Windows NT4, Windows 2000, Windows XP and " & _
            "Windows 2003 are a special type of programs that are essential to " & _
            "the system and are required for proper functioning of the system. " & _
            "Service processes are started before the user logs in and are " & _
            "protected by Windows. They can only be stopped " & _
            "from the services dialog in the Administrative Tools window.\n" & _
            "Malware that registers itself as a service is subsequently also harder " & _
            "to kill.\n\n" & _
            "(Action taken: services is disabled and stopped. Reboot needed.)" & vbCrLf
        
    '// "O24"
    s = s & "432=Desktop Components are ActiveX objects that can be made " & _
            "part of the desktop whenever Active Desktop is enabled (introduced " & _
            "in Windows 98), where it runs as a (small) website widget.\n" & _
            "Malware misuses this feature by setting the desktop " & _
            "background to a local HTML file with a large, bogus warning.\n\n" & _
            "(Action taken: ActiveX object is deleted from Registry.)" & vbCrLf
    
    '// "O25"
    s = s & "433=Windows Management Instrumentation is a default Windows service. " & _
            "It can be used to create permanent event consumer for both legitimate and malicious " & _
            "purposes. These events can collect hardware and software data " & _
            "to automate malware activities like spying. They can create a pipe to " & _
            "connect beetween machines, execute external script file or script code " & _
            "which is stored inside (fileless). Events can be triggered " & _
            "by WMI subsystem at intervals of time or manually when some application " & _
            "makes a special query to WMI.\n" & _
            "(Action taken by HiJackThis: WMI event consumer, filter, timer and binding are deleted with associated file as well.)" & vbCrLf
    
    '// frmMain
    s = s & "500=Please Wait" & vbCrLf & _
        "501=Please go to http://sourceforge.net/p/hjt/support-requests/" & vbCrLf & _
        "502=Unknown owner" & vbCrLf & _
        "503=file missing" & vbCrLf & _
        "504=The service you entered is system-critical! It can't be deleted." & vbCrLf & _
        "505=Short name" & vbCrLf & _
        "506=Full name" & vbCrLf & _
        "507=File" & vbCrLf & _
        "508=Owner" & vbCrLf & _
        "509=Enter file to delete on reboot..." & vbCrLf & _
        "510=All files" & vbCrLf & _
        "511=DLL libraries" & vbCrLf & _
        "512=Program files" & vbCrLf & _
        "513=No Internet Connection Available" & vbCrLf & _
        "514=Save Add/Remove Software list to disk..." & vbCrLf & _
        "515=Text files" & vbCrLf & _
        "516=is not implemented yet" & vbCrLf & _
        "517=items in results list" & vbCrLf & _
        "518=Save logfile..." & vbCrLf & _
        "519=Log files" & vbCrLf & _
        "520=End of file - xXxXx bytes" & vbCrLf & _
        "521=AnalyzeThis" & vbCrLf
    
    '// modBackup
    s = s & "530=Unable to create folder to place backups in. Backups of fixed items cannot be saved!" & vbCrLf & _
        "531=Not implemented yet, item '[]' will not be backed up!" & vbCrLf & _
        "532=bad coder - no donuts" & vbCrLf & _
        "533=I'm so stupid I forgot to implement this. Bug me about it." & vbCrLf & _
        "534=d'oh!" & vbCrLf & _
        "535=The backup files for this item were not found. It could not be restored." & vbCrLf & _
        "536=The backup file for this item was not found. It could not be restored." & vbCrLf & _
        "537=Could not find prefs.js file for Netscape/Mozilla, homepage has not been restored." & vbCrLf & _
        "538=BHO file for '[]' was not found. The Registry data was restored, but the file was not." & vbCrLf & _
        "539=Unable to restore this backup: too many items in your Trusted Zone!" & vbCrLf & _
        "540=Unable to restore item: Protocol '[]' was set to unknown zone." & vbCrLf
        
    '// modHosts
    s = s & "550=Loading hosts file, please wait..." & vbCrLf & _
        "551=Cannot find the hosts file. \n" & "Do you want to create a new, default hosts file?" & vbCrLf & _
        "552=No hosts file found." & vbCrLf & _
        "553=The hosts file is locked for reading and cannot be edited. \n" & "Make sure you have privileges to modify the hosts file and " & _
            "no program is protecting it against changes." & vbCrLf
    
    '// modInternet
    s = s & "560=No Internet Connection Available" & vbCrLf
    
    '// modTranslation
    s = s & "570=The language file '[]' is invalid (ambiguous id numbers)." & vbCrLf & _
        "571=Load file for language '[]'" & vbCrLf & _
        "572=Invalid language File. Reset to default (English)?" & vbCrLf
    
    '// modLSP
    s = s & "580=HijackThis cannot repair O10 Winsock LSP entries. \n" & _
            "from https://www.foolishit.com/vb6-projects/winsockreset/\n\n" & _
            "Would you like to visit that site?" & vbCrLf
    
    '// modmain
    s = s & "590=Please help us improve HiJackThis by reporting this error.\n\n" & _
        "Error message has been copied to clipboard.\n" & _
        "Click 'Yes' to submit.\n\n" & _
        "Error Details: \n\n" & _
        "An unexpected error has occurred at function: " & vbCrLf & _
        "591=Error" & vbCrLf
    

    sLines = Split(s, vbCrLf)
End Sub

Public Sub LangRU()
    Dim s$

    s = _
    "// ������� �����" & vbCrLf & _
    "001=����� ���������� � HiJackThis. ��� ��������� �������� �������� � ������� ����� � ������������� ��������� (������, ���������� ������� � �.�.) � �������� �������� �������� ������������ �������, ������� ������������ ��� ������������, ��� � ����������� �����������." & vbCrLf & _
    "002=HijackThis ��� �������." & vbCrLf & _
    "003=��������������!\n\n��������� ����� HiJackThis �������� ������������ ������� ������������� ������������ �� � ������ ��������� ������ ������ ���������� ����� Hijacker, ���������� ������������ ����� ��������� ���������� ������, �� Hijacker. ������ ���������, ����� ���-�� ��������. � ��������� ��������� �������� ����� ���������� ���������. ����� ����� ���������� �� ������� � ��������� � �������� �� ���� �����. ��� ������ ������������, ��� ������ ����� ����������. ��� �������� ���������� ��, ��������� ���������� ���������, ���������� � ������ � ���, ����� ��������� ���������������." & vbCrLf & _
    "004=���� �������� ���������� ������������ HiJackThis. ������ ��������� � ���, ��� �� �������� ������� '���������'. � ����������� ������������ ��� ������ ������������� �������. ����� �������� ����� ������������, ����� ������ 'Analyze This'." & vbCrLf & _
    "// �������� �����" & vbCrLf & _
    "009=������� ����" & vbCrLf & _
    "010=�������� � �������" & vbCrLf & _
    "011=���������" & vbCrLf & _
    "012=��������� �����" & vbCrLf & _
    "013=���������" & vbCrLf & _
    "014=���������� � ��������� ������..." & vbCrLf & _
    "015=������ �����������" & vbCrLf & _
    "016=��������" & vbCrLf & _
    "017=�����" & vbCrLf & _
    "018=���������" & vbCrLf & _
    "019=�����" & vbCrLf & _
    "020=�������� ���������� � �����-����" & vbCrLf & _
    "021=������ �� �������! ����������?" & vbCrLf & _
    "022=�� ������� ��� ����������� ���, ��� ���� ������� ���������� HiJackThis. � ������ ����� ���������� ������ ��������� �������, �������� ������� �������� � ��������� ���������������� �������.\n\n���� �� �� ������, ��� ������������ ���������� HiJackThis, ��� ������� ���������� �� ������� ������ ��� ����������� ������������ ��������. � ���� ���� ��������� ������, �� ������� ��� � ������������� ������� � �������.\n\n�� �������, ��� ������ ��������� ��� ��������, ��������� � ���� ������������?" & vbCrLf
    s = s & "023=��������� ��������� �������� - [] ��.?\n��� ������������ ������ ��� �������� ��, ��� �� �������" & vbCrLf & _
    "024=���� �� ����� �������� ��������� �����������." & vbCrLf & _
    "025=HiJackThis ����� ������������ ���������� ��������, ���� ��� �� ����� ����������. ����������?" & vbCrLf & _
    "026=��� ������� �� ������ � ��������� �����. ����������, ���������� ������ ������������." & vbCrLf & _
    "027=���� ������ �������� � [].\n�� ������ ������� ��� � ��������� ���������, �������� Notepad." & vbCrLf & _
    "028=�� ������� ����������� ���������� ��������" & vbCrLf & _
    "029=���������� ��������" & vbCrLf & _
    "// ������ �������" & vbCrLf & _
    "030=������" & vbCrLf & _
    "// ������� ���������" & vbCrLf & _
    "040=���������" & vbCrLf & _
    "041=�������" & vbCrLf & _
    "042=�����-����" & vbCrLf & _
    "043=��������� �����" & vbCrLf & _
    "044=�����������" & vbCrLf & _
    "// ������� '�������'" & vbCrLf & _
    "050=����� �������� ��� ����������� ��� ��������� � ���� ��������" & vbCrLf & _
    "051=������ ��������� ����� ����� ������������" & vbCrLf & _
    "052=������������ ����������� � �������� � ������ ������������� (���������� �����)" & vbCrLf & _
    "053=������������ �������������, �� ���������� ������ � IE (��������, msn.com, microsoft.com)" & vbCrLf
    s = s & "054=�������� � ������ ������ ���������� ���������" & vbCrLf & _
    "055=�� ���������� ������� ���� ��� �������" & vbCrLf & _
    "056=�������� HiJackThis � ����������\n(�������� ������� � ����� ������ � ����� ���������� ������, ���� ���-������ ����� �������)" & vbCrLf & _
    "057=�� �������, ��� ������ �������� ��� �����? \nHiJackThis �� �������� ���������� � ����� '������ � ���������'. ��������� �� ������� *� ��������* �� ������������ �������, ������������ ����������� ������ Hijacker, ����� ����������� ������ ������������.\n������������� ������ ����� ����� �������� � ���������� ����������� �������� � ���������. ������, ������������, ��� �� ��������� ������� ���������, ����� �� ������ ���� ������������. ����� �������, ��� ����� �������� ��� ����� ������, ���� �� ������������� ������, ��� �������!" & vbCrLf & _
    "058=�� ���������� ��������� �� �������" & vbCrLf & _
    "060=��������� ������ URL ����� �������������� ��� ����������� ����������� ������� MSIE:" & vbCrLf & _
    "061=��������� ��������:" & vbCrLf & _
    "062=�������� ������:" & vbCrLf & _
    "063=Default Search Assistant:" & vbCrLf & _
    "064=Default Search Customize:" & vbCrLf & _
    "// ������� '�����-����'" & vbCrLf & _
    "070=��������� �������� ����� �������������� �� ����� ������������:" & vbCrLf & _
    "071=�������" & vbCrLf & _
    "072=������� ���" & vbCrLf & _
    "// ������� '��������� �����'" & vbCrLf & _
    "080=��� ������ ��������� �����, ������� ���� ���������. �� ������ ������������ �� ��� �������. �������������� �������� � ����, ��� HiJackThis ����� ����� �� ������������, ���� ������ �� �� ��������� �� � ������ �������������). ������������ ��������� ����� ���������� ��� ��������� �����!" & vbCrLf & _
    "081=��������- ����" & vbCrLf & _
    "082=�������" & vbCrLf & _
    "083=������� ��" & vbCrLf & _
    "084=�� �������, ��� ������ ������� ��� ��������� �����?" & vbCrLf & _
    "085=�� �������, ��� ������ ������� ��� ��������� ����� ([] ��.) ?" & vbCrLf
    s = s & "086=������������ ���� ������?" & vbCrLf & _
    "087=������������ ��� ������� ([] ��.) ?" & vbCrLf & _
    "088=�� �������, ��� ������ ������� ��� ��������� �����?" & vbCrLf & _
    "// ������� '������ �����������'" & vbCrLf & _
    "090=������ ����������� (StartupList v.[])" & vbCrLf & _
    "091=������� ����� StartupList" & vbCrLf & _
    "092=�������� ������������ ������ (full)" & vbCrLf & _
    "093=�������� ������ ������ (complete)" & vbCrLf & _
    "100=��������� �����������" & vbCrLf & _
    "101=��������� ���������" & vbCrLf & _
    "102=���������, �������� ���������� ����� Windows." & vbCrLf & _
    "103=�������� ����� Hosts" & vbCrLf & _
    "104=������� �������� ����� 'hosts'." & vbCrLf & _
    "105=������� ���� ��� ������������..." & vbCrLf & _
    "106=���� ���� �� ���������, Windows ����� ��������� ���, ����� ������� ���� ����� ������������." & vbCrLf & _
    "107=������� ������ Windows..." & vbCrLf & _
    "108=������� ������ Windows (O23).\n������������ � �������������!" & vbCrLf & _
    "109=������� ADS Spy..." & vbCrLf & _
    "110=����� ������� �������� �������." & vbCrLf & _
    "112=���������� ���������� � ������ \n""�������� ��������""." & vbCrLf
    s = s & "113=������� ������ ��� ������, ��� ��� ������������ � ����������� ��������, ��� ����������� �������� � �������, ���� ��� �������.\n������ ������ ���� ����������� � ���������.\n��������������! ����� �������� ������ � ������ ����� ������������!" & vbCrLf & _
    "114=������� ������ Windows" & vbCrLf & _
    "115=������ '[]' �� ������� � �������.\n���������, ��� �� ��������� ����� ��� ������." & vbCrLf & _
    "116=������ '[]' �������� �/��� ��������. ������� ��������� � ���� � ������� HiJackThis (�� ���� ����������� ��������), ���� �� ���� Services.msc." & vbCrLf & _
    "117=��������� ������ ���� �������:" & vbCrLf & _
    "118=�� ����� �������, ��� ������ ������� ��� ������?" & vbCrLf & _
    "120=�������������� ��������� (��� �� ����� ���������)" & vbCrLf & _
    "121=��������� MD5 ������, ���� ��� ��������" & vbCrLf & _
    "122=�������� � ����� ���������� �����" & vbCrLf & _
    "140=�������� ���������� ����� ��������" & vbCrLf & _
    "141=��������� ����������" & vbCrLf & _
    "142=" & vbCrLf & _
    "143=������������ ������-������ (host:port) :" & vbCrLf & _
    "150=������������� HiJackThis" & vbCrLf & _
    "151=������� HiJackThis � �����" & vbCrLf & _
    "152=������� ��� ����� ������� � �����." & vbCrLf
    s = s & "153=������� �� ������� ���������� � HiJackThis � ��������� ������ ���������. �������� ��������: ��� �������� ������� ���� HiJackThis.exe �������.\n\n���������� ��������?" & vbCrLf & _
    "// ������� ����" & vbCrLf & _
    "160=������� ����" & vbCrLf & _
    "161=��� �� �� ������ �������?" & vbCrLf & _
    "162=��������� ������� � ��������� �����" & vbCrLf & _
    "163=������ ��������� �������" & vbCrLf & _
    "164=��������� �����" & vbCrLf & _
    "165=�����������" & vbCrLf & _
    "166=������ �����������" & vbCrLf & _
    "167=" & vbCrLf & _
    "168=������ �� �����, ������ ������" & vbCrLf & _
    "169=������ �� ���������� ��� ���� ��� ������� HiJackThis" & vbCrLf & _
    "183=�������� ����:" & vbCrLf & _
    "// �������� ���������" & vbCrLf & _
    "170=�������� ���������" & vbCrLf & _
    "171=���������� ��������:" & vbCrLf & _
    "172=�������� ������" & vbCrLf & _
    "173=��������� �������" & vbCrLf & _
    "174=��������" & vbCrLf & _
    "175=���������..." & vbCrLf & _
    "176=�����" & vbCrLf
    s = s & "177=�������� ������� ���� �� ����� ��� ��������� ��� �������" & vbCrLf & _
    "178=����������� ������ ���������� ��������:" & vbCrLf & _
    "179=�� �������, ��� ������ ��������� ������� []?" & vbCrLf & _
    "180=��� ������������� ������ �������� ����� ��������." & vbCrLf & _
    "181=���������" & vbCrLf & _
    "182=������� ��� ���������, �����, ��������� ��� ��������-�������, � Windows ������� ��� ��� ���." & vbCrLf & _
    "184=��� ����� ������ ������� �������, ������� �� ������ ���������!" & vbCrLf & _
    "// ADS Spy" & vbCrLf & _
    "190=������������ �������������� �������� �������" & vbCrLf & _
    "191=������� �������� (������ ����� Windows)" & vbCrLf & _
    "192=������������ ���������� ��������� ������" & vbCrLf & _
    "193=��������� ����������� ����� MD5 �������" & vbCrLf & _
    "194=��� ���?" & vbCrLf
    s = s & "195=�������" & vbCrLf & _
    "196=���������" & vbCrLf & _
    "197=��������� �����..." & vbCrLf & _
    "198=������� ���������" & vbCrLf & _
    "199=�����" & vbCrLf & _
    "200=�����." & vbCrLf & _
    "201=������������ ADS Spy �������� ������: ����� ���� ������� '���������', ��������� ���� ���� ��������, ����� �������� ������, " & _
    "������� �� ������ ������� � ������� '������� ���������'. ���� �� �� �������, ����� ������ �������, ���������� �� ������� � �����������. " & _
    "�� �������� ������, ���� �� �� ������ �� ����������!\n\n�������� �������:\n\n������� ��������: ��������� ������ ����� Windows. " & _
    "�� ��� ��� ��� ��������� ��������, ������������ �������� ������ ��� ������ ��������, ����������� � ����� Windows. " & _
    "������ ����� ������ �������� � �������� ���� ������� (�.�. ���� ������).!\n\n������������ ���������� ��������� ������: " & _
    "Windows, Internet Explorer � ��������� ������������ �������� ���������� ADS ��� �������� ���������� � ������������ ������ � ������. " & _
    "��� ������ ����� ���������������. ��� �� ����� ���������.!\n\n��������� ����������� ����� MD5 �������: ������������� � �������� ��� ������������� " & _
    "� �������� ����������.\n\n����������: �������� ��-��������� ���� ���� ������� ������ ���������� ��� ����������� �������������. " & _
    "��� ������������� �������� ��, ���� ������ �� �� ����������� ��� ������������ �������." & vbCrLf
    s = s & "202=������" & vbCrLf & _
    "203=�������� ��������!" & vbCrLf & _
    "204=�������� ���������." & vbCrLf & _
    "205=�������������� ������ ������ (ADSs) - ��� ��������� ����������, ������� � ���� ���������� ������. ��� �� ����� � ���������� � Windows �� ���������� ����� �� �����, ������� ��� ��������. ��������� ����������� �� ������ hijacker ������ �������� ���� ����� ������ �������, � ���� �������� ������������ ������� ������������ �� (���� ���).\n����������� ADS Spy, ����� ����� � ������� ��� ������.\n����������: ��� ���������� ����� ���������� ���������� ������. �� �������� ������, ���� �� �� ��������� ������� � �� �������������!" & vbCrLf & _
    "// �������� �������� ��������" & vbCrLf & _
    "209=������� ����������" & vbCrLf & _
    "210=�������� �������� ��������" & vbCrLf & _
    "211=����� �� ������ ������� ������ �������� ������� '�������� ���������' ������ ����������.\n�� ������ ��������������� ������� ��������, ������� ������ ������ �� ������ ���� ��������� ������� ���������. ������ ���������: ��������� ������ ��� ��������� ������ ������������!" & vbCrLf & _
    "212=��������:" & vbCrLf & _
    "213=������� ��������:" & vbCrLf & _
    "214=������� ��� ������" & vbCrLf & _
    "215=�������� ������� ��������" & vbCrLf & _
    "216=������� ������ �������������� ��" & vbCrLf & _
    "217=�������� ������" & vbCrLf
    s = s & "218=��������� ������..." & vbCrLf & _
    "219=�����" & vbCrLf & _
    "220=�� �������, ��� ������ ������� ���� ������� �� ������?" & vbCrLf & _
    "221=������� ����� ������� �������� ���� ���������" & vbCrLf & _
    "222=����� ������ �������� ���������!" & vbCrLf & _
    "223=�� �������, ��� ������� ������� " & vbCrLf & _
    "224=�������� �������� ��������" & vbCrLf & _
    "// ������ �� ����� ������������" & vbCrLf & _
    "230=�������� ������� IE" & vbCrLf & _
    "231=�������� ����� INI" & vbCrLf & _
    "232=�������� �������� Mozilla" & vbCrLf & _
    "233=O1 - ��������������� ����� ���� Hosts" & vbCrLf
    s = s & "234=O2 - ������������ BHO" & vbCrLf & _
    "235=O3 - ������������ ������� ������������" & vbCrLf & _
    "236=O4 - ������ � ���������� �� ���� ����" & vbCrLf & _
    "237=O5 - ������ ����������: ��������� IE" & vbCrLf & _
    "238=O6 - ��������: ��������� ��������� ���� IE" & vbCrLf & _
    "239=O7 - ��������: �������� �������" & vbCrLf & _
    "240=O8 - ������������ ��������� ������������ ���� IE" & vbCrLf
    s = s & "241=O9 - ������������ ��������� ���� ""�����������"" � ������ IE" & vbCrLf & _
    "242=O10 - ��������� � Winsock LSP" & vbCrLf & _
    "243=O11 - ������ �������� � �������������� ���������� IE" & vbCrLf
    s = s & "244=O12 - ������������ �������� IE" & vbCrLf & _
    "245=O13 - ��������� � �������� ��-���������" & vbCrLf & _
    "246=O14 - ��������� � IERESET.INF" & vbCrLf & _
    "247=O15 - ������������ ��������� ��� " & vbCrLf & _
    "248=O16 - ������������ �������� DPF" & vbCrLf & _
    "249=O17 - ��������� DNS � DNS-��������" & vbCrLf & _
    "250=O18 - ������������ ���������� � ��������" & vbCrLf & _
    "251=O19 - ��������� � User stylesheet" & vbCrLf & _
    "252=O20 - �������� ��������� ������� AppInit_DLLs" & vbCrLf & _
    "253=O21 - ���� ������� ������ ������� ���������� �������� (SSODL)" & vbCrLf & _
    "254=O22 - ���� ������� ������ ������������ ������� (SharedTaskScheduler)" & vbCrLf & _
    "255=O23 - �������� �����" & vbCrLf & _
    "256=���������!" & vbCrLf
    s = s & _
    "257=O24 - ���������� �������� ����� ActiveX" & vbCrLf & _
    "258=O25 - ����������� ������� WMI" & vbCrLf & _
    "259=�������� ��������� �����" & vbCrLf & _
    "// �������� ����� hosts" & vbCrLf & _
    "270=�������� ����� hosts" & vbCrLf & _
    "271=���� hosts ��������� �� ������" & vbCrLf & _
    "272=������� ������(�)" & vbCrLf & _
    "273=���������������� ������(�)" & vbCrLf & _
    "274=������� � ���������" & vbCrLf & _
    "275=�����" & vbCrLf & _
    "276=����������: ���������, ��������� � ���� hosts, ������� � ���� ����� ����������� ��������." & vbCrLf & _
    "277=��������:" & vbCrLf & _
    "278=�����:" & vbCrLf & _
    "// ��������� � ������ � ������� ������������" & vbCrLf
    s = s & "300=�� �����-�� ������� ���� ������� ��������� ������ �� ������ � ���� hosts. ���� �����-���� ����������� ������ ��������� � ���� �����, HijackThis �� ������ �� �������.\n\n���� ��� ���������, ��� ����� ��������������� ���� ��������������. ��� ����� ������� ������ '����', '���������' � �������:\n\notepad []\n\n� ������� ������� Enter. ������� ������(�), ��������������� ������ HijackThis � ������� ��. ��������� ���� ��� ""hosts"" (� ��������), � �������������.\n\n��� Vista � ����: ������ �������� HijackThis, �������� ������ ������� ���� �� ������ HijackThis � �������� ""������ �� ����� ��������������""." & vbCrLf & _
    "301=��� ���� hosts ����� ������������ �������� ����� � HijackThis �� ����� ��� ���������. �������� O1 �� ����� ������������.\n\n������� ""OK"" ��� ����������� ��������." & vbCrLf & _
    "302=� ��� ������� ������� ���������� �������. ��������, ����� ����� ������� ��� ����, ��� ���������� ������ ������� (� ������� ��������� �����).\n\n���� �� ������ ����� �� IP ����� �� ���� ��������� O1, ������� ���� Hosts, ������� ���������� �� ������ [].\n\n������� ����� � ������ Hosts ������?" & vbCrLf & _
    "303=HijackThis �� ������� �������� ��������� ��������� � ��� ���� hosts. ��������� �������� �������� ��, ��� �����-�� ��������� ��������� ������ � ���� ��� ���� ������� ������ �� ����� ����� ��� ������ � ����." & vbCrLf & _
    "310=HijackThis ���������� ������� BHO � ��������������� ���� �� ����� �������. �������� ��� ���� ��������� � ���������� Windows ����� ������������." & vbCrLf & _
    "320=�� ������� ������� ����:\n[]\n\n���� ���� ������������." & vbCrLf
    s = s & "321=����������� ��������� ����� ��� ���������� ���������" & vbCrLf & _
    "322=����������� ������ ���������, ��� �������� ProcView, ����� ��������� ������ ���������" & vbCrLf & _
    "323=� ��������� HijackThis �����, ����� ������� ����." & vbCrLf & _
    "330=HijackThis ���������� ������� ������ �� ����� �������. �������� ��� ���� Internet Explorer-� ������, ��� ����������, ��� ������� �������� �������� ��������." & vbCrLf & _
    "340=������, ��� �� ��������� HijackThis � ����������, ����������� �� ������, ������ ��� CD-ROM ��� ��������������� �������. ���� ��� ��������� ������� ��������� ����� ������������ ���������, �� ������ ������ ����������� HijackThis.exe �� ������� ���� � ��������� ��� ������.\n\n���� �� ����������, �� ������ �������� ������ ""������� � ������/������""." & vbCrLf & _
    "341=������ �� ������ �������� !\n\n����������� �� ������� ���� ��� ��� ?" & vbCrLf & _
    "342=���� '[]' ����� ������ Windows ��� ������������ �������." & vbCrLf & _
    "343=������ '[]' ���� �������� ��� ��������." & vbCrLf & _
    "344=�� ������� ������� ������ '[]'. ���������, ��� ��� ������� ��������� � ��� ������ �� ��������." & vbCrLf

    'Hijack ��-�������� ��� ������� �� ��������� �����. ��������� ����� temp ������������ ���������, ������������� ������� ����������� HijackThis.exe � ����������� �����, �������� C:\Program Files\HijackThis.\n����� �������, ��� ��������� �����, ������� ����� ������� ��� ������������ ���������, �� ����� �������.\n\n����������, �������� HijackThis � ���������� ��� � ��������� ����� ������, ��� ���������� ����� ��������." & vbCrLf & _

    Dim Help$
    '// Help info
    
    '"* Trend Micro HiJackThis v" & App.Major & "." & App.Minor & "." & App.Revision & " *" & "\n" & _

    Help = "\n" & _
     AppVer & _
     "\n" & "\n" & "See bottom for version history." & "\n" & "\n"

    Help = Help & "The different sections of hijacking " & _
     "possibilities have been separated into the following groups." & "\n" & _
     "You can get more detailed information about an item " & _
     "by selecting it from the list of found items OR " & _
     "highlighting the relevant line below, and clicking " & _
     "'Info on selected item'." & "\n" & "\n" & _
     " R - Registry, StartPage/SearchPage changes" & "\n" & _
     "    R0 - Changed registry value" & "\n" & _
     "    R1 - Created registry value" & "\n" & _
     "    R2 - Created registry key" & "\n" & _
     "    R3 - Created extra registry value where only one should be" & "\n" & _
     " F - IniFiles, autoloading entries" & "\n" & _
     "    F0 - Changed inifile value" & "\n" & _
     "    F1 - Created inifile value" & "\n" & _
     "    F2 - Changed inifile value, mapped to Registry" & "\n" & _
     "    F3 - Created inifile value, mapped to Registry" & "\n"
     '" N - Netscape/Mozilla StartPage/SearchPage changes" & "\n" & _
     '"    N1 - Change in prefs.js of Netscape 4.x" & "\n" & _
     '"    N2 - Change in prefs.js of Netscape 6" & "\n" & _
     '"    N3 - Change in prefs.js of Netscape 7" & "\n" & _
     '"    N4 - Change in prefs.js of Mozilla" & "\n"
    Help = Help & _
     " O - Other, several sections which represent:" & "\n" & _
     "    O1 - Hijack of Hosts / hosts.ics file, DNSApi" & "\n" & _
     "    O2 - Enumeration of existing MSIE BHO's" & "\n" & _
     "    O3 - Enumeration of existing MSIE toolbars" & "\n" & _
     "    O4 - Enumeration of suspicious autoloading Registry entries / msconfig disabled items" & "\n" & _
     "    O5 - Blocking of loading Internet Options in Control Panel" & "\n" & _
     "    O6 - Disabling of 'Internet Options' Main tab with Policies" & "\n" & _
     "    O7 - Disabling of Regedit with Policies" & "\n" & _
     "    O8 - Extra MSIE context menu items" & "\n"
    Help = Help & _
     "    O9 - Extra 'Tools' menuitems and buttons" & "\n" & _
     "    O10 - Breaking of Internet access by New.Net or WebHancer" & "\n" & _
     "    O11 - Extra options in MSIE 'Advanced' settings tab" & "\n" & _
     "    O12 - MSIE plugins for file extensions or MIME types" & "\n" & _
     "    O13 - Hijack of default URL prefixes" & "\n" & _
     "    O14 - Changing of IERESET.INF" & "\n" & _
     "    O15 - Trusted Zone Autoadd" & "\n" & _
     "    O16 - Download Program Files item" & "\n" & _
     "    O17 - Domain hijack / DHCP DNS" & "\n" & _
     "    O18 - Enumeration of existing protocols and filters" & "\n" & _
     "    O19 - User stylesheet hijack" & "\n" & _
     "    O20 - AppInit_DLLs autorun Registry value, Winlogon Notify Registry keys" & "\n" & _
     "    O21 - ShellServiceObjectDelayLoad (SSODL) autorun Registry key" & "\n" & _
     "    O22 - SharedTaskScheduler autorun Registry key" & "\n" & _
     "    O23 - Enumeration of Windows Services" & "\n" & _
     "    O24 - Enumeration of ActiveX Desktop Components" & "\n" & _
     "    O25 - WMI Event consumers" & "\n" & "\n"
     
    Help = Help & _
     "Command-line parameters:" & "\n" & _
     "* /autolog - automatically scan the system, save a logfile and open it" & "\n" & _
     "* /ihatewhitelists - ignore all internal whitelists" & "\n" & _
     "* /uninstall - remove all HiJackThis Registry entries, backups and quit" & "\n" & _
     "* /silentautolog - the same as /autolog, except with no required user intervention" & "\n" & _
     "* /startupscan - automatically scan the system (the same as button ""Do a system scan only"")" & "\n" & _
     "* /deleteonreboot ""c:\file.sys"" - delete the file specified after system rebooting"
    
    s = s & "400=" & Help & vbCrLf
    
    '// "R0"
    s = s & "401=A Registry value that has been changed " & _
            "from the default, resulting in a changed " & _
            "IE Search Page, Start Page, Search Bar Page " & _
            "or Search Assistant. \n\n" & _
            "(Action taken: Registry value is restored to preset URL.)" & vbCrLf
    '// "R1"
    s = s & "402=A Registry value that has been created " & _
            "and is not present in a default Windows " & _
            "install nor needed, possibly resulting in a " & _
            "changed IE Search Page, Start Page, Search Bar " & _
            "Page or Search Assistant.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "R2"
    s = s & "403=A Registry key that has been created " & _
            "and is not present in a default Windows " & _
            "install nor needed, possibly resulting in a " & _
            "changed IE Search Page, Start Page, Search Bar " & _
            "Page or Search Assistant.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
    '// "R3"
    s = s & "404=A Registry value that has been created " & _
            "in a key where only one value should be. Only " & _
            "is used for the URLSearchHooks regkey.\n\n" & _
            "(Action taken: Registry value is deleted, default URLSearchHook " & _
            "value is restored.)" & vbCrLf
    '// "F0"
    s = s & "405=An inifile value that has been changed " & _
            "from the default value, possibly resulting in " & _
            "program(s) loading at Windows startup. Often " & _
            "used to autostart a program that is even " & _
            "harder to disable.\n\n" & _
            "Default: Shell=explorer.exe \n" & _
            "Infected example: Shell=explorer.exe,openme.exe \n\n" & _
            "(Action taken: Default inifile value is restored.)" & vbCrLf
    '// "F1"
    s = s & "406=An inifile value that has been created " & _
            "and is not present in a default Windows " & _
            "install nor needed, possibly resulting in " & _
            "program(s) loading at Windows startup. Often " & _
            "used to autostart program(s) that are hard " & _
            "to disable. \n\n" & _
            "Default: run= OR load= \n" & _
            "Infected example: run=dialer.exe \n\n" & _
            "(Action taken: Inifile value is deleted.)" & vbCrLf
    '// "N1"
    s = s & "407=Netscape 4.x stores the browsers homepage " & _
            "the prefs.js file located in the user's Netscape " & _
            "directory. LOP.com has been known to change this " & _
            "value. \n\n" & _
            "(Action taken: Setting is restored to preset URL.)" & vbCrLf
    '// "N2", "N3", "N4"
    s = s & "408=%SHITBROWSER% stores the browser's homepage in " & _
            "prefs.js file located deep in the 'Application Data' " & _
            "folder. The default search engine is also stored " & _
            "in this file. LOP.com has been known to change the " & _
            "homepage URL. \n\n" & _
            "(Action taken: Setting is restored to preset URL.)" & vbCrLf
    '// "O1"
    s = s & "409=A change in the 'Hosts' system file " & _
            "Windows uses to lookup domain names before " & _
            "quering internet DNS servers, effectively " & _
            "making Windows believe that 'auto.search.msn" & _
            ".com' has a different IP than it really has " & _
            "and thus making IE open the wrong page when" & _
            "ever you enter an invalid domain name in the " & _
            "IE Address Bar. \n\n" & _
            "Infected example: 213.67.109.7" & vbTab & "auto.search.msn.com \n\n" & _
            "(Action taken: Line is deleted from hosts file.)" & vbCrLf
    '// "O2"
    s = s & "410=A BHO (Browser Helper Object) is a specially " & _
            "crafted program that integrates into IE, and " & _
            "has virtually unlimited access rights on your " & _
            "system. Though BHO's can be helpful (like the " & _
            "Google Toolbar), hijackers often use them for " & _
            "malicious purposes such as tracking your " & _
            "online behaviour, displaying popup ads etc. \n\n" & _
            "(Action taken: Registry key and CLSID key are deleted, BHO dll file is deleted.)" & vbCrLf
    '// "O3"
    s = s & "411=IE Toolbars are part of BHO's (Browser Helper " & _
            "Objects) like the Google Toolbar that are " & _
            "helpful, but can also be annoying and malicious " & _
            "by tracking your behaviour and displaying " & _
            "popup ads. \n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O4"
    s = s & "412=This part of the scan checks for several " & _
            "suspicious entries that autoload when Windows " & _
            "starts. Autoloading entries can load " & _
            "a Registry script, VB script or JavaScript" & _
            "file, possibly causing the IE Start Page, " & _
            "Search Page, Search Bar and Search Assistant " & _
            "to revert back to a hijacker's page after a " & _
            "system reboot. Also, a DLL file can be loaded " & _
            "that can hook into several parts of your system. \n\n" & _
            "Infected examples: \n\n" & _
            "regedit c:\windows\system\sp.tmp /s \n" & _
            "KERNEL32.VBS \n" & _
            "c:\windows\temp\install.js \n" & _
            "rundll32 C:\Program Files\NewDotNet\newdotnet4_5.dll,NewDotNetStartup \n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O5"
    s = s & "413=Modifying CONTROL.INI can cause Windows " & _
            "to hide certain icons in the Control Panel. " & _
            "Though originally meant to speed up loading of " & _
            "Control Panel and reducing clutter, it can be " & _
            "used by a hijacker to prevent access to the " & _
            "'Internet Options' window. \n\n" & _
            "Infected example: \n[don't load]\n" & _
            "inetcpl.cpl=yes OR inetcpl.cpl=no \n\n" & _
            "(Action taken: Line is deleted from Control.ini file.)" & vbCrLf
    '// "O6"
    s = s & "414=Disabling of the 'Internet Options' menu " & _
            "menu entry in the 'Tools' menu of IE is done " & _
            "by using Windows Policies. Normally used by " & _
            "administrators to restrict their users, it can " & _
            "be used by hijackers to prevent access to the " & _
            "'Internet Options' window.\n\n" & _
            "StartPage Guard also uses Policies to restrict " & _
            "homepage changes, done by hijackers.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O7"
    s = s & "415=Disabling of Regedit is done by using " & _
            "Windows Policies. Normally used by administrators " & _
            "to restrict their users, it can be used by " & _
            "hijackers to prevent access to the Registry editor." & _
            " This results in a message saying that your " & _
            "administrator has not given you privilege to use " & _
            "Regedit when running it.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
    '// "O8"
    s = s & "416=Extra items in the context (right-click) menu " & _
            "can prove helpful or annoying. Some recent hijackers " & _
            "add an item to the context menu. The MSIE PowerTweaks " & _
            "Web Accessory adds several useful items, among which " & _
            """Highlight"", ""Zoom In/Out"", ""Links list"", """ & _
            "Images list"" and ""Web Search"".\n\n" & _
            "(Action taken: Registry key is deleted.)" & vbCrLf
            
    '// "O9"
    s = s & "417=Extra items in the MSIE 'Tools' menu and extra " & _
            "buttons in the main toolbar are usally present as " & _
            "branding (Dell Home button) or after system updates " & _
            "(MSN Messenger button) and rarely by hijackers. The " & _
            "MSIE PowerTweaks Web Accessory adds two menu items, " & _
            "being ""Add site to Trusted Zone"" and ""Add site to " & _
            "Restricted Zone"".\n\n" & _
            "(Action taken: Registry key is deleted.)" & vbCrLf
            
    '// "O10"
    s = s & "418=The Windows Socket system (Winsock) uses a list of " & _
            "providers for resolving DNS names (i.e. translating www." & _
            "microsoft.com into an IP address). This is called the Layered " & _
            "Service Provider (LSP). A few programs are capable of " & _
            "injecting their own (spyware) providers in the LSP. If files " & _
            "referenced by the LSP are " & _
            "missing or the 'chain' of providers is broken, none of the " & _
            "programs on your system can access the Internet. Removing " & _
            "references to missing files and repairing the chain will " & _
            "restore your Internet access.\nSo far, only a few " & _
            "programs use a Winsock hook.\n\n" & _
            "Note: This is a risky procedure. If it should fail, " & _
            "get LSPFix from http://www.cexx.org/lspfix.htm to repair the " & _
            "Winsock stack.\n\n" & _
            "(Action taken: none. Use LSPFix to modify the Winsock stack.)" & vbCrLf
            
    '// "O11" 'MSIE options group
    s = s & "419=The options in the 'Advanced' tab of MSIE options " & _
            "are stored in the Registry, and extra options can be " & _
            "added easily by creating extra Registry keys. Very " & _
            "rarely, spyware/hijackers add their own options there " & _
            "which are hard to remove. E.g. CommonName adds a section " & _
            "'CommonName' with a few options.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
            
    '// "O12" 'MSIE plugins
    s = s & "420=Plugins handle filetypes that aren't supported " & _
            "natively by MSIE. Common plugins handle Macromedia " & _
            "Flash, Acrobat PDF documents and Windows Media formats, " & _
            "enabling the browser to open these itself instead of " & _
            "launching a separate program. When hijackers or spyware " & _
            "add plugins for their filetypes, the danger exists that " & _
            "they get reinstalled if everything except the plugin has " & _
            "been removed, and the browser opens such a file.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
        
    '// "O13" 'DefaultPrefix
    s = s & "421=When you type an URL into MSIE's Address bar without " & _
            "the prefix (http://), it is automatically added when you " & _
            "hit Enter. This prefix is stored in the Registry, together " & _
            "with the default prefixes for FTP, Gopher and a few other " & _
            "protocols. When a hijacker changes these to the URL of his " & _
            "server, you always get redirected there when you forget to " & _
            "type the prefix. Prolivation uses this hijack.\n\n" & _
            "(Action taken: Registry value is restored to default data.)" & vbCrLf
            
    '// "O14" 'IERESET.INF
    s = s & "422=When you hit 'Reset Web Settings' on the 'Programs' tab " & _
            "of the MSIE Options dialog, your homepage, search page and a " & _
            "few other sites get reset to their defaults. These defaults are " & _
            "stored in C:\Windows\Inf\Iereset.inf. When a hijacker changes these " & _
            "to his own URLs, you get (re)infected rather than cured when you " & _
            "click 'Reset Web Settings'. SearchALot uses this hijack.\n\n" & _
            "(Action taken: Value in Inf file is restore to default data.)" & vbCrLf
        
    '// "O15" 'Trusted Zone Autoadd
    s = s & "423=Websites in the Trusted Zone (see Internet Options," & _
            "Security, Trusted Zone, Sites) are allowed to use normally " & _
            "dangerous scripts and ActiveX objects normal sites aren't " & _
            "allowed to use. Some programs will " & _
            "automatically add a site to the Trusted Zone without you " & _
            "knowing. Only a very few legitimate programs are known to do this " & _
            "(Netscape 6 is one of them) and a lot of browser hijackers" & _
            "add sites with ActiveX content to them.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
            
    '// "O16" 'Downloaded Program Files
    s = s & "424=The Download Program Files (DPF) folder in your " & _
            "Windows base folder holds various types of programs " & _
            "that were downloaded from the Internet. These programs " & _
            "are loaded whenever Internet Explorer is active." & _
            "Legitimate examples are the Java VM, Microsoft XML " & _
            "Parser and the Google Toolbar.\n" & _
            "Unfortunately, due to the lack security of IE, malicious " & _
            "sites let IE automatically download porn dialers, " & _
            "bogus plugins, ActiveX Objects etc to this folder, " & _
            "which haunt you with popups, huge phone bills, random " & _
            "crashes, browser hijackings and whatnot." & vbCrLf
        
    '// "O17" 'Domain hijack
    s = s & "425=Windows uses several registry values as a help " & _
            "to resolve domain names into IP addresses. Hijacking " & _
            "these values can cause all programs that use the Internet " & _
            "to be redirected to other pages for seemingly unknown " & _
            "reasons.\n" & _
            "New versions of Lop.com use this method, together with a " & _
            "(huge) list of cryptic domains.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
        
    '// "O18" 'Protocol & Filter
    s = s & "426=A protocol is a 'language' Windows uses to 'talk' " & _
            "to programs, servers or itself. Webservers use the " & _
            "'http:' protocol, FTP servers use the 'ftp:' protocol, " & _
            "Windows Explorer uses the 'file:' protocol. Introducing " & _
            "a new protocol to Windows or changing an existing one " & _
            "can burrow deep into how Windows handles files.\n" & _
            "CommonName and Lop.com both register a new protocol " & _
            "when installed (cn: and ayb:).\n\n" & _
            "The filters are content types accepted by Internet Explorer " & _
            "(and internally by Windows). If a filter exists for a content " & _
            "type, it passes through the file handling that content type " & _
            "first. Several variants of the CWS trojan add a text/html " & _
            "and text/plain filters, allowing them to hook all of the webpage " & _
            "content passed through Internet Explorer.\n\n" & _
            "(Action taken: Registry key is deleted, with everything in it.)" & vbCrLf
            
    '// "O19" 'User stylesheet
    s = s & "427=IE has an option to use a user-defined stylesheet " & _
            "for all pages instead of the default one, to enable " & _
            "handicapped users to better view the pages.\n" & _
            "An especially vile hijacking method made by Datanotary " & _
            "has surfaced, which overwrites any stylesheet the user has " & _
            "setup and replaces it with one that causes popups, as well " & _
            "a system slowdown when typing or loading pages with many " & _
            "pictures.\n\n" & _
            "(Action taken: Registry value is deleted.)" & vbCrLf
        
    '// "O20"  'AppInit_DLLs + WinLogon Notify subkeys
    s = s & "428=Files specified in the AppInit_DLLs Registry value " & _
            "are loaded very early in Windows startup and stay in memory " & _
            "until system shutdown. This way of loading a .dll is hardly " & _
            "ever used, except by trojans.\n" & _
            "The WinLogon Notify Registry subkeys load dll files into memory " & _
            "at about the same point in the boot process, keeping them " & _
            "loaded into memory until the session ends. Apart from several " & _
            "Windows system components, the programs VX2, ABetterInternet " & _
            "and Look2Me use this Registry key.\n" & _
            "Since both methods ensure the dll file stays loaded in " & _
            "memory the entire time, fixing this won't help if the dll " & _
            "puts back the Registry value or key immediately. In such cases, " & _
            "the use of the 'Delete file on reboot' function or KillBox is " & _
            "recommended to first delete the file.\n\n" & _
            "(Action taken for AppInit_DLLs: Registry value is cleared, but not deleted.)\n" & _
            "(Action taken for Winlogon Notify: Registry key is deleted." & vbCrLf
            
    '// "O21"  'ShellServiceObjectDelayLoad
    s = s & "429=This is an undocumented Registry key that contains a list " & _
            "of references to CLSIDs, which in turn reference .dll files " & _
            "that are then loaded by Explorer.exe at system startup. " & _
            "The .dll files stay in memory until Explorer.exe quits, which is " & _
            "achieved either by shutting down the system or killing the shell " & _
            "process.\n\n" & _
            "(Action taken: Registry value is deleted, CLSID key is deleted.)" & vbCrLf
            
    '// "O22"  'SharedTaskScheduler
    s = s & "430=This is an undocumented Registry key that contains a list " & _
            "of CLSIDs, which in turn reference .dll files that are loaded " & _
            "by Explorer.exe at system startup. The .dll files stay in memory " & _
            "until Explorer.exe quits, which is achieved either by shutting " & _
            "down the system or killing the shell process.\n\n" & _
            "(Action taken: Registry value is deleted, CLSID key is deleted.)" & vbCrLf
            
    '// "O23" 'Windows Services
    s = s & "431=The 'Services' in Windows NT4, Windows 2000, Windows XP and " & _
            "Windows 2003 are a special type of programs that are essential to " & _
            "the system and are required for proper functioning of the system. " & _
            "Service processes are started before the user logs in and are " & _
            "protected by Windows. They can only be stopped " & _
            "from the services dialog in the Administrative Tools window.\n" & _
            "Malware that registers itself as a service is subsequently also harder " & _
            "to kill.\n\n" & _
            "(Action taken: services is disabled and stopped. Reboot needed.)" & vbCrLf
        
    '// "O24"
    s = s & "432=Desktop Components are ActiveX objects that can be made " & _
            "part of the desktop whenever Active Desktop is enabled (introduced " & _
            "in Windows 98), where it runs as a (small) website widget.\n" & _
            "Malware misuses this feature by setting the desktop " & _
            "background to a local HTML file with a large, bogus warning.\n\n" & _
            "(Action taken: ActiveX object is deleted from Registry.)" & vbCrLf
    
    '// "O25"
    s = s & "433=�������������� ���������� Windows - ��� ����������� ������ Windows. " & _
            "�� ����� ��������������� ��� �������� ����������� ����������� ������� ��� ��� ���������� " & _
            "��� � ����������� �����. � ������� ���� ������� ����������� ��, ��������� ����������, " & _
            "����� �������� ���������� �� ������������ � ����������� �����������. ����� ��� " & _
            "����� ��������� ����� ��� ����� ����� ������������, ��������� ������ ��� " & _
            "�� �������� �����, ��� � ���������� (�����������). ������� ����� ���������� " & _
            "����������� WMI �������������� ����� ����������� ���������� ������� ���� ������� �����-���� " & _
            "����������, ����������� ����������� ������ � WMI.\n" & _
            "(�������� HiJackThis: ����������� ������� WMI, ������, ������ � ������ ���������, ��� � ���������� ���� ����.)" & vbCrLf
    
    '// frmMain
    s = s & "500=Please Wait" & vbCrLf & _
        "501=Please go to http://sourceforge.net/p/hjt/support-requests/" & vbCrLf & _
        "502=Unknown owner" & vbCrLf & _
        "503=file missing" & vbCrLf & _
        "504=The service you entered is system-critical! It can't be deleted." & vbCrLf & _
        "505=Short name" & vbCrLf & _
        "506=Full name" & vbCrLf & _
        "507=File" & vbCrLf & _
        "508=Owner" & vbCrLf & _
        "509=Enter file to delete on reboot..." & vbCrLf & _
        "510=All files" & vbCrLf & _
        "511=DLL libraries" & vbCrLf & _
        "512=Program files" & vbCrLf & _
        "513=No Internet Connection Available" & vbCrLf & _
        "514=Save Add/Remove Software list to disk..." & vbCrLf & _
        "515=Text files" & vbCrLf & _
        "516=is not implemented yet" & vbCrLf & _
        "517=items in results list" & vbCrLf & _
        "518=Save logfile..." & vbCrLf & _
        "519=Log files" & vbCrLf & _
        "520=End of file - xXxXx bytes" & vbCrLf & _
        "521=Analyze This" & vbCrLf
    
    '// modBackup
    s = s & "530=Unable to create folder to place backups in. Backups of fixed items cannot be saved!" & vbCrLf & _
        "531=Not implemented yet, item '[]' will not be backed up!" & vbCrLf & _
        "532=bad coder - no donuts" & vbCrLf & _
        "533=I'm so stupid I forgot to implement this. Bug me about it." & vbCrLf & _
        "534=d'oh!" & vbCrLf & _
        "535=The backup files for this item were not found. It could not be restored." & vbCrLf & _
        "536=The backup file for this item was not found. It could not be restored." & vbCrLf & _
        "537=Could not find prefs.js file for Netscape/Mozilla, homepage has not been restored." & vbCrLf & _
        "538=BHO file for '[]' was not found. The Registry data was restored, but the file was not." & vbCrLf & _
        "539=Unable to restore this backup: too many items in your Trusted Zone!" & vbCrLf & _
        "540=Unable to restore item: Protocol '[]' was set to unknown zone." & vbCrLf
        
    '// modHosts
    s = s & "550=Loading hosts file, please wait..." & vbCrLf & _
        "551=Cannot find the hosts file. \n" & "Do you want to create a new, default hosts file?" & vbCrLf & _
        "552=No hosts file found." & vbCrLf & _
        "553=The hosts file is locked for reading and cannot be edited. \n" & "Make sure you have privileges to modify the hosts file and " & _
            "no program is protecting it against changes." & vbCrLf
    
    '// modInternet
    s = s & "560=No Internet Connection Available" & vbCrLf
    
    '// modTranslation
    s = s & "570=The language file '[]' is invalid (ambiguous id numbers)." & vbCrLf & _
        "571=Load file for language '[]'" & vbCrLf & _
        "572=Invalid language File. Reset to default (English)?" & vbCrLf
    
    '// modLSP
    s = s & "580=HijackThis cannot repair O10 Winsock LSP entries. \n" & _
            "from https://www.foolishit.com/vb6-projects/winsockreset/\n\n" & _
            "Would you like to visit that site?" & vbCrLf
        
    '// modmain
    s = s & "590=����������, �������� �������� HiJackThis, �������� ��� ��� ��������� �� ������.\n\n" & _
        "��������� ���� ����������� � ����� ������.\n" & _
        "������� '��', ����� ��� ���������.\n\n" & _
        "����������� �� ������:\n\n" & _
        "�������� �������������� ������ � �������: " & vbCrLf & _
        "591=������" & vbCrLf

    sLines = Split(s, vbCrLf)
End Sub

Public Sub SetCharSet(iCharSet As Long)
    'this is for multibyte languages like Japanese, Chinese, etc
    Dim objText As TextBox, objBtn As CommandButton
    Dim objList As ListBox, objLbl As Label
    On Error Resume Next
    For Each objText In frmMain
        Debug.Print objText.Name
        If Not err Then
            objText.Font.Charset = iCharSet
            err.Clear
        End If
    Next objText
    For Each objBtn In frmMain
        Debug.Print objBtn.Name
        If Not err Then
            objBtn.Font.Charset = iCharSet
            err.Clear
        End If
    Next objBtn
    For Each objList In frmMain
        Debug.Print objList.Name
        If Not err Then
            objList.Font.Charset = iCharSet
            err.Clear
        End If
    Next objList
    For Each objLbl In frmMain
        Debug.Print objLbl.Name
        If Not err Then
            objLbl.Font.Charset = iCharSet
            err.Clear
        End If
    Next objLbl
End Sub

Public Function GetHelpText() As String
    GetHelpText = Translate(400)
End Function

Public Sub GetInfo(ByVal sItem$)
    On Error GoTo ErrorHandler:
    
    Dim sMsg$, sPrefix$
    If InStr(sItem, vbCrLf) > 0 Then sItem = Left$(sItem, InStr(sItem, vbCrLf) - 1)
    
    sPrefix = Trim$(Left$(sItem, InStr(sItem, "-") - 1))
    
    Select Case sPrefix
        Case "R0"
            sMsg = Translate(401)
        Case "R1"
            sMsg = Translate(402)
        Case "R2"
            sMsg = Translate(403)
        Case "R3"
            sMsg = Translate(404)
        Case "F0"
            sMsg = Translate(405)
        Case "F1"
            sMsg = Translate(406)
'        Case "N1"
'            sMsg = Translate(407)
'        Case "N2", "N3", "N4"
'            sMsg = Translate(408)
'            If trim$(Left$(sItem, 3)) = "N2" Then sMsg = Replace$(sMsg, "%SHITBROWSER%", "Netscape 6")
'            If trim$(Left$(sItem, 3)) = "N3" Then sMsg = Replace$(sMsg, "%SHITBROWSER%", "Netscape 7")
'            If trim$(Left$(sItem, 3)) = "N4" Then sMsg = Replace$(sMsg, "%SHITBROWSER%", "Mozilla")
        Case "O1"
            sMsg = Translate(409)
        Case "O2"
            sMsg = Translate(410)
        Case "O3"
            sMsg = Translate(411)
        Case "O4"
            sMsg = Translate(412)
        Case "O5"
            sMsg = Translate(413)
        Case "O6"
            sMsg = Translate(414)
        Case "O7"
            sMsg = Translate(415)
        Case "O8"
            sMsg = Translate(416)
        Case "O9"
            sMsg = Translate(417)
        Case "O10"
            sMsg = Translate(418)
        Case "O11" 'MSIE options group
            sMsg = Translate(419)
        Case "O12" 'MSIE plugins
            sMsg = Translate(420)
        Case "O13" 'DefaultPrefix
            sMsg = Translate(421)
        Case "O14" 'IERESET.INF
            sMsg = Translate(422)
        Case "O15" 'Trusted Zone Autoadd
            sMsg = Translate(423)
        Case "O16" 'Downloaded Program Files
            sMsg = Translate(424)
        Case "O17" 'Domain hijack
            sMsg = Translate(425)
        Case "O18" 'Protocol & Filter
            sMsg = Translate(426)
        Case "O19" 'User stylesheet
            sMsg = Translate(427)
        Case "O20" 'AppInit_DLLs + WinLogon Notify subkeys
            sMsg = Translate(428)
        Case "O21" 'ShellServiceObjectDelayLoad
            sMsg = Translate(429)
        Case "O22" 'SharedTaskScheduler
            sMsg = Translate(430)
        Case "O23" 'Windows Services
            sMsg = Translate(431)
        Case "O24"
            sMsg = Translate(432)
        Case "O25"
            sMsg = Translate(433)
        Case Else
            Exit Sub
    End Select
    sMsg = "Detailed information on item " & sPrefix & ":" & vbCrLf & vbCrLf & sMsg
    MsgBoxW sItem & vbCrLf & vbCrLf & sMsg, vbInformation
    Exit Sub
    
ErrorHandler:
    ErrorMsg err, "modInfo_GetInfo", "sItem=", sItem
    If inIDE Then Stop: Resume Next
End Sub

