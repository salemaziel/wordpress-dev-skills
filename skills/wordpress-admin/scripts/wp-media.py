#!/usr/bin/env python3
"""
wp-media.py
WordPress media management — search free stock photos (Pexels/Unsplash),
download an image, upload it to WordPress via WP-CLI, and optionally set it as
a featured image for a post.

Usage:
    python3 wp-media.py search --query "mountain landscape" --source pexels
    python3 wp-media.py upload --url https://images.pexels.com/... --container my-wordpress-1
    python3 wp-media.py upload --file /tmp/photo.jpg --container my-wordpress-1
    python3 wp-media.py set-featured --post-id 42 --media-id 99 --container my-wordpress-1
    python3 wp-media.py search-and-set --query "office team" --post-id 42 --container my-wordpress-1

Requirements:
    Docker container with WP-CLI, or local wp-cli
    Optional: PEXELS_API_KEY or UNSPLASH_ACCESS_KEY env vars for stock photo search
    (no external pip dependencies required)
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path


# ─── Config ───────────────────────────────────────────────────────────────────

# Pexels free API (register at https://www.pexels.com/api/)
PEXELS_API_KEY = os.environ.get('PEXELS_API_KEY', '')

# Unsplash Access Key (register at https://unsplash.com/developers)
UNSPLASH_ACCESS_KEY = os.environ.get('UNSPLASH_ACCESS_KEY', '')


# ─── Helpers ──────────────────────────────────────────────────────────────────

def wpcli(container: str, *args: str) -> str:
    """Run a wp-cli command in a Docker container or locally."""
    if container:
        cmd = ['docker', 'exec', container, 'wp', *args, '--allow-root']
    elif _which('wp'):
        cmd = ['wp', *args]
    else:
        raise RuntimeError("No WP-CLI available. Provide --container or install wp-cli locally.")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"wp-cli error: {result.stderr.strip()}")
    return result.stdout.strip()


def _which(cmd: str) -> bool:
    return subprocess.run(['which', cmd], capture_output=True).returncode == 0


def _get(url: str, headers: dict | None = None) -> dict:
    """Simple HTTP GET returning parsed JSON."""
    try:
        import urllib.request as urlreq
        req = urlreq.Request(url, headers=headers or {})
        with urlreq.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        raise RuntimeError(f"HTTP request failed: {e}")


# ─── Search ───────────────────────────────────────────────────────────────────

def search_pexels(query: str, per_page: int = 5, orientation: str = 'landscape') -> list[dict]:
    """Search Pexels for free stock photos."""
    if not PEXELS_API_KEY:
        raise RuntimeError(
            "PEXELS_API_KEY not set. Register at https://www.pexels.com/api/ "
            "and export PEXELS_API_KEY=your_key"
        )
    url = (
        f"https://api.pexels.com/v1/search"
        f"?query={urllib.parse.quote(query)}&per_page={per_page}&orientation={orientation}"
    )
    data = _get(url, headers={"Authorization": PEXELS_API_KEY})
    results = []
    for photo in data.get('photos', []):
        results.append({
            "id": photo['id'],
            "source": "pexels",
            "photographer": photo.get('photographer', ''),
            "description": photo.get('alt', query),
            "url_preview": photo['src'].get('medium', ''),
            "url_download": photo['src'].get('large2x', photo['src'].get('original', '')),
            "width": photo.get('width', 0),
            "height": photo.get('height', 0),
            "pexels_url": photo.get('url', ''),
        })
    return results


def search_unsplash(query: str, per_page: int = 5, orientation: str = 'landscape') -> list[dict]:
    """Search Unsplash for free stock photos."""
    if not UNSPLASH_ACCESS_KEY:
        raise RuntimeError(
            "UNSPLASH_ACCESS_KEY not set. Register at https://unsplash.com/developers "
            "and export UNSPLASH_ACCESS_KEY=your_key"
        )
    url = (
        f"https://api.unsplash.com/search/photos"
        f"?query={urllib.parse.quote(query)}&per_page={per_page}&orientation={orientation}"
    )
    data = _get(url, headers={"Authorization": f"Client-ID {UNSPLASH_ACCESS_KEY}"})
    results = []
    for photo in data.get('results', []):
        desc = photo.get('description') or photo.get('alt_description') or query
        results.append({
            "id": photo['id'],
            "source": "unsplash",
            "photographer": photo.get('user', {}).get('name', ''),
            "description": desc,
            "url_preview": photo['urls'].get('small', ''),
            "url_download": photo['urls'].get('full', photo['urls'].get('regular', '')),
            "width": photo.get('width', 0),
            "height": photo.get('height', 0),
            "unsplash_url": photo.get('links', {}).get('html', ''),
        })
    return results


def search_photos(query: str, source: str = 'pexels',
                  per_page: int = 5, orientation: str = 'landscape') -> list[dict]:
    """Search for photos from the specified source."""
    if source == 'pexels':
        return search_pexels(query, per_page, orientation)
    elif source == 'unsplash':
        return search_unsplash(query, per_page, orientation)
    else:
        raise ValueError(f"Unknown source: {source}. Use 'pexels' or 'unsplash'")


# ─── Download ────────────────────────────────────────────────────────────────

def download_image(url: str, dest_path: str | None = None) -> str:
    """Download an image from a URL to a local file."""
    import urllib.request as urlreq

    if dest_path is None:
        # Create a temp file with appropriate extension
        suffix = Path(url.split('?')[0]).suffix or '.jpg'
        fd, dest_path = tempfile.mkstemp(suffix=suffix, prefix='wp-media-')
        os.close(fd)

    print(f"  Downloading: {url[:80]}...")
    headers = {'User-Agent': 'wordpress-dev-skills media manager/1.0'}
    req = urlreq.Request(url, headers=headers)
    with urlreq.urlopen(req, timeout=30) as resp, open(dest_path, 'wb') as f:
        f.write(resp.read())

    size_kb = Path(dest_path).stat().st_size // 1024
    print(f"  Downloaded: {dest_path} ({size_kb} KB)")
    return dest_path


# ─── Upload ───────────────────────────────────────────────────────────────────

def upload_to_wordpress(
    container: str,
    file_path: str | None = None,
    image_url: str | None = None,
    title: str = '',
    alt_text: str = '',
    caption: str = '',
) -> int:
    """Upload a media file to WordPress and return the media ID."""
    if not file_path and not image_url:
        raise ValueError("Either file_path or image_url must be provided")

    temp_file = None

    if image_url and not file_path:
        temp_file = download_image(image_url)
        file_path = temp_file

    # If using Docker, copy file into container first
    if container:
        container_path = f"/tmp/{Path(file_path).name}"
        print(f"  Copying to container: {container_path}")
        result = subprocess.run(
            ['docker', 'cp', file_path, f"{container}:{container_path}"],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            raise RuntimeError(f"docker cp failed: {result.stderr.strip()}")
        upload_path = container_path
    else:
        upload_path = file_path

    # Build wp media import command
    wp_args = ['media', 'import', upload_path]
    if title:
        wp_args += [f'--title={title}']
    if alt_text:
        wp_args += [f'--alt={alt_text}']
    if caption:
        wp_args += [f'--caption={caption}']
    wp_args += ['--porcelain']  # output just the ID

    print(f"  Importing into WordPress...")
    media_id_str = wpcli(container, *wp_args)
    media_id = int(media_id_str.strip())
    print(f"  Uploaded! Media ID: {media_id}")

    # Cleanup temp files
    if container and upload_path.startswith('/tmp/'):
        subprocess.run(
            ['docker', 'exec', container, 'rm', '-f', upload_path],
            capture_output=True
        )
    if temp_file:
        Path(temp_file).unlink(missing_ok=True)

    return media_id


def set_featured_image(container: str, post_id: int, media_id: int) -> None:
    """Set a media item as the featured image for a post."""
    wpcli(container, 'post', 'meta', 'update', str(post_id), '_thumbnail_id', str(media_id))
    print(f"  ✓ Featured image set: post {post_id} → media {media_id}")


# ─── Commands ─────────────────────────────────────────────────────────────────

def cmd_search(args: argparse.Namespace) -> None:
    try:
        results = search_photos(
            query=args.query,
            source=args.source,
            per_page=args.limit,
            orientation=args.orientation,
        )
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(results, indent=2))
        return

    print(f"\n  Found {len(results)} photos for: \"{args.query}\"")
    print(f"  Source: {args.source}\n")
    for i, p in enumerate(results, 1):
        print(f"  [{i}] {p['description'][:60]}")
        print(f"       By: {p['photographer']}")
        print(f"       Size: {p['width']}×{p['height']}")
        print(f"       Download: {p['url_download'][:80]}")
        print()


def cmd_upload(args: argparse.Namespace) -> None:
    try:
        media_id = upload_to_wordpress(
            container=args.container or '',
            file_path=args.file,
            image_url=args.url,
            title=args.title or '',
            alt_text=args.alt or '',
            caption=args.caption or '',
        )
        if args.json:
            print(json.dumps({"media_id": media_id}))
        else:
            print(f"\n  ✓ Media uploaded successfully. ID: {media_id}")
            if args.set_featured:
                set_featured_image(args.container or '', args.set_featured, media_id)
    except (RuntimeError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_set_featured(args: argparse.Namespace) -> None:
    try:
        set_featured_image(args.container or '', args.post_id, args.media_id)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_search_and_set(args: argparse.Namespace) -> None:
    """Search for a photo, upload the first result, and set as featured image."""
    try:
        print(f"\n  Searching for: \"{args.query}\" on {args.source}...")
        results = search_photos(
            query=args.query,
            source=args.source,
            per_page=1,
            orientation=args.orientation,
        )
        if not results:
            print("  No photos found.", file=sys.stderr)
            sys.exit(1)

        photo = results[0]
        print(f"  Selected: {photo['description'][:60]} (by {photo['photographer']})")
        print(f"  Attribution: Please credit '{photo['photographer']}' from {args.source.title()}")

        alt_text = args.alt or photo.get('description', args.query)
        title = args.title or args.query

        media_id = upload_to_wordpress(
            container=args.container or '',
            image_url=photo['url_download'],
            title=title,
            alt_text=alt_text,
        )

        if args.post_id:
            set_featured_image(args.container or '', args.post_id, media_id)

        if args.json:
            print(json.dumps({"media_id": media_id, "post_id": args.post_id, "photo": photo}))
        else:
            print(f"\n  ✓ Done! Media ID: {media_id}")

    except (RuntimeError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


# ─── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='WordPress media management — search, download, upload stock photos',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Environment Variables:
  PEXELS_API_KEY        Pexels API key (https://www.pexels.com/api/)
  UNSPLASH_ACCESS_KEY   Unsplash access key (https://unsplash.com/developers)

Examples:
  python3 wp-media.py search --query "modern office" --source pexels
  python3 wp-media.py upload --url https://images.pexels.com/... --container my-wp-1 --alt "Office"
  python3 wp-media.py upload --file /tmp/photo.jpg --container my-wp-1 --set-featured 42
  python3 wp-media.py set-featured --post-id 42 --media-id 99 --container my-wp-1
  python3 wp-media.py search-and-set --query "team meeting" --post-id 42 --container my-wp-1
"""
    )

    parent = argparse.ArgumentParser(add_help=False)
    parent.add_argument('--container', '-c', metavar='NAME',
                        help='Docker container name (omit for local wp-cli)')
    parent.add_argument('--json', action='store_true', help='Output as JSON')

    subparsers = parser.add_subparsers(dest='command', required=True)

    # search
    p_search = subparsers.add_parser('search', parents=[parent],
                                     help='Search stock photo libraries')
    p_search.add_argument('--query', '-q', required=True, help='Search query')
    p_search.add_argument('--source', choices=['pexels', 'unsplash'], default='pexels',
                          help='Photo source (default: pexels)')
    p_search.add_argument('--limit', '-n', type=int, default=5,
                          help='Number of results (default: 5)')
    p_search.add_argument('--orientation', choices=['landscape', 'portrait', 'square'],
                          default='landscape')

    # upload
    p_upload = subparsers.add_parser('upload', parents=[parent],
                                     help='Upload a photo to WordPress')
    src = p_upload.add_mutually_exclusive_group(required=True)
    src.add_argument('--url', help='Remote image URL to download and upload')
    src.add_argument('--file', help='Local image file path to upload')
    p_upload.add_argument('--title', help='Media title')
    p_upload.add_argument('--alt', help='Alt text for accessibility/SEO')
    p_upload.add_argument('--caption', help='Media caption')
    p_upload.add_argument('--set-featured', type=int, metavar='POST_ID',
                          help='Set as featured image for this post ID')

    # set-featured
    p_sf = subparsers.add_parser('set-featured', parents=[parent],
                                  help='Set an existing media item as featured image')
    p_sf.add_argument('--post-id', type=int, required=True, help='WordPress post ID')
    p_sf.add_argument('--media-id', type=int, required=True, help='WordPress media ID')

    # search-and-set
    p_ss = subparsers.add_parser('search-and-set', parents=[parent],
                                  help='Search, upload, and set as featured image in one step')
    p_ss.add_argument('--query', '-q', required=True, help='Search query')
    p_ss.add_argument('--post-id', type=int, help='Set as featured image for this post ID')
    p_ss.add_argument('--source', choices=['pexels', 'unsplash'], default='pexels')
    p_ss.add_argument('--orientation', choices=['landscape', 'portrait', 'square'],
                       default='landscape')
    p_ss.add_argument('--title', help='Media title (defaults to query)')
    p_ss.add_argument('--alt', help='Alt text (defaults to photo description)')

    args = parser.parse_args()

    dispatch = {
        'search': cmd_search,
        'upload': cmd_upload,
        'set-featured': cmd_set_featured,
        'search-and-set': cmd_search_and_set,
    }
    dispatch[args.command](args)


if __name__ == '__main__':
    main()
