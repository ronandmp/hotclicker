#Requires AutoHotkey v2.0

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

iconFolder := A_ScriptDir "\icons"
POS_INI    := A_ScriptDir "\positions.ini"
CHROMA     := "FF00FE"   ; cor invisível (preserva alfa)

gap := 10
startY := 100
nextX  := 100

; ---- lê posições salvas ----
saved := Map()
if FileExist(POS_INI) {
    ini := FileRead(POS_INI, "UTF-8")
    for line in StrSplit(ini, "`n", "`r") {
        if RegExMatch(line, "^([^=]+)=(\d+),(\d+)$", &m)
            saved[Trim(m[1])] := { x: Integer(m[2]), y: Integer(m[3]) }
    }
}

windows := []
HotkeyMap := Map()  ; tecla -> hwnd

; ---- cria uma janela por PNG ----
Loop Files iconFolder "\*.png" {
    name := A_LoopFileName
    keyName := StrLower(RegExReplace(name, "\.png$"))  ; nome sem extensão
    img  := A_LoopFileFullPath

    g := Gui()
    g.Opt("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := CHROMA
    pic := g.Add("Picture", "x0 y0", img)
    pic.OnEvent("Click", OnPicClick)
    pic.GetPos(, , &w, &h)

    if saved.Has(name) {
        x := saved[name].x, y := saved[name].y
    } else {
        x := nextX, y := startY
        nextX += w + gap
    }

    g.Show(Format("x{} y{} AutoSize", x, y))
    WinSetTransColor(CHROMA, "ahk_id " g.Hwnd)
    windows.Push({ name: name, gui: g, pic: pic })
    HotkeyMap[keyName] := g.Hwnd
}

; ---- mostra atalhos carregados ----
keys := []
for k, _ in HotkeyMap
    keys.Push(k)
MsgBox "Atalhos carregados!"

; ---- loop permanente pra detectar teclas ----
SetTimer(CheckKeys, 50) ; verifica a cada 50ms (~20x por segundo)

; ---- Shift+Esc = salvar e sair ----
Hotkey("+Esc", (*) => SaveAndExit())

; ---- funções ----
CheckKeys() {
    global HotkeyMap
    for key, hwnd in HotkeyMap {
        ; tenta detectar tanto letras quanto F-teclas
        if RegExMatch(key, "^f\d{1,2}$") {
            if GetKeyState(StrUpper(key), "P")
                ActivateIcon(hwnd, key)
        } else {
            if GetKeyState(key, "P")
                ActivateIcon(hwnd, key)
        }
    }
}

ActivateIcon(hwnd, key) {
    static cooldown := Map()
    now := A_TickCount
    if cooldown.Has(hwnd) && now - cooldown[hwnd] < 300
        return
    cooldown[hwnd] := now

    pt := GetWindowCenter(hwnd)
    if !pt
        return

    picHwnd := GetFirstChild(hwnd)

    ; habilita click-through na janela e no Picture
    SetClickThrough(hwnd, true)
    if picHwnd
        SetClickThrough(picHwnd, true)

    ; pequeno respiro garante que o estilo “pegue”
    Sleep 15
    MouseMove pt.x, pt.y, 0
    Sleep 10
    Click "Left"          ; clique único no app por baixo
    Sleep 10

    ; volta ao normal
    if picHwnd
        SetClickThrough(picHwnd, false)
    SetClickThrough(hwnd, false)
}



GetWindowCenter(hwnd) {
    ; usa WinAPI GetWindowRect pra coordenadas *de tela* (lidando bem com DPI/monitores)
    rect := Buffer(16, 0) ; LEFT, TOP, RIGHT, BOTTOM (4*4 bytes)
    if !DllCall("GetWindowRect", "ptr", hwnd, "ptr", rect, "int")
        return 0
    left   := NumGet(rect, 0,  "int")
    top    := NumGet(rect, 4,  "int")
    right  := NumGet(rect, 8,  "int")
    bottom := NumGet(rect, 12, "int")
    return { x: (left + right) // 2, y: (top + bottom) // 2 }
}

SetClickThrough(hwnd, on := true) {
    ; GWL_EXSTYLE = -20, WS_EX_TRANSPARENT = 0x20
    ex := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
    ex := on ? (ex | 0x20) : (ex & ~0x20)
    DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr", ex)
}

GetFirstChild(hwnd) {
    ; retorna o primeiro filho (nosso Picture)
    return DllCall("FindWindowEx", "ptr", hwnd, "ptr", 0, "ptr", 0, "ptr", 0, "ptr")
}

OnPicClick(ctrl, *) {
    hwnd := ctrl.Gui.Hwnd
    PostMessage(0xA1, 2,,, "ahk_id " hwnd)
}

ArrayToString(arr, sep := ", ") {
    out := ""
    for i, v in arr {
        if (i > 1)
            out .= sep
        out .= v
    }
    return out
}

SaveAndExit() {
    SavePositions()
    ExitApp
}

SavePositions() {
    global windows, POS_INI
    buf := ""
    for _, item in windows {
        WinGetPos &gx, &gy,,, "ahk_id " item.gui.Hwnd
        buf .= item.name "=" gx "," gy "`n"
    }
    try FileDelete(POS_INI)
    FileAppend(buf, POS_INI, "UTF-8")
}
