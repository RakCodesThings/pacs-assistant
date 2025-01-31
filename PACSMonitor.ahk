#Requires AutoHotkey v2.0
#Include UIA-v2/Lib/UIA.ahk

class PACSMonitor {
    static knownAccessions := []
    static refreshTimer := 0
    
    static Start() {
        ; Clear known accessions
        this.knownAccessions := []
        
        ; Start monitoring if enabled
        if Settings.Get("AutoRefreshPACS") {
            this.StartMonitoring()
        }
    }
    
    static StartMonitoring() {
        ; Clear any existing timer
        if this.refreshTimer {
            SetTimer(this.refreshTimer, 0)
            this.refreshTimer := 0
        }
        
        ; Set up new timer if auto-refresh is enabled
        if Settings.Get("AutoRefreshPACS") {
            interval := Settings.Get("RefreshInterval") * 1000  ; Convert to milliseconds
            this.refreshTimer := ObjBindMethod(this, "RefreshAndCheck")
            SetTimer(this.refreshTimer, interval)
            
            ; Do an initial refresh
            this.RefreshAndCheck()
        }
    }
    
    static StopMonitoring() {
        if this.refreshTimer {
            SetTimer(this.refreshTimer, 0)
            this.refreshTimer := 0
        }
    }
    
    static OnSettingsChanged() {
        ; Restart monitoring with new settings
        this.StartMonitoring()
    }
    
    static RefreshAndCheck() {
        try {
            ; Try to get the Explorer Portal window
            if !WinExist("Explorer Portal ahk_exe msedge.exe") {
                return  ; Portal not open, skip this check
            }
            
            ; Skip refresh if Explorer Portal is the active window
            if WinActive("Explorer Portal ahk_exe msedge.exe") {
                return  ; Don't refresh when user is actively using the portal
            }
            
            ; Store the currently active window
            previousWindow := WinExist("A")
            
            ; Click refresh button
            msedgeEl := UIA.ElementFromHandle("Explorer Portal ahk_exe msedge.exe")
            msedgeEl.ElementFromPath("Y/YYY/YqYYYVRvrRK").ControlClick()

            ; Restore the previously active window
            if IsSet(previousWindow) && previousWindow && WinExist(previousWindow) {
                WinActivate("ahk_id " previousWindow)
            }

            ; Wait a moment for the refresh to complete
            Sleep(1000)
            
            ; Get current accession numbers and study info
            currentStudies := []
            msedgeEl := UIA.ElementFromHandle("Explorer Portal ahk_exe msedge.exe")
            for row in msedgeEl.ElementFromPath("Y/YYY/YqYYYVRxrTR") {
                ; Extract study type and accession numbers
                rowText := row.Name
                ; Find any accession numbers
                accessions := []
                pos := 1
                while pos := RegExMatch(rowText, "\d{8}", &accMatch, pos) {
                    accessions.Push(accMatch[0])
                    pos += accMatch.Len
                }
                
                ; Find study type (any uppercase string that starts with two letters)
                if RegExMatch(rowText, "[A-Z]{2}\s[A-Z\s]+?(?=\s+\d|$)", &studyMatch) {
                    studyType := Trim(studyMatch[0])
                    
                    ; Add entry for each new accession
                    for acc in accessions {
                        if !this.HasAccession(acc) {
                            currentStudies.Push({
                                studyType: studyType,
                                accession: acc
                            })
                        }
                    }
                }
            }
            
            ; Add new studies to known accessions and prepare notifications
            newStudies := []
            for study in currentStudies {
                newStudies.Push(study)
                this.knownAccessions.Push(study.accession)
            }
            
            ; Alert if new studies found
            if newStudies.Length > 0 {
                this.AlertNewCases(newStudies)
            }
            
        } catch as err {
            ; Silent fail - we don't want to interrupt the user with error messages
            ; during background monitoring
            
            ; Still try to restore the active window if we have it
            if IsSet(previousWindow) && previousWindow && WinExist(previousWindow) {
                WinActivate("ahk_id " previousWindow)
            }
        }
    }
    
    static HasAccession(accession) {
        for known in this.knownAccessions {
            if (known = accession)
                return true
        }
        return false
    }
    
    static AlertNewCases(newStudies) {
        if Settings.Get("AudioAlertNewCase") {
            selectedSound := Settings.Get("AlertSound")
            if (selectedSound = "Custom File") {
                customFile := Settings.Get("CustomSoundFile")
                if customFile && FileExist(customFile)
                    SoundPlay(customFile)
                else
                    SoundPlay("*-1")  ; Fallback to default if custom file not found
            } else {
                SoundPlay(Settings.GetSystemSoundValue(selectedSound))
            }
        }
        
        if Settings.Get("MessageBoxNewCase") {
            ; Create a TrayTip for each new study
            for study in newStudies {
                TrayTip("New Study Available", study.studyType, "Iconi")
            }
            
            ; If there are multiple studies, show a summary notification
            if newStudies.Length > 1 {
                Sleep(1000)  ; Wait a bit to not overlap notifications
                TrayTip("Multiple New Studies", 
                       newStudies.Length " new studies available",
                       "Iconi")
            }
        }
    }
} 
