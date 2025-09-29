#!/usr/bin/env bash
# Arcane - étape interactive minimale :
# - Nettoie l'écran
# - Demande le nom de la machine (hostname)
# - Applique le hostname
# - Affiche un message stylé avec la valeur

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# --- Couleurs (fallback si tput indisponible) ---
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"; CYAN="$(tput setaf 6)"; YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"
else
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
    GREEN=$'\033[32m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
fi

log(){ printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }
require_root(){ if [[ $EUID -ne 0 ]]; then log "ERR" "setup.sh doit être exécuté en root (sudo)."; exit 1; fi; }

require_root

# --- Nettoie l'écran SSH ---
clear || printf '\033c'

# --- Demande du hostname ---
CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"
echo
echo "┌──────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration rapide : Nom de la machine${RESET}      │"
echo "├──────────────────────────────────────────────┤"
echo "│  ${DIM}Caractères autorisés : a-z, 0-9, '-'${RESET}                │"
echo "│  ${DIM}Longueur max : 63 caractères${RESET}                       │"
echo "└──────────────────────────────────────────────┘"
echo

read -rp "Nom de la machine [${CURRENT_HOST}]: " HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

# --- Validation simple ---
if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
    echo
    echo "${RED}Nom invalide.${RESET} Utilise : lettres, chiffres, tirets. Longueur ≤ 63. "
    echo "Abandon."
    exit 2
fi

# --- Application du hostname ---
hostnamectl set-hostname "$HOSTNAME_TARGET" || {
    echo "${RED}Échec lors de la définition du hostname.${RESET}"
    exit 3
}

# --- Message stylé ---
echo
echo "╔══════════════════════════════════════════════╗"
printf "║  %sNom de machine défini%s : %s%s%s\n" "$BOLD" "$RESET" "$GREEN" "$HOSTNAME_TARGET" "$RESET"
echo "╚══════════════════════════════════════════════╝"
echo

log "INF" "Hostname défini : ${HOSTNAME_TARGET}"

exit 0
