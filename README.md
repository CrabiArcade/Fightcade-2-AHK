# Fightcade-2-AHK
This script will let you play without a keyboard/mouse

## Ce que fait le module

- **Lancement & auto-join UI** : démarre Fightcade 2 (détecte `fc2-electron.exe`/`fightcade2.exe`) et automatise la recherche + clic JOIN sur le premier résultat correspondant au terme passé en argument (ex. `garou`).
- **Navigation sans clic intempestif** : gestion de 3 zones (🔔 Cloche / 💬 Chat / 👥 Contacts). Dans Contacts, les touches `g`/`v` se déplacent sans cliquer pour éviter les challenges involontaires ; `a` valide quand tu le décides.
- **Notifications pilotées au clavier** : ouverture de la liste (cloche), déplacement ligne par ligne, choix ACCEPT/DECLINE au clavier, clic calculé via offsets.
- **Plein écran auto en spectateur (FBNeo)** : lorsqu’un spectate démarre (fin de l’écran « [no game loaded] »), le script force le plein écran automatiquement.
- **Journalisation** : écrit un log `fc2_log.txt` (timestamps, zones, rangs visibles…) pour diagnostiquer facilement.

_Remarque_ : la position des éléments UI + couleurs des boutons Accept/Decline sont lues dans `FC2_JoinRoom.cfg.ini` (`[coords]` et `[colors]`, ex. `search_icon_x/y`, `card1_join_x/y`, `notif_*`, `accept_color*`, `decline_color*`).
