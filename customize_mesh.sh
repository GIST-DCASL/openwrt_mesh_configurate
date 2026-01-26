#!/usr/bin/env bash
set -euo pipefail

# 기본 대상 파일 경로
DEFAULT_TARGET="./openwrt/files/etc/uci-defaults/98_network_custom_setting"

TARGET_FILE="$DEFAULT_TARGET"
NEW_IP=""
NEW_SSID=""
NEW_KEY=""

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 인자 파싱
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

# 파일 존재 확인
if [[ ! -f "$TARGET_FILE" ]]; then
  echo -e "${YELLOW}Error: Target file not found at: $TARGET_FILE${NC}"
  echo "Please check the path or use --target to specify the location."
  exit 1
fi

echo -e "${GREEN}Target File: $TARGET_FILE${NC}"

# 입력값이 하나도 없으면 대화형 모드로 전환
if [[ -z "$NEW_IP" ]] && [[ -z "$NEW_SSID" ]] && [[ -z "$NEW_KEY" ]]; then
  
  # --- [추가됨] 현재 값 읽어오기 로직 ---
  # grep으로 줄을 찾고, sed로 따옴표('') 사이의 값을 추출합니다.
  # "|| true"는 grep이 실패해도 스크립트가 멈추지 않게 합니다.
  
  # 1. Current IP (uci -q set network.meshif.ipaddr='xxx')
  CUR_IP=$(grep "network.meshif.ipaddr=" "$TARGET_FILE" | head -n 1 | sed -n "s/.*ipaddr='\([^']*\)'.*/\1/p" || true)
  
  # 2. Current SSID (uci -q set wireless.wmesh.mesh_id='xxx')
  CUR_SSID=$(grep "wireless.wmesh.mesh_id=" "$TARGET_FILE" | head -n 1 | sed -n "s/.*mesh_id='\([^']*\)'.*/\1/p" || true)
  
  # 3. Current Key (uci -q set wireless.wmesh.key='xxx')
  CUR_KEY=$(grep "wireless.wmesh.key=" "$TARGET_FILE" | head -n 1 | sed -n "s/.*key='\([^']*\)'.*/\1/p" || true)

  echo "------------------------------------------------"
  echo "Interactive Mode: Press Enter to keep the current value."
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

# 변경 사항 적용 (sed 사용)
CHANGED=0

# 1. IP 주소 변경
if [[ -n "$NEW_IP" ]]; then
  echo "Updating IP to: $NEW_IP"
  sed -i "s|uci -q set network.meshif.ipaddr='.*'|uci -q set network.meshif.ipaddr='$NEW_IP'|g" "$TARGET_FILE"
  CHANGED=1
fi

# 2. SSID (Mesh ID) 변경
if [[ -n "$NEW_SSID" ]]; then
  echo "Updating SSID to: $NEW_SSID"
  sed -i "s|uci -q set wireless.wmesh.mesh_id='.*'|uci -q set wireless.wmesh.mesh_id='$NEW_SSID'|g" "$TARGET_FILE"
  CHANGED=1
fi

# 3. Key (Password) 변경
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
