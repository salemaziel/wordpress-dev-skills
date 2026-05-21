# WordPress Development Skills for Claude Code

A comprehensive WordPress development and automation toolkit for Claude Code, Codex CLI, GitHub Copilot CLI, and Gemini-style extension consumers. Set up complete WordPress sites with a single command — using Docker or Playground environments — with white-labeling (FREE plugins only), SEO, visual QA, performance optimization, and more.

**Plugin source:** <https://github.com/salemaziel/wordpress-dev-skills>  
**Canonical marketplace:** <https://github.com/salemaziel/vdw-claude-plugins>

---

## Quick Start

```bash
# Set up a new WordPress site
/wp-setup

# Audit an existing site
/wp-audit

# Pre-launch checklist
/wp-launch
```

---

## Skills Included

| Skill | Description |
|-------|-------------|
| **wp-orchestrator** | Master orchestrator — coordinates all skills and slash commands |
| **wp-docker** | Docker Compose WordPress environment with WP-CLI |
| **wp-playground** | WordPress Playground blueprints for instant browser-based testing |
| **white-label** | FREE white-labeling with ASE + Branda + Admin Menu Editor |
| **wordpress-dev** | Development best practices, coding standards, CPT creation |
| **wordpress-admin** | Page/post management, WP-CLI, REST API operations |
| **seo-optimizer** | Yoast/Rank Math audit — focus keywords, meta descriptions |
| **visual-qa** | Screenshot automation with GSAP animation handling |
| **brand-guide** | Brand documentation — colors, fonts, imagery, voice/tone |
| **gsap-animations** | GSAP best practices, accessibility, responsive animations |
| **wp-performance** | Core Web Vitals, image/video optimization, caching |
| **siteground-cache** | SiteGround cache buster for development workflows |
| **form-testing** | Form email delivery testing and mail server diagnostics |
| **wp-test-analyzer** | E2E test generation and analysis for WordPress sites |

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/wp-setup` | Set up a new WordPress site with Docker, install plugins, configure white-labeling |
| `/wp-audit` | Comprehensive site audit — SEO, performance, security, visual QA in parallel |
| `/wp-launch` | Pre-launch checklist and handoff documentation generation |

---

## Installation

## Installation

### Install Script (all tools)

```bash
# Claude Code (default)
curl -sL https://raw.githubusercontent.com/salemaziel/wordpress-dev-skills/main/install.sh | bash

# Codex CLI
curl -sL https://raw.githubusercontent.com/salemaziel/wordpress-dev-skills/main/install.sh | bash -s -- --tool codex

# Gemini CLI
curl -sL https://raw.githubusercontent.com/salemaziel/wordpress-dev-skills/main/install.sh | bash -s -- --tool gemini

# GitHub Copilot CLI
curl -sL https://raw.githubusercontent.com/salemaziel/wordpress-dev-skills/main/install.sh | bash -s -- --tool copilot

# Custom path
curl -sL https://raw.githubusercontent.com/salemaziel/wordpress-dev-skills/main/install.sh | bash -s -- --skills-dir ~/my-path
```

### Method 1: Git Clone (Recommended — Claude Code)

```bash
git clone https://github.com/salemaziel/wordpress-dev-skills.git ~/.claude/skills/wordpress-dev-skills
```

Or clone and symlink individual skills:

```bash
git clone https://github.com/salemaziel/wordpress-dev-skills.git ~/repos/wordpress-dev-skills
ln -s ~/repos/wordpress-dev-skills/skills/* ~/.claude/skills/
```

### Method 2: Manual Download

1. Download the [latest release](https://github.com/salemaziel/wordpress-dev-skills/releases)
2. Extract to your tool's skills directory
3. Skills are automatically available

### Codex CLI

```bash
# Clone or install, then point Codex at the manifest
git clone https://github.com/salemaziel/wordpress-dev-skills.git ~/.codex/skills/wordpress-dev-skills
codex --plugin ~/.codex/skills/wordpress-dev-skills/.codex-plugin/plugin.json
```

### Gemini CLI

```bash
git clone https://github.com/salemaziel/wordpress-dev-skills.git ~/.gemini/extensions/wordpress-dev-skills
# gemini-extension.json in the repo root is the extension descriptor
```

### GitHub Copilot CLI

```bash
git clone https://github.com/salemaziel/wordpress-dev-skills.git ~/.github-copilot/plugins/wordpress-dev-skills
# .github/plugin/marketplace.json is the local dev fixture referencing .claude-plugin/plugin.json
```

---

## Validation

Run the included validation script to check that all manifests are consistent and all required files exist:

```bash
bash scripts/validate-plugin-layout.sh
```

Requires `jq` for JSON validation (`brew install jq` / `apt install jq`).

---

## Marketplace

This plugin is listed in the canonical marketplace repository:

**<https://github.com/salemaziel/vdw-claude-plugins>**

See [`docs/marketplace.md`](docs/marketplace.md) for publishing workflow, versioning rules, and how to keep manifests in sync.

---

## Requirements

- **Python 3.9+** — For SEO audit and visual QA scripts
- **Playwright** — For screenshot automation (`pip install playwright && playwright install`)
- **curl** — For API requests
- **Docker** (optional) — For local WordPress Docker environment
- **jq** (optional) — For manifest validation script

---

## Usage

Once installed, ask Claude Code:

### WordPress Development

```
"Create a custom post type for properties"
"Review this code for WordPress security issues"
"Generate a meta box for property details"
"What are the best practices for enqueueing scripts?"
```

### SEO Optimization

```
"Run an SEO audit on all pages"
"Check SEO for the about page"
"Fix missing featured images"
"Update meta descriptions to include focus keywords"
```

### Visual QA

```
"Take screenshots of all pages"
"Run visual QA on the portfolio page"
"Check responsive layouts at all breakpoints"
```

### Brand Guide

```
"Generate a brand style guide"
"Document the color palette"
"Create typography guidelines"
```

### White-Labeling (FREE Plugins)

```
"White label the admin for client handoff"
"Configure the login page with client branding"
"Set up custom login URL and security"
"Apply Branda settings for admin bar"
```

### Docker Environment

```
"Set up a Docker WordPress environment"
"Start the WordPress containers"
"Run WP-CLI commands in Docker"
```

### WordPress Playground

```
"Test this in WordPress Playground"
"Create a Playground blueprint with WooCommerce"
"Share a Playground demo link"
```

### GSAP Animations

```
"Add scroll-triggered animations to this section"
"Make sure animations respect prefers-reduced-motion"
"Create a staggered card entrance animation"
"Set up responsive animations for mobile"
```

### Performance Optimization

```
"Optimize images for Core Web Vitals"
"Compress videos for web delivery"
"Configure LiteSpeed Cache settings"
"Run a speed test on all pages"
```

### Project Orchestration

```
"Set up a new WordPress project"
"Audit this WordPress site"
"Prepare site for launch"
"Generate a handoff document for the client"
```

---

## Configuration

### Environment variables (recommended — no code changes needed)

```bash
# Add to ~/.bashrc or ~/.zshrc
export WP_SKILLS_ROOT="$HOME/repos/wordpress-dev-skills"
export WORDPRESS_CONTAINER="my-project-wordpress-1"
export WORDPRESS_URL="http://localhost:8080"
export WORDPRESS_PROD_URL="https://your-site.com"
export PEXELS_API_KEY="your-pexels-api-key"         # optional: stock photos
export UNSPLASH_ACCESS_KEY="your-unsplash-key"       # optional: stock photos
```

### For Docker-based WordPress

Database settings are read from environment variables in `skills/seo-optimizer/audit.py`.
Set `WORDPRESS_CONTAINER` (the Docker container name) and the script will connect via WP-CLI.

### For Visual QA

Screenshot output goes to `./screenshots` by default. Override at runtime:

```bash
python3 skills/visual-qa/screenshot.py --base-url http://localhost:8080 --output ./my-screenshots
```

---

## Directory Structure

```
wordpress-dev-skills/
├── plugin.json                         # Canonical root manifest
├── .claude-plugin/plugin.json          # Primary Claude Code manifest
├── .codex-plugin/plugin.json           # Codex CLI manifest
├── gemini-extension.json               # Gemini extension metadata
├── .agents/plugins/marketplace.json    # Local dev fixture (NOT canonical)
├── .github/plugin/marketplace.json     # Local dev fixture (NOT canonical)
├── README.md
├── CHANGELOG.md
├── COMPLETENESS_AUDIT.md
├── LICENSE
├── install.sh
├── docs/
│   └── marketplace.md                  # Marketplace publishing guide
├── scripts/
│   └── validate-plugin-layout.sh       # Validation script
├── marketplace-submission/
│   └── vdw-claude-plugins/             # Submission package for canonical marketplace
├── skills/
│   ├── wp-orchestrator/
│   ├── wp-docker/
│   ├── wp-playground/
│   ├── white-label/
│   ├── wordpress-dev/
│   ├── wordpress-admin/
│   ├── seo-optimizer/
│   ├── visual-qa/
│   ├── brand-guide/
│   ├── gsap-animations/
│   ├── wp-performance/
│   ├── siteground-cache/
│   ├── form-testing/
│   └── wp-test-analyzer/
├── commands/
│   ├── wp-setup.md
│   ├── wp-audit.md
│   └── wp-launch.md
└── hooks/
    └── wp-session-init.sh
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `bash scripts/validate-plugin-layout.sh` to validate
5. Submit a pull request

## License

MIT License — see [LICENSE](LICENSE) for details.

## Support

- [Issues](https://github.com/salemaziel/wordpress-dev-skills/issues)
- [Discussions](https://github.com/salemaziel/wordpress-dev-skills/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
