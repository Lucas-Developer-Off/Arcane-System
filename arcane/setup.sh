#!/usr/bin/env bash
# Arcane - Interactive step (ASCII title + styled ARCANE panel + hostname prompt)
# - Clear screen
# - Top ASCII banner
# - Styled panel with "ARCANE" + subtitle (creator/repo/ref/installed/host)
# - Config frame (Hostname) + validation + apply
# - Final confirmation

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# ---------- Colors ----------
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

log() {
    printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"
}

clear || printf '\033c'

# ---------- Top ASCII Banner ----------
cat <<'ASCII'
█████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗
██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝
███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗  
██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝  
██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝
ASCII
echo

# ---------- Read metadata ----------
ROOT_DIR="$(cd "${ARCANE_DIR:-$PWD}/.." >/dev/null 2>&1 && pwd)"
META_FILE="${ROOT_DIR}/.arcane-meta"

if [[ -f "$META_FILE" ]]; then
    META_REPO="$(grep -E '^source_repo=' "$META_FILE" 2>/dev/null | cut -d= -f2- || echo "unknown")"
    META_REF="$(grep -E '^source_ref=' "$META_FILE" 2>/dev/null | cut -d= -f2- || echo "unknown")"
    META_INSTALLED="$(grep -E '^installed_at=' "$META_FILE" 2>/dev/null | cut -d= -f2- || echo "$(date +'%F %T')")"
else
    META_REPO="unknown"
    META_REF="unknown"
    META_INSTALLED="$(date +'%F %T')"
fi

CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"

# ---------- Panel rendering functions ----------
# Fixed inner width for clean rendering
W=60

repeat() {
    # repeat <char> <count>
    local char="$1"
    local count="$2"
    printf "%0.s${char}" $(seq 1 "$count")
}

line_center_raw() {
    # line_center_raw <raw_text> [color_prefix]
    local raw="$1"
    local color="${2:-}"
    local len=${#raw}
    local pad_left=$(( (W - len) / 2 ))
    (( pad_left < 0 )) && pad_left=0
    local pad_right=$(( W - len - pad_left ))
    (( pad_right < 0 )) && pad_right=0
    
    printf "║%*s" "$pad_left" ""
    printf "%s%s%s" "$color" "$raw" "$RESET"
    printf "%*s║\n" "$pad_right" ""
}

line_left() {
    # line_left <text>
    local text="$1"
    local len=${#text}
    
    # Truncate if too long
    if (( len > W - 2 )); then
        text="${text:0:$((W-5))}..."
        len=${#text}
    fi
    
    local pad=$(( W - len - 1 ))
    (( pad < 0 )) && pad=0
    printf "║ %s%*s║\n" "$text" "$pad" ""
}

# ---------- Styled ARCANE panel ----------
# Top border
printf "╔"
repeat "═" "$W"
printf "╗\n"

# Title centered
line_center_raw " ARCANE" "${BOLD}${DARKGREEN}"

# Separator
printf "╟"
repeat "─" "$W"
printf "╢\n"

# Subtitle information
line_left "${DIM}Creator:${RESET} Lucas Developer"
line_left "${DIM}Repository:${RESET} ${META_REPO}"
line_left "${DIM}Ref:${RESET} ${META_REF}"
line_left "${DIM}Installed:${RESET} ${META_INSTALLED}"
line_left "${DIM}Host:${RESET} ${CURRENT_HOST}"

# Bottom border
printf "╚"
repeat "═" "$W"
printf "╝\n"
echo

# ---------- Hostname configuration frame ----------
echo "┌────────────────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration: Hostname${RESET}                           │"
echo "├────────────────────────────────────────────────────────┤"
echo "│  Allowed characters: a-z, A-Z, 0-9, '-'                │"
echo "│  Must start with letter or digit                       │"
echo "│  Max length: 63 characters                             │"
echo "└────────────────────────────────────────────────────────┘"
echo

# ---------- Prompt for hostname ----------
printf "Hostname [%s]: " "${CURRENT_HOST}"
IFS= read -r HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

# Validation
if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]] || [[ "$HOSTNAME_TARGET" =~ -$ ]]; then
    echo
    echo "${RED}✗ Invalid hostname.${RESET}"
    echo "  Requirements:"
    echo "  - Start with letter or digit"
    echo "  - Only letters, digits, and hyphens"
    echo "  - Cannot end with hyphen"
    echo "  - Maximum 63 characters"
    exit 2
fi

# Apply hostname change (requires root privileges)
echo
echo "Applying hostname change..."
if ! hostnamectl set-hostname "$HOSTNAME_TARGET" 2>>"$LOG_FILE"; then
    echo "${RED}✗ Failed to set hostname.${RESET}"
    echo "  Check log file: $LOG_FILE"
    exit 3
fi

# Update /etc/hosts if needed
if grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
    sed -i.bak "s/127.0.1.1.*/127.0.1.1\t${HOSTNAME_TARGET}/" /etc/hosts 2>>"$LOG_FILE" || true
fi

# Final confirmation message
echo
echo "╔════════════════════════════════════════════════════════╗"
printf "║  %s✓ Hostname set:%s %-37s║\n" "$GREEN" "$RESET" "$HOSTNAME_TARGET"
echo "╚════════════════════════════════════════════════════════╝"
echo

log "INF" "Hostname changed from '${CURRENT_HOST}' to '${HOSTNAME_TARGET}'"
exit 0
