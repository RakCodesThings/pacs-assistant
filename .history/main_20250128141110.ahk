#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

#Include KeybindGUI.ahk
#Include UpdateChecker.ahk
#Include PACSMonitor.ahk

; Initialize the update checker
if !Settings.Get("AutoUpdate") {
    ; Show update dialog on first run
    UpdateChecker.ShowUpdateDialog()
} else {
    ; Check for updates silently if automatic updates are enabled
    updateInfo := UpdateChecker.CheckForUpdates()
    if updateInfo.hasUpdate {
        UpdateChecker.ShowUpdateDialog()
    }
}

; Start PACS monitoring
PACSMonitor.Start()

; Initialize the GUI when the script starts
kbGUI := KeybindGUI() 