---
name: wp-launch
description: Run the complete pre-launch checklist for a WordPress site. Verifies SEO, performance, security, forms, analytics, and content, then generates a client handoff document.
allowed-tools: Read, Write, Edit, Bash, Task, Glob, Grep, WebFetch, AskUserQuestion, TodoWrite
---

# WordPress Pre-Launch Checklist

You are the WordPress project orchestrator. Run the complete pre-launch checklist and generate a client handoff document.

## Step 1 — Gather Launch Details

Ask the user (using AskUserQuestion):

- **Site URL** (production URL, with HTTPS)
- **Client/site name**
- **Docker container name** (if still on local — for final checks)
- **Is this a client handoff or internal launch?**
- **Client admin email** (for handoff docs)
- **Support contact** (your agency email or phone)

## Step 2 — Pre-Launch Verification Checklist

Work through this checklist systematically. Mark each item as complete or note any issues found.

### Content & Pages
```bash
# List all published pages
docker exec "$CONTAINER" wp post list --post_type=page --post_status=publish \
  --fields=ID,post_title,post_name --format=table --allow-root
```
- [ ] All required pages exist and are published
- [ ] No placeholder content ("Lorem ipsum", "Coming soon", "TBD")
- [ ] Home page is set as the static front page
- [ ] 404 (not found) page has useful content and navigation
- [ ] All internal links work (no broken links)
- [ ] No "sample page" or default WordPress content remains

### SEO — Final Check
```bash
# Locate skills root (set WP_SKILLS_ROOT env var to override)
_f="${BASH_SOURCE[0]:-$0}"; [ -L "$_f" ] && _f="$(readlink -f "$_f")"
SKILLS_ROOT="${WP_SKILLS_ROOT:-$(cd "$(dirname "$_f")/.." && pwd)}"
python3 "$SKILLS_ROOT/skills/seo-optimizer/audit.py" \
  --base-url "$SITE_URL" 2>/dev/null
```
- [ ] Every published page has a focus keyword
- [ ] Every published page has a meta description (120–160 chars)
- [ ] Every published page has a featured image with ALT text
- [ ] XML sitemap is accessible at `/sitemap.xml` or `/sitemap_index.xml`
- [ ] Robots.txt is accessible and not blocking search engines
- [ ] Search engine visibility is **enabled** (Settings → Reading → uncheck "Discourage search engines")

### Images & Media
- [ ] Site logo uploaded (Settings → Customize → Site Identity)
- [ ] Favicon (site icon) uploaded
- [ ] Social sharing / Open Graph images set per page
- [ ] All images are optimized (EWWW or similar active)
- [ ] No images with missing ALT text on public-facing pages

### Performance
- [ ] Caching plugin active and configured (LiteSpeed Cache, W3 Total Cache, etc.)
- [ ] Image lazy loading enabled
- [ ] CSS/JS minification enabled
- [ ] PageSpeed Insights score ≥ 80 (mobile and desktop)
  ```bash
  # Quick PageSpeed check
  curl -s "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=${SITE_URL}&strategy=mobile" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('Mobile:', d['lighthouseResult']['categories']['performance']['score']*100)"
  ```

### Forms & Email
- [ ] All contact/inquiry forms tested — submission works
- [ ] Email delivery verified (check spam folder)
  ```bash
  bash "$SKILLS_ROOT/skills/form-testing/scripts/test-mail.sh" "$CONTAINER" "$CLIENT_EMAIL"
  ```
- [ ] Thank-you / confirmation pages configured
- [ ] Form submissions going to the right email address

### Security
```bash
# WordPress and plugin updates
docker exec "$CONTAINER" wp core check-update --allow-root
docker exec "$CONTAINER" wp plugin list --update=available --format=table --allow-root
docker exec "$CONTAINER" wp theme list --update=available --format=table --allow-root
```
- [ ] WordPress core is up to date
- [ ] All plugins up to date
- [ ] Active theme up to date
- [ ] Inactive themes and plugins deleted
- [ ] Default "admin" username not in use
- [ ] Custom login URL active (not `/wp-login.php`)
- [ ] XML-RPC disabled
- [ ] File editor disabled in admin (`DISALLOW_FILE_EDIT` in wp-config or via ASE)
- [ ] SSL certificate active (HTTPS, no mixed content)
- [ ] Automatic security updates enabled for minor core releases

### Backups & Monitoring
- [ ] Backup plugin configured and tested (UpdraftPlus, Solid Backups, or host backup)
- [ ] Backup schedule set (daily or weekly minimum)
- [ ] Backup storage is offsite (S3, Google Drive, Dropbox)
- [ ] Uptime monitoring set up (UptimeRobot, Jetpack, or host monitoring)

### Analytics & Tracking
- [ ] Google Analytics or equivalent installed and tracking
- [ ] Google Search Console verified (site ownership confirmed)
- [ ] Analytics events tested (form submissions, button clicks if applicable)

### White Label (client sites)
- [ ] Custom login URL set
- [ ] Branda login page configured (client logo, brand colors)
- [ ] Admin bar does not show WordPress branding
- [ ] Dashboard is clean (no irrelevant widgets)
- [ ] Admin menu organized (only relevant items visible to client)

### Visual QA — Final
```bash
python3 "$SKILLS_ROOT/skills/visual-qa/screenshot.py" \
  --all \
  --base-url "$SITE_URL" \
  --output /tmp/launch-screenshots-$(date +%Y%m%d)
```
- [ ] Desktop layout correct (1920, 1440, 1280)
- [ ] Tablet layout correct (1024, 768)
- [ ] Mobile layout correct (390, 375, 412)
- [ ] All animations working
- [ ] No horizontal scroll on any viewport
- [ ] No overlapping elements

### DNS & Hosting (production deployment)
- [ ] Domain DNS pointing to correct hosting
- [ ] SSL certificate valid and auto-renewing
- [ ] WordPress Site URL and Home URL set to production URL
  ```bash
  docker exec "$CONTAINER" wp option get siteurl --allow-root
  docker exec "$CONTAINER" wp option get home --allow-root
  ```
- [ ] No references to local dev URL remain (search-replace if needed)
  ```bash
  # If migrating from local to production:
  docker exec "$CONTAINER" wp search-replace 'http://localhost:8080' 'https://yourdomain.com' --all-tables --allow-root
  ```

## Step 3 — Generate Client Handoff Document

Create a `HANDOFF.md` in the project root:

```markdown
# Website Handoff — [Client Name]

**Date**: [Today's Date]
**Site**: [Production URL]
**Prepared by**: [Your Name / Agency]

---

## Admin Access

| Item | Value |
|------|-------|
| Admin URL | [SITE_URL]/[custom-login-slug]/ |
| Username | (provided separately) |
| Password | (provided separately — please change after first login) |

> **Security note**: Bookmark the custom login URL. The default `/wp-login.php` is disabled.

---

## How to Edit Content

### Pages
1. Log in to the admin area
2. Click **Pages** in the left menu
3. Click the page you want to edit
4. Make your changes in the editor
5. Click **Update** to save

### Blog Posts
1. Click **Posts** → **Add New**
2. Enter title and content
3. Set a featured image (right sidebar → Featured image)
4. Add categories and tags
5. Click **Publish**

### Images
1. Click **Media** → **Add New**
2. Drag and drop images (they are automatically optimized)
3. Always fill in the **Alt Text** field for accessibility and SEO

---

## SEO Guidelines

- Every page needs a **Focus Keyword** (set in the Yoast/Rank Math panel below the editor)
- **Meta descriptions** should be 120–160 characters and include the focus keyword
- **Featured images** should have descriptive ALT text including the focus keyword
- The Yoast/Rank Math plugin will show a traffic light: aim for **green**

---

## What to Do When Things Break

1. **Site is down**: Contact your hosting provider — [Hosting name and support URL]
2. **Forgot login**: Go to `[SITE_URL]/wp-login.php?action=lostpassword` (temporary — login URL is normally locked)
3. **Plugin conflict**: Deactivate plugins one by one to isolate the cause
4. **Need help**: Contact us at [Support email] or [Phone]

---

## Plugin Summary

| Plugin | Purpose |
|--------|---------|
| Admin and Site Enhancements | Security, admin cleanup |
| Branda | Login page branding |
| Yoast SEO / Rank Math | Search engine optimization |
| LiteSpeed Cache | Site speed |
| EWWW Image Optimizer | Image compression |
| WP Mail SMTP | Email delivery |

---

## Backups

Your site is automatically backed up [daily/weekly] to [Dropbox/S3/Google Drive].
To restore a backup: Contact us or use [Backup plugin name] → Restore.

---

*Document generated by Claude Code using the wordpress-dev-skills plugin.*
*[https://github.com/salemaziel/wordpress-dev-skills](https://github.com/salemaziel/wordpress-dev-skills)*
```

## Step 4 — Launch Summary

When all checklist items pass, tell the user:

- ✅ **Pre-launch checklist complete**
- List any items that need attention before going live
- Provide the `HANDOFF.md` location
- Remind them to:
  1. Change the admin password after first login
  2. Keep all plugins and WordPress core updated
  3. Check Google Search Console in 1–2 weeks for crawl status
  4. Schedule a monthly performance and security review (run `/wp-audit`)
