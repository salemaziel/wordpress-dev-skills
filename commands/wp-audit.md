---
name: wp-audit
description: Run a comprehensive WordPress site audit covering SEO, performance, visual QA, security, and plugin health. Launches parallel audit agents and compiles a prioritized action plan with a TodoWrite checklist.
allowed-tools: Read, Write, Edit, Bash, Task, Glob, Grep, WebFetch, AskUserQuestion, TodoWrite
---

# WordPress Site Audit

You are the WordPress project orchestrator. Run a comprehensive site audit.

## Step 1 — Gather Site Information

Ask the user (using AskUserQuestion):

- **Site URL** (staging or production)
- **WordPress admin URL** (if different)
- **Docker container name** (if running locally via Docker)
- **Specific concerns?** (e.g. slow loading, broken pages, SEO issues)

## Step 2 — Environment Detection

Detect the WordPress environment:

```bash
# Docker check
if docker ps 2>/dev/null | grep -q wordpress; then
  echo "Docker WordPress detected"
  CONTAINER=$(docker ps --format '{{.Names}}' | grep wordpress | grep -v db | head -1)
fi

# Local wp-config.php
if [ -f wp-config.php ]; then
  echo "Local WordPress installation detected"
fi

# Playground
if [ -f blueprint.json ] || [ -d blueprints/ ]; then
  echo "WordPress Playground blueprint detected"
fi
```

## Step 3 — Run Parallel Audits

Launch the following checks. Use parallel Task agents where available:

### SEO Audit

```bash
# Locate skills root (set WP_SKILLS_ROOT env var to override)
_f="${BASH_SOURCE[0]:-$0}"; [ -L "$_f" ] && _f="$(readlink -f "$_f")"
SKILLS_ROOT="${WP_SKILLS_ROOT:-$(cd "$(dirname "$_f")/.." && pwd)}"
python3 "$SKILLS_ROOT/skills/seo-optimizer/audit.py" \
  --base-url "$SITE_URL" \
  --json > /tmp/seo-audit.json 2>/tmp/seo-audit.err
cat /tmp/seo-audit.json
```

Key checks:
- Focus keyword set on each page?
- Meta description present and 120–160 chars?
- Focus keyword in meta description?
- Featured image with ALT text set?
- SEO title 50–60 chars?

### Visual QA

```bash
python3 "$SKILLS_ROOT/skills/visual-qa/screenshot.py" \
  --all \
  --base-url "$SITE_URL" \
  --output /tmp/screenshots-$(date +%Y%m%d)
```

Review screenshots for:
- Layout breakage at any viewport
- Animations firing correctly
- Images loading
- No overflow or horizontal scroll on mobile

### Performance Check

```bash
# PageSpeed Insights (mobile + desktop)
curl -s "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=${SITE_URL}&strategy=mobile" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); cats=d['lighthouseResult']['categories']; [print(f'{k}: {v[\"score\"]*100:.0f}') for k,v in cats.items()]"

curl -s "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=${SITE_URL}&strategy=desktop" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); cats=d['lighthouseResult']['categories']; [print(f'{k}: {v[\"score\"]*100:.0f}') for k,v in cats.items()]"
```

Key checks (via Docker WP-CLI if available):
- LiteSpeed Cache or other caching active?
- Image optimization enabled?
- Asset minification enabled?
- External fonts/scripts deferred?

### Security Audit

Via WP-CLI (Docker):

```bash
# Check for updates
docker exec "$CONTAINER" wp core check-update --allow-root
docker exec "$CONTAINER" wp plugin list --update=available --format=table --allow-root
docker exec "$CONTAINER" wp theme list --update=available --format=table --allow-root

# Check user list (alert on default "admin" username)
docker exec "$CONTAINER" wp user list --format=table --allow-root

# Check login URL (ASE)
docker exec "$CONTAINER" wp option get admin_site_enhancements --format=json --allow-root \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Login URL slug:', d.get('change_login_url',{}).get('slug','wp-login.php (DEFAULT!)'))"
```

### Plugin Health Check

```bash
docker exec "$CONTAINER" wp plugin list --format=table --allow-root
docker exec "$CONTAINER" wp plugin list --status=inactive --format=table --allow-root
```

### Form & Email Test

If WP Mail SMTP is installed:

```bash
# Locate skills root (set WP_SKILLS_ROOT env var to override)
_f="${BASH_SOURCE[0]:-$0}"; [ -L "$_f" ] && _f="$(readlink -f "$_f")"
SKILLS_ROOT="${WP_SKILLS_ROOT:-$(cd "$(dirname "$_f")/.." && pwd)}"
bash "$SKILLS_ROOT/skills/form-testing/scripts/test-mail.sh" \
  "$CONTAINER" "admin@example.com"
```

## Step 4 — Compile Results and Generate Action Plan

After all audits complete, compile findings and create a prioritized action plan using TodoWrite:

### Critical (Fix immediately)
Issues that affect security, indexing, or core functionality:
- WordPress or plugin updates available
- Default "admin" username in use
- Login URL still `/wp-login.php`
- XML-RPC not disabled
- Site set to discourage search engines (if meant to be live)

### High Priority (Fix this week)
SEO and performance issues:
- Pages missing focus keywords
- Pages missing meta descriptions
- Missing featured images
- No caching active
- PageSpeed < 50

### Medium Priority (Fix this sprint)
- Meta descriptions too short or too long
- Focus keyword not in meta description
- Image ALT text missing
- LiteSpeed Cache not fully configured
- Inactive plugins not removed

### Low Priority (Nice to have)
- PageSpeed 50–79 (target 80+)
- Minor visual QA notes
- Admin UI cleanup

## Step 5 — Audit Report

Output an audit report in this format:

```markdown
# WordPress Site Audit Report

**Site**: [URL]
**Date**: [Date]
**Auditor**: Claude Code via wordpress-dev-skills

## Scores
| Category        | Score | Target |
|----------------|-------|--------|
| SEO             | ?/100 | 80+    |
| Performance     | ?/100 | 80+    |
| Security        | ?/10  | 10/10  |
| Plugin Health   | ?     | All up to date |

## Critical Issues
(list)

## High Priority
(list)

## Medium Priority
(list)

## Next Steps
1. Run `/wp-launch` when all critical and high issues are resolved
2. Schedule regular audits (monthly recommended)
```

When done, tell the user the todo list has been created and point them to the full report.
