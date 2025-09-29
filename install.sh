#!/usr/bin/env bash
# =====================================================
# Arcane-System : installateur non interactif
# - Télécharge le repo GitHub
# - Installe dans ~/Arcane-System (ou --dir)
# - Lance arcane/setup.sh si présent
# - Affiche un message final
# =====================================================

set -Eeuo pipefail

# ====== Paramètres par défaut ======
REPO_DEFAULT="Lucas-Developer-Off/Arcane-System"
BRANCH_DEFAULT="main"
TARGET_DIR_DEFAULT="${HOME}/Arcane-System"
ARCANE_SUBDIR_DEFAULT="arcane"   # tout le reste vit ici

# ====== Parsing arguments ======
REPO="$REPO_DEFAULT"
BRANCH="$BRANCH_DEFAULT"
TAG=""
TARGET_DIR="$TARGET_DIR_DEFAULT"
FORCE="no"
ARCANE_SUBDIR="$ARCANE_SUBDIR_DEFAULT"

usage() {
    cat <<EOF
Installateur Arcane-System

Options:
  --repo <user/repo>     Repo GitHub (defaut: ${REPO_DEFAULT})
  --branch <branche>     Branche       (defaut: ${BRANCH_DEFAULT})
  --tag <vX.Y.Z>         Tag (prioritaire sur --branch)
  --dir <chemin>         Dossier cible (defaut: ${TARGET_DIR_DEFAULT})
  --subdir <nom>         Sous-dossier applicatif (defaut: ${ARCANE_SUBDIR_DEFAULT})
  --force                Écrase l'existant (backup .bak.TIMESTAMP)
  -h, --help             Aide
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)     REPO="$2"; shift 2;;
        --branch)   BRANCH="$2"; shift 2;;
        --tag)      TAG="$2"; shift 2;;
        --dir|--target) TARGET_DIR="$2"; shift 2;;
        --subdir)   ARCANE_SUBDIR="$2"; shift 2;;
        --force)    FORCE="yes"; shift;;
        -h|--help)  usage; exit 0;;
        *) echo "Option inconnue: $1"; usage; exit 2;;
    esac
done

# ====== Fonctions ======
log() { printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "${*:2}"; }

require_cmd() {
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || { echo "Commande requise manquante: $c"; exit 3; }
    done
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

# ====== Vérifications ======
require_cmd tar gzip find

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
        echo "Erreur: ${TARGET_DIR} existe déjà. Utilise --force."; exit 7;
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
    if [[ $EUID -ne 0 ]]; then
        sudo -E -H bash -Eeuo pipefail -c "cd \"$ARCANE_DIR\" && ./setup.sh" | tee -a "$SETUP_LOG"
        RC=${PIPESTATUS[0]}
    else
        ( cd "$ARCANE_DIR" && bash -Eeuo pipefail ./setup.sh ) | tee -a "$SETUP_LOG"
        RC=${PIPESTATUS[0]}
    fi

    if [[ $RC -eq 0 ]]; then
        log INF "setup.sh terminé avec succès. (log: $SETUP_LOG)"
    else
        log ERR "setup.sh a échoué (code=$RC). Consulte $SETUP_LOG"
        exit $RC
    fi
else
    log WRN "setup.sh absent dans ${ARCANE_DIR} → étape post-install ignorée."
fi

# ====== Message final ======
cat <<EOF

====================================================
 ✅ Arcane-System installé
----------------------------------------------------
 📂 Dossier : ${TARGET_DIR}
 📁 App     : ${ARCANE_DIR}
 📜 Log     : ${SETUP_LOG}

 🔁 Relancer le setup manuellement :
     cd ${ARCANE_DIR} && sudo ./setup.sh
====================================================

EOF
