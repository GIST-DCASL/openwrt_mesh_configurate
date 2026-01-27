#!/usr/bin/env bash
set -euo pipefail

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

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Target directory '$TARGET_DIR' does not exist."
  echo "Please run the clone script first."
  exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
  log "Found config file: $CONFIG_FILE"
  log "Copying to ${TARGET_DIR}/.config"
  cp "$CONFIG_FILE" "${TARGET_DIR}/.config"

  CURRENT_VERSION=$(grep "^CONFIG_VERSION_NUMBER=" "${TARGET_DIR}/.config" | cut -d'=' -f2 | tr -d '"')

  if [[ -z "$CURRENT_VERSION" ]]; then
    CURRENT_VERSION="SNAPSHOT"
    log "Warning: CONFIG_VERSION_NUMBER not found in diffconfig. Using 'SNAPSHOT'."
  fi

  if [[ "$BUILD_MODE" == "server" ]]; then
    VER_SUFFIX="_ser"
  else
    VER_SUFFIX="_bri"
  fi
  
  NEW_VERSION_STRING="${CURRENT_VERSION}${VER_SUFFIX}"
  log "Update Version: '$CURRENT_VERSION' -> '$NEW_VERSION_STRING'"

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


if [[ -d "$FILES_DIR" ]]; then
  log "Found files directory: $FILES_DIR"
  DEST_FILES_DIR="${TARGET_DIR}/files"
  
  if [[ -d "$DEST_FILES_DIR" ]]; then
    log "Cleaning up existing overlay: $DEST_FILES_DIR"
    rm -rf "$DEST_FILES_DIR"
  fi
  
  log "Applying overlay to $DEST_FILES_DIR..."
  mkdir -p "$DEST_FILES_DIR"
  
  # [변경 사항 1] 불필요해진 Exclude 로직 제거 (이제 변수로 제어하므로 파일 제외 불필요)
  log "Copying files using rsync..."
  rsync -av "${FILES_DIR}/" "${DEST_FILES_DIR}/"

  # [변경 사항 2] is_bridge 변수 주입 (Variable Injection)
  CUSTOM_SCRIPT="${DEST_FILES_DIR}/etc/uci-defaults/98_network_custom_setting"
  
  if [[ -f "$CUSTOM_SCRIPT" ]]; then
      if [[ "$BUILD_MODE" == "bridge" ]]; then
          BRIDGE_VAL="1"
      else
          BRIDGE_VAL="0"
      fi

      log "Injecting mode into script: is_bridge=${BRIDGE_VAL}"
      
      # sed를 사용하여 is_bridge=0 (또는 다른 숫자) 패턴을 찾아 현재 모드 값으로 치환
      sed -i "s/^is_bridge=[0-9]\+/is_bridge=${BRIDGE_VAL}/" "$CUSTOM_SCRIPT"
      
  else
      log "Warning: '${CUSTOM_SCRIPT}' not found. Skipping variable injection."
  fi

else
  log "Warning: Files directory '$FILES_DIR' not found. Skipping overlay."
fi

log "Configuration setup complete (Mode: $BUILD_MODE)."
