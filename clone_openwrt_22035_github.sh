#!/usr/bin/env bash
set -euo pipefail

TAG="v22.03.5"
CUSTOM_FEEDS_FILE=""

REMOTE_DEFAULT="https://github.com/openwrt/openwrt.git"


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

DEST_DIR="${REPO_ROOT}/openwrt"   
REMOTE="$REMOTE_DEFAULT"
APPLY_OVERLAY=1                  
QUIET=0
#CUSTOM_FEEDS_FILE="${REPO_ROOT}/custom_feeds.txt"
CUSTOM_FEEDS_GLOB="${REPO_ROOT}/custom_feeds"*.txt

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dest <dir>        OpenWrt source destination directory (default: ./openwrt)
  --remote <url>      OpenWrt git remote (default: $REMOTE_DEFAULT)
  --no-overlay        Do NOT copy this repo's ./files overlay into OpenWrt tree
  -q, --quiet         Less output
  -h, --help          Show help

What it does:
  1) Clone OpenWrt (from GitHub) and checkout tag ${TAG}
  2) Replace feed URLs to GitHub mirrors
  3) Update & install all feeds
  4) (Default) Copy ./files overlay into OpenWrt ./files

EOF
}

log() {
  if [[ "$QUIET" -eq 0 ]]; then
    echo "[bootstrap] $*"
  fi
}


while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST_DIR="$2"; shift 2 ;;
    --remote) REMOTE="$2"; shift 2 ;;
    --no-overlay) APPLY_OVERLAY=0; shift ;;
    -q|--quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done


if [[ -d "$DEST_DIR/.git" ]]; then
  log "OpenWrt tree exists: $DEST_DIR"
  cd "$DEST_DIR"
  log "Fetching tags..."
  git fetch --tags --force origin
else
  log "Cloning OpenWrt into: $DEST_DIR"
  mkdir -p "$(dirname "$DEST_DIR")"

  if ! git clone --depth 1 --branch "$TAG" "$REMOTE" "$DEST_DIR"; then
    log "Shallow clone failed; falling back to full clone."
    rm -rf "$DEST_DIR"
    git clone "$REMOTE" "$DEST_DIR"
    cd "$DEST_DIR"
    git fetch --tags --force origin
  fi
  cd "$DEST_DIR"
fi


log "Checking out tag: $TAG"
git checkout -f "$TAG"


log "Recording commit hash..."
git rev-parse HEAD | tee "${DEST_DIR}/.openwrt_commit.txt" >/dev/null
echo "$TAG" > "${DEST_DIR}/.openwrt_tag.txt"


log "Switching feeds source to GitHub..."
if [[ -f "feeds.conf.default" ]]; then

  sed -i 's|https://git.openwrt.org/feed/|https://github.com/openwrt/|g' feeds.conf.default
  sed -i 's|https://git.openwrt.org/project/|https://github.com/openwrt/|g' feeds.conf.default

  sed -i 's|https://git.openwrt.org/openwrt/|https://github.com/openwrt/|g' feeds.conf.default
else
  log "Warning: feeds.conf.default not found. Skipping feed URL modification."
fi



#
# Apply custom feeds (optional)
# - Apply all files matching ${REPO_ROOT}/custom_feeds*.txt
# - Idempotent: remove previous injected block first to avoid duplicates
#
shopt -s nullglob
custom_feed_files=( $CUSTOM_FEEDS_GLOB )
shopt -u nullglob

if (( ${#custom_feed_files[@]} > 0 )); then
  IFS=$'\n' custom_feed_files=($(printf '%s\n' "${custom_feed_files[@]}" | sort))
  unset IFS

  FEED_CONF="feeds.conf.default"
  if [[ ! -f "$FEED_CONF" ]]; then
    FEED_CONF="feeds.conf"
    if [[ ! -f "$FEED_CONF" ]]; then
      log "Error: neither feeds.conf.default nor feeds.conf found; cannot apply custom feeds."
      exit 1
    fi
  fi

  BEGIN_MARK="# --- custom_feeds*.txt BEGIN ---"
  END_MARK="# --- custom_feeds*.txt END ---"


  if grep -qF "$BEGIN_MARK" "$FEED_CONF"; then
    log "Removing previous custom feeds block from $FEED_CONF"
    sed -i "/^${BEGIN_MARK}\$/,/^${END_MARK}\$/d" "$FEED_CONF"
  fi

  log "Appending custom feeds from files:"
  for f in "${custom_feed_files[@]}"; do
    log "  - $(basename "$f")"
  done

  {
    echo ""
    echo "$BEGIN_MARK"
    for f in "${custom_feed_files[@]}"; do
      echo "# from: $(basename "$f")"
      # CRLF 정리 + 그대로 삽입
      sed 's/\r$//' "$f"
      echo ""
    done
    echo "$END_MARK"
  } >> "$FEED_CONF"
else
  log "No custom_feeds*.txt in $REPO_ROOT (skipping custom feeds)."
fi




log "Updating feeds..."
./scripts/feeds update -a
log "Installing feeds..."
./scripts/feeds install -a


if [[ "$APPLY_OVERLAY" -eq 1 ]]; then
  if [[ -d "${REPO_ROOT}/files" ]]; then
    log "Applying overlay: ${REPO_ROOT}/files  ->  ${DEST_DIR}/files"
    mkdir -p "${DEST_DIR}/files"

    rsync -a --delete "${REPO_ROOT}/files/" "${DEST_DIR}/files/"
  else
    log "No overlay directory found at ${REPO_ROOT}/files (skipping)."
  fi
fi

log "Done."
log "Next typical steps (optional): cd openwrt && make menuconfig / make defconfig / make -j\$(nproc) world"
