#Requires AutoHotkey v2.0

class PACSCommands {
    static commands := Map(
        "Toggle Dictation", (*) => sendPs("{F4}"),
        "Select Next Field", (*) => (WinActivate("PowerScribe"), Send("{Tab}")),
        "Draft Report", (*) => sendPs("{F9}"),
        "Close All Windows", (*) => closeKill("Command - ")
    )
}

pacsActive() {
    return WinActive("PowerScribe") or WinActive("ahk_exe mp.exe")
}

sendPs(x) {
    WinActivate("PowerScribe")
    Send x
}

setAttending(x) {
    WinActivate("PowerScribe")
    Send "{Alt down}ta{Alt up}"
    Sleep(100)
    Send x
    Sleep(100)
    Send "{tab}{space}{tab}{Enter}"
}

closeKill(x) {
    if ProcessExist(x) {
        ProcessClose(x)
    } else if WinExist(x) {
        WinKill(x)
        if WinExist(x) {
            ProcessClose(WinGetProcessName(x))
        }
    }
}

; ... (other PACS-related functions) 