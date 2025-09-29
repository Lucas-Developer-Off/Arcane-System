#!/usr/bin/env bash
# Arcane - Setup interactif (bannière adaptative, panneau, config hostname)

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# ---------- Couleurs ----------
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"; RED="$(tput setaf 1)"
    COLORS="$(tput colors 2>/dev/null || echo 8)"
    if [ "${COLORS:-8}" -ge 16 ]; then DARKGREEN="$(tput setaf 22)"; else DARKGREEN="$(tput setaf 2)"; fi
    CYAN="$(tput setaf 6)"
else
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
    GREEN=$'\033[32m'; RED=$'\033[31m'; DARKGREEN=$'\033[32m'; CYAN=$'\033[36m'
fi

log() { printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }

# ---------- Largeur dynamique ----------
term_cols() {
    local c
    c="${COLUMNS:-}"
    if [[ -z "$c" ]] && command -v tput >/dev/null 2>&1; then c="$(tput cols 2>/dev/null || echo)"; fi
    [[ -z "$c" ]] && c=80
    printf '%s' "$c"
}

# Visible length (sans séquences ANSI)
vlen() {
    # shellcheck disable=SC2001
    local s="${1//$'\r'/}"
    s="$(printf %s "$s" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')"
    printf '%s' "${#s}"
}

repeat() { # repeat <char> <count>
    local ch="$1" n="$2"
    [ "$n" -le 0 ] && return 0
    if command -v seq >/dev/null 2>&1; then printf "%0.s%s" $(seq 1 "$n") "$ch"; else
        local i; for (( i=0; i<n; i++ )); do printf "%s" "$ch"; done
    fi
}

center() { # center <text> <width>
    local text="$1" width="$2" len padL padR
    len="$(vlen "$text")"
    if (( len > width )); then
        printf "%s" "$text" | sed -E "s/^(.{0,$width}).*$/\1/"
        return
    fi
    padL=$(( (width - len) / 2 ))
    padR=$(( width - len - padL ))
    repeat " " "$padL"; printf "%s" "$text"; repeat " " "$padR"
}

# ---------- Dimensions ----------
TERM_W="$(term_cols)"
# marge latérale 2 colonnes (║ … ║)
W=$(( TERM_W - 2 ))
# garde-fous
(( W < 40 )) && W=40
IW=$(( W - 6 ))   # sous-cadre: "║  │" + "│  ║" → 6 colonnes d'enveloppe

# ---------- Affichage lignes ----------
outer_blank() { printf "║"; repeat " " "$W"; printf "║\n"; }
outer_text_center() { printf "║"; center "$1" "$W"; printf "║\n"; }
outer_text_left() {
    local text="$1" len; len="$(vlen "$text")"
    (( len > W )) && text="$(printf %s "$text" | sed -E "s/^(.{0,$W}).*$/\1/")"
    printf "║%s" "$text"; repeat " " $(( W - $(vlen "$text") )); printf "║\n"
}
inner_sep_top()   { printf "║  ┌"; repeat "─" "$IW"; printf "┐  ║\n"; }
inner_sep_bottom(){ printf "║  └"; repeat "─" "$IW"; printf "┘  ║\n"; }
inner_blank()     { printf "║  │"; repeat " " "$IW"; printf "│  ║\n"; }
inner_center()    { printf "║  │"; center "$1" "$IW"; printf "│  ║\n"; }
section_header() {
    local label=" $1 " left right
    left=$(( (W - $(vlen "$label")) / 2 ))
    right=$(( W - $(vlen "$label") - left ))
    printf "╠"; repeat "═" "$left"; printf "%s" "$label"; repeat "═" "$right"; printf "╣\n"
}

# ---------- Lecture version ----------
ROOT_DIR="$(cd "${ARCANE_DIR:-$PWD}/.." >/dev/null 2>&1 && pwd)"
VERSION_FILE="${ROOT_DIR}/version.txt"
if [[ -f "$VERSION_FILE" ]]; then ARCANE_VERSION="$(head -n1 "$VERSION_FILE" | tr -d '\r\n')"; else ARCANE_VERSION="unknown"; fi
CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"

clear || printf '\033c'
echo

# ---------- Bandeau ----------
printf "╔"; repeat "═" "$W"; printf "╗\n"

TITLE=" ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ${BOLD}${CYAN}A R C A N E${RESET}   ${DIM}P R O J E C T${RESET}  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ "
if (( $(vlen "$TITLE") > W )); then
    TITLE="${BOLD}${CYAN}A R C A N E${RESET} ${DIM}PROJECT${RESET}"
fi
outer_text_center "$TITLE"

printf "╠"; repeat "═" "$W"; printf "╣\n"

# ---------- Bloc ASCII (full -> compact selon largeur) ----------
ASCII_FULL=1
# Besoin minimum pour l'ASCII propre: ~72 colonnes de IW
(( IW < 72 )) && ASCII_FULL=0

inner_sep_top
if (( ASCII_FULL == 1 )); then
    inner_blank
    inner_center "${BOLD}${DARKGREEN} █████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗  ██████╗ ${RESET}"
    inner_center "${BOLD}${DARKGREEN}██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝ ██╔═══██╗${RESET}"
    inner_center "${BOLD}${DARKGREEN}███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗   ██║   ██║${RESET}"
    inner_center "${BOLD}${DARKGREEN}██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝   ██║   ██║${RESET}"
    inner_center "${BOLD}${DARKGREEN}██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗ ╚██████╔╝${RESET}"
    inner_center "${BOLD}${DARKGREEN}╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝  ╚═════╝ ${RESET}"
    inner_blank
else
    # Mode compact
    inner_blank
    inner_center "${BOLD}${DARKGREEN}ARCANE${RESET} ${DIM}SETUP${RESET}"
    inner_center "${DIM}Interactive installer${RESET}"
    inner_blank
fi
inner_sep_bottom

section_header "INFO"
outer_blank
outer_text_left " • ${DIM}Developer${RESET}   : Lucas Developer"
outer_text_left " • ${DIM}Version${RESET}     : ${ARCANE_VERSION}"
outer_blank
printf "╚"; repeat "═" "$W"; printf "╝\n"
echo

# ---------- Cadre de configuration Hostname ----------
echo "┌────────────────────────────────────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration: Hostname${RESET}                                                     │"
echo "├────────────────────────────────────────────────────────────────────────────┤"
echo "│  Caractères autorisés : a-z, A-Z, 0-9, '-'                                 │"
echo "│  Doit commencer par une lettre ou un chiffre                               │"
echo "│  Longueur max : 63 caractères                                              │"
echo "└────────────────────────────────────────────────────────────────────────────┘"
echo

# ---------- Saisie ----------
printf "Hostname [%s]: " "${CURRENT_HOST}"
IFS= read -r HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

# ---------- Validation ----------
if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]] || [[ "$HOSTNAME_TARGET" =~ -$ ]]; then
    echo
    echo "${RED}✗ Hostname invalide.${RESET}"
    echo "  Règles :"
    echo "  - Commencer par lettre ou chiffre"
    echo "  - Uniquement lettres, chiffres et tirets"
    echo "  - Ne pas finir par un tiret"
    echo "  - 63 caractères maximum"
    exit 2
fi

# ---------- Application ----------
echo
echo "Application du nouveau hostname…"
if ! hostnamectl set-hostname "$HOSTNAME_TARGET" 2>>"$LOG_FILE"; then
    echo "${RED}✗ Échec du changement de hostname.${RESET}"
    echo "  Voir le log : $LOG_FILE"
    exit 3
fi

# /etc/hosts (si présent)
if grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
    sed -i.bak "s/127.0.1.1.*/127.0.1.1\t${HOSTNAME_TARGET}/" /etc/hosts 2>>"$LOG_FILE" || true
fi

# ---------- Confirmation ----------
echo
printf "╔"; repeat "═" "$W"; printf "╗\n"
printf "║  %s✓ Hostname défini :%s " "$GREEN" "$RESET"
center "$HOSTNAME_TARGET" $(( W - 6 ))
printf "  ║\n"
printf "╚"; repeat "═" "$W"; printf "╝\n"
echo

log "INF" "Hostname changed from '${CURRENT_HOST}' to '${HOSTNAME_TARGET}'"
exit 0
