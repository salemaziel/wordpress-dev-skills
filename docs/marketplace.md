# Marketplace Publishing Guide

## Overview

This document explains how the `wordpress-dev-skills` plugin is published to and maintained in the canonical marketplace repository.

| Item | Value |
|------|-------|
| **Plugin source repo** | <https://github.com/salemaziel/wordpress-dev-skills> |
| **Canonical marketplace repo** | <https://github.com/salemaziel/vdw-claude-plugins> |
| **Primary manifest** | `.claude-plugin/plugin.json` |

---

## Marketplace Architecture

The canonical marketplace is the GitHub repository **<https://github.com/salemaziel/vdw-claude-plugins>**.

The local files `.agents/plugins/marketplace.json` and `.github/plugin/marketplace.json` are **local development fixtures only**. They are not authoritative. They exist to support local Codex CLI and GitHub Copilot CLI tooling that reads plugin metadata from the working directory. Both files include a `"marketplaceRole": "local-development-fixture"` field to make this clear.

---

## How to Publish / Update the Marketplace Entry

### If `../vdw-claude-plugins` is checked out locally

1. Inspect the marketplace repo structure and schema:

   ```bash
   ls ../vdw-claude-plugins/
   ```

2. Determine where `wordpress-dev-skills` belongs (e.g., under `vdw-wordpress/` or as its own top-level directory).

3. Copy or update the marketplace entry files from `marketplace-submission/vdw-claude-plugins/` into the appropriate path in `../vdw-claude-plugins/`.

4. If the marketplace repo has a validation script, run it:

   ```bash
   cd ../vdw-claude-plugins && bash scripts/validate.sh   # or whatever the script is called
   ```

5. Commit and open a pull request in the marketplace repo.

### If `../vdw-claude-plugins` is NOT checked out locally

Use the generated submission package at `marketplace-submission/vdw-claude-plugins/`. This directory contains the exact files that need to be added to the marketplace repo:

- `wordpress-dev-skills.entry.json` — machine-readable listing data
- `wordpress-dev-skills.entry.md` — human-readable listing
- `README.md` — instructions for the submission
- `PATCH_NOTES.md` — version and review notes

To apply:

1. Clone the marketplace repo:

   ```bash
   git clone https://github.com/salemaziel/vdw-claude-plugins.git
   ```

2. Copy the submission files into the correct path (inspect repo structure first).

3. Run the marketplace validation script if one exists.

4. Commit and open a pull request.

---

## Keeping Versions in Sync

The version **must match** across all of the following files:

| File | Field |
|------|-------|
| `plugin.json` | `"version"` |
| `.claude-plugin/plugin.json` | `"version"` |
| `.codex-plugin/plugin.json` | `"version"` |
| `gemini-extension.json` | `"version"` |
| `CHANGELOG.md` | Latest `## [X.Y.Z]` heading |
| `marketplace-submission/vdw-claude-plugins/wordpress-dev-skills.entry.json` | `"version"` |

Run the validation script to catch mismatches:

```bash
bash scripts/validate-plugin-layout.sh
```

---

## Pre-publish Checklist

Before publishing a new version to the marketplace:

- [ ] All four manifest files agree on version, name, author, repository URL, and marketplace URL
- [ ] `CHANGELOG.md` has an entry for the new version with today's date
- [ ] `scripts/validate-plugin-layout.sh` passes with no errors
- [ ] All skill paths referenced in manifests actually exist in the repository
- [ ] Repository URL in all manifests is `https://github.com/salemaziel/wordpress-dev-skills`
- [ ] Marketplace URL in all manifests is `https://github.com/salemaziel/vdw-claude-plugins`
- [ ] `marketplace-submission/` files are updated to match the new version
- [ ] Any new skills are documented in `README.md`

---

## Handling Missing `../vdw-claude-plugins`

If you do not have the marketplace repo checked out locally:

1. The submission package at `marketplace-submission/vdw-claude-plugins/` contains everything needed.
2. The `PATCH_NOTES.md` file explains exactly what to copy and where.
3. Validate the JSON files manually:

   ```bash
   jq . marketplace-submission/vdw-claude-plugins/wordpress-dev-skills.entry.json
   ```

4. Once you have access to the marketplace repo, follow the steps in the section above.

---

## Local Development Fixtures

These files exist only for local tooling. Do **not** treat them as the canonical marketplace:

- `.agents/plugins/marketplace.json` — Codex CLI / agent-runner local fixture
- `.github/plugin/marketplace.json` — GitHub Copilot CLI local fixture

Both files contain `"marketplaceRole": "local-development-fixture"` and point to the canonical marketplace URL.
