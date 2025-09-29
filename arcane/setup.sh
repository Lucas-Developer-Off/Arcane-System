#!/usr/bin/env bash
# Arcane - étape interactive minimale :
# - Clear l'écran
# - Demande le nom de la machine (hostname)
# - Applique le hostname
# - Affiche un message stylé

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# Couleurs
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"; CYAN="$(tput setaf 6)"; YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"
else
    BOLD=$'\033[1m'; RESET=$'\033[0m'
    GREEN=$'\033[32m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
fi

log(){ printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }

# Root pas indispensable ici (on ne touche qu'au hostname), mais recommandé
if [[ $EUID -ne 0 ]]; then
    echo "Astuce: exécuter en root évite certains échecs (sudo ./setup.sh)."
fi

clear || printf '\033c'

CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"
echo
echo "┌──────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration : Nom de la machine${RESET}              │"
echo "├──────────────────────────────────────────────┤"
echo "│  Caractères autorisés : a-z, 0-9, '-'        │"
echo "│  Longueur max : 63                           │"
echo "└──────────────────────────────────────────────┘"
echo

read -rp "Nom de la machine [${CURRENT_HOST}]: " HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
    echo
    echo "${RED}Nom invalide.${RESET} Utilise lettres/chiffres/tirets, ≤ 63 car."
    exit 2
fi

if ! hostnamectl set-hostname "$HOSTNAME_TARGET" 2>>"$LOG_FILE"; then
    echo "${RED}Échec : impossible de définir le hostname.${RESET}"
    exit 3
fi

echo
echo "╔══════════════════════════════════════════════╗"
printf "║  %sNom défini%s : %s%s%s\n" "$BOLD" "$RESET" "$GREEN" "$HOSTNAME_TARGET" "$RESET"
echo "╚══════════════════════════════════════════════╝"
echo

log "INF" "Hostname défini : ${HOSTNAME_TARGET}"
