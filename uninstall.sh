#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== BMAD Uninstaller ===${NC}"

DEST_DIR="/usr/local/bin"
COMMAND_NAME="bmad-init"
CONFIG_FILE="$HOME/.bmad-init-rc"

read -p "Are you sure you want to uninstall BMAD Initializer? (Y/n): " UNINSTALL_CONFIRM
UNINSTALL_CONFIRM=${UNINSTALL_CONFIRM:-Y}

if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
fi

# 1. Remove the CLI command
if [ -f "$DEST_DIR/$COMMAND_NAME" ]; then
    echo -e "Removing $COMMAND_NAME from $DEST_DIR..."
    if [ -w "$DEST_DIR" ]; then
        rm "$DEST_DIR/$COMMAND_NAME"
    else
        echo -e "${YELLOW}Sudo privileges required to remove from $DEST_DIR.${NC}"
        sudo rm "$DEST_DIR/$COMMAND_NAME"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully removed $COMMAND_NAME.${NC}"
    else
        echo -e "${RED}Failed to remove $COMMAND_NAME.${NC}"
    fi
else
    echo -e "${YELLOW}$COMMAND_NAME not found in $DEST_DIR. Skipping.${NC}"
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
