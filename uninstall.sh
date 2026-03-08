#!/bin/bash

# ==============================================================================
# Script: uninstall.sh
# Purpose: Uninstalls the Open BMAD IDE Scaffolder.
#          - Prompts for confirmation before uninstallation.
#          - Removes the bmad-init executable from installed paths (global/local).
#          - Removes the user-specific configuration file (~/.bmad-init-rc).
# Usage: ./uninstall.sh
# ==============================================================================

# --- Console Color Definitions ---
# These variables define ANSI escape codes used to colorize the terminal output.
# Doing this makes messages much easier to read for the user.
GREEN='\033[0;32m'   # Used for success messages.
BLUE='\033[0;34m'    # Used for information highlights and headers.
RED='\033[0;31m'     # Used for error and failure messages.
YELLOW='\033[1;33m'  # Used for warnings or skipped actions.
NC='\033[0m'         # No Color (resets the terminal color back to default).

# Print a nice blue header so the user knows what script is running.
echo -e "${BLUE}=== BMAD Uninstaller ===${NC}"

# --- Global Variables ---
# COMMAND_NAME: The exact filename of the CLI tool to remove from the system.
COMMAND_NAME="bmad-init"
# CONFIG_FILE: The path to the user's saved configuration for the tool. Use $HOME for dynamic resolution.
CONFIG_FILE="$HOME/.bmad-init-rc"

# --- Confirmation Prompt ---
# Ask the user if they actually want to uninstall before we delete anything.
# 'read -p' presents the prompt and stores the user's input in UNINSTALL_CONFIRM.
read -p "Are you sure you want to uninstall Open BMAD IDE Scaffolder? (Y/n): " UNINSTALL_CONFIRM
# If the user just presses Enter, default to 'Y' (Yes).
UNINSTALL_CONFIRM=${UNINSTALL_CONFIRM:-Y}

# Validate user input using a Regular Expression (RegEx).
# '^[Yy]$' means: Does the variable equal exactly 'Y' or 'y'?
if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
    # If the user typed anything other than Y/y, we cancel the action.
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    # exit 0 means the script finished successfully (no error code), but stopped early.
    exit 0
fi

# ==============================================================================
# Step 1: Remove the CLI command from all possible installation paths
# ==============================================================================

# GLOBAL_DIR: Usually where macOS/Linux tools are installed globally, requiring Sudo.
# We respect the $BMAD_DEST_DIR environment variable if it's set (useful for tests), otherwise default to /usr/local/bin.
GLOBAL_DIR="${BMAD_DEST_DIR:-/usr/local/bin}"

# LOCAL_DIR: Usually where user-specific tools go, not requiring Sudo.
LOCAL_DIR="${BMAD_LOCAL_DEST_DIR:-$HOME/.local/bin}"

# Array holding all the paths we should look through.
PATHS_TO_CHECK=("$GLOBAL_DIR" "$LOCAL_DIR")

# FOUND: A tracking boolean to know if we actually found and tried to delete the file.
FOUND=false

# Loop through each path in our array.
for DEST_DIR in "${PATHS_TO_CHECK[@]}"; do
    # Check if a file (-f) exists in the current directory we are looking at.
    if [ -f "$DEST_DIR/$COMMAND_NAME" ]; then
        FOUND=true # We found it!
        echo -e "Removing $COMMAND_NAME from $DEST_DIR..."
        
        # Check if we have write access (-w) to this directory as the current user.
        if [ -w "$DEST_DIR" ]; then
            # We have permissions, delete forcefully (-f ignores nonexistent files and doesn't prompt).
            rm -f "$DEST_DIR/$COMMAND_NAME"
        else
            # We don't have permissions (likely because it's a global folder like /usr/local/bin).
            # We must use 'sudo' to elevate privileges and perform the deletion.
            echo -e "${YELLOW}Sudo privileges required to remove from $DEST_DIR.${NC}"
            sudo rm -f "$DEST_DIR/$COMMAND_NAME"
        fi
        
        # Verify if the deletion was actually successful.
        if [ ! -f "$DEST_DIR/$COMMAND_NAME" ]; then
            # File is gone -> Success
            echo -e "${GREEN}Successfully removed $COMMAND_NAME from $DEST_DIR.${NC}"
        else
            # File is still there -> Failure
            echo -e "${RED}Failed to remove $COMMAND_NAME from $DEST_DIR.${NC}"
        fi
    fi
done

# If the loop finished and FOUND is still false, it means bmad-init wasn't on the system.
if [ "$FOUND" = false ]; then
    echo -e "${YELLOW}$COMMAND_NAME not found in standard paths. Skipping.${NC}"
fi

# ==============================================================================
# Step 2: Remove the user-specific configuration file
# ==============================================================================

# Check if the config file exists on disk.
if [ -f "$CONFIG_FILE" ]; then
    echo -e "Removing configuration file $CONFIG_FILE..."
    # Attempt to delete the file.
    rm -f "$CONFIG_FILE"
    
    # Check the return code ($?) of the previous 'rm' command (0 = success).
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully removed $CONFIG_FILE.${NC}"
    else
        echo -e "${RED}Failed to remove $CONFIG_FILE.${NC}"
    fi
else
    # Config file wasn't there to begin with, no action needed.
    echo -e "${YELLOW}Configuration file $CONFIG_FILE not found. Skipping.${NC}"
fi

# Conclude the script with a nice footer.
echo -e "${BLUE}=== Uninstallation Complete! ===${NC}"
