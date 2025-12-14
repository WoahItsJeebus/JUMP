#Requires AutoHotkey >=2.0
#SingleInstance Force

CoordMode("Mouse", "Screen")
CoordMode("Menu", "Screen")
SetTitleMatchMode 2
DetectHiddenWindows(true)

global initializing := true
global version := "2.0.0"

global ProgressBarOnStartUp := RegRead("HKCU\Software\AFKeebus", "ProgressBarOnStartUp", true) ; debug setting
GetUpdate(ProgressBarOnStartUp)

; #######################

; Variables
; global SettingsExists := IniRead("Settings.ini", "System", "Exists", false)
global SettingsExists := RegRead("HKCU\Software\AFKeebus", "Exists", false)

createDefaultSettings()
createDefaultSettings(*) {
	global SettingsExists

	if not SettingsExists {
		RegWrite(true, "REG_DWORD", "HKCU\Software\AFKeebus", "Exists")
		RegWrite(false, "REG_DWORD", "HKCU\Software\AFKeebus", "AcceptedWarning")
		RegWrite(1, "REG_DWORD", "HKCU\Software\AFKeebus", "SoundMode")
		RegWrite(1, "REG_DWORD", "HKCU\Software\AFKeebus", "isActive")
		RegWrite(false, "REG_DWORD", "HKCU\Software\AFKeebus", "isInStartFolder")
		RegWrite(false, "REG_DWORD", "HKCU\Software\AFKeebus", "isUIHidden")
		RegWrite(15, "REG_DWORD", "HKCU\Software\AFKeebus", "Cooldown")
	}

	SettingsExists := RegRead("HKCU\Software\AFKeebus", "Exists", false)
}

AutoUpdate(*) {
	global autoUpdateDontAsk
	if autoUpdateDontAsk
		return toggleAutoUpdate(false)
	
	GetUpdate(false)
}

toggleAutoUpdate(doUpdate){
	if not doUpdate
		return SetTimer(AutoUpdate, 0)

	return SetTimer(AutoUpdate, 1000)
}

; toggleAutoUpdate(true)

global MinutesToWait := RegRead("HKCU\Software\AFKeebus", "Cooldown", 15)
global SecondsToWait := SecondsToWait := RegRead("HKCU\Software\AFKeebus", "SecondsToWait", MinutesToWait*60)
global minCooldown := 0
global lastUpdateTime := A_TickCount
global CurrentElapsedTime := 0
global playSounds := RegRead("HKCU\Software\AFKeebus", "SoundMode", 1)
global isInStartFolder := RegRead("HKCU\Software\AFKeebus", "isInStartFolder", false)

global isActive := RegRead("HKCU\Software\AFKeebus", "isActive", 1)
global isUIHidden := RegRead("HKCU\Software\AFKeebus", "isUIHidden", false)
global MainUI := ""
global ExtrasUI := ""
global FirstRun := True
global MainUI_Disabled := false

; MainUI Position Data
global MainUI_PosX := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosX", A_ScreenWidth / 2)
global MainUI_PosY := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosY", A_ScreenHeight / 2)

global UI_Width := "500"
global UI_Height := "300"
global Min_UI_Width := "500"
global Min_UI_Height := "300"

; Core UI Buttons
global EditButton := ""
global ExitButton := ""
global OpenMouseSettingsButton := ""
global WindowSettingsButton := ""
global ScriptSettingsButton := ""
global CoreToggleButton := ""
global SoundToggleButton := ""
global ReloadButton := ""
global Core_Status_Bar := ""
global Sound_Status_Bar := ""
global WaitProgress := ""
global WaitTimerLabel := ""
global NextCheckTime := ""
global ElapsedTimeLabel := ""
global GitHubLink := ""
global CreditsLink := ""
global EditCooldownButton := ""
global ResetCooldownButton := ""
global MainUI_Warning := ""
global EditorButton := ""
global ScriptDirButton := ""
global AddToBootupFolderButton := ""
global AlwaysOnTopButton := ""
global AlwaysOnTopActive := RegRead("HKCU\Software\AFKeebus", "AlwaysOnTop", false)

; Extra Menus
global PatchUI := ""
global WindowSettingsUI := ""
global ScriptSettingsUI := ""
global SettingsUI := ""
global MouseSpeed := RegRead("HKCU\Software\AFKeebus", "MouseSpeed", 0)
global MouseClickRateOffset := RegRead("HKCU\Software\AFKeebus", "ClickRateOffset", 0)
global MouseClickRadius := RegRead("HKCU\Software\AFKeebus", "ClickRadius", 0)
global doMouseLock := RegRead("HKCU\Software\AFKeebus", "doMouseLock", false)
global MouseClicks := RegRead("HKCU\Software\AFKeebus", "MouseClicks", 5)

; Extras Menu
global ShowingExtrasUI := false 
global warningRequested := false

; Light/Dark mode colors
global updateTheme := true

global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
global intWindowColor := (!blnLightMode and updateTheme) and "404040" or "EEEEEE"
global intControlColor := (!blnLightMode and updateTheme) and "606060" or "FFFFFF"
global intProgressBarColor := (!blnLightMode and updateTheme) and "757575" or "dddddd"
global ControlTextColor := (!blnLightMode and updateTheme) and "FFFFFF" or "000000"
global linkColor := (!blnLightMode and updateTheme) and "99c3ff" or "4787e7"
global currentTheme := blnLightMode
global lastTheme := currentTheme

global wasActiveWindow := false

global ControlResize := (Target, position, size) => ResizeMethod(Target, position, size)
global MoveControl := (Target, position, size) => MoveMethod(Target, position, size)

global autoUpdateDontAsk := false
global AcceptedWarning := RegRead("HKCU\Software\AFKeebus", "AcceptedWarning", false) and CreateGui() or createWarningUI()
global tempUpdateFile := ""

; ================= Screen Info =================== ;
global refreshRate := GetRefreshRate_Alt() or 60
; ================ Credits Colors ================= ;
global Credits_CurrentColor := GetRandomColor(200, 255)
global Credits_TargetColor := GetRandomColor(200, 255)
global Credits_ColorChangeRate := 5 ; (higher = faster)
; ================================================= ;

global clamp := (number, minimum, maximum) => Min(Max(number, minimum), maximum)


; A_TrayMenu.Add()  ; Creates a separator line.
DeleteTrayTabs(*) {
	TabNames := [
		"&Edit Script",
		"&Window Spy"
	]

	if TabNames.Length > 0
		for _,tab in TabNames
			A_TrayMenu.Delete(tab)
}
DeleteTrayTabs()

A_TrayMenu.Insert("&Reload Script", "Fix GUI", MenuHandler)  ; Creates a new menu item.
Persistent

MenuHandler(ItemName, ItemPos, MyMenu) {
	global MainUI_PosX
	global MainUI_PosY
	global isUIHidden

	local VDisplay_Width := SysGet(78) ; SM_CXVIRTUALSCREEN
	local VDisplay_Height := SysGet(79) ; SM_CYVIRTUALSCREEN

	RegWrite(VDisplay_Width / 2, "REG_DWORD", "HKCU\Software\AFKeebus", "MainUI_PosX")
	RegWrite(VDisplay_Height / 2, "REG_DWORD", "HKCU\Software\AFKeebus", "MainUI_PosY")

	MainUI_PosX := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosX", VDisplay_Width / 2)
	MainUI_PosY := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosY", VDisplay_Height / 2)

	if isUIHidden
		ToggleHideUI(!isUIHidden)
	
    CreateGui()
}

IsVersionNewer(localVersion, onlineVersion) {
	localParts := StrSplit(localVersion, ".")
	onlineParts := StrSplit(onlineVersion, ".")
	
	; Compare each version segment numerically
	Loop localParts.Length {
		localPart := localParts[A_Index]
		onlinePart := onlineParts[A_Index]
		
		; Treat missing parts as 0 (e.g., "1.2" vs "1.2.1")
		localPart := localPart != "" ? localPart : 0
		onlinePart := onlinePart != "" ? onlinePart : 0

		if (onlinePart > localPart)
			return "Outdated"
		else if (onlinePart < localPart)
			return "Other"
	}
	return "Updated" ; Versions are equal
}

/**
 * 
 * @param throw exception handler
 */
GetUpdate(showProgressBar?) {
	; CheckScriptExists(url) {
	; 	try {
	; 		; Create a COM object for an HTTP request.
	; 		http := ComObject("MSXML2.XMLHTTP")
	; 		; Use HEAD method to avoid downloading the full file.
	; 		http.Open("HEAD", url, false)
	; 		http.Send()
	; 		status := http.Status
	; 		; Return true if the status is 200 (OK), false otherwise.
	; 		return (status = 200)
	; 	} catch
	; 		return false
	; }
	URL_SCRIPT := "https://github.com/WoahItsJeebus/JACS/releases/latest/download/JACS.ahk"
	
	; if (CheckScriptExists(URL_SCRIPT))
	; 	MsgBox "Script exists!"
	; else
	; 	return SendNotification("Could not fetch updated script... Using built-in version")
	
    global tempUpdateFile := A_Temp "\temp_script.ahk"
    
    ; Step 1: Create a Progress GUI
    local progressGui := ""
	local onlineVersion := ""
	if showProgressBar
	{
		progressGui := Gui("-SysMenu")
		progressGui.Title := "Auto-Updater"
		
		statusText := progressGui.Add("Text", "x10 y20 w300 h40", "Checking for updates...")
		progressBar := progressGui.Add("Progress", "x10 y60 w300 h20", 0) ; Start at 0%
		progressGui.Show("w320 h100")
	}

	; ========================================= ;
	PromptErrorContinue(message?, Icon?, options?)
	{
		global autoUpdateDontAsk
		local Result := MsgBox((message and (message . " ") or "") . "Continue anyway?", Icon, "YesNo 4096" (options and " " . options))
		if Result = "Yes"
		{
			autoUpdateDontAsk := true
			SetTimer(AutoUpdate, 0)

			if progressGui
				progressGui.Destroy()
			return
		}
		
		return CloseApp()
	}

	updateProgressBar(newValue, newText) {
		if !showProgressBar
			return

		try {
			progressBar.Value := newValue
			statusText.Text := newText

			Sleep(newValue == 100 and 2000 or Random(250,750))
		}
	}
	
	PromptUpdate(message := "", Icon := "", options := "")
	{
		; global autoUpdateDontAsk
		
		SendNotification("Click here to install", "JACS Update Available")
		
		; local Result := MsgBox(message, Icon, "YesNo" options)
		; if Result = "Yes" {
		; 	updateProgressBar(90, "Updating to version " . onlineVersion)
		; 	autoUpdateDontAsk := true
			
		; 	if progressGui
		; 		progressGui.Destroy()
			
		; 	return updateScript(tempUpdateFile)
		; }
		; else
		; {
		; 	autoUpdateDontAsk := true
		; 	return FileDelete(tempUpdateFile)
		; }
	}

	; ========================================= ;

    ; Step 2: Update Progress for Each Step
	updateProgressBar(10, "Downloading update info...")

    try {
        Download(URL_SCRIPT, tempUpdateFile)
    } catch {
        if progressGui
			progressGui.Destroy()
        return PromptErrorContinue("Failed to download update file.", "Error", "IconX T30")
    }

	updateProgressBar(50, "Reading update version...")
	
    try {
        onlineScript := FileRead(tempUpdateFile)
        if RegExMatch(onlineScript, 'global version := "([^"]+)"', &match)
            onlineVersion := match[1]
        else
            (Error("Version not found in script"))
    } catch {
		if progressGui
			progressGui.Destroy()
		
		FileDelete(tempUpdateFile)
        return PromptErrorContinue("Failed to read version information from the update file.", "Error", "IconX T30")
    }

	updateProgressBar(75, "Comparing versions...")

    if IsVersionNewer(version, onlineVersion) == "Outdated" {
        try {
            PromptUpdate("A new version of the script has been found! Would you like to download it?", "Notice", "Iconi T60")
            
			if progressGui
				progressGui.Destroy()
        }
		catch {
            if progressGui
				progressGui.Destroy()
			
			FileDelete(tempUpdateFile)
            return PromptErrorContinue("Failed to update the script file.", "Error", "IconX T30")
        }
    }
	else if IsVersionNewer(version, onlineVersion) == "Updated" {
        updateProgressBar(100, "Script is up-to-date! Happy farming!")
        FileDelete(tempUpdateFile)
	}
	else {
        updateProgressBar(100, "Version assumed to be beta or edited. Continuing without updating...")
		FileDelete(tempUpdateFile)
    }

	; updateProgressBar(100, "Update successful! Restarting...")
	RollThankYou()

    ; Step 3: Close the Progress GUI
	if progressGui
    	progressGui.Destroy()
}

UpdateScript(targetFile := tempUpdateFile) {
	FileMove(targetFile, A_ScriptFullPath, 1) ; Overwrite current script
	Reload
}

; Helper function to evaluate expressions in concatenated strings
Eval(expr) {
    return %expr%
}

; ================================================= ;

createWarningUI(requested := false) {
	global ExtrasUI
	if ExtrasUI {
		ExtrasUI.Destroy()
		ExtrasUI := ""
	}

	local accepted := RegRead("HKCU\Software\AFKeebus", "AcceptedWarning", false)
	if accepted and not requested {
		if MainUI_Warning
			MainUI_Warning.Destroy()
			MainUI_Warning := ""
		if not MainUI
			return CreateGui()
		return
	}

	; Global Variables
	global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")

	global AlwaysOnTopActive
	local AOTStatus := AlwaysOnTopActive == true and "+AlwaysOnTop" or "-AlwaysOnTop"
	local AOT_Text := (AlwaysOnTopActive == true and "On") or "Off"

	global ExtrasUI
	global MainUI_Warning := Gui(AOTStatus)

	MainUI_Warning.BackColor := intWindowColor

	; Local Variables
	local UI_Width_Warning := "1200"
	local UI_Height_Warning := "100"

	; Colors
	global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
	global intWindowColor := (!blnLightMode and updateTheme) and "404040" or "EEEEEE"
	global intControlColor := (!blnLightMode and updateTheme) and "606060" or "FFFFFF"
	global intProgressBarColor := (!blnLightMode and updateTheme) and "757575" or "dddddd"
	global ControlTextColor := (!blnLightMode and updateTheme) and "FFFFFF" or "000000"
	global linkColor := (!blnLightMode and updateTheme) and "99c3ff" or "4787e7"

	; Controls
	local warning_Text_Header := MainUI_Warning.Add("Text","h30 w" UI_Width_Warning/2-MainUI_Warning.MarginX*2, "WARNING")
	warning_Text_Header.SetFont("s24 w1000", "Consolas")
	warning_Text_Header.Opt("Center cff4840")
	
    ; ##############################################
    ; Body 1
	local warning_Text_Body1 := MainUI_Warning.Add("Link", "h80 w315", 'This script is provided by')
	warning_Text_Body1.SetFont("s12 w300", "Arial")
	warning_Text_Body1.Opt("c" ControlTextColor)
	
	local JEEBUS_LINK1 := MainUI_Warning.Add("Link", "x+-140 h20 w125 c" linkColor, '<a href="https://www.roblox.com/users/3817884/profile">@WoahItsJeebus</a>')
	JEEBUS_LINK1.SetFont("s12 w300", "Arial")
	LinkUseDefaultColor(JEEBUS_LINK1)

	local warning_Text_Body1_5 := MainUI_Warning.Add("Link", "x+0 h20 w300", 'and is intended solely for the purpose of')
	warning_Text_Body1_5.SetFont("s12 w300", "Arial")
	warning_Text_Body1_5.Opt("c" ControlTextColor)

    ; ###############################################
    ; Body 2
	local warning_Text_Body2 := MainUI_Warning.Add("Link", "y+0 x" MainUI_Warning.MarginX . " h80 w" UI_Width_Warning/2-MainUI_Warning.MarginX*2, 'maintaining an active gaming session while the user can do other tasks simultaneously. This is achieved by periodically activating the first found process matching a specific name and clicking the center of the window.')
	warning_Text_Body2.SetFont("s12 w300", "Arial")
	warning_Text_Body2.Opt("c" ControlTextColor)

	local warning_Text_Body3 := MainUI_Warning.Add("Text", "h60 w" UI_Width_Warning/2-MainUI_Warning.MarginX*2, 'While some games do not typically take action on the use of autoclickers, the rules of some games may prohibit the use of such tools. Use of this script is at your own risk.')
	warning_Text_Body3.SetFont("s12 w500", "Arial")
	warning_Text_Body3.Opt("c" ControlTextColor)

	local SeparationLine := MainUI_Warning.Add("Text", "0x7 h1 w" UI_Width_Warning/2) ; Separation Space
	SeparationLine.BackColor := "0x8"
	
	local important_Text_Body_Part1 := MainUI_Warning.Add("Text", "h20 w" UI_Width_Warning/2-MainUI_Warning.MarginX*2, '- [Roblox Users] Modifying this script in such a way that does not abide by the Roblox')
	important_Text_Body_Part1.SetFont("s12 w600", "Arial")
	important_Text_Body_Part1.Opt("c" ControlTextColor)

	local TOS_Link := MainUI_Warning.Add("Link", "y+-1 h20 w295 c" linkColor, '<a href="https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use">Terms of Service</a>')
	TOS_Link.SetFont("s12 w600", "Arial")
	LinkUseDefaultColor(TOS_Link)

	local important_Text_Body_Part2 := MainUI_Warning.Add("Text", "x+-160 h20 w" UI_Width_Warning/2.75-MainUI_Warning.MarginX, 'can lead to actions taken by the Roblox Corporation')
	important_Text_Body_Part2.SetFont("s12 w600", "Arial")
	important_Text_Body_Part2.Opt("c" ControlTextColor)
	
	local important_Text_Body_Part2_5 := MainUI_Warning.Add("Text", "y+-1 x" MainUI_Warning.MarginX . " h20 w" UI_Width_Warning/2-MainUI_Warning.MarginX, 'including but not limited to account suspension or banning.')
	important_Text_Body_Part2_5.SetFont("s12 w600", "Arial")
	important_Text_Body_Part2_5.Opt("c" ControlTextColor)
	
	local JEEBUS_LINK2 := MainUI_Warning.Add("Link", "h20 w295 c" linkColor, '<a href="https://www.roblox.com/users/3817884/profile">@WoahItsJeebus</a>')
	JEEBUS_LINK2.SetFont("s12 w600", "Arial")
	LinkUseDefaultColor(JEEBUS_LINK2)
	
	local important_Text_Body_Part3 := MainUI_Warning.Add("Text", "x+-155 h20 w" UI_Width_Warning/2.75-MainUI_Warning.MarginX, "is not responsible for any misuse of this script or any")
	important_Text_Body_Part3.SetFont("s12 w600", "Arial")
	important_Text_Body_Part3.Opt("c" ControlTextColor)

	local important_Text_Body_Part3_5 := MainUI_Warning.Add("Text", "y+-1 x" MainUI_Warning.MarginX . " h20 w" UI_Width_Warning/2-MainUI_Warning.MarginX, 'consequences arising from such misuse.')
	important_Text_Body_Part3_5.SetFont("s12 w600", "Arial")
	important_Text_Body_Part3_5.Opt("c" ControlTextColor)

	local important_Text_Body2 := MainUI_Warning.Add("Text", "h40 w" UI_Width_Warning/2-MainUI_Warning.MarginX*2, '`nBy proceeding, you acknowledge and agree to the above.')
	important_Text_Body2.SetFont("s12 w600", "Arial")
	important_Text_Body2.Opt("Center c" ControlTextColor)
	
	local ok_Button_Warning := MainUI_Warning.Add("Button", "h40 w" UI_Width_Warning/8-MainUI_Warning.MarginX, "I AGREE")
	ok_Button_Warning.Move(UI_Width_Warning/8)
	ok_Button_Warning.SetFont("s14 w600", "Consolas")
	ok_Button_Warning.Opt("c" ControlTextColor . " Background" intWindowColor)
	
	local no_Button_Warning := MainUI_Warning.Add("Button", "x+m h40 w" UI_Width_Warning/8-MainUI_Warning.MarginX, "DECLINE")
	no_Button_Warning.Move(UI_Width_Warning/4)
	no_Button_Warning.SetFont("s14 w600", "Consolas")
	no_Button_Warning.Opt("c" ControlTextColor . " Background" intWindowColor)
	
	ok_Button_Warning.OnEvent("Click", clickOK)
	no_Button_Warning.OnEvent("Click", clickNo)
	
	MainUI_Warning.OnEvent("Close", (*) => (
		MainUI_Warning := ""
	))

	MainUI_Warning.Title := "Jeebus' Auto-Clicker - Warning"
	
	CloseWarning(clickedYes){
		if MainUI and requested {
			MainUI_Warning.Destroy()
			MainUI_Warning := ""
		}

		if ExtrasUI
			ExtrasUI.Opt("-Disabled")

		if not accepted and clickedYes {
			RegWrite(true, "REG_DWORD", "HKCU\Software\AFKeebus", "AcceptedWarning")
			accepted := RegRead("HKCU\Software\AFKeebus", "AcceptedWarning", false)
		}
		
		if not MainUI and accepted and clickedYes
			return CreateGui()
		else
			return CloseApp()
	}
	
	clickOK(uiObj*){
		CloseWarning(true)
	}

	clickNO(uiObj*){
		CloseWarning(false)
	}

	; Show UI
	MainUI_Warning.Show("AutoSize Center h500")
}

; ================================================= ;

CreateGui(*) {
	global version
	global UI_Width := "500"
	global UI_Height := "300"
	global Min_UI_Width := "500"
	global Min_UI_Height := "300"
	
	global MainUI_PosX
	global MainUI_PosY

	global playSounds
	global isActive
	global isUIHidden

	global MainUI
	global MainUI_Warning
	global CoreToggleButton
	global SoundToggleButton
	global EditCooldownButton
	global AlwaysOnTopButton
	global AlwaysOnTopActive
	global AddToBootupFolderButton
	global ScriptSettingsButton
	global WindowSettingsButton
	global OpenMouseSettingsButton

	global MainUI_PosX
	global MainUI_PosY

	global WaitProgress
	global WaitTimerLabel
	global ElapsedTimeLabel
	global MinutesToWait
	global ResetCooldownButton

	global CreditsLink
	global OpenExtrasLabel

	global MoveControl
	global ControlResize

	global initializing
	global refreshRate

	; Colors
	global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
	global intWindowColor := (!blnLightMode and updateTheme) and "404040" or "EEEEEE"
	global intControlColor := (!blnLightMode and updateTheme) and "606060" or "FFFFFF"
	global intProgressBarColor := (!blnLightMode and updateTheme) and "757575" or "dddddd"
	global ControlTextColor := (!blnLightMode and updateTheme) and "FFFFFF" or "000000"
	global linkColor := (!blnLightMode and updateTheme) and "99c3ff" or "4787e7"

	global IntValue := Integer(0)
	
	local AOTStatus := AlwaysOnTopActive == true and "+AlwaysOnTop" or "-AlwaysOnTop"
	local AOT_Text := (AlwaysOnTopActive == true and "On") or "Off"

	; Destroy old UI object
	if MainUI {
		MainUI.Destroy()
		MainUI := ""
	}
	
	if MainUI_Warning
		MainUI_Warning.Destroy()

	; Create new UI
	global MainUI := Gui(AOTStatus . " +OwnDialogs") ; Create UI window
	MainUI.BackColor := intWindowColor
	MainUI.OnEvent("Close", CloseApp)
	MainUI.Title := "Jeebus' Auto-Clicker"
	MainUI.SetFont("s14 w500", "Courier New")
	
	local UI_Margin_Width := UI_Width-MainUI.MarginX
	local UI_Margin_Height := UI_Height-MainUI.MarginY
	
	local Header := MainUI.Add("Text", "Section Center cff4840 h100 w" UI_Margin_Width,"`nJeebus' Auto-Clicker — V" version)
	Header.SetFont("s22 w600", "Ink Free")
	
	; ########################
	; 		  Buttons
	; ########################
	; local activeText_Core := isActive and "Enabled" or "Disabled"
	global activeText_Core := (isActive == 3 and "Enabled") or (isActive == 2 and "Waiting...") or "Disabled"
	CoreToggleButton := MainUI.Add("Button", "xs h40 w" UI_Margin_Width/2, "Auto-Clicker: " activeText_Core)
	CoreToggleButton.OnEvent("Click", ToggleCore)
	CoreToggleButton.Opt("Background" intWindowColor)
	CoreToggleButton.Move((UI_Width-(UI_Margin_Width / 1.333)))
	CoreToggleButton.SetFont("s12 w500", "Consolas")

	; ##############################
	
	; Calculate initial control width based on GUI width and margins
	InitialWidth := UI_Width - (2 * UI_Margin_Width)
	;X := 0, Y := 0, UI_Width := 0, UI_Height := 0
	
	; Get the client area dimensions
	NewButtonWidth := (UI_Width - (2 * UI_Margin_Width)) / 3
	
	local pixelSpacing := 5

	; ###############################
	
	SeparationLine := MainUI.Add("Text", "xs 0x7 h1 w" UI_Margin_Width) ; Separation Space
	SeparationLine.BackColor := "0x8"
	
	; Progress Bar
	WaitTimerLabel := MainUI.Add("Text", "xs Section Center 0x300 0xC00 h28 w" UI_Margin_Width, "0%")
	WaitProgress := MainUI.Add("Progress", "xs Section Center h50 w" UI_Margin_Width)
	ElapsedTimeLabel := MainUI.Add("Text", "xs Section Center 0x300 0xC00 h28 w" UI_Margin_Width, "00:00 / 0 min")
	ElapsedTimeLabel.SetFont("s18 w500", "Consolas")
	WaitTimerLabel.SetFont("s18 w500", "Consolas")
	
	WaitTimerLabel.Opt("Background" intWindowColor . " c" ControlTextColor)
	ElapsedTimeLabel.Opt("Background" intWindowColor . " c" ControlTextColor)
	WaitProgress.Opt("Background" intProgressBarColor)

	; Reset Cooldown
	ResetCooldownButton := MainUI.Add("Button", "xm+182 h30 w" UI_Margin_Width/4, "Reset")
	ResetCooldownButton.OnEvent("Click", ResetCooldown)
	ResetCooldownButton.SetFont("s12 w500", "Consolas")
	ResetCooldownButton.Opt("Background" intWindowColor)

	; Window Settings
	WindowSettingsButton := MainUI.Add("Button", "xs h30 w" UI_Margin_Width/3, "Window Settings")
	WindowSettingsButton.OnEvent("Click", CreateWindowSettingsGUI)
	WindowSettingsButton.SetFont("s12 w500", "Consolas")
	WindowSettingsButton.Opt("Background" intWindowColor)
	
	; Mouse Settings
	OpenMouseSettingsButton := MainUI.Add("Button", "x+1 h30 w" UI_Margin_Width/3, "Clicker Settings")
	OpenMouseSettingsButton.OnEvent("Click", CreateClickerSettingsGUI)
	OpenMouseSettingsButton.SetFont("s12 w500", "Consolas")
	OpenMouseSettingsButton.Opt("Background" intWindowColor)
	
	; Script Settings
	ScriptSettingsButton := MainUI.Add("Button", "x+1 h30 w" UI_Margin_Width/3, "Script Settings")
	ScriptSettingsButton.OnEvent("Click", CreateScriptSettingsGUI)
	ScriptSettingsButton.SetFont("s12 w500", "Consolas")
	ScriptSettingsButton.Opt("Background" intWindowColor)
	
	; Credits
	CreditsLink := MainUI.Add("Link", "xm c" linkColor . " Section Left h20 w" UI_Margin_Width/2, 'Created by <a href="https://www.roblox.com/users/3817884/profile">@WoahItsJeebus</a>')
	CreditsLink.SetFont("s12 w700", "Ink Free")
	CreditsLink.Opt("c" linkColor)
	LinkUseDefaultColor(CreditsLink)

	; Version
	OpenExtrasLabel := MainUI.Add("Button", "x+120 Section Center 0x300 0xC00 h30 w" UI_Margin_Width/4, "Extras")
	OpenExtrasLabel.SetFont("s12 w500", "Consolas")
	OpenExtrasLabel.Opt("Background" intWindowColor)
	OpenExtrasLabel.OnEvent("Click", CreateExtrasGUI)

	; LinkUseDefaultColor(VersionHyperlink)
	
	; Update ElapsedTimeLabel with the formatted time and total wait time in minutes
    UpdateTimerLabel()

	; ###################################################################### ;
	; #################### UI Formatting and Visibility #################### ;
	; ###################################################################### ;
	
	; ToggleHideUI(false)
	updateUIVisibility()
	ClampMainUIPos()

	; ####################################
	
	; CreateExtrasGUI()

	; Indicate UI was fully created
	if playSounds == 1
		Loop 2
			SoundBeep(300, 200)
	
	if isActive > 1
		ToggleCore(,isActive)

	local loopFunctions := Map(
		"CheckDeviceTheme", Map(
			"Function", CheckDeviceTheme.Bind(),
			"Interval", 50,
			"Disabled", false
		),
		"SaveMainUIPosition", Map(
			"Function", SaveMainUIPosition.Bind(),
			"Interval", 50,
			"Disabled", true
		),
		"CheckOpenMenus", Map(
			"Function", CheckOpenMenus.Bind(),
			"Interval", 50,
			"Disabled", false
		),
		"ClampMainUIPosition", Map(
			"Function", ClampMainUIPos.Bind(),
			"Interval", 50,
			"Disabled", true
		),
		"ColorizeCredits", Map(
			"Function", ColorizeCredits.Bind(CreditsLink),
			"Interval", 50,
			"Disabled", true
		)
	)
	Sleep(500)

	; Run loop functions
	for FuncName, Data in loopFunctions
		if not Data["Disabled"]
        	SetTimer(Data["Function"], Data["Interval"])

	refreshRate := GetRefreshRate_Alt()
	; debugNotif(refreshRate = 0 ? "Failed to retrieve refresh rate" : "Refresh Rate: " refreshRate " Hz",,,5)

	initializing := false
}

GetRefreshRate_Alt() {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr") ; Get Device Context Handle
    RF := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 116) ; VREFRESH index = 116
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc) ; ReleaseDC for cleanup
    return RF
}

ColorizeCredits(creditsLinkCtrl) { 
    if not creditsLinkCtrl
        return

    global Credits_CurrentColor
    global Credits_TargetColor
    global Credits_ColorChangeRate

    ; Store old color before interpolation to prevent unnecessary updates
    local oldColor := Credits_CurrentColor.Clone()

    ; Interpolate each RGB channel
    Credits_CurrentColor.R := Lerp(Credits_CurrentColor.R, Credits_TargetColor.R, Credits_ColorChangeRate)
    Credits_CurrentColor.G := Lerp(Credits_CurrentColor.G, Credits_TargetColor.G, Credits_ColorChangeRate)
    Credits_CurrentColor.B := Lerp(Credits_CurrentColor.B, Credits_TargetColor.B, Credits_ColorChangeRate)

    ; Only update if color changed significantly
    if (Round(oldColor.R) != Round(Credits_CurrentColor.R) || Round(oldColor.G) != Round(Credits_CurrentColor.G) || Round(oldColor.B) != Round(Credits_CurrentColor.B)) {
        newColor := Format("c{:02}{:02}{:02}", Round(Credits_CurrentColor.R), Round(Credits_CurrentColor.G), Round(Credits_CurrentColor.B))
        creditsLinkCtrl.Opt(newColor) ; Correct AHK v2 way to update the control
    }

    ; Check if transition is complete, then set a new target color
    if (Round(Credits_CurrentColor.R) = Credits_TargetColor.R && Round(Credits_CurrentColor.G) = Credits_TargetColor.G && Round(Credits_CurrentColor.B) = Credits_TargetColor.B) {
        Credits_TargetColor := {R: Random(10, 99), G: Random(10, 99), B: Random(10, 99)}
    }
}

ClampMainUIPos(*) {
	global MainUI
	global isUIHidden
	global MainUI_PosX
	global MainUI_PosY
	
	local VDisplay_Width := SysGet(78) ; SM_CXVIRTUALSCREEN
	local VDisplay_Height := SysGet(79) ; SM_CYVIRTUALSCREEN
	
	WinGetPos(,, &W, &H, MainUI.Title)
	local X := MainUI_PosX + (W / 2)
	local Y := MainUI_PosY + (H / 2)
	local winState := WinGetMinMax(MainUI.Title) ; -1 = Minimized | 0 = "Neither" (I assume floating) | 1 = Maximized
	if winState == -1
		return

	if X > VDisplay_Width or X < -VDisplay_Width {
		RegWrite(VDisplay_Width / 2, "REG_DWORD", "HKCU\Software\AFKeebus", "MainUI_PosX")
		MainUI_PosX := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosX", VDisplay_Width / 2)
		
		if MainUI and not isUIHidden and winState != -1
			MainUI.Show("X" . MainUI_PosX . " Y" . MainUI_PosY . " AutoSize")
	}

	if Y > VDisplay_Height or Y < (-VDisplay_Height*2) {
		RegWrite(VDisplay_Height / 2, "REG_DWORD", "HKCU\Software\AFKeebus", "MainUI_PosY")
		MainUI_PosY := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosY", VDisplay_Height / 2)

		if MainUI and winState != -1
			MainUI.Show("X" . MainUI_PosX . " Y" . MainUI_PosY . " AutoSize")
	}
}

CheckOpenMenus(*) {
	global MainUI
	global ExtrasUI
	global SettingsUI
	global ScriptSettingsUI
	global WindowSettingsUI
	global MainUI_Disabled
	global MainUI_Warning
	
	if not MainUI or (MainUI and not ExtrasUI and not SettingsUI and not ScriptSettingsUI and not WindowSettingsUI and not MainUI_Warning) {
		if MainUI_Disabled {
			MainUI.Opt("-Disabled")
			MainUI_Disabled := false
		}
		
		return
	}
	else if not MainUI_Disabled {
		MainUI.Opt("+Disabled")
		MainUI_Disabled := true
	}
}

; Create blank popout window
CreateWindowSettingsGUI(*)
{
	; UI Settings
	local PixelOffset := 10
	local Popout_Width := 400
	local Popout_Height := 600
	local labelOffset := 50
	local sliderOffset := 2.5

	; Labels, Sliders, Buttons

	; Global Save Data
	global WindowSettingsUI
	global playSounds
	global AlwaysOnTopActive
	global ProgressBarOnStartUp

	; Global Controls
	global SoundToggleButton
	global AlwaysOnTopButton
	global MainUI
	global MainUI_PosX
	global MainUI_PosY

	; Local Controls
	local PB_Button := ""

	local AOTStatus := AlwaysOnTopActive == true and "+AlwaysOnTop" or "-AlwaysOnTop"
	local AOT_Text := (AlwaysOnTopActive == true and "On") or "Off"
	local PB_Text := (ProgressBarOnStartUp == true and "On") or "Off"
	
	; Colors
	global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
	global intWindowColor := (!blnLightMode and updateTheme) and "404040" or "EEEEEE"
	global intControlColor := (!blnLightMode and updateTheme) and "606060" or "FFFFFF"
	global ControlTextColor := (!blnLightMode and updateTheme) and "FFFFFF" or "000000"

	CloseSettingsUI(*)
	{
		if WindowSettingsUI {
			WindowSettingsUI.Destroy()
			WindowSettingsUI := ""
		}

		SetTimer(mouseHoverDescription,0)
	}

	; If settingsUI is open, close it
	if WindowSettingsUI
		return CloseSettingsUI()

	TogglePB(*) {
		local newState := !ProgressBarOnStartUp
		
		RegWrite(newState, "REG_DWORD", "HKCU\Software\AFKeebus", "ProgressBarOnStartUp")
		ProgressBarOnStartUp := RegRead("HKCU\Software\AFKeebus", "ProgressBarOnStartUp", true)
		
		PB_Text := (ProgressBarOnStartUp == true and "On") or "Off"
		PB_Button.Text := "Show Update Window On Startup: " . PB_Text
	}

	; Create GUI Window
	WindowSettingsUI := Gui(AOTStatus)
	WindowSettingsUI.Opt("+Owner" . MainUI.Hwnd)
	WindowSettingsUI.BackColor := intWindowColor
	WindowSettingsUI.OnEvent("Close", CloseSettingsUI)
	WindowSettingsUI.Title := "Window Settings"
	
	if AlwaysOnTopButton
		AlwaysOnTopButton := ""

	AlwaysOnTopButton := WindowSettingsUI.Add("Button", "Section Center vAlwaysOnTopButton h30 w" Popout_Width/1.05, "Always-On-Top: " AOT_Text)
	AlwaysOnTopButton.OnEvent("Click", ToggleAOT)
	AlwaysOnTopButton.Opt("Background" intWindowColor)
	AlwaysOnTopButton.SetFont("s12 w500", "Consolas")

	local activeText_Sound := (playSounds == 1 and "All") or (playSounds == 2 and "Less") or (playSounds == 3 and "None")
	
	if SoundToggleButton
		SoundToggleButton := ""

	SoundToggleButton := WindowSettingsUI.Add("Button", "xm Section Center vSoundToggleButton h30 w" Popout_Width/1.05, "Sounds: " activeText_Sound)
	SoundToggleButton.OnEvent("Click", ToggleSound)
	SoundToggleButton.Opt("Background" intWindowColor)
	SoundToggleButton.SetFont("s12 w500", "Consolas")

	if PB_Button
		PB_Button := ""

	PB_Button := WindowSettingsUI.Add("Button", "xm Section Center vPB_Button h30 w" Popout_Width/1.05, "Show Update Window On Startup: " . PB_Text)
	PB_Button.OnEvent("Click", TogglePB)
	PB_Button.Opt("Background" intWindowColor)
	PB_Button.SetFont("s12 w500", "Consolas")

	CloseWindowSettings(*) {
	}

	; Slider Description Box
	local testBoxColor := "666666"
	DescriptionBox := WindowSettingsUI.Add("Text", "xm Section Left vDescriptionBox h" . Popout_Height/2 . " w" Popout_Width/1.05)
	DescriptionBox.SetFont("s10 w700", "Consolas")
	DescriptionBox.Opt("+Border Background" (testBoxColor or intWindowColor) . " c" ControlTextColor)
	
	; Hover Descriptions
	local Descriptions := Map(
		; Sliders
		"AlwaysOnTopButton", "This button controls whether the script's UI stays as the top-most window on the screen.",
		"SoundToggleButton", "This button controls the sounds that play when the auto-clicker sequence triggers, when no Roblox window is found, etc.`n`nAll: All sounds play. This includes a 3 second countdown via audible beeps, a higher pitched trigger tone indicating the sequence has begun after the aforementioned countdown, and an audible indication the script launched.`n`nLess: Only the single higher pitched indicator and indicator on script launch are played.`n`nNone: No indication sounds are played.",
		"PB_Button", "This button controls seeing the update progress window whenever the script launches. Turning this setting 'Off' typically yields faster load times."
	)
	
	updateDescriptionBox(newText := "") {
		DescriptionBox.Text := newText
	}

	mouseHoverDescription(*)
	{
		if not WindowSettingsUI or not DescriptionBox
			return SetTimer(mouseHoverDescription,0)

		MouseGetPos(&MouseX,&MouseY,&HoverWindow,&HoverControl)
		local targetControl := ""

		if HoverControl
		{
			try targetControl := WindowSettingsUI.__Item[HoverControl]
			if WindowSettingsUI and DescriptionBox and HoverControl and targetControl and Descriptions.Has(targetControl.Name) and DescriptionBox.Text != Descriptions[targetControl.Name] {
				try updateDescriptionBox(Descriptions[targetControl.Name])
			}
			else if WindowSettingsUI and DescriptionBox and not HoverControl or not targetControl or not Descriptions.Has(targetControl.Name) {
				try updateDescriptionBox()
			}
		}
	}
	WindowSettingsUI.OnEvent("Close", CloseWindowSettings)

	; Calculate center position
	WinGetClientPos(&MainX, &MainY, &MainW, &MainH, MainUI.Title)
	CenterX := MainX + (MainW / 2) - (Popout_Width / 2)
	CenterY := MainY + (MainH / 2) - (Popout_Height / 2)

	WindowSettingsUI.Show("AutoSize X" . CenterX . " Y" . CenterY . " w" . Popout_Width . "h" . Popout_Height)

	SetTimer(mouseHoverDescription,50)
}

; Create blank popout window
CreateClickerSettingsGUI(*)
{
	; UI Settings
	local PixelOffset := 10
	local Popout_Width := 400
	local Popout_Height := 600
	local labelOffset := 50
	local sliderOffset := 2.5

	; Labels, Sliders, Buttons
	local MouseSpeedLabel := ""
	local MouseSpeedSlider := ""

	local ClickRateOffsetLabel := ""
	local ClickRateSlider := ""

	local ClickRadiusLabel := ""
	local ClickRadiusSlider := ""
	
	local MouseClicksLabel := ""
	local MouseClicksSlider := ""
	local CooldownLabel := ""
	local CooldownSlider := ""
	global EditCooldownButton
	local ToggleMouseLock := ""

	; Global Save Data
	global SettingsUI
	global MouseSpeed
	global MouseClickRateOffset
	global MouseClickRadius
	global doMouseLock
	global MouseClicks
	global MainUI
	global MainUI_PosX
	global MainUI_PosY
	global MinutesToWait
	global SecondsToWait

	; Clamps
	local maxRadius := 200
	local maxRate := 1000
	local maxSpeed := 1000
	local maxClicks := 10
	local maxCooldown := 15*60

	; Colors
	global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
	global intWindowColor := (!blnLightMode and updateTheme) and "404040" or "EEEEEE"
	global intControlColor := (!blnLightMode and updateTheme) and "606060" or "FFFFFF"
	global ControlTextColor := (!blnLightMode and updateTheme) and "FFFFFF" or "000000"

	CloseSettingsUI(*)
	{
		if SettingsUI
		{
			SettingsUI.Destroy()
			SettingsUI := ""
		}

		SetTimer(mouseHoverDescription,0)
	}

	; If settingsUI is open, close it
	if SettingsUI
		return CloseSettingsUI()
	
	; Slider update function
	updateSliderValues(ctrlObj, info) {
		; MsgBox(ctrlObj.Name . ": " . info)
		if ctrlObj.Name == "MouseSpeed" {
			RegWrite(ctrlObj.Value, "REG_DWORD", "HKCU\Software\AFKeebus", "MouseSpeed")
			MouseSpeed := RegRead("HKCU\Software\AFKeebus", "MouseSpeed", 0)
			
			if MouseSpeedLabel
				MouseSpeedLabel.Text := "Mouse Speed: " . (ctrlObj.Value >= 1000 ? Format("{:.2f} s", ctrlObj.Value / 1000) : ctrlObj.Value . " ms")
		}

		if ctrlObj.Name == "ClickRateOffset" {
			RegWrite(ctrlObj.Value, "REG_DWORD", "HKCU\Software\AFKeebus", "ClickRateOffset")
			MouseClickRateOffset := RegRead("HKCU\Software\AFKeebus", "ClickRateOffset", 0)
			
			if ClickRateOffsetLabel
				ClickRateOffsetLabel.Text := "Click Rate Offset: " . (ctrlObj.Value >= 1000 ? Format("{:.2f} s", ctrlObj.Value / 1000) : ctrlObj.Value . " ms")
		}

		if ctrlObj.Name == "ClickRadius" {
			RegWrite(ctrlObj.Value, "REG_DWORD", "HKCU\Software\AFKeebus", "ClickRadius")
			MouseClickRateOffset := RegRead("HKCU\Software\AFKeebus", "ClickRadius", 0)
			
			if ClickRadiusLabel
				ClickRadiusLabel.Text := "Click Radius: " . ctrlObj.Value . " pixels"
		}

		if ctrlObj.Name == "MouseClicks" {
			RegWrite(ctrlObj.Value, "REG_DWORD", "HKCU\Software\AFKeebus", "MouseClicks")
			MouseClicks := RegRead("HKCU\Software\AFKeebus", "MouseClicks", 5)
			
			if MouseClicksLabel
				MouseClicksLabel.Text := "Click Amount: " . ctrlObj.Value . " clicks"
		}

		if ctrlObj.Name == "CooldownSlider" {
			RegWrite(ctrlObj.Value/60, "REG_DWORD", "HKCU\Software\AFKeebus", "Cooldown")
			MinutesToWait := RegRead("HKCU\Software\AFKeebus", "Cooldown", 15)
			SecondsToWait := MinutesToWait/60

			if CooldownLabel
				CooldownLabel.Text := "Cooldown: " . (SecondsToWait < 60) ? SecondsToWait " seconds" : Format("{:02}:{:02}", Floor(SecondsToWait / 60), Mod(SecondsToWait, 60))
		}
	}

	; Toggle Function
	updateToggle(ctrlObj, info) {
		if ctrlObj.Name == "ToggleMouseLock" {
			RegWrite(not doMouseLock, "REG_DWORD", "HKCU\Software\AFKeebus", "doMouseLock")
			doMouseLock := RegRead("HKCU\Software\AFKeebus", "doMouseLock", false)

			local toggleStatus := doMouseLock and "Enabled" or "Disabled"
			ctrlObj.Text := "Block Inputs: " . toggleStatus
		}
	}

	local AOTStatus := AlwaysOnTopActive == true and "+AlwaysOnTop" or "-AlwaysOnTop"
	local AOT_Text := (AlwaysOnTopActive == true and "On") or "Off"

	; Create GUI Window
	SettingsUI := Gui(AOTStatus)
	SettingsUI.Opt("+Owner" . MainUI.Hwnd)
	SettingsUI.BackColor := intWindowColor
	SettingsUI.OnEvent("Close", CloseSettingsUI)
	SettingsUI.Title := "Clicker Settings"

	; Mouse Speed
	MouseSpeedLabel := SettingsUI.Add("Text", "Section Center vMouseSpeedLabel h20 w" Popout_Width/1.05, "Mouse Speed: " . clamp(MouseSpeed,0,maxSpeed) . " ms")
	MouseSpeedLabel.SetFont("s14 w600", "Consolas")
	MouseSpeedLabel.Opt("Background" intWindowColor . " c" ControlTextColor)

	MouseSpeedSlider := SettingsUI.Add("Slider", "xm+" . Popout_Width/6.5 . " 0x300 0xC00 AltSubmit vMouseSpeed w" Popout_Width/1.5 - (SettingsUI.MarginX))
	MouseSpeedSlider.OnEvent("Change", updateSliderValues)
	
	MS_Buddy1 := SettingsUI.Add("Text", "Center vMS_Buddy1 h20 w40", "Fast")
	MS_Buddy1.SetFont("s12 w600", "Consolas")
	MS_Buddy1.Opt("Background" intWindowColor . " c" ControlTextColor)
	MS_Buddy2 := SettingsUI.Add("Text", "Center vMS_Buddy2 h20 w40", "Slow")
	MS_Buddy2.SetFont("s12 w600", "Consolas")
	MS_Buddy2.Opt("Background" intWindowColor . " c" ControlTextColor)

	MouseSpeedSlider.Opt("Buddy1MS_Buddy1 Buddy2MS_Buddy2 Range0-" maxSpeed)
	MouseSpeedSlider.Value := clamp(MouseSpeed,0,maxSpeed) or 0

	; Mouse Click Rate Offset
	ClickRateOffsetLabel := SettingsUI.Add("Text", "xm y+-" . labelOffset . " Section Center vClickRateOffsetLabel h20 w" Popout_Width/1.05, "Click Rate Offset: " . clamp(MouseClickRateOffset,0,maxSpeed) . " ms")
	ClickRateOffsetLabel.SetFont("s14 w600", "Consolas")
	ClickRateOffsetLabel.Opt("Background" intWindowColor . " c" ControlTextColor)

	ClickRateSlider := SettingsUI.Add("Slider", "xm+" . Popout_Width/6.5 . " y+-" . sliderOffset . " 0x300 0xC00 AltSubmit vClickRateOffset w" Popout_Width/1.5 - (SettingsUI.MarginX))
	ClickRateSlider.OnEvent("Change", updateSliderValues)
	
	Rate_Buddy1 := SettingsUI.Add("Text", "Center vRate_Buddy1 h20 w40", "Less")
	Rate_Buddy1.SetFont("s12 w600", "Consolas")
	Rate_Buddy1.Opt("Background" intWindowColor . " c" ControlTextColor)
	Rate_Buddy2 := SettingsUI.Add("Text", "Center vRate_Buddy2 h20 w40", "More")
	Rate_Buddy2.SetFont("s12 w600", "Consolas")
	Rate_Buddy2.Opt("Background" intWindowColor . " c" ControlTextColor)

	ClickRateSlider.Opt("Buddy1Rate_Buddy1 Buddy2Rate_Buddy2 Range0-" maxRate)
	ClickRateSlider.Value := clamp(MouseClickRateOffset,0,maxSpeed) or 0

	; Mouse Click Radius
	ClickRadiusLabel := SettingsUI.Add("Text", "xm y+-" . labelOffset . " Section Center vClickRadiusLabel h20 w" Popout_Width/1.05, "Click Radius: " . clamp(MouseClickRadius,0,maxSpeed) . " pixels")
	ClickRadiusLabel.SetFont("s14 w600", "Consolas")
	ClickRadiusLabel.Opt("Background" intWindowColor . " c" ControlTextColor)

	ClickRadiusSlider := SettingsUI.Add("Slider", "xm+" . Popout_Width/6.5 . " y+-" . sliderOffset . " 0x300 0xC00 AltSubmit vClickRadius w" Popout_Width/1.5 - (SettingsUI.MarginX))
	ClickRadiusSlider.OnEvent("Change", updateSliderValues)
	
	ClickRadiusBuddy1 := SettingsUI.Add("Text", "Center vClickRadiusBuddy1 h20 w40", "Small")
	ClickRadiusBuddy1.SetFont("s12 w600", "Consolas")
	ClickRadiusBuddy1.Opt("Background" intWindowColor . " c" ControlTextColor)
	ClickRadiusBuddy2 := SettingsUI.Add("Text", "Center vClickRadiusBuddy2 h20 w40", "Big")
	ClickRadiusBuddy2.SetFont("s12 w600", "Consolas")
	ClickRadiusBuddy2.Opt("Background" intWindowColor . " c" ControlTextColor)

	ClickRadiusSlider.Opt("Buddy1ClickRadiusBuddy1 Buddy2ClickRadiusBuddy2 Range0-" maxRadius)
	ClickRadiusSlider.Value := clamp(MouseClickRadius,0,maxSpeed) or 0
	
	; Mouse Clicks
	MouseClicksLabel := SettingsUI.Add("Text", "xm y+-" . labelOffset . " Section Center vMouseClicksLabel h20 w" Popout_Width/1.05, "Click Amount: " . clamp(MouseClicks,1,maxClicks) . " clicks")
	MouseClicksLabel.SetFont("s14 w600", "Consolas")
	MouseClicksLabel.Opt("Background" intWindowColor . " c" ControlTextColor)

	MouseClicksSlider := SettingsUI.Add("Slider", "xm+" . Popout_Width/6.5 . " y+-" . sliderOffset . " 0x300 0xC00 AltSubmit vMouseClicks w" Popout_Width/1.5 - (SettingsUI.MarginX))
	MouseClicksSlider.OnEvent("Change", updateSliderValues)
	
	MouseClicksBuddy1 := SettingsUI.Add("Text", "Center vMouseClicksBuddy1 h20 w40", "Less")
	MouseClicksBuddy1.SetFont("s12 w600", "Consolas")
	MouseClicksBuddy1.Opt("Background" intWindowColor . " c" ControlTextColor)
	MouseClicksBuddy2 := SettingsUI.Add("Text", "Center vMouseClicksBuddy2 h20 w40", "More")
	MouseClicksBuddy2.SetFont("s12 w600", "Consolas")
	MouseClicksBuddy2.Opt("Background" intWindowColor . " c" ControlTextColor)

	MouseClicksSlider.Opt("Buddy1MouseClicksBuddy1 Buddy2MouseClicksBuddy2 Range1-" maxClicks)
	MouseClicksSlider.Value := clamp(MouseClicks,1,maxClicks) or 1
	
	; Mouse Click Rate Offset
	CooldownLabel := SettingsUI.Add("Text", "xm y+-" . labelOffset . " Section Center vCooldownLabel h20 w" Popout_Width/1.05, "")
	CooldownLabel.SetFont("s14 w600", "Consolas")
	CooldownLabel.Opt("Background" intWindowColor . " c" ControlTextColor)
	CooldownLabel.Text := "Cooldown: " . (SecondsToWait < 60) ? SecondsToWait " seconds" : Format("{:02}:{:02}", Floor(SecondsToWait / 60), Mod(SecondsToWait, 60))

	CooldownSlider := SettingsUI.Add("Slider", "xm+" . Popout_Width/6.5 . " y+-" . sliderOffset . " 0x300 0xC00 AltSubmit vCooldownSlider w" Popout_Width/1.5 - (SettingsUI.MarginX))
	CooldownSlider.OnEvent("Change", updateSliderValues)
	
	Cooldown_Buddy1 := SettingsUI.Add("Text", "Center vCooldown_Buddy1 h20 w40", "Less")
	Cooldown_Buddy1.SetFont("s12 w600", "Consolas")
	Cooldown_Buddy1.Opt("Background" intWindowColor . " c" ControlTextColor)
	Cooldown_Buddy2 := SettingsUI.Add("Text", "Center vCooldown_Buddy2 h20 w40", "More")
	Cooldown_Buddy2.SetFont("s12 w600", "Consolas")
	Cooldown_Buddy2.Opt("Background" intWindowColor . " c" ControlTextColor)

	CooldownSlider.Opt("Buddy1Cooldown_Buddy1 Buddy2Cooldown_Buddy2 Range0-" maxCooldown)
	CooldownSlider.Value := clamp(SecondsToWait,0,maxCooldown) or 0

	; Cooldown Editor
	EditCooldownButton := SettingsUI.Add("Button", "xm y+-" . labelOffset . " vCooldownEditor h40 w" Popout_Width/1.05, "Custom Cooldown")
	EditCooldownButton.OnEvent("Click", CooldownEditPopup)
	EditCooldownButton.SetFont("s14 w500", "Consolas")
	EditCooldownButton.Opt("Background" intWindowColor)
	
	; Mouse Lock
	local toggleStatus := doMouseLock and "Enabled" or "Disabled"
	ToggleMouseLock := SettingsUI.Add("Button", "xm y+" . labelOffset/6.5 . " Section Center vToggleMouseLock h40 w" Popout_Width/1.05, "Block Inputs: " . toggleStatus)
	ToggleMouseLock.SetFont("s14 w500", "Consolas")
	ToggleMouseLock.Opt("Background" intWindowColor . " c" ControlTextColor)
	ToggleMouseLock.OnEvent("Click", updateToggle)
	
	; Slider Description Box
	local testBoxColor := "666666"
	DescriptionBox := SettingsUI.Add("Text", "xm Section Left vDescriptionBox h" . Popout_Height/3.25 . " w" Popout_Width/1.05)
	DescriptionBox.SetFont("s10 w700", "Consolas")
	DescriptionBox.Opt("+Border Background" (testBoxColor or intWindowColor) . " c" ControlTextColor)
	
	; Hover Descriptions
	local Descriptions := Map(
		; Sliders
		"MouseSpeed", "Use this slider to control how fast the mouse moves to each location in the auto-clicker sequence.",
		"ClickRateOffset", 'Use this slider to control the time between clicks when the auto-clicker fires.',
		"ClickRadius", "Use this slider to add random variations to the click auto-clicker's click pattern.`n`n(Higher values = Larger area of randomized clicks)",
		"ToggleMouseLock", "This button controls if the script blocks user inputs or not during the short auto-click sequence.`n`nIt is recommended to enable this setting if you are actively using your mouse or keyboard when the script is running. This is to prevent accidental mishaps in your gameplay.`n`n(Note: This setting will not impede on your active gameplay session, as your manual inputs will reset the script's auto-click timer!)",
		"MouseClicks", "Use this slider to control how many clicks are sent when the bar fills to 100%.",
		"CooldownEditor", "This button controls the duration of the auto-clicker sequence timer.`n`nLength: 0-15 minutes`n`n(Note: Setting the auto-clicker to 0 will have a constant reoeating click effect, like typical auto-clickers. However other windows not in the target scope will be ignored and not clicked.)",
		"CooldownSlider", "Use this slider to fine-tune the cooldown for the auto-clicker. Alternatively you can use the `"Custom Cooldown`" button to set a specific value."
	)
	
	Descriptions.Set("MouseSpeedLabel", Descriptions["MouseSpeed"])
	Descriptions.Set("MS_Buddy1", Descriptions["MouseSpeed"])
	Descriptions.Set("MS_Buddy2", Descriptions["MouseSpeed"])

	Descriptions.Set("ClickRateOffsetLabel", Descriptions["ClickRateOffset"])
	Descriptions.Set("Rate_Buddy1", Descriptions["ClickRateOffset"])
	Descriptions.Set("Rate_Buddy2", Descriptions["ClickRateOffset"])

	Descriptions.Set("ClickRadiusLabel", Descriptions["ClickRadius"])
	Descriptions.Set("ClickRadiusBuddy1", Descriptions["ClickRadius"])
	Descriptions.Set("ClickRadiusBuddy2", Descriptions["ClickRadius"])

	Descriptions.Set("MouseClicksLabel", Descriptions["MouseClicks"])
	Descriptions.Set("MouseClicksBuddy1", Descriptions["MouseClicks"])
	Descriptions.Set("MouseClicksBuddy2", Descriptions["MouseClicks"])
	
	Descriptions.Set("CooldownLabel", Descriptions["CooldownSlider"])
	Descriptions.Set("Cooldown_Buddy1", Descriptions["CooldownSlider"])
	Descriptions.Set("Cooldown_Buddy2", Descriptions["CooldownSlider"])


	updateDescriptionBox(newText := "") {
		DescriptionBox.Text := newText
	}

	mouseHoverDescription(*)
	{
		if not SettingsUI or not DescriptionBox
			return SetTimer(mouseHoverDescription,0)

		MouseGetPos(&MouseX,&MouseY,&HoverWindow,&HoverControl)
		local targetControl := ""

		if HoverControl
		{
			try targetControl := SettingsUI.__Item[HoverControl]
			if SettingsUI and DescriptionBox and HoverControl and targetControl and Descriptions.Has(targetControl.Name) and DescriptionBox.Text != Descriptions[targetControl.Name] {
				try updateDescriptionBox(Descriptions[targetControl.Name])
			}
			else if SettingsUI and DescriptionBox and not HoverControl or not targetControl or not Descriptions.Has(targetControl.Name) {
				try updateDescriptionBox()
			}
		}
	}
	SettingsUI.OnEvent("Close", CloseSettingsUI)

	; Calculate center position
	WinGetClientPos(&MainX, &MainY, &MainW, &MainH, MainUI.Title)
	CenterX := MainX + (MainW / 2) - (Popout_Width / 2)
	CenterY := MainY + (MainH / 2) - (Popout_Height / 2)

	SettingsUI.Show("AutoSize X" . CenterX . " Y" . CenterY . " w" . Popout_Width . "h" . Popout_Height)

	SetTimer(mouseHoverDescription,50)
}

; Create blank popout window
CreateScriptSettingsGUI(*)
{
	; UI Settings
	local PixelOffset := 10
	local Popout_Width := 400
	local Popout_Height := 600
	local labelOffset := 50
	local sliderOffset := 2.5

	; Labels, Sliders, Buttons
	global EditButton
	global ExitButton
	global OpenMouseSettingsButton
	global ReloadButton
	global EditorButton
	global ScriptDirButton
	global AddToBootupFolderButton

	; Global Save Data
	global ScriptSettingsUI
	global AlwaysOnTopActive
	
	; Global Controls
	global MainUI
	global MainUI_PosX
	global MainUI_PosY

	local AOTStatus := AlwaysOnTopActive == true and "+AlwaysOnTop" or "-AlwaysOnTop"
	local AOT_Text := (AlwaysOnTopActive == true and "On") or "Off"

	; Colors
	global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
	global intWindowColor := (!blnLightMode and updateTheme) and "404040" or "EEEEEE"
	global intControlColor := (!blnLightMode and updateTheme) and "606060" or "FFFFFF"
	global ControlTextColor := (!blnLightMode and updateTheme) and "FFFFFF" or "000000"

	CloseSettingsUI(*)
	{
		if ScriptSettingsUI {
			ScriptSettingsUI.Destroy()
			ScriptSettingsUI := ""
		}
	}

	; If settingsUI is open, close it
	if ScriptSettingsUI
		return CloseSettingsUI()

	; ############################################ ;
	; ############################################ ;
	; ############################################ ;

	; Create GUI Window
	ScriptSettingsUI := Gui(AOTStatus)
	ScriptSettingsUI.Opt("+Owner" . MainUI.Hwnd)
	ScriptSettingsUI.BackColor := intWindowColor
	ScriptSettingsUI.OnEvent("Close", CloseSettingsUI)
	ScriptSettingsUI.Title := "Script Settings"

	; ############################################ ;
	; ############################################ ;
	; ############################################ ;
	
	; Edit
	EditButton := ScriptSettingsUI.Add("Button","vEditButton Section Center h40 w" Popout_Width/1.05, "View Script")
	EditButton.OnEvent("Click", EditApp)
	EditButton.SetFont("s12 w500", "Consolas")
	EditButton.Opt("Background" intWindowColor)
	
	; Reload
	ReloadButton := ScriptSettingsUI.Add("Button", "vReloadButton xs h40 w" (Popout_Width/1.05), "Relaunch Script")
	ReloadButton.OnEvent("Click", ReloadScript)
	ReloadButton.SetFont("s12 w500", "Consolas")
	ReloadButton.Opt("Background" intWindowColor)
	
	; Exit
	ExitButton := ScriptSettingsUI.Add("Button", "vExitButton xs h40 w" (Popout_Width/1.05), "Close Script")
	ExitButton.OnEvent("Click", CloseApp)
	ExitButton.SetFont("s12 w500", "Consolas")
	ExitButton.Opt("Background" intWindowColor)

	; ############################################ ;
	; ############################################ ;
	
	; Editor Selector
	EditorButton := ScriptSettingsUI.Add("Button", "vEditorSelector xs h40 w" Popout_Width/1.05, "Select Script Editor")
	EditorButton.OnEvent("Click", SelectEditor)
	EditorButton.SetFont("s12 w500", "Consolas")
	EditorButton.Opt("Background" intWindowColor)

	; Open Script Directory
	ScriptDirButton := ScriptSettingsUI.Add("Button", "vScriptDir xs h40 w" Popout_Width/1.05, "Open File Location")
	ScriptDirButton.OnEvent("Click", OpenScriptDir)
	ScriptDirButton.SetFont("s12 w500", "Consolas")
	ScriptDirButton.Opt("Background" intWindowColor)

	local addToStartUp_Text := isInStartFolder and "Remove from Windows startup folder" or "Add to Windows startup folder"
	AddToBootupFolderButton := ScriptSettingsUI.Add("Button", "vStartupToggle xs h40 w" Popout_Width/1.05, addToStartUp_Text)
	AddToBootupFolderButton.OnEvent("Click", ToggleStartup)
	AddToBootupFolderButton.Opt("Background" intWindowColor)
	AddToBootupFolderButton.SetFont("s12 w500", "Consolas")

	; ############################################ ;
	; ############################################ ;
	; ############################################ ;

	; Slider Description Box
	local testBoxColor := "666666"
	DescriptionBox := ScriptSettingsUI.Add("Text", "xm Section Left vDescriptionBox h" . Popout_Height/4 . " w" Popout_Width/1.05)
	DescriptionBox.SetFont("s10 w700", "Consolas")
	DescriptionBox.Opt("+Border Background" (testBoxColor or intWindowColor) . " c" ControlTextColor)
	
	; Hover Descriptions
	local Descriptions := Map(
		; Sliders
		; "Button", "Text",
		"StartupToggle", "If enabled, the script will launch automatically when Windows boots up. Recommended with hidden UI (Alt + Backspace)",
		"ScriptDir", "View where the script is location in Windows Explorer",
		"EditorSelector", "Select a script editor to edit the script with (notepad, notepad++, Visual Studio Code, etc.)",
		"EditButton", "View or edit the script using a script editor of your choice.",
		"ExitButton", "Terminate the script",
		"ReloadButton", "Reload the script",
	)
	
	updateDescriptionBox(newText := "") {
		DescriptionBox.Text := newText
	}

	mouseHoverDescription(*)
	{
		if not ScriptSettingsUI or not DescriptionBox
			return SetTimer(mouseHoverDescription,0)

		MouseGetPos(&MouseX,&MouseY,&HoverWindow,&HoverControl)
		local targetControl := ""

		if HoverControl
		{
			try targetControl := ScriptSettingsUI.__Item[HoverControl]
			if ScriptSettingsUI and DescriptionBox and HoverControl and targetControl and Descriptions.Has(targetControl.Name) and DescriptionBox.Text != Descriptions[targetControl.Name] {
				try updateDescriptionBox(Descriptions[targetControl.Name])
			}
			else if ScriptSettingsUI and DescriptionBox and not HoverControl or not targetControl or not Descriptions.Has(targetControl.Name) {
				try updateDescriptionBox()
			}
		}
	}

	; Calculate center position
	WinGetClientPos(&MainX, &MainY, &MainW, &MainH, MainUI.Title)
	CenterX := MainX + (MainW / 2) - (Popout_Width / 2)
	CenterY := MainY + (MainH / 2) - (Popout_Height / 2)

	ScriptSettingsUI.Show("AutoSize X" . CenterX . " Y" . CenterY . " w" . Popout_Width . "h" . Popout_Height)

	SetTimer(mouseHoverDescription,50)
}

CreateExtrasGUI(*)
{
	global MoveControl
	global ControlResize
	global warningRequested
	global MainUI_PosX
	global MainUI_PosY

	local Popout_Width := 400
	local Popout_Height := 600
	local createNewWarningButton := ""
	local ExtrasUI_Width := 400
	local ExtrasUI_Height := 400
	
	; Create new UI
	global ExtrasUI

	if ExtrasUI
		ExtrasUI.Destroy()

	ExtrasUI := Gui(AlwaysOnTopActive)
	ExtrasUI.BackColor := intWindowColor
	ExtrasUI.Title := "Extras"
	ExtrasUI.OnEvent("Close", killGUI)
	ExtrasUI.SetFont("s14 w500", "Courier New")
	
	local UI_Margin_Width := ExtrasUI.MarginX*2
	local UI_Margin_Height := ExtrasUI.MarginY*1.25
	local buttonHeight := (ExtrasUI_Height/8) - UI_Margin_Height
	local buttonWidth := ExtrasUI_Width - UI_Margin_Width

	; Discord
	local DiscordLink := ExtrasUI.Add("Button", "vDiscordLink Center h" . buttonHeight . " w" . Popout_Width/1.05, 'Join the Discord!')
	DiscordLink.SetFont("s12 w500", "Consolas")
	DiscordLink.OnEvent("Click", DiscordLink_Click)
	DiscordLink.Opt("Background" intWindowColor)
	DiscordLink_Click(*) {
		Run("https://discord.gg/w8QdNsYmbr")
	}
	
	; GitHub
	local GitHubLink := ExtrasUI.Add("Button", "vGithubLink Center h" . buttonHeight . " w" . Popout_Width/1.05, "GitHub Repository")
	GitHubLink.SetFont("s12 w500", "Consolas")
	GitHubLink.OnEvent("Click", GitHubLink_Click)
	GitHubLink.Opt("Background" intWindowColor)
	GitHubLink_Click(*) {
		Run("https://github.com/WoahItsJeebus/JACS/")
	}

	; Warning UI
	local OpenWarningLabel := ExtrasUI.Add("Button", "vOpenWarning Center h" . buttonHeight . " w" . Popout_Width/1.05, "View Warning Agreement")
	OpenWarningLabel.SetFont("s12 w500", "Consolas")
	OpenWarningLabel.OnEvent("Click", (*) => createWarningUI(true))
	OpenWarningLabel.Opt("Background" intWindowColor)

	; Patchnotes UI
	local ViewPatchnotes := ExtrasUI.Add("Button", "vViewPatchnotes Center h" . buttonHeight . " w" . Popout_Width/1.05, "Patchnotes")
	ViewPatchnotes.SetFont("s12 w500", "Consolas")
	ViewPatchnotes.OnEvent("Click", ShowPatchNotesGUI)
	ViewPatchnotes.Opt("Background" intWindowColor)


	; ############################### ;
	; ############################### ;
	; Slider Description Box
	local testBoxColor := "666666"
	DescriptionBox := ExtrasUI.Add("Text", "xm Section Left vDescriptionBox h" . Popout_Height/4 . " w" Popout_Width/1.05)
	DescriptionBox.SetFont("s10 w700", "Consolas")
	DescriptionBox.Opt("+Border Background" (testBoxColor or intWindowColor) . " c" ControlTextColor)
	
	; Hover Descriptions
	local Descriptions := Map(
		; Sliders
		; "Button", "Text",
		"DiscordLink","Join the Discordeebus Discord server!",
		"GithubLink","View the Github repository and see changes from past versions!",
		"OpenWarning","View the warning popup seen when running the script for the first time (or if denying the agreement/closing without accepting)",
		"ViewPatchnotes","Fetch the patchnotes for the latest version of the script posted to Github!",
	)
	
	updateDescriptionBox(newText := "") {
		DescriptionBox.Text := newText
	}

	mouseHoverDescription(*)
	{
		if not ExtrasUI or not DescriptionBox
			return SetTimer(mouseHoverDescription,0)

		MouseGetPos(&MouseX,&MouseY,&HoverWindow,&HoverControl)
		local targetControl := ""

		if HoverControl
		{
			try targetControl := ExtrasUI.__Item[HoverControl]
			if ExtrasUI and DescriptionBox and HoverControl and targetControl and Descriptions.Has(targetControl.Name) and DescriptionBox.Text != Descriptions[targetControl.Name] {
				try updateDescriptionBox(Descriptions[targetControl.Name])
			}
			else if ExtrasUI and DescriptionBox and not HoverControl or not targetControl or not Descriptions.Has(targetControl.Name) {
				try updateDescriptionBox()
			}
		}
	}

	; Calculate center position
	WinGetClientPos(&MainX, &MainY, &MainW, &MainH, MainUI.Title)
	CenterX := MainX + (MainW / 2) - (Popout_Width / 2)
	CenterY := MainY + (MainH / 2) - (Popout_Height / 2)

	ExtrasUI.Show("AutoSize X" . CenterX . " Y" . CenterY . " w" . Popout_Width . "h" . Popout_Height)

	SetTimer(mouseHoverDescription,50)

	; Calculate center position
	WinGetClientPos(&MainX, &MainY, &MainW, &MainH, MainUI.Title)
	CenterX := MainX + (MainW / 2) - (ExtrasUI_Width / 2)
	CenterY := MainY + (MainH / 2) - (ExtrasUI_Height / 2)

	ExtrasUI.Show("AutoSize X" . CenterX . " Y" . CenterY . " w" . ExtrasUI_Width . " h" . ExtrasUI_Height)

	killGUI(*) {
		if ExtrasUI
			ExtrasUI := ""
	}
}

ToggleHideUI(newstate)
{
	global MainUI
	global isUIHidden

	if not MainUI
		return CreateGui()

	RegWrite(newstate or not isUIHidden, "REG_DWORD", "HKCU\Software\AFKeebus", "isUIHidden")
	isUIHidden := RegRead("HKCU\Software\AFKeebus", "isUIHidden", false)
}

updateUIVisibility(*)
{
	global MainUI
	global isUIHidden
	global MainUI_PosX
	global MainUI_PosY
	
	if not MainUI
		return

	local winState := WinGetMinMax(MainUI.Title) ; -1 = Minimized | 0 = "Neither" (I assume floating) | 1 = Maximized
	if isUIHidden
		MainUI.Hide()
	else if not isUIHidden and winState != -1
		MainUI.Show("X" . MainUI_PosX . " Y" . MainUI_PosY . " Restore AutoSize")
}

ToggleStartup(*) {
	global AddToBootupFolderButton
	global isInStartFolder

    StartupPath := A_AppData "\Microsoft\Windows\Start Menu\Programs\Startup"
	TargetFile := StartupPath "\" A_ScriptName
	
	local newMode

    if (FileExist(TargetFile)) {
        FileDelete(TargetFile)

		newMode := false
		RegWrite(newMode, "REG_DWORD", "HKCU\Software\AFKeebus", "isInStartFolder")
		isInStartFolder := RegRead("HKCU\Software\AFKeebus", "isInStartFolder", false)

        MsgBox "Script removed from Startup."
    } else {
        FileCopy(A_ScriptFullPath, TargetFile)

		newMode := true
		RegWrite(newMode, "REG_DWORD", "HKCU\Software\AFKeebus", "isInStartFolder")
		isInStartFolder := RegRead("HKCU\Software\AFKeebus", "isInStartFolder", false)

        MsgBox "Script added to Startup."
    }

	local addToStartUp_Text := isInStartFolder and "Remove from startup folder" or "Add to startup folder"
	AddToBootupFolderButton.Text := addToStartUp_Text
}

ToggleAOT(*)
{
	global MainUI
	global SettingsUI
	global WindowSettingsUI
	global AlwaysOnTopButton
	global AlwaysOnTopActive

	RegWrite(!AlwaysOnTopActive, "REG_DWORD", "HKCU\Software\AFKeebus", "AlwaysOnTop")
	AlwaysOnTopActive := RegRead("HKCU\Software\AFKeebus", "AlwaysOnTop", false)

	local AOTStatus := (AlwaysOnTopActive == true and "+AlwaysOnTop") or "-AlwaysOnTop"
	local AOT_Text := (AlwaysOnTopActive == true and "On") or "Off"

	if AlwaysOnTopButton
		AlwaysOnTopButton.Text := "Always-On-Top: " . AOT_Text

	if MainUI
		MainUI.Opt(AOTStatus)

	if SettingsUI
		SettingsUI.Opt(AOTStatus)

	if WindowSettingsUI
		WindowSettingsUI.Opt(AOTStatus)
}

CheckDeviceTheme(*)
{
	global MainUI
	global EditButton
	global ExitButton
	global CoreToggleButton
	global SoundToggleButton
	global ReloadButton
	global EditCooldownButton
	global EditorButton
	global ScriptDirButton

	global WaitProgress
	global WaitTimerLabel
	global ElapsedTimeLabel
	global MinutesToWait
	global CreditsLink
	global ResetCooldownButton

	; Colors
	global blnLightMode := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
	global intWindowColor := (!blnLightMode and updateTheme) and "404040" or "EEEEEE"
	global intControlColor := (!blnLightMode and updateTheme) and "606060" or "FFFFFF"
	global intProgressBarColor := (!blnLightMode and updateTheme) and "757575" or "dddddd"
	global ControlTextColor := (!blnLightMode and updateTheme) and "FFFFFF" or "000000"
	global linkColor := (!blnLightMode and updateTheme) and "99c3ff" or "4787e7"
	
	global currentTheme := blnLightMode
	global lastTheme
	
	if lastTheme != currentTheme and MainUI
	{
		lastTheme := currentTheme
		MainUI.BackColor := intWindowColor
		
		EditButton.Opt("Background" intWindowColor)
		ExitButton.Opt("Background" intWindowColor)
		CoreToggleButton.Opt("Background" intWindowColor)
		SoundToggleButton.Opt("Background" intWindowColor)
		ReloadButton.Opt("Background" intWindowColor)
		ScriptDirButton.Opt("Background" intWindowColor)
		EditorButton.Opt("Background" intWindowColor)
		EditCooldownButton.Opt("Background" intWindowColor)
		WaitProgress.Opt("Background" intProgressBarColor)
		ResetCooldownButton.Opt("Background" intWindowColor)
		WaitTimerLabel.Opt("Background" intWindowColor . " c" ControlTextColor)
		ElapsedTimeLabel.Opt("Background" intWindowColor . " c" ControlTextColor)
		
		EditButton.Redraw()
		ExitButton.Redraw()
		CoreToggleButton.Redraw()
		SoundToggleButton.Redraw()
		ReloadButton.Redraw()
		ScriptDirButton.Redraw()
		EditorButton.Redraw()
		WaitProgress.Redraw()
		WaitTimerLabel.Redraw()
		ElapsedTimeLabel.Redraw()
		ResetCooldownButton.Redraw()
		CreditsLink.Opt("c" linkColor)
	}
}

CooldownEditPopup(*)
{
	global MinutesToWait
	global SecondsToWait
	global MainUI
	global minCooldown
	global clamp := (n, low, hi) => Min(Max(n, low), hi)
	
	local newMinutes := MinutesToWait
	local InpBox := InputBox(minCooldown . " - 15 minutes", "Edit Cooldown", "w100 h100")
	if InpBox.Result != "Cancel" and IsNumber(InpBox.Value) {
		newMinutes := clamp(InpBox.Value,minCooldown,15)
		SecondsToWait := clamp(Round(InpBox.Value * 60,0),(minCooldown > 0 and minCooldown/60) or 0,900)
	}
	else if InpBox.Result != "Cancel" and not IsNumber(InpBox.Value) and InpBox.Value != ""
		MsgBox("Please enter a valid number to update the cooldown!","Cooldown update error","T5")
	
	RegWrite(SecondsToWait, "REG_DWORD", "HKCU\Software\AFKeebus", "SecondsToWait")
	RegWrite(newMinutes, "REG_DWORD", "HKCU\Software\AFKeebus", "Cooldown")
	MinutesToWait := RegRead("HKCU\Software\AFKeebus", "Cooldown", 15)
	SecondsToWait := RegRead("HKCU\Software\AFKeebus", "SecondsToWait", MinutesToWait*60)
	
	; ResetCooldown()
	UpdateTimerLabel()

	return MinutesToWait
}

SaveMainUIPosition(*) {
    global MainUI_PosX
    global MainUI_PosY
    global MainUI
	local winState := WinGetMinMax(MainUI.Title) ; -1 = Minimized | 0 = "Neither" (I assume floating) | 1 = Maximized

	if not WinActive(MainUI.Title)
		return

    if MainUI and WinExist(MainUI.Title) {
        WinGetClientPos(&X, &Y,&W,&H, MainUI.Title)

        ; Convert to unsigned if negative before saving
        X := (X < 0) ? (0xFFFFFFFF + X + 1) : X
        Y := (Y < 0) ? (0xFFFFFFFF + Y + 1) : Y

        if MainUI_PosX != X and (X < 32000 and X > -32000) and winState != -1 {
            RegWrite(X, "REG_DWORD", "HKCU\Software\AFKeebus", "MainUI_PosX")
            MainUI_PosX := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosX", A_ScreenWidth / 2)
        }

        if MainUI_PosY != Y and (Y < 32000 and Y > -32000) and winState != -1 {
            RegWrite(Y, "REG_DWORD", "HKCU\Software\AFKeebus", "MainUI_PosY")
            MainUI_PosY := RegReadSigned("HKCU\Software\AFKeebus", "MainUI_PosY", A_ScreenHeight / 2)
        }
    }
}

UpdateTimerLabel(*) {
	global isActive
	global MinutesToWait
	global ElapsedTimeLabel
	global CurrentElapsedTime
	global lastUpdateTime := isActive > 1 and lastUpdateTime or A_TickCount
	global SecondsToWait
	
	; Calculate and update progress bar
    secondsPassed := (A_TickCount - lastUpdateTime) / 1000  ; Convert ms to seconds

    finalProgress := (MinutesToWait == 0 and SecondsToWait == 0) and 100 or (secondsPassed / SecondsToWait) * 100
	
	; Calculate and format CurrentElapsedTime as MM:SS
    currentMinutes := Floor(secondsPassed / 60)
    currentSeconds := Round(Mod(secondsPassed, 60),0)
	
	targetSeconds := (SecondsToWait > 0) and Round(Mod(SecondsToWait, 60),0) or 0
	
	CurrentElapsedTime := Format("{:02}:{:02}", currentMinutes, currentSeconds)
	targetFormattedTime := Format("{:02}:{:02}", MinutesToWait, targetSeconds)

	local mins_suffix := MinutesToWait > 1 and "minutes" or MinutesToWait == 1 and "minute" or MinutesToWait < 1 and "seconds"
	
	try if ElapsedTimeLabel.Text != CurrentElapsedTime " / " . targetFormattedTime . " " mins_suffix
			ElapsedTimeLabel.Text := CurrentElapsedTime " / " . targetFormattedTime . " " mins_suffix
}

OpenScriptDir(*) {
	; SetWorkingDir A_InitialWorkingDir
	Run("explorer.exe " . A_ScriptDir)
}

SelectEditor(*) {
	Editor := FileSelect(2,, "Select your editor", "Programs (*.exe)")
	RegWrite Format('"{1}" "%L"', Editor), "REG_SZ", "HKCR\AutoHotkeyScript\Shell\Edit\Command"
}

CloseApp(*) {
	; SetTimer(SaveMainUIPosition,0)
	SaveMainUIPosition()
	ExitApp
}

EditApp(*) {
	Edit
}

Roblox_Not_Found(*) {
	msgBox("Roblox Player not found!`n`nMake sure Roblox is running and you're using one of the following supported Roblox clients:`n`n(RobloxPlayerBeta.exe`nBloxstrap client also supported!)", "Jeebus's Auto-Clicker Script", "T20")
}

ResetCooldown(*) {
	global CoreToggleButton
	global ElapsedTimeLabel
	global WaitProgress
	global WaitTimerLabel
	global activeText_Core
	global lastUpdateTime := A_TickCount

	activeText_Core := (isActive == 3 and "Enabled") or (isActive == 2 and "Waiting...") or "Disabled"

	if CoreToggleButton.Text != "Auto-Clicker: " activeText_Core
		CoreToggleButton.Text := "Auto-Clicker: " activeText_Core
	; CoreToggleButton.Redraw()

	if isActive == 2 and getRobloxHWND()
		ToggleCore(,3)
	else if isActive == 3 and not getRobloxHWND()
		ToggleCore(,2)

	; Reset cooldown progress bar
	UpdateTimerLabel()
	
	if isActive <= 2 or (WaitProgress and WaitProgress.Value != 0 and (MinutesToWait > 0 or SecondsToWait > 0))
		WaitProgress.Value := 0
    
	local finalText  := Round(WaitProgress.Value, 0) "%"
	if WaitTimerLabel and WaitTimerLabel.Text != finalText
		WaitTimerLabel.Text := finalText
}

isWaitingForRoblox(*) {
	global isActive
	
	if isActive == 2 and not getRobloxHWND()
		return true

	return false
}

switchActiveState(*) {
	global isActive
	local newMode := isActive < 3 and isActive + 1 or 1
	if newMode == 3 and not getRobloxHWND()
		newMode := 1
	return newMode
}

ToggleCore(optionalControl?, forceState?, *) {
	; Variables
	global isActive
	global FirstRun
	global activeText_Core
	global CoreToggleButton

	local newMode := forceState or switchActiveState()
	
	RegWrite(newMode, "REG_DWORD", "HKCU\Software\AFKeebus", "isActive")
	
	isActive := RegRead("HKCU\Software\AFKeebus", "isActive", 1)
	activeText_Core := (isActive == 3 and "Enabled") or (isActive == 2 and "Waiting...") or "Disabled"
	
	CoreToggleButton.Text := "Auto-Clicker: " activeText_Core
	CoreToggleButton.Redraw()

	; Reset cooldown
	ResetCooldown()
	
	UpdateTimerLabel()
	; Toggle Timer
	if isActive > 1
	{
		FirstRun := True
		return SetTimer(RunCore, 100)
	}
	else if isActive == 1
		return SetTimer(RunCore, 0)

	; isActive := 1
	ResetCooldown()
	SetTimer(RunCore, 0)
	return
}

ReloadScript(*) {
	SaveMainUIPosition()
	Reload
}

getRobloxHWND(*) {	
	local RobloxWindows := []
	local windowsVersion_Roblox := WinExist("ahk_exe ApplicationFrameHost.exe") and WinGetTitle(WinExist("ahk_exe ApplicationFrameHost.exe")) = "Roblox" and WinExist("ahk_exe ApplicationFrameHost.exe")
	local websiteVersion_Roblox := WinExist("ahk_exe RobloxPlayerBeta.exe") and WinExist("ahk_exe RobloxPlayerBeta.exe")
	
	if not windowsVersion_Roblox and not websiteVersion_Roblox
		return false
	if websiteVersion_Roblox
		RobloxWindows.Push(websiteVersion_Roblox)
	if windowsVersion_Roblox
		RobloxWindows.Push(windowsVersion_Roblox)

	return RobloxWindows
}

RunCore(*) {
	global FirstRun
	global MainUI
	global UI_Width
	global UI_Height
	global playSounds
	global isActive
	
	global EditButton
	global ExitButton

	global ReloadButton
	global CoreToggleButton
	
	global lastUpdateTime
	global MinutesToWait
	global SecondsToWait
	global WaitProgress
	global WaitTimerLabel
	global CurrentElapsedTime

	global wasActiveWindow

	global doMouseLock

	; Check for Roblox process
	if not getRobloxHWND()
		ResetCooldown()
	; 	ToggleCore(, 2)
	
	; Check if the toggle has been switched off
	if isActive == 1
		return
	
	if (FirstRun or WaitProgress.Value >= 100) and getRobloxHWND()
	{
		; Kill FirstRun for automation
		if FirstRun
			FirstRun := False
		
		ResetCooldown()
		
		if playSounds == 1
			RunWarningSound()
		
		if isActive == 1
			return
		
		; Indicate target found with audible beep
		if playSounds == 2
			SoundBeep(2000, 70)
		
		; Get old mouse pos
		MouseGetPos(&OldPosX, &OldPosY, &windowID)
		
		local wasMinimized := False
		
		; Block Inputs
		if doMouseLock and (MinutesToWait > 0 or SecondsToWait > 0) {
			BlockInput("On")
			BlockInput("SendAndMouse")
			BlockInput("MouseMove")
		}

		;---------------
		; Find and activate Roblox processes
		local robloxProcesses := getRobloxHWND()
		
		if robloxProcesses.Length > 1 {
			for i,v in robloxProcesses
				ClickWindow(v)
		}
		else
			ClickWindow(robloxProcesses[1])
		
		; Activate previous application window & reposition mouse
		local lastActiveWindowID := ""
		try lastActiveWindowID := WinExist(windowID)

		if not wasActiveWindow and lastActiveWindowID and (MinutesToWait > 0 or SecondsToWait > 0) {
			WinActivate lastActiveWindowID
			MouseMove OldPosX, OldPosY, 0
		}

		if doMouseLock
			Sleep(25)

		; Unblock Inputs
		BlockInput("Off")
		BlockInput("Default")
		BlockInput("MouseMoveOff")

		if (MinutesToWait > 0 or SecondsToWait > 0)
			WaitProgress.Value := 0

		lastUpdateTime := A_TickCount
	}
	
	; Calculate and progress visuals
    secondsPassed := (A_TickCount - lastUpdateTime) / 1000  ; Convert ms to seconds
    finalProgress := (MinutesToWait == 0 and SecondsToWait == 0) and 100 or (secondsPassed / SecondsToWait) * 100
	UpdateTimerLabel()

    ; Update UI elements for progress
    WaitProgress.Value := finalProgress

    local finalText  := Round(WaitProgress.Value, 0) "%"
	if WaitTimerLabel and WaitTimerLabel.Text != finalText
		WaitTimerLabel.Text := finalText
}

; ########################################################### ;
; #################### Button Formatting #################### ;
; ########################################################### ;

ResizeMethod(TargetButton, optionalX, objInGroup) {
	local parentUI := TargetButton.Gui
	
	; Calculate initial control width based on GUI width and margins
	local X := 0, Y := 0, UI_Width := 0, UI_Height := 0
	local UI_Margin_Width := UI_Width-parentUI.MarginX
	
	; Get the client area dimensions
	parentUI.GetPos(&X, &Y, &UI_Width, &UI_Height)
	NewButtonWidth := (UI_Width - (2 * UI_Margin_Width))
	
	; Prevent negative button widths
	if (NewButtonWidth < UI_Margin_Width/(objInGroup or 1)) {
		NewButtonWidth := UI_Margin_Width/(objInGroup or 1)  ; Set to 0 if the width is negative
	}
	
	OldButtonPosX := 0, OldY := 0, OldWidth := 0, OldHeight := 0
	TargetButton.GetPos(&OldButtonPosX, &OldY, &OldWidth, &OldHeight)
	
	; Move
	TargetButton.Move(optionalX > 0 and 0 + (UI_Width / optionalX) or 0 + parentUI.MarginX, , )
}

MoveMethod(Target, position, size) {
	local parentUI := Target.Gui
	
	local X := 0, Y := 0, UI_Width := 0, UI_Height := 0
	local UI_Margin_Width := UI_Width-parentUI.MarginX
	
	; Calculate initial control width based on GUI width and margins
	X := 0, Y := 0, UI_Width := 0, UI_Height := 0
	
	; Get the client area dimensions
	parentUI.GetPos(&X, &Y, &UI_Width, &UI_Height)
	NewButtonWidth := (UI_Width - (2 * UI_Margin_Width))
	
	; Prevent negative button widths
	if (NewButtonWidth < UI_Margin_Width/(size or 1)) {
		NewButtonWidth := UI_Margin_Width/(size or 1)  ; Set to 0 if the width is negative
	}
	
	OldButtonPosX := 0, OldY := 0, OldWidth := 0, OldHeight := 0
	Target.GetPos(&OldButtonPosX, &OldY, &OldWidth, &OldHeight)
	
	; Resize
	Target.Move(position > 0 and 0 + (UI_Width / position) or 0 + parentUI.MarginX, , position > 0 and 0 + (UI_Width / position) or 0 + parentUI.MarginX)
}

; ############################### ;
; ########### Sounds ############ ;
; ############################### ;

RunWarningSound(*) {

	Loop 3
		{
			if isActive == 1
			break

			if playSounds == 1
				SoundBeep(1000, 80)
			else
				break

			Sleep 1000
		}
}

ToggleSound(*) {
	global playSounds
	global SoundToggleButton
	local newMode := playSounds < 3 and playSounds + 1 or 1
	RegWrite(newMode, "REG_DWORD", "HKCU\Software\AFKeebus", "SoundMode")
	playSounds := RegRead("HKCU\Software\AFKeebus", "SoundMode", 1)

	local activeText_Sound := (playSounds == 1 and "All") or (playSounds == 2 and "Less") or (playSounds == 3 and "None")
	
	; Setup Sound Toggle Button
	if SoundToggleButton
		SoundToggleButton.Text := "Sounds: " activeText_Sound
	
	return
}

; ################################ ;
; ####### Window Functions ####### ;
; ################################ ;

isMouseClickingOnRoblox(key?, override*) {
	global initializing
	if initializing
		return

	local robloxProcesses := getRobloxHWND()
	if not robloxProcesses
		return
	
	checkWindow(*) {
		MouseGetPos(&mouseX, &mouseY, &hoverWindow)
		
		if robloxProcesses.Length > 1 {
			for i,v in robloxProcesses
				if hoverWindow == v
					return ResetCooldown()
		}
		else if hoverWindow == robloxProcesses[1] {
			return ResetCooldown()
		}
	}
	
	if override[1]
		return checkWindow()
	
	while (GetKeyState(key) == 1)
		checkWindow()
}

ClickWindow(process) {
	global wasActiveWindow := false
	global MouseSpeed
	global MouseClickRateOffset
	global MouseClickRadius
	global MouseClicks

	try wasActiveWindow := WinActive(process) and true or false

	MouseGetPos(&mouseX, &mouseY, &hoverWindow)
	local activeTitle := ""

	; Check if a window is active before calling WinGetTitle("A")
	if WinExist("A")
		try activeTitle := WinGetTitle("A")  ; Only attempt if a window exists
	
	ActivateRoblox() {
		try {
			if not WinActive(process) and (MinutesToWait > 0 or SecondsToWait > 0)
				WinActivate(process)
		}
	}

	ClickRoblox(loopAmount := 1) {
		loop loopAmount {
			if activeTitle and not WinExist(activeTitle)
				break
			
			WinGetPos(&WindowX, &WindowY, &Width, &Height, WinGetID(process))
			MouseGetPos(&mouseX, &mouseY, &hoverWindow, &hoverCtrl)
			
			; Determine exact center of the active window
			CenterX := WindowX + (Width / 2)
			CenterY := WindowY + (Height / 2)

			; Generate randomized offset
			OffsetX := Random(-MouseClickRadius, MouseClickRadius)
			OffsetY := Random(-MouseClickRadius, MouseClickRadius)

			; Move mouse to the new randomized position within the area
			if (hoverWindow and (hoverWindow != WinGetID(process))) and (MinutesToWait > 0 or SecondsToWait > 0)
				MouseMove(CenterX + OffsetX, CenterY + OffsetY, (MouseSpeed == 0 and 0 or Random(0, MouseSpeed)))

			if not hoverCtrl and (hoverWindow and hoverWindow == WinGetID(process))
				Send "{Click}"

			if loopAmount > 1
				Sleep(Random(10,(MouseClickRateOffset or 10)))
		}
	}

	; Use the local variable instead of calling WinGetTitle("A") again
	if (hoverWindow and (hoverWindow != process and hoverWindow != WinGetID(process))) and activeTitle
		ActivateRoblox()

	ClickRoblox(MouseClicks or 5)
}

debugNotif(msg := "1", title := "", options := "16", duration := 1) {
	SendNotification(msg, title, options, duration)
}

; ############################
; ######Extra Functions#######
; ############################

GetRandomColor(minVal := 0, maxVal := 255) {
    minVal := Max(0, Min(255, minVal)) ; Ensure min is within range
    maxVal := Max(0, Min(255, maxVal)) ; Ensure max is within range

    if (minVal > maxVal) { ; Prevents invalid range (swaps values if needed)
        temp := minVal
        minVal := maxVal
        maxVal := temp
    }

    ; Generate a bright color within the given range
    r := Random(minVal, maxVal)
    g := Random(minVal, maxVal)
    b := Random(minVal, maxVal)

    ; Ensure at least one channel is strong (prevents dark colors)
    if (r + g + b < (minVal * 3 + 50)) { ; If too dark, boost a random channel
        RandomChannel := Random(1, 3)
        if (RandomChannel = 1) 
            r := maxVal
        else if (RandomChannel = 2) 
            g := maxVal
        else 
            b := maxVal
    }

    return {R: r, G: g, B: b}
}

Lerp(start, stop, step) {
    return start + (stop - start) * (step / 100)
}

RollThankYou(*)
{
	local randomNumber := Random(1,100)
	local OSVer := GetWinOSVersion()
	
	if randomNumber != 1 or (OSVer != "11" and OSVer != "10")
		return
	
	SendNotification("Hey! I want to thank you for using my script! It's nice to see my work getting out there and being used!", "Jeebus' Auto-Clicker Script", "16", 5)
}

SendNotification(msg := "", title := "", options := "", optionalCooldown := 0) {
	local SleepAmount := 1000 * optionalCooldown

	if title == "JACS Update Available" {
		global tempUpdateFile

		local event := OnMessage(0x404, AHK_NOTIFYICON)
		AHK_NOTIFYICON(wParam, lParam, msg, hwnd)
		{
			if (hwnd != A_ScriptHwnd)
				return
			if (lParam = 1029) { ; Left-Clicked
				event := ""
				UpdateScript(tempUpdateFile)
			}
		}
	}

	TrayTip(msg, title, options)

	if optionalCooldown == 0
		return

	if GetWinOSVersion() == "10" {
		Sleep(SleepAmount)
		HideTrayTip()
	}
	else {
		Sleep(SleepAmount)
		TrayTip
	}
}

HideTrayTip() {
    TrayTip  ; Attempt to hide it the normal way.
    if SubStr(A_OSVersion,1,3) = "10." {
        A_IconHidden := true
        Sleep 200  ; It may be necessary to adjust this sleep.
        A_IconHidden := false
    }
}

GetWinOSVersion(WindowsVersion := "") {
	Ver := 0
	static Versions := [[">=10.0.20000", "11"], [">=10.0.10000", "10"], [">=6.3", "8.1"], [">=6.2", "8"], [">=6.1", "7"], [">=6.0", "Vista"], [">=5.2", "XP"], [">=5.1", "XP"]]
	if !(WindowsVersion)
		WindowsVersion := A_OSVersion
	if (WindowsVersion = "WIN_7")
		Ver := "7"
	else if (WindowsVersion = "WIN_8.1")
		Ver := "8.1"
	else if (WindowsVersion = "WIN_VISTA")
		Ver := "Vista"
	else if (WindowsVersion = "WIN_XP")
		Ver := "XP"
	else {
		static Versions := [[">=10.0.20000", "11"], [">=10.0.10000", "10"], [">=6.3", "8.1"], [">=6.2", "8"], [">=6.1", "7"], [">=6.0", "Vista"], [">=5.2", "XP"], [">=5.1", "XP"]]
		for i, VersionData in Versions {
			if !(VerCompare(WindowsVersion, VersionData[1]))
				continue
			Ver := VersionData[2]
			break
		}
	}
	return Ver
}

LinkUseDefaultColor(CtrlObj, Use := True)
{
	LITEM := Buffer(4278, 0)                  ; 16 + (MAX_LINKID_TEXT * 2) + (L_MAX_URL_LENGTH * 2)
	NumPut("UInt", 0x03, LITEM)               ; LIF_ITEMINDEX (0x01) | LIF_STATE (0x02)
	NumPut("UInt", Use ? 0x10 : 0, LITEM, 8)  ; ? LIS_DEFAULTCOLORS : 0
	NumPut("UInt", 0x10, LITEM, 12)           ; LIS_DEFAULTCOLORS
	While DllCall("SendMessage", "Ptr", CtrlObj.Hwnd, "UInt", 0x0702, "Ptr", 0, "Ptr", LITEM, "UInt") ; LM_SETITEM
	   NumPut("Int", A_Index, LITEM, 4)
	CtrlObj.Opt("+Redraw")
}

RegReadSigned(Key, ValueName, Default) {
    Value := RegRead(Key, ValueName, Default)  ; Read value from the registry

    if (Value > 0x7FFFFFFF) {  ; If it's an incorrectly stored unsigned 32-bit integer
        Value := -(0xFFFFFFFF - Value + 1)  ; Convert it to a signed 32-bit integer
    }

    return Value
}

ToggleHide_Hotkey(*) {
	global isUIHidden
	if isUIHidden == ""
		return

	ToggleHideUI(not isUIHidden)
	updateUIVisibility()
}


; ################################# ;
; ########## Patchnotes ########### ;
; ################################# ;

GetGitHubReleaseInfo(owner, repo, release:="latest") {
    req := ComObject("Msxml2.XMLHTTP")
    req.open("GET", "https://api.github.com/repos/" owner "/" repo "/releases/" release, false)
    req.send()

    if req.status != 200
        Error(req.status " - " req.statusText, -1)

    res := JSON_parse(req.responseText)

    try {
        return Map( 
            "title", res.name,     ; The release title (name)
            "tag", res.tag_name,   ; The release version/tag
            "body", StripMarkdown(res.body)       ; The release body
		)
    }
    catch PropertyError {
        (Error(res.message, -1))
    }

}

JSON_parse(str) {
	htmlfile := ComObject("htmlfile")
	htmlfile.write('<meta http-equiv="X-UA-Compatible" content="IE=edge">')
	return htmlfile.parentWindow.JSON.parse(str)
}

StripMarkdown(text) {
    ; Remove HTML tags (like <ins>, <del>, <mark>)
    text := RegExReplace(text, "<(ins|del|mark)>(.*?)<\/\1>", "$2")

    ; Remove full URLs (http/https links)
    text := RegExReplace(text, "https?://[^\s]+", "")

    ; Remove Markdown-style headings
    text := RegExReplace(text, "m)^#+\s*", "")

    ; Format common Markdown symbols
    text := RegExReplace(text, "\*\*(.*?)\*\*", "$1")  ; Bold
    text := RegExReplace(text, "\*(.*?)\*", "$1")      ; Italics
    text := RegExReplace(text, "``(.*?)``", "'$1'")    ; Inline code → 'code'
    text := RegExReplace(text, "~~(.*?)~~", "[$1]")    ; Strikethrough → [text]
    text := RegExReplace(text, ">\s?", "")             ; Blockquotes
    text := RegExReplace(text, "\[(.*?)\]\(.*?\)", "$1")  ; Remove hyperlinks but keep text

    ; Handle lists correctly
    text := RegExReplace(text, "-\s?", "• ")           ; Convert Markdown lists to bullet points
    text := RegExReplace(text, "\n\s*-", "\n•")        ; Ensure list continuity

    return text
}

ShowPatchNotesGUI(*) {
    owner := "WoahItsJeebus"  ; Change to your GitHub username
    repo := "JACS"     ; Change to your repository name
    
	githubResponse := GetGitHubReleaseInfo("WoahItsJeebus", "JACS")
	patchNotes := githubResponse["body"]

	global AlwaysOnTopActive
	global MainUI_PosX
	global MainUI_PosY
	global PatchUI

	local Popout_Width := "500"
	local Popout_Height := "500"
	local AOTStatus := AlwaysOnTopActive == true and "+AlwaysOnTop" or "-AlwaysOnTop"
	local AOT_Text := (AlwaysOnTopActive == true and "On") or "Off"

    ; Create GUI Window
	if PatchUI
		PatchUI.Destroy()

	PatchUI := Gui(AOTStatus)
	; PatchUI.Opt("+Owner" . MainUI.Hwnd)
	PatchUI.BackColor := intWindowColor
	PatchUI.Title := "Patchnotes"
	
	; Mouse Speed
	TopLabel := PatchUI.Add("Text", "Section Center vTopLabel h40 w" Popout_Width-PatchUI.MarginX, "Version " githubResponse["title"] " Patchnotes")
	TopLabel.SetFont("s20 w600", "Consolas")
	TopLabel.Opt("Background" intWindowColor . " c" ControlTextColor)

	patches := PatchUI.Add("Edit", "vPatchnotes VScroll Section ReadOnly h" Popout_Height, patchNotes)
	patches.SetFont("s12 w600", "Consolas")
	patches.Opt("Background555555" . " c" ControlTextColor)

	; Calculate center position
	PatchUI.Show("AutoSize")

	WinGetClientPos(&MainX, &MainY, &MainW, &MainH, MainUI.Title)
	WinGetPos(,,&patchUI_width,&patchUI_height, PatchUI.Title)

	CenterX := MainX + (MainW / 2) - (patchUI_width / 2)
	CenterY := MainY + (MainH / 2) - (patchUI_height / 2)
	PatchUI.Show("X" CenterX " Y" CenterY)

	TopLabel.Move(,,patchUI_width-PatchUI.MarginX)
	TopLabel.Redraw()
}

ConvertMarkdownToPlainText(markdownText) {
    static apiUrl := "https://api.github.com/markdown"

    ; Ensure the markdown text does not contain unescaped double quotes
    markdownText := StrReplace(markdownText, '""', '\""')

    ; Construct JSON string safely using single quotes
    jsonBody := "{'text': '" . markdownText . "', 'mode': 'gfm'}"

    ; Convert single quotes to double quotes for proper JSON formatting
    jsonBody := StrReplace(jsonBody, "'", '""')

    ; Create HTTP request object
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("POST", apiUrl, true)
    http.SetRequestHeader("Content-Type", "application/json")
    http.SetRequestHeader("User-Agent", "AHK-Request")

    ; Send the request with the JSON body
    http.Send(jsonBody)

    ; Wait for response
    while http.ReadyState != 4
        Sleep(10)

    ; Return the converted plain text response
    return http.ResponseText
}

; ############################## ;
; ########## Hotkeys ########### ;
; ############################## ;

A_HotkeyInterval := 0
; A_MaxHotkeysPerInterval := 1000

global movement_Keys := Map()

movement_Keys["~W"] := Map()
movement_Keys["~W"]["Function"] := isMouseClickingOnRoblox.Bind("W", false)

movement_Keys["~A"] := Map()
movement_Keys["~A"]["Function"] := isMouseClickingOnRoblox.Bind("A", false)

movement_Keys["~S"] := Map()
movement_Keys["~S"]["Function"] := isMouseClickingOnRoblox.Bind("S", false)

movement_Keys["~D"] := Map()
movement_Keys["~D"]["Function"] := isMouseClickingOnRoblox.Bind("D", false)

movement_Keys["~Space"] := Map()
movement_Keys["~Space"]["Function"] := isMouseClickingOnRoblox.Bind("Space", false)

movement_Keys["~Left"] := Map()
movement_Keys["~Left"]["Function"] := isMouseClickingOnRoblox.Bind("Left", false)

movement_Keys["~Right"] := Map()
movement_Keys["~Right"]["Function"] := isMouseClickingOnRoblox.Bind("Right", false)

movement_Keys["~Up"] := Map()
movement_Keys["~Up"]["Function"] := isMouseClickingOnRoblox.Bind("Up", false)

movement_Keys["~Down"] := Map()
movement_Keys["~Down"]["Function"] := isMouseClickingOnRoblox.Bind("Down", false)

movement_Keys["~/"] := Map()
movement_Keys["~/"]["Function"] := isMouseClickingOnRoblox.Bind("/", false)

movement_Keys["~LButton"] := Map()
movement_Keys["~LButton"]["Function"] := isMouseClickingOnRoblox.Bind("LButton", false)

movement_Keys["~RButton"] := Map()
movement_Keys["~RButton"]["Function"] := isMouseClickingOnRoblox.Bind("RButton", false)

movement_Keys["~WheelUp"] := Map()
movement_Keys["~WheelUp"]["Function"] := isMouseClickingOnRoblox.Bind("WheelUp", true)

movement_Keys["~WheelDown"] := Map()
movement_Keys["~WheelDown"]["Function"] := isMouseClickingOnRoblox.Bind("WheelDown", true)

movement_Keys["!BackSpace"] := Map()
movement_Keys["!BackSpace"]["Function"] := ToggleHide_Hotkey.Bind()


enableAllHotkeys(*) {
	for keyName, data in movement_Keys
		enableHotkey(keyName, data["Function"])
}

disableAllHotkeys(*) {
	for keyName, data in movement_Keys
		disableHotkey(keyName, data["Function"])
}

disableHotkey(keyName?, bind?) {
	try Hotkey(keyName,, "Off")
}

enableHotkey(keyName?, bind?) {
	Hotkey(keyName, bind, "On")
}

enableAllHotkeys()