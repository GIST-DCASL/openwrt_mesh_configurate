#!/usr/bin/env bash
set -euo pipefail


DEFAULT_TARGET="./openwrt/files/etc/uci-defaults/95_network_custom_setting"

TARGET_FILE="$DEFAULT_TARGET"
NEW_IP=""
NEW_SSID=""
NEW_KEY=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --ip <ip>           Set Mesh Interface IP
  --ssid <name>       Set Mesh ID / SSID
  --key <password>    Set Mesh Key / Password
  --target <file>     Path to the target file (default: $DEFAULT_TARGET)
  -h, --help          Show help
EOF
}


while [[ $# -gt 0 ]]; do
  case "$1" in
    --ip) NEW_IP="$2"; shift 2 ;;
    --ssid) NEW_SSID="$2"; shift 2 ;;
    --key) NEW_KEY="$2"; shift 2 ;;
    --target) TARGET_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ ! -f "$TARGET_FILE" ]]; then
  echo -e "${YELLOW}Error: Target file not found at: $TARGET_FILE${NC}"
  echo "Please check the path or use --target to specify the location."
  exit 1
fi

echo -e "${GREEN}Target File: $TARGET_FILE${NC}"

if [[ -z "$NEW_IP" ]] && [[ -z "$NEW_SSID" ]] && [[ -z "$NEW_KEY" ]]; then
  
  
  CUR_IP=$(grep "network.meshif.ipaddr=" "$TARGET_FILE" | head -n 1 | sed -n "s/.*ipaddr='\([^']*\)'.*/\1/p" || true)
  
  CUR_SSID=$(grep "wireless.wmesh.mesh_id=" "$TARGET_FILE" | head -n 1 | sed -n "s/.*mesh_id='\([^']*\)'.*/\1/p" || true)
  
  CUR_KEY=$(grep "wireless.wmesh.key=" "$TARGET_FILE" | head -n 1 | sed -n "s/.*key='\([^']*\)'.*/\1/p" || true)

  echo "------------------------------------------------"
  echo "Interactive Mode: Press Enter without value to keep the current value."
  echo "------------------------------------------------"
  
  # IP 입력
  echo -e "Current IP:   ${BLUE}${CUR_IP:-Unknown}${NC}"
  read -p "Enter New IP: " INPUT_IP
  [[ -n "$INPUT_IP" ]] && NEW_IP="$INPUT_IP"
  echo ""

  # SSID 입력
  echo -e "Current SSID: ${BLUE}${CUR_SSID:-Unknown}${NC}"
  read -p "Enter New SSID: " INPUT_SSID
  [[ -n "$INPUT_SSID" ]] && NEW_SSID="$INPUT_SSID"
  echo ""
  
  # Key 입력
  echo -e "Current Key:  ${BLUE}${CUR_KEY:-Unknown}${NC}"
  read -p "Enter New Key: " INPUT_KEY
  [[ -n "$INPUT_KEY" ]] && NEW_KEY="$INPUT_KEY"
  echo "------------------------------------------------"
fi


CHANGED=0

if [[ -n "$NEW_IP" ]]; then
  echo "Updating IP to: $NEW_IP"
  sed -i "s|uci -q set network.meshif.ipaddr='.*'|uci -q set network.meshif.ipaddr='$NEW_IP'|g" "$TARGET_FILE"
  CHANGED=1
fi

if [[ -n "$NEW_SSID" ]]; then
  echo "Updating SSID to: $NEW_SSID"
  sed -i "s|uci -q set wireless.wmesh.mesh_id='.*'|uci -q set wireless.wmesh.mesh_id='$NEW_SSID'|g" "$TARGET_FILE"
  CHANGED=1
fi

if [[ -n "$NEW_KEY" ]]; then
  echo "Updating Key to: $NEW_KEY"
  sed -i "s|uci -q set wireless.wmesh.key='.*'|uci -q set wireless.wmesh.key='$NEW_KEY'|g" "$TARGET_FILE"
  CHANGED=1
fi

if [[ "$CHANGED" -eq 1 ]]; then
  echo -e "${GREEN}Configuration updated successfully.${NC}"
else
  echo -e "${YELLOW}No changes were made (Values kept as is).${NC}"
fi
