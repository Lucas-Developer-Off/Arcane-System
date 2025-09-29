#!/usr/bin/env bash
# Installation non-interactive d'Arcane-System depuis un repo GitHub
# Usage local (par wget/curl) :
#   bash -c "$(wget -qO- https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh)" -- [options]
# Options :
#   --repo <user/repo>       (facultatif si REPO_DEFAULT est bon)
#   --branch <branche>       (défaut: main)   --tag <vX.Y.Z> prioritaire sur --branch
#   --dir <chemin>           (défaut: $HOME/Arcane-System)
#   --force                  (sauvegarde l’existant et remplace)
#   -h|--help

set -Eeuo pipefail

# ====== Paramètres par défaut à ADAPTER ======
REPO_DEFAULT="Lucas-Developer-Off/Arcane-System"   # ← remplacer par ton user/repo, ex: LucasDev/Arcane-System
BRANCH_DEFAULT="main"
TARGET_DIR_DEFAULT="${HOME}/Arcane-System"

# ====== Parsing arguments ======
REPO="$REPO_DEFAULT"
BRANCH="$BRANCH_DEFAULT"
TAG=""
TARGET_DIR="$TARGET_DIR_DEFAULT"
FORCE="no"

usage() {
    cat <<EOF
Installateur Arcane-System

Options:
  --repo <user/repo>     Repo GitHub (ex: lucasdev/Arcane-System)
  --branch <branche>     Branche (defaut: ${BRANCH_DEFAULT})
  --tag <vX.Y.Z>         Tag (prioritaire sur --branch)
  --dir <chemin>         Dossier cible (defaut: ${TARGET_DIR_DEFAULT})
  --force                Ecrase l'existant (avec backup .bak.TIMESTAMP)
  -h, --help             Aide
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)   REPO="$2"; shift 2;;
        --branch) BRANCH="$2"; shift 2;;
        --tag)    TAG="$2"; shift 2;;
        --dir|--target) TARGET_DIR="$2"; shift 2;;
        --force)  FORCE="yes"; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Option inconnue: $1"; usage; exit 2;;
    esac
done

log() { printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "${*:2}"; }

require_cmd() {
    local c
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || { echo "Commande requise manquante: $c"; exit 3; }
    done
}

download() {
    # download <url> <destfile>
    local url="$1" dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$dest" "$url"
    else
        echo "Ni wget ni curl n'est disponible."; exit 4
    fi
}

# ====== Vérifications minimales ======
require_cmd tar gzip find

# ====== Construction URL de l'archive GitHub ======
if [[ -n "$TAG" ]]; then
    ARCHIVE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/tags/${TAG}"
    REF_DESC="tag ${TAG}"
else
    ARCHIVE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"
    REF_DESC="branche ${BRANCH}"
fi

log INF "Repo: ${REPO} (${REF_DESC})"
log INF "Cible: ${TARGET_DIR}"

# ====== Téléchargement + extraction ======
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE_FILE="${TMP_DIR}/repo.tar.gz"
download "$ARCHIVE_URL" "$ARCHIVE_FILE" || { echo "Téléchargement échoué."; exit 5; }

mkdir -p "${TMP_DIR}/extract"
tar -xzf "$ARCHIVE_FILE" -C "${TMP_DIR}/extract"

# GitHub décompresse dans un dossier unique <repo>-<ref>
SRC_DIR="$(find "${TMP_DIR}/extract" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[[ -n "$SRC_DIR" && -d "$SRC_DIR" ]] || { echo "Extraction invalide."; exit 6; }

# ====== Déploiement ======
if [[ -e "$TARGET_DIR" ]]; then
    if [[ "$FORCE" == "yes" ]]; then
        BKP="${TARGET_DIR}.bak.$(date +'%Y%m%d%H%M%S')"
        mv "$TARGET_DIR" "$BKP"
        log INF "Backup de l'ancien dossier: $BKP"
    else
        echo "Erreur: ${TARGET_DIR} existe déjà. Relance avec --force pour remplacer."; exit 7;
    fi
fi

mkdir -p "$(dirname "$TARGET_DIR")"
mv "$SRC_DIR" "$TARGET_DIR"

# Rendre exécutables les scripts .sh (jusqu'à 2 niveaux)
if command -v xargs >/dev/null 2>&1; then
    find "$TARGET_DIR" -maxdepth 2 -type f -name "*.sh" -print0 | xargs -0 chmod +x || true
fi

# Marqueur simple
echo "installed_at=$(date +'%F %T')" > "${TARGET_DIR}/.arcane-meta"
echo "source_repo=${REPO}"           >> "${TARGET_DIR}/.arcane-meta"
echo "source_ref=${TAG:-$BRANCH}"    >> "${TARGET_DIR}/.arcane-meta"

log INF "Installation terminée."
log INF "Chemin: ${TARGET_DIR}"
exit 0
