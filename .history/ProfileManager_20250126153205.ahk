#Requires AutoHotkey v2.0
#Include PACSCommands.ahk

class ProfileManager {
    static profiles := Map()
    static currentProfile := ""
    static defaultProfile := ""
    static availableFunctions := Map()  ; Store all available functions

    static __New() {
        ; Initialize available functions from PACSCommands
        this.availableFunctions := PACSCommands.commands
        
        ; Load default profile name if it exists
        try {
            this.defaultProfile := IniRead("config.ini", "Settings", "DefaultProfile", "")
        }
    }

    static LoadProfiles() {
        try {
            Loop Files "profiles/*.ini" {
                profileName := StrReplace(A_LoopFileName, ".ini")
                this.profiles[profileName] := this.LoadProfile(A_LoopFilePath)
            }
            ; Set current profile to default if it exists and is valid
            if (this.defaultProfile != "" && this.profiles.Has(this.defaultProfile)) {
                this.currentProfile := this.defaultProfile
            }
        }
    }

    static LoadProfile(path) {
        binds := Map()
        try {
            IniRead(path)
            ; Read the ordered list of functions
            functionList := StrSplit(IniRead(path, "Functions", "Order", ""), "|")
            for funcName in functionList {
                if (funcName != "") {
                    binds[funcName] := IniRead(path, "Keybinds", funcName, "")
                }
            }
        }
        return binds
    }

    static SaveProfile(name, binds) {
        if !DirExist("profiles")
            DirCreate("profiles")
        
        path := "profiles/" name ".ini"
        
        ; Save the ordered list of functions
        functionList := ""
        for funcName, _ in binds {
            functionList .= funcName "|"
        }
        IniWrite(functionList, path, "Functions", "Order")
        
        ; Save the keybinds
        for funcName, bind in binds {
            IniWrite(bind, path, "Keybinds", funcName)
        }
    }

    static SetDefaultProfile(name) {
        if !DirExist("profiles")
            DirCreate("profiles")
        
        this.defaultProfile := name
        try {
            IniWrite(name, "config.ini", "Settings", "DefaultProfile")
            return true
        } catch {
            return false
        }
    }

    static DeleteProfile(name) {
        if (this.profiles.Count <= 1) {
            return false  ; Don't allow deleting the last profile
        }
        
        try {
            FileDelete("profiles/" name ".ini")
            this.profiles.Delete(name)
            
            ; If we deleted the default profile, clear it
            if (this.defaultProfile = name) {
                this.defaultProfile := ""
                IniDelete("config.ini", "Settings", "DefaultProfile")
            }
            return true
        } catch {
            return false
        }
    }

    static RenameProfile(oldName, newName) {
        if (oldName = newName)
            return true
            
        if (newName = "" || this.profiles.Has(newName))
            return false
            
        try {
            ; Save the binds
            binds := this.profiles[oldName]
            
            ; Delete old profile
            FileDelete("profiles/" oldName ".ini")
            this.profiles.Delete(oldName)
            
            ; Create new profile
            this.profiles[newName] := binds
            this.SaveProfile(newName, binds)
            
            ; Update default profile if needed
            if (this.defaultProfile = oldName) {
                this.SetDefaultProfile(newName)
            }
            
            ; Update current profile if needed
            if (this.currentProfile = oldName) {
                this.currentProfile := newName
            }
            
            return true
        } catch {
            return false
        }
    }
} 