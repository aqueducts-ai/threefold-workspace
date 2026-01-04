#!/bin/bash
#
# LLM Workspace - Quick Install Script
# https://github.com/threefold/threefold-workspace
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/threefold/threefold-workspace/main/install.sh | bash
#
# Or clone and run:
#   git clone https://github.com/threefold/threefold-workspace.git
#   cd threefold-workspace && ./install.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║     LLM WORKSPACE INSTALLER           ║"
echo "  ║     Multi-pane AI Development         ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Check dependencies
echo -e "${CYAN}Checking dependencies...${NC}"

check_dep() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 (required)"
        return 1
    fi
}

check_optional() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1"
    else
        echo -e "  ${YELLOW}○${NC} $1 (optional - $2)"
    fi
}

DEPS_OK=true

check_dep "tmux" || DEPS_OK=false
check_dep "git" || DEPS_OK=false
check_dep "bash" || DEPS_OK=false
check_optional "jq" "enhanced JSON parsing"
check_optional "node" "usage monitoring"
check_optional "gh" "GitHub PR integration"

if [ "$DEPS_OK" = false ]; then
    echo ""
    echo -e "${RED}Missing required dependencies. Please install them first.${NC}"
    exit 1
fi

echo ""

# Determine install location
INSTALL_DIR="${LLM_WORKSPACE_DIR:-$HOME/.llm-workspace}"

# Check if we're running from a cloned repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/bin/workspace" ]; then
    # Running from cloned repo - use it directly
    INSTALL_DIR="$SCRIPT_DIR"
    echo -e "${GREEN}Installing from local clone: $INSTALL_DIR${NC}"
else
    # Clone the repo
    echo -e "${CYAN}Cloning repository to $INSTALL_DIR...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Directory exists. Updating...${NC}"
        cd "$INSTALL_DIR"
        git pull origin main
    else
        git clone https://github.com/threefold/threefold-workspace.git "$INSTALL_DIR"
    fi
fi

echo ""

# Run setup
echo -e "${CYAN}Running setup...${NC}"
"$INSTALL_DIR/bin/workspace" --setup

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo -e "Quick start:"
echo -e "  ${CYAN}source ~/.zshrc${NC}  (or ~/.bashrc)"
echo -e "  ${CYAN}ws${NC}               Start workspace"
echo ""
echo -e "Commands:"
echo -e "  ${CYAN}ws${NC}               Attach or start workspace"
echo -e "  ${CYAN}ws-fresh${NC}         Re-select worktrees"
echo -e "  ${CYAN}workspace --help${NC} Show all options"
echo ""
