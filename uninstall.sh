#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== BMAD Uninstaller ===${NC}"

COMMAND_NAME="bmad-init"
CONFIG_FILE="$HOME/.bmad-init-rc"

read -p "Are you sure you want to uninstall Open BMAD IDE Scaffolder? (Y/n): " UNINSTALL_CONFIRM
UNINSTALL_CONFIRM=${UNINSTALL_CONFIRM:-Y}

if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
fi

# 1. Remove the CLI command from all possible installation paths
GLOBAL_DIR="${BMAD_DEST_DIR:-/usr/local/bin}"
LOCAL_DIR="${BMAD_LOCAL_DEST_DIR:-$HOME/.local/bin}"
PATHS_TO_CHECK=("$GLOBAL_DIR" "$LOCAL_DIR")
FOUND=false

for DEST_DIR in "${PATHS_TO_CHECK[@]}"; do
    if [ -f "$DEST_DIR/$COMMAND_NAME" ]; then
        FOUND=true
        echo -e "Removing $COMMAND_NAME from $DEST_DIR..."
        if [ -w "$DEST_DIR/$COMMAND_NAME" ] || [ -w "$DEST_DIR" ]; then
            rm -f "$DEST_DIR/$COMMAND_NAME"
        else
            echo -e "${YELLOW}Sudo privileges required to remove from $DEST_DIR.${NC}"
            sudo rm -f "$DEST_DIR/$COMMAND_NAME"
        fi
        
        if [ ! -f "$DEST_DIR/$COMMAND_NAME" ]; then
            echo -e "${GREEN}Successfully removed $COMMAND_NAME from $DEST_DIR.${NC}"
        else
            echo -e "${RED}Failed to remove $COMMAND_NAME from $DEST_DIR.${NC}"
        fi
    fi
done

if [ "$FOUND" = false ]; then
    echo -e "${YELLOW}$COMMAND_NAME not found in standard paths. Skipping.${NC}"
fi

# 2. Remove configuration file
if [ -f "$CONFIG_FILE" ]; then
    echo -e "Removing configuration file $CONFIG_FILE..."
    rm "$CONFIG_FILE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully removed $CONFIG_FILE.${NC}"
    else
        echo -e "${RED}Failed to remove $CONFIG_FILE.${NC}"
    fi
else
    echo -e "${YELLOW}Configuration file $CONFIG_FILE not found. Skipping.${NC}"
fi

echo -e "${BLUE}=== Uninstallation Complete! ===${NC}"
