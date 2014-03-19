#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=PitBoss_121.ico
#AutoIt3Wrapper_outfile=CivStatsUploader.exe
#AutoIt3Wrapper_Res_Comment=CivStats Uploader
#AutoIt3Wrapper_Res_Description=CivStats Uploader
#AutoIt3Wrapper_Res_Fileversion=1.5.3.1
#AutoIt3Wrapper_Res_LegalCopyright=Copyright 2014 Greg Laabs
#AutoIt3Wrapper_Res_Language=1033
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Allow_Decompile=n

; AutoIt Version: 3.0
; Language:       English
; Platform:       WinXP
; Author:         Greg Laabs

#include <Date.au3>
#include <Array.au3>
#include <GuiConstants.au3>
#include <Constants.au3>
#Include <GuiStatusBar.au3>
#include <UnixTime.au3>
#include <HTTP.au3>
;#include <BetterArray.au3> ; Only needed for debugging

#region AutoIt Options
Opt("MustDeclareVars", 1)
Opt("TrayAutoPause", 0) ;Do not pause when trayicon is clicked
Opt("TrayMenuMode", 1) ;No default menu on tray icon
Opt("TrayOnEventMode", 1) ;Use OnEvent mode for tray menus
Opt("WinTitleMatchMode", 4) ;Advanced Window Title mode
Opt("WinWaitDelay", 10)
Opt("GUIOnEventMode", 1) ;Use OnEvent functions instead of the $msg loop
#endregion AutoIt Options

#region Constants
If @Compiled Then
	Global $UPLOADERVERSION = FileGetVersion(@AutoItExe)
Else
	Global $UPLOADERVERSION = "DEV"
EndIf

Const $INIFILENAME = "CivStatsUploader.ini"
Const $OLDINIFILENAME = "PitbossStats.ini"

Const $SCRIPTHOST = "www.civstats.com"
Const $SCRIPTFILE = "/pbupload.php"

Const $HIDDENWINDOWTITLEPREFIX = "PBStatsApp"

;Const $TRAY_EVENT_PRIMARYDOUBLE = -13

Const $PB_PARSELEVEL_INIT = 3
Const $PB_PARSELEVEL_PLAYER = 2
Const $PB_PARSELEVEL_GAME = 1
Const $PB_PARSELEVEL_NONE = 0

Const $PB_ARRAY_PLAYERNAME = 0
Const $PB_ARRAY_SCORE = 1
Const $PB_ARRAY_PLAYERTYPE = 2
Const $PB_ARRAY_FINISHEDTURN = 3

Const $PB_PLAYERTYPE_HUMANOFFLINE = 1
Const $PB_PLAYERTYPE_HUMANONLINE = 2
Const $PB_PLAYERTYPE_AI = 3
Const $PB_PLAYERTYPE_UNCLAIMED = 4

Const $PB_LOGLEVEL_ALWAYS = 0
Const $PB_LOGLEVEL_ERROR = 1
Const $PB_LOGLEVEL_INFO = 2
Const $PB_LOGLEVEL_DEBUG = 3

Const $PB_RETURNCODE_SUCCESS = 1
Const $PB_RETURNCODE_UNKNOWN = 0
Const $PB_RETURNCODE_BADPASSWORD = -1
Const $PB_RETURNCODE_DATABASEERROR = -2
Const $PB_RETURNCODE_UNKNOWNFUNC = -3
Const $PB_RETURNCODE_UNKNOWNDATA = -4
Const $PB_RETURNCODE_BADGAMEID = -5
Const $PB_RETURNCODE_ROLLBACKDETECTED = -6

Const $PB_STATUSICON_NET_INACTIVE = 62
Const $PB_STATUSICON_NET_UPLOADING = 60
Const $PB_STATUSICON_NET_DOWNLOADING = 61
Const $PB_STATUSICON_NET_FULLACTIVITY = 59
Const $PB_STATUSICON_NET_BROKEN = 64
Const $PB_STATUSICON_NET_UNKNOWN = 65
#endregion Constants

#region IniVars
Global $iniDefaultProfile = "default"
Global $iniPathToExe = "C:\Program Files\Firaxis Games\Sid Meier's Civilization 4\Pitboss.exe"
Global $iniLogLevel = 1
Global $iniNeverAskProfile = 0
Global $iniCheckInterval = 4
Global $iniWindowTitleRegex = "'(.+)' successfully saved"""

Global $fileInit = 0
Global $fileDefaultProfile
Global $filePathToExe
Global $fileLogLevel
Global $fileNeverAskProfile
Global $fileCheckInterval

Global $iniGameName
Global $iniGameID
Global $iniGamePass
#endregion

#region Globals
;General
Global $LogFile
Global $LogFileName
Global $ActiveProfile
Global $Watching
Global $GlobalParseTimer
Global $Exiting
Global $PitbossWindowFound
Global $WaitingToParse

;Windows
Global $PitbossWindow

;Game data
Global $GD_NumPlayers
Global $GD_Year
Global $GD_UseTurnTimer
Global $GD_TurnTimer
Global $GD_Players[64][4]
Global $GD_TimerPaused

;Uploading
Global $Uploading
Global $UploadTimer
Global $TimeSinceLastUpload
Global $UploadQueue[1]

Global $FailedUploads
Global $WaitingToRetryUpload
Global $WaitingToUploadTimer
#endregion Globals

#region GUI Globals
Global $MainWindow
Global $LabelGameName, $InputGameName, $ButtonStartWatching
Global $LabelUserName, $InputUserName, $LabelPass, $InputPass, $ButtonDetectWindow
Global $StatusBarMain

Global $ProfilesWindow
Global $LabelSelectProfile, $ListProfiles, $ButtonProfilesNew, $ButtonProfilesCopy, $ButtonProfilesRemove, $ButtonProfilesRename
Global $ButtonProfilesOK, $CheckboxProfilesDontAsk

Global $WindowChooserWindow
Global $LabelWindowChooser, $ListWindows, $ButtonWindowChooserOK, $ButtonWindowChooserCancel

Global $TrayMenuItemExit
#endregion

#region StringGlobals
Global $LOC_MainWindowTitle = "CivStats Uploader"
Global $LOC_GameName = "Game Name:"
Global $LOC_Username = "GameID:"
Global $LOC_Pass = "Upload Pass:"
Global $LOC_StartWatching = "Activate"
Global $LOC_StopWatching = "Deactivate"
Global $LOC_DetectWindow = "Auto Detect"

Global $LOC_SelectProfile = "Please select a profile to use"
Global $LOC_OK = "OK"
Global $LOC_New = "New"
Global $LOC_Rename = "Rename"
Global $LOC_Copy = "Copy"
Global $LOC_Remove = "Remove"
Global $LOC_DontAsk = "Always use this profile"

Global $LOC_EnterNameTitle = "Enter a name"
Global $LOC_EnterNameBody = "Please enter a name"

Global $LOC_StatusReady = "Idle"
Global $LOC_StatusParsing = "Currently Parsing..."
Global $LOC_StatusIdle = "Monitoring Active"
Global $LOC_StatusNoWindow = "Waiting for Pitboss window"
Global $LOC_StatusUploadSuccess = "Last successful upload at %1"
Global $LOC_StatusUploadFail = "Server returned non-critical error at %1. Will retry in 10 seconds. Total Errors: %2"

Global $LOC_ChooserTitle = "Select Window"
Global $LOC_ChooserLabel = "%1 Pitboss windows found"

Global $LOC_ProfileInUse = "The profile ""%1"" is already in use."

Global $LOC_TrayMenuExit = "Exit"

Global $LOC_Error_ServerError = "The server returned a critical error:"
Global $LOC_Error_GameIDMustBeNumber = "The Game ID must be a number"
Global $LOC_Error_BadCharsInProfileName = "A profile name cannot contain any of the following characters: \ / : * ? "" < > |"
#endregion

#region MainFunction ;FUNCTIONS
Func MainLoop()
	While 1
		Sleep(100)

		; Horrible nasty hack code to work around the "nested events do not fire" bug:
		While IsHWnd($WindowChooserWindow) and WinExists($WindowChooserWindow)
			Sleep(10)
			; Wait for the WindowChooser Window to be closed
		WEnd

		; If we were trying to exit and the upload has failed more than twice, we have to give up.
		If $Exiting == 1 And $FailedUploads > 2 Then
			ExitScript("GUI Closed. UNABLE TO UPLOAD HALT COMMAND!")
		EndIf

		; If we were uploading, check to see if it's finished
		If $Uploading == 1 Then
			If $WaitingToRetryUpload == 1 Then
				; The upload failed previously and we're waiting 10 seconds before retrying.
				If TimerDiff($WaitingToUploadTimer) > 10000 Then
					$WaitingToRetryUpload = 0
					UploadNext()
				EndIf
			Else
				UploadNext()
			EndIf
		EndIf

		; If we're currently watching the window, we do a couple things.
		If $Watching == 1 Then
			; If we are waiting for the window to show up, we should keep checking
			If $WaitingToParse > $PB_PARSELEVEL_NONE Then
				;We should only try once every second.
				If TimerDiff($GlobalParseTimer) > 1000 Then
					ParseWindow($WaitingToParse)
					$GlobalParseTimer = TimerInit()
				EndIf
			ElseIf TimerDiff($GlobalParseTimer) > $iniCheckInterval * 1000 Then
				ParseWindow($PB_PARSELEVEL_PLAYER)
				$GlobalParseTimer = TimerInit()
			EndIf
		EndIf
	WEnd
EndFunc   ;==>MainLoop
#endregion

#region GUI Functions
;***************
; GUI FUNCTIONS
;***************
Func MainWindowCreate()
	$MainWindow = GUICreate($LOC_MainWindowTitle & " " & $UPLOADERVERSION, 275, 165, -1, -1)
	GUISetOnEvent($GUI_EVENT_CLOSE, "MainWindowCLOSE")
	GUISetOnEvent($GUI_EVENT_MINIMIZE, "MainWindowMINIMIZE")

	$LabelGameName = GUICtrlCreateLabel($LOC_GameName, 10, 10, 80, 20)
	$InputGameName = GUICtrlCreateInput($iniGameName, 10, 30, 180, 20)
	GUICtrlSetOnEvent($InputGameName, "MainWindowINPUTChanged")
	$ButtonDetectWindow = GUICtrlCreateButton($LOC_DetectWindow, 195, 30, 65, 20)
	GUICtrlSetOnEvent($ButtonDetectWindow, "MainWindowBUTTONDetectWindow")

	$LabelUserName = GUICtrlCreateLabel($LOC_Username, 10, 60, 125, 20)
	$InputUserName = GUICtrlCreateInput($iniGameID, 10, 80, 45, 20)
	GUICtrlSetOnEvent($InputUserName, "MainWindowINPUTChanged")
	$LabelPass = GUICtrlCreateLabel($LOC_Pass, 65, 60, 160, 20)
	$InputPass = GUICtrlCreateInput($iniGamePass, 65, 80, 205, 20)
	GUICtrlSetOnEvent($InputPass, "MainWindowINPUTChanged")

	$ButtonStartWatching = GUICtrlCreateButton($LOC_StartWatching, 10, 115, 90, 20)
	GUICtrlSetOnEvent($ButtonStartWatching, "MainWindowBUTTONStartWatching")
	Local $status_bar_edge[2] = [253, 275]
	Local $status_bar_text[2] = ["1", "2"]
	$StatusBarMain = _GuiCtrlStatusBar_Create($MainWindow, $status_bar_edge, $status_bar_text, $SBT_TOOLTIPS)
	Status($LOC_StatusReady)
	StatusNetIcon($PB_STATUSICON_NET_INACTIVE)
	GUISetState()

EndFunc   ;==>MainWindowCreate

Func MainWindowCLOSE()
	UpdateVarsFromGUI()
	StartExitProcess()
EndFunc   ;==>MainWindowCLOSE

Func MainWindowMINIMIZE()
	HideWindow()
EndFunc   ;==>MainWindowMINIMIZE

Func MainWindowINPUTChanged()
	UpdateVarsFromGUI()
EndFunc   ;==>MainWindowINPUTChanged

Func MainWindowBUTTONStartWatching()
	UpdateVarsFromGUI()
	ToggleWatching()
EndFunc   ;==>MainWindowBUTTONStartWatching

Func MainWindowBUTTONDetectWindow()
	DetectPitbossWindows()
	UpdateVarsFromGUI()
EndFunc   ;==>MainWindowBUTTONDetectWindow

Func HideWindow()
	GUISetState(@SW_HIDE, $MainWindow)
	TraySetState(1)
	TraySetClick(16)
	TraySetToolTip($LOC_MainWindowTitle & " - " & $ActiveProfile)
EndFunc   ;==>HideWindow

Func ShowWindow()
	TraySetState(2)
	GUISetState(@SW_SHOW, $MainWindow)
EndFunc   ;==>ShowWindow

#region WindowChooser
Func ChooseWindow(ByRef $windowtitles)
	Dim $numwindows, $i
	$numwindows = UBound($windowtitles)

	MyLog( "GUI Event: WindowChooser Window Created", $PB_LOGLEVEL_DEBUG)
	$WindowChooserWindow = GUICreate($LOC_ChooserTitle, 150, 165, -1, -1, $WS_DLGFRAME, -1, $MainWindow)
	GUISetOnEvent($GUI_EVENT_CLOSE, "WindowChooserCLOSED")

	$LabelWindowChooser = GUICtrlCreateLabel(FormatString($LOC_ChooserLabel, $numwindows), 10, 10, 130, 20)
	$ListWindows = GUICtrlCreateList("", 10, 30, 130, 90)
	$ButtonWindowChooserOK = GUICtrlCreateButton("OK", 10, 120, 60, 20)
	GUICtrlSetOnEvent($ButtonWindowChooserOK, "WindowChooserBUTTONOK")
	$ButtonWindowChooserCancel = GUICtrlCreateButton("Cancel", 80, 120, 60, 20)
	GUICtrlSetOnEvent($ButtonWindowChooserCancel, "WindowChooserCLOSED")

	For $i = 1 To $numwindows
		GUICtrlSetData($ListWindows, $windowtitles[$i - 1] & "|")
	Next
	GUISetState()
	GUISetState(@SW_DISABLE, $MainWindow)

;~ 	While WinExists($WindowChooserWindow)
;~ 		Sleep(10)
;~ 		; Wait for the WindowChooser Window to be closed
;~ 	WEnd
EndFunc   ;==>ChooseWindow

Func WindowChooserCLOSED()
	MyLog( "GUI Event: WindowChooser Closed", $PB_LOGLEVEL_DEBUG)
	GUISetState(@SW_ENABLE, $MainWindow)
	GUIDelete($WindowChooserWindow)
EndFunc   ;==>WindowChooserCLOSED

Func WindowChooserBUTTONOK()
	MyLog( "GUI Event: WindowChooser OK Button Clicked", $PB_LOGLEVEL_DEBUG)
	GUICtrlSetData($InputGameName, GUICtrlRead($ListWindows))
	WindowChooserCLOSED()
EndFunc   ;==>WindowChooserBUTTONOK

Func DetectPitbossWindows()
	Dim $numwindows, $windows, $j, $i, $regex
	$windows = WinList("classname=wxWindowClassNR")
	If $windows[0][0] <> 0 Then
		Dim $windowtitles[1]
		$j = 0
		For $i = 1 To $windows[0][0]
			$regex = StringRegExp($windows[$i][0], $iniWindowTitleRegex, 1)
			If @error = 0 Then
				ReDim $windowtitles[$j+1]
				$windowtitles[$j] = $regex[0]
				$j = $j + 1
			EndIf
		Next
		$numwindows = $j
		If $numwindows = 0 Then
			MsgBox(48 + 8192, $LOC_MainWindowTitle, "No Pitboss windows detected.")
		ElseIf $numwindows = 1 Then
			GUICtrlSetData($InputGameName, $windowtitles[0])
		Else
			ChooseWindow($windowtitles)
		EndIf
	Else
		MsgBox(48 + 8192, $LOC_MainWindowTitle, "No Pitboss windows detected.")
	EndIf
EndFunc   ;==>DetectPitbossWindows
#endregion WindowChooser

#region ProfileWindow
Func ChooseProfile()

	MyLog("ProfilesGUI()", $PB_LOGLEVEL_DEBUG)
	$ProfilesWindow = GUICreate($LOC_MainWindowTitle, 270, 255, -1, -1)
	GUISetOnEvent($GUI_EVENT_CLOSE, "ProfileWindowCLOSED")

	$LabelSelectProfile = GUICtrlCreateLabel($LOC_SelectProfile, 10, 10, 190, 20)
	$ListProfiles = GUICtrlCreateList("", 10, 30, 150, 180)
	GUICtrlSetOnEvent($ListProfiles, "ProfileWindowLISTUpdated")
	$ButtonProfilesNew = GUICtrlCreateButton($LOC_New, 170, 30, 90, 22)
	GUICtrlSetOnEvent($ButtonProfilesNew, "ProfileWindowBUTTONNew")
	$ButtonProfilesRename = GUICtrlCreateButton($LOC_Rename, 170, 60, 90, 22)
	GUICtrlSetOnEvent($ButtonProfilesRename, "ProfileWindowBUTTONRename")
	$ButtonProfilesCopy = GUICtrlCreateButton($LOC_Copy, 170, 90, 90, 22)
	GUICtrlSetOnEvent($ButtonProfilesCopy, "ProfileWindowBUTTONCopy")
	$ButtonProfilesRemove = GUICtrlCreateButton($LOC_Remove, 170, 120, 90, 22)
	GUICtrlSetOnEvent($ButtonProfilesRemove, "ProfileWindowBUTTONRemove")
	$CheckboxProfilesDontAsk = GUICtrlCreateCheckbox($LOC_DontAsk, 10, 200, 190, 22)
	If $iniNeverAskProfile = 1 Then GUICtrlSetState($CheckboxProfilesDontAsk, $GUI_CHECKED)
	$ButtonProfilesOK = GUICtrlCreateButton($LOC_OK, 10, 225, 90, 22)
	GUICtrlSetOnEvent($ButtonProfilesOK, "ProfileWindowBUTTONOK")

	UpdateProfilesList()

	GUISetState()

	While WinExists($ProfilesWindow)
		; Wait for the Profiles Window to be closed
		Sleep(10)
	WEnd
EndFunc   ;==>ChooseProfile

Func ProfileWindowCLOSED()
	MyLog( "GUI Event: Closed Profile Window", $PB_LOGLEVEL_DEBUG)
	ExitScript("Closed Profile Window")
EndFunc   ;==>ProfileWindowCLOSED

Func ProfileWindowBUTTONOK()
	MyLog( "GUI Event: Profile OK Button Clicked: " & GUICtrlRead($ListProfiles), $PB_LOGLEVEL_DEBUG)
	UpdateVarsFromProfilesGUI()
	GUIDelete($ProfilesWindow)
EndFunc   ;==>ProfileWindowBUTTONOK

Func ProfileWindowBUTTONNew()
	MyLog( "GUI Event: New Profile Clicked: " & GUICtrlRead($ListProfiles), $PB_LOGLEVEL_DEBUG)
	Dim $profilename = GetNewProfileName()
	If $profilename <> - 1 Then
		NewProfile($profilename)
		UpdateProfilesList()
	EndIf
EndFunc   ;==>ProfileWindowBUTTONNew

Func ProfileWindowBUTTONRename()
	MyLog( "GUI Event: Rename Profile Clicked: " & GUICtrlRead($ListProfiles), $PB_LOGLEVEL_DEBUG)
	Dim $profilename = GetNewProfileName()
	If $profilename <> - 1 Then
		RenameProfile(GUICtrlRead($ListProfiles), $profilename)
		UpdateProfilesList()
	EndIf
EndFunc   ;==>ProfileWindowBUTTONRename

Func ProfileWindowBUTTONCopy()
	MyLog( "GUI Event: Copy Profile Clicked: " & GUICtrlRead($ListProfiles), $PB_LOGLEVEL_DEBUG)
	Dim $profilename = GetNewProfileName()
	If $profilename <> - 1 Then
		DuplicateProfile(GUICtrlRead($ListProfiles), $profilename)
		UpdateProfilesList()
	EndIf
EndFunc   ;==>ProfileWindowBUTTONCopy

Func ProfileWindowBUTTONRemove()
	MyLog( "GUI Event: Delete Profile Clicked: " & GUICtrlRead($ListProfiles), $PB_LOGLEVEL_DEBUG)
	DeleteProfile(GUICtrlRead($ListProfiles))
	UpdateProfilesList()
EndFunc   ;==>ProfileWindowBUTTONRemove

Func ProfileWindowLISTUpdated()
	If GUICtrlRead($ListProfiles) Then
		MyLog( "GUI Event: Profile Changed: " & GUICtrlRead($ListProfiles), $PB_LOGLEVEL_DEBUG)
		LoadProfileFromIni(GUICtrlRead($ListProfiles))
	Else
		;Shouldn't ever happen
	EndIf
EndFunc   ;==>ProfileWindowLISTUpdated

Func UpdateProfilesList()
	MyLog("UpdateProfilesList()", $PB_LOGLEVEL_DEBUG)

	Dim $SectionNames, $numProfiles, $BackupProfile

	$numProfiles = 0

	GUICtrlSetData($ListProfiles, "")

	$BackupProfile = ""
	$SectionNames = IniReadSectionNames(@ScriptDir & "\" & $INIFILENAME)
	If @error Or $SectionNames[0] = 0 Then
		MyLog("ERROR: UNABLE TO GET PROFILES LIST FOR GUI", $PB_LOGLEVEL_ERROR)
	Else
		For $i = 1 To $SectionNames[0]
			If $SectionNames[$i] <> "global" Then
				If $BackupProfile == "" Then $BackupProfile = $SectionNames[$i]

				If $SectionNames[$i] = $ActiveProfile Then
					GUICtrlSetData($ListProfiles, $SectionNames[$i] & "|", $SectionNames[$i])
				Else
					GUICtrlSetData($ListProfiles, $SectionNames[$i] & "|")
				EndIf
				$numProfiles = $numProfiles + 1
			EndIf
		Next
	EndIf

	If $numProfiles > 1 Then
		GUICtrlSetState($ButtonProfilesRemove, $GUI_ENABLE)
	Else
		GUICtrlSetState($ButtonProfilesRemove, $GUI_DISABLE)
	EndIf

	If GUICtrlRead($ListProfiles) Then
		LoadProfileFromIni(GUICtrlRead($ListProfiles))
	Else
		LoadProfileFromIni($BackupProfile)
	EndIf
EndFunc   ;==>UpdateProfilesList

Func GetNewProfileName()
	Dim $name
	While 1
		$name = InputBox($LOC_EnterNameTitle, $LOC_EnterNameBody, $name, " M", 190, 115)
		If StringRegExp($name, "[\\/:*?""<>|]") Then
			MsgBox(16 + 8192, $LOC_MainWindowTitle, $LOC_Error_BadCharsInProfileName)
		Else
			ExitLoop
		EndIf
	WEnd
	If @error Then
		Return -1
	Else
		Return $name
	EndIf
EndFunc   ;==>GetNewProfileName
#endregion ProfileWindow

Func StartExitProcess()
	$Exiting = 1
	If $Watching = 1 Then
		UploadHaltCommand()
	ElseIf $Uploading = 0 Then
		ExitScript("GUI Closed")
	EndIf
	$Watching = 0
	GUISetState(@SW_HIDE)
EndFunc   ;==>StartExitProcess

Func Status($text, $repl1 = "", $repl2 = "", $repl3 = "", $repl4 = "")
	$text = FormatString($text, $repl1, $repl2, $repl3, $repl4)
	_GuiCtrlStatusBar_SetText($StatusBarMain, $text)
EndFunc   ;==>Status

Func StatusNetIcon($icon)
	_GuiCtrlStatusBar_SetIcon($StatusBarMain, 1, @SystemDir & "\NetShell.dll", $icon)
EndFunc   ;==>StatusNetIcon

Func StatusNetText($text, $repl1 = "", $repl2 = "", $repl3 = "", $repl4 = "")
	$text = FormatString($text, $repl1, $repl2, $repl3, $repl4)
	_GuiCtrlStatusBar_SetTipText($StatusBarMain, 1, $text)
EndFunc   ;==>StatusNetText
#endregion

#region Game Watching Functions
;************************
; GAME WATCHING FUNCTIONS
;************************
Func FindPitbossWindow()
	Dim $WindowTitle

	If $PitbossWindowFound = 1 And WinExists($PitbossWindow) Then
		Return 1
	Else
		$WindowTitle = "'" & $iniGameName & "' successfully saved"""
		$PitbossWindow = WinGetHandle($WindowTitle)

		If @error = 1 Then
			$PitbossWindow = 0
			$PitbossWindowFound = 0
			Return 0
		Else
			$PitbossWindowFound = 1
			MyLog("Found Pitboss Window. Handle: " & $PitbossWindow, $PB_LOGLEVEL_INFO)
			Return 1
		EndIf
	EndIf
EndFunc   ;==>FindPitbossWindow

Func ToggleWatching()
	Dim $i

	If $Watching = 0 Then
		GUICtrlSetData($ButtonStartWatching, $LOC_StopWatching)

		$GlobalParseTimer = TimerInit()
		$GD_NumPlayers = 0
		$GD_TurnTimer = -1
		$GD_UseTurnTimer = 0
		$GD_Year = 0

		GUICtrlSetState($InputGameName, $GUI_DISABLE)
		GUICtrlSetState($InputUserName, $GUI_DISABLE)
		GUICtrlSetState($InputPass, $GUI_DISABLE)

		Status($LOC_StatusIdle)

		$Watching = 1
		ParseWindow($PB_PARSELEVEL_INIT)
	Else
		GUICtrlSetData($ButtonStartWatching, $LOC_StartWatching)
		$Watching = 0
		UploadHaltCommand()

		GUICtrlSetState($InputGameName, $GUI_ENABLE)
		GUICtrlSetState($InputUserName, $GUI_ENABLE)
		GUICtrlSetState($InputPass, $GUI_ENABLE)

		Status($LOC_StatusReady)
	EndIf
EndFunc   ;==>ToggleWatching

Func ParseWindow($level)
	Dim $text, $parsetimer, $totalparsetimer, $num, $i, $changed, $regex, $playersfound

	If FindPitbossWindow() = 1 Then
		$totalparsetimer = TimerInit()
		$changed = 0
		Status($LOC_StatusParsing)

		; INIT LEVEL
		; This is when we first start watching. We need to get basic info like
		; how many players there are in the game
		If $level >= $PB_PARSELEVEL_INIT Then
			;Find out the number of players
			$num = 0
			$playersfound = 0
			$changed = 1
			$parsetimer = TimerInit()
			While 1
				;Button1 = "Player 1"
				;Button3 = "Player 2"
				;Button5 = "Player 3"
				$text = ControlGetText($PitbossWindow, "", "Button" & $num * 2 + 1)
				If $text = "Save Game" or $text = "Exit Game" Then
					ExitLoop
				EndIf
				If $text = "Kick" or StringRegExp($text, "^Player .*") Then
					$playersfound = $playersfound + 1
				EndIf
				$num = $num + 1
			WEnd
			$GD_NumPlayers = $playersfound
			MyLog("There are " & $GD_NumPlayers & " players. Parse Time: " & TimerDiff($parsetimer) / 1000, $PB_LOGLEVEL_INFO)

			;Find out if there is a turn timer in use
			$parsetimer = TimerInit()
			$text = ControlGetText($PitbossWindow, "", "Static2")
			If $text = "Who" Then
				$GD_UseTurnTimer = 0
				MyLog("No turn timer is in use. Parse Time: " & TimerDiff($parsetimer) / 1000, $PB_LOGLEVEL_INFO)
			Else
				$GD_UseTurnTimer = 1
				MyLog("A turn timer is in use and is currently: " & $text & ". Parse Time: " & TimerDiff($parsetimer) / 1000, $PB_LOGLEVEL_INFO)
			EndIf
		EndIf

		; "SOME" LEVEL
		; This checks general game info like the turn timer, year, and MOTD.
		; This must come before the "ALL" level because it resets a lot of things when the year changes.
		If $level >= $PB_PARSELEVEL_GAME Then
			;Check to see if the year changed.
			$text = GetYear()
			If $text <> $GD_Year Then
				MyLog("A new turn has begun! Year: " & $text, $PB_LOGLEVEL_INFO)
				$GD_Year = $text
				$changed = 1

				For $i = 1 To $GD_NumPlayers
					$GD_Players[$i - 1][$PB_ARRAY_FINISHEDTURN] = 0
				Next
				;Force a check of all player info because it's a new turn.
				If $level < $PB_PARSELEVEL_PLAYER Then $level = $PB_PARSELEVEL_PLAYER
			EndIf

			;Find out how many seconds are left on the turn timer.
			If $GD_UseTurnTimer = 1 Then
				$num = GetTurnTimeLeft()
				If $num <> $GD_TurnTimer Then
					If $num > $GD_TurnTimer Then
						$changed = 1
					EndIf
					$GD_TimerPaused = 0
					$GD_TurnTimer = $num
				Else
					$GD_TimerPaused = 1
				EndIf
			EndIf
		EndIf

		; "ALL" LEVEL
		; This checks all of the players info
		If $level >= $PB_PARSELEVEL_PLAYER Then
			;Find out if anyone's name changed.
			$parsetimer = TimerInit()
			For $i = 1 To $GD_NumPlayers
				;Check player name
				$text = GetPlayerName($i)
				;Strip any *MOD* out of a player's name. Pitboss puts this in players' names when it detects they are using modified
				;assets. The asterisk screws up the turn finished indicator.
				$text = StringReplace($text, "*MOD*  ", "")
				;Split out the "finished turn star" and the actual player name
				$regex = StringRegExp($text, "(\*?)(.+)", 1)
				If UBound($regex) = 1 Then
					$text = $regex[0]
				Else
					$text = $regex[1]
				EndIf

				;Check to see if this player recently finished his turn
				If $regex[0] = "*" And $GD_Players[$i - 1][$PB_ARRAY_FINISHEDTURN] = 0 Then
					MyLog("Player " & $i & " has finished his turn.", $PB_LOGLEVEL_INFO)
					$GD_Players[$i - 1][$PB_ARRAY_FINISHEDTURN] = 1
					$changed = 1
				EndIf

				;Check to see if this player changed his name
				If $text <> $GD_Players[$i - 1][$PB_ARRAY_PLAYERNAME]Then
					MyLog("Player " & $i & "'s name is now: " & $text, $PB_LOGLEVEL_INFO)
					$GD_Players[$i - 1][$PB_ARRAY_PLAYERNAME] = $text
					$changed = 1
				EndIf
			Next

			;Find out if anyone's score changed.
			$parsetimer = TimerInit()
			For $i = 1 To $GD_NumPlayers
				;Check player score
				$text = GetPlayerScore($i)
				If $text <> $GD_Players[$i - 1][$PB_ARRAY_SCORE]Then
					MyLog("Player " & $i & "'s score is now: " & $text, $PB_LOGLEVEL_INFO)
					$GD_Players[$i - 1][$PB_ARRAY_SCORE] = $text
					$changed = 1
				EndIf
			Next

			;Find out if anyone's "type" changed.
			$parsetimer = TimerInit()
			For $i = 1 To $GD_NumPlayers
				;Check player types
				$text = GetPlayerType($i)
				If $text <> $GD_Players[$i - 1][$PB_ARRAY_PLAYERTYPE]Then
					MyLog("Player " & $i & "'s type is now: " & $text, $PB_LOGLEVEL_INFO)
					$GD_Players[$i - 1][$PB_ARRAY_PLAYERTYPE] = $text
					$changed = 1
				EndIf
			Next
		EndIf

		MyLog("Total Parse Time: " & TimerDiff($totalparsetimer) / 1000, $PB_LOGLEVEL_DEBUG)

		; If it's been more than 15 minutes since the last upload, force one now because the turn timer
		; gets out of sync.
		If TimerDiff($TimeSinceLastUpload) > 900 * 1000 Then
			$changed = 1
		EndIf

		If $changed = 1 Then
			UploadData($level)
		EndIf

		Status($LOC_StatusIdle)
		$WaitingToParse = $PB_PARSELEVEL_NONE
	Else
		; Pitboss Window not found
		Status($LOC_StatusNoWindow)
		$WaitingToParse = $level
	EndIf
EndFunc   ;==>ParseWindow

Func GetPlayerName($playernum)
	Dim $text

	;Static3 = Player 1's name
	;Static9 = Player 2's name
	;Static15 = Player 3's name
	;If there is a turn timer, it's all increased by 1

	$text = ControlGetText($PitbossWindow, "", "Static"& (($playernum - 1) * 6) + 3 + $GD_UseTurnTimer)
	Return $text
EndFunc   ;==>GetPlayerName

Func GetPlayerScore($playernum)
	Dim $text

	;Static7 = Player 1's score
	;Static13 = Player 2's score
	;Static19 = Player 3's score
	;If there is a turn timer, it's all increased by 1

	$text = ControlGetText($PitbossWindow, "", "Static"& (($playernum - 1) * 6) + 7 + $GD_UseTurnTimer)
	Return $text
EndFunc   ;==>GetPlayerScore

Func GetPlayerType($playernum)
	Dim $text

	;Static5 = Player 1's score
	;Static11 = Player 2's score
	;Static17 = Player 3's score
	;If there is a turn timer, it's all increased by 1

	$text = ControlGetText($PitbossWindow, "", "Static"& (($playernum - 1) * 6) + 5 + $GD_UseTurnTimer)
	If $text = "Unclaimed" Then
		Return $PB_PLAYERTYPE_UNCLAIMED
	ElseIf $text = "AI" Then
		Return $PB_PLAYERTYPE_AI
	ElseIf $text = "Disconnected" Then
		Return $PB_PLAYERTYPE_HUMANOFFLINE
	Else
		Return $PB_PLAYERTYPE_HUMANONLINE
	EndIf
EndFunc   ;==>GetPlayerType

Func GetYear()
	Dim $text, $regex, $regerror, $year

	$text = ControlGetText($PitbossWindow, "", "Static1")
	$regex = StringRegExp($text, ".* - ([0-9]+ BC)|.* - ([0-9]+ AD)", 1)
	$regerror = @error
	If $regerror = 2 Then
		MyLog("ERROR: Bad Regex for getting Year", $PB_LOGLEVEL_ERROR)
		Return "Unknown"
	Else
		If $regerror = 1 Then
			MyLog("ERROR: Regex for getting Year did not match anything", $PB_LOGLEVEL_ERROR)
			Return "Unknown"
		Else
			If $regex[0] <> "" Then
				$year = $regex[0]
			ElseIf $regex[1] <> "" Then
				$year = $regex[1]
			EndIf
			MyLog("The year is " & $year, $PB_LOGLEVEL_INFO)
			Return $year
		EndIf
	EndIf
EndFunc   ;==>GetYear

Func GetTurnTimeLeft()
	Dim $text, $regex, $seconds
	If $GD_UseTurnTimer Then
		$text = ControlGetText($PitbossWindow, "", "Static2")
		$regex = StringRegExp($text, "([0-9]+):([0-9]+):([0-9]+)", 1)
		If @error = 2 Then
			MyLog("ERROR: Bad Regex for getting Turn Timer", $PB_LOGLEVEL_ERROR)
			Return -2
		Else
			If @error = 1 Then
				MyLog("ERROR: Regex for getting Turn Timer did not match anything", $PB_LOGLEVEL_ERROR)
				Return -2
			Else
				$seconds = $regex[0] * 3600 + $regex[1] * 60 + $regex[2]
				Return $seconds
			EndIf
		EndIf
	Else
		Return -1
	EndIf
EndFunc   ;==>GetTurnTimeLeft

#endregion

#region Net Functions
Func InitUploadData(ByRef $data, $func)
	Dim $timestamp = _TimeGetStamp()

	If @error = 99 Then
		$timestamp = 0
	EndIf

	Dim $data[5][2]

	$data[0][0] = "Func"
	$data[0][1] = $func

	$data[1][0] = "ID"
	$data[1][1] = $iniGameID

	$data[2][0] = "Pass"
	$data[2][1] = $iniGamePass

	$data[3][0] = "UploaderVersion"
	$data[3][1] = $UPLOADERVERSION

	$data[4][0] = "timestamp"
	$data[4][1] = $timestamp
EndFunc   ;==>InitUploadData

Func AddUploadData(ByRef $array, $key, $value)
	Dim $size = UBound($array)
	ReDim $array[$size + 1][2]
	$array[$size][0] = $key
	$array[$size][1] = $value
EndFunc   ;==>AddUploadData

Func UploadData($level)
	Dim $i, $data

	If $level >= $PB_PARSELEVEL_INIT Then
		InitUploadData($data, "Init")
		AddUploadData($data, "NumPlayers", $GD_NumPlayers)
		AddUploadData($data, "UseTurnTimer", $GD_UseTurnTimer)
		AddUploadData($data, "GameName", $iniGameName)

		QueueUpload($data)
	EndIf

	If $level >= $PB_PARSELEVEL_GAME Then
		InitUploadData($data, "GameData")
		AddUploadData($data, "Year", $GD_Year)
		AddUploadData($data, "TurnTimer", $GD_TurnTimer)

		QueueUpload($data)
	EndIf

	If $level >= $PB_PARSELEVEL_PLAYER Then
		InitUploadData($data, "PlayerData")

		For $i = 1 To $GD_NumPlayers
			AddUploadData($data, "P" & $i & "Name", $GD_Players[$i - 1][$PB_ARRAY_PLAYERNAME])
			AddUploadData($data, "P" & $i & "Type", $GD_Players[$i - 1][$PB_ARRAY_PLAYERTYPE])
			AddUploadData($data, "P" & $i & "Score", $GD_Players[$i - 1][$PB_ARRAY_SCORE])
			AddUploadData($data, "P" & $i & "Finished", $GD_Players[$i - 1][$PB_ARRAY_FINISHEDTURN])
		Next

		QueueUpload($data)
	EndIf
EndFunc   ;==>UploadData

Func UploadHaltCommand()
	Dim $data
	InitUploadData($data, "Halt")

	QueueUpload($data)
EndFunc   ;==>UploadHaltCommand

; Returns an array:
; [0] - The PB_RETURNCODE
; [1] - A flag whether or not the error was a critical error
; [2] - Human readable error
Func CheckUpload($data)
	Dim $regex

	$regex = StringRegExp($data, "pbupload:([^|:]*)\|", 1)
	Dim $returncode
	If @error = 1 Then
		$returncode = $PB_RETURNCODE_UNKNOWNDATA
	Else
		$returncode = int($regex[0])
	EndIf

	$regex = StringRegExp($data, "\|critical:([^|:]*)\|", 1)
	Dim $criticalflag
	If @error = 1 Then
		$criticalflag = 0
	Else
		$criticalflag = int($regex[0])
	EndIf

	$regex = StringRegExp($data, "\|error:([^|:]*)\|", 1)
	Dim $errorname
	If @error = 1 Then
		$errorname = "Unable to parse response from server."
	Else
		$errorname = $regex[0]
	EndIf

	Local $return_array[3] = [$returncode, $criticalflag, $errorname]
	Return $return_array
EndFunc   ;==>CheckUpload

Func UploadNext()
	Dim $errorcode;
	Dim $QueueLength = UBound($UploadQueue)
	If $QueueLength < 2 Then
		$Uploading = 0

		If $Exiting = 1 Then
			ExitScript("GUI Closed, Halt command uploaded.")
		EndIf

		StatusNetIcon($PB_STATUSICON_NET_INACTIVE)
		Return
	EndIf

	StatusNetIcon($PB_STATUSICON_NET_UPLOADING)
	$TimeSinceLastUpload = TimerInit()
	Dim $data = $UploadQueue[1]

	$Uploading = 1
	$UploadTimer = TimerInit()

	Dim $POSTVars = FormatPOSTVars($data)
	MyLog("Uploading data: "&$POSTVars, $PB_LOGLEVEL_DEBUG)
	Dim $s = _HTTPConnect ($SCRIPTHOST)

	If @error = 1 Then
		MyLog("Unable to connect to server: "&$SCRIPTHOST&" - Windows API WSAGetLasterror: "&@extended, $PB_LOGLEVEL_ERROR)
		UploadFailed()
		_HTTPClose($s)
		Return
	EndIf

	MyLog("Starting an upload. Func=" & $data[0][1] & " Vars: " & $POSTVars, $PB_LOGLEVEL_DEBUG)
	_HTTPPost ($SCRIPTHOST, $SCRIPTFILE, $s, $POSTVars)
	ConsoleWrite(@error&@CRLF)
	If @error = 2 Then
		MyLog("Unable to send data on open socket. Windows API WSAGetError: "&@extended, $PB_LOGLEVEL_ERROR)
		UploadFailed()
		_HTTPClose($s)
		Return
	EndIf

	Dim $recv = _HTTPRead ($s, 1)
	$errorcode = @error

	_HTTPClose($s)
	Switch $errorcode
		Case 3 ; Server timeout
			UploadFailed()
			MyLog("Server timed out. Will retry.", $PB_LOGLEVEL_ERROR)
			Return
		Case 4 ; Partial download
			UploadFailed()
			MyLog("Data only partially downloaded. Will retry.", $PB_LOGLEVEL_ERROR)
			Return
		Case 5, 6, 8 ; Unable to parse HTTP response.
			UploadFailed()
			MyLog("****** CRITICAL ERROR ****** UNABLE TO PARSE PART OF THE HTTP RESPONSE ("&$errorcode&"). PLEASE SUBMIT THIS AS A BUG REPORT. The line that caused the problem is: "& $recv)
			Return
	EndSwitch

	If $recv[0] < 200 OR $recv[0] >= 300 Then
		UploadFailed()
		MyLog("Server returned an HTTP error. Response: "&$recv[0]&" "&$recv[1], $PB_LOGLEVEL_ERROR)
		Return
	EndIf

	Dim $serverresponse = CheckUpload($recv[4])

	If $serverresponse[0] > 0 Then
		; The upload worked!
		_ArrayDelete($UploadQueue, 1)
		$FailedUploads = 0
		StatusNetText($LOC_StatusUploadSuccess, _NowTime())
	ElseIf $serverresponse[0] == $PB_RETURNCODE_UNKNOWNDATA Then
		; Could not parse response from server. Most likely the php script returned an error.
		UploadFailed()
		MyLog("Unable to parse response from server. The PHP script is most likely throwing an error.", $PB_LOGLEVEL_ERROR)
		MyLog("Response from server: "&@CRLF&$recv[4], $PB_LOGLEVEL_DEBUG)
	Else ; The upload failed for some reason.
		If $serverresponse[1] == 1 Then
			; The error was critical. Abort uploads and display the error.
			AbortUploads()
			MyLog("Server replied with a CRITICAL error. Return code: " & $serverresponse[0] & " Error: " & $serverresponse[2], $PB_LOGLEVEL_ERROR)
			MsgBox(16 + 8192, $LOC_MainWindowTitle, $LOC_Error_ServerError&@CR&$serverresponse[2])
			Return
		Else
			;The error was non-critical. We will retry the upload.
			UploadFailed()
			MyLog("Server replied with a NON-critical error. Return code: " & $serverresponse[0] & " Error: " & $serverresponse[2], $PB_LOGLEVEL_ERROR)
			Return
		EndIf
	EndIf
EndFunc   ;==>UploadNext

Func UploadFailed()
	$FailedUploads = $FailedUploads + 1
	$WaitingToRetryUpload = 1
	$WaitingToUploadTimer = TimerInit()
	StatusNetIcon($PB_STATUSICON_NET_BROKEN)
	StatusNetText($LOC_StatusUploadFail, _NowTime(), $FailedUploads)
EndFunc

Func AbortUploads()
	If $Watching == 1 Then
		ToggleWatching()
	EndIf
	Dim $UploadQueue[1]
	$Uploading = 0
	StatusNetIcon($PB_STATUSICON_NET_INACTIVE)
EndFunc   ;==>AbortUploads

Func FormatPOSTVars(ByRef $data)
	Dim $i, $string

	For $i = 0 To UBound($data) - 1
		If $i <> 0 Then
			$string &= "&"
		EndIf

		$string = $string & $data[$i][0] & "=" & $data[$i][1]
	Next

	Return _HTTPEncodeString($string)
EndFunc   ;==>FormatPOSTVars

Func QueueUpload($data)
	MyLog("Queueing data to upload. Func: " & $data[0][1] & " Items in queue before this one: " & UBound($UploadQueue) - 1, $PB_LOGLEVEL_DEBUG)
	MyLog("Full POST string: "&FormatPOSTVars($data), $PB_LOGLEVEL_DEBUG)
	Dim $QueueLength

	$QueueLength = UBound($UploadQueue)
	ReDim $UploadQueue[$QueueLength + 1]
	$UploadQueue[$QueueLength] = $data

	$Uploading = 1
EndFunc   ;==>QueueUpload
#endregion

#region Init Functions
;**********************
; INIT FUNCTIONS
;**********************
Func Init()
	LoadINI()
	CheckExe()

	_HTTPSetUserAgent("CivStatsUploader", $UPLOADERVERSION)
	$TrayMenuItemExit = TrayCreateItem($LOC_TrayMenuExit)
	TrayItemSetOnEvent($TrayMenuItemExit, "Abort")
	TraySetOnEvent($TRAY_EVENT_PRIMARYDOUBLE, "ShowWindow")

	$Watching = 0
	$Uploading = 0
	$FailedUploads = 0

	If $iniNeverAskProfile = 0 Then
		ChooseProfile()
	EndIf

	While Not ActivateProfile($ActiveProfile)
		MsgBox(16 + 8192, $LOC_MainWindowTitle, FormatString($LOC_ProfileInUse, $ActiveProfile))
		ChooseProfile()
	WEnd

	InitLog()
	MainWindowCreate()
	MainLoop()
EndFunc   ;==>Init

Func InitLog()
	$LogFile = FileOpen($LogFileName, 2)
	MyLog( "Log file opened at " & _Now(), $PB_LOGLEVEL_ALWAYS)
	FileClose($LogFile)
EndFunc   ;==>InitLog

Func CheckExe()
	MyLog("CheckExe()", $PB_LOGLEVEL_DEBUG)
	If Not FileExists($iniPathToExe) Then
		$iniPathToExe = FileOpenDialog("Please Locate Pitboss.exe", "\", "Executable Files (*.exe)", 1, "Pitboss.exe")
		If @error Or $iniPathToExe = 1 Then
			ExitScript("User did not locate executable")
		EndIf
		SaveIniFile()
	EndIf
EndFunc   ;==>CheckExe

Func LoadINI()
	Dim $SectionNames, $Settings, $i, $ValidProfile, $BackupProfile

	If FileExists($OLDINIFILENAME) AND Not FileExists($INIFILENAME) Then
		FileMove(@ScriptDir & "\" & $OLDINIFILENAME,@ScriptDir & "\" & $INIFILENAME)
		MyLog("Renamed " & $OLDINIFILENAME & " to " & $INIFILENAME,$PB_LOGLEVEL_ERROR)
	EndIf

	; First load global ini settings
	$Settings = IniReadSection(@ScriptDir & "\" & $INIFILENAME, "global")
	If Not @error Then
		For $i = 1 To $Settings[0][0]
			SetIniVariable($Settings[$i][0], $Settings[$i][1])
		Next
	EndIf

	; Load the section names to see if there are multiple profiles
	$SectionNames = IniReadSectionNames(@ScriptDir & "\" & $INIFILENAME)
	If @error Or $SectionNames[0] < 2 Then
		; There are no profiles - create a default one
		$ActiveProfile = "default"
		SetIniDefaults()
		SaveIniFile()
	ElseIf $SectionNames[0] >= 3 Then
		; There are multiple profiles. We'll load the one marked as default in the global ini settings.
		$ActiveProfile = $iniDefaultProfile
	Else
		; There is only one profile. It should be set as the default profile.
		$ActiveProfile = $iniDefaultProfile
	EndIf

	; Now check to make sure the ActiveProfile actually exists. If it does not, we'll fall back
	; to one we know exists.
	$ValidProfile = 0
	$BackupProfile = ""
	$SectionNames = IniReadSectionNames(@ScriptDir & "\" & $INIFILENAME)
	For $i = 1 To $SectionNames[0]
		If $SectionNames[$i] <> "global" And $SectionNames[$i] = $ActiveProfile Then
			$ValidProfile = 1
		EndIf
		If $SectionNames[$i] <> "global" And $BackupProfile = "" Then
			$BackupProfile = $SectionNames[$i]
		EndIf
	Next
	If $ValidProfile = 0 Then
		$ActiveProfile = $BackupProfile
	EndIf

	; Activate the default profile!
	LoadProfileFromIni($ActiveProfile)
EndFunc   ;==>LoadINI
#endregion

#region Utility Functions
;**********************
; UTILITY FUNCTIONS
;**********************
Func MyLog($Line, $level = 1)
	Dim $filename
	; Log Levels:
	; 0 - No Logging
	; 1 - Errors only
	; 2 - Information and Errors
	; 3 - Full debug logging
	; 4 - Also output to console
	If $level <= $iniLogLevel Then
		If $ActiveProfile == "" Then
			$filename = "PitbossStats"
		Else
			$filename = $ActiveProfile
		EndIf

		$LogFileName = @ScriptDir & "\" & $filename & ".log"
		$LogFile = FileOpen($LogFileName, 1)
		If $Line == "" Then
			FileWriteLine($LogFile, "")
		Else
			FileWriteLine($LogFile, _Now() & " - " & $Line)
		EndIf
		FileClose($LogFile)

		If $iniLogLevel >= 4 Then
			ConsoleWrite(_Now() & " - " & $Line & @CRLF)
		EndIf
	EndIf
EndFunc   ;==>MyLog

Func FormatString($text, $repl1 = "", $repl2 = "", $repl3 = "", $repl4 = "")
	If $repl1 <> "" Then
		$text = StringReplace($text, "%1", $repl1)
	EndIf
	If $repl2 <> "" Then
		$text = StringReplace($text, "%2", $repl2)
	EndIf
	If $repl3 <> "" Then
		$text = StringReplace($text, "%3", $repl3)
	EndIf
	If $repl4 <> "" Then
		$text = StringReplace($text, "%4", $repl4)
	EndIf

	Return $text
EndFunc   ;==>FormatString

Func UpdateVarsFromProfilesGUI()
	MyLog("UpdateVarsFromProfilesGUI()", $PB_LOGLEVEL_DEBUG)

	$iniNeverAskProfile = BitAND(GUICtrlRead($CheckboxProfilesDontAsk), $GUI_CHECKED)

	SaveIniFile()
EndFunc   ;==>UpdateVarsFromProfilesGUI

Func UpdateVarsFromGUI()
	MyLog("UpdateVarsFromGUI()", $PB_LOGLEVEL_DEBUG)

	$iniGameName = GUICtrlRead($InputGameName)
	$iniGameID = GUICtrlRead($InputUserName)
	$iniGamePass = GUICtrlRead($InputPass)

	SaveIniFile()
EndFunc   ;==>UpdateVarsFromGUI

Func SetIniVariable($variable, $value)
	MyLog("SetIniVariable(" & $variable & "," & $value & ")", $PB_LOGLEVEL_DEBUG)
	$variable = "ini" & $variable
	If IsDeclared($variable) Then
		Assign($variable, $value, 4)
	EndIf
EndFunc   ;==>SetIniVariable

Func SetIniDefaults()
	MyLog("SetIniDefaults()", $PB_LOGLEVEL_DEBUG)
	$iniGameName = "Game Name"
	$iniGameID = ""
	$iniGamePass = ""
EndFunc   ;==>SetIniDefaults

Func ActivateProfile($profile)
	MyLog("ActivateProfile(" & $profile & ")", $PB_LOGLEVEL_DEBUG)

	If WinExists($HIDDENWINDOWTITLEPREFIX & $ActiveProfile) Then
		Return 0
	EndIf

	$ActiveProfile = $profile
	AutoItWinSetTitle($HIDDENWINDOWTITLEPREFIX & $profile)
	Return 1
EndFunc   ;==>ActivateProfile

Func LoadProfileFromIni($profile)
	Dim $Settings

	$ActiveProfile = $profile
	$Settings = IniReadSection(@ScriptDir & "\" & $INIFILENAME, $profile)
	For $i = 1 To $Settings[0][0]
		SetIniVariable($Settings[$i][0], $Settings[$i][1])
	Next
EndFunc   ;==>LoadProfileFromIni

Func NewProfile($profile)
	MyLog("NewProfile(" & $profile & ")", $PB_LOGLEVEL_DEBUG)

	$ActiveProfile = $profile
	SetIniDefaults()
	SaveIniFile()
EndFunc   ;==>NewProfile

Func DuplicateProfile($oldprofile, $newprofile)
	MyLog("DuplicateProfile(" & $oldprofile & "," & $newprofile & ")", $PB_LOGLEVEL_DEBUG)

	LoadProfileFromIni($oldprofile)
	$ActiveProfile = $newprofile
	SaveIniFile()
EndFunc   ;==>DuplicateProfile

Func RenameProfile($oldname, $newname)
	MyLog("DuplicateProfile(" & $oldname & "," & $newname & ")", $PB_LOGLEVEL_DEBUG)
	DuplicateProfile($oldname, $newname)
	DeleteProfile($oldname)
EndFunc   ;==>RenameProfile

Func DeleteProfile($profile)
	MyLog("DeleteProfile(" & $profile & ")", $PB_LOGLEVEL_DEBUG)
	IniDelete(@ScriptDir & "\" & $INIFILENAME, $profile)
EndFunc   ;==>DeleteProfile

Func SaveIniFile()
	MyLog("SaveIniFile()", $PB_LOGLEVEL_DEBUG)

	if ($iniDefaultProfile <> $fileDefaultProfile Or Not $fileInit) Then
		IniWrite(@ScriptDir & "\" & $INIFILENAME, "global", "DefaultProfile", $ActiveProfile)
		$fileDefaultProfile = $iniDefaultProfile
	EndIf
	if ($iniPathToExe <> $filePathToExe Or Not $fileInit) Then
		IniWrite(@ScriptDir & "\" & $INIFILENAME, "global", "PathToExe", $iniPathToExe)
		$filePathToExe = $iniPathToExe
	EndIf
	if ($iniLogLevel <> $fileLogLevel Or Not $fileInit) Then
		IniWrite(@ScriptDir & "\" & $INIFILENAME, "global", "LogLevel", $iniLogLevel)
		$fileLogLevel = $iniLogLevel
	EndIf
	if ($iniNeverAskProfile <> $fileNeverAskProfile Or Not $fileInit) Then
		IniWrite(@ScriptDir & "\" & $INIFILENAME, "global", "NeverAskProfile", $iniNeverAskProfile)
		$fileNeverAskProfile = $iniNeverAskProfile
	EndIf
	if ($iniCheckInterval <> $fileCheckInterval Or Not $fileInit) Then
		IniWrite(@ScriptDir & "\" & $INIFILENAME, "global", "CheckInterval", $iniCheckInterval)
		$fileCheckInterval = $iniCheckInterval
	EndIf

	IniWrite(@ScriptDir & "\" & $INIFILENAME, $ActiveProfile, "GameName", $iniGameName)
	IniWrite(@ScriptDir & "\" & $INIFILENAME, $ActiveProfile, "GameID", $iniGameID)
	IniWrite(@ScriptDir & "\" & $INIFILENAME, $ActiveProfile, "GamePass", $iniGamePass)



	$fileInit = 1
EndFunc   ;==>SaveIniFile

Func Abort()
	ExitScript("User Exited from Tray")
EndFunc   ;==>Abort

Func ExitScript($reason = "UNKNOWN")
	SaveIniFile()
	MyLog( "Script stopped at " & _Now() & " | Reason: " & $reason, $PB_LOGLEVEL_ALWAYS)
	MyLog("", $PB_LOGLEVEL_ALWAYS)
	Exit
EndFunc   ;==>ExitScript

#endregion

;***********************
; RUN THE MAIN FUNCTION
;***********************
Init()