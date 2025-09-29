#!/usr/bin/env bash
# Arcane - Module WireGuard optimisé
# Installation et configuration de WireGuard

set -Eeuo pipefail

# ---------- Configuration ----------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="${SCRIPT_DIR%/*}"
readonly LOG_FILE="${ARCANE_LOG_FILE:-${ARCANE_DIR:-$ROOT_DIR}/setup.log}"
readonly WG_DIR="/etc/wireguard"
readonly WG_IF="wg0"

# ---------- Couleurs ----------
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    readonly BOLD=$(tput bold) RESET=$(tput sgr0)
    readonly GREEN=$(tput setaf 2) RED=$(tput setaf 1)
    readonly YELLOW=$(tput setaf 3) CYAN=$(tput setaf 6)
else
    readonly BOLD=$'\033[1m' RESET=$'\033[0m'
    readonly GREEN=$'\033[32m' RED=$'\033[31m'
    readonly YELLOW=$'\033[33m' CYAN=$'\033[36m'
fi

# ---------- Logging ----------
log() { printf '%s [WG] %s\n' "$(date '+%F %T')" "$1" >> "$LOG_FILE"; }
error_exit() { echo "${RED}✗ $1${RESET}" >&2; log "ERR: $1"; exit "${2:-1}"; }

# ---------- Détection distribution ----------
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# ---------- Installation ----------
install_wireguard() {
    local os=$(detect_os)
    log "Installation sur: $os"
    
    case "$os" in
        debian|ubuntu)
            apt-get update -qq 2>>"$LOG_FILE" || error_exit "Échec mise à jour apt"
            DEBIAN_FRONTEND=noninteractive apt-get install -qq -y wireguard wireguard-tools 2>>"$LOG_FILE" || \
                error_exit "Échec installation WireGuard"
            ;;
        rhel|centos|rocky|almalinux)
            yum install -y -q epel-release 2>>"$LOG_FILE" || error_exit "Échec installation epel-release"
            yum install -y -q wireguard-tools 2>>"$LOG_FILE" || error_exit "Échec installation WireGuard"
            ;;
        fedora)
            dnf install -y -q wireguard-tools 2>>"$LOG_FILE" || error_exit "Échec installation WireGuard"
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm --quiet wireguard-tools 2>>"$LOG_FILE" || error_exit "Échec installation WireGuard"
            ;;
        *)
            error_exit "Distribution non supportée: $os"
            ;;
    esac
    
    log "WireGuard installé"
}

# ---------- Génération des clés ----------
generate_keys() {
    mkdir -p "$WG_DIR" && chmod 700 "$WG_DIR"
    
    wg genkey | tee "${WG_DIR}/server_private.key" | wg pubkey > "${WG_DIR}/server_public.key"
    chmod 600 "${WG_DIR}/server_private.key"
    chmod 644 "${WG_DIR}/server_public.key"
    
    log "Clés générées"
}

# ---------- Configuration ----------
configure_interface() {
    local ip="${1:-10.0.0.1/24}" port="${2:-51820}" iface
    iface=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
    [[ -z "$iface" ]] && iface="eth0"
    
    cat > "${WG_DIR}/${WG_IF}.conf" << EOF
[Interface]
Address = ${ip}
ListenPort = ${port}
PrivateKey = $(cat "${WG_DIR}/server_private.key")
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${iface} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${iface} -j MASQUERADE

# Peers
EOF
    
    chmod 600 "${WG_DIR}/${WG_IF}.conf"
    log "Interface configurée (IP: $ip, Port: $port, Iface: $iface)"
}

# ---------- IP Forwarding ----------
enable_ip_forwarding() {
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || \
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    log "IP forwarding activé"
}

# ---------- Démarrage ----------
start_wireguard() {
    systemctl enable wg-quick@${WG_IF} 2>>"$LOG_FILE" || error_exit "Échec activation service"
    systemctl start wg-quick@${WG_IF} 2>>"$LOG_FILE" || error_exit "Échec démarrage service"
    log "Service démarré"
}

# ---------- Résumé ----------
show_summary() {
    local pub=$(cat "${WG_DIR}/server_public.key")
    cat << EOF

╔════════════════════════════════════════════════════════╗
║  ${BOLD}${GREEN}WireGuard installé${RESET}                                  ║
╠════════════════════════════════════════════════════════╣
║  Interface : ${WG_IF}                                       ║
║  Clé publique :                                        ║
║  ${pub:0:54} ║
╠════════════════════════════════════════════════════════╣
║  Config : ${WG_DIR}/${WG_IF}.conf                        ║
║  Clés   : ${WG_DIR}/server_*.key                       ║
╚════════════════════════════════════════════════════════╝
EOF
}

# ---------- Main ----------
main() {
    log "Démarrage module WireGuard"
    
    if command -v wg >/dev/null 2>&1; then
        echo "${YELLOW}⚠ WireGuard déjà installé${RESET}"
        log "WireGuard déjà installé"
        printf "Reconfigurer ? (o/N): "
        read -r resp
        [[ ! "$resp" =~ ^[oO]$ ]] && { log "Reconfiguration annulée"; exit 0; }
    else
        install_wireguard
    fi
    
    echo -e "\n${BOLD}Configuration du serveur WireGuard${RESET}\n"
    
    printf "Adresse IP serveur (ex: 10.0.0.1/24) [10.0.0.1/24]: "
    read -r ip
    ip="${ip:-10.0.0.1/24}"
    
    printf "Port d'écoute [51820]: "
    read -r port
    port="${port:-51820}"
    
    echo
    generate_keys
    configure_interface "$ip" "$port"
    enable_ip_forwarding
    start_wireguard
    show_summary
    
    log "Module terminé avec succès"
}

main "$@"
