---
name: wp-setup
description: Set up a new WordPress site with Docker, install essential plugins, and configure white-labeling. Runs a discovery interview, creates a project todo list, spins up the Docker environment, installs recommended plugins, and applies initial ASE security and white-label configuration.
allowed-tools: Read, Write, Edit, Bash, Task, Glob, Grep, WebFetch, AskUserQuestion, TodoWrite
---

# WordPress Site Setup

You are the WordPress project orchestrator. Run a complete new-site setup workflow.

## Step 1 — Discovery Interview

Ask the user (using AskUserQuestion) for the following details. Ask all at once if possible:

- **Project name** (used for Docker container names, folder name)
- **Site URL** for local development (e.g. `http://localhost:8080` or `https://local.mysite.dev`)
- **Site title**
- **Admin username** and **admin email**
- **Hosting environment**: Docker local, SiteGround, WP Engine, other?
- **Custom post types needed?** List them.
- **Pages needed?** (Home, About, Contact, etc.)
- **Do you have brand assets?** (logo, colors, fonts)
- **White-label admin for client?** (yes/no)
- **Preferred SEO plugin**: Yoast SEO or Rank Math?

Store answers in a TodoWrite todo list and in a `project-config.json` file at the project root.

## Step 2 — Create Project Todo List

Use TodoWrite to create a comprehensive checklist:

```
## Foundation
- [ ] Docker environment started
- [ ] WordPress installed and configured
- [ ] Permalinks set to /%postname%/
- [ ] Default sample post/page deleted

## Plugins
- [ ] Admin and Site Enhancements (ASE) — admin cleanup, custom login URL, security
- [ ] Branda — login page branding (logo, colors, background)
- [ ] Admin Menu Editor — menu organization
- [ ] Yoast SEO / Rank Math — SEO
- [ ] LiteSpeed Cache — performance/caching
- [ ] EWWW Image Optimizer — image compression
- [ ] WP Mail SMTP — email delivery
- [ ] Instant Images — stock photos for content
- [ ] Duplicate Post — content workflow
- [ ] WP Activity Log — audit trail

## Pages
- [ ] Home page created
- [ ] About page created
- [ ] Contact page created
- [ ] Privacy Policy page created
- [ ] Terms of Service page created
- [ ] Home page set as static front page

## White Label
- [ ] Custom login URL configured (/client-login or similar)
- [ ] XML-RPC disabled
- [ ] Author slugs obfuscated
- [ ] Branda login page configured (logo, colors)
- [ ] Admin bar branded
- [ ] Dashboard widgets cleaned up
- [ ] Admin menu organized

## SEO Baseline
- [ ] Sitemaps enabled
- [ ] Robots.txt configured
- [ ] Site discourage search engines = OFF (when ready for indexing)
- [ ] Focus keyword set on each page
- [ ] Meta descriptions written (120–160 chars)
- [ ] Featured images added

## Performance
- [ ] LiteSpeed Cache configured
- [ ] Image optimization enabled
- [ ] Lazy loading enabled
- [ ] Heartbeat API configured

## Security
- [ ] Login URL changed from /wp-login.php
- [ ] 2FA configured for admin
- [ ] File editor disabled
- [ ] Automatic updates for minor releases enabled
- [ ] Backup plugin configured

## Launch
- [ ] All pages reviewed
- [ ] Forms tested (submit + email delivery)
- [ ] Analytics installed
- [ ] SSL active
- [ ] 404 page configured
- [ ] Favicon uploaded
- [ ] Social sharing images set
```

## Step 3 — Environment Setup

### Docker (if selected)

Copy the Docker templates from the wp-docker skill:

```bash
# Locate skills root (set WP_SKILLS_ROOT env var to override)
_f="${BASH_SOURCE[0]:-$0}"; [ -L "$_f" ] && _f="$(readlink -f "$_f")"
SKILLS_ROOT="${WP_SKILLS_ROOT:-$(cd "$(dirname "$_f")/.." && pwd)}"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

cp "$SKILLS_ROOT/skills/wp-docker/templates/docker-compose.yml" "$PROJECT_DIR/"
cp "$SKILLS_ROOT/skills/wp-docker/templates/uploads.ini" "$PROJECT_DIR/"
cp "$SKILLS_ROOT/skills/wp-docker/templates/.env.example" "$PROJECT_DIR/.env"
```

Edit `.env` with the project details from Step 1, then:

```bash
docker compose up -d
docker compose logs -f wordpress   # wait until "ready"
```

Run the setup script:

```bash
bash "$SKILLS_ROOT/skills/wp-docker/templates/wp-setup.sh" \
  "$SITE_URL" "$SITE_TITLE" "$ADMIN_USER" "$ADMIN_PASS" "$ADMIN_EMAIL"
```

### SiteGround / Existing WordPress

If the site already exists, skip Docker and proceed directly to plugin installation using WP-CLI or the WordPress admin UI.

## Step 4 — Install Plugins

Via WP-CLI in Docker:

```bash
CONTAINER="${PROJECT_NAME}-wordpress-1"
docker exec "$CONTAINER" wp plugin install \
  admin-site-enhancements \
  branda-white-labeling \
  admin-menu-editor \
  wordpress-seo \
  litespeed-cache \
  ewww-image-optimizer \
  wp-mail-smtp \
  instant-images \
  duplicate-post \
  wp-activity-log \
  --activate --allow-root
```

## Step 5 — Apply ASE Security Configuration

```bash
docker exec "$CONTAINER" wp option update admin_site_enhancements '{
  "change_login_url": {"enabled": true, "slug": "client-login"},
  "disable_xmlrpc": true,
  "obfuscate_author_slugs": true,
  "hide_admin_notices": true,
  "disable_dashboard_widgets": {"welcome": true, "quick_draft": true, "wordpress_news": true},
  "heartbeat_control": {"dashboard": "disable", "frontend": "disable", "post_editor": 30},
  "revisions_control": 5
}' --format=json --allow-root
```

## Step 6 — White Label (if requested)

If the user requested client white-labeling, run the white-label skill:

```bash
# Locate skills root (set WP_SKILLS_ROOT env var to override)
_f="${BASH_SOURCE[0]:-$0}"; [ -L "$_f" ] && _f="$(readlink -f "$_f")"
SKILLS_ROOT="${WP_SKILLS_ROOT:-$(cd "$(dirname "$_f")/.." && pwd)}"
bash "$SKILLS_ROOT/skills/white-label/scripts/apply-white-label.sh" \
  "" "$CONTAINER"
```

## Step 7 — Summary

When complete, tell the user:

- ✅ Site URL and admin URL
- ✅ Custom login URL
- ✅ Admin credentials (remind them to change the password)
- ✅ List of installed plugins
- ✅ Next steps: add content, configure SEO, run `/wp-audit`
