#Requires AutoHotkey v2.0

class UpdateChecker {
    static currentVersion := "v2.0b"  ; Match this with your current version
    static repoUrl := "https://github.com/rakan959/pacs-assistant"
    static apiUrl := "https://api.github.com/repos/rakan959/pacs-assistant/releases/latest"
    static settingsFile := A_ScriptDir "\settings.ini"
    
    static __New() {
        if !FileExist(this.settingsFile)
            this.SaveSettings(false)  ; Default to manual updates
        
        ; Check for updates on launch if automatic updates are enabled
        if this.GetAutoUpdateSetting()
            this.CheckAndShowDialog()
    }
    
    static GetAutoUpdateSetting() {
        return IniRead(this.settingsFile, "Settings", "AutoUpdate", "0") = "1"
    }
    
    static SaveSettings(autoUpdate) {
        IniWrite(autoUpdate ? "1" : "0", this.settingsFile, "Settings", "AutoUpdate")
    }
    
    static CheckAndShowDialog() {
        SetTimer(() => this.ShowUpdateDialog(), -100)  ; Slight delay to allow main GUI to load
    }
    
    static CheckForUpdates() {
        ; Download the latest release info
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", this.apiUrl, true)
            whr.Send()
            whr.WaitForResponse()
            
            if (whr.Status = 200) {
                response := Jsons.Load(whr.ResponseText)
                latestVersion := response.tag_name
                
                ; Compare versions
                if (latestVersion != this.currentVersion) {
                    ; Find the .exe asset in the release
                    downloadUrl := ""
                    for asset in response.assets {
                        if (InStr(asset.name, ".exe")) {
                            downloadUrl := asset.browser_download_url
                            break
                        }
                    }
                    
                    if (downloadUrl = "")
                        return { hasUpdate: false }
                        
                    return {
                        hasUpdate: true,
                        currentVersion: this.currentVersion,
                        latestVersion: latestVersion,
                        downloadUrl: downloadUrl,
                        releaseNotes: response.body
                    }
                }
            }
        }
        return { hasUpdate: false }
    }
    
    static ShowUpdateDialog() {
        updateInfo := this.CheckForUpdates()
        if (!updateInfo.hasUpdate)
            return
            
        ; Create update dialog with modern styling
        updateGui := Gui("+AlwaysOnTop", "PACS Assistant - Update Available")
        updateGui.SetFont("s10", "Segoe UI")  ; Modern font
        
        ; Header
        updateGui.Add("Text", "y10 w400", "A new version of PACS Assistant is available!")
        updateGui.Add("Text", "y+10", "Current version: " updateInfo.currentVersion)
        updateGui.Add("Text", "y+5", "Latest version: " updateInfo.latestVersion)
        
        ; Release notes with better formatting
        updateGui.Add("Text", "y+15", "What's New:")
        updateGui.Add("Edit", "y+5 r10 w400 ReadOnly", updateInfo.releaseNotes)
        
        ; Auto-update checkbox
        autoUpdateCheckbox := updateGui.Add("Checkbox", "y+10", "Automatically check for updates on launch")
        autoUpdateCheckbox.Value := this.GetAutoUpdateSetting()
        
        ; Buttons
        buttonGroup := updateGui.Add("GroupBox", "y+15 w400 h50")
        updateGui.Add("Button", "xp+10 yp+15 w120", "Update Now").OnEvent("Click", (*) => this.PerformUpdate(updateInfo.downloadUrl, updateGui))
        updateGui.Add("Button", "x+10 w120", "Remind Me Later").OnEvent("Click", (*) => updateGui.Destroy())
        updateGui.Add("Button", "x+10 w120", "Skip This Version").OnEvent("Click", (*) => updateGui.Destroy())
        
        ; Save auto-update setting when closing
        updateGui.OnEvent("Close", (*) => this.SaveSettings(autoUpdateCheckbox.Value))
        
        updateGui.Show()
    }
    
    static PerformUpdate(downloadUrl, updateGui) {
        try {
            ; Get the current executable path
            currentExe := A_ScriptFullPath
            backupExe := A_ScriptDir "\pacs-assistant.backup.exe"
            newExe := A_ScriptDir "\pacs-assistant.new.exe"
            
            ; Create backup of current executable
            if FileExist(currentExe)
                FileCopy(currentExe, backupExe, true)
                
            ; Download new version
            Download(downloadUrl, newExe)
            
            ; Create a batch file to perform the update after this process exits
            batchScript := "
            (
            @echo off
            timeout /t 1 /nobreak >nul
            move /y `"" newExe "`" `"" currentExe "`"
            start `"`" `"" currentExe "`"
            del `"%~f0`"
            )"
            
            FileAppend(batchScript, "update.bat")
            
            ; Run the update batch file and exit this process
            Run("update.bat", , "Hide")
            updateGui.Destroy()
            ExitApp
        } catch as err {
            MsgBox("Update failed: " err.Message, "Error", "Icon!")
            ; Restore from backup if it exists
            if FileExist(backupExe)
                FileMove(backupExe, currentExe, true)
        }
    }
}

; Simple JSON parser
class Jsons {
    static Load(text) {
        text := Trim(text)
        if !(text ~= "^[{[]") || !(text ~= "[}\]]$")
            throw Error("Invalid JSON")
        
        return this.Parse(&text)
    }
    
    static Parse(&text) {
        text := Trim(text)
        switch SubStr(text, 1, 1) {
            case "{":
                obj := Map()
                text := SubStr(text, 2)
                loop {
                    text := Trim(text)
                    if (SubStr(text, 1, 1) = "}")
                        break
                    key := this.Parse(&text)
                    text := Trim(text)
                    if (SubStr(text, 1, 1) != ":")
                        throw Error("Expected ':'")
                    text := Trim(SubStr(text, 2))
                    value := this.Parse(&text)
                    obj[key] := value
                    text := Trim(text)
                    if (SubStr(text, 1, 1) = "}")
                        break
                    if (SubStr(text, 1, 1) != ",")
                        throw Error("Expected ',' or '}'")
                    text := SubStr(text, 2)
                }
                text := SubStr(text, 2)
                return obj
            case "[":
                arr := []
                text := SubStr(text, 2)
                loop {
                    text := Trim(text)
                    if (SubStr(text, 1, 1) = "]")
                        break
                    value := this.Parse(&text)
                    arr.Push(value)
                    text := Trim(text)
                    if (SubStr(text, 1, 1) = "]")
                        break
                    if (SubStr(text, 1, 1) != ",")
                        throw Error("Expected ',' or ']'")
                    text := SubStr(text, 2)
                }
                text := SubStr(text, 2)
                return arr
            case '"':
                pos := 2
                while (pos := InStr(text, '"',, pos)) {
                    if (SubStr(text, pos-1, 1) != "\")
                        break
                    pos++
                }
                if (!pos)
                    throw Error("Missing closing quote")
                value := SubStr(text, 2, pos-2)
                text := SubStr(text, pos+1)
                return value
            default:
                if (text ~= "^(true|false|null|-?\d+\.?\d*([eE][+-]?\d+)?)")
                    return SubStr(text, 1, RegExMatch(text, "[\s,}\]]|$")-1)
                throw Error("Invalid value")
        }
    }
} 