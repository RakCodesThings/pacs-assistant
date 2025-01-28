#Requires AutoHotkey v2.0

class Settings {
    static settingsFile := A_ScriptDir "\settings.ini"
    static defaultSettings := Map(
        "AutoUpdate", true,  ; Changed to true by default
        "SkipBetaVersions", true,
        "AutoRefreshPACS", false,
        "RefreshInterval", 60,
        "AudioAlertNewCase", false,
        "MessageBoxNewCase", false,
        "AlertSound", "Default",  ; Default system sound
        "CustomSoundFile", ""     ; Path to custom sound file
    )
    
    ; Predefined system sounds
    static systemSounds := [
        "Default",           ; Default beep
        "Asterisk",         ; Information
        "Exclamation",      ; Warning
        "Hand",             ; Error
        "Question",         ; Question
        "Notification",     ; Windows notification
        "Custom File"       ; Option to use custom file
    ]
    
    static __New() {
        ; Create settings file if it doesn't exist
        if !FileExist(this.settingsFile) {
            this.SaveAllSettings()
        }
    }
    
    ; Get a setting value, returns the default if not found
    static Get(settingName) {
        try {
            value := IniRead(this.settingsFile, "Settings", settingName)
            ; Handle numeric values
            if (settingName = "RefreshInterval")
                return Integer(value)
            ; Handle boolean values
            if (settingName = "AutoUpdate" || settingName = "SkipBetaVersions" 
                || settingName = "AutoRefreshPACS" || settingName = "AudioAlertNewCase" 
                || settingName = "MessageBoxNewCase")
                return value = "1" ? true : false
            ; Return string values as is
            return value
        } catch {
            return this.defaultSettings.Has(settingName) ? this.defaultSettings[settingName] : false
        }
    }
    
    ; Save a setting value
    static Set(settingName, value) {
        ; Handle numeric values
        if (settingName = "RefreshInterval")
            IniWrite(value, this.settingsFile, "Settings", settingName)
        ; Handle boolean values
        else if (settingName = "AutoUpdate" || settingName = "SkipBetaVersions" 
            || settingName = "AutoRefreshPACS" || settingName = "AudioAlertNewCase" 
            || settingName = "MessageBoxNewCase")
            IniWrite(value ? "1" : "0", this.settingsFile, "Settings", settingName)
        ; Handle string values
        else
            IniWrite(value, this.settingsFile, "Settings", settingName)
    }
    
    ; Save all settings to their default values
    static SaveAllSettings() {
        for setting, value in this.defaultSettings {
            this.Set(setting, value)
        }
    }
    
    ; Show settings dialog
    static ShowDialog() {
        ; Create GUI with proper margins
        settingsGui := Gui("+AlwaysOnTop +MinSize320", "PACS Assistant - Settings")
        settingsGui.SetFont("s10", "Segoe UI")
        
        ; Constants for layout
        margin := 20  ; Margin from window edge
        width := 320  ; Total window width
        contentWidth := width - (margin * 2)  ; Width of content area
        
        ; Create checkboxes for each setting
        y := margin
        checkboxes := Map()
        
        ; Updates section
        settingsGui.Add("GroupBox", "x" margin " y" y " w" contentWidth " h80", "Updates")
        checkboxes["AutoUpdate"] := settingsGui.Add("Checkbox", "x" margin+10 " y" y+20, "Automatically check for updates")
        checkboxes["SkipBetaVersions"] := settingsGui.Add("Checkbox", "x" margin+10 " y+10", "Skip beta versions")
        
        ; PACS section
        y += 90
        settingsGui.Add("GroupBox", "x" margin " y" y " w" contentWidth " h100", "PACS")
        checkboxes["AutoRefreshPACS"] := settingsGui.Add("Checkbox", "x" margin+10 " y" y+20, "Auto refresh PACS")
        settingsGui.Add("Text", "x" margin+10 " y+10", "Refresh interval (seconds):")
        refreshIntervalEdit := settingsGui.Add("Edit", "x" margin+10 " y+5 w60 Number", this.Get("RefreshInterval"))
        
        ; Notifications section
        y += 110
        settingsGui.Add("GroupBox", "x" margin " y" y " w" contentWidth " h180", "Notifications")
        checkboxes["AudioAlertNewCase"] := settingsGui.Add("Checkbox", "x" margin+10 " y" y+20, "Play sound on new case")
        checkboxes["MessageBoxNewCase"] := settingsGui.Add("Checkbox", "x" margin+10 " y+10", "Show message box on new case")
        
        ; Sound selection
        settingsGui.Add("Text", "x" margin+10 " y+10", "Alert Sound:")
        soundDropDown := settingsGui.Add("DropDownList", "x" margin+10 " y+5 w" contentWidth-20, this.systemSounds)
        soundDropDown.Value := this.FindSoundIndex(this.Get("AlertSound"))
        
        ; Custom sound file section
        settingsGui.Add("Text", "x" margin+10 " y+10", "Custom Sound File:")
        customSoundEdit := settingsGui.Add("Edit", "x" margin+10 " y+5 w" contentWidth-90 " ReadOnly", this.Get("CustomSoundFile"))
        settingsGui.Add("Button", "x+5 yp w60", "Browse").OnEvent("Click", (*) => this.BrowseSound(customSoundEdit))
        testButton := settingsGui.Add("Button", "x" margin+10 " y+5 w60", "Test")
        testButton.OnEvent("Click", (*) => this.TestSound(soundDropDown.Text, customSoundEdit.Text))
        
        ; Set current values
        for setting, checkbox in checkboxes {
            checkbox.Value := this.Get(setting)
        }
        
        ; Get the position of the Test button and add spacing for Save/Cancel buttons
        testPos := testButton.GetPos()
        y := testPos.y + testPos.h + 20  ; Add 20px spacing after Test button
        
        ; Add Save and Cancel buttons in a centered position
        buttonWidth := 80
        spacing := 10
        totalButtonWidth := (buttonWidth * 2) + spacing
        startX := margin + (contentWidth - totalButtonWidth) // 2
        
        ; Add buttons with proper alignment
        settingsGui.Add("Button", "x" startX " y" y " w" buttonWidth, "Save")
            .OnEvent("Click", (*) => this.SaveSettings(checkboxes, refreshIntervalEdit, soundDropDown, customSoundEdit, settingsGui))
        settingsGui.Add("Button", "x+" spacing " yp w" buttonWidth, "Cancel")
            .OnEvent("Click", (*) => settingsGui.Destroy())
        
        ; Add bottom margin
        y += buttonWidth + margin
        settingsGui.Add("Text", "x" margin " y" y " w0 h0")  ; Invisible control to enforce bottom margin
        
        settingsGui.Show()
    }
    
    ; Find index of sound in systemSounds array
    static FindSoundIndex(sound) {
        loop this.systemSounds.Length {
            if (this.systemSounds[A_Index] = sound)
                return A_Index
        }
        return 1  ; Default if not found
    }
    
    ; Browse for custom sound file
    static BrowseSound(editControl) {
        file := FileSelect(3,, "Select Sound File", "Sound Files (*.wav; *.mp3)")
        if file
            editControl.Value := file
    }
    
    ; Test selected sound
    static TestSound(selectedSound, customFile) {
        if (selectedSound = "Custom File" && customFile) {
            try {
                SoundPlay(customFile)
            } catch {
                MsgBox("Error playing custom sound file.", "Error", "Icon!")
            }
        } else {
            SoundPlay("*" this.GetSystemSoundValue(selectedSound))
        }
    }
    
    ; Get system sound value
    static GetSystemSoundValue(sound) {
        switch sound {
            case "Default": return -1
            case "Asterisk": return 1
            case "Exclamation": return 2
            case "Hand": return 3
            case "Question": return 4
            case "Notification": return 5
            default: return -1
        }
    }
    
    ; Save settings from GUI
    static SaveSettings(checkboxes, refreshIntervalEdit, soundDropDown, customSoundEdit, settingsGui) {
        ; Validate refresh interval
        interval := Integer(refreshIntervalEdit.Value)
        if (interval < 10) {
            MsgBox("Refresh interval must be at least 10 seconds.", "Invalid Setting", "Icon!")
            return
        }
        
        ; Save all checkbox settings
        for setting, checkbox in checkboxes {
            this.Set(setting, checkbox.Value)
        }
        
        ; Save refresh interval
        this.Set("RefreshInterval", interval)
        
        ; Save sound settings
        this.Set("AlertSound", soundDropDown.Text)
        this.Set("CustomSoundFile", customSoundEdit.Text)
        
        settingsGui.Destroy()
        
        ; Notify PACSMonitor of settings change
        if IsSet(PACSMonitor)
            PACSMonitor.OnSettingsChanged()
    }
} 