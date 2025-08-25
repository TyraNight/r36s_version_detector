#!/bin/bash
# R36S — Détection DTB + MD5 + identification écran (AEUX) + manette OK dans dialog

set -euo pipefail

#-----------------------------------
# Configuration du terminal
#-----------------------------------
CURR_TTY="/dev/tty1"
if command -v sudo >/dev/null 2>&1; then
  sudo chmod 666 "$CURR_TTY" 2>/dev/null || true
else
  chmod 666 "$CURR_TTY" 2>/dev/null || true
fi
reset
# Masquer le curseur
printf "\e[?25l" > "$CURR_TTY"
dialog --clear > "$CURR_TTY"

#-----------------------------------
# Variables
#-----------------------------------
BOOT_DIR="${BOOT_DIR:-/boot}"
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || echo "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"

# Nom de log basé sur le nom du script
LOG="${LOG:-$SCRIPT_DIR/$(basename "$SCRIPT_PATH" .sh)_log.txt}"

# Test d'écriture ; si KO (µSD en RO ?), bascule sur /tmp
{ : >> "$LOG"; } 2>/dev/null || LOG="/tmp/$(basename "$SCRIPT_PATH" .sh)_log.txt"

ARKOS_SET=("rk3326-r35s-linux.dtb" "rk3326-rg351mp-linux.dtb")
EMUELEC_SET=("rf3536k4ka.dtb" "rf3536k3ka.dtb" "rk3326-evb-lp3-v12-linux.dtb")

#-----------------------------------
# Fonctions utilitaires
#-----------------------------------
ExitMenu() {
  printf "\033c" > "$CURR_TTY"
  # Couper gptokeyb si lancé
  if [[ -n "$(pgrep -f gptokeyb || true)" ]]; then
    if command -v sudo >/dev/null 2>&1; then
      pgrep -f gptokeyb | sudo xargs kill -9 2>/dev/null || true
    else
      pgrep -f gptokeyb | xargs kill -9 2>/dev/null || true
    fi
  fi
  # (Optionnel) restaurer une police console si besoin :
  if [[ ! -e "/dev/input/by-path/platform-odroidgo3-joypad-event-joystick" && -f "/usr/share/consolefonts/Lat7-Terminus20x10.psf.gz" ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz 2>/dev/null || true
    else
      setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz 2>/dev/null || true
    fi
  fi
  # Afficher de nouveau le curseur
  printf "\e[?25h" > "$CURR_TTY"
  exit 0
}
trap ExitMenu EXIT INT TERM

has_cmd() { command -v "$1" >/dev/null 2>&1; }

md5_of() {
  local f="$1"
  if has_cmd md5sum; then
    md5sum "$f" | awk '{print $1}'
  elif has_cmd busybox; then
    busybox md5sum "$f" | awk '{print $1}'
  elif has_cmd openssl; then
    openssl dgst -md5 -r "$f" | awk '{print $1}'
  else
    echo "ERREUR: aucun md5sum/busybox/openssl disponible." >&2
    return 2
  fi
}

filesize_bytes() { wc -c < "$1" | awk '{print $1}'; }

start_gptokeyb() {
  # Autoriser uinput
  if command -v sudo >/dev/null 2>&1; then
    sudo chmod 666 /dev/uinput 2>/dev/null || true
  else
    chmod 666 /dev/uinput 2>/dev/null || true
  fi
  export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
  # Stopper éventuel gptokeyb
  if [[ -n "$(pgrep -f gptokeyb || true)" ]]; then
    if command -v sudo >/dev/null 2>&1; then
      pgrep -f gptokeyb | sudo xargs kill -9 2>/dev/null || true
    else
      pgrep -f gptokeyb | xargs kill -9 2>/dev/null || true
    fi
  fi
  # Lancer gptokeyb si présent
  if [[ -x "/opt/inttools/gptokeyb" ]]; then
    /opt/inttools/gptokeyb -1 "r36s-dtb-checker.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
  fi
}

#-----------------------------------
# Détection du DTB
#-----------------------------------
TYPE="UNKNOWN"
DTB_PATH=""
DTB_NAME=""

for n in "${ARKOS_SET[@]}"; do
  if [[ -f "$BOOT_DIR/$n" ]]; then
    TYPE="ARKOS_AEUX"
    DTB_PATH="$BOOT_DIR/$n"
    DTB_NAME="$n"
    break
  fi
done

if [[ -z "$DTB_PATH" ]]; then
  for n in "${EMUELEC_SET[@]}"; do
    if [[ -f "$BOOT_DIR/$n" ]]; then
      TYPE="EMUELEC"
      DTB_PATH="$BOOT_DIR/$n"
      DTB_NAME="$n"
      break
    fi
  done
fi

if [[ -z "$DTB_PATH" ]]; then
  MSG=$'Aucun DTB attendu trouvé dans '"$BOOT_DIR"$'\n\nRecherchés (ordre):\n- ArkOS (AEUX): '"${ARKOS_SET[*]}"$'\n- EmuELEC: '"${EMUELEC_SET[*]}"$'\n\nConseils:\n- Vérifie que /boot est monté.\n- Si besoin, spécifie BOOT_DIR: ex. BOOT_DIR=/mnt/boot ./r36s-dtb-checker.sh'
  dialog --backtitle "R36S DTB checker | Code by TyraNight" --title "DTB introuvable" --msgbox "$MSG" 14 78 > "$CURR_TTY"
  ExitMenu
fi

#-----------------------------------
# Calculs et mapping écran
#-----------------------------------
MD5="$(md5_of "$DTB_PATH")"
SIZE="$(filesize_bytes "$DTB_PATH")"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"

SCREEN_INFO="(non applicable)"
NOTE_EXTRA=""

if [[ "$TYPE" == "ARKOS_AEUX" ]]; then
  case "$MD5" in
    543038f0cc9b515401186ebbde232cfa|9f41df45acac67bff88ec52306efc225|72856dd54e77a0fd61d9c2a59b08b685|040b5bfff8c1969aaeedcfbe8a33ad06|f6984db1b07f03a90c182c59dd51ccf0)
      SCREEN_INFO="Panel 3 (V4)" ;;
    df50e4c1847859cc94f7e6d3e4951e15)
      SCREEN_INFO="EmuELEC" ;;
    7b76c4e4333887fd0ccc0afddd2f41ce|4863e7544738df62eaae4a1bec031fd9|5871fde00d2ed1e5866665e38ee3cfab|b92e8d791dec428b65ad52ccc5a17af4|8faf0a3873008548c55dfff574b2a3f9|42a3021377abadd36375e62a7d5a2e40|c4547ce22eca3c318546f3cbf5f3d878)
      SCREEN_INFO="Panel 4 (V5)" ;;
    b3bf18765a4453b8eaeaf60362b79b3d|f6984db1b07f03a90c182c59dd51ccf0)
      SCREEN_INFO="Panel 3 (V3)" ;;
	bfc6068ef7d80575bef04b36ef881619)
	  SCREEN_INFO="Panel 0" ;;
	a5d6f30491abac29423d0c1334ad88d3|2d82650c523ac734a16bddf600286d6d|daf777a6b5ed355c3aaf546da4e42da9)
	  SCREEN_INFO="Panel 2" ;;
	a3d55922b4ccce3e2b23c57cefdd9ba7|28792e1126f543279237ec45de5c03e5|3869152c5fb8e5c0e923f7f00e42231e)
	  SCREEN_INFO="Panel 1" ;;
	861278f7ab7ade97ac1515aedbbdeff0)
	  SCREEN_INFO="Panel 5" ;;
    *)
      SCREEN_INFO="Inconnu (MD5 non référencé)"
      NOTE_EXTRA="Donne-moi ce MD5 pour l’ajouter à la base de données." ;;
  esac
fi

#-----------------------------------
# Sortie console + log
#-----------------------------------
OUT=$'R36S — Rapport DTB\n---------------------\n'"Date       : $DATE"$'\n'"Dossier    : $BOOT_DIR"$'\n'"DTB        : $DTB_NAME"$'\n'"Taille     : ${SIZE} octets"$'\n'"MD5        : $MD5"$'\n'"Type       : $TYPE"
if [[ "$TYPE" == "ARKOS_AEUX" ]]; then
  OUT+=$'\n'"Écran     : $SCREEN_INFO"
elif [[ "$TYPE" == "EMUELEC" ]]; then
  OUT+=$'\n'"Conseil    : R36S sous EmuELEC détectée → installer ArkOS K36."
fi
if [[ -n "$NOTE_EXTRA" ]]; then
  OUT+=$'\n'"Note       : $NOTE_EXTRA"
fi

echo "$OUT"

# Log
echo "$DATE  $TYPE  $DTB_NAME  $MD5  ${SIZE}B  $SCREEN_INFO" >> "$LOG" 2>/dev/null || true

#-----------------------------------
# Dialog + manette (A/Start OK, B Quitter)
#-----------------------------------
DLG_TEXT=$'DTB : '"$DTB_NAME"$'\n'"Type : $TYPE"$'\n'"Taille : ${SIZE} octets"$'\n'"MD5 : $MD5"
if [[ "$TYPE" == "ARKOS_AEUX" ]]; then
  DLG_TEXT+=$'\n'"Écran : $SCREEN_INFO"
elif [[ "$TYPE" == "EMUELEC" ]]; then
  DLG_TEXT+=$'\n'"Conseil : Installer ArkOS K36"
fi
if [[ -n "$NOTE_EXTRA" ]]; then
  DLG_TEXT+=$'\n\n'"$NOTE_EXTRA"
fi

# Démarrer la capture manette → clavier
start_gptokeyb

# Affichage + attente d'une touche (A/Start ou B/Échap)
dialog --backtitle "R36S DTB checker | Code by TyraNight" \
       --title "Rapport DTB (A=OK, B=Quitter)" \
       --ok-label "OK (A/Start)" \
       --msgbox "$DLG_TEXT" 14 78 > "$CURR_TTY"

# Nettoyage et sortie
ExitMenu
