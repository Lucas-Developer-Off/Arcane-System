#!/usr/bin/env bash
# Arcane - Setup automatique optimisé
# Installation de WireGuard avec barre de progression

set -Eeuo pipefail

# ---------- Configuration ----------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="${SCRIPT_DIR%/*}"
readonly LOG_FILE="${ARCANE_DIR:-$ROOT_DIR}/setup.log"
readonly VERSION_FILE="${ROOT_DIR}/version.txt"
readonly WIREGUARD_SCRIPT="${SCRIPT_DIR}/wireguard.sh"

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

# ---------- Logging ----------
log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" >> "$LOG_FILE"; }
error_exit() { echo "${RED}✗ $1${RESET}" >&2; log "ERR" "$1"; exit "${2:-1}"; }

# ---------- Bannière ----------
show_banner() {
    local v="${1:-unknown}" pad=$((37 - ${#v}))
    printf '%s' "\
╔═════════════════════════════════════════════════════════════════════════════════════╗
║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     A R C A N E . S H     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║
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
╠═════════════════════════════════════════════════════════════════════════════════════╣
║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     I N F O R M A T I O N S     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║
╠═════════════════════════════════════════════════════════════════════════════════════╣
║ ┌─────────────────────────────────────────────────────────────────────────────────┐ ║
║ │                                                                                 │ ║
║ │                         • Developer : Lucas Developer •                         │ ║
"
    printf "║ │%*s• Version : %s •%*s│ ║\n" 30 "" "$v" "$pad" ""
    printf '%s' "\
║ │                                                                                 │ ║
║ └─────────────────────────────────────────────────────────────────────────────────┘ ║
╚═════════════════════════════════════════════════════════════════════════════════════╝

"
}

# ---------- Barre de progression ----------
show_progress() {
    local pct=$((${1} * 100 / ${2})) filled=$((${1} * 50 / ${2}))
    printf "\r${CYAN}[${RESET}%50s${CYAN}]${RESET} ${BOLD}%3d%%${RESET} %s" \
        "$(printf '%*s' "$filled" | tr ' ' '█')$(printf '%*s' $((50 - filled)) | tr ' ' '░')" \
        "$pct" "$3"
}

# ---------- Prérequis ----------
check_requirements() {
    [[ $EUID -ne 0 ]] && error_exit "Ce script doit être exécuté en tant que root" 1
    [[ ! -f "$WIREGUARD_SCRIPT" ]] && error_exit "Module wireguard.sh introuvable: $WIREGUARD_SCRIPT" 2
    chmod +x "$WIREGUARD_SCRIPT" 2>>"$LOG_FILE" || error_exit "Impossible de rendre wireguard.sh exécutable" 3
}

# ---------- Installation ----------
install_wireguard_with_progress() {
    local steps=("Vérification système" "Mise à jour" "Téléchargement WireGuard" 
                 "Installation" "Génération clés" "Configuration interface" 
                 "Activation IP forwarding" "Configuration firewall" "Démarrage service" "Finalisation")
    local total=${#steps[@]} current=0
    
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo "${BOLD}  Installation de WireGuard${RESET}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}\n"
    
    ARCANE_VERSION="$ARCANE_VERSION" ARCANE_LOG_FILE="$LOG_FILE" \
        bash "$WIREGUARD_SCRIPT" >>"${LOG_FILE}.verbose" 2>&1 &
    local pid=$!
    
    while kill -0 $pid 2>/dev/null; do
        ((current < total)) && show_progress $current $total "${steps[$current]}" && ((current++)) && sleep 0.8 ||
            show_progress $total $total "Finalisation..." && sleep 0.3
    done
    
    wait $pid
    local code=$?
    show_progress $total $total "Terminé !"
    echo -e "\n"
    return $code
}

# ---------- Écrans ----------
show_start_screen() {
    cat << EOF

┌────────────────────────────────────────────────────────┐
│                                                        │
│  ${BOLD}Installation automatique de WireGuard${RESET}              │
│                                                        │
│  Ce script va :                                        │
│    • Installer WireGuard                               │
│    • Générer les clés de chiffrement                   │
│    • Configurer le serveur VPN                         │
│                                                        │
└────────────────────────────────────────────────────────┘

${YELLOW}Appuyez sur une touche pour commencer l'installation...${RESET}
EOF
    read -n 1 -s -r
}

show_completion_screen() {
    cat << EOF

╔════════════════════════════════════════════════════════╗
║                                                        ║
║  ${BOLD}${GREEN}✓  Installation terminée avec succès !${RESET}              ║
║                                                        ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  Prochaines étapes :                                   ║
║    1. Configurez vos clients WireGuard                 ║
║    2. Vérifiez : systemctl status wg-quick@wg0         ║
║    3. Logs : $LOG_FILE
║                                                        ║
╚════════════════════════════════════════════════════════╝

EOF
}

# ---------- Main ----------
main() {
    clear 2>/dev/null || printf '\033c'
    
    export ARCANE_VERSION="unknown"
    [[ -f "$VERSION_FILE" ]] && ARCANE_VERSION=$(head -n1 "$VERSION_FILE" | tr -d '\r\n')
    
    show_banner "$ARCANE_VERSION"
    check_requirements
    log "INF" "Démarrage setup Arcane v${ARCANE_VERSION}"
    
    show_start_screen
    
    if install_wireguard_with_progress; then
        show_completion_screen
        log "INF" "Installation terminée avec succès"
        exit 0
    else
        echo -e "\n${RED}✗ L'installation a échoué${RESET}"
        echo "  Consultez les logs : $LOG_FILE"
        log "ERR" "Installation échouée"
        exit 1
    fi
}

main "$@"
