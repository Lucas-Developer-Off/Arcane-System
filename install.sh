#!/usr/bin/env bash
# =====================================================
# Arcane-System : installateur non interactif + verrou
# - Télécharge le repo GitHub
# - Installe dans ~/Arcane-System (ou --dir)
# - Lance arcane/setup.sh si présent
# - Crée /var/lib/arcane/installed.lock
# - Bloque toute réinstallation si lock présent (sauf --reinstall)
# =====================================================

set -Eeuo pipefail

# ====== Paramètres par défaut ======
REPO_DEFAULT="Lucas-Developer-Off/Arcane-System"
BRANCH_DEFAULT="main"
TARGET_DIR_DEFAULT="${HOME}/Arcane-System"
ARCANE_SUBDIR_DEFAULT="arcane"   # tout le reste vit ici

LOCK_DIR_DEFAULT="/var/lib/arcane"
LOCK_FILE_NAME="installed.lock"

# ====== Parsing arguments ======
REPO="$REPO_DEFAULT"
BRANCH="$BRANCH_DEFAULT"
TAG=""
TARGET_DIR="$TARGET_DIR_DEFAULT"
FORCE="no"
REINSTALL="no"
ARCANE_SUBDIR="$ARCANE_SUBDIR_DEFAULT"
LOCK_DIR="$LOCK_DIR_DEFAULT"

usage() {
    cat <<EOF
Installateur Arcane-System

Options:
  --repo <user/repo>     Repo GitHub (defaut: ${REPO_DEFAULT})
  --branch <branche>     Branche       (defaut: ${BRANCH_DEFAULT})
  --tag <vX.Y.Z>         Tag (prioritaire sur --branch)
  --dir <chemin>         Dossier cible (defaut: ${TARGET_DIR_DEFAULT})
  --subdir <nom>         Sous-dossier applicatif (defaut: ${ARCANE_SUBDIR_DEFAULT})
  --lock-dir <chemin>    Dossier du verrou (defaut: ${LOCK_DIR_DEFAULT})
  --force                Remplace le dossier cible existant (backup)
  --reinstall            Autorise la réinstallation même si un verrou existe
  -h, --help             Aide
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)       REPO="$2"; shift 2;;
        --branch)     BRANCH="$2"; shift 2;;
        --tag)        TAG="$2"; shift 2;;
        --dir|--target) TARGET_DIR="$2"; shift 2;;
        --subdir)     ARCANE_SUBDIR="$2"; shift 2;;
        --lock-dir)   LOCK_DIR="$2"; shift 2;;
        --force)      FORCE="yes"; shift;;
        --reinstall)  REINSTALL="yes"; shift;;
        -h|--help)    usage; exit 0;;
        *) echo "Option inconnue: $1"; usage; exit 2;;
    esac
done

LOCK_FILE="${LOCK_DIR}/${LOCK_FILE_NAME}"

# ====== Fonctions ======
log() { printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "${*:2}"; }

require_cmd() {
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || { echo "Commande requise manquante: $c"; exit 3; }
    done
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Ce script doit être exécuté en root (sudo) pour gérer le verrou dans ${LOCK_DIR}."
        exit 1
    fi
}

download() {
    local url="$1" dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$dest" "$url"
    else
        echo "Ni wget ni curl trouvé."; exit 4
    fi
}

write_lock() {
    install -d -m 0755 "$LOCK_DIR"
    local host_now
    host_now="$(hostnamectl --static 2>/dev/null || hostname)"
    cat > "$LOCK_FILE" <<EOF
installed_at=$(date +'%F %T')
source_repo=${REPO}
source_ref=${TAG:-$BRANCH}
target_dir=${TARGET_DIR}
arcane_subdir=${ARCANE_SUBDIR}
hostname=${host_now}
user=${SUDO_USER:-$USER}
EOF
    chmod 0644 "$LOCK_FILE"
}

# ====== Pré-requis ======
require_root
require_cmd tar gzip find

# ====== Vérif verrou ======
if [[ -f "$LOCK_FILE" && "$REINSTALL" != "yes" ]]; then
    echo "Installation déjà présente (verrou: $LOCK_FILE)."
    echo "Pour réinstaller : relance avec --reinstall (et --force pour remplacer ${TARGET_DIR})."
    exit 10
fi

# ====== URL archive GitHub ======
if [[ -n "$TAG" ]]; then
    ARCHIVE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/tags/${TAG}"
    REF_DESC="tag ${TAG}"
else
    ARCHIVE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"
    REF_DESC="branche ${BRANCH}"
fi

log INF "Repo: ${REPO} (${REF_DESC})"
log INF "Cible: ${TARGET_DIR}"
log INF "Sous-dossier applicatif: ${ARCANE_SUBDIR}"
log INF "Verrou: ${LOCK_FILE}"

# ====== Téléchargement ======
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE_FILE="${TMP_DIR}/repo.tar.gz"
download "$ARCHIVE_URL" "$ARCHIVE_FILE" || { echo "Téléchargement échoué."; exit 5; }

mkdir -p "${TMP_DIR}/extract"
tar -xzf "$ARCHIVE_FILE" -C "${TMP_DIR}/extract"

SRC_DIR="$(find "${TMP_DIR}/extract" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[[ -n "$SRC_DIR" && -d "$SRC_DIR" ]] || { echo "Extraction invalide."; exit 6; }

# ====== Déploiement ======
if [[ -e "$TARGET_DIR" ]]; then
    if [[ "$FORCE" == "yes" ]]; then
        BKP="${TARGET_DIR}.bak.$(date +'%Y%m%d%H%M%S')"
        mv "$TARGET_DIR" "$BKP"
        log INF "Backup de l'ancien dossier: $BKP"
    else
        echo "Erreur: ${TARGET_DIR} existe déjà. Utilise --force pour remplacer."
        exit 7
    fi
fi

mkdir -p "$(dirname "$TARGET_DIR")"
mv "$SRC_DIR" "$TARGET_DIR"

# Scripts .sh exécutables (2 niveaux)
if command -v xargs >/dev/null 2>&1; then
    find "$TARGET_DIR" -maxdepth 2 -type f -name "*.sh" -print0 | xargs -0 chmod +x || true
else
    find "$TARGET_DIR" -maxdepth 2 -type f -name "*.sh" -exec chmod +x {} \; || true
fi

# Meta
{
  echo "installed_at=$(date +'%F %T')"
  echo "source_repo=${REPO}"
  echo "source_ref=${TAG:-$BRANCH}"
  echo "arcane_subdir=${ARCANE_SUBDIR}"
} > "${TARGET_DIR}/.arcane-meta"

log INF "Installation terminée."
log INF "Chemin: ${TARGET_DIR}"

# ====== Lancement auto : arcane/setup.sh ======
ARCANE_DIR="${TARGET_DIR}/${ARCANE_SUBDIR}"
SETUP="${ARCANE_DIR}/setup.sh"
SETUP_LOG="${ARCANE_DIR}/setup.log"

if [[ -f "$SETUP" ]]; then
    log INF "setup.sh détecté → exécution immédiate (dans ${ARCANE_DIR})."
    export ARCANE_DIR
    ( cd "$ARCANE_DIR" && bash -Eeuo pipefail ./setup.sh ) | tee -a "$SETUP_LOG"
    RC=${PIPESTATUS[0]}
    if [[ $RC -ne 0 ]]; then
        log ERR "setup.sh a échoué (code=$RC). Consulte $SETUP_LOG"
        exit $RC
    fi
    log INF "setup.sh terminé avec succès. (log: $SETUP_LOG)"
else
    log WRN "setup.sh absent dans ${ARCANE_DIR} → étape post-install ignorée."
fi

# ====== Écriture du verrou (toujours, même sans setup.sh) ======
write_lock

# ====== Message final ======
cat <<EOF

====================================================
 ✅ Arcane-System installé
----------------------------------------------------
 📂 Dossier : ${TARGET_DIR}
 📁 App     : ${ARCANE_DIR}
 🔒 Verrou  : ${LOCK_FILE}

 🔁 Pour réinstaller malgré le verrou :
     sudo $(basename "$0") --reinstall --force

 📜 Log setup : ${SETUP_LOG}
====================================================

EOF
