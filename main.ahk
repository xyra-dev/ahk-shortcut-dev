#Requires AutoHotkey v2.0
#SingleInstance Force

; Entry point. Double-click this file to start.
; CapsLock is the "leader" key: CapsLock + right click opens the menu.
; No app uses CapsLock as a modifier, so these never clash with built-in shortcuts.

SetCapsLockState "AlwaysOff"   ; CapsLock no longer toggles caps (use Shift instead)

; Order matters: config first (data), then menu (engine with startup code)
#Include "config.ahk"
#Include "menu.ahk"

CapsLock & r:: Reload   ; reload script after editing
CapsLock & v:: Send "#v"   ; open Windows clipboard history (same as Win + V)
