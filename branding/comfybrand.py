#!/usr/bin/env python3
"""ComfyConnect brand system — the single source of truth for the mark.

The mark: a coffee mug whose steam doubles as a signal — "secure work from home".
Tile: squircle, indigo→violet gradient. Mug: porcelain white, amber coffee, aqua steam.

Everything the product ships (Windows icons, installer bitmaps, web favicon) is
generated from the functions here so the brand can never drift out of sync again.
"""
from PIL import Image, ImageDraw, ImageFont

S = 4  # supersample factor — draw big, downsample for clean edges

def hx(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

# ── Palette ──────────────────────────────────────────────────────────────────
INDIGO   = hx('312E81')   # tile gradient start
VIOLET   = hx('6D28D9')   # tile gradient end
PORCELAIN= hx('FFFFFF')   # mug body
COFFEE   = hx('FBBF24')   # amber accent
STEAM    = hx('5EEAD4')   # aqua signal
INK      = hx('0F172A')   # text / dark surfaces
SLATE    = hx('475569')
MUTED    = hx('94A3B8')
SURFACE  = hx('F1F5F9')   # light background
WHITE    = hx('FFFFFF')

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REG  = "/System/Library/Fonts/Supplemental/Arial.ttf"

def font(size, bold=True):
    return ImageFont.truetype(BOLD if bold else REG, size)

# ── The mark ─────────────────────────────────────────────────────────────────
def _gradient_tile(n, c1=INDIGO, c2=VIOLET, radius_frac=0.42):
    g = Image.new("RGB", (n, n)); px = g.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2.0 * n)
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n-1, n-1],
                                           radius=int(n*radius_frac), fill=255)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(g, (0, 0), mask)
    return out

def _draw_mug(d, n, cx, cy, bw, bh, body, coffee, steam):
    """Barrel mug with an ATTACHED handle: the handle ring is drawn first, then
    the body is painted over its left side so the two read as one object."""
    top, bot = cy - bh/2, cy + bh/2
    tw, bwid = bw, bw*0.93          # gentle taper
    r = n*0.075                     # bottom corner radius (barrel = rounder)

    d.ellipse([cx + tw*0.20, cy - bh*0.30, cx + tw*0.92, cy + bh*0.30],
              outline=body, width=int(n*0.040))                     # handle
    d.polygon([(cx-tw/2, top), (cx+tw/2, top),
               (cx+bwid/2, bot-r), (cx-bwid/2, bot-r)], fill=body)  # body
    d.rounded_rectangle([cx-bwid/2, bot-2*r, cx+bwid/2, bot],
                        radius=int(r), fill=body)                   # rounded base

    lip, rh = n*0.014, n*0.062
    d.ellipse([cx-tw/2-lip, top-rh/2, cx+tw/2+lip, top+rh/2], fill=body)   # rim
    ins = n*0.030
    d.ellipse([cx-tw/2-lip+ins, top-rh/2+ins*0.42,
               cx+tw/2+lip-ins, top+rh/2-ins*0.42], fill=coffee)           # coffee

    for rad in (n*0.090, n*0.142, n*0.194):                                # steam
        d.arc([cx-rad, top-rh/2-rad*0.84-n*0.030,
               cx+rad, top-rh/2+rad*0.84-n*0.030],
              203, 337, fill=steam, width=int(n*0.032))

def mark(size, tile=True, body=PORCELAIN, coffee=COFFEE, steam=STEAM):
    """The ComfyConnect mark. tile=False gives a transparent, freestanding mug."""
    n = size*S
    img = _gradient_tile(n) if tile else Image.new("RGBA", (n, n), (0,0,0,0))
    d = ImageDraw.Draw(img)
    k = 1.0 if tile else 1.20
    _draw_mug(d, n, n/2 - n*0.030, n/2 + n*0.105,
              n*0.300*k, n*0.265*k, body, coffee, steam)
    return img.resize((size, size), Image.LANCZOS)

# ── Wordmark lockup ──────────────────────────────────────────────────────────
def wordmark(height=96, on_dark=False, mark_size=None, gap=18, pad=0):
    """'[mark] ComfyConnect' lockup sized to `height`. Returns an RGBA image."""
    ms = mark_size or int(height*0.82)
    m = mark(ms)
    fs = int(height*0.46)
    f = font(fs)
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    w1 = probe.textlength("Comfy", font=f)
    w2 = probe.textlength("Connect", font=f)
    W = pad*2 + ms + gap + int(w1 + w2)
    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    img.paste(m, (pad, (height-ms)//2), m)
    d = ImageDraw.Draw(img)
    ty = (height - fs)//2 - int(fs*0.16)
    x = pad + ms + gap
    d.text((x, ty), "Comfy", font=f, fill=WHITE if on_dark else INK)
    d.text((x + w1, ty), "Connect", font=f, fill=STEAM if on_dark else hx('7C3AED'))
    return img

# ── Output helpers ───────────────────────────────────────────────────────────
def save_bmp(img, path, size, bg=WHITE):
    """Flatten onto `bg` and save a 24-bit BMP at exactly `size` (w,h)."""
    canvas = Image.new("RGB", size, bg)
    im = img.convert("RGBA")
    im.thumbnail((size[0], size[1]), Image.LANCZOS)
    canvas.paste(im, ((size[0]-im.width)//2, (size[1]-im.height)//2), im)
    canvas.save(path, "BMP")
    return canvas

def save_ico(path, sizes=(16, 32, 48, 64, 128, 256)):
    base = mark(256)
    base.save(path, format="ICO", sizes=[(s, s) for s in sizes])

if __name__ == "__main__":
    mark(512).save("/tmp/cc_mark.png")
    wordmark(120).save("/tmp/cc_wordmark.png")
    print("brand module OK")
