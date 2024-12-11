#Requires AutoHotkey >=2.0
#include UIA-v2-1.0.1\Lib\UIA.ahk

; Return true if PowerScribe or PACS viewer is the active window
pacsActive()
{
	if WinActive("PowerScribe") or WinActive("ahk_exe mp.exe")
	{
		return true
	}
	return false
}

; Set PowerScribe to the active window and send keystrokes
sendPs(x)
{
	WinActivate("PowerScribe")
	Send x
	Return
}

setAttending(x) {
	WinActivate("PowerScribe")
	Send "{Alt down}ta{Alt up}"
	Sleep(100)
    Send x
	Sleep(100)
	Send "{tab}{space}{tab}{Enter}"
}

checkAttending(haystack) {
    bodyStr := "i)EXAMINATION:[\s]*((CT.*pelvis)|(XR.*abdomen)|(MRCP)|(MRI.*abdomen))"
    chestStr := "i)EXAMINATION:[\s]*((CT.*chest)|(XR.*chest))"
    pedsStr := "i)EXAMINATION:[\s]*((US.*((right lower quadrant)|(neurosonography))))"
    neuroStr := "i)EXAMINATION:[\s]*((CT.*((facial)|(spine)|(head)|(escape)|(neck)))|(MRI.*((brain)|(spine)|(orbits)))|(MRA))"
    usStr := "i)EXAMINATION:[\s]*US"
    nucsStr := "i)EXAMINATION:[\s]*NM"

    if RegExMatch(haystack, bodyStr) {
		setAttending("Body")
	} else if RegExMatch(haystack, chestStr) {
		setAttending("Chest")
	} else if RegExMatch(haystack, neuroStr) {
		setAttending("Neuro")
	} else if RegExMatch(haystack, nucsStr) {
		setAttending("Nucs")
	} else if RegExMatch(haystack, pedsStr) {
		setAttending("Peds")
	} else if RegExMatch(haystack, usStr) {
		setAttending("Ultrasound")
	} else {
		setAttending("MSK")
	}
}


; Toggle dictation
F16:: 
{
	sendPs("{F4}")
	Return
}


F17::
{
	WinActivate("PowerScribe")
	Send "{Tab}"
	Return
}


; Draft report in PS
F18::
{
	SendPs("{F9}") ; F9 to draft, F12 to approve
	Return
}


closeKill(x) {

	if ProcessExist(x) {
		ProcessClose(x)
	} else if WinExist(x)
	{
		WinKill(x)
		if WinExist(x) {
			ProcessClose(WinGetProcessName(x))
		}
	}

	Return

}


^+r::
{

	closeKill("Command - ")

	closeKill("WinDgb:")

	closeKill("Vue PACS")

	closeKill("Explorer Portal")

	closeKill("PowerScribe")

	closeKill("Hyperspace")

	closeKill("mp.exe")

	closeKill("NativeBridge.exe")

	Sleep 500
 
	found := False

    Loop Files, A_DesktopCommon "\*"
    {
        if InStr(A_LoopFileName, "Vue Client (Integrated)")
        {
            found := True
            Run A_LoopFileFullPath
            break
        }
    }
    if !found
    {  
        Loop Files, A_Desktop "\*"
            {
                if InStr(A_LoopFileName, "Vue Client (Integrated)")
                {
                    found := True
                    Run A_LoopFileFullPath
                    break
                }
            }
    }
    if !found
    {
        MsgBox "ERROR: PACS not found..."
    }

	Return

}

; If pasting into PACS, paste text only
$^v::
{
	if WinActive("ahk_exe mp.exe") {
		Send A_Clipboard
	} else {
		Send "^v"
	}
	Return
}

^+v::
{
	NuanceEl := UIA.ElementFromHandle("PowerScribe 360 | Reporting ahk_exe Nuance.PowerScribe360.exe")
	haystack := NuanceEl.ElementFromPath("YYYYV").Value
	checkAttending(haystack)
	Sleep(100)
	WinActivate("Vue PACS ahk_exe mp.exe")
	Sleep(100)
	mpEl := UIA.ElementFromHandle("Vue PACS ahk_exe mp.exe")
	Sleep(100)
	mpEl.FindElement({Name:"scn_sticky_notes"}).Click()
	WinWait("Sticky Notes", , 1)
	mpEl := UIA.ElementFromHandle("Sticky Notes")
	Sleep(100)
	mpEl.ElementFromPath("YY0").Click()
	Sleep(100)
	MouseGetPos &xpos, &ypos 
	mpEl.ElementFromPath("87K/").Click("left")
	MouseMove xpos, ypos
	Sleep(100)
	Send('r')
	Sleep(100)
	mpEl.ElementFromPath("V").ControlClick()
	Sleep(100)
	Send A_Clipboard
	Sleep(2*StrLen(A_Clipboard))
	mpEl.ElementFromPath("YY0/").Click()
	Return
}