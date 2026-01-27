#!/usr/bin/env bash
set -euo pipefail

# 1. WSL2 호환성: Windows 경로 공백 문제 방지를 위한 PATH 고정
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ==========================================
# [사용자 설정 영역]
# 아래 값을 입력하면 'customize_mesh.sh'가 자동으로 처리됩니다.
# 값을 비워두면("") 해당 단계에서 직접 입력(Interactive)해야 합니다.
MESH_IP="192.168.100.5"
MESH_SSID="your_ssid"
MESH_KEY="your_key"
# ==========================================

# 스크립트 파일명 정의 (파일 이름이 바뀌면 여기서 수정하세요)
SCRIPT_CLONE="./clone_openwrt22035_github.sh"
SCRIPT_CONFIG="./copy_config.sh"
SCRIPT_CUSTOM="./customize_mesh.sh"
SCRIPT_BUILD="./build_firmware.sh"

# 색상 코드
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${BLUE}[Master Script] $1${NC}"
}

# 0. 실행 권한 부여 (혹시 모르니 실행 전 권한 확인)
chmod +x "$SCRIPT_CLONE" "$SCRIPT_CONFIG" "$SCRIPT_CUSTOM" "$SCRIPT_BUILD"

# ---------------------------------------------------------
# Step 1: OpenWrt 소스 다운로드 (폴더가 있으면 생략)
# ---------------------------------------------------------
if [ -d "openwrt" ]; then
  log "Step 1: 'openwrt' folder exists. Skipping clone/download."
else
  log "Step 1: Cloning OpenWrt..."
  "$SCRIPT_CLONE"
fi

# ---------------------------------------------------------
# Step 2: Config 및 Files 복사
# ---------------------------------------------------------
log "Step 2: Applying config and file overlays..."
"$SCRIPT_CONFIG"

# ---------------------------------------------------------
# Step 3: Mesh 네트워크 정보 커스터마이징
# ---------------------------------------------------------
log "Step 3: Customizing Mesh settings..."

# 변수가 설정되어 있으면 인자로 전달, 아니면 인자 없이 실행(대화형 모드 진입)
CMD_ARGS=""
if [ -n "$MESH_IP" ];   then CMD_ARGS="$CMD_ARGS --ip $MESH_IP"; fi
if [ -n "$MESH_SSID" ]; then CMD_ARGS="$CMD_ARGS --ssid $MESH_SSID"; fi
if [ -n "$MESH_KEY" ];  then CMD_ARGS="$CMD_ARGS --key $MESH_KEY"; fi

if [ -n "$CMD_ARGS" ]; then
  # 변수 내용을 그대로 전달하기 위해 eval 혹은 그대로 실행
  "$SCRIPT_CUSTOM" $CMD_ARGS
else
  # 설정된 변수가 없으면 대화형 모드 실행
  "$SCRIPT_CUSTOM"
fi

# ---------------------------------------------------------
# Step 4: 펌웨어 빌드 및 결과물 이동
# ---------------------------------------------------------
log "Step 4: Building firmware (This may take a while)..."
"$SCRIPT_BUILD"

log "All steps completed successfully!"
