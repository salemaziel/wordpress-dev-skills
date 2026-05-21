# Marketplace Submission Package — wordpress-dev-skills

## Why this package exists

The canonical marketplace repository (`https://github.com/salemaziel/vdw-claude-plugins`) was not available locally at the time the `wordpress-dev-skills` plugin packaging was completed. This package contains the exact files that need to be copied into the marketplace repo.

## Canonical marketplace repository

**<https://github.com/salemaziel/vdw-claude-plugins>**

## Files in this package

| File | Purpose |
|------|---------|
| `wordpress-dev-skills.entry.json` | Machine-readable marketplace listing data |
| `wordpress-dev-skills.entry.md` | Human-readable marketplace listing |
| `PATCH_NOTES.md` | Version, review notes, and validation instructions |
| `README.md` | This file |

## How to apply

1. Clone the marketplace repository:

   ```bash
   git clone https://github.com/salemaziel/vdw-claude-plugins.git
   cd vdw-claude-plugins
   ```

2. Inspect the repo structure to determine where this plugin belongs:

   ```bash
   ls -la
   ```

   If there is a `vdw-wordpress/` directory or similar WordPress category, place the files there. Otherwise create a `wordpress-dev-skills/` top-level directory.

3. Copy the entry files:

   ```bash
   # Example — adjust path based on marketplace repo structure
   cp wordpress-dev-skills.entry.json ../vdw-claude-plugins/wordpress-dev-skills/
   cp wordpress-dev-skills.entry.md   ../vdw-claude-plugins/wordpress-dev-skills/
   ```

4. Run the marketplace validation script (if one exists):

   ```bash
   bash scripts/validate.sh   # or whatever the script is named
   ```

5. Validate the JSON manually:

   ```bash
   jq . wordpress-dev-skills.entry.json
   ```

6. Commit and open a pull request.

## Version

This package was generated for plugin version **1.4.0**.

Always ensure the version in these files matches `.claude-plugin/plugin.json` in the plugin source repo before publishing.
