
; Shortcut list: CapsLock + H shows every shortcut, read straight from the .ahk files.
; Description = the inline comment after the hotkey (...:: Run "x"  ; description).
; If a hotkey has no inline comment, the comment line right above it is used.
; Add a shortcut anywhere with a comment, and it shows up here automatically.

; Files to scan (add new .ahk files here)
helpFiles := ["main.ahk", "menu.ahk", "shortcuts.ahk", "snippets.ahk", "help.ahk"]

ReadShortcuts() {
    rows := []
    for file in helpFiles {
        block := ""
        for line in StrSplit(FileRead(A_ScriptDir "\" file, "UTF-8"), "`n", "`r") {
            if SubStr(line, 1, 1) = ";" {
                if block = ""
                    block := Trim(SubStr(line, 2))
                continue
            }
            if RegExMatch(line, "^::(.+?)::(.*)$", &m)
                rows.Push([m[1], "ketik + spasi/Enter/Tab = " m[2]])
            else if RegExMatch(line, "^([^\s;:][^:]*?)::(.*)$", &m) {
                desc := RegExMatch(m[2], "\s;\s*(.*)$", &c) ? c[1] : block
                rows.Push([PrettyKey(m[1]), desc != "" ? desc : "(tanpa keterangan)"])
            }
            block := ""
        }
    }
    return rows
}

PrettyKey(k) {
    k := StrReplace(k, " & ", " + ")
    k := StrReplace(k, "RButton", "Klik kanan")
    if RegExMatch(k, "^(.* \+ )(\w)$", &p)
        k := p[1] StrUpper(p[2])
    return k
}

ShowHelp() {
    static g := ""
    if IsObject(g)
        g.Destroy()
    g := Gui("+AlwaysOnTop -MinimizeBox", "Daftar Shortcut (Esc = tutup)")
    g.SetFont("s10", "Segoe UI")
    lv := g.Add("ListView", "r12 w560 -Multi", ["Tombol", "Fungsi"])
    for row in ReadShortcuts()
        lv.Add(, row[1], row[2])
    lv.ModifyCol(1, 190)
    lv.ModifyCol(2, 350)
    g.OnEvent("Escape", (*) => g.Destroy())
    g.OnEvent("Close", (*) => g.Destroy())
    g.Show()
}

CapsLock & h:: ShowHelp()   ; tampilkan daftar shortcut ini
