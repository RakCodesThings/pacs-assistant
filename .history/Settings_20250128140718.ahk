#Requires AutoHotkey v2.0

class Settings {
    static settingsFile := A_ScriptDir "\settings.ini"
    static defaultSettings := Map(
        "AutoUpdate", false,
        "SkipBetaVersions", true,
        "AutoRefreshPACS", false,
        "AudioAlertNewCase", false,
        "MessageBoxNewCase", false
    )
    
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
            return value = "1" ? true : false
        } catch {
            return this.defaultSettings.Has(settingName) ? this.defaultSettings[settingName] : false
        }
    }
    
    ; Save a setting value
    static Set(settingName, value) {
        IniWrite(value ? "1" : "0", this.settingsFile, "Settings", settingName)
    }
    
    ; Save all settings to their default values
    static SaveAllSettings() {
        for setting, value in this.defaultSettings {
            this.Set(setting, value)
        }
    }
    
    ; Show settings dialog
    static ShowDialog() {
        settingsGui := Gui("+AlwaysOnTop", "PACS Assistant - Settings")
        settingsGui.SetFont("s10", "Segoe UI")
        
        ; Create checkboxes for each setting
        y := 10
        checkboxes := Map()
        
        ; Updates section
        settingsGui.Add("GroupBox", "x10 y" y " w300 h80", "Updates")
        checkboxes["AutoUpdate"] := settingsGui.Add("Checkbox", "x20 y" (y+20), "Automatically check for updates")
        checkboxes["SkipBetaVersions"] := settingsGui.Add("Checkbox", "x20 y+10", "Skip beta versions")
        
        ; PACS section
        y += 90
        settingsGui.Add("GroupBox", "x10 y" y " w300 h60", "PACS")
        checkboxes["AutoRefreshPACS"] := settingsGui.Add("Checkbox", "x20 y" (y+20), "Auto refresh PACS")
        
        ; Notifications section
        y += 70
        settingsGui.Add("GroupBox", "x10 y" y " w300 h80", "Notifications")
        checkboxes["AudioAlertNewCase"] := settingsGui.Add("Checkbox", "x20 y" (y+20), "Play sound on new case")
        checkboxes["MessageBoxNewCase"] := settingsGui.Add("Checkbox", "x20 y+10", "Show message box on new case")
        
        ; Set current values
        for setting, checkbox in checkboxes {
            checkbox.Value := this.Get(setting)
        }
        
        ; Add Save and Cancel buttons
        y += 90
        settingsGui.Add("Button", "x70 y" y " w80", "Save").OnEvent("Click", (*) => this.SaveSettings(checkboxes, settingsGui))
        settingsGui.Add("Button", "x+20 w80", "Cancel").OnEvent("Click", (*) => settingsGui.Destroy())
        
        settingsGui.Show()
    }
    
    ; Save settings from GUI
    static SaveSettings(checkboxes, settingsGui) {
        for setting, checkbox in checkboxes {
            this.Set(setting, checkbox.Value)
        }
        settingsGui.Destroy()
    }
} 