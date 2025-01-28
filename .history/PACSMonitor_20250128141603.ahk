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
            
            ; Click refresh button
            msedgeEl := UIA.ElementFromHandle("Explorer Portal ahk_exe msedge.exe")
            msedgeEl.ElementFromPath("Y/YYY/YqYYYVRvrRK").ControlClick()
            
            ; Wait a moment for the refresh to complete
            Sleep(1000)
            
            ; Get current accession numbers
            currentAccessions := []
            msedgeEl := UIA.ElementFromHandle("Explorer Portal ahk_exe msedge.exe")
            for row in msedgeEl.ElementFromPath("Y/YYY/YqYYYVRxrTR") {
                ; Extract accession number (second 8-digit number)
                if RegExMatch(row.Name, "\d{8}.*?(\d{8})", &match) {
                    currentAccessions.Push(match[1])
                }
            }
            
            ; Check for new accessions
            newAccessions := []
            for accession in currentAccessions {
                if !this.HasAccession(accession) {
                    newAccessions.Push(accession)
                    this.knownAccessions.Push(accession)
                }
            }
            
            ; Alert if new accessions found
            if newAccessions.Length > 0 {
                this.AlertNewCases(newAccessions)
            }
            
        } catch as err {
            ; Silent fail - we don't want to interrupt the user with error messages
            ; during background monitoring
        }
    }
    
    static HasAccession(accession) {
        for known in this.knownAccessions {
            if (known = accession)
                return true
        }
        return false
    }
    
    static AlertNewCases(newAccessions) {
        if Settings.Get("AudioAlertNewCase") {
            selectedSound := Settings.Get("AlertSound")
            if (selectedSound = "Custom File") {
                customFile := Settings.Get("CustomSoundFile")
                if customFile && FileExist(customFile)
                    SoundPlay(customFile)
                else
                    SoundPlay("*-1")  ; Fallback to default if custom file not found
            } else {
                SoundPlay("*" Settings.GetSystemSoundValue(selectedSound))
            }
        }
        
        if Settings.Get("MessageBoxNewCase") {
            msg := "New case" (newAccessions.Length > 1 ? "s" : "") " received:`n"
            for accession in newAccessions {
                msg .= accession "`n"
            }
            MsgBox(msg, "New Cases Available", "0x40040")  ; 0x40040 = Info + Always on top
        }
    }
} 