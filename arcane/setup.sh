#!/usr/bin/env bash
# Arcane - Setup interactif (bannière + panneau + configuration hostname)
# - Bannière ASCII
# - Panneau (Développeur + Version du script depuis version.txt)
# - Saisie hostname + validation + application
# - Journalisation

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# ---------- Couleurs ----------
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"
    DIM="$(tput dim)"
    RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"
    RED="$(tput setaf 1)"
    COLORS="$(tput colors 2>/dev/null || echo 8)"
    if [ "${COLORS:-8}" -ge 16 ]; then
        DARKGREEN="$(tput setaf 22)"
        CYAN="$(tput setaf 6)"
    else
        DARKGREEN="$(tput setaf 2)"
        CYAN="$(tput setaf 6 2>/dev/null || echo)"
    fi
else
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    DARKGREEN=$'\033[32m'
    CYAN=$'\033[36m'
fi

log()
{
    printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"
}

clear || printf '\033c'
echo

# ---------- Lecture version ----------
# On suppose que setup.sh est dans <repo>/arcane/setup.sh et version.txt à <repo>/version.txt
ROOT_DIR="$(cd "${ARCANE_DIR:-$PWD}/.." >/dev/null 2>&1 && pwd)"
VERSION_FILE="${ROOT_DIR}/version.txt"

if [[ -f "$VERSION_FILE" ]]; then
    ARCANE_VERSION="$(head -n1 "$VERSION_FILE" | tr -d '\r\n')"
else
    ARCANE_VERSION="unknown"
fi

CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"

# ---------- Fonctions d'affichage ----------
W=60

repeat()
{
    # repeat <char> <count>
    local char="$1"
    local count="$2"
    printf "%0.s${char}" $(seq 1 "$count")
}

line_left()
{
    # line_left <text>
    local text="$1"
    local len=${#text}

    if (( len > W - 2 )); then
        text="${text:0:$((W-5))}..."
        len=${#text}
    fi

    local pad=$(( W - len - 1 ))
    (( pad < 0 )) && pad=0
    printf "║ %s%*s║\n" "$text" "$pad" ""
}

# ---------- Panneau stylisé ----------
printf "╔"; repeat "═" "$W"; printf "╗\n"

printf "║"; repeat " " "$W"; printf "║\n"

printf "║      █████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗     ║\n"
printf "║     ██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝     ║\n"
printf "║     ███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗       ║\n"
printf "║     ██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝       ║\n"
printf "║     ██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗     ║\n"
printf "║     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝     ║\n"

printf "║"; repeat " " "$W"; printf "║\n"

printf "╟"; repeat "─" "$W"; printf "╢\n"

printf "║"; repeat " " "$W"; printf "║\n"

line_left "${DIM}Développeur:${RESET} Lucas Developer"
line_left "${DIM}Version du script:${RESET} ${ARCANE_VERSION}"

printf "║"; repeat " " "$W"; printf "║\n"

printf "╚"; repeat "═" "$W"; printf "╝\n"
echo

# ---------- Cadre de configuration Hostname ----------
echo "┌────────────────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration: Hostname${RESET}                           │"
echo "├────────────────────────────────────────────────────────┤"
echo "│  Caractères autorisés : a-z, A-Z, 0-9, '-'             │"
echo "│  Doit commencer par une lettre ou un chiffre           │"
echo "│  Longueur max : 63 caractères                          │"
echo "└────────────────────────────────────────────────────────┘"
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
echo "╔════════════════════════════════════════════════════════╗"
printf "║  %s✓ Hostname défini :%s %-36s║\n" "$GREEN" "$RESET" "$HOSTNAME_TARGET"
echo "╚════════════════════════════════════════════════════════╝"
echo

log "INF" "Hostname changed from '${CURRENT_HOST}' to '${HOSTNAME_TARGET}'"
exit 0
