#Requires AutoHotkey v2.0

#Include HotkeyManager.ahk
#Include ProfileManager.ahk
#Include PACSCommands.ahk

class KeybindGUI {
    gui := ""
    static isListening := false
    static listeningControl := ""

    __New() {
        ProfileManager.LoadProfiles()
        if ProfileManager.profiles.Count = 0 {
            this.PromptNewProfile()
        } else {
            this.ShowProfileSelector()
        }
    }

    CreateMainGUI() {
        this.gui := Gui("+AlwaysOnTop", "PACS Assistant - " ProfileManager.currentProfile)
        this.gui.Add("Text",, "Current Profile: " ProfileManager.currentProfile)
        
        this.gui.Add("Text", "xm y+20", "Keybinds:")
        y := 70
        
        for funcName, bind in ProfileManager.profiles[ProfileManager.currentProfile] {
            this.gui.Add("Text", "xm y" y, funcName)
            bindBox := this.gui.Add("Edit", "x+10 yp-2 w100 ReadOnly", this.PrettifyHotkey(bind))
            this.gui.Add("Button", "x+5 yp w60", "Change").OnEvent("Click", this.StartListening.Bind(this, bindBox, funcName))
            y += 30
        }
        
        this.gui.Add("Button", "xm y+20", "Save").OnEvent("Click", (*) => this.SaveCurrentProfile())
        this.gui.Add("Button", "x+10", "Switch Profile").OnEvent("Click", (*) => (this.gui.Destroy(), this.ShowProfileSelector()))
        
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.Show()
        
        this.ApplyBinds()
    }

    ShowProfileSelector() {
        selectorGui := Gui("+AlwaysOnTop", "Profile Selector")
        selectorGui.Add("Text",, "Select profile:")
        
        ; Add profiles listbox
        profileNames := []
        for name, _ in ProfileManager.profiles
            profileNames.Push(name)
        lb := selectorGui.Add("ListBox", "w200 h150", profileNames)
        
        ; If there's a default profile, select it in the listbox
        if (ProfileManager.defaultProfile != "") {
            for i, name in profileNames {
                if (name = ProfileManager.defaultProfile) {
                    lb.Choose(i)
                    break
                }
            }
        }
        
        ; Add buttons
        buttonGroup := selectorGui.Add("GroupBox", "w190 h120", "Actions")
        
        selectorGui.Add("Button", "xp+10 yp+20 w170", "Select").OnEvent("Click", (*) => this.SelectProfile(lb.Text, selectorGui))
        selectorGui.Add("Button", "w170", "Set as Default").OnEvent("Click", (*) => this.SetDefaultProfile(lb.Text, selectorGui))
        selectorGui.Add("Button", "w170", "Delete Profile").OnEvent("Click", (*) => this.DeleteProfile(lb.Text, selectorGui))
        selectorGui.Add("Button", "w170", "New Profile").OnEvent("Click", (*) => (selectorGui.Destroy(), this.PromptNewProfile()))
        
        ; Add status text
        if (ProfileManager.defaultProfile != "")
            selectorGui.Add("Text", "y+10", "Default Profile: " ProfileManager.defaultProfile)
        
        selectorGui.Show()
    }

    PromptNewProfile() {
        inputGui := Gui("+AlwaysOnTop")
        inputGui.Add("Text",, "Enter profile name:")
        nameEdit := inputGui.Add("Edit", "w200")
        inputGui.Add("Button",, "OK").OnEvent("Click", (*) => this.CreateProfile(nameEdit.Value, inputGui))
        inputGui.Show()
    }

    CreateProfile(name, inputGui) {
        if name != "" {
            ProfileManager.profiles[name] := ProfileManager.defaultBinds.Clone()
            ProfileManager.SaveProfile(name, ProfileManager.profiles[name])
            ProfileManager.currentProfile := name
            inputGui.Destroy()
            this.CreateMainGUI()
        }
    }

    SelectProfile(name, selectorGui) {
        if name != "" {
            ProfileManager.currentProfile := name
            selectorGui.Destroy()
            this.CreateMainGUI()
        }
    }

    SetDefaultProfile(name, selectorGui) {
        if (name = "") {
            MsgBox("Please select a profile first.", "Error", "Icon!")
            return
        }

        if (ProfileManager.SetDefaultProfile(name)) {
            selectorGui.Destroy()
            this.ShowProfileSelector()  ; Refresh the selector to show updated default
        } else {
            MsgBox("Failed to set default profile.", "Error", "Icon!")
        }
    }

    DeleteProfile(name, selectorGui) {
        if (name = "") {
            MsgBox("Please select a profile first.", "Error", "Icon!")
            return
        }

        if (MsgBox("Are you sure you want to delete profile '" name "'?", "Confirm Delete", "YesNo Icon!") = "Yes") {
            if (ProfileManager.DeleteProfile(name)) {
                if (name = ProfileManager.currentProfile) {
                    ; If we deleted the current profile, switch to another one
                    for newName, _ in ProfileManager.profiles {
                        if (newName != name) {
                            ProfileManager.currentProfile := newName
                            break
                        }
                    }
                }
                selectorGui.Destroy()
                this.ShowProfileSelector()  ; Refresh the selector
            } else {
                MsgBox("Cannot delete the last remaining profile.", "Error", "Icon!")
            }
        }
    }

    StartListening(control, funcName, *) {
        if KeybindGUI.isListening
            return
        
        KeybindGUI.isListening := true
        KeybindGUI.listeningControl := control
        control.Value := "Press keys..."
        
        ih := InputHook("V B")  ; Added 'B' option to suppress the beep
        ih.KeyOpt("{All}", "E")
        ih.OnEnd := this.OnInputEnd.Bind(this, funcName, control)
        ih.Start()
    }

    OnInputEnd(funcName, control, ih) {
        ; Get current state of modifier keys
        hasCtrl := GetKeyState("Ctrl")
        hasAlt := GetKeyState("Alt")
        hasShift := GetKeyState("Shift")
        hasWin := GetKeyState("LWin") || GetKeyState("RWin")
        
        key := ih.EndKey
        
        ; Handle Escape to cancel
        if (key = "Escape") {
            this.StopListening()
            control.Value := this.PrettifyHotkey(ProfileManager.profiles[ProfileManager.currentProfile][funcName])
            return
        }
        
        ; Skip if the key is just a modifier
        if key ~= "^[LR]?(Control|Alt|Shift|Win)$" {
            ih.Start()  ; Restart listening if it was just a modifier
            return
        }
        
        ; Build the hotkey string
        modifiers := ""
        modifiers .= hasCtrl ? "^" : ""
        modifiers .= hasAlt ? "!" : ""
        modifiers .= hasShift ? "+" : ""
        modifiers .= hasWin ? "#" : ""
        
        newBind := modifiers key
        ProfileManager.profiles[ProfileManager.currentProfile][funcName] := newBind
        control.Value := this.PrettifyHotkey(newBind)
        this.StopListening()
        this.ApplyBinds()
    }

    StopListening() {
        KeybindGUI.isListening := false
        KeybindGUI.listeningControl := ""
    }

    SaveCurrentProfile() {
        ProfileManager.SaveProfile(ProfileManager.currentProfile, ProfileManager.profiles[ProfileManager.currentProfile])
        MsgBox("Profile saved successfully!", "Success")
    }

    ApplyBinds() {
        HotkeyManager.DisableAllHotkeys()
        for funcName, bind in ProfileManager.profiles[ProfileManager.currentProfile] {
            HotkeyManager.RegisterHotkey(funcName, bind)
        }
    }

    PrettifyHotkey(hotkeyStr) {
        modifiers := ""
        key := hotkeyStr
        
        ; Extract modifiers in order
        if (InStr(key, "^")) {
            modifiers .= "Ctrl + "
            key := StrReplace(key, "^")
        }
        if (InStr(key, "!")) {
            modifiers .= "Alt + "
            key := StrReplace(key, "!")
        }
        if (InStr(key, "+")) {
            modifiers .= "Shift + "
            key := StrReplace(key, "+")
        }
        if (InStr(key, "#")) {
            modifiers .= "Win + "
            key := StrReplace(key, "#")
        }
        
        ; Capitalize the key
        key := Format("{:U}", key)
        
        return modifiers key
    }
} 