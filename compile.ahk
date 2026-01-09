#Requires AutoHotkey v2.0
#SingleInstance Force

; Configuration
SourceFile := A_ScriptDir "\app.ahk"
IconFile := A_ScriptDir "\Data\Icon.ico"
TargetFile := A_ScriptDir "\POS.exe"

; Compiler Paths (Adjust if needed)
CompilerPath := "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"

; Check for Compiler
if !FileExist(CompilerPath) {
    ; Try finding it via registry or other common paths if needed
    MsgBox("Error: Ahk2Exe not found at '" CompilerPath "'.`nPlease ensure AutoHotkey is installed with the compiler.")
    ExitApp
}

; Build Command
; /in <file> /out <file> /icon <file> /base <file> /compress <0-2>
; Base file for 64-bit: AutoHotkey64.exe (typical for v2) or Unicode 64-bit.bin (typical for v1/legacy compiler)
; We will try to detect typical v2 base

BaseFile := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
if !FileExist(BaseFile) {
    ; Fallback lookup or simple ask?
    ; Let's assume standard v2 install. If not found, try the 'Compiler' folder for .bin files (older style)
    BaseFile := "C:\Program Files\AutoHotkey\Compiler\Unicode 64-bit.bin"
}

if !FileExist(BaseFile) {
    MsgBox("Error: 64-bit Base file not found.`nLooking for: " BaseFile)
    ExitApp
}

RunWait(Format('"{1}" /in "{2}" /out "{3}" /icon "{4}" /base "{5}"', CompilerPath, SourceFile, TargetFile, IconFile,
    BaseFile))

MsgBox("Compilation Complete!`nCreated: " TargetFile)