
; FC2_JoinRoom_SETUP_v6.ahk — Assistant de capture de coordonnées
; Changelog vs v5:
; - Flow plus rapide et clair (prévisualisation des captures au fur et à mesure via ToolTip)
; - Sauvegarde des options supplémentaires si absentes (list_rows_visible)

#SingleInstance Force
#NoEnv
SendMode Input
SetTitleMatchMode, 2
CoordMode, Mouse, Screen

cfgFile := A_ScriptDir . "\FC2_JoinRoom.cfg.ini"

MsgBox, 64, Setup, Placez la souris sur chaque point demandé puis appuyez sur ESPACE. ESC pour annuler.

showPos(label) {
    MouseGetPos, sx, sy
    ToolTip, % label " — X:" sx "  Y:" sy
}

capture(label) {
    ToolTip, % "Placez la souris sur: " label "  (ESPACE = valider)"
    Loop {
        if GetKeyState("Escape","P") {
            ToolTip
            ExitApp
        }
        if GetKeyState("Space","P") {
            MouseGetPos, x, y
            ToolTip
            return {x:x, y:y}
        }
        showPos(label)
        Sleep, 20
    }
}

pts := {}
pts.loupe   := capture("Loupe (recherche)")
pts.search  := capture("Barre de recherche")
pts.join    := capture("Bouton JOIN (carte du jeu)")
pts.leave   := capture("Bouton LEAVE (si visible)")
pts.chat    := capture("Zone de saisie du chat")
pts.bell    := capture("Icône Cloche (notifications)")
pts.firstn  := capture("Première ligne de la liste de notifications")
pts.accept  := capture("Depuis la 1ère notif: CENTRE du bouton ACCEPT")
pts.decline := capture("Depuis la 1ère notif: CENTRE du bouton DECLINE")
pts.contact := capture("Premier contact (colonne de droite)")

; Offsets boutons par rapport à la 1ère ligne
acc_off_x := pts.accept.x - pts.firstn.x
acc_off_y := pts.accept.y - pts.firstn.y
dec_off_x := pts.decline.x - pts.firstn.x
dec_off_y := pts.decline.y - pts.firstn.y

; Hauteur de ligne
MsgBox, 64, Setup, Mesurez la hauteur d'une ligne: curseur sur la 1ère ligne puis ESPACE, ensuite curseur sur la 2ème ligne juste en dessous puis ESPACE.
p1 := capture("1ère ligne (haut)")
p2 := capture("2ème ligne (sous la 1ère)")
line_h := Abs(p2.y - p1.y)

; Ecriture INI
IniWrite, % pts.loupe.x,   %cfgFile%, coords, loupe_x
IniWrite, % pts.loupe.y,   %cfgFile%, coords, loupe_y
IniWrite, % pts.search.x,  %cfgFile%, coords, search_x
IniWrite, % pts.search.y,  %cfgFile%, coords, search_y
IniWrite, % pts.join.x,    %cfgFile%, coords, join_x
IniWrite, % pts.join.y,    %cfgFile%, coords, join_y
IniWrite, % pts.leave.x,   %cfgFile%, coords, leave_x
IniWrite, % pts.leave.y,   %cfgFile%, coords, leave_y
IniWrite, % pts.chat.x,    %cfgFile%, coords, chat_x
IniWrite, % pts.chat.y,    %cfgFile%, coords, chat_y
IniWrite, % pts.bell.x,    %cfgFile%, coords, bell_x
IniWrite, % pts.bell.y,    %cfgFile%, coords, bell_y
IniWrite, % pts.firstn.x,  %cfgFile%, coords, first_notif_x
IniWrite, % pts.firstn.y,  %cfgFile%, coords, first_notif_y
IniWrite, % acc_off_x,     %cfgFile%, coords, accept_off_x
IniWrite, % acc_off_y,     %cfgFile%, coords, accept_off_y
IniWrite, % dec_off_x,     %cfgFile%, coords, decline_off_x
IniWrite, % dec_off_y,     %cfgFile%, coords, decline_off_y
IniWrite, % pts.contact.x, %cfgFile%, coords, contact_first_x
IniWrite, % pts.contact.y, %cfgFile%, coords, contact_first_y
IniWrite, % line_h,        %cfgFile%, coords, line_h

; Options par défaut (sans écraser si déjà présentes)
IniRead, tmp1, %cfgFile%, opts, pixel_search, 
if (tmp1 = "")
    IniWrite, 0, %cfgFile%, opts, pixel_search

IniRead, tmp2, %cfgFile%, opts, safe_delay_ms, 
if (tmp2 = "")
    IniWrite, 200, %cfgFile%, opts, safe_delay_ms

IniRead, tmp3, %cfgFile%, opts, list_rows_visible, 
if (tmp3 = "")
    IniWrite, 10, %cfgFile%, opts, list_rows_visible

MsgBox, 64, Setup, Terminé ! Fichier mis à jour:`n%cfgFile%
ExitApp
