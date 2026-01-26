#!/usr/bin/env bash
set -euo pipefail

# 기본값 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

TARGET_DIR="${REPO_ROOT}/openwrt"
CONFIG_FILE="${REPO_ROOT}/diffconfig"
FILES_DIR="${REPO_ROOT}/files"

DO_DEFCONFIG=1
BUILD_MODE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --target <dir>      OpenWrt source directory (default: ./openwrt)
  --config <file>     Path to diffconfig file (default: ./diffconfig)
  --files <dir>       Path to custom files directory (default: ./files)
  --mode <type>       Set build mode explicitly (server|bridge)
  --no-expand         Do NOT run 'make defconfig' after copying config
  -h, --help          Show help
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
    --mode) BUILD_MODE="$2"; shift 2 ;;
    --no-expand) DO_DEFCONFIG=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# 1. 모드 선택 (대화형 인터페이스)
if [[ -z "$BUILD_MODE" ]]; then
  echo "========================================"
  echo " Which mode will you choice?(select)"
  echo "========================================"
  select opt in "Server (Main Node)" "Bridge (Mesh Node)"; do
    case $opt in
      "Server (Main Node)")
        BUILD_MODE="server"
        break
        ;;
      "Bridge (Mesh Node)")
        BUILD_MODE="bridge"
        break
        ;;
      *) echo "Invalid Input. Try again." ;;
    esac
  done
fi

log "Selected Mode: $BUILD_MODE"

# OpenWrt 디렉토리 확인
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Target directory '$TARGET_DIR' does not exist."
  echo "Please run the clone script first."
  exit 1
fi

# 2. Config 파일 적용 및 동적 버전 수정
if [[ -f "$CONFIG_FILE" ]]; then
  log "Found config file: $CONFIG_FILE"
  log "Copying to ${TARGET_DIR}/.config"
  cp "$CONFIG_FILE" "${TARGET_DIR}/.config"

  # [수정됨] diffconfig 내부의 버전 읽기 로직
  # .config에서 CONFIG_VERSION_NUMBER 줄을 찾아 값만 추출합니다.
  # 예: CONFIG_VERSION_NUMBER="22.03.5" -> 22.03.5
  CURRENT_VERSION=$(grep "^CONFIG_VERSION_NUMBER=" "${TARGET_DIR}/.config" | cut -d'=' -f2 | tr -d '"')

  # 만약 diffconfig에 버전이 명시되어 있지 않다면 기본값(SNAPSHOT) 설정
  if [[ -z "$CURRENT_VERSION" ]]; then
    CURRENT_VERSION="SNAPSHOT"
    log "Warning: CONFIG_VERSION_NUMBER not found in diffconfig. Using 'SNAPSHOT'."
  fi

  # 접미사 설정
  if [[ "$BUILD_MODE" == "server" ]]; then
    VER_SUFFIX="_ser"
  else
    VER_SUFFIX="_bri"
  fi
  
  # 새 버전 문자열 조합
  NEW_VERSION_STRING="${CURRENT_VERSION}${VER_SUFFIX}"
  log "Update Version: '$CURRENT_VERSION' -> '$NEW_VERSION_STRING'"

  # 기존 설정 줄을 지우고, 새로운 버전을 파일 끝에 추가
  sed -i "/^CONFIG_VERSION_NUMBER=/d" "${TARGET_DIR}/.config"
  echo "CONFIG_VERSION_NUMBER=\"$NEW_VERSION_STRING\"" >> "${TARGET_DIR}/.config"

  if [[ "$DO_DEFCONFIG" -eq 1 ]]; then
    log "Expanding configuration (make defconfig)..."
    (cd "$TARGET_DIR" && make defconfig)
  else
    log "Skipping 'make defconfig' as requested."
  fi
else
  log "Warning: Config file '$CONFIG_FILE' not found. Skipping config setup."
fi

# 3. Files 오버레이 적용 (조건부 제외)
if [[ -d "$FILES_DIR" ]]; then
  log "Found files directory: $FILES_DIR"
  DEST_FILES_DIR="${TARGET_DIR}/files"
  
  log "Applying overlay to $DEST_FILES_DIR..."
  mkdir -p "$DEST_FILES_DIR"
  
  # 모드에 따라 제외할 파일 설정
  EXCLUDE_PATTERN=""
  if [[ "$BUILD_MODE" == "server" ]]; then
    EXCLUDE_PATTERN="usr/is_bridge"
  else
    EXCLUDE_PATTERN="usr/is_server"
  fi

  log "Copying files (Excluding: $EXCLUDE_PATTERN)..."
  rsync -av --exclude "$EXCLUDE_PATTERN" "${FILES_DIR}/" "${DEST_FILES_DIR}/"
else
  log "Warning: Files directory '$FILES_DIR' not found. Skipping overlay."
fi

log "Configuration setup complete (Mode: $BUILD_MODE)."
