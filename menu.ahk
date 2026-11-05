
; Menu engine: builds the CapsLock + right click window (Gui + ListView) and registers
; every hotkey and hotstring from config.ahk. Normally you don't edit this file.

usedKeys := Map("r", "reload", "v", "clipboard history")   ; keys already taken (CapsLock + R / V, see main.ahk)
items := []                      ; rows of the window: [type, label, key, action]
state := Map("tab", "Command", "w", 460, "h", 300)   ; last opened tab + window size (kept while the script runs; resets on reload)

histFile := A_ScriptDir "\history.ini"   ; last run entries, survives reload and restart
histMax := 100
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

; Auto click toggle (macro keys "click:100" = left click every 100 ms). One auto clicker at a time.
; Never runs while Roblox Player is active (games may treat auto click as cheating); Roblox Studio is fine.
clickOn := false
Notice(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -1000)
}

StopClick(*) {
    global clickOn
    SetTimer(DoClick, 0)
    clickOn := false
}

DoClick() {
    if WinActive("ahk_exe RobloxPlayerBeta.exe") {
        StopClick()
        Notice("Auto click OFF (Roblox Player)")
        return
    }
    Click()
}

ToggleClick(ms, *) {
    global clickOn
    if clickOn {
        StopClick()
        Notice("Auto click OFF")
        return
    }
    if WinActive("ahk_exe RobloxPlayerBeta.exe") {
        Notice("Auto click is blocked in Roblox Player")
        return
    }
    clickOn := true
    SetTimer(DoClick, ms)
    Notice("Auto click ON (" ms " ms)")
}

; ---------- Entries added from the panel (+ Add), stored in custom.ini ----------
; One section per entry: [c1] with type=Command|Folder|Snippet, label, value (command / path / text), key,
; and dir (the folder a command runs in, Command only). Old type=App entries load as Command.
; label, value and dir are saved with a leading "~" so IniRead never strips quotes or spaces.

CustomWrite(sec, name, text) => IniWrite("~" text, customFile, sec, name)
CustomRead(sec, name) => SubStr(IniRead(customFile, sec, name, "~"), 2)

; Builds the row for one custom entry and claims its key / trigger.
MakeCustomItem(sec, kind, label, value, key, dir := "") {
    if kind = "Command" {   ; value = command, dir = folder it runs in
        fn := RunCommand.Bind(dir, value)
        RegisterKey(key, fn, label)
        return ["Command", label, key, fn, Map("dir", dir, "cmd", value, "custom", sec)]
    }
    if kind = "Folder" {
        fn := OpenFolder.Bind(value)
        RegisterKey(key, fn, label)
        return ["Folder", label, key, fn, Map("path", value, "custom", sec)]
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
        if kind = "App"   ; the App type was removed, old entries become Commands
            kind := "Command"
        label := CustomRead(sec, "label")
        value := CustomRead(sec, "value")
        key := CustomRead(sec, "key")
        dir := CustomRead(sec, "dir")
        if label = "" || value = ""
            continue
        row := MakeCustomItem(sec, kind, label, value, key, dir)
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
AddCustom(kind, label, value, key, dir := "") {
    if !FileExist(customFile)
        FileAppend("", customFile, "UTF-16")   ; Unicode ini, so emoji / accents in snippets and paths survive
    sec := NextCustomId()
    IniWrite(kind, customFile, sec, "type")
    CustomWrite(sec, "label", label)
    CustomWrite(sec, "value", value)
    CustomWrite(sec, "key", key)
    if dir != ""
        CustomWrite(sec, "dir", dir)
    row := MakeCustomItem(sec, kind, label, value, key, dir)
    items.Push(row)
    SortItems()
}

; Removes a custom entry: switches off its key / trigger, deletes it from custom.ini, items and History
RemoveCustom(it) {
    meta := it[5]
    if it[3] != "" {
        k := StrLower(it[3])
        if usedKeys.Has(k) && usedKeys[k] = it[2] {   ; only if this entry really owns the key
            try Hotkey("CapsLock & " k, "Off")
            usedKeys.Delete(k)
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
NameTaken(tab, label) {
    for it in items
        if it[1] = tab && it[2] = label
            return true
    return false
}

; The "+ Add" form. Types: Command, Folder and Snippet.
; The form is rebuilt from scratch whenever the type changes (just toggling .Visible leaves gaps).
; vals carries what was already typed, and the window position, over to the rebuilt form.
ShowAdd(kind := "", vals := "") {
    static f := ""
    if IsObject(f)
        try f.Destroy()
    if !IsObject(vals)
        vals := Map()
    if kind = ""   ; open on the type that matches the current tab
        kind := Map("Command", "Command", "Folder", "Folder", "Snippet", "Snippet").Get(state["tab"], "Command")
    tabName := kind   ; tab (= item type) the new entry ends up in
    isSnip := kind = "Snippet"
    isCmd := kind = "Command"

    f := Gui("+AlwaysOnTop", "Add entry")
    f.SetFont("s10", "Segoe UI")
    f.Add("Text", "w320", "Type")
    ddl := f.Add("DropDownList", "w320", ["Command", "Folder", "Snippet"])
    ddl.Choose(kind)
    eName := eDir := eCmd := eKey := eTrig := eText := br := ""
    if isSnip {   ; Snippet: Trigger -> Text
        f.Add("Text", "w320", "Trigger (e.g. `;gm)")
        eTrig := f.Add("Edit", "w320", vals.Get("trigger", ""))
        f.Add("Text", "w320", "Text to type")
        eText := f.Add("Edit", "w320", vals.Get("text", ""))
    } else {   ; Folder: Name -> Folder -> Key.  App / Command: Name -> Folder -> Command -> Key
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
    ok := f.Add("Button", "Default w100 xm", "Add")
    cancelBtn := f.Add("Button", "x+10 w100", "Cancel")

    ; Remembers the typed values + window position before the form is rebuilt for another type
    Collect() {
        if isSnip {
            vals["trigger"] := eTrig.Value
            vals["text"] := eText.Value
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

    Cancel(*) {
        try f.Destroy()
        ShowMenu()
    }

    Save(*) {
        f.Opt("+OwnDialogs")
        dir := ""
        key := ""
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
            if usedTriggers.Has(StrLower(label)) {
                MsgBox("The trigger " label " already exists.", "Add entry")
                return
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
            if NameTaken(tabName, label) {
                MsgBox("There is already a " kind " named '" label "'.", "Add entry")
                return
            }
            if key != "" {
                if !RegExMatch(key, "^[A-Za-z0-9]$") {
                    MsgBox("Key must be a single letter or digit.", "Add entry")
                    return
                }
                if usedKeys.Has(StrLower(key)) {
                    MsgBox("CapsLock + " StrUpper(key) " is already used (" usedKeys[StrLower(key)] ").", "Add entry")
                    return
                }
            }
        }
        try {
            AddCustom(kind, label, value, key, isCmd ? dir : "")
        } catch as err {
            MsgBox("Could not save:`n" err.Message, "Add entry")
            return
        }
        try f.Destroy()
        state["tab"] := tabName   ; reopen the menu on the tab of the new entry
        ShowMenu()
    }

    ddl.OnEvent("Change", (*) => (Collect(), ShowAdd(ddl.Text, vals)))   ; rebuild the form for the new type
    if IsObject(br)
        br.OnEvent("Click", Browse)
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
        fn := RegExMatch(item[2], "^click:(\d+)$", &cm) ? ToggleClick.Bind(Integer(cm[1])) : SendMacro.Bind(item[2])
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
    items.Push(["Script", "Edit config.ahk", "", EditConfig, Map()])
    items.Push(["Script", "Clipboard history", "v", (*) => Send("#v"), Map()])   ; hotkey itself lives in main.ahk
    items.Push(["Script", "Reload script", "r", (*) => Reload(), Map()])
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
    tabs := g.Add("Tab3", "w580 h28", ["History", "Command", "Folder", "Macro", "Script", "Snippet"])
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
        if meta.Has("custom")
            m.Add("Remove entry", (*) => AskRemove(it))
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
