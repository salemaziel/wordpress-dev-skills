#!/usr/bin/env python3
"""
color-utils.py
WordPress brand color utilities: hex/RGB/HSL conversion, WCAG contrast checking,
complementary color generation, and accessible palette suggestions.

Usage:
    python3 color-utils.py --hex "#07254B" --check-contrast "#EDEAE3"
    python3 color-utils.py --hex "#07254B" --info
    python3 color-utils.py --palette "#07254B" "#B4C1D1" "#EDEAE3"
    python3 color-utils.py --check-wcag "#07254B" "#EDEAE3" --level AA
"""

import argparse
import json
import math
import sys


# ─── Color conversion ─────────────────────────────────────────────────────────

def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    """Convert hex color string to (r, g, b) tuple."""
    hex_color = hex_color.lstrip('#')
    if len(hex_color) == 3:
        hex_color = ''.join(c * 2 for c in hex_color)
    if len(hex_color) != 6:
        raise ValueError(f"Invalid hex color: #{hex_color}")
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return r, g, b


def rgb_to_hex(r: int, g: int, b: int) -> str:
    """Convert (r, g, b) to hex string."""
    return '#{:02X}{:02X}{:02X}'.format(
        max(0, min(255, r)),
        max(0, min(255, g)),
        max(0, min(255, b))
    )


def rgb_to_hsl(r: int, g: int, b: int) -> tuple[float, float, float]:
    """Convert RGB (0-255 each) to HSL (h: 0-360, s: 0-100, l: 0-100)."""
    r_f = r / 255
    g_f = g / 255
    b_f = b / 255

    cmax = max(r_f, g_f, b_f)
    cmin = min(r_f, g_f, b_f)
    delta = cmax - cmin

    l = (cmax + cmin) / 2

    if delta == 0:
        h = 0.0
        s = 0.0
    else:
        s = delta / (1 - abs(2 * l - 1))
        if cmax == r_f:
            h = 60 * (((g_f - b_f) / delta) % 6)
        elif cmax == g_f:
            h = 60 * (((b_f - r_f) / delta) + 2)
        else:
            h = 60 * (((r_f - g_f) / delta) + 4)

    return round(h % 360, 1), round(s * 100, 1), round(l * 100, 1)


def hsl_to_rgb(h: float, s: float, l: float) -> tuple[int, int, int]:
    """Convert HSL (h: 0-360, s: 0-100, l: 0-100) to RGB (0-255 each)."""
    s_f = s / 100
    l_f = l / 100

    c = (1 - abs(2 * l_f - 1)) * s_f
    x = c * (1 - abs((h / 60) % 2 - 1))
    m = l_f - c / 2

    if 0 <= h < 60:
        r, g, b = c, x, 0.0
    elif 60 <= h < 120:
        r, g, b = x, c, 0.0
    elif 120 <= h < 180:
        r, g, b = 0.0, c, x
    elif 180 <= h < 240:
        r, g, b = 0.0, x, c
    elif 240 <= h < 300:
        r, g, b = x, 0.0, c
    else:
        r, g, b = c, 0.0, x

    return (
        round((r + m) * 255),
        round((g + m) * 255),
        round((b + m) * 255),
    )


# ─── WCAG contrast ────────────────────────────────────────────────────────────

def relative_luminance(r: int, g: int, b: int) -> float:
    """Calculate WCAG relative luminance (0–1)."""
    def linearize(channel: int) -> float:
        c = channel / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)


def contrast_ratio(hex1: str, hex2: str) -> float:
    """Calculate WCAG contrast ratio between two hex colors."""
    r1, g1, b1 = hex_to_rgb(hex1)
    r2, g2, b2 = hex_to_rgb(hex2)
    l1 = relative_luminance(r1, g1, b1)
    l2 = relative_luminance(r2, g2, b2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return round((lighter + 0.05) / (darker + 0.05), 2)


def wcag_level(ratio: float) -> dict:
    """Return WCAG compliance levels for a given contrast ratio."""
    return {
        "ratio": ratio,
        "AA_normal": ratio >= 4.5,    # Normal text AA
        "AA_large": ratio >= 3.0,     # Large text AA (18pt+)
        "AAA_normal": ratio >= 7.0,   # Normal text AAA
        "AAA_large": ratio >= 4.5,    # Large text AAA
        "decorative_ok": ratio >= 3.0,
    }


# ─── Color analysis ───────────────────────────────────────────────────────────

def color_info(hex_color: str) -> dict:
    """Return full color information for a hex color."""
    r, g, b = hex_to_rgb(hex_color)
    h, s, l_val = rgb_to_hsl(r, g, b)

    # Determine if light or dark
    is_dark = l_val < 50

    # Accessible text color (black or white)
    contrast_black = contrast_ratio(hex_color, '#000000')
    contrast_white = contrast_ratio(hex_color, '#FFFFFF')
    accessible_text = '#000000' if contrast_black > contrast_white else '#FFFFFF'

    return {
        "hex": hex_color.upper() if hex_color.startswith('#') else f"#{hex_color.upper()}",
        "rgb": f"rgb({r}, {g}, {b})",
        "hsl": f"hsl({h}, {s}%, {l_val}%)",
        "r": r, "g": g, "b": b,
        "hue": h, "saturation": s, "lightness": l_val,
        "is_dark": is_dark,
        "accessible_text_color": accessible_text,
        "contrast_vs_black": contrast_black,
        "contrast_vs_white": contrast_white,
        "css_variable": f"--color-{hex_color.lstrip('#').lower()}: {hex_color};",
    }


# ─── Palette generation ───────────────────────────────────────────────────────

def complementary(hex_color: str) -> str:
    """Return the complementary color (opposite on color wheel)."""
    r, g, b = hex_to_rgb(hex_color)
    h, s, l_val = rgb_to_hsl(r, g, b)
    comp_h = (h + 180) % 360
    cr, cg, cb = hsl_to_rgb(comp_h, s, l_val)
    return rgb_to_hex(cr, cg, cb)


def tints_and_shades(hex_color: str, steps: int = 5) -> list[str]:
    """Generate tints (lighter) and shades (darker) of a color."""
    r, g, b = hex_to_rgb(hex_color)
    h, s, l_val = rgb_to_hsl(r, g, b)

    results = []
    # Shades (darker)
    for i in range(steps, 0, -1):
        new_l = max(0, l_val - (i * (l_val / (steps + 1))))
        nr, ng, nb = hsl_to_rgb(h, s, new_l)
        results.append(rgb_to_hex(nr, ng, nb))

    # Original
    results.append(hex_color.upper() if hex_color.startswith('#') else f"#{hex_color.upper()}")

    # Tints (lighter)
    for i in range(1, steps + 1):
        new_l = min(100, l_val + (i * ((100 - l_val) / (steps + 1))))
        nr, ng, nb = hsl_to_rgb(h, s, new_l)
        results.append(rgb_to_hex(nr, ng, nb))

    return results


def analyze_palette(hex_colors: list[str]) -> dict:
    """Analyze a palette of colors for accessibility and relationships."""
    results = {
        "colors": {},
        "contrast_matrix": {},
        "issues": [],
        "recommendations": [],
    }

    for hc in hex_colors:
        norm = hc.upper() if hc.startswith('#') else f"#{hc.upper()}"
        results["colors"][norm] = color_info(hc)

    # Build contrast matrix
    for i, c1 in enumerate(hex_colors):
        for j, c2 in enumerate(hex_colors):
            if i >= j:
                continue
            key = f"{c1.upper()} vs {c2.upper()}"
            ratio = contrast_ratio(c1, c2)
            wcag = wcag_level(ratio)
            results["contrast_matrix"][key] = wcag

            if not wcag["AA_normal"]:
                results["issues"].append(
                    f"{c1} vs {c2}: contrast {ratio}:1 — fails WCAG AA for normal text (need 4.5:1)"
                )
            elif not wcag["AAA_normal"]:
                results["recommendations"].append(
                    f"{c1} vs {c2}: contrast {ratio}:1 — passes AA but not AAA (need 7:1)"
                )

    return results


# ─── CLI ─────────────────────────────────────────────────────────────────────

def print_color_info(info: dict) -> None:
    """Pretty-print color info."""
    print(f"\n  Hex:        {info['hex']}")
    print(f"  RGB:        {info['rgb']}")
    print(f"  HSL:        {info['hsl']}")
    print(f"  Dark/Light: {'dark' if info['is_dark'] else 'light'}")
    print(f"  Text on:    {info['accessible_text_color']} (auto-selected for contrast)")
    print(f"  vs Black:   {info['contrast_vs_black']}:1")
    print(f"  vs White:   {info['contrast_vs_white']}:1")
    print(f"  CSS var:    {info['css_variable']}")


def main():
    parser = argparse.ArgumentParser(
        description='WordPress brand color utilities',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 color-utils.py --hex "#07254B" --info
  python3 color-utils.py --check-contrast "#07254B" "#EDEAE3"
  python3 color-utils.py --palette "#07254B" "#B4C1D1" "#EDEAE3"
  python3 color-utils.py --tints "#07254B"
  python3 color-utils.py --complementary "#07254B"
"""
    )

    parser.add_argument('--hex', metavar='COLOR',
                        help='Hex color to analyze (e.g. "#07254B")')
    parser.add_argument('--info', action='store_true',
                        help='Show full color information')
    parser.add_argument('--check-contrast', metavar='BG_COLOR',
                        help='Check contrast ratio against this background color')
    parser.add_argument('--level', choices=['AA', 'AAA'], default='AA',
                        help='WCAG compliance level to check (default: AA)')
    parser.add_argument('--palette', nargs='+', metavar='COLOR',
                        help='Analyze a palette of hex colors for accessibility')
    parser.add_argument('--tints', metavar='COLOR',
                        help='Generate tints and shades for a color')
    parser.add_argument('--steps', type=int, default=5,
                        help='Number of tint/shade steps (default: 5)')
    parser.add_argument('--complementary', metavar='COLOR',
                        help='Get the complementary color')
    parser.add_argument('--json', action='store_true',
                        help='Output as JSON')

    args = parser.parse_args()

    if not any([args.hex, args.palette, args.tints, args.complementary]):
        parser.print_help()
        sys.exit(1)

    # ── Single color info ────────────────────────────────────────────────────
    if args.hex:
        info = color_info(args.hex)

        if args.check_contrast:
            ratio = contrast_ratio(args.hex, args.check_contrast)
            wcag = wcag_level(ratio)

            if args.json:
                print(json.dumps({"hex": args.hex, "bg": args.check_contrast, "wcag": wcag}, indent=2))
            else:
                print(f"\n  Contrast: {args.hex} on {args.check_contrast}")
                print(f"  Ratio:  {ratio}:1")
                print(f"  AA  (normal text ≥4.5): {'✓ PASS' if wcag['AA_normal'] else '✗ FAIL'}")
                print(f"  AA  (large text  ≥3.0): {'✓ PASS' if wcag['AA_large'] else '✗ FAIL'}")
                print(f"  AAA (normal text ≥7.0): {'✓ PASS' if wcag['AAA_normal'] else '✗ FAIL'}")
                print(f"  AAA (large text  ≥4.5): {'✓ PASS' if wcag['AAA_large'] else '✗ FAIL'}")
        elif args.info:
            if args.json:
                print(json.dumps(info, indent=2))
            else:
                print_color_info(info)

    # ── Palette analysis ─────────────────────────────────────────────────────
    if args.palette:
        result = analyze_palette(args.palette)
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print("\n  Palette Analysis")
            print("  " + "─" * 44)
            for color, cinfo in result["colors"].items():
                print(f"\n  {color}")
                print_color_info(cinfo)

            print("\n  Contrast Matrix")
            print("  " + "─" * 44)
            for pair, wcag in result["contrast_matrix"].items():
                status = "✓" if wcag["AA_normal"] else "✗"
                print(f"  {status} {pair}: {wcag['ratio']}:1")

            if result["issues"]:
                print("\n  Issues (must fix):")
                for issue in result["issues"]:
                    print(f"  ✗ {issue}")

            if result["recommendations"]:
                print("\n  Recommendations:")
                for rec in result["recommendations"]:
                    print(f"  ⚠ {rec}")

    # ── Tints & shades ───────────────────────────────────────────────────────
    if args.tints:
        colors = tints_and_shades(args.tints, args.steps)
        if args.json:
            print(json.dumps(colors, indent=2))
        else:
            print(f"\n  Tints & Shades for {args.tints}")
            print("  " + "─" * 30)
            mid = len(colors) // 2
            for i, c in enumerate(colors):
                label = "(original)" if i == mid else ("← lighter" if i > mid else "← darker")
                print(f"  {c}  {label}")

    # ── Complementary ────────────────────────────────────────────────────────
    if args.complementary:
        comp = complementary(args.complementary)
        if args.json:
            print(json.dumps({"original": args.complementary, "complementary": comp}, indent=2))
        else:
            print(f"\n  {args.complementary} → complementary: {comp}")
            ratio = contrast_ratio(args.complementary, comp)
            print(f"  Contrast ratio: {ratio}:1")

    print()


if __name__ == '__main__':
    main()
