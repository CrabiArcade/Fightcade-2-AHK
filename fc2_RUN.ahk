/*
  fc2_run_v42.ahk — AHK 1.1 (labels only)
  - Zones: Cloche(1) ↔ Chat(2) ↔ Contacts(3) — start at Chat
  - f = GAUCHE (3→2→1→3), h = DROITE (1→2→3→1) — déterministe
  - Contacts: g/v NE CLIQUENT PLUS. 1 par 1 avec scroll, la souris ne fait que se POSER.
      * Bas de page: WheelDown 1, update index, souris sur la nouvelle dernière ligne visible (pas de clic).
      * Haut de page: WheelUp 1, update index, souris sur la nouvelle première ligne visible (pas de clic).
  - 'a' en zone Contacts fait le double-clic (challenge). 
  - 1s d'attente avant de taper la recherche
  - Esc (si FC2 actif) : ferme FC2 + quitte script
*/

#SingleInstance Force
#NoEnv
#Persistent
#InstallKeybdHook
#InstallMouseHook
SendMode Input
SetTitleMatchMode, 2
ListLines, Off
CoordMode, Mouse, Window
CoordMode, Pixel, Window
DllCall("SetProcessDPIAware")

; ---------- CONFIG PATHS ----------
fc_root  := "D:\HFSBox\Emulators\FightCade2"
fc_title := "Fightcade - Online retro gaming"
cfg      := A_ScriptDir . "\FC2_JoinRoom.cfg.ini"
log_path := A_ScriptDir . "\fc2_log.txt"

; ---------- TIMINGS ----------
ColdBootDelay      := 6000
SearchDebounceMs   := 1000
JoinHoverMs        := 1000
DownloaderAppearMs := 15000
DownloaderMaxMs    := 420000
PostDownloadDelay  := 500

; ---------- STATE ----------
zone := 2              ; 1=Cloche, 2=Chat, 3=Contacts
sel_idx := 0           ; index absolu (virtuel) du contact en focus souris
top_idx := 0           ; index de la première ligne visible
notif_idx := 0
cmd_side := 1          ; 1=ACCEPT, 2=DECLINE
notif_mode := false
chat_mode := false
right_view_rows := 0   ; calculé dynamiquement
lastFocusTitleLog := 0
fbneo_watch_started := false

; ---------- LOG ----------
FormatTime, t0,, yyyy-MM-dd HH:mm:ss
FileAppend, % t0 "  START v42 no-click-nav (g/v)`r`n", %log_path%

; ---------- READ ARG ----------
query := ""
if (IsObject(A_Args) && A_Args.MaxIndex()>=1)
    query := A_Args[1]
if (query = "") {
    full := DllCall("GetCommandLine","str")
    pos := InStr(full, A_ScriptFullPath, false)
    if (pos) {
        rest := SubStr(full, pos + StrLen(A_ScriptFullPath) + 1)
        rest := RegExReplace(rest, "^\s+|\s+$", "")
        if (rest != "") {
            if (SubStr(rest,1,1) = """" && InStr(rest, """", false, 2))
                rest := RegExReplace(rest, "^""(.*)""$", "$1")
            parts := StrSplit(rest, A_Space, " `t")
            if (IsObject(parts) && parts.MaxIndex()>=1)
                query := parts[1]
        }
    }
}

if (query = "") {
    MsgBox, 48, FC2, Pas d'argument jeu. Exemple:`nAutoHotkey.exe fc2_run_v42.ahk garou
    Goto, __stay
}

; ---------- LOAD COORDS ----------
IniRead, search_icon_x, %cfg%, coords, search_icon_x, 0
IniRead, search_icon_y, %cfg%, coords, search_icon_y, 0
IniRead, search_bar_x,  %cfg%, coords, search_bar_x,  0
IniRead, search_bar_y,  %cfg%, coords, search_bar_y,  0
IniRead, card1_join_x,  %cfg%, coords, card1_join_x,  0
IniRead, card1_join_y,  %cfg%, coords, card1_join_y,  0
IniRead, leftlist_item1_x, %cfg%, coords, leftlist_item1_x, 0
IniRead, leftlist_item1_y, %cfg%, coords, leftlist_item1_y, 0
IniRead, leave_btn_x, %cfg%, coords, leave_btn_x, 0
IniRead, leave_btn_y, %cfg%, coords, leave_btn_y, 0
IniRead, right_first_x, %cfg%, coords, right_first_x, 0
IniRead, right_first_y, %cfg%, coords, right_first_y, 0
IniRead, right_row_h,   %cfg%, coords, right_row_h,   36
IniRead, chat_x,  %cfg%, coords, chat_x, 0
IniRead, chat_y,  %cfg%, coords, chat_y, 0
IniRead, bell_x,  %cfg%, coords, bell_x, 0
IniRead, bell_y,  %cfg%, coords, bell_y, 0
IniRead, notif_item1_x, %cfg%, coords, notif_item1_x, 0
IniRead, notif_item1_y, %cfg%, coords, notif_item1_y, 0
IniRead, notif_row_h,   %cfg%, coords, notif_row_h, 40
IniRead, notif_accept_dx, %cfg%, coords, notif_accept_dx, 0
IniRead, notif_accept_dy, %cfg%, coords, notif_accept_dy, 0
IniRead, notif_decline_dx, %cfg%, coords, notif_decline_dx, 0
IniRead, notif_decline_dy, %cfg%, coords, notif_decline_dy, 0

; ---------- RESOLVE EXE ----------
exe := ""
c1 := fc_root . "\fc2-electron\fc2-electron.exe"
c2 := fc_root . "\fightcade2.exe"
c3 := A_ScriptDir . "\fc2-electron\fc2-electron.exe"
c4 := A_ScriptDir . "\fightcade2.exe"
if FileExist(c1)
    exe := c1
else if FileExist(c2)
    exe := c2
else if FileExist(c3)
    exe := c3
else if FileExist(c4)
    exe := c4

if (exe = "") {
    MsgBox, 16, FC2, Impossible de localiser Fightcade2.`nTestes:`n%c1%`n%c2%`n%c3%`n%c4%
    FormatTime, t,, yyyy-MM-dd HH:mm:ss
    FileAppend, % t "  ABORT no exe`r`n", %log_path%
    Goto, __stay
}

; ---------- LAUNCH / ACTIVATE ----------
Process, Exist, fc2-electron.exe
if (ErrorLevel = 0) {
    Run, %exe%, %fc_root%
    FormatTime, t,, yyyy-MM-dd HH:mm:ss
    FileAppend, % t "  Run sent`r`n", %log_path%
    Sleep, %ColdBootDelay%
} else {
    FormatTime, t,, yyyy-MM-dd HH:mm:ss
    FileAppend, % t "  already running pid " ErrorLevel "`r`n", %log_path%
}

WinWait, %fc_title%,, 30000
WinActivate, %fc_title%
WinWaitActive, %fc_title%,, 15000
WinGet, mm, MinMax, %fc_title%
if (mm != 1){
  WinMaximize, %fc_title%
  Sleep, 300
}

; ---------- OPTION: LEAVE FIRST ----------
if (leave_btn_x + leave_btn_y > 0) {
    Click, %leave_btn_x%, %leave_btn_y%
    Sleep, 300
}

; ---------- SEARCH + JOIN ----------
Click, %search_icon_x%, %search_icon_y%
Sleep, 150
Click, %search_bar_x%, %search_bar_y%
Sleep, 1000            ; attendre 1 seconde avant d'écrire
Send ^a
Sleep, 100
Send %query%
Sleep, %SearchDebounceMs%
MouseMove, %card1_join_x%, %card1_join_y%, 0
Sleep, %JoinHoverMs%
Click, %card1_join_x%, %card1_join_y%

; ---------- HANDLE DOWNLOADER (frm.exe) ----------
t0 := A_TickCount
down := false
__dlp1:
Process, Exist, frm.exe
if (ErrorLevel) {
    down := true
    goto __dlp1_end
}
if (A_TickCount - t0 > DownloaderAppearMs)
    goto __dlp1_end
Sleep, 120
goto __dlp1
__dlp1_end:

if (down) {
    t0 := A_TickCount
    __dlp2:
    Process, Exist, frm.exe
    if (ErrorLevel=0)
        goto __dlp2_end
    if (A_TickCount - t0 > DownloaderMaxMs)
        goto __dlp2_end
    Sleep, 250
    goto __dlp2
    __dlp2_end:
    Sleep, %PostDownloadDelay%
}

; ---------- ENTER ROOM (left list first item) ----------
Sleep, 1200
Click, %leftlist_item1_x%, %leftlist_item1_y%
Sleep, 150
Send {WheelUp 6}
Sleep, 120
Click, %leftlist_item1_x%, %leftlist_item1_y%
Sleep, 120
Click, %leftlist_item1_x%, %leftlist_item1_y%, 2

; ---------- START AT CHAT ----------
zone := 2
top_idx := 0
Gosub, __calc_view_rows
if (chat_x + chat_y > 0) {
    Sleep, 150
    Click, %chat_x%, %chat_y%
    Sleep, 80
    Send {End}
}
tipmsg := "Zones: f=GAUCHE / h=DROITE | Cloche ↔ Chat ↔ Contacts | g/v=haut/bas | a=valider | b=retour | Esc=Quit"
tipms := 2400
Gosub, __showtip
Gosub, __focusZone

if (!fbneo_watch_started) {
    SetTimer, __fbneo_watch, 400
    fbneo_watch_started := true
}

; ---------- HOTKEYS (active only in FC2 window) ----------
#IfWinActive, Fightcade - Online retro gaming

Esc::
  WinClose, %fc_title%
  Sleep, 200
  ExitApp
return

g::
  ifWinNotActive, %fc_title%
    WinActivate, %fc_title%
  if (notif_mode){
     if (notif_idx>0) notif_idx--
     Gosub, __moveNotifCursor
  } else if (zone=3) {
     ; MOVE UP one user (no click)
     if (sel_idx>0) {
        vis := sel_idx - top_idx
        if (vis>0) {
          sel_idx--
          vis--
          ry := right_first_y + (vis*right_row_h)
          MouseMove, %right_first_x%, %ry%, 0
        } else {
          ; at top row -> scroll up one step, select previous, then hover new TOP row
          if (top_idx>0) {
             MouseMove, %right_first_x%, %right_first_y%, 0
             Send {WheelUp}
             Sleep, 40
             top_idx--
             sel_idx--
             MouseMove, %right_first_x%, %right_first_y%, 0
          }
        }
     }
  }
return

v::
  ifWinNotActive, %fc_title%
    WinActivate, %fc_title%
  if (notif_mode){
     notif_idx++
     Gosub, __moveNotifCursor
  } else if (zone=3) {
     ; MOVE DOWN one user (no click)
     vis := sel_idx - top_idx
     Gosub, __calc_view_rows_if_needed
     maxVis := right_view_rows - 1
     if (vis < maxVis) {
        sel_idx++
        vis++
        ry := right_first_y + (vis*right_row_h)
        MouseMove, %right_first_x%, %ry%, 0
     } else {
        ; at bottom row -> scroll down one step, hover new BOTTOM row
        MouseMove, %right_first_x%, % (right_first_y + maxVis*right_row_h), 0
        Send {WheelDown}
        Sleep, 40
        top_idx++
        sel_idx++
        ryb := right_first_y + (maxVis*right_row_h)
        MouseMove, %right_first_x%, %ryb%, 0
     }
  }
return

f::
  if (notif_mode){
     if (cmd_side>1) cmd_side--
     Gosub, __moveNotifCursor
     tipmsg := "Bouton: " . (cmd_side=1 ? "ACCEPT" : "DECLINE")
     tipms := 900
     Gosub, __showtip
  } else {
     if (zone=3)
        zone := 2
     else if (zone=2)
        zone := 1
     else
        zone := 3
     Gosub, __focusZone
  }
return

h::
  if (notif_mode){
     if (cmd_side<2) cmd_side++
     Gosub, __moveNotifCursor
     tipmsg := "Bouton: " . (cmd_side=1 ? "ACCEPT" : "DECLINE")
     tipms := 900
     Gosub, __showtip
  } else {
     if (zone=1)
        zone := 2
     else if (zone=2)
        zone := 3
     else
        zone := 1
     Gosub, __focusZone
  }
return

a::
  if (notif_mode){
     x := notif_item1_x + (cmd_side=1 ? notif_accept_dx : notif_decline_dx)
     y := notif_item1_y + (notif_idx*notif_row_h) + (cmd_side=1 ? notif_accept_dy : notif_decline_dy)
     Click, %x%, %y%
  } else if (zone=1){
     Click, %bell_x%, %bell_y%
     Sleep, 120
     notif_mode := true
     notif_idx := 0
     cmd_side := 1
     Gosub, __moveNotifCursor
     tipmsg := "Notifications ON — g/v, f/h, a, b"
     tipms := 1200
     Gosub, __showtip
  } else if (zone=2){
     Click, %chat_x%, %chat_y%
     Sleep, 80
     Send {End}
     chat_mode := true
     tipmsg := "Chat ON — (placeholder)"
     tipms := 900
     Gosub, __showtip
  } else {
     Gosub, __dblclick_current_contact
  }
return

b::
  if (notif_mode){
     Click, %bell_x%, %bell_y%
     notif_mode := false
     tipmsg := "Notifications OFF"
     tipms := 800
     Gosub, __showtip
  } else if (chat_mode){
     chat_mode := false
     tipmsg := "Chat OFF"
     tipms := 800
     Gosub, __showtip
  } else {
     Send {Esc}
  }
return

c::
  if (accept_color1+accept_color2>0){
     Gosub, __try_accept
  } else Send {Enter}
return
e::
  if (decline_color1+decline_color2>0){
     Gosub, __try_decline
  } else Send {Esc}
return

n::
  Click, %bell_x%, %bell_y%
  tipmsg := "Toggle cloche"
  tipms := 700
  Gosub, __showtip
return

p::
  if (chat_x+chat_y>0){
    Click, %chat_x%, %chat_y%
    Sleep, 80
    Send gg{Enter}
  }
return

#IfWinActive

; ---------- LABEL HELPERS ----------
__calc_view_rows:
  if (chat_y>0 && right_first_y>0 && right_row_h>0){
     bottom_y := chat_y - 16
     rows := Floor( (bottom_y - right_first_y) / right_row_h )
     if (rows < 6)
        rows := 6
     right_view_rows := rows
  } else if (right_view_rows = 0){
     right_view_rows := 12
  }
  FormatTime, tx,, HH:mm:ss
  FileAppend, % tx "  view_rows=" right_view_rows "`r`n", %log_path%
return

__calc_view_rows_if_needed:
  if (right_view_rows<=0)
     Gosub, __calc_view_rows
return

__focusZone:
  if (zone=1){
    MouseMove, %bell_x%, %bell_y%, 0
    tip := "Zone: Cloche"
  } else if (zone=2){
    MouseMove, %chat_x%, %chat_y%, 0
    tip := "Zone: Chat"
  } else {
    MouseMove, %right_first_x%, %right_first_y%, 0
    tip := "Zone: Contacts"
  }
  tipmsg := tip
  tipms := 700
  Gosub, __showtip
  FormatTime, tx,, HH:mm:ss
  FileAppend, % tx "  zone=" zone "  top_idx=" top_idx " sel_idx=" sel_idx " view=" right_view_rows "`r`n", %log_path%
return

__moveNotifCursor:
  x := notif_item1_x + (cmd_side=1 ? notif_accept_dx : notif_decline_dx)
  y := notif_item1_y + (notif_idx*notif_row_h) + (cmd_side=1 ? notif_accept_dy : notif_decline_dy)
  MouseMove, %x%, %y%, 0
return

__showtip:
  sx := A_ScreenWidth//2 - 380
  ToolTip, %tipmsg%, %sx%, 20
  SetTimer, __hidetip, -%tipms%
return

__hidetip:
  ToolTip
return

__dblclick_current_contact:
  Gosub, __calc_view_rows_if_needed
  vis := sel_idx - top_idx
  maxVis := right_view_rows - 1
  if (vis<0) vis := 0
  if (vis>maxVis) vis := maxVis
  ry := right_first_y + (vis*right_row_h)
  MouseMove, %right_first_x%, %ry%, 0
  Click, %right_first_x%, %ry%, 2
return

; ---------- Pixel helpers for c/e ----------
__try_accept:
  Gosub, __find_click_accept
return
__try_decline:
  Gosub, __find_click_decline
return

__find_click_accept:
  if (accept_color1!=0){
    color := accept_color1
    Gosub, __scan_click_color_generic
    if (!ErrorLevel)
        return
  }
  if (accept_color2!=0){
    color := accept_color2
    Gosub, __scan_click_color_generic
  }
return
__find_click_decline:
  if (decline_color1!=0){
    color := decline_color1
    Gosub, __scan_click_color_generic
    if (!ErrorLevel)
        return
  }
  if (decline_color2!=0){
    color := decline_color2
    Gosub, __scan_click_color_generic
  }
return

__scan_click_color_generic:
  WinGetPos, , , w, h, Fightcade - Online retro gaming
  left := 80
  right := w - 80
  y2 := chat_y - 50
  y1 := y2 - 560
  PixelSearch, fx, fy, left, y1, right, y2, %color%, 18, Fast RGB
  if (ErrorLevel){
    Send {End}
    Sleep, 120
    PixelSearch, fx, fy, left, y1, right, y2, %color%, 18, Fast RGB
  }
  if (!ErrorLevel){
    Click, %fx%, %fy%
  }
return

; ---------- STAY RESIDENT ----------
__stay:
  global fbneo_watch_started
  SetTimer, __keepalive, 3000
  ; Démarre le watcher (toutes les 400 ms)
  if (!fbneo_watch_started) {
    SetTimer, __fbneo_watch, 400
    fbneo_watch_started := true
  }
__keepalive:
return



; ===== Auto plein écran FBNeo en mode SPECTATE (robuste) =====
fbneoSpectatingHwnd := 0
fbneoSpectateArmed := false
lastFcActive := ""
fbneoNoGameWatchHwnd := 0
fbneoNoGameWatchSince := 0

__fbneo_watch:
  global lastFocusTitleLog, log_path, fc_title, fbneoSpectatingHwnd, fbneoSpectateArmed, lastFcActive
  global fbneoNoGameWatchHwnd, fbneoNoGameWatchSince
  currentFcActive := WinActive(fc_title) ? 1 : 0
  if (lastFcActive = "")
  {
     lastFcActive := currentFcActive
  }
  else if (currentFcActive != lastFcActive)
  {
     FormatTime, txFocus,, yyyy-MM-dd HH:mm:ss
     if (currentFcActive)
        FileAppend, % txFocus "  FOCUS Fightcade activated`r`n", %log_path%
     else
        FileAppend, % txFocus "  FOCUS Fightcade lost`r`n", %log_path%
     lastFcActive := currentFcActive
  }

  activeHwnd := WinExist("A")
  if (A_TickCount - lastFocusTitleLog >= 1000)
  {
     activeTitle := ""
     if (activeHwnd)
        WinGetTitle, activeTitle, ahk_id %activeHwnd%
     FormatTime, txFocusTitle,, yyyy-MM-dd HH:mm:ss
     FileAppend, % txFocusTitle "  FOCUS active title=" activeTitle "`r`n", %log_path%
     lastFocusTitleLog := A_TickCount
  }

  ; Parcourt toutes les fenêtres FBNeo
  activeHwndNum := activeHwnd + 0
  FormatTime, tx,, HH:mm:ss
  FileAppend, % tx "  spectate active hwnd raw=" activeHwnd " normalized=" activeHwndNum "`r`n", %log_path%
  firstNoGameHwnd := 0
  preferredHwnd := 0
WinGet, list, List, Fightcade FBNeo
loop, %list%
{
    id := list%A_Index%
    WinGetTitle, t, ahk_id %id%
    if InStr(t, "[no game loaded]")
    {
        ; Candidat spectate détecté
        FormatTime, tx,, yyyy-MM-dd HH:mm:ss
        FileAppend, % tx "  spectate candidate hwnd=" id " normalized=" (id + 0) "`r`n", %log_path%

        if (!firstNoGameHwnd)
            firstNoGameHwnd := id

        ; Si la fenêtre candidate est la fenêtre active, on la préfère
        if (id + 0 = activeHwndNum)
        {
            preferredHwnd := id
            FileAppend, % tx "  spectate prefer active hwnd " id " (normalized " activeHwndNum ")`r`n", %log_path%

            ; Log additionnel lorsque la fenêtre active correspond
            if WinActive("ahk_id " id)
                FileAppend, % tx "  spectator wait active: " t "`r`n", %log_path%

            break
        }
    }
}

  if (!preferredHwnd && firstNoGameHwnd)
     preferredHwnd := firstNoGameHwnd

  if (preferredHwnd)
  {
     rearmedWatch := false
     if (fbneoNoGameWatchHwnd != preferredHwnd)
     {
        fbneoNoGameWatchHwnd := preferredHwnd
        rearmedWatch := true
     }
     if (!fbneoNoGameWatchSince || rearmedWatch)
     {
        fbneoNoGameWatchSince := A_TickCount
        FormatTime, txWatch,, yyyy-MM-dd HH:mm:ss
        FileAppend, % txWatch "  [no game loaded] trouvé, lancement du timer de 10 secondes hwnd=" (preferredHwnd + 0) "`r`n", %log_path%
     }
     fbneoSpectatingHwnd := preferredHwnd
     fbneoSpectateArmed := true
  }

  ; Si armé, vérifier que la même fenêtre est toujours là et que le titre n'a plus "[no game loaded]"
  if (fbneoSpectateArmed && fbneoSpectatingHwnd)
  {
     if WinExist("ahk_id " fbneoSpectatingHwnd)
     {
        WinGetTitle, t2, ahk_id %fbneoSpectatingHwnd%
        timeoutReached := (fbneoNoGameWatchHwnd = fbneoSpectatingHwnd)
            && (fbneoNoGameWatchSince)
            && (A_TickCount - fbneoNoGameWatchSince >= 10000)
        if (timeoutReached)
        {
           WinActivate, ahk_id %fbneoSpectatingHwnd%
           Sleep, 250
           ControlSend,, !{Enter}, ahk_id %fbneoSpectatingHwnd%
           FormatTime, txTimeout,, yyyy-MM-dd HH:mm:ss
           elapsed := A_TickCount - fbneoNoGameWatchSince
           FileAppend, % txTimeout "  spectate forced fullscreen after wait hwnd=" fbneoSpectatingHwnd " elapsed=" elapsed "ms`r`n", %log_path%
           fbneoSpectateArmed := false
           fbneoSpectatingHwnd := 0
           fbneoNoGameWatchHwnd := 0
           fbneoNoGameWatchSince := 0
        }
        else if !InStr(t2, "[no game loaded]")
        {
           ; Jeu chargé → plein écran
           WinActivate, ahk_id %fbneoSpectatingHwnd%
           Sleep, 250
           ControlSend,, !{Enter}, ahk_id %fbneoSpectatingHwnd%
           ; Reset pour éviter les répétitions
           fbneoSpectateArmed := false
           fbneoSpectatingHwnd := 0
           fbneoNoGameWatchHwnd := 0
           fbneoNoGameWatchSince := 0
        }
     }
     else
     {
        ; Fenêtre disparue
        fbneoSpectateArmed := false
        fbneoSpectatingHwnd := 0
        fbneoNoGameWatchHwnd := 0
        fbneoNoGameWatchSince := 0
     }
  }
return

; ===== ESC spécifique émulateurs (FBNeo/Flycast/etc.) =====
EmuActive() {
    WinGetTitle, t, A
    return InStr(t, "Fightcade FBNeo")
        || InStr(t, "FBNeo")
        || InStr(t, "Flycast")
        || InStr(t, "nullDC")
        || InStr(t, "Demul")
        || InStr(t, "Supermodel")
        || InStr(t, "MAME")
        || InStr(t, "RetroArch")
}

#If EmuActive()
Esc::
    ; Fermer l'émulateur actif
    Send, !{F4}
return
#If
