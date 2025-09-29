#!/usr/bin/env bash
# Arcane - étape interactive minimale
# - Clear l'écran
# - Affiche un cadre
# - Affiche un "titre" sur 2 lignes sous le cadre
# - Demande le nom de la machine (hostname), le valide et l'applique
# - Affiche un message stylé de confirmation

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# Couleurs (fallback si tput indisponible)
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"; CYAN="$(tput setaf 6)"; YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"
else
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
    GREEN=$'\033[32m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
fi

log(){ printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }

# Root recommandé pour hostnamectl
if [[ $EUID -ne 0 ]]; then
    echo "Astuce: exécuter en root évite certains échecs (sudo ./setup.sh)."
fi

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

# --- Titre 2 lignes (sous le cadre) ---
echo " ${BOLD}${CYAN}ARCANE SYSTEM — INITIALISATION${RESET}"
echo " ${DIM}Étape 1 : définir l'identité de la machine avant la suite.${RESET}"
echo

# --- Saisie du hostname ---
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
