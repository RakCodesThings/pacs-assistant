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
        selectorGui := Gui("+AlwaysOnTop")
        selectorGui.Add("Text",, "Select profile:")
        profileNames := []
        for name, _ in ProfileManager.profiles
            profileNames.Push(name)
        lb := selectorGui.Add("ListBox", "w200", profileNames)
        selectorGui.Add("Button",, "Select").OnEvent("Click", (*) => this.SelectProfile(lb.Text, selectorGui))
        selectorGui.Add("Button",, "New Profile").OnEvent("Click", (*) => (selectorGui.Destroy(), this.PromptNewProfile()))
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