#!/usr/bin/env bash
# Arcane-System : Installateur simplifié
# Met à jour le système avec une barre de progression

set -Eeo pipefail

# ---------- Configuration (minimale) ----------
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

set -u

# ---------- Couleurs ----------
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    readonly BOLD=$(tput bold) RESET=$(tput sgr0)
    readonly GREEN=$(tput setaf 2) RED=$(tput setaf 1)
    readonly CYAN=$(tput setaf 6) YELLOW=$(tput setaf 3)
else
    readonly BOLD=$'\033[1m' RESET=$'\033[0m'
    readonly GREEN=$'\033[32m' RED=$'\033[31m'
    readonly CYAN=$'\033[36m' YELLOW=$'\033[33m'
fi

# ---------- Fonctions ----------
log() { printf "${CYAN}[%s]${RESET} %s\n" "$(date '+%T')" "$*"; }
error_exit() { echo "${RED}✗ $1${RESET}" >&2; exit "${2:-1}"; }

usage() {
    cat <<EOF
${BOLD}Installateur Arcane-System (simplifié)${RESET}

${BOLD}Usage:${RESET}
  sudo $(basename "$0")
EOF
}

require_root() {
    [[ $EUID -ne 0 ]] && error_exit "Ce script nécessite les droits root (sudo)" 1
}

require_cmd() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    [[ ${#missing[@]} -gt 0 ]] && error_exit "Commandes manquantes: ${missing[*]}" 2
}

# Affiche une barre de progression animée pendant l'exécution d'une commande
run_with_progress() {
    # Exige au moins 2 arguments: message + commande
    if [[ $# -lt 2 ]]; then
        error_exit "run_with_progress: arguments insuffisants" 9
    fi

    local message="$1"; shift
    local cmd="$*"

    echo "${BOLD}${message}${RESET}"

    # Lance la commande en arrière-plan avec redirection complète
    bash -c "$cmd" >/dev/null 2>&1 &
    local cmd_pid=$!

    # Prépare l'affichage
    local width=40
    local i=0
    tput civis 2>/dev/null || true
    printf "\n"  # ligne dédiée à la barre

    # Animation tant que la commande tourne
    while kill -0 "$cmd_pid" 2>/dev/null; do
        i=$(( (i + 1) % (width * 2) ))
        local filled=$(( i <= width ? i : (2*width - i) ))
        local bar
        bar=$(printf "%${filled}s" | tr ' ' '#')
        local spaces
        spaces=$(printf "%$((width - filled))s")
        printf "\r[%s%s]" "$bar" "$spaces"
        sleep 0.08
    done

    # Attend la fin et fixe l'état
    wait "$cmd_pid"
    local status=$?
    printf "\r[%s]\n" "$(printf "%${width}s" | tr ' ' '#')"
    tput cnorm 2>/dev/null || true
    return "$status"
}

# (Téléchargement et verrou supprimés dans la version simplifiée)

# ---------- Bannière ----------
show_banner() {
    cat << 'EOF'

╔═════════════════════════════════════════════════════════════════════════════════════╗
║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     I N S T A L L E R     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║
╠═════════════════════════════════════════════════════════════════════════════════════╣
║ ┌─────────────────────────────────────────────────────────────────────────────────┐ ║
║ │                                                                                 │ ║
║ │      █████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗     ███████╗██╗  ██╗     │ ║
║ │     ██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝     ██╔════╝██║  ██║     │ ║
║ │     ███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗       ███████╗███████║     │ ║
║ │     ██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝       ╚════██║██╔══██║     │ ║
║ │     ██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗ ██╗ ███████║██║  ██║     │ ║
║ │     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚═╝ ╚══════╝╚═╝  ╚═╝     │ ║
║ │                                                                                 │ ║
║ └─────────────────────────────────────────────────────────────────────────────────┘ ║
╚═════════════════════════════════════════════════════════════════════════════════════╝

EOF
}

# (Parsing d'arguments supprimé)

# ---------- Main ----------
main() {
    show_banner
    
    require_root
    require_cmd apt-get

    # Mise à jour du système avec barre de progression
    log "Préparation de la mise à jour du système"
    local apt_log="/tmp/arcane_apt_update.log"
    if run_with_progress "Exécution: apt-get update && apt-get upgrade -y" "apt-get update -y >$apt_log 2>&1 && apt-get upgrade -y >>$apt_log 2>&1"; then
        log "${GREEN}✓ Système à jour${RESET}"
    else
        log "${YELLOW}⚠ La mise à jour du système a rencontré des erreurs${RESET}"
        log "Consulte le journal: ${apt_log}"
    fi

    echo
    cat << EOF
${BOLD}${GREEN}✓ Fin de l'installation simplifiée${RESET}
EOF
}

main "$@"