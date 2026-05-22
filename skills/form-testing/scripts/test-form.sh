#!/usr/bin/env bash
# test-form.sh
# Test a WordPress contact form by submitting it via HTTP and checking the response.
#
# Usage:
#   ./test-form.sh https://site.com/contact/
#   ./test-form.sh https://site.com/contact/ --name "Test User" --email "test@example.com"
#   ./test-form.sh https://site.com/contact/ --json
#
# What this checks:
#   1. Fetches the form page and extracts the nonce value (if present)
#   2. Submits the form with test data via curl
#   3. Checks for a success redirect (?contact=success, ?sent=true, etc.)
#   4. Reports status: PASS / FAIL / WARNING

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────────
FORM_URL="${1:-}"
TEST_NAME="Test User"
TEST_EMAIL="test+formtest@example.com"
TEST_MESSAGE="This is an automated form test from wordpress-dev-skills. Please ignore."
TEST_PHONE="555-0100"
JSON_OUTPUT=false
COOKIE_JAR="/tmp/wp-form-test-cookies-$$.txt"
TIMEOUT=30

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") FORM_URL [OPTIONS]

Options:
  --name NAME      Sender name (default: "Test User")
  --email EMAIL    Sender email (default: test+formtest@example.com)
  --message MSG    Message text (default: automated test message)
  --phone PHONE    Phone number (default: 555-0100)
  --json           Output results as JSON
  -h, --help       Show this help

Examples:
  $(basename "$0") https://mysite.com/contact/
  $(basename "$0") https://mysite.com/contact/ --email dev@myagency.com --json
EOF
  exit 0
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)    TEST_NAME="$2";    shift 2;;
    --email)   TEST_EMAIL="$2";   shift 2;;
    --message) TEST_MESSAGE="$2"; shift 2;;
    --phone)   TEST_PHONE="$2";   shift 2;;
    --json)    JSON_OUTPUT=true;  shift;;
    -h|--help) usage;;
    *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1;;
  esac
done

if [ -z "$FORM_URL" ]; then
  echo -e "${RED}Error: FORM_URL is required${NC}"
  usage
fi

if ! command -v curl &>/dev/null; then
  echo -e "${RED}Error: curl is required but not installed${NC}"
  exit 1
fi

# ─── Result tracking ──────────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0
declare -a RESULTS=()

record() {
  local status="$1" msg="$2"
  RESULTS+=("${status}|${msg}")
  case "$status" in
    PASS) PASS=$((PASS+1));;
    FAIL) FAIL=$((FAIL+1));;
    WARN) WARN=$((WARN+1));;
  esac
}

# ─── Step 1: Fetch form page ───────────────────────────────────────────────────
if [ "$JSON_OUTPUT" = false ]; then
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  WordPress Form Test${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  URL: ${YELLOW}$FORM_URL${NC}"
  echo ""
  echo "Step 1: Fetching form page..."
fi

PAGE_CONTENT=$(curl -s -c "$COOKIE_JAR" \
  --max-time "$TIMEOUT" \
  -A "Mozilla/5.0 (compatible; wordpress-dev-skills form tester)" \
  "$FORM_URL" 2>/dev/null || echo "")

if [ -z "$PAGE_CONTENT" ]; then
  record "FAIL" "Could not fetch form page: $FORM_URL"
else
  record "PASS" "Form page fetched successfully"
fi

# ─── Step 2: Check for form element ──────────────────────────────────────────
FORM_COUNT=$(echo "$PAGE_CONTENT" | grep -ic '<form' || true)
if [ "$FORM_COUNT" -gt 0 ]; then
  record "PASS" "Found $FORM_COUNT form(s) on the page"
else
  record "WARN" "No <form> elements found on page — may be loaded via JavaScript"
fi

# ─── Step 3: Extract nonce ────────────────────────────────────────────────────
NONCE_VALUE=$(echo "$PAGE_CONTENT" | sed -n 's/.*name="[^"]*nonce[^"]*"[^"]*value="\([^"]*\)".*/\1/p' | head -1 || true)
NONCE_FIELD=$(echo "$PAGE_CONTENT" | sed -n 's/.*name="\([^"]*nonce[^"]*\)".*/\1/p' | head -1 || true)

if [ -n "$NONCE_VALUE" ]; then
  record "PASS" "Nonce found: field=$NONCE_FIELD value=${NONCE_VALUE:0:8}..."
else
  record "WARN" "No WordPress nonce detected — form may lack CSRF protection"
fi

# ─── Step 4: Detect common form field names ───────────────────────────────────
FORM_FIELDS_RAW=$(echo "$PAGE_CONTENT" | grep -oP '<input[^>]*name="\K[^"]+' || true)
TEXTAREA_FIELDS=$(echo "$PAGE_CONTENT" | grep -oP '<textarea[^>]*name="\K[^"]+' || true)
ALL_FIELDS=$(echo -e "$FORM_FIELDS_RAW\n$TEXTAREA_FIELDS" | sort -u | grep -v '^$' || true)

# Common field mappings
NAME_FIELD=$(echo "$ALL_FIELDS" | grep -iE 'name|full.?name|your.?name' | head -1 || echo "name")
EMAIL_FIELD=$(echo "$ALL_FIELDS" | grep -iE 'email|your.?email|e.?mail' | head -1 || echo "email")
MSG_FIELD=$(echo "$ALL_FIELDS" | grep -iE 'message|msg|body|comment' | head -1 || echo "message")
PHONE_FIELD=$(echo "$ALL_FIELDS" | grep -iE 'phone|tel|mobile|number' | head -1 || echo "phone")

[ -n "$NAME_FIELD" ] && record "PASS" "Name field detected: $NAME_FIELD" || record "WARN" "No name field detected — will try generic 'name'"
[ -n "$EMAIL_FIELD" ] && record "PASS" "Email field detected: $EMAIL_FIELD" || record "WARN" "No email field detected — will try generic 'email'"

# ─── Step 5: Build POST data ─────────────────────────────────────────────────
POST_DATA="${NAME_FIELD}=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TEST_NAME'))" 2>/dev/null || echo "Test+User")"
POST_DATA="${POST_DATA}&${EMAIL_FIELD}=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TEST_EMAIL'))" 2>/dev/null || echo "test%40example.com")"
POST_DATA="${POST_DATA}&${MSG_FIELD}=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TEST_MESSAGE'))" 2>/dev/null || echo "Automated+test")"
[ -n "$PHONE_FIELD" ] && POST_DATA="${POST_DATA}&${PHONE_FIELD}=${TEST_PHONE}"

# Add nonce if found
if [ -n "$NONCE_FIELD" ] && [ -n "$NONCE_VALUE" ]; then
  POST_DATA="${POST_DATA}&${NONCE_FIELD}=${NONCE_VALUE}"
fi

# Add common hidden fields that WP forms use
POST_DATA="${POST_DATA}&_wp_http_referer=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FORM_URL'))" 2>/dev/null || echo "")"

# ─── Step 6: Submit form ──────────────────────────────────────────────────────
if [ "$JSON_OUTPUT" = false ]; then
  echo "Step 2: Submitting form..."
fi

RESPONSE_HEADERS=$(curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  --max-time "$TIMEOUT" \
  -X POST "$FORM_URL" \
  -d "$POST_DATA" \
  -A "Mozilla/5.0 (compatible; wordpress-dev-skills form tester)" \
  -D - \
  -o /tmp/wp-form-response-$$.html \
  2>/dev/null || echo "")

RESPONSE_BODY=$(cat /tmp/wp-form-response-$$.html 2>/dev/null || echo "")
HTTP_STATUS=$(echo "$RESPONSE_HEADERS" | grep -oP 'HTTP/\S+ \K\d+' | tail -1 || echo "0")
REDIRECT_URL=$(echo "$RESPONSE_HEADERS" | grep -i '^location:' | awk '{print $2}' | tr -d '\r' || echo "")

# ─── Step 7: Evaluate response ────────────────────────────────────────────────
if [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "301" ]; then
  # Check if redirect indicates success
  if echo "$REDIRECT_URL" | grep -qiE 'success|sent|thank|confirm|done'; then
    record "PASS" "Form submitted → success redirect: $REDIRECT_URL"
  else
    record "WARN" "Form redirected to: $REDIRECT_URL (verify this is a success state)"
  fi
elif [ "$HTTP_STATUS" = "200" ]; then
  # Check response body for success indicators
  if echo "$RESPONSE_BODY" | grep -qiE 'success|thank you|message sent|received|confirmation'; then
    record "PASS" "Form submitted → success message found in response"
  elif echo "$RESPONSE_BODY" | grep -qiE 'error|invalid|required|failed|wrong'; then
    record "FAIL" "Form submission returned an error (HTTP $HTTP_STATUS) — check field names"
  else
    record "WARN" "Form returned HTTP 200 — check page manually to confirm success/failure"
  fi
else
  record "FAIL" "Unexpected HTTP status: $HTTP_STATUS"
fi

# ─── Step 8: Check for spam honeypot ─────────────────────────────────────────
if echo "$PAGE_CONTENT" | grep -qi 'hp_\|honeypot\|bot.check\|_gotcha\|website.*display.*none'; then
  record "PASS" "Honeypot spam protection detected"
else
  record "WARN" "No honeypot detected — consider adding spam protection"
fi

# ─── Cleanup ─────────────────────────────────────────────────────────────────
rm -f "$COOKIE_JAR" "/tmp/wp-form-response-$$.html"

# ─── Output ──────────────────────────────────────────────────────────────────
if [ "$JSON_OUTPUT" = true ]; then
  echo "{"
  echo "  \"url\": \"$FORM_URL\","
  echo "  \"pass\": $PASS,"
  echo "  \"fail\": $FAIL,"
  echo "  \"warn\": $WARN,"
  echo "  \"results\": ["
  FIRST=true
  for result in "${RESULTS[@]}"; do
    status="${result%%|*}"
    msg="${result#*|}"
    [ "$FIRST" = true ] && FIRST=false || echo ","
    printf '    {"status": "%s", "message": "%s"}' "$status" "$msg"
  done
  echo ""
  echo "  ]"
  echo "}"
else
  echo ""
  for result in "${RESULTS[@]}"; do
    status="${result%%|*}"
    msg="${result#*|}"
    case "$status" in
      PASS) echo -e "  ${GREEN}✓${NC} $msg";;
      FAIL) echo -e "  ${RED}✗${NC} $msg";;
      WARN) echo -e "  ${YELLOW}⚠${NC}  $msg";;
    esac
  done
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}RESULT: FAIL${NC}  (PASS: $PASS  FAIL: $FAIL  WARN: $WARN)"
  elif [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}RESULT: WARN${NC}  (PASS: $PASS  FAIL: 0  WARN: $WARN)"
  else
    echo -e "${GREEN}RESULT: PASS${NC}  ($PASS checks passed)"
  fi
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
fi

[ "$FAIL" -eq 0 ]
