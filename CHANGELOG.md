# Changelog

All notable changes to the WordPress Development Skills package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-05-21

### Added

#### Multi-agent packaging and marketplace support
- `.claude-plugin/plugin.json` — primary Claude Code manifest
- `.codex-plugin/plugin.json` — Codex CLI manifest
- `gemini-extension.json` — Gemini-style extension metadata
- `.agents/plugins/marketplace.json` — local dev fixture (points to canonical marketplace)
- `.github/plugin/marketplace.json` — GitHub Copilot CLI local dev fixture
- `docs/marketplace.md` — marketplace publishing guide
- `COMPLETENESS_AUDIT.md` — full audit of repo state and packaging work
- `scripts/validate-plugin-layout.sh` — validates all manifests, versions, and required files
- `marketplace-submission/vdw-claude-plugins/` — marketplace submission package for canonical marketplace

#### Skills added to manifests
- `form-testing` — WordPress form email delivery testing (was present in repo but not listed)
- `wp-test-analyzer` — E2E test generation and analysis (was present in repo but not listed)

#### Repository metadata corrections
- Updated `plugin.json`: author changed to "Salem Aziel", repository URL updated to `https://github.com/salemaziel/wordpress-dev-skills`, marketplace URL added
- Updated `install.sh`: repository URL corrected to `https://github.com/salemaziel/wordpress-dev-skills`
- Updated `README.md`: all URLs updated, multi-agent installation docs added, marketplace info added

---

## [1.3.0] - 2025-12-28

### Added

#### wp-docker skill (NEW)
- Docker Compose templates for WordPress development
- MariaDB 10.11 with health checks
- WordPress PHP 8.3 Apache image
- WP-CLI container for automation
- Complete `wp-setup.sh` automated installation script
- Environment variable configuration via `.env`
- Custom `uploads.ini` for 64MB file uploads
- Plugin installation and ASE configuration automation

#### wp-playground skill (NEW)
- WordPress Playground blueprint documentation
- Base blueprint with ASE, Branda, Yoast, Instant Images
- WooCommerce blueprint with Storefront theme
- CLI usage with `@wp-playground/cli`
- URL parameter reference for quick testing
- Snapshot export functionality

#### white-label skill (REPLACES ase-config)
- Renamed from `ase-config` to `white-label`
- Added Branda plugin configuration for login page customization
- Added Admin Menu Editor integration
- Complete FREE-only white-labeling guide (no paid plugins required)
- WP-CLI automation scripts for programmatic configuration
- Client handoff checklist

#### Slash Commands (NEW)
- `/wp-setup` - Complete WordPress site setup workflow
- `/wp-audit` - Comprehensive site audit with parallel agents
- `/wp-launch` - Pre-launch checklist and handoff documentation

#### wp-orchestrator updates
- Added environment detection (Docker, Playground, Standard WP)
- Integrated slash command references
- Updated skill list with new skills
- Updated plugin installation list with Branda

#### Hooks configuration
- WordPress session initialization hook script
- Docker-compose startup notifications
- Enhanced PostToolUse hooks for WordPress operations

---

## [1.2.0] - 2024-12-28

### Added

#### gsap-animations skill (NEW)
- WordPress GSAP/ScrollTrigger enqueue patterns
- Animation patterns (fade, stagger, parallax, text reveal, curtain)
- Accessibility with `prefers-reduced-motion` support
- Responsive animations with `gsap.matchMedia()`
- Visual QA integration with `completeAllAnimations()` helper
- Reusable animation library with data attributes

#### wp-performance skill (NEW)
- Core Web Vitals targets (LCP < 2.5s, INP < 200ms, CLS < 0.1)
- EWWW Image Optimizer configuration guide
- FFmpeg video compression commands (H.264/H.265)
- LiteSpeed Cache optimization settings
- CSS/JS defer and minification patterns
- Database optimization SQL queries
- Automated speed testing script

#### wp-orchestrator skill (NEW)
- Master skill coordinating all WordPress skills
- Discovery interview phases (project type, requirements, brand)
- Site audit workflows (SEO, visual, performance, security)
- Todo list generation for project phases
- Parallel agent patterns using Haiku sub-agents
- Audit report and handoff documentation templates
- Pre-launch checklist generation
- Quick reference command mapping

---

## [1.1.0] - 2024-12-28

### Added

#### ase-config skill (NEW)
- Complete ASE plugin configuration guide
- White labeling setup (admin logo, footer, login page)
- Security hardening (custom login URL, XML-RPC disable, author slug obfuscation)
- Admin cleanup (notices, widgets, menu organization)
- Performance optimization (heartbeat, revisions, image control)
- Pro vs Free feature matrix
- Export/import configuration templates

#### wordpress-dev updates
- Added `recommended-plugins.md` documentation
- Core plugin stack: ASE, LiteSpeed Cache, Yoast SEO, WP Mail SMTP, Solid Security, EWWW
- Management plugins: ManageWP Worker, Site Kit, WP Activity Log
- Content plugins: Classic Editor, Duplicate Post, Instant Images
- Installation order and configuration checklist

---

## [1.0.0] - 2024-12-28

### Added

#### wordpress-dev skill
- Comprehensive SKILL.md with best practices overview
- Documentation files:
  - `coding-standards.md` - PHP, JS, CSS conventions
  - `custom-post-types.md` - CPT registration guide
  - `security.md` - Input/output handling, nonces, SQL safety
  - `performance.md` - Caching, optimization, asset loading
  - `hooks-filters.md` - Actions and filters reference
  - `template-hierarchy.md` - Theme template structure
- Code templates:
  - `custom-post-type.php` - CPT registration boilerplate
  - `taxonomy.php` - Custom taxonomy registration
  - `meta-box.php` - Admin meta box with save handling
  - `rest-api-endpoint.php` - Custom REST API endpoints
  - `plugin-skeleton/` - Complete plugin starter files
- `scaffold.py` - Code generation script for CPTs, taxonomies, meta boxes

#### seo-optimizer skill
- SEO audit script for Yoast/Rank Math
- Direct database access for meta fields
- Focus keyword validation
- Meta description quality checks
- Featured image presence verification
- Unsplash integration for missing images

#### visual-qa skill
- Playwright-based screenshot automation
- 10 viewport configurations (desktop, tablet, mobile)
- GSAP/ScrollTrigger animation handling
- Full-page scroll before capture
- Parallel analysis support with Haiku agents

#### wordpress-admin skill
- Page/post management via REST API
- WP-CLI command reference
- Yoast SEO configuration
- Media upload handling

#### brand-guide skill
- Brand documentation generation
- Color palette documentation
- Typography guidelines
- Voice/tone specifications

### Plugin Bundle
- `plugin.json` manifest with all skill metadata
- `README.md` installation documentation
- `install.sh` installation script
- `CHANGELOG.md` version history

## [Unreleased]

### Roadmap
- Block theme / theme.json development guidance
- ACF field group templates
- WooCommerce development patterns
- Migration support workflows
- Accessibility audit skill
