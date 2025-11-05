; =========================================================================
; HelpPanel.ahk  (para incluir no HotClicker.ahk)
; =========================================================================
#Requires AutoHotkey v2.0

if (IsSet(HP_ModuleLoaded) && HP_ModuleLoaded)
    return
HP_ModuleLoaded := true

; ----------------------- OPÇÕES ------------------------
if !IsSet(HP_AutoShow)
    HP_AutoShow := true
if !IsSet(HP_Hotkey)
    HP_Hotkey := "CapsLock"
if !IsSet(HP_RegisterEsc)
    HP_RegisterEsc := true
if !IsSet(HP_Width)
    HP_Width := 380
if !IsSet(HP_Height)
    HP_Height := 260
	
; Centraliza o painel automaticamente na tela
if !IsSet(HP_X)
    HP_X := (A_ScreenWidth  - HP_Width)  // 2
if !IsSet(HP_Y)
    HP_Y := (A_ScreenHeight - HP_Height) // 2
	
if !IsSet(HP_Font)
    HP_Font := "Segoe UI"
if !IsSet(HP_FontS)
    HP_FontS := 10
; -------------------------------------------------------

HP__Gui := 0
HP__Visible := false
HP__HelpText := "
(
Teclas básicas — Painel de Ajuda

CapsLock  : Alterna este painel de ajuda
Shift     : Modificador (ações secundárias)
Ctrl      : Modificador (atalhos de controle)
Alt       : Modificador (atalhos alternativos)
Tab       : Alterna foco / navegação entre áreas
Esc       : Fecha painel / cancela ação atual
Enter     : Confirma / executar seleção
Espaço    : Ação principal (ex.: disparo/pausa)
Mouse Esq : Clique principal / selecionar
Mouse Dir : Clique secundário / menu alternativo
F1..F12   : Funções configuráveis (app)
ScrollLock: Alterna comportamento do scroll
Dica      : Segure Shift+Ctrl para modos avançados
Dica 2    : Pressione CapsLock de novo para ocultar
)"

; =======================================================
; ===  FUNÇÕES PRINCIPAIS  ==============================
; =======================================================

HP_Init() {
    global HP__Gui, HP__Visible, HP__HelpText, HP_Width, HP_Height, HP_X, HP_Y, HP_Font, HP_FontS
    global HP_Hotkey, HP_RegisterEsc

    if (HP__Gui)
        return

    HP__Gui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Painel de Ajuda")
    HP__Gui.SetFont("s" HP_FontS, HP_Font)
    HP__Gui.Add("Text", "xm ym w" HP_Width " h20 Center", "PAINEL DE AJUDA — TECLAS RÁPIDAS")
    HP__Gui.Add("Text", "x10 y30 w" HP_Width-20 " h" HP_Height-40, HP__HelpText)

    HP__Gui.Show("x" HP_X " y" HP_Y " w" HP_Width " h" HP_Height)
    HP__Gui.Hide()
    HP__Visible := false

    ; registra hotkeys
    Hotkey(HP_Hotkey, (*) => HP_Toggle(), "On")
    if (HP_RegisterEsc)
        Hotkey("Esc", (*) => HP_Close(), "On")
}

HP_Toggle() {
    global HP__Gui, HP__Visible, HP_X, HP_Y, HP_Width, HP_Height
    if !HP__Gui
        HP_Init()
    if HP__Visible {
        HP__Gui.Hide()
        HP__Visible := false
    } else {
        HP__Gui.Show("x" HP_X " y" HP_Y " w" HP_Width " h" HP_Height)
        HP__Visible := true
    }
}

HP_Show() {
    global HP__Gui, HP__Visible, HP_X, HP_Y, HP_Width, HP_Height
    if !HP__Gui
        HP_Init()
    if !HP__Visible {
        HP__Gui.Show("x" HP_X " y" HP_Y " w" HP_Width " h" HP_Height)
        HP__Visible := true
    }
}

HP_Close() {
    global HP__Gui, HP__Visible, HP_RegisterEsc
    if (HP__Gui && HP__Visible) {
        HP__Gui.Hide()
        HP__Visible := false
        return
    }
    if (HP_RegisterEsc) {
        Hotkey("Esc", "Off")
        Send "{Esc}"
        Sleep 30
        Hotkey("Esc", "On")
    } else {
        Send "{Esc}"
    }
}

HP_Destroy() {
    global HP__Gui, HP__Visible, HP_Hotkey, HP_RegisterEsc
    Hotkey(HP_Hotkey, "Off")
    if (HP_RegisterEsc)
        Hotkey("Esc", "Off")
    if HP__Gui {
        HP__Gui.Destroy()
        HP__Gui := 0
        HP__Visible := false
    }
}

; =======================================================
; ===  ARRASTAR PAINEL  ================================
; =======================================================
; Usa uma lambda simples (sem Func()) → elimina "Invalid base"
OnMessage(0x0201, (wParam, lParam, msg, hwnd) => (
    (IsSet(HP__Gui) && HP__Gui && hwnd == HP__Gui.Hwnd)
        ? PostMessage(0xA1, 2, 0, hwnd)
        : ""
))

; =======================================================
; ===  AUTO-INICIALIZAÇÃO  =============================
; =======================================================
if (HP_AutoShow) {
    HP_Init()
    HP_Show()  ; mostra apenas 1x ao carregar
} else {
    HP_Init()
}
; =======================================================
; Fim do HelpPanel.ahk
; =======================================================
