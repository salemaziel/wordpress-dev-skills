#!/usr/bin/env bash
# wp-dev-install.sh
# Install the wordpress-dev-skills plugin into any AI CLI tool's skills directory.
#
# Usage:
#   ./scripts/wp-dev-install.sh
#   ./scripts/wp-dev-install.sh --skills-dir /custom/path
#   ./scripts/wp-dev-install.sh --commands-dir /custom/path
#   ./scripts/wp-dev-install.sh --dry-run
#
# Portable: works with Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI.
# Set WP_SKILLS_ROOT to the repo root to override default detection.
# After install, scripts resolve their own location at runtime — no absolute
# paths are hardcoded.
#
# What this does:
#   1. Copies the repo to <skills-dir>/wordpress-dev-skills/ (rsync, no git history)
#   2. Symlinks commands/*.md → <commands-dir>/
#   3. Symlinks hooks/wp-session-init.sh → <hooks-dir>/
#   4. Validates the plugin layout

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SKILLS_DIR="${SKILLS_DIR:-$CLAUDE_DIR/skills}"
COMMANDS_DIR="${COMMANDS_DIR:-$CLAUDE_DIR/commands}"
HOOKS_DIR="${HOOKS_DIR:-$CLAUDE_DIR/hooks}"

PLUGIN_NAME="wordpress-dev-skills"
PLUGIN_TARGET="$SKILLS_DIR/$PLUGIN_NAME"
DRY_RUN=false

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-dir)   SKILLS_DIR="$2";   PLUGIN_TARGET="$SKILLS_DIR/$PLUGIN_NAME"; shift 2;;
    --commands-dir) COMMANDS_DIR="$2"; shift 2;;
    --hooks-dir)    HOOKS_DIR="$2";    shift 2;;
    --dry-run)      DRY_RUN=true;      shift;;
    -h|--help)
      echo "Usage: $0 [--skills-dir PATH] [--commands-dir PATH] [--hooks-dir PATH] [--dry-run]"
      exit 0;;
    *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1;;
  esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
run() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${CYAN}[dry-run]${NC} $*"
  else
    "$@"
  fi
}

announce() {
  echo -e "${YELLOW}$*${NC}"
}

ok() {
  echo -e "  ${GREEN}✓${NC} $*"
}

warn() {
  echo -e "  ${YELLOW}⚠${NC}  $*"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  WordPress Dev Skills — Install${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN — no files will be written${NC}"
  echo ""
fi

# ── 1. Create target directories ──────────────────────────────────────────────
announce "Creating directories..."
run mkdir -p "$PLUGIN_TARGET"
run mkdir -p "$COMMANDS_DIR"
run mkdir -p "$HOOKS_DIR"
ok "Directories ready"
echo ""

# ── 2. Copy skills directory ──────────────────────────────────────────────────
announce "Copying skills to $PLUGIN_TARGET ..."
if [ "$DRY_RUN" = true ]; then
  echo -e "  ${CYAN}[dry-run]${NC} rsync -a --delete $REPO_ROOT/ $PLUGIN_TARGET/"
else
  rsync -a --delete \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.DS_Store' \
    --exclude='*.zip' \
    "$REPO_ROOT/" "$PLUGIN_TARGET/"
fi
ok "Skills directory synced"
echo ""

# ── 3. Link slash commands ────────────────────────────────────────────────────
announce "Installing slash commands to $COMMANDS_DIR ..."
for cmd_file in "$PLUGIN_TARGET/commands/"*.md; do
  [ -f "$cmd_file" ] || continue
  cmd_name="$(basename "$cmd_file")"
  target_link="$COMMANDS_DIR/$cmd_name"

  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${CYAN}[dry-run]${NC} ln -sf $cmd_file $target_link"
  else
    ln -sf "$cmd_file" "$target_link"
  fi
  ok "$cmd_name → $target_link"
done
echo ""

# ── 4. Link session-init hook ─────────────────────────────────────────────────
announce "Installing session hook to $HOOKS_DIR ..."
HOOK_SRC="$PLUGIN_TARGET/hooks/wp-session-init.sh"
HOOK_DEST="$HOOKS_DIR/wp-session-init.sh"
if [ -f "$HOOK_SRC" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${CYAN}[dry-run]${NC} ln -sf $HOOK_SRC $HOOK_DEST"
  else
    run chmod +x "$HOOK_SRC"
    ln -sf "$HOOK_SRC" "$HOOK_DEST"
  fi
  ok "wp-session-init.sh → $HOOK_DEST"
else
  warn "Hook file not found: $HOOK_SRC"
fi
echo ""

# ── 5. Validate plugin layout ─────────────────────────────────────────────────
VALIDATE_SCRIPT="$REPO_ROOT/scripts/validate-plugin-layout.sh"
if [ -f "$VALIDATE_SCRIPT" ] && [ "$DRY_RUN" = false ]; then
  announce "Running plugin layout validation..."
  bash "$VALIDATE_SCRIPT" && ok "Validation passed" || warn "Validation reported issues (see above)"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}Dry run complete. Run without --dry-run to apply.${NC}"
else
  echo -e "${GREEN}Install complete!${NC}"
  echo ""
  echo "  Skills installed to : $PLUGIN_TARGET"
  echo "  Commands installed to: $COMMANDS_DIR"
  echo "  Hooks installed to  : $HOOKS_DIR"
  echo ""
  echo "  Slash commands available:"
  echo "    /wp-setup  — Set up a new WordPress site"
  echo "    /wp-audit  — Run a comprehensive audit"
  echo "    /wp-launch — Pre-launch checklist"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
