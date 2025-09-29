#!/usr/bin/env bash
# Arcane - Setup interactif optimisé
# Configuration hostname avec validation et journalisation

set -Eeuo pipefail

# ---------- Configuration ----------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="${SCRIPT_DIR%/*}"
readonly LOG_FILE="${ARCANE_DIR:-$ROOT_DIR}/setup.log"
readonly VERSION_FILE="${ROOT_DIR}/version.txt"
readonly HOSTNAME_MAX_LEN=63
readonly HOSTNAME_REGEX='^[A-Za-z0-9][A-Za-z0-9-]{0,62}$'

# ---------- Couleurs (optimisé) ----------
init_colors() {
    if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
        readonly BOLD="$(tput bold)"
        readonly RESET="$(tput sgr0)"
        readonly GREEN="$(tput setaf 2)"
        readonly RED="$(tput setaf 1)"
        
        local colors="$(tput colors 2>/dev/null || echo 8)"
        if [[ $colors -ge 16 ]]; then
            readonly CYAN="$(tput setaf 6)"
        else
            readonly CYAN="${GREEN}"
        fi
    else
        readonly BOLD=$'\033[1m' RESET=$'\033[0m'
        readonly GREEN=$'\033[32m' RED=$'\033[31m' CYAN=$'\033[36m'
    fi
}

# ---------- Logging ----------
log() {
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$LOG_FILE"
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

# ---------- Validation hostname ----------
validate_hostname() {
    local hostname="$1"
    
    # Vérification longueur
    if [[ ${#hostname} -gt $HOSTNAME_MAX_LEN ]]; then
        return 1
    fi
    
    # Vérification format
    if [[ ! $hostname =~ $HOSTNAME_REGEX ]]; then
        return 1
    fi
    
    # Ne doit pas finir par un tiret
    if [[ $hostname =~ -$ ]]; then
        return 1
    fi
    
    return 0
}

# ---------- Affichage des règles ----------
show_hostname_rules() {
    cat << EOF
┌────────────────────────────────────────────────────────┐
│  ${BOLD}Configuration: Hostname${RESET}                           │
├────────────────────────────────────────────────────────┤
│  Caractères autorisés : a-z, A-Z, 0-9, '-'             │
│  Doit commencer par une lettre ou un chiffre           │
│  Longueur max : ${HOSTNAME_MAX_LEN} caractères                          │
└────────────────────────────────────────────────────────┘

EOF
}

# ---------- Application du hostname ----------
apply_hostname() {
    local new_hostname="$1"
    
    echo "Application du nouveau hostname…"
    
    # Changement via hostnamectl
    if ! hostnamectl set-hostname "$new_hostname" 2>>"$LOG_FILE"; then
        error_exit "Échec du changement de hostname. Voir: $LOG_FILE" 3
    fi
    
    # Mise à jour de /etc/hosts si nécessaire
    if [[ -f /etc/hosts ]] && grep -q "^127.0.1.1" /etc/hosts 2>/dev/null; then
        sed -i.bak "s/^127\.0\.1\.1.*/127.0.1.1\t${new_hostname}/" /etc/hosts 2>>"$LOG_FILE" || true
    fi
}

# ---------- Programme principal ----------
main() {
    # Initialisation
    init_colors
    clear 2>/dev/null || printf '\033c'
    
    # Lecture de la version
    local version="unknown"
    if [[ -f $VERSION_FILE ]]; then
        version="$(head -n1 "$VERSION_FILE" | tr -d '\r\n')"
    fi
    
    # Affichage de la bannière
    show_banner "$version"
    
    # Récupération du hostname actuel
    local current_hostname
    current_hostname="$(hostnamectl --static 2>/dev/null || hostname)"
    
    # Affichage des règles
    show_hostname_rules
    
    # Saisie du nouveau hostname
    printf "Hostname [%s]: " "$current_hostname"
    local new_hostname
    IFS= read -r new_hostname
    new_hostname="${new_hostname:-$current_hostname}"
    
    # Validation
    if ! validate_hostname "$new_hostname"; then
        echo
        echo "${RED}✗ Hostname invalide.${RESET}"
        echo "  Règles :"
        echo "  - Commencer par lettre ou chiffre"
        echo "  - Uniquement lettres, chiffres et tirets"
        echo "  - Ne pas finir par un tiret"
        echo "  - ${HOSTNAME_MAX_LEN} caractères maximum"
        exit 2
    fi
    
    # Application
    echo
    apply_hostname "$new_hostname"
    
    # Confirmation
    echo
    cat << EOF
╔════════════════════════════════════════════════════════╗
║  ${GREEN}✓ Hostname défini :${RESET} $(printf '%-36s' "$new_hostname")║
╚════════════════════════════════════════════════════════╝

EOF
    
    log "INF" "Hostname changed from '${current_hostname}' to '${new_hostname}'"
}

# ---------- Exécution ----------
main "$@"
