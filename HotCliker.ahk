#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\HelpPanel.ahk


; ====== CONFIG ======
iconFolder := A_ScriptDir "\icons"
POS_INI    := A_ScriptDir "\positions.ini"
CHROMA     := "FF00FE"   ; cor “furo” que não aparece (preserva alfa das PNGs)
gap := 10
startY := 100
nextX  := 100

; coordenadas absolutas de tela
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

; ====== ESTADO ======
windows   := []          ; { name, gui, pic }
HotkeyMap := Map()       ; tecla -> hwnd (string em minúsculo, ex.: "a", "f5", "1")
saved     := Map()       ; posições salvas: name -> {x,y}
isEnabled := true        ; TAB alterna esse estado
checkIntervalMs := 50    ; frequência do loop de verificação de teclas

; ====== LER POSIÇÕES SALVAS ======
if FileExist(POS_INI) {
    ini := FileRead(POS_INI, "UTF-8")
    for line in StrSplit(ini, "`n", "`r") {
        if RegExMatch(line, "^([^=]+)=(\d+),(\d+)$", &m)
            saved[Trim(m[1])] := { x: Integer(m[2]), y: Integer(m[3]) }
    }
}

; ====== CRIAR UMA JANELA POR PNG ======
Loop Files iconFolder "\*.png" {
    name := A_LoopFileName              ; ex.: "a.png" / "1.png" / "F5.png"
    keyName := StrLower(RegExReplace(name, "\.png$"))  ; só o nome, minúsculo
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

; ====== LOOP DE TECLAS (só roda quando isEnabled = true) ======
SetTimer(CheckKeys, checkIntervalMs)

; ====== HOTKEYS GERAIS ======
Hotkey("+Esc", (*) => SaveAndExit())                      ; Shift+Esc salva e sai
Hotkey("Tab", (*) => ToggleActive())                      ; TAB alterna ligar/desligar

return ; ====== FIM DA INICIALIZAÇÃO ======

; ---------------- FUNÇÕES ----------------

ToggleActive() {
    global isEnabled, windows, checkIntervalMs, CHROMA
    isEnabled := !isEnabled

    ; congela redesenho do desktop pra aplicar tudo de uma vez
    DllCall("LockWindowUpdate", "ptr", DllCall("GetDesktopWindow", "ptr"))

    if !isEnabled {
        ; ===== DESATIVAR: pausa teclas + torna invisível e atravessável =====
        SetTimer(CheckKeys, 0)
        for _, item in windows {
            hwnd := item.gui.Hwnd
            pic  := GetFirstChild(hwnd)
            try {
                ; click-through (janela e Picture)
                SetClickThrough(hwnd, true)
                if pic
                    SetClickThrough(pic, true)
                ; alpha quase zero (1) — some sem piscar
                WinSetTransparent(1, "ahk_id " hwnd)
            }
        }
        OkTip("Overlay DESATIVADO (TAB)")
    } else {
        ; ===== ATIVAR: volta alpha, tira click-through e garante TOP =====
        for _, item in windows {
            hwnd := item.gui.Hwnd
            pic  := GetFirstChild(hwnd)
            try {
                WinSetTransparent(255, "ahk_id " hwnd)
                if pic
                    SetClickThrough(pic, false)
                SetClickThrough(hwnd, false)
                WinSetAlwaysOnTop(1, "ahk_id " hwnd)
                WinSetTransColor(CHROMA, "ahk_id " hwnd)
            }
        }
        SetTimer(CheckKeys, checkIntervalMs)
        OkTip("Overlay ATIVADO (TAB)")
    }

    ; libera redesenho do desktop
    DllCall("LockWindowUpdate", "ptr", 0)
}


OkTip(txt) {
    ToolTip(txt, 10, 10)
    SetTimer(() => ToolTip(), -900)
}

CheckKeys() {
    global HotkeyMap, isEnabled
    if !isEnabled
        return

    ; percorre as teclas mapeadas e verifica pressionamento
    for key, hwnd in HotkeyMap {
        ; F-teclas (f1..f24 em minúsculo no mapa → testa com maiúsculo)
        if RegExMatch(key, "^f\d{1,2}$") {
            if GetKeyState(StrUpper(key), "P")
                ActivateIcon(hwnd, key)
        } else {
            ; letras/números (já estão minúsculos)
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

    ; habilita click-through (janela + primeiro filho) para o clique “atravessar”
    picHwnd := GetFirstChild(hwnd)
    SetClickThrough(hwnd, true)
    if picHwnd
        SetClickThrough(picHwnd, true)

    Sleep 15
    MouseMove pt.x, pt.y, 0
    Sleep 10
    Click "Left"      ; clique simples
    Sleep 10

    if picHwnd
        SetClickThrough(picHwnd, false)
    SetClickThrough(hwnd, false)
}

OnPicClick(ctrl, *) {
    hwnd := ctrl.Gui.Hwnd
    ; arrastar janela simulando clique na barra de título
    PostMessage(0xA1, 2,,, "ahk_id " hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
}

GetWindowCenter(hwnd) {
    rect := Buffer(16, 0) ; LEFT, TOP, RIGHT, BOTTOM
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
    return DllCall("FindWindowEx", "ptr", hwnd, "ptr", 0, "ptr", 0, "ptr", 0, "ptr")
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
