#Requires AutoHotkey v2.0

#SingleInstance Force
#Warn All, Off

; Initialize static variables before class definition
global profiles := Map()
global currentProfile := ""
global defaultBinds := Map(
    "toggleDictation", "F16",
    "testFunction", "^!x"
)
global activeHotkeys := Map()
global isListening := false
global listeningControl := ""

; Create global function objects
global hotkeyFunctions := Map()
hotkeyFunctions["toggleDictation"] := (*) => MsgBox("Toggling Dictation", "Dictation")
hotkeyFunctions["testFunction"] := (*) => MsgBox("Hello", "Test Function")

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
            global currentProfile := name
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
            global currentProfile := name
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
    
    StartListening(control, funcName, *) {
        global isListening
        if isListening
            return
        
        isListening := true
        this.listeningControl := control
        control.Value := "Press keys..."
        
        ih := InputHook("V B")  ; Added 'B' option to suppress the beep
        ih.KeyOpt("{All}", "E")
        ih.OnEnd := this.OnInputEnd.Bind(this, funcName, control)
        ih.Start()
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
            control.Value := this.PrettifyHotkey(profiles[currentProfile][funcName])
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
        profiles[currentProfile][funcName] := newBind
        control.Value := this.PrettifyHotkey(newBind)
        this.StopListening()
        this.ApplyBinds()
    }
    
    StopListening() {
        global isListening
        isListening := false
        this.listeningControl := ""
    }
    
    SaveCurrentProfile() {
        this.SaveProfile(currentProfile, profiles[currentProfile])
        MsgBox("Profile saved successfully!", "Success")
    }
    
    ApplyBinds() {
        global activeHotkeys, hotkeyFunctions
        for funcName, hotkey in activeHotkeys {
            try {
                Hotkey(hotkey, "Off")
            } catch as err {
                MsgBox("Error disabling hotkey: " hotkey "`nError: " err.Message)
            }
        }
        activeHotkeys := Map()
        
        for funcName, bind in profiles[currentProfile] {
            try {
                MsgBox("Attempting to bind: " funcName " to " bind)
                testFunction()
                Hotkey bind, (bind) => MsgBox(bind)
                MsgBox("Bound: " funcName " to " bind)
                activeHotkeys[funcName] := bind
            } catch as err {
                MsgBox("Error setting hotkey: " bind " for " funcName "`nError: " err.Message)
            }
        }
    }
}

; Initialize the GUI when the script starts
kbGUI := KeybindGUI()
