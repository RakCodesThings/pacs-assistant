#Requires AutoHotkey v2.0
#Include PACSCommands.ahk

class ProfileManager {
    static profiles := Map()
    static currentProfile := ""
    static defaultBinds := Map()
    static defaultProfile := ""  ; Add default profile storage

    static __New() {
        ; Initialize default binds from PACSCommands
        this.defaultBinds := Map(
            "Toggle Dictation", "F16",
            "Select Next Field", "F17",
            "Draft Report", "F18",
            "Close All Windows", "^+r"
        )
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
            for funcName, defaultBind in this.defaultBinds {
                binds[funcName] := IniRead(path, "Keybinds", funcName, defaultBind)
            }
        }
        return binds
    }

    static SaveProfile(name, binds) {
        if !DirExist("profiles")
            DirCreate("profiles")
        
        path := "profiles/" name ".ini"
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
} 