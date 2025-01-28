#Requires AutoHotkey v2.0

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

; ... (other PACS-related functions) 