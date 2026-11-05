
; CONFIG: the only file you edit to add or change menu items.
; After editing, reload with CapsLock + R.
;
; Every entry can end with an optional key: CapsLock + key then opens/runs it directly.
; Entries without a key only appear in the CapsLock + right click menu.
; Reserved keys: R (reload). Right click is the menu itself.

; ["Label", "Folder to run in", "Command", "key (optional)"]
; Shortcuts that start your apps (same format as commands, just grouped in the Apps tab)
apps := [
    ["Xyra Dashboard", "C:\Dev_Ex\Apps\Xyra_Dashboard_Wip2", "npm run tauri dev"],
    ["Open Place",     "C:\Dev_Ex\Apps\tauri-workspace-XyraDev\apps\open-place", "pnpm tauri dev"]
]

; ["Label", "Folder path", "key (optional)"]
folders := [
    ["Dev_Ex (root)",       "C:\Dev_Ex"],
    ["Apps",                "C:\Dev_Ex\Apps",                              "a"],
    ["Xyra Dashboard",      "C:\Dev_Ex\Apps\Xyra_Dashboard_Wip2"],
    ["Tauri Workspace",     "C:\Dev_Ex\Apps\tauri-workspace-XyraDev"],
    ["Dev_Zee_Tools",       "C:\Dev_Ex\Apps\Dev_Zee_Tools",                "t"],
    ["AHK Shortcut (edit)", "C:\Dev_Ex\AHK Shorcut Dev",                   "s"]
]

; ["Label", "Folder to run in", "Command", "key (optional)"]
commands := [
    ["Workspace: pick app",       "C:\Dev_Ex\Apps\tauri-workspace-XyraDev", ".\scripts\pick-app.ps1"]
]

; ["Label", "keys", "key (optional)", "window (optional)"]
; Macro = sends a key sequence in AHK Send syntax: ^ = Ctrl, + = Shift, ! = Alt, # = Win, {Enter} {Tab} {Left 3} {Home}
; "window" (optional) makes the key work only in that app, e.g. "ahk_exe Code.exe", so the same key can differ per app.
; Examples (remove the leading ; to use):
;   ["Save all",    "^+s",          "u"],
;   ["Delete line", "{Home}+{End}{Delete}", "k", "ahk_exe Code.exe"],
; "click:100" = auto click toggle (left click every 100 ms, press again to stop). Blocked while Roblox Player is active.
macros := [
    ["Auto click (100 ms)", "click:100", "j"]
]

; ["trigger", "text"]
; Type the trigger + space/Enter/Tab and it becomes the text. Clicking it in the menu types the text.
; Start triggers with ; so they never fire during normal typing.
snippets := [
    [";ok", "okeey sip"]
]
