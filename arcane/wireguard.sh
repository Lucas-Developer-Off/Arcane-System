#!/usr/bin/env bash
# Arcane - Module WireGuard
# Installation et configuration de WireGuard

set -Eeuo pipefail

# ---------- Configuration ----------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="${SCRIPT_DIR%/*}"
readonly LOG_FILE="${ARCANE_LOG_FILE:-${ARCANE_DIR:-$ROOT_DIR}/setup.log}"
readonly WG_CONFIG_DIR="/etc/wireguard"
readonly WG_INTERFACE="wg0"

# ---------- Couleurs ----------
init_colors() {
    if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
        readonly BOLD="$(tput bold)"
        readonly RESET="$(tput sgr0)"
        readonly GREEN="$(tput setaf 2)"
        readonly RED="$(tput setaf 1)"
        readonly YELLOW="$(tput setaf 3)"
        readonly CYAN="$(tput setaf 6)"
    else
        readonly BOLD=$'\033[1m' RESET=$'\033[0m'
        readonly GREEN=$'\033[32m' RED=$'\033[31m'
        readonly YELLOW=$'\033[33m' CYAN=$'\033[36m'
    fi
}

# ---------- Logging ----------
log() {
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$LOG_FILE"
}

error_exit() {
    echo "${RED}✗ $1${RESET}" >&2
    log "ERR" "[wireguard] $1"
    exit "${2:-1}"
}

# ---------- Vérification de l'installation ----------
check_wireguard_installed() {
    if command -v wg >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# ---------- Installation de WireGuard ----------
install_wireguard() {
    echo "${CYAN}Installation de WireGuard...${RESET}"
    log "INF" "[wireguard] Début de l'installation"
    
    # Détection de la distribution
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        apt-get update 2>>"$LOG_FILE" || error_exit "Échec de la mise à jour des paquets"
        apt-get install -y wireguard wireguard-tools 2>>"$LOG_FILE" || \
            error_exit "Échec de l'installation de WireGuard"
    elif [[ -f /etc/redhat-release ]]; then
        # RedHat/CentOS/Rocky
        yum install -y epel-release 2>>"$LOG_FILE" || \
            error_exit "Échec de l'installation de epel-release"
        yum install -y wireguard-tools 2>>"$LOG_FILE" || \
            error_exit "Échec de l'installation de WireGuard"
    else
        error_exit "Distribution non supportée"
    fi
    
    echo "${GREEN}✓ WireGuard installé${RESET}"
    log "INF" "[wireguard] Installation terminée avec succès"
}

# ---------- Génération des clés ----------
generate_keys() {
    echo "${CYAN}Génération des clés...${RESET}"
    log "INF" "[wireguard] Génération des clés"
    
    # Créer le répertoire de configuration
    mkdir -p "$WG_CONFIG_DIR"
    chmod 700 "$WG_CONFIG_DIR"
    
    # Générer la clé privée
    wg genkey | tee "${WG_CONFIG_DIR}/server_private.key" | \
        wg pubkey > "${WG_CONFIG_DIR}/server_public.key"
    
    chmod 600 "${WG_CONFIG_DIR}/server_private.key"
    chmod 644 "${WG_CONFIG_DIR}/server_public.key"
    
    echo "${GREEN}✓ Clés générées${RESET}"
    log "INF" "[wireguard] Clés générées avec succès"
}

# ---------- Configuration de l'interface ----------
configure_interface() {
    local server_ip="$1"
    local server_port="${2:-51820}"
    local private_key
    
    echo "${CYAN}Configuration de l'interface ${WG_INTERFACE}...${RESET}"
    log "INF" "[wireguard] Configuration de l'interface ${WG_INTERFACE}"
    
    private_key="$(cat "${WG_CONFIG_DIR}/server_private.key")"
    
    # Créer la configuration
    cat > "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf" << EOF
[Interface]
Address = ${server_ip}
ListenPort = ${server_port}
PrivateKey = ${private_key}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Peers will be added below
EOF
    
    chmod 600 "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"
    
    echo "${GREEN}✓ Interface configurée${RESET}"
    log "INF" "[wireguard] Configuration de l'interface terminée"
}

# ---------- Activation de l'IP forwarding ----------
enable_ip_forwarding() {
    echo "${CYAN}Activation de l'IP forwarding...${RESET}"
    log "INF" "[wireguard] Activation de l'IP forwarding"
    
    # Activer temporairement
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    
    # Rendre permanent
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    
    echo "${GREEN}✓ IP forwarding activé${RESET}"
    log "INF" "[wireguard] IP forwarding activé"
}

# ---------- Démarrage du service ----------
start_wireguard() {
    echo "${CYAN}Démarrage de WireGuard...${RESET}"
    log "INF" "[wireguard] Démarrage du service"
    
    # Activer et démarrer le service
    systemctl enable wg-quick@${WG_INTERFACE} 2>>"$LOG_FILE" || \
        error_exit "Échec de l'activation du service"
    
    systemctl start wg-quick@${WG_INTERFACE} 2>>"$LOG_FILE" || \
        error_exit "Échec du démarrage du service"
    
    echo "${GREEN}✓ WireGuard démarré${RESET}"
    log "INF" "[wireguard] Service démarré avec succès"
}

# ---------- Affichage du résumé ----------
show_summary() {
    local public_key
    public_key="$(cat "${WG_CONFIG_DIR}/server_public.key")"
    
    echo
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  ${BOLD}${GREEN}Installation WireGuard terminée${RESET}                      ║"
    echo "╠════════════════════════════════════════════════════════╣"
    echo "║  Interface  : ${WG_INTERFACE}                                      ║"
    echo "║  Clé publique serveur :                                ║"
    echo "║  ${public_key:0:50}... ║"
    echo "╠════════════════════════════════════════════════════════╣"
    echo "║  ${YELLOW}Configuration${RESET} : ${WG_CONFIG_DIR}/${WG_INTERFACE}.conf          ║"
    echo "║  ${YELLOW}Clés${RESET}          : ${WG_CONFIG_DIR}/server_*.key           ║"
    echo "╚════════════════════════════════════════════════════════╝"
}

# ---------- Programme principal ----------
main() {
    # Initialisation
    init_colors
    
    log "INF" "[wireguard] Démarrage du module"
    
    # Vérifier si WireGuard est déjà installé
    if check_wireguard_installed; then
        echo "${YELLOW}⚠ WireGuard est déjà installé${RESET}"
        log "INF" "[wireguard] WireGuard déjà installé"
        
        printf "Voulez-vous reconfigurer ? (o/N): "
        local response
        read -r response
        if [[ ! "$response" =~ ^[oO]$ ]]; then
            echo "Configuration annulée"
            log "INF" "[wireguard] Reconfiguration annulée par l'utilisateur"
            exit 0
        fi
    else
        # Installation
        install_wireguard
    fi
    
    # Saisie des paramètres
    echo
    echo "${BOLD}Configuration du serveur WireGuard${RESET}"
    echo
    
    printf "Adresse IP du serveur (ex: 10.0.0.1/24): "
    local server_ip
    read -r server_ip
    
    if [[ -z "$server_ip" ]]; then
        error_exit "L'adresse IP est requise"
    fi
    
    printf "Port d'écoute [51820]: "
    local server_port
    read -r server_port
    server_port="${server_port:-51820}"
    
    # Configuration
    echo
    generate_keys
    configure_interface "$server_ip" "$server_port"
    enable_ip_forwarding
    start_wireguard
    
    # Résumé
    show_summary
    
    log "INF" "[wireguard] Module terminé avec succès"
}

# ---------- Exécution ----------
main "$@"
