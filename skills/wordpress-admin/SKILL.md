---
name: wordpress-admin
description: Full WordPress site management - create pages/posts, configure SEO (Yoast), upload media, manage settings. Use when creating content, setting up SEO, or managing any WordPress site.
allowed-tools: Read, Write, Edit, Bash(docker *), Bash(curl *), Bash(python3 *), Bash(lftp *)
---

# WordPress Admin Skill

Complete WordPress site management via WP-CLI (local Docker) and REST API (production sites).

## When to Use This Skill

Invoke this skill when you need to:
- Create pages or posts in WordPress
- Set up SEO (focus keyword, meta description, title)
- Upload and manage media/images
- Configure WordPress settings
- Check or recommend plugins
- Manage the local WordPress Docker environment

## Available Sites

### Production Site
- **Site URL:** `$WORDPRESS_PROD_URL` (set via env var, default: https://example.com)
- **REST API:** `$WORDPRESS_PROD_URL/wp-json/wp/v2`
- **FTP Host:** your FTP host
- **FTP User:** your FTP username
- **Theme Path:** /wp-content/themes/your-theme
- **Local Files:** ~/repos/my-project/public_html

### Local WordPress (Docker)
- **Site URL:** `$WORDPRESS_URL` (default: http://localhost:8080)
- **Container:** `$WORDPRESS_CONTAINER` (default: wordpress-1)
- **WP-CLI:** `docker exec $WORDPRESS_CONTAINER wp <command> --allow-root`
- **Admin:** `$WORDPRESS_URL/wp-admin`
- **Credentials:** admin / admin (default; set via .env)

## Workflows

### Create a Page

**Local (Docker):**
```bash
docker exec $WORDPRESS_CONTAINER wp post create \
  --post_type=page \
  --post_title="Privacy Policy" \
  --post_name="privacy-policy" \
  --post_status="publish" \
  --allow-root
```

**Production (REST API):**
```bash
curl -X POST "$WORDPRESS_PROD_URL/wp-json/wp/v2/pages" \
  -H "Authorization: Basic BASE64_CREDENTIALS" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Privacy Policy",
    "slug": "privacy-policy",
    "status": "publish",
    "template": "page-privacy-policy.php"
  }'
```

### Set Page Template

```bash
docker exec $WORDPRESS_CONTAINER wp post meta update <POST_ID> _wp_page_template "page-privacy-policy.php" --allow-root
```

### Configure SEO (Yoast)

**Requirements:** Theme must have Yoast meta fields registered (see functions.php snippet below)

```bash
# Set focus keyphrase
docker exec $WORDPRESS_CONTAINER wp post meta update <POST_ID> _yoast_wpseo_focuskw "privacy policy miami real estate" --allow-root

# Set meta description (155 chars max, include focus keyword)
docker exec $WORDPRESS_CONTAINER wp post meta update <POST_ID> _yoast_wpseo_metadesc "Learn how CSR Real Estate protects your privacy and handles personal information on our Miami real estate development website." --allow-root

# Set SEO title
docker exec $WORDPRESS_CONTAINER wp post meta update <POST_ID> _yoast_wpseo_title "Privacy Policy | CSR Real Estate" --allow-root
```

### Upload Media

**From URL:**
```bash
docker exec $WORDPRESS_CONTAINER wp media import "https://images.pexels.com/photos/123456/image.jpg" --title="Privacy Header" --allow-root
```

**Set Featured Image:**
```bash
docker exec $WORDPRESS_CONTAINER wp post meta update <POST_ID> _thumbnail_id <MEDIA_ID> --allow-root
```

### List Pages/Posts

```bash
docker exec $WORDPRESS_CONTAINER wp post list --post_type=page --allow-root
docker exec $WORDPRESS_CONTAINER wp post list --post_type=post --allow-root
docker exec $WORDPRESS_CONTAINER wp post list --post_type=property --allow-root
```

### Check/Install Plugins

```bash
# List installed plugins
docker exec $WORDPRESS_CONTAINER wp plugin list --allow-root

# Install and activate a plugin
docker exec $WORDPRESS_CONTAINER wp plugin install wordpress-seo --activate --allow-root
```

## SEO Best Practices

### Focus Keyphrase
- 2-4 words that describe the page content
- Should appear in title, meta description, and content
- Use naturally, don't keyword stuff

### Meta Description
- 150-155 characters max
- Include focus keyphrase
- Compelling call to action
- Unique for each page

### Page Title (SEO Title)
- 50-60 characters max
- Focus keyphrase near the beginning
- Brand name at the end (e.g., "Title | CSR Real Estate")

### Featured Image
- Every page/post should have one
- Optimized file size (< 200KB)
- Descriptive alt text with keyphrase

## Required Theme Modification

Add to theme's `functions.php` to enable Yoast fields via REST API:

```php
// Enable Yoast SEO fields in REST API
function enable_yoast_rest_api() {
    $post_types = ['post', 'page', 'property'];
    foreach ($post_types as $type) {
        register_post_meta($type, '_yoast_wpseo_focuskw', [
            'show_in_rest' => true,
            'single' => true,
            'type' => 'string'
        ]);
        register_post_meta($type, '_yoast_wpseo_metadesc', [
            'show_in_rest' => true,
            'single' => true,
            'type' => 'string'
        ]);
        register_post_meta($type, '_yoast_wpseo_title', [
            'show_in_rest' => true,
            'single' => true,
            'type' => 'string'
        ]);
    }
}
add_action('init', 'enable_yoast_rest_api');
```

## Stock Photo Integration

### Pexels API
- **API Key:** Store in the `PEXELS_API_KEY` environment variable
- **Search:** `curl -H "Authorization: API_KEY" "https://api.pexels.com/v1/search?query=TERM&per_page=5"`
- **Download:** Use the `src.large` or `src.original` URL from response

### Unsplash API
- **API Key:** Store in the `UNSPLASH_ACCESS_KEY` environment variable
- **Search:** `curl "https://api.unsplash.com/search/photos?query=TERM&client_id=API_KEY"`

## Scripts

### wp-page.py
Creates a WordPress page with optional SEO and featured image.

**Usage:**
```bash
python3 ./scripts/wp-page.py \
  --site local \
  --title "Privacy Policy" \
  --slug "privacy-policy" \
  --template "page-privacy-policy.php" \
  --focus-kw "privacy policy" \
  --meta-desc "Description here"
```

### wp-seo.py
Sets Yoast SEO fields for existing posts/pages.

**Usage:**
```bash
python3 ./scripts/wp-seo.py \
  --site local \
  --post-id 123 \
  --focus-kw "keyword" \
  --meta-desc "Description" \
  --seo-title "SEO Title"
```

### wp-media.py
Downloads stock photo and uploads to WordPress.

**Usage:**
```bash
python3 ./scripts/wp-media.py \
  --site local \
  --search "miami skyline" \
  --set-featured 123
```

## Docker Management

### Start Local WordPress
```bash
cd ~/repos/my-project && docker-compose up -d
```

### Stop Local WordPress
```bash
cd ~/repos/my-project && docker-compose down
```

### View Logs
```bash
docker logs $WORDPRESS_CONTAINER -f
```

### Reset Database
```bash
cd ~/repos/my-project && docker-compose down -v && docker-compose up -d
```

## FTP Sync (Production)

### Sync Theme Files
```bash
~/repos/my-project/sync-to-remote.sh
```

### Upload Single File
```bash
lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << 'EOF'
set ssl:verify-certificate no
cd /public_html/wp-content/themes/your-theme
put ~/repos/my-project/public_html/wp-content/themes/your-theme/FILE.php
bye
EOF
```

## Common Tasks

### Create Privacy Policy Page
1. Create page with slug `privacy-policy`
2. Set template to `page-privacy-policy.php`
3. Set focus keyphrase: "CSR privacy policy"
4. Set meta description (~155 chars with keyphrase)
5. Upload relevant featured image

### Create Terms of Service Page
1. Create page with slug `terms`
2. Set template to `page-terms.php`
3. Set focus keyphrase: "CSR terms of service"
4. Set meta description (~155 chars with keyphrase)
5. Upload relevant featured image

## Reference

- **WordPress REST API:** https://developer.wordpress.org/rest-api/
- **WP-CLI Commands:** https://developer.wordpress.org/cli/commands/
- **Yoast SEO API:** https://developer.yoast.com/customization/apis/
- **Pexels API:** https://www.pexels.com/api/documentation/
