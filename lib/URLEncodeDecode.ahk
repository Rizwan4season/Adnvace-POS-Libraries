#SingleInstance Force
#Requires AutoHotkey v2.0+

; It needs to be a preference to choose your hotkeys.
;alt W or something that it just You have one to encode and one to decode.
;I should just have a tab at the tab on everything that it parses, the new line starts with a tab.

ini := "Settings.ini"
IniRead(ini,"Hotkey","HK","!w")
Pref := Gui(,"Assign Hotkey")

CreateTryMenu()
Pref.SetFont("s12")
Pref.AddText("xm w250","Hotkey Encode")
Encode_SetWin := Pref.AddCheckbox("xm","Win")
Encode_SetHK  := Pref.AddHotkey("x+m w170")

Pref.AddText("xm w250","Hotkey Decode")
Decode_SetWin := Pref.AddCheckbox("xm","Win")
Decode_SetHK  := Pref.AddHotkey("x+m w170")

; Pref.AddText("xm w250","Hotkey Wrap Url")
; WrapSetWin := Pref.AddCheckbox("xm","Win")
; WrapSetHK := Pref.AddHotkey("x+m w170")

Pref.AddButton("xm+20 w100","Apply").OnEvent("Click",HKapply)
Pref.AddButton("x+m w100","Cancel").OnEvent("Click", (*) => pref.Hide())
;Pref.Show()
Showkey

HKapply(*)
{
    Encode_oldhk := IniRead(ini,"Hotkey","Encode_HK","NotAssign")
    if !(Encode_oldhk = "NotAssign")
        Hotkey(Encode_oldhk,EncodeUrl,"off")

    Decode_oldhk := IniRead(ini,"Hotkey","Decode_HK","NotAssign")
    if !(Decode_oldhk = "NotAssign")
        Hotkey(Decode_oldHK,DecodeUrl,"off")

    if Encode_SetWin.Value
    {
        IniWrite("#" Encode_SetHK.value,ini,"Hotkey","Encode_HK")
        Hotkey("#" Encode_SetHK.value,EncodeUrl,"on")
    }
    else
    {
        IniWrite(Encode_SetHK.value,ini,"Hotkey","Encode_HK")
        Hotkey(Encode_SetHK.value,EncodeUrl,"on")
    }

    if Decode_SetWin.Value
    {
        IniWrite("#" Decode_SetHK.value,ini,"Hotkey","Decode_HK")
        Hotkey("#" Decode_SetHK.value,DecodeUrl,"on")
    }
    else
    {
        IniWrite(Decode_SetHK.value,ini,"Hotkey","Decode_HK")
        Hotkey(Decode_SetHK.value,DecodeUrl,"on")
    }
    CreateTryMenu()
    Pref.Hide()
}

DecodeUrl(*)
{
    originalClipboard := ClipboardAll()
    SendInput("^c") ; Copy selected text
    if !ClipWait(1) { ; Wait for clipboard to contain text
        MsgBox("No text was sent to the clipboard")
        return
    }

    A_Clipboard := UriDecode(A_Clipboard)
    SendEvent("^v")
    A_Clipboard := originalClipboard
}

EncodeUrl(*)
{
    EncodeDecodeAndPaste(false) ; true for encoding
    ;DecodeAndWrapParameters()
}


EncodeDecodeAndPaste(encode := true) {
    ; Backup clipboard and copy selected text
    originalClipboard := ClipboardAll()
    A_Clipboard := "" ; Empty the clipboard
    SendInput("^c") ; Copy selected text
    if !ClipWait(1) { ; Wait for clipboard to contain text
        MsgBox("No text was sent to the clipboard")
        return
    }

    if InStr(A_Clipboard,"https:")
        encode := 1
    ; Encode or decode the clipboard content
    if (encode)
        A_Clipboard := UriEncode(A_Clipboard)
    else
        A_Clipboard := UriDecode(A_Clipboard)

    ; Paste the result and restore the original clipboard
    SendEvent("^v")
    A_Clipboard := originalClipboard
    return 1
}

UriEncode(Uri, RE := "[0-9A-Za-z]")
{
    Var := Buffer(StrPut(Uri, "UTF-8"), 0)
    StrPut(Uri, Var, "UTF-8")
    Res := ""
    Loop StrLen(Uri)
    {
        Code := NumGet(Var, A_Index - 1, "UChar")
        xChr := Chr(Code)
        Res .= (xChr ~= RE) ? xChr : Format("%{:02X}", Code)
    }
    return res
}

DecodeAndWrapParameters() {
    ; Backup clipboard and copy selected text
    originalClipboard := ClipboardAll()
    A_Clipboard := "" ; Empty the clipboard
    SendInput("^c") ; Copy selected text
    if !ClipWait(1) { ; Wait for clipboard to contain text
        MsgBox("No text was sent to the clipboard")
        return
    }

    ; Decode the clipboard content
    A_Clipboard := UriDecode(A_Clipboard)

    ; Wrap parameters with line breaks and indentation
    A_Clipboard := StrReplace(A_Clipboard, "?", "`r`n`t?") ; Line break and tab indent
    A_Clipboard := StrReplace(A_Clipboard, "&", "`r`n`t&") ; Line break and double tab indent
    
    ; Paste the result and restore the original clipboard
    SendEvent("^v")
    A_Clipboard := originalClipboard
}

;***********URL Encoding and Decoding Functions******************* 
UriDecode(str)
{
    while RegExMatch(str, "i)(?<=%)[\da-f]{1,2}", &hex)
    {
        
        str := StrReplace(str, "%" hex[0], Chr("0x" . hex[0]))
    }
    return str
}

Showkey(*)
{
	AssignedHK := IniRead(ini,'HOTKEY','Encode_HK', false)
	if InStr(AssignedHK,"#")
	{
		AssignedHK := StrReplace(AssignedHK,"#")
		Encode_SetHK.value := AssignedHK
		Encode_SetWin.value := true
	}
	else
	{
		if (AssignedHK = false)
		{
			Pref.Show()
		}
		else
		{
			Encode_SetHK.value := AssignedHK
			Hotkey(AssignedHK, EncodeUrl,'on')
		}
	}


    AssignedHK := IniRead(ini,'HOTKEY','Decode_HK', false)
	if InStr(AssignedHK,"#")
	{
		AssignedHK := StrReplace(AssignedHK,"#")
		Decode_SetHK.value := AssignedHK
		Decode_SetWin.value := true
	}
	else
	{
		if (AssignedHK = false)
		{
			Pref.Show()
		}
		else
		{
			Decode_SetHK.value := AssignedHK
			Hotkey(AssignedHK, DecodeUrl,'on')
		}
	}
}


HKToString(hk)
{
	; removed logging due to performance issues
	; Log.Add(DEBUG_ICON_INFO, A_Now, A_ThisFunc, 'started', 'none')

	if !hk
		return

	temphk := []

	if InStr(hk, '#')
		temphk.Push('Win+')
	if InStr(hk, '^')
		temphk.Push('Ctrl+')
	if InStr(hk, '+')
		temphk.Push('Shift+')
	if InStr(hk, '!')
		temphk.Push('Alt+')

	hk := RegExReplace(hk, '[#^+!]')
	for mod in temphk
		fixedMods .= mod

	; Log.Add(DEBUG_ICON_INFO, A_Now, A_ThisFunc, 'ended', 'none')
	return (fixedMods ?? '') StrUpper(hk)
}

CreateTryMenu(*)
{
	global tray := A_TrayMenu
	tray.Delete()
	tray.Add("Preferences`t",(*) =>  Pref.Show())
	Ehk := IniRead(ini,'HOTKEY','Encode_HK',"NotAssign")
    Dhk := IniRead(ini,'HOTKEY','Decode_HK',"NotAssign")
    tray.Add("Encode Url`t" HKToString(Ehk),(*) => false)
    tray.Add("Decode Url`t" HKToString(Dhk),(*) => false)
	tray.Add()
	tray.add('Open Folder',(*)=>Run(A_ScriptDir))
	tray.SetIcon("Open Folder","shell32.dll",4)
	;tray.Add("About",(*) => Script.About())
	tray.Add("Exit`t",(*) => Exitapp())
}