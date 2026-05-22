#!/usr/bin/env bash
# wp-session-init.sh
# WordPress session initialization hook for Claude Code.
#
# Automatically detects the WordPress environment at the start of each session
# and prints useful context so the AI assistant knows which tools are available.
#
# This hook runs when Claude Code starts a session in a directory that contains
# WordPress or this skills package.
#
# To register with Claude Code:
#   1. Copy to ~/.claude/hooks/wp-session-init.sh  (or symlink from there)
#   2. Or reference it from your CLAUDE.md: "Run hooks/wp-session-init.sh on session start"

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  WordPress Dev Skills — Session Init${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─── Locate skills directory ──────────────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="${WP_SKILLS_ROOT:-$(cd "$HOOK_DIR/.." && pwd)}"

echo -e "${BLUE}Skills directory:${NC} $SKILLS_ROOT"
echo ""

# ─── Detect WordPress environment ─────────────────────────────────────────────
echo -e "${YELLOW}Detecting WordPress environment...${NC}"

WP_ENV="none"
WP_CONTAINER=""
WP_URL=""

# 1. Docker WordPress
if command -v docker &>/dev/null; then
  RUNNING_WP=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i wordpress | grep -iv "db\|database\|maria\|mysql" | head -1 || true)
  if [ -n "$RUNNING_WP" ]; then
    WP_ENV="docker"
    WP_CONTAINER="$RUNNING_WP"
    echo -e "  ${GREEN}✓${NC} Docker WordPress detected"
    echo -e "     Container: ${GREEN}$WP_CONTAINER${NC}"

    # Try to get site URL from WP-CLI
    WP_URL=$(docker exec "$WP_CONTAINER" wp option get siteurl --allow-root 2>/dev/null || echo "")
    if [ -n "$WP_URL" ]; then
      echo -e "     Site URL: ${GREEN}$WP_URL${NC}"
    fi
  fi
fi

# 2. Local wp-config.php
if [ "$WP_ENV" = "none" ] && [ -f "wp-config.php" ]; then
  WP_ENV="local"
  echo -e "  ${GREEN}✓${NC} Local WordPress installation detected (wp-config.php found)"

  # Try WP-CLI locally
  if command -v wp &>/dev/null; then
    WP_URL=$(wp option get siteurl 2>/dev/null || echo "")
    if [ -n "$WP_URL" ]; then
      echo -e "     Site URL: ${GREEN}$WP_URL${NC}"
    fi
  fi
fi

# 3. WordPress Playground blueprint
if [ "$WP_ENV" = "none" ] && ([ -f "blueprint.json" ] || [ -d "blueprints" ]); then
  WP_ENV="playground"
  echo -e "  ${GREEN}✓${NC} WordPress Playground blueprint detected"
fi

# 4. Docker compose file (not yet started)
if [ "$WP_ENV" = "none" ] && [ -f "docker-compose.yml" ] && grep -qi wordpress "docker-compose.yml" 2>/dev/null; then
  WP_ENV="docker-stopped"
  echo -e "  ${YELLOW}⚠${NC}  Docker Compose file found with WordPress — containers may not be running"
  echo -e "     Start with: ${CYAN}docker compose up -d${NC}"
fi

if [ "$WP_ENV" = "none" ]; then
  echo -e "  ${YELLOW}⚠${NC}  No running WordPress environment detected"
  echo -e "     Use ${CYAN}/wp-setup${NC} to create a new site"
fi

echo ""

# ─── Check available tools ────────────────────────────────────────────────────
echo -e "${YELLOW}Available tools:${NC}"

# Docker
if command -v docker &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} docker"
else
  echo -e "  ✗ docker (not installed)"
fi

# WP-CLI
if command -v wp &>/dev/null; then
  WP_VER=$(wp --version 2>/dev/null | head -1 || echo "unknown")
  echo -e "  ${GREEN}✓${NC} wp-cli ($WP_VER)"
elif [ -n "$WP_CONTAINER" ] 2>/dev/null; then
  DOCKER_WP_VER=$(docker exec "$WP_CONTAINER" wp --version --allow-root 2>/dev/null | head -1 || echo "unknown")
  echo -e "  ${GREEN}✓${NC} wp-cli in Docker ($DOCKER_WP_VER)"
else
  echo -e "  ✗ wp-cli (not installed locally)"
fi

# Python 3
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1)
  echo -e "  ${GREEN}✓${NC} $PY_VER"
else
  echo -e "  ✗ python3 (not installed — required for SEO audit and visual QA)"
fi

# Playwright
if python3 -c "import playwright" 2>/dev/null; then
  echo -e "  ${GREEN}✓${NC} playwright"
else
  echo -e "  ✗ playwright (run: pip install playwright && playwright install chromium)"
fi

# jq
if command -v jq &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} jq"
else
  echo -e "  ✗ jq (optional — required for validate-plugin-layout.sh)"
fi

# curl
if command -v curl &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} curl"
else
  echo -e "  ✗ curl (required for PageSpeed checks)"
fi

echo ""

# ─── Print skill summary ──────────────────────────────────────────────────────
echo -e "${YELLOW}Available skills:${NC}"
if [ -d "$SKILLS_ROOT/skills" ]; then
  for skill_dir in "$SKILLS_ROOT/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    echo -e "  ${GREEN}•${NC} $skill_name"
  done
else
  echo -e "  ${YELLOW}⚠${NC}  Skills directory not found at $SKILLS_ROOT/skills"
fi

echo ""

# ─── Quick commands reminder ──────────────────────────────────────────────────
echo -e "${YELLOW}Slash commands:${NC}"
echo -e "  ${CYAN}/wp-setup${NC}   — Set up a new WordPress site"
echo -e "  ${CYAN}/wp-audit${NC}   — Run a comprehensive site audit"
echo -e "  ${CYAN}/wp-launch${NC}  — Pre-launch checklist and handoff docs"
echo ""

# ─── Export context for the session ──────────────────────────────────────────
export WP_ENV WP_CONTAINER WP_URL SKILLS_ROOT

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Session initialized. ${GREEN}WP_ENV=${WP_ENV}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
