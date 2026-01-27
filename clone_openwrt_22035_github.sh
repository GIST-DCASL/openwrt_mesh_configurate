#!/usr/bin/env bash
set -euo pipefail

TAG="v22.03.5"
# 변경 1: 기본 리모트 주소를 GitHub로 변경
REMOTE_DEFAULT="https://github.com/openwrt/openwrt.git"

# repo root (this script is assumed to be in ./scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

DEST_DIR="${REPO_ROOT}/openwrt"   # default: ./openwrt
REMOTE="$REMOTE_DEFAULT"
APPLY_OVERLAY=1                  # default: apply this repo's ./files overlay into OpenWrt tree
QUIET=0

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

# arg parse
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

# clone or update
if [[ -d "$DEST_DIR/.git" ]]; then
  log "OpenWrt tree exists: $DEST_DIR"
  cd "$DEST_DIR"
  log "Fetching tags..."
  git fetch --tags --force origin
else
  log "Cloning OpenWrt into: $DEST_DIR"
  mkdir -p "$(dirname "$DEST_DIR")"
  # Shallow clone for tag. If it fails, fall back to full clone.
  if ! git clone --depth 1 --branch "$TAG" "$REMOTE" "$DEST_DIR"; then
    log "Shallow clone failed; falling back to full clone."
    rm -rf "$DEST_DIR"
    git clone "$REMOTE" "$DEST_DIR"
    cd "$DEST_DIR"
    git fetch --tags --force origin
  fi
  cd "$DEST_DIR"
fi

# checkout fixed tag
log "Checking out tag: $TAG"
git checkout -f "$TAG"

# record version info (useful for reproducibility in logs)
log "Recording commit hash..."
git rev-parse HEAD | tee "${DEST_DIR}/.openwrt_commit.txt" >/dev/null
echo "$TAG" > "${DEST_DIR}/.openwrt_tag.txt"

# 변경 2: feeds.conf.default 파일 내 URL을 GitHub 주소로 치환
log "Switching feeds source to GitHub..."
if [[ -f "feeds.conf.default" ]]; then
  # v22.03 기준: packages, routing, telephony 등은 /feed/ 경로, luci는 /project/ 경로를 사용하므로 각각 치환
  sed -i 's|https://git.openwrt.org/feed/|https://github.com/openwrt/|g' feeds.conf.default
  sed -i 's|https://git.openwrt.org/project/|https://github.com/openwrt/|g' feeds.conf.default
  # 혹시 모를 openwrt/openwrt.git 패턴도 대응 (필요 시)
  sed -i 's|https://git.openwrt.org/openwrt/|https://github.com/openwrt/|g' feeds.conf.default
else
  log "Warning: feeds.conf.default not found. Skipping feed URL modification."
fi

# feeds
log "Updating feeds..."
./scripts/feeds update -a
log "Installing feeds..."
./scripts/feeds install -a

# overlay copy (optional)
if [[ "$APPLY_OVERLAY" -eq 1 ]]; then
  if [[ -d "${REPO_ROOT}/files" ]]; then
    log "Applying overlay: ${REPO_ROOT}/files  ->  ${DEST_DIR}/files"
    mkdir -p "${DEST_DIR}/files"
    # Copy overlay contents into OpenWrt ./files
    rsync -a --delete "${REPO_ROOT}/files/" "${DEST_DIR}/files/"
  else
    log "No overlay directory found at ${REPO_ROOT}/files (skipping)."
  fi
fi

log "Done."
log "Next typical steps (optional): cd openwrt && make menuconfig / make defconfig / make -j\$(nproc) world"
