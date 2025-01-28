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
        } else if (ProfileManager.defaultProfile != "" && ProfileManager.profiles.Has(ProfileManager.defaultProfile)) {
            ; If there's a valid default profile, load it directly
            ProfileManager.currentProfile := ProfileManager.defaultProfile
            this.CreateMainGUI()
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
        
        ; Create ListView for keybinds with adjusted column widths
        lv := this.gui.Add("ListView", "xm y" y " w400 h200", ["Function", "Keybind", "Type"])
        
        ; Populate ListView with current bindings, separated by type
        for funcName, bind in ProfileManager.profiles[ProfileManager.currentProfile] {
            funcType := InStr(funcName, "Custom: ") = 1 ? "Custom" : "Built-in"
            lv.Add(, funcName, this.PrettifyHotkey(bind), funcType)
        }

        this.ResizeColumns(lv)  ; Resize after initial population
        
        ; Auto-size columns to fit content
        lv.ModifyCol(1, "AutoHdr")  ; Function column - size to fit both content and header
        lv.ModifyCol(2, "AutoHdr")  ; Keybind column - size to fit both content and header
        lv.ModifyCol(3, "AutoHdr")  ; Type column - size to fit both content and header
        
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
        selectorGui := Gui(, "PACS Assistant - Profile Selection")
        selectorGui.Add("Text",, "Select profile:")
        
        ; Add profiles listbox with default profile marked
        profileNames := []
        for name, _ in ProfileManager.profiles {
            ; Add asterisk to mark default profile
            profileNames.Push(name (name = ProfileManager.defaultProfile ? " *" : ""))
        }
        lb := selectorGui.Add("ListBox", "w200 h150", profileNames)
        
        ; If there's a default profile, select it in the listbox
        if (ProfileManager.defaultProfile != "") {
            for i, name in profileNames {
                if (InStr(name, ProfileManager.defaultProfile " *")) {
                    lb.Choose(i)
                    break
                }
            }
        }
        
        ; Add buttons
        buttonGroup := selectorGui.Add("GroupBox", "w190 h150", "Actions")
        
        selectorGui.Add("Button", "xp+10 yp+20 w170", "Select").OnEvent("Click", (*) => this.SelectProfile(StrReplace(lb.Text, " *"), selectorGui))
        selectorGui.Add("Button", "w170", "Set as Default").OnEvent("Click", (*) => this.SetDefaultProfile(StrReplace(lb.Text, " *"), selectorGui))
        selectorGui.Add("Button", "w170", "Rename").OnEvent("Click", (*) => this.PromptRenameProfile(StrReplace(lb.Text, " *"), selectorGui))
        selectorGui.Add("Button", "w170", "Delete Profile").OnEvent("Click", (*) => this.DeleteProfile(StrReplace(lb.Text, " *"), selectorGui))
        selectorGui.Add("Button", "w170", "New Profile").OnEvent("Click", (*) => (selectorGui.Destroy(), this.PromptNewProfile()))
        
        ; Add legend text
        selectorGui.Add("Text", "y+10", "* = Default Profile")
        
        selectorGui.Show()
    }

    PromptNewProfile() {
        inputGui := Gui(, "PACS Assistant - Create New Profile")
        inputGui.Add("Text",, "Enter profile name:")
        nameEdit := inputGui.Add("Edit", "w200")
        inputGui.Add("Button",, "OK").OnEvent("Click", (*) => this.CreateProfile(nameEdit.Value, inputGui))
        inputGui.Show()
    }

    CreateProfile(name, inputGui) {
        if name != "" {
            ; Initialize an empty profile instead of using defaultBinds
            ProfileManager.profiles[name] := Map()
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
        
        ih := InputHook("V B")
        ih.KeyOpt("{All}", "E")
        ih.OnEnd := this.OnInputEnd.Bind(this, funcName, control)
        ih.Start()
    }

    OnInputEnd(funcName, control, promptGui := 0, ih?) {
        ; Get current state of modifier keys
        hasCtrl := GetKeyState("Ctrl")
        hasAlt := GetKeyState("Alt")
        hasShift := GetKeyState("Shift")
        hasWin := GetKeyState("LWin") || GetKeyState("RWin")
        
        key := ih.EndKey
        
        ; Handle Escape to cancel
        if (key = "Escape") {
            this.StopListening()
            if (promptGui) {
                promptGui.Destroy()
            } else {
                control.Value := this.PrettifyHotkey(ProfileManager.profiles[ProfileManager.currentProfile][funcName])
            }
            return
        }
        
        ; Skip if the key is just a modifier
        if key ~= "^[LR]?(Control|Alt|Shift|Win)$" {
            ; Create and start a new input hook since the old one is ended
            newIh := InputHook("V B")
            newIh.KeyOpt("{All}", "E")
            if (promptGui) {
                newIh.OnEnd := this.OnInputEnd.Bind(this, funcName, control, promptGui)
            } else {
                newIh.OnEnd := this.OnInputEnd.Bind(this, funcName, control)
            }
            newIh.Start()
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
                if (promptGui) {
                    promptGui.Destroy()
                } else {
                    control.Value := this.PrettifyHotkey(ProfileManager.profiles[ProfileManager.currentProfile][funcName])
                }
                return
            }
        }
        
        ; Update profile
        ProfileManager.profiles[ProfileManager.currentProfile][funcName] := newBind
        
        ; Update UI
        if (promptGui) {
            ; Find and update the ListView row before destroying the prompt
            Loop control.GetCount() {
                if (control.GetText(A_Index, 1) = funcName) {
                    control.Modify(A_Index,, funcName, this.PrettifyHotkey(newBind))
                    break
                }
            }
            this.ResizeColumns(control)  ; Resize after modifying keybind
            this.StopListening()
            promptGui.Destroy()
        } else {
            control.Value := this.PrettifyHotkey(newBind)
            this.StopListening()
        }
        
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

        renameGui := Gui(, "PACS Assistant - Rename Profile")
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
        selectorGui := Gui(, "PACS Assistant - Add Function")
        
        ; Get list of unbound functions, separated by type
        builtInFunctions := []
        customFunctions := []
        
        for funcName, _ in ProfileManager.availableFunctions {
            if !ProfileManager.profiles[ProfileManager.currentProfile].Has(funcName) {
                if (InStr(funcName, "Custom: ") = 1) {
                    customFunctions.Push(funcName)
                } else {
                    builtInFunctions.Push(funcName)
                }
            }
        }
        
        ; Add custom keybind creation button
        selectorGui.Add("Button", "w200", "Create New Custom Keybind").OnEvent("Click", (*) => (selectorGui.Destroy(), this.ShowCustomKeybindDialog(listView)))
        
        ; Add built-in functions section
        selectorGui.Add("Text", "xm y+20", "Built-in Functions:")
        lbBuiltIn := selectorGui.Add("ListBox", "w200 h150", builtInFunctions)
        
        ; Add custom functions section if any exist
        if (customFunctions.Length > 0) {
            selectorGui.Add("Text", "xm y+10", "Custom Functions:")
            lbCustom := selectorGui.Add("ListBox", "w200 h100", customFunctions)
            selectorGui.Add("Button", "y+5 w200", "Delete Selected Custom Function").OnEvent("Click", (*) => this.DeleteCustomFunction(lbCustom.Text, selectorGui))
        }
        
        ; Add action buttons
        selectorGui.Add("Button", "xm y+10", "Add Selected").OnEvent("Click", (*) => this.AddFunction(lbBuiltIn.Text || lbCustom.Text, listView, selectorGui))
        selectorGui.Add("Button", "x+10", "Cancel").OnEvent("Click", (*) => selectorGui.Destroy())
        
        selectorGui.Show()
    }

    DeleteCustomFunction(funcName, selectorGui) {
        if (funcName = "") {
            MsgBox("Please select a custom function to delete.", "Error", "Icon!")
            return
        }
        
        if (!InStr(funcName, "Custom: ") = 1) {
            MsgBox("Only custom functions can be deleted.", "Error", "Icon!")
            return
        }
        
        if (MsgBox("Are you sure you want to delete the custom function '" funcName "'?`nThis will remove it from all profiles.", "Confirm Delete", "YesNo Icon!") = "Yes") {
            ; Remove from available functions
            ProfileManager.availableFunctions.Delete(funcName)
            
            ; Remove from profiles that have this function
            for _, profile in ProfileManager.profiles {
                if (profile.Has(funcName)) {
                    profile.Delete(funcName)
                }
            }
            
            ; Save all profiles to persist the changes
            for name, binds in ProfileManager.profiles {
                ProfileManager.SaveProfile(name, binds)
            }
            
            ; Refresh the dialog
            selectorGui.Destroy()
            this.ShowAddFunctionDialog(this.gui["ListView"])
            
            ; Refresh the main GUI if the function was in the current profile
            if (ProfileManager.profiles[ProfileManager.currentProfile].Has(funcName)) {
                this.gui.Destroy()
                this.CreateMainGUI()
            }
        }
    }

    ShowCustomKeybindDialog(listView) {
        customGui := Gui(, "PACS Assistant - Configure Custom Keybind")
        customGui.Add("Text",, "Name for this keybind:")
        nameEdit := customGui.Add("Edit", "w200")
        
        customGui.Add("Text", "y+10", "Keys to send (e.g. {Tab}, ^c, Hello):")
        keysEdit := customGui.Add("Edit", "w200")
        
        customGui.Add("Text", "y+10", "Target window (optional):")
        windowEdit := customGui.Add("Edit", "w200")
        
        customGui.Add("Button", "y+10", "OK").OnEvent("Click", (*) => this.AddCustomKeybind(nameEdit.Value, keysEdit.Value, windowEdit.Value, listView, customGui))
        customGui.Add("Button", "x+10", "Cancel").OnEvent("Click", (*) => customGui.Destroy())
        
        ; Add help text
        customGui.Add("Text", "y+20", "Examples:")
        customGui.Add("Text",, "{Tab} = Tab key`n^c = Ctrl+C`nHello = types 'Hello'")
        
        customGui.Show()
    }

    AddCustomKeybind(name, keys, window, listView, customGui) {
        if (name = "") {
            MsgBox("Please enter a name for the keybind.", "Error", "Icon!")
            return
        }
        if (keys = "") {
            MsgBox("Please enter keys to send.", "Error", "Icon!")
            return
        }
        
        ; Create unique function name
        funcName := "Custom: " name
        
        ; Check if name already exists
        if ProfileManager.profiles[ProfileManager.currentProfile].Has(funcName) {
            MsgBox("A keybind with this name already exists.", "Error", "Icon!")
            return
        }
        
        ; Create the custom function
        ProfileManager.availableFunctions[funcName] := PACSCommands.CreateCustomKeybind(keys, window)
        
        ; Add to profile with empty binding
        ProfileManager.profiles[ProfileManager.currentProfile][funcName] := ""
        
        ; Add to ListView
        listView.Add(, funcName, "Unassigned")
        this.ResizeColumns(listView)
        
        customGui.Destroy()
        
        ; Prompt user to set the keybind
        this.PromptKeybind(funcName, listView)
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
        this.ResizeColumns(listView)  ; Resize after adding function
        
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
            this.ResizeColumns(listView)  ; Resize after removing function
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
        promptGui := Gui(, "PACS Assistant - Set Keybind")
        promptGui.Add("Text",, "Press keys for '" funcName "'...")
        promptGui.Add("Edit", "w200 ReadOnly", "Press keys...")
        promptGui.Add("Button",, "Cancel").OnEvent("Click", (*) => (promptGui.Destroy(), this.StopListening()))
        
        ih := InputHook("V B")
        ih.KeyOpt("{All}", "E")
        ih.OnEnd := this.OnInputEnd.Bind(this, funcName, listView, promptGui)
        ih.Start()
        
        promptGui.Show()
    }

    ResizeColumns(listView) {
        listView.ModifyCol(1, "AutoHdr")  ; Function column
        listView.ModifyCol(2, "AutoHdr")  ; Keybind column
        listView.ModifyCol(3, "AutoHdr")  ; Type column
    }
} 