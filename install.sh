#!/usr/bin/env bash
# Arcane-System : Installateur optimisé
# Télécharge, installe et configure automatiquement

set -Eeuo pipefail

# ---------- Configuration ----------
readonly REPO_DEFAULT="Lucas-Developer-Off/Arcane-System"
readonly BRANCH_DEFAULT="main"
readonly TARGET_DIR_DEFAULT="${HOME}/Arcane-System"
readonly ARCANE_SUBDIR="arcane"
readonly LOCK_DIR="/var/lib/arcane"
readonly LOCK_FILE="${LOCK_DIR}/installed.lock"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- Variables ----------
REPO="$REPO_DEFAULT"
BRANCH="$BRANCH_DEFAULT"
TAG=""
TARGET_DIR="$TARGET_DIR_DEFAULT"
FORCE="no"
REINSTALL="no"
USE_LOCAL="auto"

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
${BOLD}Installateur Arcane-System${RESET}

${BOLD}Usage:${RESET}
  $(basename "$0") [options]

${BOLD}Options:${RESET}
  --repo <user/repo>   Repo GitHub (défaut: ${REPO_DEFAULT})
  --branch <branche>   Branche (défaut: ${BRANCH_DEFAULT})
  --tag <vX.Y.Z>       Tag spécifique (prioritaire sur --branch)
  --dir <chemin>       Dossier cible (défaut: ${TARGET_DIR_DEFAULT})
  --force              Remplace le dossier existant (backup auto)
  --reinstall          Autorise réinstallation malgré le verrou
  -h, --help           Affiche cette aide

${BOLD}Exemples:${RESET}
  sudo $(basename "$0")
  sudo $(basename "$0") --tag v1.0.0
  sudo $(basename "$0") --dir /opt/arcane --force
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
    local message="$1"; shift
    local cmd="$*"

    echo "${BOLD}${message}${RESET}"

    # Lance la commande en arrière-plan
    bash -c "$cmd" &
    local cmd_pid=$!

    # Prépare l'affichage
    local width=40
    local i=0
    tput civis 2>/dev/null || true
    printf "\n"  # ligne dédiée à la barre

    # Animation tant que la commande tourne
    while kill -0 "$cmd_pid" >/dev/null 2>&1; do
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

download() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$dest" "$url" --progress-bar 2>&1 | tr '\r' '\n' | tail -1
    elif command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$dest" "$url" 2>&1 | tail -1
    else
        error_exit "Ni curl ni wget disponible" 3
    fi
}

write_lock() {
    mkdir -p "$LOCK_DIR"
    cat > "$LOCK_FILE" <<EOF
installed_at=$(date '+%F %T')
source_repo=${REPO}
source_ref=${TAG:-$BRANCH}
target_dir=${TARGET_DIR}
hostname=$(hostnamectl --static 2>/dev/null || hostname)
user=${SUDO_USER:-$USER}
EOF
    chmod 644 "$LOCK_FILE"
}

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

# ---------- Parsing arguments ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)      REPO="$2"; shift 2;;
        --branch)    BRANCH="$2"; shift 2;;
        --tag)       TAG="$2"; shift 2;;
        --dir)       TARGET_DIR="$2"; shift 2;;
        --force)     FORCE="yes"; shift;;
        --reinstall) REINSTALL="yes"; shift;;
        --local)     USE_LOCAL="yes"; shift;;
        -h|--help)   usage; exit 0;;
        *) error_exit "Option inconnue: $1\nUtilise --help pour l'aide" 2;;
    esac
done

# ---------- Main ----------
main() {
    clear 2>/dev/null || printf '\033c'
    show_banner
    
    require_root
    require_cmd tar gzip apt-get

    # Mise à jour du système avec barre de progression
    log "Préparation de la mise à jour du système"
    if run_with_progress "Exécution: apt-get update && apt-get upgrade -y" "apt-get update && apt-get upgrade -y"; then
        log "${GREEN}✓ Système à jour${RESET}"
    else
        log "${YELLOW}⚠ La mise à jour du système a rencontré des erreurs (suite de l'installation)${RESET}"
    fi
    
    # Mode local: si le script est exécuté depuis un clone contenant arcane/setup.sh
    local local_arcane_setup="${SCRIPT_DIR}/${ARCANE_SUBDIR}/setup.sh"
    if [[ "$USE_LOCAL" == "yes" || ( "$USE_LOCAL" == "auto" && -f "$local_arcane_setup" ) ]]; then
        log "Mode    : ${BOLD}local${RESET} (aucun téléchargement)"
        TARGET_DIR="$SCRIPT_DIR"
        local arcane_dir="${TARGET_DIR}/${ARCANE_SUBDIR}"
        local setup="${arcane_dir}/setup.sh"
        echo
        if [[ -f "$setup" ]]; then
            log "Lancement de ${BOLD}setup.sh${RESET}..."
            echo
            export ARCANE_DIR="$arcane_dir"
            if (cd "$arcane_dir" && bash ./setup.sh); then
                log "${GREEN}✓ Configuration terminée${RESET}"
            else
                error_exit "Échec de la configuration" 8
            fi
            write_lock
            # Résumé final
            cat << EOF

╔═══════════════════════════════════════════════════════════╗
║  ${BOLD}${GREEN}✓  Installation réussie${RESET}                               ║
╠═══════════════════════════════════════════════════════════╣
║  📂 Dossier : ${TARGET_DIR}
║  📁 App     : ${arcane_dir}
║  🔒 Verrou  : ${LOCK_FILE}
║                                                           ║
║  ${BOLD}Réinstaller :${RESET}                                         ║
║  sudo $0 --reinstall --force --local
╚═══════════════════════════════════════════════════════════╝

EOF
            return 0
        else
            log "${YELLOW}⚠ setup.sh introuvable en mode local, bascule en mode distant${RESET}"
        fi
    fi
    
    # Vérif verrou
    if [[ -f "$LOCK_FILE" && "$REINSTALL" != "yes" ]]; then
        echo "${YELLOW}⚠ Installation déjà présente${RESET}"
        echo "  Verrou : ${LOCK_FILE}"
        echo "  Pour réinstaller : ${BOLD}sudo $0 --reinstall --force${RESET}"
        exit 10
    fi
    
    # URL archive
    if [[ -n "$TAG" ]]; then
        local url="https://codeload.github.com/${REPO}/tar.gz/refs/tags/${TAG}"
        local ref="${TAG}"
    else
        local url="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"
        local ref="${BRANCH}"
    fi
    
    log "Dépôt    : ${BOLD}${REPO}${RESET} (${ref})"
    log "Cible    : ${BOLD}${TARGET_DIR}${RESET}"
    log "Verrou   : ${BOLD}${LOCK_FILE}${RESET}"
    echo
    
    # Téléchargement
    local tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT
    
    local archive="${tmp_dir}/repo.tar.gz"
    log "Téléchargement..."
    download "$url" "$archive" || error_exit "Échec du téléchargement" 4
    
    # Extraction
    log "Extraction..."
    mkdir -p "${tmp_dir}/extract"
    tar -xzf "$archive" -C "${tmp_dir}/extract" 2>/dev/null || error_exit "Échec de l'extraction" 5
    
    local src_dir=$(find "${tmp_dir}/extract" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [[ -z "$src_dir" ]] && error_exit "Archive invalide" 6
    
    # Déploiement
    if [[ -e "$TARGET_DIR" ]]; then
        if [[ "$FORCE" == "yes" ]]; then
            local bkp="${TARGET_DIR}.bak.$(date +%s)"
            mv "$TARGET_DIR" "$bkp"
            log "Backup   : ${bkp}"
        else
            error_exit "${TARGET_DIR} existe. Utilise --force pour remplacer" 7
        fi
    fi
    
    log "Installation..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    mv "$src_dir" "$TARGET_DIR"
    
    # Permissions
    find "$TARGET_DIR" -maxdepth 2 -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    # Métadonnées
    cat > "${TARGET_DIR}/.arcane-meta" <<EOF
installed_at=$(date '+%F %T')
source_repo=${REPO}
source_ref=${ref}
EOF
    
    echo
    log "${GREEN}✓ Installation terminée${RESET}"
    echo
    
    # Lancement setup
    local arcane_dir="${TARGET_DIR}/${ARCANE_SUBDIR}"
    local setup="${arcane_dir}/setup.sh"
    
    if [[ -f "$setup" ]]; then
        log "Lancement de ${BOLD}setup.sh${RESET}..."
        echo
        export ARCANE_DIR="$arcane_dir"
        
        if (cd "$arcane_dir" && bash ./setup.sh); then
            log "${GREEN}✓ Configuration terminée${RESET}"
        else
            error_exit "Échec de la configuration" 8
        fi
    else
        log "${YELLOW}⚠ setup.sh introuvable, installation brute${RESET}"
    fi
    
    # Verrou
    write_lock
    
    # Résumé final
    cat << EOF

╔═══════════════════════════════════════════════════════════╗
║  ${BOLD}${GREEN}✓  Installation réussie${RESET}                               ║
╠═══════════════════════════════════════════════════════════╣
║  📂 Dossier : ${TARGET_DIR}
║  📁 App     : ${arcane_dir}
║  🔒 Verrou  : ${LOCK_FILE}
║                                                           ║
║  ${BOLD}Réinstaller :${RESET}                                         ║
║  sudo $0 --reinstall --force
╚═══════════════════════════════════════════════════════════╝

EOF
}

main "$@"
