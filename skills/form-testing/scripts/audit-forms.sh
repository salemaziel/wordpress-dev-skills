#!/usr/bin/env bash
# audit-forms.sh
# Audit all forms in a WordPress site: email delivery, nonces, spam protection, SMTP config.
#
# Usage:
#   ./audit-forms.sh [CONTAINER] [--theme-path /path] [--url https://site.com]
#
# What this audits:
#   1. WP Mail SMTP plugin status and configuration
#   2. All form handlers in the theme (PHP scan)
#   3. Nonce usage in forms
#   4. Input sanitization patterns
#   5. Email delivery test via wp_mail()
#   6. SPAM protection (honeypots, reCAPTCHA, etc.)
#   7. Recommended improvements

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────────
CONTAINER="${1:-}"
THEME_PATH=""
SITE_URL=""
TEST_EMAIL="admin@example.com"
SKIP_EMAIL_TEST=false

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Argument parsing ─────────────────────────────────────────────────────────
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme-path)      THEME_PATH="$2";    shift 2;;
    --url)             SITE_URL="$2";      shift 2;;
    --email)           TEST_EMAIL="$2";    shift 2;;
    --skip-email-test) SKIP_EMAIL_TEST=true; shift;;
    -h|--help)
      echo "Usage: $(basename "$0") [CONTAINER] [--theme-path PATH] [--url URL] [--email EMAIL]"
      exit 0;;
    *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1;;
  esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0

pass()  { echo -e "  ${GREEN}✓${NC} $*"; PASS=$((PASS+1)); }
fail()  { echo -e "  ${RED}✗${NC} $*"; FAIL=$((FAIL+1)); }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $*"; WARN=$((WARN+1)); }
info()  { echo -e "  ${BLUE}i${NC}  $*"; }
header(){ echo -e "\n${YELLOW}$*${NC}"; }

wpcli() {
  if [ -n "$CONTAINER" ]; then
    docker exec "$CONTAINER" wp "$@" --allow-root 2>/dev/null || echo ""
  elif command -v wp &>/dev/null; then
    wp "$@" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# ─── Print header ─────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  WordPress Form Audit${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
[ -n "$CONTAINER" ] && echo -e "  Container: ${YELLOW}$CONTAINER${NC}"
[ -n "$SITE_URL" ]  && echo -e "  Site URL:  ${YELLOW}$SITE_URL${NC}"
echo ""

# ─── Section 1: WP Mail SMTP ─────────────────────────────────────────────────
header "1. Email Plugin & SMTP Configuration"

if [ -n "$CONTAINER" ] || command -v wp &>/dev/null; then
  SMTP_STATUS=$(wpcli plugin is-active wp-mail-smtp && echo "active" || echo "inactive")
  if [ "$SMTP_STATUS" = "active" ]; then
    pass "WP Mail SMTP is active"

    SMTP_CONFIG=$(wpcli option get wp_mail_smtp --format=json 2>/dev/null || echo "")
    if [ -n "$SMTP_CONFIG" ]; then
      # Try to parse host
      SMTP_HOST=$(echo "$SMTP_CONFIG" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('smtp',{}).get('host',''))" 2>/dev/null || echo "")
      SMTP_PORT=$(echo "$SMTP_CONFIG" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('smtp',{}).get('port',''))" 2>/dev/null || echo "")
      MAILER=$(echo "$SMTP_CONFIG" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('mail',{}).get('mailer','php'))" 2>/dev/null || echo "php")

      if [ "$MAILER" != "php" ] && [ -n "$SMTP_HOST" ]; then
        pass "SMTP configured: $SMTP_HOST:$SMTP_PORT (mailer: $MAILER)"
      elif [ "$MAILER" = "php" ]; then
        warn "Using PHP mail() — configure SMTP for reliable delivery"
      else
        warn "Mailer: $MAILER — verify configuration"
      fi

      FROM_EMAIL=$(echo "$SMTP_CONFIG" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('mail',{}).get('from_email',''))" 2>/dev/null || echo "")
      FROM_NAME=$(echo "$SMTP_CONFIG" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('mail',{}).get('from_name',''))" 2>/dev/null || echo "")
      [ -n "$FROM_EMAIL" ] && info "From: $FROM_NAME <$FROM_EMAIL>"
    fi
  else
    warn "WP Mail SMTP is NOT active — using PHP mail() (unreliable)"
    info "Install: wp plugin install wp-mail-smtp --activate"
  fi

  # Check for alternative SMTP plugins
  for plugin in "easy-smtp" "post-smtp" "fluent-smtp" "smtp-mailer"; do
    STATUS=$(wpcli plugin is-active "$plugin" 2>/dev/null && echo "active" || echo "")
    [ "$STATUS" = "active" ] && info "Alternative SMTP plugin active: $plugin"
  done
else
  warn "No container or local WP-CLI — skipping plugin checks"
fi

# ─── Section 2: Email Delivery Test ──────────────────────────────────────────
header "2. Email Delivery Test"

if [ "$SKIP_EMAIL_TEST" = true ]; then
  info "Skipping email test (--skip-email-test)"
elif [ -n "$CONTAINER" ] || command -v wp &>/dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$SCRIPT_DIR/test-mail.sh" ]; then
    bash "$SCRIPT_DIR/test-mail.sh" "${CONTAINER:-}" "$TEST_EMAIL" 2>/dev/null && \
      pass "Email delivery test passed" || fail "Email delivery test failed"
  else
    # Inline email test
    EMAIL_RESULT=$(wpcli eval "
\$result = wp_mail('$TEST_EMAIL', 'Form Audit Test - ' . date('Y-m-d H:i:s'), 'Automated audit email. Please ignore.');
echo \$result ? 'SUCCESS' : 'FAILED';
" 2>/dev/null || echo "ERROR")
    if echo "$EMAIL_RESULT" | grep -q "SUCCESS"; then
      pass "Email delivery test: SUCCESS → $TEST_EMAIL"
    elif echo "$EMAIL_RESULT" | grep -q "FAILED"; then
      fail "Email delivery test: FAILED — check SMTP config"
    else
      warn "Could not run email test: $EMAIL_RESULT"
    fi
  fi
else
  warn "No WP-CLI available — skipping email delivery test"
fi

# ─── Section 3: Theme Form Analysis ──────────────────────────────────────────
header "3. Theme Form Analysis"

SEARCH_PATHS=()
if [ -n "$THEME_PATH" ]; then
  SEARCH_PATHS+=("$THEME_PATH")
fi

# Try to get theme path from Docker
if [ -n "$CONTAINER" ]; then
  ACTIVE_THEME=$(wpcli option get stylesheet 2>/dev/null || echo "")
  if [ -n "$ACTIVE_THEME" ]; then
    CONTAINER_THEME_PATH="/var/www/html/wp-content/themes/$ACTIVE_THEME"
    info "Active theme: $ACTIVE_THEME"

    # Copy theme to temp dir for analysis
    TMP_THEME_DIR="/tmp/wp-form-audit-$$"
    mkdir -p "$TMP_THEME_DIR"
    docker cp "${CONTAINER}:${CONTAINER_THEME_PATH}" "$TMP_THEME_DIR/" 2>/dev/null && \
      SEARCH_PATHS+=("$TMP_THEME_DIR/$ACTIVE_THEME") || true
  fi
fi

if [ ${#SEARCH_PATHS[@]} -gt 0 ]; then
  for search_path in "${SEARCH_PATHS[@]}"; do
    [ -d "$search_path" ] || continue

    # Count form elements
    FORM_FILES=$(grep -rl '<form' "$search_path" --include="*.php" 2>/dev/null | wc -l || echo 0)
    FORM_INSTANCES=$(grep -r '<form' "$search_path" --include="*.php" 2>/dev/null | wc -l || echo 0)
    [ "$FORM_INSTANCES" -gt 0 ] && \
      pass "Found $FORM_INSTANCES form(s) in $FORM_FILES file(s)" || \
      warn "No HTML forms found in theme PHP files"

    # Check nonce usage
    NONCE_FILES=$(grep -rl 'wp_nonce_field\|wp_verify_nonce\|check_admin_referer' \
      "$search_path" --include="*.php" 2>/dev/null | wc -l || echo 0)
    if [ "$NONCE_FILES" -gt 0 ]; then
      pass "Nonce protection found in $NONCE_FILES file(s)"
    else
      fail "No nonce usage detected — forms may lack CSRF protection"
      info "Add: wp_nonce_field('form_action', 'form_nonce') to each form"
    fi

    # Check input sanitization
    SANITIZE_COUNT=$(grep -r 'sanitize_text_field\|sanitize_email\|wp_kses\|absint\|esc_html\|intval' \
      "$search_path" --include="*.php" 2>/dev/null | wc -l || echo 0)
    if [ "$SANITIZE_COUNT" -gt 0 ]; then
      pass "Input sanitization found ($SANITIZE_COUNT occurrences)"
    else
      warn "No input sanitization detected — verify form handlers use sanitize_*()"
    fi

    # Check for honeypot fields
    HONEYPOT=$(grep -r 'honeypot\|hp_\|_gotcha\|display.*none.*input\|hidden.*bot' \
      "$search_path" --include="*.php" --include="*.js" 2>/dev/null | wc -l || echo 0)
    if [ "$HONEYPOT" -gt 0 ]; then
      pass "Honeypot spam protection found"
    else
      warn "No honeypot detected — consider adding a honeypot field to forms"
    fi

    # Check wp_mail() usage
    WP_MAIL_COUNT=$(grep -r 'wp_mail\s*(' "$search_path" --include="*.php" 2>/dev/null | wc -l || echo 0)
    [ "$WP_MAIL_COUNT" -gt 0 ] && \
      pass "wp_mail() called in $WP_MAIL_COUNT location(s)" || \
      warn "No wp_mail() found — verify form handlers send emails"

    # Check reply-to header
    REPLY_TO=$(grep -r 'reply-to\|Reply-To' "$search_path" --include="*.php" 2>/dev/null | wc -l || echo 0)
    [ "$REPLY_TO" -gt 0 ] && \
      pass "Reply-To header set in email headers" || \
      warn "No Reply-To header — add sender email to make replying easy"
  done

  # Cleanup temp files
  [ -d "/tmp/wp-form-audit-$$" ] && rm -rf "/tmp/wp-form-audit-$$"
else
  warn "No theme path to analyze — provide --theme-path or --container"
fi

# ─── Section 4: HTTP Form Test (if URL provided) ──────────────────────────────
if [ -n "$SITE_URL" ]; then
  header "4. HTTP Form Test"
  CONTACT_URL="${SITE_URL%/}/contact/"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ -f "$SCRIPT_DIR/test-form.sh" ]; then
    info "Testing contact form at: $CONTACT_URL"
    bash "$SCRIPT_DIR/test-form.sh" "$CONTACT_URL" --email "$TEST_EMAIL" 2>/dev/null && \
      pass "Contact form test passed" || \
      warn "Contact form test had issues — check output above"
  else
    # Quick curl test
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$CONTACT_URL" || echo "0")
    [ "$HTTP_STATUS" = "200" ] && \
      pass "Contact page accessible (HTTP 200)" || \
      warn "Contact page returned HTTP $HTTP_STATUS"
  fi
fi

# ─── Section 5: Recommendations ──────────────────────────────────────────────
header "5. Recommendations"

[ "$FAIL" -gt 0 ] && echo -e "  ${RED}Critical:${NC}"
[ "$FAIL" -gt 0 ] && fail "Fix all failing checks before launch"

echo ""
echo "  SMTP Best Practices:"
info "Use a transactional email service (SendGrid, Mailgun, SMTP.com)"
info "Set a proper From address (noreply@yourdomain.com)"
info "Configure SPF and DKIM DNS records to prevent spam filtering"

echo ""
echo "  Security Best Practices:"
info "Every form should have: wp_nonce_field() for CSRF protection"
info "All user input should be: sanitize_text_field() or sanitize_email()"
info "All output should be: esc_html() or esc_attr()"
info "Consider a honeypot field: hidden input that bots fill in"

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}AUDIT: FAIL${NC}  PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
elif [ "$WARN" -gt 0 ]; then
  echo -e "${YELLOW}AUDIT: WARN${NC}  PASS: $PASS  FAIL: 0  WARN: $WARN"
else
  echo -e "${GREEN}AUDIT: PASS${NC}  $PASS checks passed"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

[ "$FAIL" -eq 0 ]
