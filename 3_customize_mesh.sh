#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TARGET="./openwrt/files/etc/uci-defaults/95_network_custom_setting"

TARGET_FILE="$DEFAULT_TARGET"
NEW_IP=""
NEW_SSID=""
NEW_KEY=""
NEW_HOSTNAME=""

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
  --hostname <name>   Set System Hostname
  --target <file>     Path to the target file (default: $DEFAULT_TARGET)
  -h, --help          Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ip) NEW_IP="$2"; shift 2 ;;
    --ssid) NEW_SSID="$2"; shift 2 ;;
    --key) NEW_KEY="$2"; shift 2 ;;
    --hostname) NEW_HOSTNAME="$2"; shift 2 ;;
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

if [[ -z "$NEW_IP" ]] && [[ -z "$NEW_SSID" ]] && [[ -z "$NEW_KEY" ]] && [[ -z "$NEW_HOSTNAME" ]]; then
  
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

  # =================================================================
  # Hostname Failsafe 및 자동 생성 로직
  # =================================================================
  if grep -q "^TARGET_HOSTNAME=" "$TARGET_FILE"; then
    read -p "Do you want to configure the Hostname? (y/N): " CONF_HOST
    if [[ "$CONF_HOST" =~ ^[Yy]$ ]]; then
      
      CUR_HOSTNAME=$(grep "^TARGET_HOSTNAME=" "$TARGET_FILE" | head -n 1 | sed -n 's/.*TARGET_HOSTNAME="\([^"]*\)".*/\1/p' || true)
      CUR_BRIDGE=$(grep "^is_bridge=" "$TARGET_FILE" | head -n 1 | sed -n 's/.*is_bridge=\([0-9]\).*/\1/p' || true)
      
      # 방금 입력한 IP가 있으면 사용, 없으면 기존 IP 사용
      FINAL_IP="${NEW_IP:-$CUR_IP}"
      
      # 모드 문자열 결정 (Bridge=1 이면 bridge, 아니면 server)
      USE_BRIDGE="${CUR_BRIDGE:-0}"
      if [[ "$USE_BRIDGE" == "1" ]]; then
          MODE_STR="bridge"
      else
          MODE_STR="server"
      fi

      # IP에서 마지막 옥텟 추출 (예: 192.168.100.2 -> 2)
      LAST_OCTET=$(echo "$FINAL_IP" | awk -F. '{print $4}')
      
      # 추천 호스트 네임 생성 로직 (RFC 표준에 맞춰 언더스코어(_)를 하이픈(-)으로 변경)
      if [[ -z "$LAST_OCTET" ]]; then
          SUGGESTED_HOSTNAME="dcas-adhoc-${MODE_STR}"
      else
          SUGGESTED_HOSTNAME="dcas-${MODE_STR}-${LAST_OCTET}"
      fi
      echo ""
      echo -e "Current Hostname:   ${BLUE}${CUR_HOSTNAME:-Unknown}${NC}"
      echo -e "Suggested Hostname: ${GREEN}${SUGGESTED_HOSTNAME}${NC}"
      read -p "Enter New Hostname (Press Enter to use suggested): " INPUT_HOSTNAME
      
      if [[ -n "$INPUT_HOSTNAME" ]]; then
        NEW_HOSTNAME="$INPUT_HOSTNAME"
      else
        NEW_HOSTNAME="$SUGGESTED_HOSTNAME"
      fi
    fi
  fi
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

if [[ -n "${NEW_HOSTNAME:-}" ]]; then
  echo "Updating Hostname to: $NEW_HOSTNAME"
  sed -i "s|^TARGET_HOSTNAME=\".*\"|TARGET_HOSTNAME=\"$NEW_HOSTNAME\"|g" "$TARGET_FILE"
  CHANGED=1
fi

if [[ "$CHANGED" -eq 1 ]]; then
  echo -e "${GREEN}Configuration updated successfully.${NC}"
else
  echo -e "${YELLOW}No changes were made (Values kept as is).${NC}"
fi
