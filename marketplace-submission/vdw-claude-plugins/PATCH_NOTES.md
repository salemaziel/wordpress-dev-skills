# Patch Notes — wordpress-dev-skills marketplace submission

## Target

- **Repository:** <https://github.com/salemaziel/vdw-claude-plugins>
- **Intended path:** `wordpress-dev-skills/` (or `vdw-wordpress/wordpress-dev-skills/` — inspect repo structure)

## Version

`1.4.0`

## Files to add / update

| File | Action |
|------|--------|
| `wordpress-dev-skills.entry.json` | Add (new entry) |
| `wordpress-dev-skills.entry.md` | Add (new entry) |

## Summary of changes in this version

- First marketplace submission for `salemaziel/wordpress-dev-skills`
- Plugin includes 14 skills covering WordPress development, Docker, Playground, SEO, visual QA, performance, white-labeling, GSAP animations, SiteGround cache busting, form testing, and E2E test analysis
- Three slash commands: `/wp-setup`, `/wp-audit`, `/wp-launch`
- Multi-agent manifests: `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`

## Manual review notes

- Verify that `.claude-plugin/plugin.json` in the source repo is still version `1.4.0` before publishing
- Check that `https://github.com/salemaziel/wordpress-dev-skills` is accessible
- Confirm the marketplace repo schema matches the format of `wordpress-dev-skills.entry.json`
- If the marketplace repo has a different schema, adapt the entry file accordingly

## Validation

After copying files into the marketplace repo:

```bash
# Validate JSON
jq . wordpress-dev-skills.entry.json

# If the marketplace repo has its own validation script
bash scripts/validate.sh
```

## Notes

- The `../vdw-claude-plugins` directory was not available locally when this package was generated
- Direct marketplace validation was not run; validate after applying
