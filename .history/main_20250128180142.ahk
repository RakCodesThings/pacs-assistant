#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

#Include KeybindGUI.ahk
#Include UpdateChecker.ahk
#Include PACSMonitor.ahk

; Initialize the update checker
UpdateChecker.Start()

; Start PACS monitoring
PACSMonitor.Start()

; Initialize the GUI when the script starts
kbGUI := KeybindGUI() 