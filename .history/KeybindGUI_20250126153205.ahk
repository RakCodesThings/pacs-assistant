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
        this.gui := Gui(, "PACS Assistant - " ProfileManager.currentProfile)
        this.gui.Add("Text",, "Current Profile: " ProfileManager.currentProfile)
        
        ; Add rename button next to profile name
        this.gui.Add("Button", "x+10 yp-4 w60", "Rename").OnEvent("Click", (*) => this.PromptRenameProfile(ProfileManager.currentProfile))
        
        this.gui.Add("Text", "xm y+20", "Active Keybinds:")
        y := 70
        
        ; Create ListView for keybinds
        lv := this.gui.Add("ListView", "xm y" y " w400 h200", ["Function", "Keybind"])
        
        ; Populate ListView with current bindings
        for funcName, bind in ProfileManager.profiles[ProfileManager.currentProfile] {
            lv.Add(, funcName, this.PrettifyHotkey(bind))
        }
        
        ; Add buttons below ListView
        y += 210
        this.gui.Add("Button", "xm y" y " w120", "Add Function").OnEvent("Click", (*) => this.ShowAddFunctionDialog(lv))
        this.gui.Add("Button", "x+10 yp w120", "Remove Function").OnEvent("Click", (*) => this.RemoveFunction(lv))
        this.gui.Add("Button", "x+10 yp w120", "Change Keybind").OnEvent("Click", (*) => this.ChangeSelectedKeybind(lv))
        
        ; Add profile management buttons
        y += 30
        this.gui.Add("Button", "xm y" y, "Save").OnEvent("Click", (*) => this.SaveCurrentProfile())
        this.gui.Add("Button", "x+10", "Switch Profile").OnEvent("Click", (*) => (this.gui.Destroy(), this.ShowProfileSelector()))
        
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.Show()
        
        this.ApplyBinds()
    }

    ShowProfileSelector() {
        selectorGui := Gui(, "Profile Selector")
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
        buttonGroup := selectorGui.Add("GroupBox", "w190 h150", "Actions")  ; Made group box taller
        
        selectorGui.Add("Button", "xp+10 yp+20 w170", "Select").OnEvent("Click", (*) => this.SelectProfile(lb.Text, selectorGui))
        selectorGui.Add("Button", "w170", "Set as Default").OnEvent("Click", (*) => this.SetDefaultProfile(lb.Text, selectorGui))
        selectorGui.Add("Button", "w170", "Rename").OnEvent("Click", (*) => this.PromptRenameProfile(lb.Text, selectorGui))
        selectorGui.Add("Button", "w170", "Delete Profile").OnEvent("Click", (*) => this.DeleteProfile(lb.Text, selectorGui))
        selectorGui.Add("Button", "w170", "New Profile").OnEvent("Click", (*) => (selectorGui.Destroy(), this.PromptNewProfile()))
        
        ; Add status text
        if (ProfileManager.defaultProfile != "")
            selectorGui.Add("Text", "y+10", "Default Profile: " ProfileManager.defaultProfile)
        
        selectorGui.Show()
    }

    PromptNewProfile() {
        inputGui := Gui()
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

        ; Check if this hotkey is already assigned to another function
        for otherFunc, otherBind in ProfileManager.profiles[ProfileManager.currentProfile] {
            if (otherFunc != funcName && otherBind = newBind) {
                MsgBox("This hotkey is already assigned to '" otherFunc "'", "Duplicate Binding", "Icon!")
                this.StopListening()
                control.Value := this.PrettifyHotkey(ProfileManager.profiles[ProfileManager.currentProfile][funcName])
                return
            }
        }
        
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
        if (hotkeyStr = "")
            return "Unassigned"
            
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

    PromptRenameProfile(name, parentGui := 0) {
        if (name = "") {
            MsgBox("Please select a profile first.", "Error", "Icon!")
            return
        }

        renameGui := Gui()
        renameGui.Add("Text",, "Enter new name for profile '" name "':")
        nameEdit := renameGui.Add("Edit", "w200", name)
        renameGui.Add("Button",, "OK").OnEvent("Click", (*) => this.RenameProfile(name, nameEdit.Value, renameGui, parentGui))
        renameGui.Add("Button", "x+10", "Cancel").OnEvent("Click", (*) => renameGui.Destroy())
        renameGui.Show()
    }

    RenameProfile(oldName, newName, renameGui, parentGui := 0) {
        if (newName = "") {
            MsgBox("Profile name cannot be empty.", "Error", "Icon!")
            return
        }

        if (ProfileManager.RenameProfile(oldName, newName)) {
            renameGui.Destroy()
            if (parentGui) {
                parentGui.Destroy()
                this.ShowProfileSelector()  ; Refresh the selector
            } else {
                this.gui.Destroy()
                this.CreateMainGUI()  ; Refresh the main GUI
            }
        } else {
            MsgBox("Failed to rename profile. The name may already be in use.", "Error", "Icon!")
        }
    }

    UnassignHotkey(control, funcName, *) {
        ProfileManager.profiles[ProfileManager.currentProfile][funcName] := ""
        control.Value := "Unassigned"
        this.ApplyBinds()
    }

    ShowAddFunctionDialog(listView) {
        ; Get list of unbound functions
        unboundFunctions := []
        for funcName, _ in ProfileManager.availableFunctions {
            if !ProfileManager.profiles[ProfileManager.currentProfile].Has(funcName) {
                unboundFunctions.Push(funcName)
            }
        }
        
        if (unboundFunctions.Length = 0) {
            MsgBox("All functions are already bound!", "No Functions Available", "Icon!")
            return
        }
        
        ; Create function selector dialog
        selectorGui := Gui()
        selectorGui.Add("Text",, "Select function to add:")
        lb := selectorGui.Add("ListBox", "w200 h150", unboundFunctions)
        selectorGui.Add("Button",, "Add").OnEvent("Click", (*) => this.AddFunction(lb.Text, listView, selectorGui))
        selectorGui.Add("Button", "x+10", "Cancel").OnEvent("Click", (*) => selectorGui.Destroy())
        selectorGui.Show()
    }

    AddFunction(funcName, listView, selectorGui) {
        if (funcName = "") {
            MsgBox("Please select a function first.", "Error", "Icon!")
            return
        }
        
        ; Add to profile with empty binding
        ProfileManager.profiles[ProfileManager.currentProfile][funcName] := ""
        
        ; Add to ListView
        listView.Add(, funcName, "Unassigned")
        
        selectorGui.Destroy()
        
        ; Prompt user to set the keybind
        this.PromptKeybind(funcName, listView)
    }

    RemoveFunction(listView) {
        if (listView.GetNext(0) = 0) {
            MsgBox("Please select a function to remove.", "Error", "Icon!")
            return
        }
        
        funcName := listView.GetText(listView.GetNext(0), 1)
        if (MsgBox("Remove '" funcName "' from the profile?", "Confirm Remove", "YesNo Icon!") = "Yes") {
            ProfileManager.profiles[ProfileManager.currentProfile].Delete(funcName)
            listView.Delete(listView.GetNext(0))
            this.ApplyBinds()
        }
    }

    ChangeSelectedKeybind(listView) {
        if (listView.GetNext(0) = 0) {
            MsgBox("Please select a function to change.", "Error", "Icon!")
            return
        }
        
        funcName := listView.GetText(listView.GetNext(0), 1)
        this.PromptKeybind(funcName, listView)
    }

    PromptKeybind(funcName, listView) {
        KeybindGUI.isListening := true
        
        ; Create keybind prompt dialog
        promptGui := Gui()
        promptGui.Add("Text",, "Press keys for '" funcName "'...")
        promptGui.Add("Edit", "w200 ReadOnly", "Press keys...")
        promptGui.Add("Button",, "Cancel").OnEvent("Click", (*) => (promptGui.Destroy(), this.StopListening()))
        
        ih := InputHook("V B")
        ih.KeyOpt("{All}", "E")
        ih.OnEnd := this.OnInputEnd.Bind(this, funcName, listView, promptGui)
        ih.Start()
        
        promptGui.Show()
    }

    OnInputEnd(funcName, listView, promptGui, ih) {
        ; Get current state of modifier keys
        hasCtrl := GetKeyState("Ctrl")
        hasAlt := GetKeyState("Alt")
        hasShift := GetKeyState("Shift")
        hasWin := GetKeyState("LWin") || GetKeyState("RWin")
        
        key := ih.EndKey
        
        ; Handle Escape to cancel
        if (key = "Escape") {
            this.StopListening()
            promptGui.Destroy()
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

        ; Check if this hotkey is already assigned to another function
        for otherFunc, otherBind in ProfileManager.profiles[ProfileManager.currentProfile] {
            if (otherFunc != funcName && otherBind = newBind) {
                MsgBox("This hotkey is already assigned to '" otherFunc "'", "Duplicate Binding", "Icon!")
                this.StopListening()
                promptGui.Destroy()
                return
            }
        }
        
        ; Update profile and ListView
        ProfileManager.profiles[ProfileManager.currentProfile][funcName] := newBind
        
        ; Find and update the ListView row
        Loop listView.GetCount() {
            if (listView.GetText(A_Index, 1) = funcName) {
                listView.Modify(A_Index,, funcName, this.PrettifyHotkey(newBind))
                break
            }
        }
        
        this.StopListening()
        promptGui.Destroy()
        this.ApplyBinds()
    }
} 