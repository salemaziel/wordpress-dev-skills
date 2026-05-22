#!/usr/bin/env bash
# wp-sync-prod.sh
# Sync a WordPress theme or plugin from local Docker to a production server via rsync over SSH.
#
# Usage:
#   ./scripts/wp-sync-prod.sh --host user@myserver.com --theme my-child-theme
#   ./scripts/wp-sync-prod.sh --host user@myserver.com --plugin my-plugin
#   ./scripts/wp-sync-prod.sh --host user@myserver.com --theme my-theme --wp-path /var/www/vhosts/mysite.com/httpdocs
#   ./scripts/wp-sync-prod.sh --dry-run --host user@myserver.com --theme my-theme
#
# Requirements:
#   - rsync
#   - SSH key-based authentication configured for the target host
#   - The local WordPress theme/plugin present in the Docker container or at a local path
#
# What this does:
#   1. Exports the theme/plugin directory from Docker (if --container is given)
#   2. Search-replaces local dev URL → production URL in a temporary copy (optional)
#   3. rsyncs the directory to the production server
#   4. Optionally flushes the WordPress cache on production via SSH + WP-CLI

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────────
CONTAINER=""
LOCAL_PATH=""
REMOTE_HOST=""
REMOTE_WP_PATH="/var/www/html"
SYNC_TYPE=""       # "theme" or "plugin"
SYNC_NAME=""       # theme/plugin folder name
LOCAL_URL=""
PROD_URL=""
FLUSH_CACHE=false
DRY_RUN=false
RSYNC_OPTS="-avz --delete"
EXCLUDE_LIST=(
  ".git"
  ".gitignore"
  "node_modules"
  ".DS_Store"
  "*.log"
  "tests/"
  "playwright-report/"
  "test-results/"
  "*.zip"
  ".env"
)

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Sync a WordPress theme or plugin to a production server via rsync.

Options:
  --host HOST              SSH host (e.g. user@myserver.com)  [required]
  --theme NAME             Theme folder name to sync
  --plugin NAME            Plugin folder name to sync
  --container NAME         Docker container to extract from (optional)
  --local-path PATH        Local path of theme/plugin (alternative to --container)
  --wp-path PATH           WordPress root on the remote server
                           (default: /var/www/html)
  --local-url URL          Local development URL to search-replace (optional)
  --prod-url URL           Production URL to replace with (optional)
  --flush-cache            Run wp cache flush on production after sync (requires
                           wp-cli on production)
  --dry-run                Show what would happen without making changes
  -h, --help               Show this help

Examples:
  # Sync from Docker container
  $(basename "$0") --host user@myserver.com --theme my-child-theme \\
    --container wordpress-local-wordpress-1 \\
    --local-url https://localhost:8080 --prod-url https://mysite.com

  # Sync from local path
  $(basename "$0") --host user@myserver.com --theme my-child-theme \\
    --local-path ./wp-content/themes/my-child-theme

  # Dry run
  $(basename "$0") --dry-run --host user@myserver.com --theme my-child-theme \\
    --local-path /tmp/my-child-theme
EOF
  exit 0
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)        REMOTE_HOST="$2";     shift 2;;
    --theme)       SYNC_TYPE="theme";    SYNC_NAME="$2"; shift 2;;
    --plugin)      SYNC_TYPE="plugin";   SYNC_NAME="$2"; shift 2;;
    --container)   CONTAINER="$2";       shift 2;;
    --local-path)  LOCAL_PATH="$2";      shift 2;;
    --wp-path)     REMOTE_WP_PATH="$2";  shift 2;;
    --local-url)   LOCAL_URL="$2";       shift 2;;
    --prod-url)    PROD_URL="$2";        shift 2;;
    --flush-cache) FLUSH_CACHE=true;     shift;;
    --dry-run)     DRY_RUN=true;         shift;;
    -h|--help)     usage;;
    *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1;;
  esac
done

# ─── Validation ───────────────────────────────────────────────────────────────
if [ -z "$REMOTE_HOST" ]; then
  echo -e "${RED}Error: --host is required${NC}"; exit 1
fi
if [ -z "$SYNC_TYPE" ] || [ -z "$SYNC_NAME" ]; then
  echo -e "${RED}Error: either --theme or --plugin is required${NC}"; exit 1
fi
if [ -z "$CONTAINER" ] && [ -z "$LOCAL_PATH" ]; then
  echo -e "${RED}Error: either --container or --local-path is required${NC}"; exit 1
fi
if ! command -v rsync &>/dev/null; then
  echo -e "${RED}Error: rsync is required but not installed${NC}"; exit 1
fi

# ─── Determine remote path ────────────────────────────────────────────────────
if [ "$SYNC_TYPE" = "theme" ]; then
  REMOTE_DEST="$REMOTE_WP_PATH/wp-content/themes/$SYNC_NAME/"
  CONTAINER_PATH="/var/www/html/wp-content/themes/$SYNC_NAME"
else
  REMOTE_DEST="$REMOTE_WP_PATH/wp-content/plugins/$SYNC_NAME/"
  CONTAINER_PATH="/var/www/html/wp-content/plugins/$SYNC_NAME"
fi

# ─── Print header ─────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  WordPress Dev Skills — Sync to Production${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Type    : ${GREEN}$SYNC_TYPE${NC}"
echo -e "  Name    : ${GREEN}$SYNC_NAME${NC}"
echo -e "  Target  : ${GREEN}${REMOTE_HOST}:${REMOTE_DEST}${NC}"
[ -n "$CONTAINER" ]  && echo -e "  Source  : Docker container ${GREEN}$CONTAINER${NC}"
[ -n "$LOCAL_PATH" ] && echo -e "  Source  : Local path ${GREEN}$LOCAL_PATH${NC}"
[ "$DRY_RUN" = true ] && echo -e "  ${YELLOW}MODE    : DRY RUN (no changes will be made)${NC}"
echo ""

# ─── Step 1: Get local source ─────────────────────────────────────────────────
SYNC_SOURCE=""

if [ -n "$CONTAINER" ]; then
  echo -e "${YELLOW}Exporting from Docker container...${NC}"
  TMP_EXPORT="/tmp/wp-sync-$$-$SYNC_NAME"
  mkdir -p "$TMP_EXPORT"

  if [ "$DRY_RUN" = false ]; then
    docker cp "${CONTAINER}:${CONTAINER_PATH}" "$TMP_EXPORT/" \
      || { echo -e "${RED}Error: Could not copy from container${NC}"; exit 1; }
  else
    echo -e "  ${CYAN}[dry-run]${NC} docker cp ${CONTAINER}:${CONTAINER_PATH} $TMP_EXPORT/"
  fi
  SYNC_SOURCE="$TMP_EXPORT/$SYNC_NAME"
  echo -e "  ${GREEN}✓${NC} Exported to $SYNC_SOURCE"

elif [ -n "$LOCAL_PATH" ]; then
  if [ ! -d "$LOCAL_PATH" ]; then
    echo -e "${RED}Error: Local path not found: $LOCAL_PATH${NC}"; exit 1
  fi
  SYNC_SOURCE="$LOCAL_PATH"
  echo -e "  ${GREEN}✓${NC} Using local path: $SYNC_SOURCE"
fi

echo ""

# ─── Step 2: Optional URL search-replace in temp copy ─────────────────────────
if [ -n "$LOCAL_URL" ] && [ -n "$PROD_URL" ] && [ -n "$CONTAINER" ]; then
  echo -e "${YELLOW}Replacing development URLs with production URL...${NC}"
  echo -e "  ${LOCAL_URL} → ${PROD_URL}"

  if [ "$DRY_RUN" = false ]; then
    find "$SYNC_SOURCE" -type f \( -name "*.php" -o -name "*.js" -o -name "*.css" -o -name "*.json" \) \
      -exec perl -i -pe "s|${LOCAL_URL}|${PROD_URL}|g" {} +
  else
    echo -e "  ${CYAN}[dry-run]${NC} find/sed replace in $SYNC_SOURCE"
  fi
  echo -e "  ${GREEN}✓${NC} URL replacement complete"
  echo ""
fi

# ─── Step 3: Build rsync exclude flags ───────────────────────────────────────
EXCLUDES=()
for item in "${EXCLUDE_LIST[@]}"; do
  EXCLUDES+=("--exclude=$item")
done

# ─── Step 4: rsync to production ─────────────────────────────────────────────
echo -e "${YELLOW}Syncing to production...${NC}"

if [ "$DRY_RUN" = true ]; then
  echo -e "  ${CYAN}[dry-run]${NC} rsync $RSYNC_OPTS ${EXCLUDES[*]} $SYNC_SOURCE/ ${REMOTE_HOST}:${REMOTE_DEST}"
else
  # shellcheck disable=SC2086
  rsync $RSYNC_OPTS "${EXCLUDES[@]}" \
    "$SYNC_SOURCE/" \
    "${REMOTE_HOST}:${REMOTE_DEST}"
fi
echo -e "  ${GREEN}✓${NC} Sync complete"
echo ""

# ─── Step 5: Optional cache flush ────────────────────────────────────────────
if [ "$FLUSH_CACHE" = true ]; then
  echo -e "${YELLOW}Flushing WordPress cache on production...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${CYAN}[dry-run]${NC} ssh $REMOTE_HOST wp cache flush --path=$REMOTE_WP_PATH --allow-root"
  else
    # shellcheck disable=SC2029
    ssh "$REMOTE_HOST" "wp cache flush --path=$REMOTE_WP_PATH --allow-root 2>/dev/null || echo 'wp-cli not found on server — flush skipped'"
  fi
  echo -e "  ${GREEN}✓${NC} Cache flushed"
  echo ""
fi

# ─── Cleanup ──────────────────────────────────────────────────────────────────
if [ -n "$CONTAINER" ] && [ -d "/tmp/wp-sync-$$-$SYNC_NAME" ] && [ "$DRY_RUN" = false ]; then
  rm -rf "/tmp/wp-sync-$$-$SYNC_NAME"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}Dry run complete. Re-run without --dry-run to apply.${NC}"
else
  echo -e "${GREEN}Deployment complete!${NC}"
  echo ""
  echo -e "  ${SYNC_TYPE^} ${SYNC_NAME} synced to ${REMOTE_HOST}:${REMOTE_DEST}"
  if [ "$FLUSH_CACHE" = false ]; then
    echo ""
    echo -e "  ${YELLOW}Tip:${NC} Run with --flush-cache to also flush the WP cache on production."
  fi
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
