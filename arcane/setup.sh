#!/usr/bin/env bash
# Arcane - étape interactive (titre ASCII au-dessus du cadre)
# - Clear écran
# - Titre ASCII
# - Cadre d'info
# - Saisie du hostname + validation + application
# - Message de confirmation

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# Couleurs (utilisées uniquement pour le message final)
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"; RED="$(tput setaf 1)"
else
    BOLD=$'\033[1m'; RESET=$'\033[0m'
    GREEN=$'\033[32m'; RED=$'\033[31m'
fi

log(){ printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }

clear || printf '\033c'

# ---- Titre ASCII (ne pas colorer pour garder l'alignement) ----
cat <<'ASCII'
█████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗
██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝
███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗  
██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝  
██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝
ASCII
echo

# ---- Cadre d'information ----
CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"
echo "┌────────────────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration : Nom de la machine${RESET}                      │"
echo "├────────────────────────────────────────────────────────┤"
echo "│  Caractères autorisés : a-z, 0-9, '-'                   │"
echo "│  Longueur max : 63                                      │"
echo "└────────────────────────────────────────────────────────┘"
echo

# ---- Saisie du hostname ----
printf "Nom de la machine [%s]: " "${CURRENT_HOST}"
IFS= read -r HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

# Validation simple
if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
    echo
    echo "${RED}Nom invalide.${RESET} Utilise lettres/chiffres/tirets, longueur ≤ 63."
    exit 2
fi

# Application (nécessite root si appelé via install.sh)
if ! hostnamectl set-hostname "$HOSTNAME_TARGET" 2>>"$LOG_FILE"; then
    echo "${RED}Échec : impossible de définir le hostname.${RESET}"
    exit 3
fi

# ---- Message final ----
echo
echo "╔════════════════════════════════════════════════════════╗"
printf "║  %sNom de machine défini%s : %s%s%s\n" "$BOLD" "$RESET" "$GREEN" "$HOSTNAME_TARGET" "$RESET"
echo "╚════════════════════════════════════════════════════════╝"
echo

log "INF" "Hostname défini : ${HOSTNAME_TARGET}"
exit 0
