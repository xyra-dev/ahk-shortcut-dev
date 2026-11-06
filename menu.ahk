
; Menu engine: builds the CapsLock + right click window (Gui + ListView) and registers
; every hotkey and hotstring from config.ahk. Normally you don't edit this file.

usedKeys := Map()                ; keys already taken by CapsLock + key (config.ahk and panel entries), lowercase
items := []                      ; rows of the window: [type, label, key, action]
state := Map("tab", "Command", "w", 460, "h", 300)   ; last opened tab + window size (kept while the script runs; resets on reload)

histFile := A_ScriptDir "\history.ini"   ; last run entries, survives reload and restart
histMax := 100
SetWinDelay -1   ; no automatic 100 ms pause after each window command (minimize / restore / activate), so an app shortcut pressed twice quickly toggles right away
customFile := A_ScriptDir "\custom.ini"   ; entries added from the panel (+ Add), one section per entry
usedTriggers := Map()                    ; snippet triggers already taken (lowercase)
history := []                            ; ids ("Type|Label"), newest first

; Opens the folder, then brings its Explorer window to the front (Windows may otherwise leave it minimized in the taskbar)
OpenFolder(path, *) {
    Run('explorer.exe "' path '"')
    SetTitleMatchMode 2   ; title only has to contain the folder name
    SplitPath(RTrim(path, "\"), &name)
    if WinWait((name = "" ? "" : name " ") "ahk_class CabinetWClass", , 3) {
        WinRestore
        WinActivate
    }
}

; Process name (e.g. "firefox.exe") used to find the app's window. "" = unknown, then the app is only started.
; .lnk: reads the shortcut's target. Squirrel launchers (Discord, Slack...) start the real exe through Update.exe --processStart X.exe.
AppExe(file, args) {
    target := file
    all := args
    SplitPath(file, , , &ext)
    if StrLower(ext) = "lnk" {
        try
            FileGetShortcut(file, &target, , &lnkArgs)
        catch
            return ""
        all := lnkArgs " " args
    }
    SplitPath(target, &exeName, , &tExt)
    if StrLower(tExt) != "exe"   ; .bat / .cmd, or a shortcut without a readable target
        return ""
    if exeName = "Update.exe" && RegExMatch(all, 'i)--processStart(?:AndWait)?[ =]+"?([^\s"]+\.exe)', &m)
        return m[1]
    if RegExMatch(exeName, "i)^(explorer|cmd|powershell|pwsh|wscript|cscript|rundll32)\.exe$")   ; generic hosts: their windows aren't the app
        return ""
    return exeName
}

; First real window (visible, with a title, not a tool window) of the process, 0 if there is none
AppWindow(exe) {
    for hwnd in WinGetList("ahk_exe " exe) {
        try {
            if WinGetTitle(hwnd) != "" && !(WinGetExStyle(hwnd) & 0x80)   ; 0x80 = WS_EX_TOOLWINDOW
                return hwnd
        }
    }
    return 0
}

ShowWin(hwnd) {
    if WinGetMinMax(hwnd) = -1
        WinRestore(hwnd)
    WinActivate(hwnd)
}

; Opens an app without a terminal window. args = optional command-line arguments.
; Already running: its window comes to the front (restored if minimized), no second instance is started.
; Pressing the CapsLock + key shortcut again while the app is already in front minimizes it (toggle).
; Not running: it is started from the file's own folder (.lnk keeps its own start folder), and the new window is brought to the front
; once it shows up (Windows would otherwise leave it behind the other windows).
RunApp(file, args, trigger := "") {   ; trigger = hotkey name when it comes from CapsLock + key (empty when run from the panel)
    SplitPath(file, , &dir, &ext)
    exe := AppExe(file, args)
    if exe != "" {
        hwnd := AppWindow(exe)
        if hwnd {
            if trigger != "" && WinActive(hwnd) && WinGetMinMax(hwnd) != -1 {   ; shortcut pressed again while the app is in front: minimize (toggle). Not from the panel, there it would minimize the app you just came from. A minimized window can still report as active for a moment, hence the MinMax check
                WinMinimize(hwnd)
                return
            }
            ShowWin(hwnd)
            return
        }
    }
    try {
        Run('"' file '"' (args = "" ? "" : " " args), StrLower(ext) = "lnk" ? "" : dir)
    } catch as err {
        MsgBox("Could not open:`n" file "`n`n" err.Message, "Dev Menu")
        return
    }
    if exe != "" {
        hwnd := WinWait("ahk_exe " exe, , 10)
        if hwnd
            ShowWin(hwnd)
    }
}

; PowerShell -EncodedCommand wants base64 of the UTF-16 text, so quotes and special characters in a command can't break the command line
EncodePS(text) {
    n := StrPut(text, "UTF-16")   ; characters incl. the terminating null
    buf := Buffer(n * 2)
    StrPut(text, buf, "UTF-16")
    bytes := (n - 1) * 2   ; without the null
    chars := 0
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", bytes, "UInt", 0x40000001, "Ptr", 0, "UInt*", &chars)   ; 0x40000001 = base64, no line breaks
    out := Buffer(chars * 2)
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", bytes, "UInt", 0x40000001, "Ptr", out, "UInt*", &chars)
    return StrGet(out, "UTF-16")
}

; -NoExit keeps the terminal open so you can see output/errors
; -ExecutionPolicy Bypass (this window only) lets .ps1 scripts and npm.ps1 run
; The first line of the window shows the command that runs (grey), remove the Write-Host part if you don't want it
RunCommand(dir, cmd, *) {
    script := "Write-Host '> " StrReplace(cmd, "'", "''") "' -ForegroundColor DarkGray`n" cmd
    Run('powershell.exe -NoExit -ExecutionPolicy Bypass -EncodedCommand ' EncodePS(script), dir)
}

TypeText(text, *) {
    SendText(text)
}

EditConfig(*) {
    Run('notepad.exe "' A_ScriptDir '\config.ahk"')
}

Opt(item, n) => item.Has(n) ? item[n] : ""

KeyText(key) => key = "" ? "" : "CapsLock + " StrUpper(key)

Shorten(s) {
    s := RegExReplace(s, "\R", " ")
    return StrLen(s) > 40 ? SubStr(s, 1, 40) "..." : s
}

; Claims CapsLock + key for an entry (warns and skips if the key is already taken)
; scope (optional, macros only): window criteria like "ahk_exe Code.exe". The hotkey then only works while that window is active,
; so the same key can do different things in different apps.
RegisterKey(key, fn, label, scope := "") {
    if key = ""
        return
    k := StrLower(key)
    id := scope = "" ? k : k "|" scope
    if usedKeys.Has(id) {
        MsgBox("CapsLock + " StrUpper(k) (scope = "" ? "" : " (" scope ")") " is already used (" usedKeys[id] ").`nEntry '" label "' got no shortcut.", "config.ahk")
        return
    }
    usedKeys[id] := label
    if scope != ""
        HotIfWinActive(scope)
    Hotkey("CapsLock & " k, fn, "On")   ; "On" re-enables a key that was switched off by a removed entry
    if scope != ""
        HotIf()   ; back to global hotkeys
}

; Sends the key sequence (AHK Send syntax: ^c = Ctrl+C, {Enter}, {Left 3}, ...)
SendMacro(keys, *) {
    Send(keys)
}

; ---------- Entries added from the panel (+ Add), stored in custom.ini ----------
; One section per entry: [c1] with type=Command|Folder|Macro|Snippet, label, value (command / path / keys / text), key,
; dir (the folder a command runs in, Command only) and win ("ahk_exe X", Macro only, empty = works in every app).
; Old type=App entries load as Command.
; label, value and dir are saved with a leading "~" so IniRead never strips quotes or spaces.

; Macro helpers. keys = AHK Send syntax (same as macros in config.ahk)
MacroFn(keys) => SendMacro.Bind(keys)

; Name shown in the list: label + the app it is limited to, e.g. "Command bar  [RobloxStudioBeta.exe]"
MacroName(label, win) => win = "" ? label : label "  [" RegExReplace(win, "^ahk_exe ") "]"

; Exe names of the open windows (plus Roblox Studio), A-Z, for the App dropdown of the Macro form
RunningExes() {
    seen := Map()
    seen.CaseSense := "Off"
    seen["RobloxStudioBeta.exe"] := 1   ; always offered, even when Studio is closed
    for hwnd in WinGetList() {
        try {
            if WinGetTitle(hwnd) = "" || !(WinGetStyle(hwnd) & 0x10000000)   ; skip hidden / untitled windows
                continue
            seen[WinGetProcessName(hwnd)] := 1
        }
    }
    list := ""
    for name in seen
        list .= name "`n"
    list := Sort(list, "U")   ; AHK v2: Sort returns the sorted string (no ByRef)
    return StrSplit(Trim(list, "`n"), "`n")
}

CustomWrite(sec, name, text) => IniWrite("~" text, customFile, sec, name)
CustomRead(sec, name) => SubStr(IniRead(customFile, sec, name, "~"), 2)

; Builds the row for one custom entry and claims its key / trigger.
MakeCustomItem(sec, kind, label, value, key, dir := "", win := "", args := "") {
    if kind = "Command" {   ; value = command, dir = folder it runs in
        fn := RunCommand.Bind(dir, value)
        RegisterKey(key, fn, label)
        return ["Command", label, key, fn, Map("dir", dir, "cmd", value, "custom", sec)]
    }
    if kind = "App" {   ; value = file (.exe / .lnk / .bat), args = optional arguments
        fn := RunApp.Bind(value, args)
        RegisterKey(key, fn, label)
        SplitPath(value, , &fd)
        return ["App", label, key, fn, Map("path", value, "dir", fd, "args", args, "custom", sec)]
    }
    if kind = "Folder" {
        fn := OpenFolder.Bind(value)
        RegisterKey(key, fn, label)
        return ["Folder", label, key, fn, Map("path", value, "custom", sec)]
    }
    if kind = "Macro" {   ; value = keys, win = "ahk_exe X" or empty
        fn := MacroFn(value)
        RegisterKey(key, fn, label, win)
        return ["Macro", MacroName(label, win), key, fn, Map("text", value, "custom", sec, "win", win, "label", label)]
    }
    if kind = "Snippet" {
        usedTriggers[StrLower(label)] := 1
        Hotstring(":T:" label, value, "On")
        return ["Snippet", label "  =  " Shorten(value), "", TypeText.Bind(value), Map("text", value, "custom", sec, "trigger", label)]
    }
    return ""
}

LoadCustom() {
    if !FileExist(customFile)
        return
    try names := IniRead(customFile)
    catch
        return
    for sec in StrSplit(names, "`n", "`r") {
        if sec = ""
            continue
        kind := IniRead(customFile, sec, "type", "")
        if kind = "App" && CustomRead(sec, "dir") != ""   ; old App entries have a folder and are Commands; the current App type has none
            kind := "Command"
        label := CustomRead(sec, "label")
        value := CustomRead(sec, "value")
        key := CustomRead(sec, "key")
        dir := CustomRead(sec, "dir")
        win := CustomRead(sec, "win")
        args := CustomRead(sec, "args")
        if label = "" || value = ""
            continue
        row := MakeCustomItem(sec, kind, label, value, key, dir, win, args)
        if row != ""
            items.Push(row)
    }
}

NextCustomId() {
    n := 1
    while IniRead(customFile, "c" n, "type", "") != ""
        n++
    return "c" n
}

; Saves a new entry to custom.ini and adds it live (no reload needed)
AddCustom(kind, label, value, key, dir := "", win := "", args := "") {
    if !FileExist(customFile)
        FileAppend("", customFile, "UTF-16")   ; Unicode ini, so emoji / accents in snippets and paths survive
    sec := NextCustomId()
    IniWrite(kind, customFile, sec, "type")
    CustomWrite(sec, "label", label)
    CustomWrite(sec, "value", value)
    CustomWrite(sec, "key", key)
    if dir != ""
        CustomWrite(sec, "dir", dir)
    if win != ""
        CustomWrite(sec, "win", win)
    if args != ""
        CustomWrite(sec, "args", args)
    row := MakeCustomItem(sec, kind, label, value, key, dir, win, args)
    items.Push(row)
    SortItems()
    return row
}

; Writes History to history.ini (same format as AddHistory / RemoveHistory)
SaveHistory() {
    try IniDelete(histFile, "History")
    for i, v in history
        IniWrite(v, histFile, "History", i)
}

; Edit = replace: removes the old entry and adds the new one. If saving the new one fails, the old one is put back.
; History: same Type|Name keeps its place, a renamed entry just loses its old History row.
ReplaceCustom(old, kind, label, value, key, dir := "", win := "", args := "") {
    sec := old[5]["custom"]
    snap := Map("kind", IniRead(customFile, sec, "type", ""), "label", CustomRead(sec, "label"), "value", CustomRead(sec, "value"),
        "key", CustomRead(sec, "key"), "dir", CustomRead(sec, "dir"), "win", CustomRead(sec, "win"), "args", CustomRead(sec, "args"))
    if snap["kind"] = "App" && snap["dir"] != ""
        snap["kind"] := "Command"
    oldId := ItemId(old)
    pos := 0
    for i, v in history {
        if v = oldId {
            pos := i
            break
        }
    }
    RemoveCustom(old)
    try {
        row := AddCustom(kind, label, value, key, dir, win, args)
    } catch as err {
        AddCustom(snap["kind"], snap["label"], snap["value"], snap["key"], snap["dir"], snap["win"], snap["args"])   ; put the old entry back
        throw err
    }
    if pos && ItemId(row) = oldId {
        history.InsertAt(Min(pos, history.Length + 1), oldId)
        SaveHistory()
    }
}

; Opens the Add form as an editor for a custom entry (type locked, fields filled in)
EditCustom(it) {
    meta := it[5]
    kind := it[1]
    vals := Map("key", it[3])
    if kind = "Command" {
        vals["name"] := it[2]
        vals["dir"] := meta["dir"]
        vals["cmd"] := meta["cmd"]
    } else if kind = "Folder" {
        vals["name"] := it[2]
        vals["dir"] := meta["path"]
    } else if kind = "Macro" {
        vals["name"] := meta["label"]
        vals["keys"] := meta["text"]
        vals["win"] := RegExReplace(meta["win"], "^ahk_exe ")
    } else if kind = "App" {
        vals["name"] := it[2]
        vals["file"] := meta["path"]
        vals["args"] := meta["args"]
    } else if kind = "Snippet" {
        vals["trigger"] := meta["trigger"]
        vals["text"] := meta["text"]
    }
    ShowAdd(kind, vals, it)
}

; Removes a custom entry: switches off its key / trigger, deletes it from custom.ini, items and History
RemoveCustom(it) {
    meta := it[5]
    if it[3] != "" {
        lbl := meta.Has("label") ? meta["label"] : it[2]   ; macros show label + app in it[2], the key is registered under the plain label
        win := meta.Has("win") ? meta["win"] : ""
        k := StrLower(it[3])
        id := win = "" ? k : k "|" win
        if usedKeys.Has(id) && usedKeys[id] = lbl {   ; only if this entry really owns the key
            if win != ""
                HotIfWinActive(win)   ; the app-limited hotkey lives in its own context
            try Hotkey("CapsLock & " k, "Off")
            HotIf()
            usedKeys.Delete(id)
        }
    }
    if meta.Has("trigger") {
        try Hotstring(":T:" meta["trigger"], , "Off")
        usedTriggers.Delete(StrLower(meta["trigger"]))
    }
    try IniDelete(customFile, meta["custom"])
    for i, v in items {
        if v = it {
            items.RemoveAt(i)
            break
        }
    }
    RemoveHistory(it)
}

; True if the tab already has an entry with this name (History ids are "Type|Name", so names must be unique per type)
NameTaken(tab, label, skip := "") {   ; skip = the entry being edited (it may keep its own name)
    for it in items {
        if IsObject(skip) && it = skip
            continue
        if it[1] = tab && it[2] = label
            return true
    }
    return false
}

; The "+ Add" form. Types: Command, Folder, Macro and Snippet.
; The form is rebuilt from scratch whenever the type changes (just toggling .Visible leaves gaps).
; vals carries what was already typed, and the window position, over to the rebuilt form.
ShowAdd(kind := "", vals := "", edit := "") {
    static f := ""
    if IsObject(f)
        try f.Destroy()
    if !IsObject(vals)
        vals := Map()
    isEdit := IsObject(edit)   ; edit = the entry being edited (opened from the right-click menu)
    oldKid := ""   ; its current key id and trigger: it may keep them, they don't count as taken
    oldTrig := ""
    if isEdit {
        if edit[3] != "" {
            ek := StrLower(edit[3])
            ew := edit[5].Has("win") ? edit[5]["win"] : ""
            oldKid := ew = "" ? ek : ek "|" ew
        }
        if edit[5].Has("trigger")
            oldTrig := StrLower(edit[5]["trigger"])
    }
    if kind = ""   ; open on the type that matches the current tab
        kind := Map("App", "App", "Command", "Command", "Folder", "Folder", "Macro", "Macro", "Snippet", "Snippet").Get(state["tab"], "Command")
    tabName := kind   ; tab (= item type) the new entry ends up in
    isSnip := kind = "Snippet"
    isCmd := kind = "Command"
    isMac := kind = "Macro"
    isApp := kind = "App"

    f := Gui("+AlwaysOnTop", isEdit ? "Edit entry" : "Add entry")
    f.SetFont("s10", "Segoe UI")
    f.Add("Text", "w320", "Type")
    ddl := f.Add("DropDownList", "w320", ["App", "Command", "Folder", "Macro", "Snippet"])
    ddl.Choose(kind)
    if isEdit
        ddl.Enabled := false   ; the type of an existing entry can't change
    eName := eDir := eCmd := eKey := eTrig := eText := br := eKeys := eWin := tst := recBtn := eFile := eArgs := ""
    rec := Map()   ; holds the active InputHook while the Record button is listening
    if isSnip {   ; Snippet: Trigger -> Text
        f.Add("Text", "w320", "Trigger (e.g. `;gm)")
        eTrig := f.Add("Edit", "w320", vals.Get("trigger", ""))
        f.Add("Text", "w320", "Text to type")
        eText := f.Add("Edit", "w320", vals.Get("text", ""))
    } else if isMac {   ; Macro: Name -> Keys (+ Test) -> App -> Key
        f.Add("Text", "w320", "Name (shown in the menu)")
        eName := f.Add("Edit", "w320", vals.Get("name", ""))
        f.Add("Text", "w320", "Keys to send (AHK Send syntax)")
        eKeys := f.Add("Edit", "w320", vals.Get("keys", ""))
        f.Add("Text", "w320 cGray", "^ Ctrl   + Shift   ! Alt   # Win   {Enter} {Tab} {Left 3}")
        tst := f.Add("Button", "w155", "Test (sends after 3 s)")
        recBtn := f.Add("Button", "x+10 w155", "Record keys")
        f.Add("Text", "xm w320", "App (optional): only works in this app")
        eWin := f.Add("ComboBox", "w320", RunningExes())   ; open apps + Roblox Studio, or type an exe name
        eWin.Text := vals.Get("win", "")
        f.Add("Text", "w320", "Key (optional): CapsLock + key")
        eKey := f.Add("Edit", "w40 Limit1", vals.Get("key", ""))
    } else if isApp {   ; App: Name -> File (+ Browse) -> Arguments -> Key
        f.Add("Text", "w320", "Name (shown in the menu)")
        eName := f.Add("Edit", "w320", vals.Get("name", ""))
        f.Add("Text", "w320", "File (.exe / .lnk / .bat)")
        eFile := f.Add("Edit", "w320", vals.Get("file", ""))
        br := f.Add("Button", "w320", "Browse...")
        f.Add("Text", "w320", "Arguments (optional)")
        eArgs := f.Add("Edit", "w320", vals.Get("args", ""))
        f.Add("Text", "w320", "Key (optional): CapsLock + key")
        eKey := f.Add("Edit", "w40 Limit1", vals.Get("key", ""))
    } else {   ; Folder: Name -> Folder -> Key.  Command: Name -> Folder -> Command -> Key
        f.Add("Text", "w320", "Name (shown in the menu)")
        eName := f.Add("Edit", "w320", vals.Get("name", ""))
        f.Add("Text", "w320", kind = "Folder" ? "Folder path" : "Folder to run in")
        eDir := f.Add("Edit", "w320", vals.Get("dir", ""))
        br := f.Add("Button", "w320", "Browse...")
        if isCmd {
            f.Add("Text", "w320", "Command (one line)")
            eCmd := f.Add("Edit", "w320", vals.Get("cmd", ""))
        }
        f.Add("Text", "w320", "Key (optional): CapsLock + key")
        eKey := f.Add("Edit", "w40 Limit1", vals.Get("key", ""))
    }
    ok := f.Add("Button", "Default w100 xm", isEdit ? "Save" : "Add")
    cancelBtn := f.Add("Button", "x+10 w100", "Cancel")

    ; Remembers the typed values + window position before the form is rebuilt for another type
    Collect() {
        if isSnip {
            vals["trigger"] := eTrig.Value
            vals["text"] := eText.Value
        } else if isMac {
            vals["name"] := eName.Value
            vals["keys"] := eKeys.Value
            vals["win"] := eWin.Text
            vals["key"] := eKey.Value
        } else if isApp {
            vals["name"] := eName.Value
            vals["file"] := eFile.Value
            vals["args"] := eArgs.Value
            vals["key"] := eKey.Value
        } else {
            vals["name"] := eName.Value
            vals["dir"] := eDir.Value
            vals["key"] := eKey.Value
            if isCmd
                vals["cmd"] := eCmd.Value
        }
        f.GetPos(&px, &py)
        vals["x"] := px
        vals["y"] := py
    }

    Browse(*) {
        f.Opt("+OwnDialogs")
        if isApp {   ; pick a file (exe / lnk / bat), the name is filled from the file name if still empty
            p := FileSelect(3, FileExist(eFile.Value) ? eFile.Value : A_ProgramFiles, "Pick an app", "Programs (*.exe; *.lnk; *.bat; *.cmd)")
            if p = ""
                return
            eFile.Value := p
            if Trim(eName.Value) = "" {
                SplitPath(p, , , , &nm)   ; file name without extension
                eName.Value := nm
            }
            return
        }
        start := (eDir.Value != "" && DirExist(eDir.Value)) ? eDir.Value : (DirExist("C:\Dev_Ex") ? "C:\Dev_Ex" : "C:\")
        p := FileSelect("D", start, "Pick a folder")   ; "D" = modern Explorer-style folder picker (resizable, address bar)
        if p = ""
            return
        eDir.Value := p
        if kind = "Folder" && Trim(eName.Value) = "" {   ; only a folder entry is named after its folder
            SplitPath(p, &nm)
            eName.Value := nm
        }
    }

    ; Hides the form, gives you 3 seconds to switch to the target app, then sends the keys there
    TestKeys(*) {
        f.Opt("+OwnDialogs")
        keys := Trim(eKeys.Value)
        if keys = "" {
            MsgBox("Type the keys first.", "Add entry")
            return
        }
        f.Hide()
        loop 3 {
            ToolTip("Sending in " (4 - A_Index) "... switch to the target app")
            Sleep(1000)
        }
        ToolTip()
        try {
            Send(keys)
        } catch as err {
            f.Show()
            MsgBox("These keys are not valid:`n" err.Message, "Add entry")
            return
        }
        f.Show()
    }

    ; Stops listening for the Record button and resets its label
    StopRec() {
        if rec.Has("ih") {
            try rec["ih"].Stop()
            rec.Delete("ih")
        }
        if IsObject(recBtn)
            try recBtn.Text := "Record keys"
    }

    ; Called for every key press while recording: the first non-modifier key finishes it and writes the combo
    ; to Keys in Send syntax (Ctrl+Alt+Shift+C -> ^!+c). Esc alone cancels.
    RecKey(ih, vk, sc) {
        name := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
        if RegExMatch(name, "i)^(L|R)?(Control|Ctrl|Shift|Alt|Win)$")   ; modifier alone: keep waiting
            return
        mods := (GetKeyState("Ctrl", "P") ? "^" : "") (GetKeyState("Alt", "P") ? "!" : "") (GetKeyState("Shift", "P") ? "+" : "") (GetKeyState("LWin", "P") || GetKeyState("RWin", "P") ? "#" : "")
        StopRec()
        if name = "Escape" && mods = ""
            return
        key := (StrLen(name) = 1 && !InStr("^+!#{}", name)) ? StrLower(name) : "{" name "}"   ; letters plain, special keys in braces
        eKeys.Value := mods key
        eKeys.Focus()
    }

    Record(*) {
        if rec.Has("ih") {   ; clicking again cancels
            StopRec()
            return
        }
        recBtn.Text := "Press combo... (Esc)"
        ih := InputHook()
        ih.KeyOpt("{All}", "NS")   ; notify on every key and keep it from reaching the form
        ih.OnKeyDown := RecKey
        ih.Start()
        rec["ih"] := ih
    }

    Cancel(*) {
        StopRec()
        try f.Destroy()
        ShowMenu()
    }

    Save(*) {
        f.Opt("+OwnDialogs")
        dir := ""
        key := ""
        win := ""
        args := ""
        if isSnip {
            label := Trim(eTrig.Value)
            value := eText.Value
            if label = "" || value = "" {
                MsgBox("Please fill in trigger and text.", "Add entry")
                return
            }
            if SubStr(label, 1, 1) != ";"
                label := ";" label
            if StrLen(label) < 2 || InStr(label, " ") {
                MsgBox("The trigger can't be empty or contain spaces, e.g. `;gm", "Add entry")
                return
            }
            if usedTriggers.Has(StrLower(label)) && StrLower(label) != oldTrig {
                MsgBox("The trigger " label " already exists.", "Add entry")
                return
            }
        } else if isMac {
            label := Trim(eName.Value)
            value := Trim(eKeys.Value)
            key := Trim(eKey.Value)
            exe := Trim(eWin.Text)
            if label = "" || value = "" {
                MsgBox("Please fill in name and keys.", "Add entry")
                return
            }
            if RegExMatch(value, "\R") {
                MsgBox("The keys must be a single line.", "Add entry")
                return
            }
            if exe != "" && !RegExMatch(exe, 'i)^[^\\/:*?"<>|]+\.exe$') {
                MsgBox("App must be an exe name, e.g. RobloxStudioBeta.exe", "Add entry")
                return
            }
            win := exe = "" ? "" : "ahk_exe " exe
            if NameTaken(tabName, MacroName(label, win), edit) {
                MsgBox("There is already a Macro named '" MacroName(label, win) "'.", "Add entry")
                return
            }
            if key != "" {
                if !RegExMatch(key, "^[A-Za-z0-9]$") {
                    MsgBox("Key must be a single letter or digit.", "Add entry")
                    return
                }
                kid := win = "" ? StrLower(key) : StrLower(key) "|" win   ; same key is fine in different apps
                if usedKeys.Has(kid) && kid != oldKid {
                    MsgBox("CapsLock + " StrUpper(key) (win = "" ? "" : " in " exe) " is already used (" usedKeys[kid] ").", "Add entry")
                    return
                }
            }
        } else if isApp {
            label := Trim(eName.Value)
            value := Trim(Trim(eFile.Value), '"')   ; drop quotes that come with "Copy as path"
            args := Trim(eArgs.Value)
            key := Trim(eKey.Value)
            if label = "" || value = "" {
                MsgBox("Please fill in name and file.", "Add entry")
                return
            }
            if !FileExist(value) || DirExist(value) {
                MsgBox("File not found:`n" value, "Add entry")
                return
            }
            if NameTaken(tabName, label, edit) {
                MsgBox("There is already an App named '" label "'.", "Add entry")
                return
            }
            if key != "" {
                if !RegExMatch(key, "^[A-Za-z0-9]$") {
                    MsgBox("Key must be a single letter or digit.", "Add entry")
                    return
                }
                if usedKeys.Has(StrLower(key)) && StrLower(key) != oldKid {
                    MsgBox("CapsLock + " StrUpper(key) " is already used (" usedKeys[StrLower(key)] ").", "Add entry")
                    return
                }
            }
        } else {
            label := Trim(eName.Value)
            dir := Trim(Trim(eDir.Value), '"')   ; drop quotes that come with "Copy as path"
            key := Trim(eKey.Value)
            value := isCmd ? Trim(eCmd.Value) : dir   ; Folder keeps its path as the value
            if label = "" || dir = "" || value = "" {
                MsgBox("Please fill in " (isCmd ? "name, folder and command." : "name and path."), "Add entry")
                return
            }
            if isCmd && RegExMatch(value, "\R") {
                MsgBox("The command must be a single line.", "Add entry")
                return
            }
            if !DirExist(dir) {
                MsgBox("Folder not found:`n" dir, "Add entry")
                return
            }
            if NameTaken(tabName, label, edit) {
                MsgBox("There is already a " kind " named '" label "'.", "Add entry")
                return
            }
            if key != "" {
                if !RegExMatch(key, "^[A-Za-z0-9]$") {
                    MsgBox("Key must be a single letter or digit.", "Add entry")
                    return
                }
                if usedKeys.Has(StrLower(key)) && StrLower(key) != oldKid {
                    MsgBox("CapsLock + " StrUpper(key) " is already used (" usedKeys[StrLower(key)] ").", "Add entry")
                    return
                }
            }
        }
        try {
            if isEdit
                ReplaceCustom(edit, kind, label, value, key, isCmd ? dir : "", win, args)
            else
                AddCustom(kind, label, value, key, isCmd ? dir : "", win, args)
        } catch as err {
            MsgBox("Could not save:`n" err.Message, "Add entry")
            return
        }
        StopRec()
        try f.Destroy()
        state["tab"] := tabName   ; reopen the menu on the tab of the new entry
        ShowMenu()
    }

    ddl.OnEvent("Change", (*) => (StopRec(), Collect(), ShowAdd(ddl.Text, vals, edit)))   ; rebuild the form for the new type
    if IsObject(br)
        br.OnEvent("Click", Browse)
    if IsObject(tst)
        tst.OnEvent("Click", TestKeys)
    if IsObject(recBtn)
        recBtn.OnEvent("Click", Record)
    ok.OnEvent("Click", Save)
    cancelBtn.OnEvent("Click", Cancel)
    f.OnEvent("Escape", Cancel)
    f.OnEvent("Close", Cancel)
    f.Show(vals.Has("x") ? "x" vals["x"] " y" vals["y"] : "")
    (isSnip ? eTrig : eName).Focus()
}

BuildItems() {
    for item in folders {
        fn := OpenFolder.Bind(item[2])
        items.Push(["Folder", item[1], Opt(item, 3), fn, Map("cfg", 1, "path", item[2])])
        RegisterKey(Opt(item, 3), fn, item[1])
    }
    for item in commands {
        fn := RunCommand.Bind(item[2], item[3])
        items.Push(["Command", item[1], Opt(item, 4), fn, Map("cfg", 1, "dir", item[2], "cmd", item[3])])
        RegisterKey(Opt(item, 4), fn, item[1])
    }
    for item in macros {   ; ["Label", "keys", "key", "window (optional)"]
        fn := SendMacro.Bind(item[2])
        scope := Opt(item, 4)
        items.Push(["Macro", item[1] (scope = "" ? "" : "  [" scope "]"), Opt(item, 3), fn, Map("cfg", 1, "text", item[2])])
        RegisterKey(Opt(item, 3), fn, item[1], scope)
    }
    for item in snippets {
        Hotstring(":T:" item[1], item[2])
        usedTriggers[StrLower(item[1])] := 1
        items.Push(["Snippet", item[1] "  =  " Shorten(item[2]), "", TypeText.Bind(item[2]), Map("cfg", 1, "text", item[2])])
    }
    LoadCustom()
}

BuildItems()

; Sorts rows A-Z by name (every tab except History). History ignores this, it keeps its own order.
SortItems() {
    loop items.Length - 1 {
        i := A_Index + 1
        cur := items[i]
        j := i - 1
        while j >= 1 && StrCompare(items[j][2], cur[2]) > 0 {
            items[j + 1] := items[j]
            j--
        }
        items[j + 1] := cur
    }
}

SortItems()

ItemId(it) => it[1] "|" it[2]

LoadHistory() {
    loop histMax {
        id := IniRead(histFile, "History", A_Index, "")
        if id != ""
            history.Push(id)
    }
}

; Moves the entry to the top (no duplicates), keeps the newest histMax, saves to history.ini
AddHistory(it) {
    id := ItemId(it)
    for i, v in history {
        if v = id {
            history.RemoveAt(i)
            break
        }
    }
    history.InsertAt(1, id)
    if history.Length > histMax
        history.Length := histMax
    try IniDelete(histFile, "History")
    for i, v in history
        IniWrite(v, histFile, "History", i)
}

CopyText(text) {
    A_Clipboard := text
    ToolTip("Copied")
    SetTimer(() => ToolTip(), -1000)
}

; Empties History and history.ini
ClearHistory() {
    history.Length := 0
    try IniDelete(histFile, "History")
}

; Drops one entry from History and saves history.ini
RemoveHistory(it) {
    id := ItemId(it)
    for i, v in history {
        if v = id {
            history.RemoveAt(i)
            break
        }
    }
    try IniDelete(histFile, "History")
    for i, v in history
        IniWrite(v, histFile, "History", i)
}

; History rows in order; ids no longer in config.ahk are skipped
HistoryItems() {
    byId := Map()
    for it in items
        byId[ItemId(it)] := it
    list := []
    for id in history
        if byId.Has(id)
            list.Push(byId[id])
    return list
}

LoadHistory()

ShowMenu() {
    static g := ""
    if IsObject(g)
        g.Destroy()
    g := Gui("+AlwaysOnTop +Resize -MinimizeBox -MaximizeBox +MinSize460x300", "Dev Menu")   ; -MaximizeBox must come after +Resize (Resize re-enables it)
    g.SetFont("s10", "Segoe UI")
    tabs := g.Add("Tab3", "w580 h28", ["History", "App", "Command", "Folder", "Macro", "Snippet"])
    tabs.UseTab()   ; controls below are outside the tab, so the list isn't clipped inside it
    lv := g.Add("ListView", "r14 w580 -Multi NoSort", ["Name", "Shortcut", "Type"])
    shown := []   ; rows currently in the list (same order), so row number -> item

    ; Fixed columns: Shortcut 140, Type 80 (only on the History tab), Name takes the leftover width (no horizontal scrollbar)
    ; Called on open, on resize and on tab change (Type is hidden outside History, so Name gets wider)
    FitCols() {
        typeW := tabs.Text = "History" ? 80 : 0   ; other tabs: Type would just repeat the tab name
        lv.GetPos(, , &lw)
        lv.ModifyCol(2, 140)
        lv.ModifyCol(3, typeW)
        lv.ModifyCol(1, Max(120, lw - 140 - typeW - SysGet(2) - 6))   ; SysGet(2) = vertical scrollbar width
    }

    ; Fills the list with the items of the selected tab (tab name = item type, History = last run entries)
    Fill(*) {
        filter := tabs.Text
        state["tab"] := filter
        lv.Delete()
        shown.Length := 0
        for it in (filter = "History" ? HistoryItems() : items) {
            if filter != "History" && it[1] != filter
                continue
            lv.Add(, it[2], KeyText(it[3]), it[1])
            shown.Push(it)
        }
        FitCols()
        lv.Focus()   ; no row is pre-selected; use arrows/click, then Enter
    }

    RunRow(row := 0) {
        row := row ? row : lv.GetNext()
        if !row
            return
        AddHistory(shown[row])
        fn := shown[row][4]
        g.Destroy()
        fn()
    }

    ; Asks first, then wipes History and refreshes the list
    AskClear() {
        g.Opt("+OwnDialogs")
        if MsgBox("Clear all history?", "Dev Menu", "YesNo Icon?") = "Yes" {
            ClearHistory()
            Fill()
        }
    }

    ; Asks first, then removes an entry that was added from the panel
    AskRemove(it) {
        g.Opt("+OwnDialogs")
        if MsgBox("Remove '" it[2] "'?", "Dev Menu", "YesNo Icon?") = "Yes" {
            RemoveCustom(it)
            Fill()
        }
    }

    ; Right-click on a row: popup menu like the Windows context menu
    ShowRowMenu(row) {
        if !row {   ; blank area: only History has something to offer (clear all)
            if tabs.Text = "History" {
                bm := Menu()
                bm.Add("Clear all history", (*) => AskClear())
                bm.Show()
            }
            return
        }
        if row < 1 || row > shown.Length   ; right-click on the column header sends a bogus number, ignore it
            return
        it := shown[row]
        meta := it[5]
        m := Menu()
        m.Add("Run", (*) => RunRow(row))
        m.Default := "Run"
        m.Add()
        if meta.Has("cmd")
            m.Add("Copy command", (*) => CopyText(meta["cmd"]))
        if meta.Has("path")
            m.Add("Copy path", (*) => CopyText(meta["path"]))
        if meta.Has("text")
            m.Add("Copy text", (*) => CopyText(meta["text"]))
        if meta.Has("dir")
            m.Add("Open folder location", (*) => (g.Destroy(), OpenFolder(meta["dir"])))
        if meta.Has("cfg")
            m.Add("Edit config.ahk", (*) => (g.Destroy(), EditConfig()))
        if meta.Has("custom") {
            m.Add("Edit entry", (*) => (g.Destroy(), EditCustom(it)))
            m.Add("Remove entry", (*) => AskRemove(it))
        }
        if tabs.Text = "History" {
            m.Add()
            m.Add("Remove from History", (*) => (RemoveHistory(it), Fill()))
            m.Add("Clear all history", (*) => AskClear())
        }
        m.Show()
        try lv.Modify(0, "-Select")   ; popup closed: clear the selection again (try: the window may be gone after Run/Open)
    }

    tabs.OnEvent("Change", Fill)
    tabs.Choose(state["tab"])   ; reopen on the last used tab (default: Apps)
    Fill()

    lv.OnEvent("DoubleClick", (ctrl, row) => RunRow(row))
    ; Row really under the mouse (screen x, y): 0 = empty area, -1 = column header.
    ; The ContextMenu event itself reports the focused row (the first one) when you click outside any row.
    RowAt() {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", pt)   ; screen coords (the event's own x, y are window-relative)
        x := NumGet(pt, 0, "Int")
        y := NumGet(pt, 4, "Int")
        hdr := SendMessage(0x101F, 0, 0, lv.Hwnd)   ; LVM_GETHEADER
        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", hdr, "Ptr", rc)
        if x >= NumGet(rc, 0, "Int") && x < NumGet(rc, 8, "Int") && y >= NumGet(rc, 4, "Int") && y < NumGet(rc, 12, "Int")
            return -1
        hti := Buffer(24, 0)   ; LVHITTESTINFO: POINT pt, flags, iItem, iSubItem, iGroup
        NumPut("Int", x, "Int", y, hti)
        DllCall("ScreenToClient", "Ptr", lv.Hwnd, "Ptr", hti)
        SendMessage(0x1039, 0, hti, lv.Hwnd)   ; LVM_SUBITEMHITTEST
        return NumGet(hti, 12, "Int") + 1   ; iItem is 0-based, -1 = no row -> 0
    }
    lv.OnEvent("ContextMenu", (ctrl, row, isRight, *) => ShowRowMenu(isRight ? RowAt() : row))
    hint := g.Add("Text", "xm", "Enter = run     Right-click = more     Esc = close")
    addBtn := g.Add("Button", "w70", "+ Add")
    addBtn.OnEvent("Click", (*) => (g.Destroy(), ShowAdd()))
    ; Right-click on empty panel space (margins, bottom strip): script actions
    ShowPanelMenu() {
        m := Menu()
        m.Add("Reload script", (*) => Reload())
        m.Add("Open script folder", (*) => (g.Destroy(), OpenFolder(A_ScriptDir)))
        m.Add("Edit config.ahk", (*) => (g.Destroy(), EditConfig()))
        if tabs.Text = "History" {   ; only History has something to clear
            m.Add()
            m.Add("Clear all history", (*) => AskClear())
        }
        m.Show()
    }
    g.Add("Button", "Default Hidden").OnEvent("Click", (*) => RunRow())   ; Enter key
    ; Resize: tab + list follow the window width, list also follows the height, hint stays at the bottom
    OnSize(guiObj, minMax, w, h) {
        if minMax = -1
            return
        state["w"] := w   ; remember the size for the next open
        state["h"] := h
        cw := w - 2 * g.MarginX
        hint.GetPos(, , , &hh)
        addBtn.GetPos(, , &bw, &bh)
        lv.GetPos(, &ly)
        tabs.Move(, , cw)
        lv.Move(, , cw, h - ly - bh - 2 * g.MarginY)
        addBtn.Move(w - bw - g.MarginX, h - bh - g.MarginY)
        hint.Move(, h - bh - g.MarginY + (bh - hh) // 2)
        FitCols()   ; keep columns fitted to the new width
    }
    g.OnEvent("Size", OnSize)
    g.OnEvent("ContextMenu", (gObj, ctrl, item, isRight, x, y) => (!ctrl || ctrl = hint) ? ShowPanelMenu() : "")   ; only empty space, controls keep their own
    g.OnEvent("Escape", (*) => g.Destroy())
    g.OnEvent("Close", (*) => g.Destroy())
    g.Show("w" state["w"] " h" state["h"])   ; reopen at the last size (default = minimum, same as +MinSize)
    OnSize(g, 0, state["w"], state["h"])
    lv.Focus()
}

; KeyWait lets the window open after the button is released, so the release can't click a row.
CapsLock & RButton:: {
    KeyWait "RButton"
    ShowMenu()
}
