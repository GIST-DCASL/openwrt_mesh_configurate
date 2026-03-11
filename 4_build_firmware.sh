#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
OPENWRT_DIR="${REPO_ROOT}/openwrt"
DEST_DIR="${REPO_ROOT}/firmware"

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SKIP_BUILD=0
VERBOSE=0
DO_CLEAN=0 

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --no-build          Skip compilation, only copy existing binaries
  --clean             Run 'make clean' before building (Full rebuild)
  -v, --verbose       Show verbose build output (make V=s)
  -h, --help          Show this help

Description:
  Runs 'make -j$(nproc)' in the OpenWrt directory and copies 
  the resulting *sysupgrade.bin file to the script's directory.
  By default, it performs an INCREMENTAL BUILD (without 'clean').
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build) SKIP_BUILD=1; shift ;;
    --clean) DO_CLEAN=1; shift ;;
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

      if ! grep -q '^CONFIG_VERSIONOPT=y' .config; then
        echo "CONFIG_VERSIONOPT=y" >> .config
      fi

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

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  if [[ ! -f ".config" ]]; then
    echo -e "${RED}Error: .config file missing. Please run setup_config.sh or make menuconfig first.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Starting OpenWrt build using $(nproc) threads...${NC}"
  
  
  if [[ "$DO_CLEAN" -eq 1 ]]; then
    echo -e "${YELLOW}Performing FULL BUILD (make clean included). This may take a long time.${NC}"
    BUILD_CMD="make defconfig download clean world -j$(nproc)"
  else
    echo -e "${GREEN}Performing INCREMENTAL BUILD.${NC}"
    BUILD_CMD="make defconfig download world -j$(nproc)"
  fi
  
  [[ "$VERBOSE" -eq 1 ]] && BUILD_CMD="$BUILD_CMD V=s"

  if eval $BUILD_CMD; then
    echo -e "${GREEN}Build completed successfully.${NC}"
  else
    echo -e "${RED}Build failed.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Skipping build step (copy-only mode).${NC}"
fi

echo "Searching for sysupgrade.bin..."

FOUND_FILES=$(find bin/targets -type f -name "*sysupgrade.bin" 2>/dev/null || true)

if [[ -z "$FOUND_FILES" ]]; then
  echo -e "${RED}Error: No sysupgrade.bin found in bin/targets.${NC}"
  echo "Make sure the build completed successfully."
  exit 1
fi


if [[ ! -d "$DEST_DIR" ]]; then
  mkdir -p "$DEST_DIR"
  echo -e "${GREEN}Created directory:${NC} $DEST_DIR"
fi

COUNT=0
for FILE in $FOUND_FILES; do
  BASENAME=$(basename "$FILE")
  

  cp "$FILE" "${DEST_DIR}/"
  
  echo -e "${GREEN}Copied:${NC} $FILE"
  echo -e "     -> ${DEST_DIR}/$BASENAME"
  COUNT=$((COUNT+1))
done

if [[ "$COUNT" -gt 0 ]]; then
  echo -e "${GREEN}Success! $COUNT file(s) copied to firmware folder.${NC}"
else
  echo "Something went wrong. No files copied."
fi
