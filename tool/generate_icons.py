"""Draws the SSHetu launcher icon and writes every platform's files.

    python3 tool/generate_icons.py

No dependencies — Python's zlib is all a PNG encoder needs, and an ICO is a
small directory of PNGs. That is deliberate: an icon pipeline that needs
ImageMagick or a paid app is an icon pipeline nobody can rerun, and the icon
then becomes a binary nobody dares change.

The mark is a bridge — सेतु — carrying a terminal prompt across it: two piers,
a span, and a caret with its cursor block sitting on the deck. At 16px only
the prompt survives, which is the point: the thing a person recognises in a
dock at a glance is `>_`, and the arch is what rewards a second look.
"""

import math
import struct
import zlib

# The app's own accent, both brightnesses, from lib/core/theme/accent.dart.
INDIGO_DARK = (0x2A, 0x2F, 0x6B)
INDIGO = (0x4A, 0x57, 0xC8)
LIGHT = (0xE8, 0xEA, 0xFF)
WHITE = (0xFF, 0xFF, 0xFF)


def _blend(dst, src, alpha):
    return tuple(round(d + (s - d) * alpha) for d, s in zip(dst, src))


def render(size, *, padded=True, opaque=True):
    """Returns an RGBA bytearray of the icon at `size`."""
    # Supersample, then box-filter down: the only way to get clean curves
    # without a rasteriser.
    scale = 4
    n = size * scale
    px = [[(0, 0, 0, 0)] * n for _ in range(n)]

    # A vertical gradient ground, so the mark sits on something with depth
    # rather than a flat fill.
    inset = n * 0.06 if padded else 0.0
    radius = (n - 2 * inset) * 0.235  # close to the macOS squircle
    for y in range(n):
        t = y / (n - 1)
        base = _blend(INDIGO, INDIGO_DARK, t * 0.85)
        for x in range(n):
            if opaque and _rounded_alpha(x, y, inset, n - inset, radius) > 0:
                a = _rounded_alpha(x, y, inset, n - inset, radius)
                px[y][x] = (*base, round(255 * a))
            elif not opaque:
                px[y][x] = (*base, 255)

    _draw_bridge(px, n)
    _draw_prompt(px, n)

    return _downsample(px, n, scale, size)


def _rounded_alpha(x, y, lo, hi, radius):
    """Coverage of a rounded square, antialiased at the edge."""
    cx = min(max(x + 0.5, lo + radius), hi - radius)
    cy = min(max(y + 0.5, lo + radius), hi - radius)
    dx, dy = x + 0.5 - cx, y + 0.5 - cy
    distance = math.hypot(dx, dy)
    if distance <= radius - 0.5:
        return 1.0
    if distance >= radius + 0.5:
        return 0.0
    return radius + 0.5 - distance


def _fill(px, n, test, colour, alpha=1.0):
    for y in range(n):
        for x in range(n):
            if test(x + 0.5, y + 0.5):
                r, g, b, a = px[y][x]
                px[y][x] = (*_blend((r, g, b), colour, alpha), max(a, 255))


def _draw_bridge(px, n):
    """The arch and its two piers, in a dimmed tint of the ground."""
    deck = n * 0.755
    span_left, span_right = n * 0.19, n * 0.81
    centre = (span_left + span_right) / 2
    half = (span_right - span_left) / 2
    rise = n * 0.13
    thickness = n * 0.030

    def arch(x, y):
        if not (span_left <= x <= span_right) or y > deck:
            return False
        # A parabola is close enough to a suspension curve at this size and
        # far cheaper than a catenary.
        curve = deck - rise * (1 - ((x - centre) / half) ** 2)
        return abs(y - curve) <= thickness / 2

    def piers(x, y):
        if not (deck - rise * 0.55 <= y <= deck + n * 0.085):
            return False
        return (
            abs(x - span_left) <= thickness / 2
            or abs(x - span_right) <= thickness / 2
        )

    def roadway(x, y):
        return span_left <= x <= span_right and abs(y - deck) <= thickness / 2

    _fill(px, n, arch, LIGHT, 0.34)
    _fill(px, n, piers, LIGHT, 0.34)
    _fill(px, n, roadway, LIGHT, 0.46)


def _draw_prompt(px, n):
    """`>` and a cursor block, sitting on the deck — the part that survives 16px."""
    weight = n * 0.066
    top, bottom = n * 0.235, n * 0.545
    apex_x = n * 0.475
    start_x = n * 0.285
    mid_y = (top + bottom) / 2

    def chevron(x, y):
        # Two strokes meeting at the apex, each a thick segment.
        for (x0, y0, x1, y1) in (
            (start_x, top, apex_x, mid_y),
            (apex_x, mid_y, start_x, bottom),
        ):
            if _near_segment(x, y, x0, y0, x1, y1) <= weight / 2:
                return True
        return False

    cursor_left = n * 0.565
    cursor_right = n * 0.735

    def cursor(x, y):
        return (
            cursor_left <= x <= cursor_right
            and bottom - weight <= y <= bottom
        )

    _fill(px, n, chevron, WHITE)
    _fill(px, n, cursor, WHITE)


def _near_segment(px_, py, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    length = dx * dx + dy * dy
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((px_ - x0) * dx + (py - y0) * dy) / length))
    return math.hypot(px_ - (x0 + t * dx), py - (y0 + t * dy))


def _downsample(px, n, scale, size):
    out = bytearray()
    for y in range(size):
        out.append(0)  # PNG filter: none
        for x in range(size):
            r = g = b = a = 0
            for sy in range(scale):
                for sx in range(scale):
                    pr, pg, pb, pa = px[y * scale + sy][x * scale + sx]
                    r += pr * pa
                    g += pg * pa
                    b += pb * pa
                    a += pa
            if a == 0:
                out += bytes(4)
            else:
                out += bytes(
                    (round(r / a), round(g / a), round(b / a), round(a / (scale * scale)))
                )
    return out


def _emit(path, size, raw):
    """Writes one RGBA scanline buffer as a PNG."""

    def chunk(tag, data):
        payload = tag + data
        return (
            struct.pack('>I', len(data))
            + payload
            + struct.pack('>I', zlib.crc32(payload) & 0xFFFFFFFF)
        )

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as fh:
        fh.write(png)
    return path


def write_png(path, size, *, padded=True, opaque=True):
    return _emit(path, size, render(size, padded=padded, opaque=opaque))


def main():
    """Writes every platform's icon files from this one drawing."""
    import json
    import os

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144,
               'xxxhdpi': 192}
    for bucket, size in android.items():
        directory = f'{root}/android/app/src/main/res/mipmap-{bucket}'
        os.makedirs(directory, exist_ok=True)
        write_png(f'{directory}/ic_launcher.png', size)
        _write_adaptive_foreground(f'{directory}/ic_launcher_foreground.png', size)

    ios = f'{root}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    with open(f'{ios}/Contents.json') as fh:
        for image in json.load(fh)['images']:
            if 'filename' not in image:
                continue
            base = float(image['size'].split('x')[0])
            scale = int(image['scale'].rstrip('x'))
            write_png(f"{ios}/{image['filename']}", round(base * scale),
                      padded=False)

    mac = f'{root}/macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for size in (16, 32, 64, 128, 256, 512, 1024):
        write_png(f'{mac}/app_icon_{size}.png', size)

    write_ico(f'{root}/windows/runner/resources/app_icon.ico')
    write_png(f'{root}/linux/runner/resources/sshetu.png', 512)
    write_png(f'{root}/assets/icon/sshetu.png', 1024)
    print('icons written')


def _write_adaptive_foreground(path, size):
    """Android masks adaptive icons and may crop the outer third."""
    inner = round(size * 0.62)
    body = render(inner, padded=False, opaque=False)
    offset = (size - inner) // 2
    stride = inner * 4 + 1
    rows = [bytes(body[y * stride + 1: y * stride + 1 + inner * 4])
            for y in range(inner)]

    out = bytearray()
    for y in range(size):
        out.append(0)
        if offset <= y < offset + inner:
            out += (bytes(4 * offset) + rows[y - offset]
                    + bytes(4 * (size - inner - offset)))
        else:
            out += bytes(4 * size)
    _emit(path, size, out)


def write_ico(path, sizes=(16, 24, 32, 48, 64, 128, 256)):
    """An ICO is a directory of images; PNG entries keep the alpha channel."""
    import os
    import tempfile

    blobs = []
    with tempfile.TemporaryDirectory() as tmp:
        for size in sizes:
            written = write_png(os.path.join(tmp, f'{size}.png'), size)
            with open(written, 'rb') as fh:
                blobs.append((size, fh.read()))

    offset = 6 + 16 * len(blobs)
    entries, payload = b'', b''
    for size, blob in blobs:
        dimension = 0 if size >= 256 else size  # 0 means 256
        entries += struct.pack('<BBBBHHII', dimension, dimension, 0, 0, 1, 32,
                               len(blob), offset)
        payload += blob
        offset += len(blob)

    with open(path, 'wb') as fh:
        fh.write(struct.pack('<HHH', 0, 1, len(blobs)) + entries + payload)
    return path


if __name__ == '__main__':
    main()
