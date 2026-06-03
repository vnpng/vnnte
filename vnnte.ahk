#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib\GUI.ahk

global AppGUI := 0

F10:: {
    if !AppGUI
        return
    StartPinkClaw()
}

OnExit(Cleanup)
Cleanup(*) {
}

AppGUI := CreateMainGUI()
return
