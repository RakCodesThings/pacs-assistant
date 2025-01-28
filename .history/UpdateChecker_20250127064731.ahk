#Requires AutoHotkey v2.0

class UpdateChecker {
    static currentVersion := "v2.0b"  ; Match this with your current version
    static repoUrl := "https://github.com/rakan959/pacs-assistant"
    static apiUrl := "https://api.github.com/repos/rakan959/pacs-assistant/releases/latest"
    
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
            
        ; Create update dialog
        updateGui := Gui(, "PACS Assistant - Update Available")
        updateGui.Add("Text",, "A new version is available!")
        updateGui.Add("Text",, "Current version: " updateInfo.currentVersion)
        updateGui.Add("Text",, "Latest version: " updateInfo.latestVersion)
        
        ; Add release notes
        updateGui.Add("Text", "y+10", "Release Notes:")
        updateGui.Add("Edit", "r5 w400 ReadOnly", updateInfo.releaseNotes)
        
        ; Add update button
        updateGui.Add("Button", "y+10 w120", "Update Now").OnEvent("Click", (*) => this.PerformUpdate(updateInfo.downloadUrl, updateGui))
        updateGui.Add("Button", "x+10 w120", "Cancel").OnEvent("Click", (*) => updateGui.Destroy())
        
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