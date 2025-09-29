#!/usr/bin/env bash
# Arcane - interactive step (ASCII title + styled ARCANE panel + hostname prompt)
# - Clear screen
# - Top ASCII banner
# - Styled panel with "ARCANE" + subtitle (creator/repo/ref/installed/host)
# - Config frame (Hostname) + validation + apply
# - Final confirmation

set -Eeuo pipefail

LOG_FILE="${ARCANE_DIR:-$PWD}/setup.log"

# ---------- Colors ----------
if command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
    GREEN="$(tput setaf 2)"; RED="$(tput setaf 1)"
    COLORS="$(tput colors 2>/dev/null || echo 8)"
    if [ "${COLORS:-8}" -ge 16 ]; then
        DARKGREEN="$(tput setaf 22)"
        CYAN="$(tput setaf 6)"
    else
        DARKGREEN="$(tput setaf 2)"
        CYAN="$(tput setaf 6 2>/dev/null || echo)"
    fi
else
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
    GREEN=$'\033[32m'; RED=$'\033[31m'
    DARKGREEN=$'\033[32m'; CYAN=$'\033[36m'
fi

log(){ printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2" | tee -a "$LOG_FILE"; }

clear || printf '\033c'

# ---------- Top ASCII (keep uncolored for alignment) ----------
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

META_REPO="$(grep -E '^source_repo=' "$META_FILE" 2>/dev/null | cut -d= -f2- || true)"
META_REF="$(grep -E '^source_ref=' "$META_FILE" 2>/dev/null | cut -d= -f2- || true)"
META_INSTALLED="$(grep -E '^installed_at=' "$META_FILE" 2>/dev/null | cut -d= -f2- || true)"
CURRENT_HOST="$(hostnamectl --static 2>/dev/null || hostname)"

[ -n "$META_REPO" ] || META_REPO="unknown"
[ -n "$META_REF" ] || META_REF="unknown"
[ -n "$META_INSTALLED" ] || META_INSTALLED="$(date +'%F %T')"

# ---------- Styled ARCANE panel ----------
# Fixed inner width for clean rendering
W=60

repeat()
{
    # repeat <char> <count>
    printf "%0.s$1" $(seq 1 "$2")
}

line_center_raw()
{
    # line_center_raw <raw_text> [color_prefix]
    local raw="$1"; local color="${2:-}"
    local len=${#raw}
    local pad_left=$(( (W - len) / 2 ))
    (( pad_left < 0 )) && pad_left=0
    local pad_right=$(( W - len - pad_left ))
    (( pad_right < 0 )) && pad_right=0
    printf "╠"; repeat "═"  "$W"; printf "╣\n" >/dev/null # placeholder suppressed
    # Actual centered line:
    printf "║%*s" "$pad_left" ""
    printf "%s%s%s" "$color" "$raw" "$RESET"
    printf "%*s║\n" "$pad_right" ""
}

line_left()
{
    # line_left <text>
    local text="$1"
    local len=${#text}
    (( len > W )) && text="${text:0:W}"
    local pad=$(( W - ${#text} ))
    (( pad < 0 )) && pad=0
    printf "║ %s%*s║\n" "$text" "$((pad-1))" ""
}

# Top border
printf "╔"; repeat "═" "$W"; printf "╗\n"
# Title centered: " ARCANE" (leading space as requested)
line_center_raw " ARCANE" "${BOLD}${DARKGREEN}"

# Separator
printf "╟"; repeat "─" "$W"; printf "╢\n"

# Subtitle (all in English)
line_left "${DIM}Creator:${RESET} Lucas Developer"
line_left "${DIM}Repository:${RESET} ${META_REPO}"
line_left "${DIM}Ref:${RESET} ${META_REF}"
line_left "${DIM}Installed:${RESET} ${META_INSTALLED}"
line_left "${DIM}Host:${RESET} ${CURRENT_HOST}"

# Bottom border
printf "╚"; repeat "═" "$W"; printf "╝\n"
echo

# ---------- Hostname config frame ----------
echo "┌────────────────────────────────────────────────────────┐"
echo "│  ${BOLD}Configuration: Hostname${RESET}                           │"
echo "├────────────────────────────────────────────────────────┤"
echo "│  Allowed characters: a-z, 0-9, '-'                      │"
echo "│  Max length: 63                                         │"
echo "└────────────────────────────────────────────────────────┘"
echo

# ---------- Prompt ----------
printf "Hostname [%s]: " "${CURRENT_HOST}"
IFS= read -r HOSTNAME_TARGET
HOSTNAME_TARGET="${HOSTNAME_TARGET:-$CURRENT_HOST}"

# Validation
if [[ ! "$HOSTNAME_TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
    echo
    echo "${RED}Invalid name.${RESET} Use letters/digits/hyphens, length ≤ 63."
    exit 2
fi

# Apply (requires root through install.sh)
if ! hostnamectl set-hostname "$HOSTNAME_TARGET" 2>>"$LOG_FILE"; then
    echo "${RED}Failed to set hostname.${RESET}"
    exit 3
fi

# Final message
echo
echo "╔════════════════════════════════════════════════════════╗"
printf "║  %sHostname set%s: %s%s%s\n" "$BOLD" "$RESET" "$GREEN" "$HOSTNAME_TARGET" "$RESET"
echo "╚════════════════════════════════════════════════════════╝"
echo

log "INF" "Hostname set: ${HOSTNAME_TARGET}"
exit 0
