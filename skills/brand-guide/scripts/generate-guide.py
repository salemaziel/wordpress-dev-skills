#!/usr/bin/env python3
"""
generate-guide.py
Generate a Markdown brand guide document from extracted brand data (JSON/YAML).

Usage:
    python3 generate-guide.py --brand-data brand-data.json --output brand-guide.md
    python3 generate-guide.py --brand-data brand-data.yaml --output brand-guide.html --format html
    python3 generate-guide.py --brand-data brand-data.json   # prints to stdout

Input format (JSON or YAML):
    {
      "name": "Acme Corp",
      "tagline": "Building Tomorrow",
      "colors": {
        "primary":   {"name": "Deep Navy",  "hex": "#07254B", "usage": "Headings, CTAs"},
        "secondary": {"name": "Steel Blue", "hex": "#B4C1D1", "usage": "Accents"},
        "accent":    {"name": "Gold",       "hex": "#C9A227", "usage": "Highlights"},
        "background":{"name": "Cream",      "hex": "#EDEAE3", "usage": "Page backgrounds"},
        "text":      {"name": "Dark Navy",  "hex": "#07254B", "usage": "Body text"}
      },
      "typography": {
        "heading_font": "Playfair Display",
        "body_font":    "Inter",
        "weights": [300, 400, 700]
      },
      "voice": {
        "personality": ["Professional", "Trustworthy", "Modern"],
        "tone": "Confident but approachable",
        "dos":   ["Use active voice", "Be concise"],
        "donts": ["Avoid jargon", "No exclamation points"]
      }
    }
"""

import argparse
import json
import sys
from pathlib import Path
from datetime import date


def load_brand_data(path: str) -> dict:
    """Load brand data from JSON or YAML file."""
    p = Path(path)
    if not p.exists():
        print(f"Error: File not found: {path}", file=sys.stderr)
        sys.exit(1)

    content = p.read_text(encoding='utf-8')

    if p.suffix in ('.yaml', '.yml'):
        try:
            import yaml  # type: ignore
            return yaml.safe_load(content)
        except ImportError:
            print("Error: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
            sys.exit(1)
    else:
        try:
            return json.loads(content)
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON: {e}", file=sys.stderr)
            sys.exit(1)


def hex_to_rgb(hex_color: str) -> str:
    """Convert hex to rgb() string."""
    h = hex_color.lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    try:
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return f"rgb({r}, {g}, {b})"
    except Exception:
        return ""


def contrast_ratio(hex1: str, hex2: str) -> float:
    """Calculate WCAG contrast ratio between two hex colors."""
    def luminance(h: str) -> float:
        h = h.lstrip('#')
        if len(h) == 3:
            h = ''.join(c * 2 for c in h)
        def lin(c: int) -> float:
            v = c / 255
            return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    l1, l2 = luminance(hex1), luminance(hex2)
    lighter, darker = max(l1, l2), min(l1, l2)
    return round((lighter + 0.05) / (darker + 0.05), 2)


def wcag_badge(ratio: float) -> str:
    """Return a WCAG compliance badge string."""
    if ratio >= 7.0:
        return "AAA ✓"
    elif ratio >= 4.5:
        return "AA ✓"
    elif ratio >= 3.0:
        return "AA large ✓"
    else:
        return "Fails AA ✗"


def generate_markdown(data: dict) -> str:
    """Generate a complete Markdown brand guide from brand data."""
    name = data.get('name', 'Brand')
    tagline = data.get('tagline', '')
    established = data.get('established', '')
    location = data.get('location', '')
    today = date.today().strftime('%B %d, %Y')

    lines = []

    # ── Header ────────────────────────────────────────────────────────────────
    lines += [
        f"# {name} — Brand Style Guide",
        "",
        f"> *{tagline}*" if tagline else "",
        "",
        f"**Last Updated:** {today}",
    ]
    if established:
        lines.append(f"**Established:** {established}")
    if location:
        lines.append(f"**Location:** {location}")
    lines += ["", "---", ""]

    # ── Table of contents ─────────────────────────────────────────────────────
    lines += [
        "## Contents",
        "",
        "1. [Color Palette](#color-palette)",
        "2. [Typography](#typography)",
        "3. [Logo Usage](#logo-usage)",
        "4. [Imagery](#imagery)",
        "5. [Voice & Tone](#voice--tone)",
        "6. [Responsive Breakpoints](#responsive-breakpoints)",
        "7. [CSS Variables](#css-variables)",
        "",
        "---",
        "",
    ]

    # ── Color palette ─────────────────────────────────────────────────────────
    lines += ["## Color Palette", ""]
    colors = data.get('colors', {})

    if colors:
        lines += [
            "| Role | Name | Hex | RGB | Usage | Contrast (vs white) |",
            "|------|------|-----|-----|-------|---------------------|",
        ]
        for role, color in colors.items():
            if not isinstance(color, dict):
                continue
            hex_val = color.get('hex', '#000000')
            rgb_val = hex_to_rgb(hex_val)
            cname = color.get('name', role.title())
            usage = color.get('usage', '')
            cr = contrast_ratio(hex_val, '#FFFFFF')
            badge = wcag_badge(cr)
            lines.append(f"| {role.title()} | {cname} | `{hex_val}` | `{rgb_val}` | {usage} | {cr}:1 ({badge}) |")
        lines.append("")

        # Usage guidance
        bg_color = colors.get('background', colors.get('primary', {})).get('hex', '#FFFFFF')
        text_color = colors.get('text', colors.get('primary', {})).get('hex', '#000000')

        lines += [
            "### Color Combinations",
            "",
        ]
        checked = set()
        color_list = [(r, c.get('hex', '#000')) for r, c in colors.items() if isinstance(c, dict)]
        for role1, hex1 in color_list:
            for role2, hex2 in color_list:
                key = tuple(sorted([role1, role2]))
                if role1 == role2 or key in checked:
                    continue
                checked.add(key)
                cr = contrast_ratio(hex1, hex2)
                badge = wcag_badge(cr)
                ok = "✓" if cr >= 4.5 else ("⚠" if cr >= 3.0 else "✗")
                lines.append(f"- {ok} **{role1.title()}** (`{hex1}`) on **{role2.title()}** (`{hex2}`): {cr}:1 — {badge}")
        lines += ["", "---", ""]
    else:
        lines += ["*No color data provided.*", "", "---", ""]

    # ── Typography ────────────────────────────────────────────────────────────
    lines += ["## Typography", ""]
    typography = data.get('typography', {})

    if typography:
        heading_font = typography.get('heading_font', typography.get('primary_font', 'Sans-serif'))
        body_font = typography.get('body_font', typography.get('primary_font', 'Sans-serif'))
        weights = typography.get('weights', [400, 700])

        lines += [
            f"**Heading Font:** {heading_font}",
            f"**Body Font:** {body_font}",
            f"**Available Weights:** {', '.join(str(w) for w in weights)}",
            "",
        ]

        # Type scale
        type_scale = typography.get('scale', {})
        if type_scale:
            lines += [
                "### Type Scale",
                "",
                "| Element | Size | Weight | Line Height |",
                "|---------|------|--------|-------------|",
            ]
            for element, props in type_scale.items():
                size = props.get('size', '')
                weight = props.get('weight', '')
                lh = props.get('line_height', '')
                lines.append(f"| {element} | {size} | {weight} | {lh} |")
            lines.append("")

        # Google Fonts import
        fonts = set()
        if heading_font:
            fonts.add(heading_font.replace(' ', '+'))
        if body_font and body_font != heading_font:
            fonts.add(body_font.replace(' ', '+'))
        if fonts:
            weight_str = ','.join(str(w) for w in sorted(weights))
            font_params = '|'.join(f"family={f}:wght@{weight_str}" for f in fonts)
            lines += [
                "### Google Fonts Import",
                "",
                "```html",
                f'<link rel="preconnect" href="https://fonts.googleapis.com">',
                f'<link href="https://fonts.googleapis.com/css2?{font_params}&display=swap" rel="stylesheet">',
                "```",
                "",
            ]
        lines += ["---", ""]
    else:
        lines += ["*No typography data provided.*", "", "---", ""]

    # ── Logo usage ────────────────────────────────────────────────────────────
    logo = data.get('logo', {})
    lines += ["## Logo Usage", ""]
    if logo:
        if logo.get('primary'):
            lines.append(f"**Primary Logo:** `{logo['primary']}`")
        if logo.get('white'):
            lines.append(f"**White Version:** `{logo['white']}` (use on dark backgrounds)")
        if logo.get('dark'):
            lines.append(f"**Dark Version:** `{logo['dark']}` (use on light backgrounds)")
        lines += [
            "",
            "### Rules",
            "",
            "- Maintain clear space equal to the logo height around all sides",
            "- Never stretch, rotate, or apply effects to the logo",
            "- Use the white version on primary/dark backgrounds",
            "- Minimum width: 120px",
            "",
        ]
    else:
        lines += [
            "- Use SVG format for all logo files",
            "- Maintain clear space equal to the logo height on all sides",
            "- Never stretch, rotate, or apply visual effects",
            "- Provide both dark (for light backgrounds) and white (for dark backgrounds) versions",
            "",
        ]
    lines += ["---", ""]

    # ── Imagery ───────────────────────────────────────────────────────────────
    imagery = data.get('imagery', {})
    lines += ["## Imagery", ""]
    if imagery:
        style = imagery.get('style', '')
        treatment = imagery.get('treatment', '')
        subjects = imagery.get('subjects', [])
        ratios = imagery.get('aspect_ratios', {})

        if style:
            lines.append(f"**Photography Style:** {style}")
        if treatment:
            lines.append(f"**Treatment:** {treatment}")
        if subjects:
            lines.append(f"**Subjects:** {', '.join(subjects)}")
        if ratios:
            lines += ["", "### Aspect Ratios", ""]
            for context, ratio in ratios.items():
                lines.append(f"- **{context.title()}:** {ratio}")
        lines += ["", "---", ""]
    else:
        lines += [
            "- Use high-quality, professional photography",
            "- Maintain visual consistency across the site",
            "- Optimize all images (max 200KB for web, use WebP where supported)",
            "- Always provide descriptive ALT text",
            "",
            "---",
            "",
        ]

    # ── Voice and tone ────────────────────────────────────────────────────────
    voice = data.get('voice', {})
    lines += ["## Voice & Tone", ""]
    if voice:
        personality = voice.get('personality', [])
        tone = voice.get('tone', '')
        dos = voice.get('dos', voice.get('do', []))
        donts = voice.get('donts', voice.get('dont', []))

        if personality:
            lines.append(f"**Personality:** {', '.join(personality)}")
        if tone:
            lines.append(f"**Tone:** {tone}")
        lines.append("")

        if dos:
            lines += ["### Do ✓", ""]
            for item in dos:
                lines.append(f"- {item}")
            lines.append("")

        if donts:
            lines += ["### Don't ✗", ""]
            for item in donts:
                lines.append(f"- {item}")
            lines.append("")
    else:
        lines += [
            "- Be professional, clear, and concise",
            "- Use active voice",
            "- Avoid jargon and overly technical language",
            "- Write for the audience, not the brand",
            "",
        ]
    lines += ["---", ""]

    # ── Responsive breakpoints ────────────────────────────────────────────────
    responsive = data.get('responsive', {})
    breakpoints = responsive.get('breakpoints', {
        "mobile":  "< 768px",
        "tablet":  "768px – 1024px",
        "desktop": "> 1024px",
    })

    lines += [
        "## Responsive Breakpoints",
        "",
        "| Breakpoint | Range | CSS Prefix |",
        "|------------|-------|-----------|",
    ]
    css_prefixes = {"mobile": "none", "tablet": "md:", "desktop": "lg:", "wide": "xl:"}
    for bp, val in breakpoints.items():
        prefix = css_prefixes.get(bp, "")
        lines.append(f"| {bp.title()} | {val} | `{prefix}` |")
    lines += ["", "---", ""]

    # ── CSS variables ─────────────────────────────────────────────────────────
    lines += ["## CSS Variables", "", "```css", ":root {"]
    if colors:
        lines.append("  /* Colors */")
        for role, color in colors.items():
            if isinstance(color, dict) and color.get('hex'):
                lines.append(f"  --color-{role}: {color['hex']};")
    if typography:
        lines.append("  /* Typography */")
        hf = typography.get('heading_font', '')
        bf = typography.get('body_font', '')
        if hf:
            lines.append(f"  --font-heading: '{hf}', serif;")
        if bf and bf != hf:
            lines.append(f"  --font-body: '{bf}', sans-serif;")
    lines += ["}", "```", "", "---", ""]

    # ── Footer ────────────────────────────────────────────────────────────────
    lines += [
        f"*{name} Brand Style Guide — Generated by wordpress-dev-skills*",
        f"*{today}*",
        "",
    ]

    return "\n".join(line for line in lines if line is not None)


def main():
    parser = argparse.ArgumentParser(
        description='Generate a brand style guide from brand data JSON/YAML',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 generate-guide.py --brand-data brand-data.json
  python3 generate-guide.py --brand-data brand-data.json --output brand-guide.md
  python3 generate-guide.py --brand-data brand-data.yaml --output brand-guide.html --format html
"""
    )
    parser.add_argument('--brand-data', required=True, metavar='FILE',
                        help='Path to brand data JSON or YAML file')
    parser.add_argument('--output', metavar='FILE',
                        help='Output file path (default: print to stdout)')
    parser.add_argument('--format', choices=['markdown', 'html'], default='markdown',
                        help='Output format (default: markdown)')

    args = parser.parse_args()

    data = load_brand_data(args.brand_data)

    if args.format == 'markdown':
        content = generate_markdown(data)
    else:
        # Convert markdown to minimal HTML
        md = generate_markdown(data)
        name = data.get('name', 'Brand')
        content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{name} — Brand Style Guide</title>
<style>
  body {{ font-family: sans-serif; max-width: 900px; margin: 40px auto; padding: 0 20px; line-height: 1.6; }}
  h1 {{ border-bottom: 3px solid #333; padding-bottom: 10px; }}
  h2 {{ border-bottom: 1px solid #ddd; margin-top: 40px; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ border: 1px solid #ddd; padding: 8px 12px; text-align: left; }}
  th {{ background: #f5f5f5; }}
  code {{ background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }}
  pre {{ background: #f5f5f5; padding: 16px; border-radius: 6px; overflow-x: auto; }}
  blockquote {{ border-left: 4px solid #ddd; padding-left: 16px; color: #666; margin: 0; }}
</style>
</head>
<body>
<!-- Brand guide content (Markdown source follows) -->
<pre style="white-space:pre-wrap">{md.replace('<', '&lt;').replace('>', '&gt;')}</pre>
</body>
</html>"""

    if args.output:
        out_path = Path(args.output)
        out_path.write_text(content, encoding='utf-8')
        print(f"Brand guide written to: {args.output}")
    else:
        print(content)


if __name__ == '__main__':
    main()
