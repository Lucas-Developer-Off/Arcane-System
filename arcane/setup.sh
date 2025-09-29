#!/usr/bin/env bash
# Arcane - Setup interactif (bannière double cadre + panneau + configuration hostname)
# - Bannière ASCII (double cadre + bandeau titre)
# - Panneau (Développeur + Version du script depuis version.txt)
# - Saisie hostname + validation + application
# - Journalisation

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# ---------- Couleurs ----------
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"
    DIM="$(tput dim)"
    RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"
    RED="$(tput setaf 1)"
    COLORS="$(tput colors 2>/dev/null || echo 8)"
    if [ "${COLORS:-8}" -ge 16 ]; then
        DARKGREEN="$(tput setaf 22)"
        CYAN="$(tput setaf 6)"
    else
        DARKGREEN="$(tput setaf 2)"
        CYAN="$(tput setaf 6 2>/dev/null || echo)"
    fi
else
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    DARKGREEN=$'\033[32m'
    CYAN=$'\033[36m'
fi

log()
{
    printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"
}

# ---------- Terminal / mise en page ----------
# Largeur interne du cadre extérieur (W) : fixe pour un rendu stable.
W=78
IW=$(( W - 6 ))  # largeur utile du sous-cadre (entre │ │), avec marges

repeat() { # repeat <char> <count>
    # Utilise printf + seq (portable sur Linux). Si seq absent, fallback simple.
    local char="$1" count="$2"
    if command -v seq >/dev/null 2>&1; then
        printf "%0.s%s" $(seq 1 "$count") "$char"
    else
        local i
        for (( i=0; i<count; i++ )); do printf "%s" "$char"; done
    fi
}

center() { # center <text> <width>
    local text="$1" width="$2"
    # Retire approximativement les séquences ANSI pour un centrage visuel correct.
    local plain="${text//\033\[[0-9;]*m/}"
    local len=${#plain}
    if (( len > width )); then
        printf "%s" "$text" | cut -c1-"$width"
        return
    fi
    local pad_left=$(( (width - len) / 2 ))
    local pad_right=$(( width - len - pad_left ))
    repeat " " "$pad_left"; printf "%s" "$text"; repeat " " "$pad_right"
}

line_outer_blank() {
    printf "║"; repeat " " "$W"; printf "║\n"
}

line_outer_text_left() { # line_outer_text_left <text>
    local text="$1"
    # Tronque si nécessaire en se basant sur longueur "visible".
    local plain="${text//\033\[[0-9;]*m/}"
    local len=${#plain}
    if (( len > W )); then
        # On coupe en conservant les séquences ANSI (approximation acceptable)
        text="$(printf "%s" "$text" | cut -c1-$W)"
        plain="${text//\033\[[0-9;]*m/}"
        len=${#plain}
    fi
    printf "║%s" "$text"
    repeat " " $(( W - len ))
    printf "║\n"
}

line_inner_blank() {
    printf "║  │"; repeat " " "$IW"; printf "│  ║\n"
}

line_inner_center() { # line_inner_center <text>
    local text="$1"
    printf "║  │"; center "$text" "$IW"; printf "│  ║\n"
}

section_header() { # section_header <LABEL>
    local label=" $1 "
    local left_len=$(( (W - ${#label}) / 2 ))
    local right_len=$(( W - ${#label} - left_len ))
    printf "╠"; repeat "═" "$left_len"; printf "%s" "$label"; repeat "═" "$right_len"; printf "╣\n"
}

clear || printf '\033c'
echo

# ---------- Lecture version ----------
# On suppose que setup.sh est dans <repo>/arcane/setup.sh et version.txt à <repo>/version.txt
ROOT_DIR="$(cd "${ARCANE_DIR:-$PWD}/.." >/dev/null 2>&1 && pwd)"
VERSION_FILE="${ROOT_DIR}/version.txt"

if [[ -f "$VERSION_FILE" ]]; then
    ARCANE_VERSION="$(head -n1 "$VERSION_FILE" | tr -d '\r\n')"
else
    ARCANE_VERSION="unknown"
fi

CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"

# ---------- Bannière double cadre ----------
printf "╔"; repeat "═" "$W"; printf "╗\n"
line_outer_text_left " ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ${BOLD}${CYAN}A R C A N E${RESET}   ${DIM}P R O J E C T${RESET}  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ "
printf "╠"; repeat "═" "$W"; printf "╣\n"

# Sous-cadre
printf "║  ┌"; repeat "─" "$IW"; printf "┐  ║\n"
line_inner_blank
line_inner_center "${BOLD}${DARKGREEN} █████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗  ██████╗ ${RESET}"
line_inner_center "${BOLD}${DARKGREEN}██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝ ██╔═══██╗${RESET}"
line_inner_center "${BOLD}${DARKGREEN}███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗   ██║   ██║${RESET}"
line_inner_center "${BOLD}${DARKGREEN}██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝   ██║   ██║${RESET}"
line_inner_center "${BOLD}${DARKGREEN}██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗ ╚██████╔╝${RESET}"
line_inner_center "${BOLD}${DARKGREEN}╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝  ╚═════╝ ${RESET}"
line_inner_blank
printf "║  └"; repeat "─" "$IW"; printf "┘  ║\n"

section_header "INFO"
line_outer_blank
line_outer_text_left " • ${DIM}Developer${RESET}   : Lucas Developer"
line_outer_text_left " • ${DIM}Version${RESET}     : ${ARCANE_VERSION}"
line_outer_blank
printf "╚"; repeat "═" "$W"; printf "╝\n"
echo

# ---------- Cadre de configuration Hostname ----------
echo "┌────────────────────────────────────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration: Hostname${RESET}                                                     │"
echo "├────────────────────────────────────────────────────────────────────────────┤"
echo "│  Caractères autorisés : a-z, A-Z, 0-9, '-'                                 │"
echo "│  Doit commencer par une lettre ou un chiffre                               │"
echo "│  Longueur max : 63 caractères                                              │"
echo "└────────────────────────────────────────────────────────────────────────────┘"
echo

# ---------- Saisie ----------
printf "Hostname [%s]: " "${CURRENT_HOST}"
IFS= read -r HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

# ---------- Validation ----------
if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]] || [[ "$HOSTNAME_TARGET" =~ -$ ]]; then
    echo
    echo "${RED}✗ Hostname invalide.${RESET}"
    echo "  Règles :"
    echo "  - Commencer par lettre ou chiffre"
    echo "  - Uniquement lettres, chiffres et tirets"
    echo "  - Ne pas finir par un tiret"
    echo "  - 63 caractères maximum"
    exit 2
fi

# ---------- Application ----------
echo
echo "Application du nouveau hostname…"
if ! hostnamectl set-hostname "$HOSTNAME_TARGET" 2>>"$LOG_FILE"; then
    echo "${RED}✗ Échec du changement de hostname.${RESET}"
    echo "  Voir le log : $LOG_FILE"
    exit 3
fi

# /etc/hosts (si présent)
if grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
    sed -i.bak "s/127.0.1.1.*/127.0.1.1\t${HOSTNAME_TARGET}/" /etc/hosts 2>>"$LOG_FILE" || true
fi

# ---------- Confirmation ----------
echo
echo "╔════════════════════════════════════════════════════════════════════════════╗"
printf "║  %s✓ Hostname défini :%s %-54s║\n" "$GREEN" "$RESET" "$HOSTNAME_TARGET"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo

log "INF" "Hostname changed from '${CURRENT_HOST}' to '${HOSTNAME_TARGET}'"
exit 0
