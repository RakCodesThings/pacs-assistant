#Requires AutoHotkey v2.0

class ProfileManager {
    static profiles := Map()
    static currentProfile := ""
    static defaultBinds := Map(
        "toggleDictation", "F16",
        "testFunction", "^!x"
    )

    static LoadProfiles() {
        try {
            Loop Files "profiles/*.ini" {
                profileName := StrReplace(A_LoopFileName, ".ini")
                this.profiles[profileName] := this.LoadProfile(A_LoopFilePath)
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
} 