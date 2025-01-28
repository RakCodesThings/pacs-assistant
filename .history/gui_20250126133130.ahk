#Requires AutoHotkey v2.0

#SingleInstance Force
#Warn All, Off

; Initialize static variables before class definition
global profiles := Map()
global currentProfile := ""
global defaultBinds := Map("toggleDictation", "F16")
global activeHotkeys := Map()
global isListening := false
global listeningControl := ""

class KeybindGUI {
    gui := ""  ; Make gui an instance property
    
    __New() {
        this.LoadProfiles()
        if profiles.Count = 0 {
            this.PromptNewProfile()
        } else {
            this.ShowProfileSelector()
        }
    }
    
    LoadProfiles() {
        try {
            Loop Files "profiles/*.ini" {
                profileName := StrReplace(A_LoopFileName, ".ini")
                profiles[profileName] := this.LoadProfile(A_LoopFilePath)
            }
        }
    }
    
    LoadProfile(path) {
        binds := Map()
        try {
            IniRead(path)
            for funcName, defaultBind in defaultBinds {
                binds[funcName] := IniRead(path, "Keybinds", funcName, defaultBind)
            }
        }
        return binds
    }
    
    SaveProfile(name, binds) {
        if !DirExist("profiles")
            DirCreate("profiles")
        
        path := "profiles/" name ".ini"
        for funcName, bind in binds {
            IniWrite(bind, path, "Keybinds", funcName)
        }
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
            profiles[name] := defaultBinds.Clone()
            this.SaveProfile(name, profiles[name])
            currentProfile := name
            inputGui.Destroy()
            this.CreateMainGUI()
        }
    }
    
    ShowProfileSelector() {
        selectorGui := Gui("+AlwaysOnTop")
        selectorGui.Add("Text",, "Select profile:")
        profileNames := []
        for name, _ in profiles
            profileNames.Push(name)
        lb := selectorGui.Add("ListBox", "w200", profileNames)
        selectorGui.Add("Button",, "Select").OnEvent("Click", (*) => this.SelectProfile(lb.Text, selectorGui))
        selectorGui.Add("Button",, "New Profile").OnEvent("Click", (*) => (selectorGui.Destroy(), this.PromptNewProfile()))
        selectorGui.Show()
    }
    
    SelectProfile(name, selectorGui) {
        if name != "" {
            currentProfile := name
            selectorGui.Destroy()
            this.CreateMainGUI()
        }
    }
    
    CreateMainGUI() {
        this.gui := Gui("+AlwaysOnTop", "PACS Assistant - " currentProfile)
        this.gui.Add("Text",, "Current Profile: " currentProfile)
        
        this.gui.Add("Text", "xm y+20", "Keybinds:")
        y := 70
        
        for funcName, bind in profiles[currentProfile] {
            this.gui.Add("Text", "xm y" y, funcName)
            bindBox := this.gui.Add("Edit", "x+10 yp-2 w100 ReadOnly", bind)
            bindBox.OnEvent("Click", this.StartListening.Bind(this, bindBox, funcName))
            y += 30
        }
        
        this.gui.Add("Button", "xm y+20", "Save").OnEvent("Click", this.SaveCurrentProfile.Bind(this))
        this.gui.Add("Button", "x+10", "Switch Profile").OnEvent("Click", (*) => (this.gui.Destroy(), this.ShowProfileSelector()))
        
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.Show()
        
        this.ApplyBinds()
    }
    
    StartListening(control, funcName, *) {
        if this.isListening
            return
        
        this.isListening := true
        this.listeningControl := control
        control.Value := "Press keys..."
        
        ih := InputHook("L1 V")
        ih.KeyOpt("{All}", "E")
        ih.Start()
        
        SetTimer(() => this.ListenForKeys(ih, funcName), 10)
    }
    
    ListenForKeys(ih, funcName) {
        if !this.isListening {
            SetTimer(, 0)
            return
        }
        
        if GetKeyState("Escape") {
            this.StopListening()
            this.listeningControl.Value := profiles[currentProfile][funcName]
            return
        }
        
        if GetKeyState("LButton") {
            return
        }
        
        modifiers := ""
        modifiers .= GetKeyState("Ctrl") ? "^" : ""
        modifiers .= GetKeyState("Alt") ? "!" : ""
        modifiers .= GetKeyState("Shift") ? "+" : ""
        modifiers .= GetKeyState("Win") ? "#" : ""
        
        for key in ["Ctrl", "Alt", "Shift", "Win", "Escape", "LButton"]
            if GetKeyState(key)
                return
        
        keys := ih.EndKeys
        if keys.Length > 0 {
            newBind := modifiers keys[1]
            profiles[currentProfile][funcName] := newBind
            this.listeningControl.Value := newBind
            this.StopListening()
            this.ApplyBinds()
        }
    }
    
    StopListening() {
        this.isListening := false
        this.listeningControl := ""
    }
    
    SaveCurrentProfile() {
        this.SaveProfile(currentProfile, profiles[currentProfile])
        MsgBox("Profile saved successfully!", "Success")
    }
    
    ApplyBinds() {
        for funcName, hotkey in this.activeHotkeys {
            Hotkey(hotkey, "Off")
        }
        this.activeHotkeys := Map()
        
        for funcName, bind in profiles[currentProfile] {
            try {
                Hotkey(bind, %funcName%)
                this.activeHotkeys[funcName] := bind
            }
        }
    }
}

; Initialize the GUI when the script starts
KeybindGUI()
