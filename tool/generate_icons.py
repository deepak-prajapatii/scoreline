"""Renders the launcher-icon sources from the same geometry lib/ui/scoreline_logo.dart draws.

One source of truth for the mark: change the constants there and rerun this, then
`dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.

    python3 tool/generate_icons.py

Emits one badge per Android flavor. Only the gradient differs — the white bolt is
identical everywhere, so the three read as the same app in three builds rather than
as three apps. The colours are pulled from lib/theme/arena_theme.dart rather than
invented, so the launcher stays inside the palette the board already uses.

The per-flavor legacy square matters more than it looks: minSdk is 24, and API 24-25
predate adaptive icons, so those devices fall back to this full-bleed PNG and would
otherwise show prod colours on a dev build.
"""
import math
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersample, then downscale — Pillow has no antialiased polygon fill

# arena_theme.dart, by name: violet, cyan, gold, gain, bronze.
VIOLET = (0x7C, 0x3A, 0xED)
CYAN = (0x22, 0xD3, 0xEE)
GOLD = (0xFB, 0xBF, 0x24)
GAIN = (0x4A, 0xDE, 0x80)
BRONZE = (0xFB, 0x71, 0x85)

# flavor -> (gradient start, gradient end). The start colour is also what the
# matching flutter_launcher_icons-<flavor>.yaml uses as adaptive_icon_background,
# so the adaptive and legacy icons agree. `prod` writes the unsuffixed filename
# because it is the one the main (flavor-less) icon config already points at.
FLAVORS = {
    "prod": (VIOLET, CYAN),
    "dev": (GOLD, GAIN),
    "staging": (BRONZE, VIOLET),
}

BOLT = [
    (0.585, 0.16), (0.315, 0.545), (0.475, 0.545),
    (0.415, 0.84), (0.685, 0.455), (0.525, 0.455),
]
HEX_RADIUS, HEX_SIDES, DEG_PER_SIDE, START_ANGLE = 0.46, 6, 60.0, -90.0


def gradient(size, start, end):
    """Corner to corner — the same brush direction the header logo uses."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(
                round(a + (b - a) * t) for a, b in zip(start, end)
            )
    return img


def hexagon(size):
    cx = cy = size / 2
    return [
        (
            cx + size * HEX_RADIUS * math.cos(math.radians(START_ANGLE + i * DEG_PER_SIDE)),
            cy + size * HEX_RADIUS * math.sin(math.radians(START_ANGLE + i * DEG_PER_SIDE)),
        )
        for i in range(HEX_SIDES)
    ]


def bolt(size, scale=1.0):
    cx = cy = size / 2
    n = size * scale
    return [(cx - n / 2 + bx * n, cy - n / 2 + by * n) for bx, by in BOLT]


def full_mark(path, start, end):
    """The badge: gradient hexagon with a white bolt. The iOS and legacy icon."""
    big = SIZE * SS
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).polygon(hexagon(big), fill=255)
    out.paste(gradient(SIZE, start, end).resize((big, big), Image.BICUBIC), mask=mask)
    ImageDraw.Draw(out).polygon(bolt(big), fill=(255, 255, 255, 255))
    out.resize((SIZE, SIZE), Image.LANCZOS).save(path)


def foreground(path):
    """Bolt alone on transparency, inset for the adaptive-icon safe zone.

    Android masks the adaptive foreground to the launcher's own outline and only
    the middle ~66% survives every mask, so the bolt is drawn at that scale
    rather than full-bleed. The hexagon is deliberately absent: its points would
    be sliced off by a circular mask, which is why the app draws the badge in
    the header where nothing masks it and lets the launcher show the bolt alone.
    """
    big = SIZE * SS
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(out).polygon(bolt(big, scale=0.6), fill=(255, 255, 255, 255))
    out.resize((SIZE, SIZE), Image.LANCZOS).save(path)


if __name__ == "__main__":
    for flavor, (start, end) in FLAVORS.items():
        suffix = "" if flavor == "prod" else f"_{flavor}"
        path = f"assets/icon/scoreline{suffix}.png"
        full_mark(path, start, end)
        print(f"wrote {path}")

    # One foreground for every flavor: the bolt is white in all three, and the
    # flavor reads from the adaptive background behind it.
    foreground("assets/icon/scoreline_foreground.png")
    print("wrote assets/icon/scoreline_foreground.png")
