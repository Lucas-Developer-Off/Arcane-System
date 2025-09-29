#!/usr/bin/env bash
# Arcane - Setup automatique
# Installation de WireGuard avec barre de progression

set -Eeuo pipefail

# ---------- Configuration ----------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="${SCRIPT_DIR%/*}"
readonly LOG_FILE="${ARCANE_DIR:-$ROOT_DIR}/setup.log"
readonly VERSION_FILE="${ROOT_DIR}/version.txt"
readonly WIREGUARD_SCRIPT="${SCRIPT_DIR}/wireguard.sh"

# ---------- Couleurs ----------
init_colors() {
    if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
        readonly BOLD="$(tput bold)"
        readonly RESET="$(tput sgr0)"
        readonly GREEN="$(tput setaf 2)"
        readonly RED="$(tput setaf 1)"
        readonly CYAN="$(tput setaf 6)"
        readonly YELLOW="$(tput setaf 3)"
    else
        readonly BOLD=$'\033[1m' RESET=$'\033[0m'
        readonly GREEN=$'\033[32m' RED=$'\033[31m'
        readonly CYAN=$'\033[36m' YELLOW=$'\033[33m'
    fi
}

# ---------- Logging ----------
log() {
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" >> "$LOG_FILE"
}

error_exit() {
    echo "${RED}✗ $1${RESET}" >&2
    log "ERR" "$1"
    exit "${2:-1}"
}

# ---------- Affichage de la bannière ----------
show_banner() {
    local v="${1:-unknown}"
    local vlen=${#v}
    local pad=$((37 - vlen))
    
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
    local current=$1
    local total=$2
    local message="$3"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}[${RESET}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${CYAN}]${RESET} ${BOLD}%3d%%${RESET} ${message}" "$percentage"
}

# ---------- Vérification des prérequis ----------
check_requirements() {
    # Vérifier les droits root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Ce script doit être exécuté en tant que root" 1
    fi
    
    # Vérifier que le module wireguard existe
    if [[ ! -f "$WIREGUARD_SCRIPT" ]]; then
        error_exit "Module wireguard.sh introuvable: $WIREGUARD_SCRIPT" 2
    fi
    
    # Rendre le module exécutable
    chmod +x "$WIREGUARD_SCRIPT" 2>>"$LOG_FILE" || \
        error_exit "Impossible de rendre wireguard.sh exécutable" 3
}

# ---------- Installation avec progression ----------
install_wireguard_with_progress() {
    local steps=(
        "Vérification du système"
        "Mise à jour des paquets"
        "Téléchargement de WireGuard"
        "Installation de WireGuard"
        "Génération des clés"
        "Configuration de l'interface"
        "Activation de l'IP forwarding"
        "Configuration du firewall"
        "Démarrage du service"
        "Finalisation"
    )
    
    local total=${#steps[@]}
    
    echo
    echo "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo "${BOLD}  Installation de WireGuard${RESET}"
    echo "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo
    
    # Exécuter l'installation en arrière-plan et capturer la sortie
    (
        export ARCANE_VERSION="$ARCANE_VERSION"
        export ARCANE_LOG_FILE="$LOG_FILE"
        bash "$WIREGUARD_SCRIPT" 2>&1 | while IFS= read -r line; do
            echo "$line" >> "${LOG_FILE}.verbose"
        done
    ) &
    
    local pid=$!
    local current=0
    
    # Simuler la progression pendant l'installation
    while kill -0 $pid 2>/dev/null; do
        if [[ $current -lt $total ]]; then
            show_progress $current $total "${steps[$current]}"
            sleep 0.8
            ((current++))
        else
            show_progress $total $total "Finalisation..."
            sleep 0.3
        fi
    done
    
    # Attendre la fin du processus et récupérer le code de sortie
    wait $pid
    local exit_code=$?
    
    # Afficher la barre complète
    show_progress $total $total "Terminé !"
    echo
    echo
    
    return $exit_code
}

# ---------- Écran de démarrage ----------
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

EOF
    printf "${YELLOW}Appuyez sur une touche pour commencer l'installation...${RESET}"
    read -n 1 -s -r
    echo
}

# ---------- Écran de fin ----------
show_completion_screen() {
    echo
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║  ${BOLD}${GREEN}✓  Installation terminée avec succès !${RESET}              ║"
    echo "║                                                        ║"
    echo "╠════════════════════════════════════════════════════════╣"
    echo "║                                                        ║"
    echo "║  Prochaines étapes :                                   ║"
    echo "║    1. Configurez vos clients WireGuard                 ║"
    echo "║    2. Vérifiez le statut : systemctl status wg-quick@wg0 ║"
    echo "║    3. Consultez les logs : $LOG_FILE"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo
}

# ---------- Programme principal ----------
main() {
    # Initialisation
    init_colors
    clear 2>/dev/null || printf '\033c'
    
    # Lecture de la version
    export ARCANE_VERSION="unknown"
    if [[ -f "$VERSION_FILE" ]]; then
        ARCANE_VERSION="$(head -n1 "$VERSION_FILE" | tr -d '\r\n')"
    fi
    
    # Affichage de la bannière
    show_banner "$ARCANE_VERSION"
    
    # Vérification des prérequis
    check_requirements
    
    log "INF" "Démarrage du setup Arcane v${ARCANE_VERSION}"
    
    # Écran de démarrage
    show_start_screen
    
    # Installation avec barre de progression
    if install_wireguard_with_progress; then
        show_completion_screen
        log "INF" "Installation terminée avec succès"
        exit 0
    else
        echo
        echo "${RED}✗ L'installation a échoué${RESET}"
        echo "  Consultez les logs : $LOG_FILE"
        log "ERR" "Installation échouée"
        exit 1
    fi
}

# ---------- Exécution ----------
main "$@"
