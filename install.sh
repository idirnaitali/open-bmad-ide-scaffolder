#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Open BMAD IDE Scaffolder - Installer ===${NC}"

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_FILE="$SCRIPT_DIR/bmad-init"
COMMAND_NAME="bmad-init"

if [ ! -f "$SRC_FILE" ]; then
    echo -e "${RED}Error: Cannot find $SRC_FILE in the current directory.${NC}"
    exit 1
fi

DEST_DIR="${BMAD_DEST_DIR:-/usr/local/bin}"
LOCAL_DEST_DIR="${BMAD_LOCAL_DEST_DIR:-$HOME/.local/bin}"

install_to() {
    local dest=$1
    local use_sudo=$2
    echo "Attempting to install to $dest..."
    if [ "$use_sudo" = "yes" ]; then
        sudo mkdir -p "$dest"
        sudo cp "$SRC_FILE" "$dest/$COMMAND_NAME"
        sudo chmod +x "$dest/$COMMAND_NAME"
    else
        mkdir -p "$dest"
        cp "$SRC_FILE" "$dest/$COMMAND_NAME"
        chmod +x "$dest/$COMMAND_NAME"
    fi
}

# Optional Pre-configuration
echo -e "\n${BLUE}--- Pre-configuration ---${NC}"
read -p "Do you want to pre-configure bmad-init defaults now? (Y/n): " PRECONF
PRECONF=${PRECONF:-Y}

if [[ "$PRECONF" =~ ^[Yy]$ ]]; then
    echo -e "Available tools: ${GREEN}antigravity, roo-cline, cursor, windsurf, copilot${NC}"
    echo -e "Refer to ${BLUE}https://docs.bmad-method.org/${NC} for more details."
    read -p "Default tools (comma separated) [antigravity]: " DEF_TOOLS
    DEF_TOOLS=${DEF_TOOLS:-antigravity}
    read -p "Auto initialize Git? (Y/n) [Y]: " DEF_GIT_INIT
    DEF_GIT_INIT=${DEF_GIT_INIT:-Y}
    read -p "Auto add BMAD to .gitignore? (Y/n) [Y]: " DEF_GIT_IGNORE
    DEF_GIT_IGNORE=${DEF_GIT_IGNORE:-Y}
    
    # Save configuration securely
    CONFIG_FILE="$HOME/.bmad-init-rc"
    {
        printf "BMAD_TOOLS=%q\n" "$DEF_TOOLS"
        printf "AUTO_GIT_INIT=%q\n" "$DEF_GIT_INIT"
        printf "AUTO_GIT_IGNORE=%q\n" "$DEF_GIT_IGNORE"
    } > "$CONFIG_FILE"
    echo -e "${GREEN}Default configuration saved to $CONFIG_FILE${NC}"
else
    echo -e "${YELLOW}Skipping pre-configuration. bmad-init will use standard defaults.${NC}"
    rm -f "$HOME/.bmad-init-rc"
fi

echo -e "\n${BLUE}--- Installing CLI ---${NC}"
echo -e "Installing bmad-init to your system..."

# If user can write to DEST_DIR without sudo, do it. Usually on macOS Homebrew setups.
if [ -w "$DEST_DIR" ]; then
    install_to "$DEST_DIR" "no"
else
    # Prefer LOCAL_DEST_DIR to avoid sudo whenever possible for open source devs
    if [ -d "$LOCAL_DEST_DIR" ] || mkdir -p "$LOCAL_DEST_DIR" 2>/dev/null; then
        install_to "$LOCAL_DEST_DIR" "no"
        if [ $? -eq 0 ]; then
            echo -e "${YELLOW}Note: Make sure $LOCAL_DEST_DIR is in your system \$PATH.${NC}"
            DEST_DIR=$LOCAL_DEST_DIR
        fi
    else
        # Fallback to global with sudo
        echo -e "${YELLOW}Sudo is required to install globally into $DEST_DIR.${NC}"
        install_to "$DEST_DIR" "yes"
    fi
fi

if command -v $COMMAND_NAME >/dev/null 2>&1 || [ -f "$DEST_DIR/$COMMAND_NAME" ]; then
    echo -e "\n${GREEN}=== Installation Complete! ===${NC}"
    echo -e "You can now run '${COMMAND_NAME}' in any of your projects."
    echo -e "Run '${COMMAND_NAME} --help' to see all available options."
else
    echo -e "${RED}Installation failed.${NC}"
    exit 1
fi
