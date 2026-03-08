#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Interactive BMAD Installer ===${NC}"

# Check and offer to install prerequisites
install_prereqs() {
    if ! command -v node &> /dev/null || ! command -v npx &> /dev/null; then
        echo -e "${YELLOW}Node.js and npx are not installed.${NC}"
        read -p "Do you want to try installing them now? (Y/n): " INSTALL_NODE
        INSTALL_NODE=${INSTALL_NODE:-Y}
        if [[ "$INSTALL_NODE" =~ ^[Yy]$ ]]; then
            if command -v brew &> /dev/null; then
                brew install node
            elif command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y nodejs npm
            else
                echo -e "${RED}Could not find brew or apt-get. Please install Node.js manually: https://nodejs.org/${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Node.js is required to use BMAD. Exiting.${NC}"
            exit 1
        fi
    fi

    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git is not installed.${NC}"
        read -p "Do you want to try installing Git now? (Y/n): " INSTALL_GIT
        INSTALL_GIT=${INSTALL_GIT:-Y}
        if [[ "$INSTALL_GIT" =~ ^[Yy]$ ]]; then
            if command -v brew &> /dev/null; then
                brew install git
            elif command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y git
            else
                echo -e "${RED}Could not find brew or apt-get. Please install Git manually.${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Git is not installed. Some Git-related features will be disabled.${NC}"
        fi
    fi
}

install_prereqs

echo -e "\n${BLUE}--- Configuration ---${NC}"

# 1. Tools
echo -e "${YELLOW}Available BMAD tools:${NC}"
echo -e "  - ${GREEN}antigravity${NC} (default)"
echo -e "  - ${GREEN}roo-cline${NC}"
echo -e "  - ${GREEN}cursor${NC}"
echo -e "  - ${GREEN}windsurf${NC}"
echo -e "  - ${GREEN}copilot${NC}"
read -p "Which tools do you want to install with BMAD? (comma separated, default: antigravity): " BMAD_TOOLS
BMAD_TOOLS=${BMAD_TOOLS:-antigravity}

# 2. Git Init
read -p "Should bmad-init automatically initialize a git repository? (Y/n): " AUTO_GIT_INIT
AUTO_GIT_INIT=${AUTO_GIT_INIT:-Y}

# 3 & 4. Git Identity (only if Git Init is yes)
if [[ "$AUTO_GIT_INIT" =~ ^[Yy]$ ]]; then
    CURRENT_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
    if [ -n "$CURRENT_GIT_NAME" ]; then
        read -p "Git user.name (default: $CURRENT_GIT_NAME): " GIT_NAME
        GIT_NAME=${GIT_NAME:-$CURRENT_GIT_NAME}
    else
        read -p "Git user.name: " GIT_NAME
    fi

    CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
    if [ -n "$CURRENT_GIT_EMAIL" ]; then
        read -p "Git user.email (default: $CURRENT_GIT_EMAIL): " GIT_EMAIL
        GIT_EMAIL=${GIT_EMAIL:-$CURRENT_GIT_EMAIL}
    else
        read -p "Git user.email: " GIT_EMAIL
    fi
fi

# Save configuration securely
CONFIG_FILE="$HOME/.bmad-init-rc"
{
    printf "BMAD_TOOLS=%q\n" "$BMAD_TOOLS"
    printf "AUTO_GIT_INIT=%q\n" "$AUTO_GIT_INIT"
    printf "GIT_NAME=%q\n" "$GIT_NAME"
    printf "GIT_EMAIL=%q\n" "$GIT_EMAIL"
} > "$CONFIG_FILE"

echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"

echo -e "\n${BLUE}--- Installing bmad-init CLI ---${NC}"
# Get the directory where install.sh is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_FILE="$SCRIPT_DIR/bmad-init"

if [ ! -f "$SRC_FILE" ]; then
    echo -e "${RED}Error: Cannot find $SRC_FILE in the current directory.${NC}"
    exit 1
fi

DEST_DIR="/usr/local/bin"
COMMAND_NAME="bmad-init"

echo -e "To install the command to $DEST_DIR, we may need sudo privileges."
sudo cp "$SRC_FILE" "$DEST_DIR/$COMMAND_NAME"
sudo chmod +x "$DEST_DIR/$COMMAND_NAME"

if [ $? -eq 0 ]; then
    echo -e "${BLUE}=== Installation Complete! ===${NC}"
    echo -e "You can now run '${COMMAND_NAME}' in any project directory to initialize BMAD."
else
    echo -e "${RED}Installation to $DEST_DIR failed. Please check permissions.${NC}"
fi
