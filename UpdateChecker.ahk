#Requires AutoHotkey v2.0
#Include Settings.ahk

class UpdateChecker {
    static currentVersion := "v2.0b2"  ; Match this with your current version
    static repoUrl := "https://github.com/rakan959/pacs-assistant"
    static apiUrl := "https://api.github.com/repos/rakan959/pacs-assistant/releases/latest"
    static updateTimer := 0
    
    static Start() {
        ; Check for updates immediately if enabled
        if Settings.Get("AutoUpdate") {
            updateInfo := this.CheckForUpdates()
            if updateInfo.hasUpdate {
                this.ShowUpdateDialog()
            }
        }
        
        ; Set up hourly check if auto-update is enabled
        if Settings.Get("AutoUpdate") {
            this.StartAutoCheck()
        }
    }
    
    static StartAutoCheck() {
        ; Clear any existing timer
        if this.updateTimer {
            SetTimer(this.updateTimer, 0)
            this.updateTimer := 0
        }
        
        ; Set up new timer if auto-update is enabled
        if Settings.Get("AutoUpdate") {
            this.updateTimer := ObjBindMethod(this, "AutoCheck")
            SetTimer(this.updateTimer, 3600000)  ; Check every hour (3600000 ms)
        }
    }
    
    static StopAutoCheck() {
        if this.updateTimer {
            SetTimer(this.updateTimer, 0)
            this.updateTimer := 0
        }
    }
    
    static AutoCheck() {
        updateInfo := this.CheckForUpdates()
        if updateInfo.hasUpdate {
            this.ShowUpdateDialog()
        }
    }
    
    static OnSettingsChanged() {
        ; Restart auto-check with new settings
        this.StartAutoCheck()
    }
    
    ; Parse version string into components
    static ParseVersion(version) {
        ; Remove 'v' prefix if present
        version := RegExReplace(version, "^v", "")
        
        ; Parse version components
        parts := StrSplit(version, ".")
        major := Integer(parts[1])
        minor := parts.Length >= 2 ? Integer(parts[2]) : 0
        
        ; Handle beta versions (e.g., "2.0b", "2.0b2")
        if (RegExMatch(version, "b\d*$")) {
            betaMatch := RegExMatch(version, "b(\d*)", &betaNum)
            isBeta := true
            betaVersion := betaNum[1] != "" ? Integer(betaNum[1]) : 1
        } else {
            isBeta := false
            betaVersion := 0
        }
        
        return {
            major: major,
            minor: minor,
            isBeta: isBeta,
            betaVersion: betaVersion
        }
    }
    
    ; Compare two version strings
    static CompareVersions(v1, v2) {
        v1Info := this.ParseVersion(v1)
        v2Info := this.ParseVersion(v2)
        
        ; Compare major versions
        if (v1Info.major != v2Info.major)
            return v1Info.major < v2Info.major ? -1 : 1
            
        ; Compare minor versions
        if (v1Info.minor != v2Info.minor)
            return v1Info.minor < v2Info.minor ? -1 : 1
            
        ; If one is beta and other is not
        if (v1Info.isBeta && !v2Info.isBeta)
            return -1  ; Beta is older than release
        if (!v1Info.isBeta && v2Info.isBeta)
            return 1   ; Release is newer than beta
            
        ; If both are beta, compare beta versions
        if (v1Info.isBeta && v2Info.isBeta)
            return v1Info.betaVersion < v2Info.betaVersion ? -1 : (v1Info.betaVersion > v2Info.betaVersion ? 1 : 0)
            
        ; Versions are equal
        return 0
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
                
                ; Skip beta versions if enabled in settings
                if (Settings.Get("SkipBetaVersions")) {
                    versionInfo := this.ParseVersion(latestVersion)
                    if (versionInfo.isBeta)
                        return { hasUpdate: false }
                }
                
                ; Compare versions using comparison logic
                if (this.CompareVersions(this.currentVersion, latestVersion) < 0) {
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
        autoUpdateCheckbox.Value := Settings.Get("AutoUpdate")
        
        ; Skip beta versions checkbox
        skipBetaCheckbox := updateGui.Add("Checkbox", "y+5", "Skip beta versions")
        skipBetaCheckbox.Value := Settings.Get("SkipBetaVersions")
        
        ; Buttons
        buttonGroup := updateGui.Add("GroupBox", "y+15 w400 h50")
        updateGui.Add("Button", "xp+10 yp+15 w120", "Update Now").OnEvent("Click", (*) => this.PerformUpdate(updateInfo.downloadUrl, updateGui))
        updateGui.Add("Button", "x+10 w120", "Remind Me Later").OnEvent("Click", (*) => updateGui.Destroy())
        updateGui.Add("Button", "x+10 w120", "Skip This Version").OnEvent("Click", (*) => updateGui.Destroy())
        
        ; Save settings when closing
        updateGui.OnEvent("Close", (*) => (
            Settings.Set("AutoUpdate", autoUpdateCheckbox.Value),
            Settings.Set("SkipBetaVersions", skipBetaCheckbox.Value)
        ))
        
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