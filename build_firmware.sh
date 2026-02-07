#!/usr/bin/env bash
set -euo pipefail

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
OPENWRT_DIR="${REPO_ROOT}/openwrt"
DEST_DIR="${REPO_ROOT}" # 결과물을 복사할 루트 경로

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 옵션 기본값
SKIP_BUILD=0
VERBOSE=0

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --no-build          Skip compilation, only copy existing binaries
  -v, --verbose       Show verbose build output (make V=s)
  -h, --help          Show this help

Description:
  Runs 'make -j$(nproc)' in the OpenWrt directory and copies 
  the resulting *sysupgrade.bin file to the script's directory.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build) SKIP_BUILD=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ ! -d "$OPENWRT_DIR" ]]; then
  echo -e "${RED}Error: OpenWrt directory not found at $OPENWRT_DIR${NC}"
  exit 1
fi

cd "$OPENWRT_DIR"

CUSTOM_SCRIPT="files/etc/uci-defaults/98_network_custom_setting"
if [[ -f ".config" && -f "$CUSTOM_SCRIPT" ]]; then
  MESH_IP=$(grep "network.meshif.ipaddr=" "$CUSTOM_SCRIPT" | head -n 1 | sed -n "s/.*ipaddr='\([^']*\)'.*/\1/p" || true)
  if [[ -n "$MESH_IP" ]]; then
    IP_SUFFIX="${MESH_IP##*.}"
    if [[ "$IP_SUFFIX" =~ ^[0-9]+$ ]] && (( IP_SUFFIX >= 0 && IP_SUFFIX <= 255 )); then
      echo -e "${GREEN}Stamping VERSION_CODE from mesh IP:${NC} $MESH_IP  ->  ip${IP_SUFFIX}"

      # Ensure VERSIONOPT is enabled (VERSION_CODE options are under it)
      if ! grep -q '^CONFIG_VERSIONOPT=y' .config; then
        echo "CONFIG_VERSIONOPT=y" >> .config
      fi

      # Avoid duplicate lines if re-running
      sed -i \
        -e '/^CONFIG_VERSION_CODE=/d' \
        -e '/^CONFIG_VERSION_CODE_FILENAMES=/d' \
        .config

      echo "CONFIG_VERSION_CODE_FILENAMES=y" >> .config
      echo "CONFIG_VERSION_CODE=\"ip${IP_SUFFIX}\"" >> .config
    else
      echo -e "${YELLOW}Warning:${NC} invalid last octet from IP '$MESH_IP' -> skip filename tag"
    fi
  else
    echo -e "${YELLOW}Notice:${NC} mesh IP not found in $CUSTOM_SCRIPT -> skip filename tag"
  fi
else
  echo -e "${YELLOW}Notice:${NC} missing .config or $CUSTOM_SCRIPT -> skip filename tag"
fi


# 1. 빌드 수행
if [[ "$SKIP_BUILD" -eq 0 ]]; then
  if [[ ! -f ".config" ]]; then
    echo -e "${RED}Error: .config file missing. Please run setup_config.sh or make menuconfig first.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Starting OpenWrt build using $(nproc) threads...${NC}"
  echo "This may take a long time."
  
  BUILD_CMD="make defconfig download clean world -j$(nproc)"
  [[ "$VERBOSE" -eq 1 ]] && BUILD_CMD="$BUILD_CMD V=s"

  if $BUILD_CMD; then
    echo -e "${GREEN}Build completed successfully.${NC}"
  else
    echo -e "${RED}Build failed.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Skipping build step (copy-only mode).${NC}"
fi

# 2. 결과물 탐색 및 복사
echo "Searching for sysupgrade.bin..."

# bin/targets 내부에서 sysupgrade.bin으로 끝나는 파일 찾기
# 주의: 여러 타겟이 빌드되어 있을 경우 복수 파일이 검색될 수 있음
FOUND_FILES=$(find bin/targets -type f -name "*sysupgrade.bin" 2>/dev/null || true)

if [[ -z "$FOUND_FILES" ]]; then
  echo -e "${RED}Error: No sysupgrade.bin found in bin/targets.${NC}"
  echo "Make sure the build completed successfully."
  exit 1
fi

COUNT=0
for FILE in $FOUND_FILES; do
  BASENAME=$(basename "$FILE")
  
  # 파일 복사
  cp "$FILE" "${DEST_DIR}/"
  
  echo -e "${GREEN}Copied:${NC} $FILE"
  echo -e "     -> ${DEST_DIR}/$BASENAME"
  COUNT=$((COUNT+1))
done

if [[ "$COUNT" -gt 0 ]]; then
  echo -e "${GREEN}Success! $COUNT file(s) copied to root.${NC}"
else
  echo "Something went wrong. No files copied."
fi
