#!/usr/bin/env bash
set -euo pipefail

# 기본값 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

TARGET_DIR="${REPO_ROOT}/openwrt"  # OpenWrt 소스 위치
CONFIG_FILE="${REPO_ROOT}/diffconfig" # 적용할 설정 파일 (기본값: ./diffconfig)
FILES_DIR="${REPO_ROOT}/files"        # 적용할 오버레이 폴더 (기본값: ./files)

DO_DEFCONFIG=1 # .config 복사 후 make defconfig 실행 여부

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --target <dir>      OpenWrt source directory (default: ./openwrt)
  --config <file>     Path to diffconfig file (default: ./diffconfig)
  --files <dir>       Path to custom files directory (default: ./files)
  --no-expand         Do NOT run 'make defconfig' after copying config
  -h, --help          Show help

Description:
  Copies the specified diffconfig to .config and applies the custom files overlay.
EOF
}

log() {
  echo "[config-setup] $*"
}

# 인자 파싱
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET_DIR="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --files) FILES_DIR="$2"; shift 2 ;;
    --no-expand) DO_DEFCONFIG=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# OpenWrt 디렉토리 확인
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Target directory '$TARGET_DIR' does not exist."
  echo "Please run the clone script first."
  exit 1
fi

# 1. Config 파일 적용
if [[ -f "$CONFIG_FILE" ]]; then
  log "Found config file: $CONFIG_FILE"
  log "Copying to ${TARGET_DIR}/.config"
  cp "$CONFIG_FILE" "${TARGET_DIR}/.config"

  if [[ "$DO_DEFCONFIG" -eq 1 ]]; then
    log "Expanding configuration (make defconfig)..."
    # make defconfig는 현재 설정(.config)을 기반으로 의존성을 계산하여 
    # 완전한 설정 파일로 만듭니다. (diffconfig 사용 시 필수 권장)
    (cd "$TARGET_DIR" && make defconfig)
  else
    log "Skipping 'make defconfig' as requested."
  fi
else
  log "Warning: Config file '$CONFIG_FILE' not found. Skipping config setup."
fi

# 2. Files 오버레이 적용
if [[ -d "$FILES_DIR" ]]; then
  log "Found files directory: $FILES_DIR"
  DEST_FILES_DIR="${TARGET_DIR}/files"
  
  log "Applying overlay to $DEST_FILES_DIR..."
  mkdir -p "$DEST_FILES_DIR"
  
  # rsync를 사용하여 디렉토리 병합 (존재하지 않으면 일반 cp -r 처럼 동작)
  # -a: 아카이브 모드 (권한, 시간 보존), -v: 상세 출력
  rsync -av "${FILES_DIR}/" "${DEST_FILES_DIR}/"
else
  log "Warning: Files directory '$FILES_DIR' not found. Skipping overlay."
fi

log "Configuration setup complete."
