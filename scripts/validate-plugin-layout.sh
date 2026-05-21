#!/usr/bin/env bash
# validate-plugin-layout.sh
# Validates the wordpress-dev-skills plugin layout, manifests, and marketplace submission.
#
# Usage:
#   bash scripts/validate-plugin-layout.sh
#
# Requirements:
#   jq  (install with: brew install jq  OR  apt install jq)

set -euo pipefail

# ─── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass()  { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail()  { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; WARN=$((WARN+1)); }
info()  { echo -e "  ${BLUE}→${NC} $1"; }

# ─── Locate repo root ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} wordpress-dev-skills — Plugin Validator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ─── Check jq ─────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v jq &>/dev/null; then
  echo -e "${RED}ERROR: jq is required but not installed.${NC}"
  echo "  Install with:  brew install jq   (macOS)"
  echo "                 apt install jq    (Debian/Ubuntu)"
  echo "                 yum install jq    (RHEL/CentOS)"
  exit 1
fi
pass "jq is available"
echo ""

EXPECTED_REPO="https://github.com/salemaziel/wordpress-dev-skills"
EXPECTED_MARKETPLACE="https://github.com/salemaziel/vdw-claude-plugins"
EXPECTED_NAME="wordpress-dev-skills"

# ─── Helper: validate JSON file ───────────────────────────────────────────────
check_json() {
  local file="$1"
  local label="${2:-$1}"
  if [ ! -f "$file" ]; then
    fail "$label — file does not exist"
    return 1
  fi
  if ! jq empty "$file" 2>/dev/null; then
    fail "$label — invalid JSON"
    return 1
  fi
  pass "$label — exists and is valid JSON"
  return 0
}

# ─── Helper: check field value ────────────────────────────────────────────────
check_field() {
  local file="$1"
  local jq_path="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual=$(jq -r "$jq_path" "$file" 2>/dev/null || echo "")
  if [ "$actual" = "$expected" ]; then
    pass "$label = \"$expected\""
  else
    fail "$label — expected \"$expected\", got \"$actual\""
  fi
}

# ─── 1. Required manifest files ───────────────────────────────────────────────
echo -e "${YELLOW}1. Checking required manifest files...${NC}"
ROOT_OK=0;     check_json "plugin.json"                 "plugin.json"                 && ROOT_OK=1
CLAUDE_OK=0;   check_json ".claude-plugin/plugin.json"  ".claude-plugin/plugin.json"  && CLAUDE_OK=1
CODEX_OK=0;    check_json ".codex-plugin/plugin.json"   ".codex-plugin/plugin.json"   && CODEX_OK=1
GEMINI_OK=0;   check_json "gemini-extension.json"       "gemini-extension.json"       && GEMINI_OK=1
AGENTS_OK=0;   check_json ".agents/plugins/marketplace.json" ".agents/plugins/marketplace.json" && AGENTS_OK=1
GH_OK=0;       check_json ".github/plugin/marketplace.json"  ".github/plugin/marketplace.json"  && GH_OK=1
echo ""

# ─── 2. Required documentation files ─────────────────────────────────────────
echo -e "${YELLOW}2. Checking required documentation files...${NC}"
for f in README.md CHANGELOG.md docs/marketplace.md COMPLETENESS_AUDIT.md; do
  if [ -f "$f" ]; then pass "$f exists"; else fail "$f missing"; fi
done
echo ""

# ─── 3. Version consistency ───────────────────────────────────────────────────
echo -e "${YELLOW}3. Checking version consistency across manifests...${NC}"
if [ "$ROOT_OK" = 1 ] && [ "$CLAUDE_OK" = 1 ] && [ "$CODEX_OK" = 1 ] && [ "$GEMINI_OK" = 1 ]; then
  V_ROOT=$(jq -r '.version' plugin.json)
  V_CLAUDE=$(jq -r '.version' .claude-plugin/plugin.json)
  V_CODEX=$(jq -r '.version' .codex-plugin/plugin.json)
  V_GEMINI=$(jq -r '.version' gemini-extension.json)

  info "plugin.json version:              $V_ROOT"
  info ".claude-plugin/plugin.json:       $V_CLAUDE"
  info ".codex-plugin/plugin.json:        $V_CODEX"
  info "gemini-extension.json:            $V_GEMINI"

  if [ "$V_ROOT" = "$V_CLAUDE" ] && [ "$V_ROOT" = "$V_CODEX" ] && [ "$V_ROOT" = "$V_GEMINI" ]; then
    pass "All manifest versions match: $V_ROOT"
  else
    fail "Version mismatch across manifests"
  fi
else
  warn "Skipping version check — one or more manifest files missing or invalid"
fi
echo ""

# ─── 4. Name consistency ──────────────────────────────────────────────────────
echo -e "${YELLOW}4. Checking name consistency across manifests...${NC}"
if [ "$ROOT_OK" = 1 ] && [ "$CLAUDE_OK" = 1 ] && [ "$CODEX_OK" = 1 ] && [ "$GEMINI_OK" = 1 ]; then
  N_ROOT=$(jq -r '.name' plugin.json)
  N_CLAUDE=$(jq -r '.name' .claude-plugin/plugin.json)
  N_CODEX=$(jq -r '.name' .codex-plugin/plugin.json)
  N_GEMINI=$(jq -r '.name' gemini-extension.json)

  if [ "$N_ROOT" = "$EXPECTED_NAME" ] && [ "$N_ROOT" = "$N_CLAUDE" ] && [ "$N_ROOT" = "$N_CODEX" ] && [ "$N_ROOT" = "$N_GEMINI" ]; then
    pass "All manifest names match: $N_ROOT"
  else
    fail "Name mismatch — root=$N_ROOT, claude=$N_CLAUDE, codex=$N_CODEX, gemini=$N_GEMINI"
  fi
else
  warn "Skipping name check — one or more manifest files missing or invalid"
fi
echo ""

# ─── 5. Repository URL ────────────────────────────────────────────────────────
echo -e "${YELLOW}5. Checking repository URL in manifests...${NC}"
if [ "$CLAUDE_OK" = 1 ]; then
  REPO_CLAUDE=$(jq -r '.repository // ""' .claude-plugin/plugin.json)
  if [ "$REPO_CLAUDE" = "$EXPECTED_REPO" ]; then
    pass ".claude-plugin/plugin.json repository = $EXPECTED_REPO"
  else
    fail ".claude-plugin/plugin.json repository — expected $EXPECTED_REPO, got $REPO_CLAUDE"
  fi
fi
if [ "$ROOT_OK" = 1 ]; then
  REPO_ROOT_VAL=$(jq -r '.repository.url // .repository // ""' plugin.json)
  REPO_ROOT_CLEAN="${REPO_ROOT_VAL%.git}"
  if [ "$REPO_ROOT_CLEAN" = "$EXPECTED_REPO" ]; then
    pass "plugin.json repository.url = $EXPECTED_REPO"
  else
    fail "plugin.json repository.url — expected $EXPECTED_REPO (or .git variant), got $REPO_ROOT_VAL"
  fi
fi
echo ""

# ─── 6. Marketplace URL ───────────────────────────────────────────────────────
echo -e "${YELLOW}6. Checking marketplace URL in manifests...${NC}"
for manifest_file in plugin.json .claude-plugin/plugin.json .codex-plugin/plugin.json gemini-extension.json; do
  if [ -f "$manifest_file" ]; then
    MP=$(jq -r '.marketplace // ""' "$manifest_file")
    if [ "$MP" = "$EXPECTED_MARKETPLACE" ]; then
      pass "$manifest_file marketplace = $EXPECTED_MARKETPLACE"
    else
      fail "$manifest_file marketplace — expected $EXPECTED_MARKETPLACE, got $MP"
    fi
  fi
done
echo ""

# ─── 7. Local fixture fields ──────────────────────────────────────────────────
echo -e "${YELLOW}7. Checking local fixture role fields...${NC}"
for fixture in ".agents/plugins/marketplace.json" ".github/plugin/marketplace.json"; do
  if [ -f "$fixture" ]; then
    ROLE=$(jq -r '.marketplaceRole // ""' "$fixture")
    CMP=$(jq -r '.canonicalMarketplace // ""' "$fixture")
    if [ "$ROLE" = "local-development-fixture" ]; then
      pass "$fixture has marketplaceRole=local-development-fixture"
    else
      fail "$fixture missing or wrong marketplaceRole"
    fi
    if [ "$CMP" = "$EXPECTED_MARKETPLACE" ]; then
      pass "$fixture canonicalMarketplace = $EXPECTED_MARKETPLACE"
    else
      fail "$fixture canonicalMarketplace — expected $EXPECTED_MARKETPLACE, got $CMP"
    fi
  fi
done
echo ""

# ─── 8. Docs mention marketplace repo ────────────────────────────────────────
echo -e "${YELLOW}8. Checking documentation references to canonical marketplace...${NC}"
for doc in README.md CHANGELOG.md docs/marketplace.md; do
  if [ -f "$doc" ]; then
    if grep -q "vdw-claude-plugins" "$doc"; then
      pass "$doc mentions vdw-claude-plugins"
    else
      fail "$doc does not mention the canonical marketplace (vdw-claude-plugins)"
    fi
  fi
done
echo ""

# ─── 9. Marketplace submission package ───────────────────────────────────────
echo -e "${YELLOW}9. Checking marketplace submission package...${NC}"
SUB_DIR="marketplace-submission/vdw-claude-plugins"

# Check if ../vdw-claude-plugins exists
if [ -d "../vdw-claude-plugins" ]; then
  info "../vdw-claude-plugins is available locally"

  # Check for a wordpress-dev-skills entry
  if grep -r "wordpress-dev-skills" "../vdw-claude-plugins" &>/dev/null; then
    pass "../vdw-claude-plugins contains an entry for wordpress-dev-skills"

    # Check the entry points to the right repo
    if grep -r "$EXPECTED_REPO" "../vdw-claude-plugins" &>/dev/null; then
      pass "Marketplace entry references $EXPECTED_REPO"
    else
      fail "Marketplace entry does not reference $EXPECTED_REPO"
    fi

    # Check the entry references .claude-plugin/plugin.json
    if grep -r ".claude-plugin/plugin.json" "../vdw-claude-plugins" &>/dev/null; then
      pass "Marketplace entry references .claude-plugin/plugin.json"
    else
      warn "Marketplace entry does not reference .claude-plugin/plugin.json"
    fi
  else
    fail "../vdw-claude-plugins does not contain an entry for wordpress-dev-skills"
  fi
else
  warn "../vdw-claude-plugins is NOT available locally — checking submission package instead"

  for f in README.md PATCH_NOTES.md wordpress-dev-skills.entry.json wordpress-dev-skills.entry.md; do
    if [ -f "$SUB_DIR/$f" ]; then
      pass "marketplace-submission: $f exists"
    else
      fail "marketplace-submission: $f missing"
    fi
  done

  # Validate submission JSON
  if [ -f "$SUB_DIR/wordpress-dev-skills.entry.json" ]; then
    if jq empty "$SUB_DIR/wordpress-dev-skills.entry.json" 2>/dev/null; then
      pass "marketplace-submission: wordpress-dev-skills.entry.json is valid JSON"

      # Check version matches .claude-plugin/plugin.json
      if [ "$CLAUDE_OK" = 1 ]; then
        SUB_VER=$(jq -r '.version // ""' "$SUB_DIR/wordpress-dev-skills.entry.json")
        CLAUDE_VER=$(jq -r '.version // ""' .claude-plugin/plugin.json)
        if [ "$SUB_VER" = "$CLAUDE_VER" ]; then
          pass "Submission version ($SUB_VER) matches .claude-plugin/plugin.json ($CLAUDE_VER)"
        else
          fail "Submission version ($SUB_VER) does not match .claude-plugin/plugin.json ($CLAUDE_VER)"
        fi
      fi

      # Check source URL
      SUB_SOURCE=$(jq -r '.source // .repository // ""' "$SUB_DIR/wordpress-dev-skills.entry.json")
      if [ "$SUB_SOURCE" = "$EXPECTED_REPO" ]; then
        pass "Submission entry source = $EXPECTED_REPO"
      else
        fail "Submission entry source — expected $EXPECTED_REPO, got $SUB_SOURCE"
      fi

      # Check manifest reference
      SUB_MANIFEST=$(jq -r '.manifest // ""' "$SUB_DIR/wordpress-dev-skills.entry.json")
      if [ "$SUB_MANIFEST" = ".claude-plugin/plugin.json" ]; then
        pass "Submission entry manifest = .claude-plugin/plugin.json"
      else
        fail "Submission entry manifest — expected .claude-plugin/plugin.json, got $SUB_MANIFEST"
      fi
    else
      fail "marketplace-submission: wordpress-dev-skills.entry.json is not valid JSON"
    fi
  fi
fi
echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────
echo -e "${BLUE}========================================${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${RED}FAIL: $FAIL${NC}   ${YELLOW}WARN: $WARN${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Validation FAILED — $FAIL check(s) failed. Fix errors above before publishing.${NC}"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo -e "${YELLOW}Validation passed with $WARN warning(s). Review warnings above.${NC}"
  exit 0
else
  echo -e "${GREEN}All checks passed.${NC}"
  exit 0
fi
