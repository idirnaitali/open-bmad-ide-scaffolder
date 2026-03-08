#!/bin/bash

# ==============================================================================
# Script: install.sh
# Purpose: Installs the Open BMAD IDE Scaffolder CLI tool on the system.
#          - Guides the user through pre-configuration options (defaults, tools).
#          - Saves the configuration securely in ~/.bmad-init-rc.
#          - Installs the bmad-init script to the system path handling permissions.
# Usage: ./install.sh
# ==============================================================================

# --- Console Color Definitions ---
# These variables define ANSI escape codes used to colorize the terminal output.
GREEN='\033[0;32m'   # Success/highlight colors
BLUE='\033[0;34m'    # Headers and information
RED='\033[0;31m'     # Error/failure messages
YELLOW='\033[1;33m'  # Warnings or notes
NC='\033[0m'         # No Color (resets terminal color)

# Display a welcome header
echo -e "${BLUE}=== Open BMAD IDE Scaffolder - Installer ===${NC}"

# --- Setup Paths ---
# SCRIPT_DIR: Determines the absolute folder path where this installer script is located.
# The `cd dirname ...` and `pwd` ensures this works even if called from another folder.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# SRC_FILE: The absolute path to the 'bmad-init' script we want to copy/install.
SRC_FILE="$SCRIPT_DIR/bmad-init"

# COMMAND_NAME: The name the command will have once installed on the user's system.
COMMAND_NAME="bmad-init"

# Check if the source executable script actually exists before we even try.
if [ ! -f "$SRC_FILE" ]; then
    echo -e "${RED}Error: Cannot find $SRC_FILE in the current directory.${NC}"
    # Error code 1 means standard failure.
    exit 1
fi

# --- Target Installation Paths ---
# DEST_DIR: Where global tools go. We use the environment variable $BMAD_DEST_DIR if available (for tests).
DEST_DIR="${BMAD_DEST_DIR:-/usr/local/bin}"

# LOCAL_DEST_DIR: Local user bin directory. We prefer this to avoid Sudo usage.
LOCAL_DEST_DIR="${BMAD_LOCAL_DEST_DIR:-$HOME/.local/bin}"

# --- Helper Function: install_to ---
# A reusable block of code to handle creating directories, copying files, and setting permissions.
# Arguments:
#   $1: The destination folder path
#   $2: A string 'yes' or 'no' indicating if 'sudo' is required
install_to() {
    local dest=$1
    local use_sudo=$2
    
    echo "Attempting to install to $dest..."
    
    # If sudo is requested by the caller, do all steps using 'sudo'
    if [ "$use_sudo" = "yes" ]; then
        # 1. Create directory structure (-p ignores if it exists, creates parents if needed).
        # 2. Copy the file. 
        # 3. Add execute (+x) permissions to the new copy.
        if sudo mkdir -p "$dest" && sudo cp "$SRC_FILE" "$dest/$COMMAND_NAME" && sudo chmod +x "$dest/$COMMAND_NAME"; then
            return 0 # Success
        else
            echo -e "${RED}Error: Failed to install to $dest using sudo.${NC}"
            return 1 # Failure
        fi
    else
        # Perform the exact same steps but without 'sudo'
        if mkdir -p "$dest" && cp "$SRC_FILE" "$dest/$COMMAND_NAME" && chmod +x "$dest/$COMMAND_NAME"; then
            return 0 # Success
        else
            echo -e "${RED}Error: Failed to install to $dest.${NC}"
            return 1 # Failure
        fi
    fi
}

# ==============================================================================
# Step 1: Optional Pre-configuration
# ==============================================================================
echo -e "\n${BLUE}--- Pre-configuration ---${NC}"

# Ask if they want to setup default values now. So they don't have to provide them every time they run `bmad-init`.
read -p "Do you want to pre-configure bmad-init defaults now? (Y/n): " PRECONF
# Default to Y (Yes) if they press Enter.
PRECONF=${PRECONF:-Y}

# If user agreed to pre-configure (RegEx checks for Y or y).
if [[ "$PRECONF" =~ ^[Yy]$ ]]; then
    # Inform the user about the available modules/tools.
    echo -e "Available tools: ${GREEN}antigravity, roo-cline, cursor, windsurf, copilot${NC}"
    echo -e "Refer to ${BLUE}https://docs.bmad-method.org/${NC} for more details."
    
    # Collect preferences and provide defaults.
    read -p "Default tools (comma separated) [antigravity]: " DEF_TOOLS
    DEF_TOOLS=${DEF_TOOLS:-antigravity} # Default: antigravity
    
    read -p "Auto initialize Git? (Y/n) [Y]: " DEF_GIT_INIT
    DEF_GIT_INIT=${DEF_GIT_INIT:-Y} # Default: Yes
    
    read -p "Auto add BMAD to .gitignore? (Y/n) [Y]: " DEF_GIT_IGNORE
    DEF_GIT_IGNORE=${DEF_GIT_IGNORE:-Y} # Default: Yes
    
    # Define the config file location in the user's home directory.
    CONFIG_FILE="$HOME/.bmad-init-rc"
    
    # Write the collected variables into the config file.
    # We use a code block {} > to output all lines into the file in one operation safely.
    {
        printf "BMAD_TOOLS=%s\n" "$DEF_TOOLS"
        printf "AUTO_GIT_INIT=%s\n" "$DEF_GIT_INIT"
        printf "AUTO_GIT_IGNORE=%s\n" "$DEF_GIT_IGNORE"
    } > "$CONFIG_FILE"
    
    echo -e "${GREEN}Default configuration saved to $CONFIG_FILE${NC}"
else
    # User decided not to configure.
    echo -e "${YELLOW}Skipping pre-configuration. bmad-init will use standard defaults.${NC}"
    # Delete any old configuration files just in case.
    rm -f "$HOME/.bmad-init-rc"
fi

# ==============================================================================
# Step 2: System Installation
# ==============================================================================
echo -e "\n${BLUE}--- Installing CLI ---${NC}"
echo -e "Installing bmad-init to your system..."

# First check: Can the regular user write to the global directory? (Often true for Homebrew on Mac).
if [ -w "$DEST_DIR" ]; then
    install_to "$DEST_DIR" "no"
else
    # Option 2: Attempt local installation without sudo (preferred for isolated environments/open source).
    if [ -d "$LOCAL_DEST_DIR" ] || mkdir -p "$LOCAL_DEST_DIR" 2>/dev/null; then
        install_to "$LOCAL_DEST_DIR" "no"
        if [ $? -eq 0 ]; then # If install_to succeeded
            # Inform the user that they must make sure the local bin folder is in their PATH for the command to work.
            echo -e "${YELLOW}Note: Make sure $LOCAL_DEST_DIR is in your system \$PATH.${NC}"
            # Reassign DEST_DIR so the validation check later verifies the right location.
            DEST_DIR=$LOCAL_DEST_DIR
        fi
    else
        # Fallback Option 3: Local directory inaccessible, must use Sudo to put in Global directory.
        echo -e "${YELLOW}Sudo is required to install globally into $DEST_DIR.${NC}"
        install_to "$DEST_DIR" "yes"
    fi
fi

# ==============================================================================
# Step 3: Validation
# ==============================================================================

# Verify the installation was successful.
# Check 1: `command -v` returns true if the command can be run normally from the exact current shell path.
# Check 2: Check if the file physically exists exactly where we put it.
if command -v $COMMAND_NAME >/dev/null 2>&1 || [ -f "$DEST_DIR/$COMMAND_NAME" ]; then
    echo -e "\n${GREEN}=== Installation Complete! ===${NC}"
    echo -e "You can now run '${COMMAND_NAME}' in any of your projects."
    echo -e "Run '${COMMAND_NAME} --help' to see all available options."
else
    # Something broke.
    echo -e "${RED}Installation failed.${NC}"
    exit 1
fi
