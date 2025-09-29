#!/usr/bin/env bash
# Arcane - étape interactive minimale
# - Clear l'écran
# - Cadre d'info
# - Titre (2 lignes) CENTRÉ sous le cadre
# - Saisie du hostname + confirmation

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# Couleurs (fallback si tput indisponible)
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"; RED="$(tput setaf 1)"
else
    BOLD=$'\033[1m'; RESET=$'\033[0m'
    GREEN=$'\033[32m'; RED=$'\033[31m'
fi

log(){ printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }

# Centrage horizontal sans codes couleur
center()
{
    local s="$1"
    local cols
    cols="$(tput cols 2>/dev/null || echo 80)"
    # Longueur visible (pas de couleurs ici -> exact)
    local len=${#s}
    local pad=$(( (cols - len) / 2 ))
    (( pad < 0 )) && pad=0
    printf "%*s%s\n" "$pad" "" "$s"
}

clear || printf '\033c'

CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"
echo
echo "┌────────────────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration : Nom de la machine${RESET}                      │"
echo "├────────────────────────────────────────────────────────┤"
echo "│  Caractères autorisés : a-z, 0-9, '-'                   │"
echo "│  Longueur max : 63                                      │"
echo "└────────────────────────────────────────────────────────┘"
echo

# ---- Titre 2 lignes centré sous le cadre ----
center "ARCANE SYSTEM — INITIALISATION"
center "Étape 1 : définir l'identité de la machine"
echo

# ---- Saisie du hostname ----
read -rp "Nom de la machine [${CURRENT_HOST}]: " HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

# Validation simple
if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
    echo
    echo "${RED}Nom invalide.${RESET} Utilise lettres/chiffres/tirets, longueur ≤ 63."
    exit 2
fi

# Application
if ! hostnamectl set-hostname "$HOSTNAME_TARGET" 2>>"$LOG_FILE"; then
    echo "${RED}Échec : impossible de définir le hostname.${RESET}"
    exit 3
fi

# Message final stylé
echo
echo "╔════════════════════════════════════════════════════════╗"
printf "║  %sNom de machine défini%s : %s%s%s\n" "$BOLD" "$RESET" "$GREEN" "$HOSTNAME_TARGET" "$RESET"
echo "╚════════════════════════════════════════════════════════╝"
echo

log "INF" "Hostname défini : ${HOSTNAME_TARGET}"
exit 0
