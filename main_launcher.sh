#!/usr/bin/env bash
set -euo pipefail

# For WSL 2
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ==========================================
MESH_IP="192.168.100.5"
MESH_SSID="your_ssid"
MESH_KEY="your_key"



SCRIPT_CLONE="./clone_openwrt22035_github.sh"
SCRIPT_CONFIG="./copy_config.sh"
SCRIPT_CUSTOM="./customize_mesh.sh"
SCRIPT_BUILD="./build_firmware.sh"


GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${BLUE}[Master Script] $1${NC}"
}


chmod +x "$SCRIPT_CLONE" "$SCRIPT_CONFIG" "$SCRIPT_CUSTOM" "$SCRIPT_BUILD"

log "Downloading Openwrt... Checking Openwrt exist."

if [ -d "openwrt" ]; then
  log "'openwrt' folder exists. Skipping clone/download."
else
  log "Cloning OpenWrt..."
  "$SCRIPT_CLONE"
fi


log "Applying config and file overlays..."
"$SCRIPT_CONFIG"


log "Customizing Mesh settings..."

CMD_ARGS=""
if [ -n "$MESH_IP" ];   then CMD_ARGS="$CMD_ARGS --ip $MESH_IP"; fi
if [ -n "$MESH_SSID" ]; then CMD_ARGS="$CMD_ARGS --ssid $MESH_SSID"; fi
if [ -n "$MESH_KEY" ];  then CMD_ARGS="$CMD_ARGS --key $MESH_KEY"; fi

if [ -n "$CMD_ARGS" ]; then

  "$SCRIPT_CUSTOM" $CMD_ARGS
else
  "$SCRIPT_CUSTOM"
fi

log "Building firmware (This may take a while)..."
"$SCRIPT_BUILD"

log "All steps completed successfully!"
