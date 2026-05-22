#!/bin/bash
#
# WordPress Development Skills Installer
# Works with Claude Code, Codex CLI, Gemini CLI, and GitHub Copilot CLI.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/salemaziel/wordpress-dev-skills/main/install.sh | bash
#   ./install.sh [--tool claude|codex|gemini|copilot] [--skills-dir /path] [--symlink]
#
# Tool defaults (override with --skills-dir):
#   claude  → ~/.claude/skills/wordpress-dev-skills
#   codex   → ~/.codex/skills/wordpress-dev-skills
#   gemini  → ~/.gemini/extensions/wordpress-dev-skills
#   copilot → ~/.github-copilot/plugins/wordpress-dev-skills

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/salemaziel/wordpress-dev-skills.git"
PLUGIN_NAME="wordpress-dev-skills"

# Parse arguments
USE_SYMLINK=false
TOOL="claude"
SKILLS_DIR=""   # set after --tool is parsed

while [[ $# -gt 0 ]]; do
    case $1 in
        --symlink)
            USE_SYMLINK=true
            shift
            ;;
        --tool)
            TOOL="$2"
            shift 2
            ;;
        --skills-dir)
            SKILLS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            cat <<EOF
WordPress Development Skills Installer
Works with Claude Code, Codex CLI, Gemini CLI, and GitHub Copilot CLI.

Usage: ./install.sh [options]

Options:
  --tool TOOL        Target AI tool: claude (default), codex, gemini, copilot
  --skills-dir PATH  Override install path (default depends on --tool)
  --symlink          Symlink individual skills instead of copying
  -h, --help         Show this help message

Tool defaults:
  claude  → ~/.claude/skills/wordpress-dev-skills
  codex   → ~/.codex/skills/wordpress-dev-skills
  gemini  → ~/.gemini/extensions/wordpress-dev-skills
  copilot → ~/.github-copilot/plugins/wordpress-dev-skills

Override with WP_SKILLS_ROOT env var (sets skills dir) or --skills-dir.
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Resolve default install dir based on tool (can be overridden by WP_SKILLS_ROOT or --skills-dir)
if [ -z "$SKILLS_DIR" ] && [ -n "${WP_SKILLS_ROOT:-}" ]; then
    SKILLS_DIR="$WP_SKILLS_ROOT"
fi
if [ -z "$SKILLS_DIR" ]; then
    case "$TOOL" in
        claude)  SKILLS_DIR="$HOME/.claude/skills" ;;
        codex)   SKILLS_DIR="$HOME/.codex/skills" ;;
        gemini)  SKILLS_DIR="$HOME/.gemini/extensions" ;;
        copilot) SKILLS_DIR="$HOME/.github-copilot/plugins" ;;
        *)
            echo -e "${RED}Unknown --tool: $TOOL. Use: claude, codex, gemini, copilot${NC}"
            exit 1
            ;;
    esac
fi

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}WordPress Dev Skills Installer${NC}"
echo -e "${BLUE}  Tool: $TOOL${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed${NC}"
    exit 1
fi

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Warning: Python 3 not found. Some skills may not work.${NC}"
fi

# Create skills directory if it doesn't exist
echo -e "${YELLOW}Creating skills directory...${NC}"
mkdir -p "$SKILLS_DIR"

# Clone or update repository
INSTALL_DIR="$SKILLS_DIR/$PLUGIN_NAME"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Updating existing installation...${NC}"
    cd "$INSTALL_DIR"
    git pull origin main
else
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Handle symlinks if requested
if [ "$USE_SYMLINK" = true ]; then
    echo -e "${YELLOW}Creating symlinks for individual skills...${NC}"

    SKILLS=(
        "wordpress-dev"
        "wordpress-admin"
        "seo-optimizer"
        "visual-qa"
        "brand-guide"
    )

    for skill in "${SKILLS[@]}"; do
        SKILL_PATH="$INSTALL_DIR/skills/$skill"
        LINK_PATH="$SKILLS_DIR/$skill"

        if [ -d "$SKILL_PATH" ]; then
            # Remove existing symlink or directory
            if [ -L "$LINK_PATH" ]; then
                rm "$LINK_PATH"
            fi

            # Create symlink
            ln -s "$SKILL_PATH" "$LINK_PATH"
            echo -e "  ${GREEN}✓${NC} Linked $skill"
        else
            echo -e "  ${YELLOW}⚠${NC} Skill not found: $skill"
        fi
    done
fi

# Install Python dependencies if Python is available
if command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Installing Python dependencies...${NC}"

    # Check for pip
    if command -v pip3 &> /dev/null; then
        pip3 install playwright --quiet 2>/dev/null || true

        # Install Playwright browsers
        if python3 -c "import playwright" 2>/dev/null; then
            python3 -m playwright install chromium --quiet 2>/dev/null || true
            echo -e "  ${GREEN}✓${NC} Playwright installed"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} pip3 not found, skipping Python dependencies"
    fi
fi

# Summary
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Skills installed to: ${BLUE}$INSTALL_DIR${NC}"
echo ""
echo "Available skills:"
echo "  - wordpress-dev     : Development best practices"
echo "  - wordpress-admin   : Site management"
echo "  - seo-optimizer     : SEO audit & optimization"
echo "  - visual-qa         : Screenshot testing"
echo "  - brand-guide       : Brand documentation"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
case "$TOOL" in
    claude)
        echo "  1. Open Claude Code"
        echo "  2. Ask: 'Set up a WordPress Docker environment'"
        echo "  3. Or run: /wp-setup"
        ;;
    codex)
        echo "  1. Open Codex CLI"
        echo "  2. Load the plugin: codex --plugin $INSTALL_DIR/.codex-plugin/plugin.json"
        echo "  3. Ask: 'Set up a WordPress Docker environment'"
        ;;
    gemini)
        echo "  1. Open Gemini CLI"
        echo "  2. The extension is registered at: $INSTALL_DIR/gemini-extension.json"
        echo "  3. Ask: 'Set up a WordPress Docker environment'"
        ;;
    copilot)
        echo "  1. Open GitHub Copilot CLI"
        echo "  2. Plugin metadata is at: $INSTALL_DIR/.github/plugin/marketplace.json"
        echo "  3. Ask: 'Set up a WordPress Docker environment'"
        ;;
esac
echo ""
echo -e "${GREEN}Happy coding!${NC}"
