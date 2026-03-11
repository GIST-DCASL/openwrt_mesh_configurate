#!/usr/bin/env bash
set -euo pipefail

# 스크립트가 실행되는 현재 디렉토리 기준
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(dirname "$SCRIPT_DIR")"
DEST_FILE="${TARGET_DIR}/diffconfig"


shopt -s nullglob
CONFIG_FILES=( "${SCRIPT_DIR}"/diffconfig_* )
shopt -u nullglob

if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
    echo -e "\033[0;31mError:\033[0m No 'diffconfig_*' files found in ${SCRIPT_DIR}"
    exit 1
fi

echo -e "\033[0;32mAvailable diffconfig files:\033[0m"

PS3="Select a diffconfig file (enter the number): "

select FILE_PATH in "${CONFIG_FILES[@]}"; do
    if [[ -n "$FILE_PATH" ]]; then
        FILENAME=$(basename "$FILE_PATH")
        echo "Selected: $FILENAME"
        
        cp "$FILE_PATH" "$DEST_FILE"
        
        echo -e "\033[1;33mSuccess:\033[0m Copied $FILENAME to $DEST_FILE"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done
