#!/usr/bin/env python3
"""Regenerate every brand-carrying asset the product ships, from comfybrand.py.

Replaces the upstream SoftEther artwork (the "S" logo, protocol diagram, Server
Manager banner, About box, University of Tsukuba emblems, and the art for the
disabled VPN Gate / VPN Azure / update features) with ComfyConnect equivalents at
byte-for-byte identical dimensions, plus the Windows .ico icon set.

Run:  python3 branding/generate_assets.py
"""
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comfybrand import (mark, wordmark, font, hx, save_ico,
                        INDIGO, VIOLET, PORCELAIN, COFFEE, STEAM,
                        INK, SLATE, MUTED, WHITE)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PEN  = os.path.join(ROOT, "src", "PenCore")
S    = 3   # supersample for the composite art

def _hgrad(w, h, c1, c2):
    g = Image.new("RGB", (w, h)); px = g.load()
    for x in range(w):
        t = x/float(max(1, w-1))
        col = tuple(int(a+(b-a)*t) for a, b in zip(c1, c2))
        for y in range(h):
            px[x, y] = col
    return g

def bmp(path, size, img):
    """Save `img` as a 24-bit BMP at exactly `size`."""
    if img.size != size:
        img = img.resize(size, Image.LANCZOS)
    img.convert("RGB").save(path, "BMP")
    print(f"  {os.path.basename(path):<24} {size[0]}x{size[1]}")

def banner(size, title, subtitle=None, bg=WHITE):
    """A wide banner: mark on the left, product name to its right."""
    w, h = size
    W, H = w*S, h*S
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    # subtle indigo underline for polish
    d.rectangle([0, H-max(2, int(H*0.045)), W, H], fill=hx('EDE9FE'))
    ms = int(H*0.72)
    m = mark(ms)
    img.paste(m, (int(H*0.16), (H-ms)//2), m)
    x = int(H*0.16) + ms + int(H*0.20)
    fs = int(H*(0.36 if subtitle else 0.42))
    f  = font(fs)
    ty = (H-fs)//2 - int(fs*0.5 if subtitle else fs*0.18)
    d.text((x, ty), "Comfy", font=f, fill=INK)
    wl = d.textlength("Comfy", font=f)
    d.text((x+wl, ty), "Connect", font=f, fill=hx('7C3AED'))
    if subtitle:
        sf = font(int(fs*0.74), bold=False)
        d.text((x, ty+int(fs*1.12)), subtitle, font=sf, fill=SLATE)
    else:
        sf = font(int(fs*0.62), bold=False)
        d.text((x+wl+d.textlength("Connect", font=f)+int(H*0.12), ty+int(fs*0.30)),
               "VPN", font=sf, fill=MUTED)
    return img.resize(size, Image.LANCZOS)

def centered_mark(size, bg=WHITE, frac=0.74):
    w, h = size
    img = Image.new("RGB", (w, h), bg)
    ms = max(8, int(min(w, h)*frac))
    m = mark(ms)
    img.paste(m, ((w-ms)//2, (h-ms)//2), m)
    return img

def centered_wordmark(size, bg=WHITE):
    w, h = size
    img = Image.new("RGB", (w, h), bg)
    wm = wordmark(height=max(12, int(h*0.62)))
    if wm.width > int(w*0.92):
        nh = max(10, int(wm.height * (w*0.92)/wm.width))
        wm = wordmark(height=nh)
    img.paste(wm, ((w-wm.width)//2, (h-wm.height)//2), wm)
    return img

def protocol_figure(size=(428, 160)):
    """Replaces VPNServerFigure.bmp — the Welcome-screen diagram that read
    'SoftEther VPN'. Same idea (which clients can connect), ComfyConnect styling."""
    w, h = size
    W, H = w*S, h*S
    img = Image.new("RGB", (W, H), WHITE)
    d = ImageDraw.Draw(img)

    # headline bar
    bar_h = int(H*0.30)
    bar = _hgrad(W, bar_h, INDIGO, VIOLET)
    m = Image.new("L", (W, bar_h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W-1, bar_h-1],
                                        radius=int(bar_h*0.34), fill=255)
    img.paste(bar, (0, 0), m)
    bd = ImageDraw.Draw(img)
    tf = font(int(bar_h*0.50))
    t = "ComfyConnect VPN"
    bd.text(((W-bd.textlength(t, font=tf))//2, int(bar_h*0.24)), t,
            font=tf, fill=WHITE)

    protos  = ["SSL-VPN", "OpenVPN", "L2TP/IPsec", "MS-SSTP", "L2TPv3", "EtherIP"]
    clients = ["Windows", "Mac", "iPhone\nAndroid", "Windows", "Routers", "Linux"]
    n = len(protos)
    colw = W/float(n)
    pf = font(int(H*0.085))
    cf = font(int(H*0.078), bold=False)

    for i, (p, c) in enumerate(zip(protos, clients)):
        cx = colw*(i+0.5)
        # pill
        pw, ph = colw*0.86, int(H*0.15)
        py = bar_h + int(H*0.10)
        bd.rounded_rectangle([cx-pw/2, py, cx+pw/2, py+ph],
                             radius=int(ph*0.5), fill=hx('EDE9FE'),
                             outline=hx('C4B5FD'), width=max(1, int(H*0.008)))
        bd.text((cx-bd.textlength(p, font=pf)/2, py+ph*0.24), p, font=pf,
                fill=hx('5B21B6'))
        # up arrow
        ay = py + ph + int(H*0.075)
        bd.line([(cx, ay+int(H*0.16)), (cx, ay)], fill=STEAM,
                width=max(2, int(H*0.022)))
        a = int(H*0.045)
        bd.polygon([(cx, ay-a*0.7), (cx-a, ay+a*0.5), (cx+a, ay+a*0.5)], fill=STEAM)
        # client label
        ly = ay + int(H*0.21)
        for j, line in enumerate(c.split("\n")):
            bd.text((cx-bd.textlength(line, font=cf)/2, ly+j*int(H*0.095)),
                    line, font=cf, fill=SLATE)
    return img.resize(size, Image.LANCZOS)


def protocol_diagram(size, client="VPN Client", proto="Encrypted tunnel"):
    """Simple client -> ComfyConnect server diagram, replacing upstream art that
    labelled the server box 'SoftEther VPN Server'."""
    w, h = size
    W, H = w*S, h*S
    img = Image.new("RGB", (W, H), WHITE)
    d = ImageDraw.Draw(img)
    bw, bh = W*0.26, H*0.34
    cy = H*0.50
    lf, sf = font(int(H*0.095)), font(int(H*0.082), bold=False)
    # client box
    d.rounded_rectangle([W*0.04, cy-bh/2, W*0.04+bw, cy+bh/2],
                        radius=int(H*0.06), fill=hx('EDE9FE'),
                        outline=hx('C4B5FD'), width=max(1, int(H*0.012)))
    d.text((W*0.04+bw/2 - d.textlength(client, font=lf)/2, cy-int(H*0.05)),
           client, font=lf, fill=hx('5B21B6'))
    # server box (ours)
    sx = W*0.70
    d.rounded_rectangle([sx, cy-bh/2, sx+bw, cy+bh/2], radius=int(H*0.06),
                        fill=hx('312E81'))
    # shrink the label until it fits inside the box (no clipped text)
    t, t2 = "ComfyConnect", "VPN Server"
    bf, bs = int(H*0.095), int(H*0.082)
    while bf > 6 and d.textlength(t, font=font(bf)) > bw*0.88:
        bf -= 1
    while bs > 5 and d.textlength(t2, font=font(bs, bold=False)) > bw*0.88:
        bs -= 1
    f1, f2 = font(bf), font(bs, bold=False)
    d.text((sx+bw/2 - d.textlength(t, font=f1)/2, cy-int(H*0.09)), t,
           font=f1, fill=WHITE)
    d.text((sx+bw/2 - d.textlength(t2, font=f2)/2, cy+int(H*0.01)), t2,
           font=f2, fill=hx('C4B5FD'))
    # tunnel arrow
    ax0, ax1 = W*0.04+bw+W*0.03, sx-W*0.03
    d.line([(ax0, cy), (ax1, cy)], fill=STEAM, width=max(2, int(H*0.030)))
    a = int(H*0.055)
    d.polygon([(ax1+a*0.6, cy), (ax1-a*0.5, cy-a), (ax1-a*0.5, cy+a)], fill=STEAM)
    d.text(((ax0+ax1)/2 - d.textlength(proto, font=sf)/2, cy-int(H*0.155)),
           proto, font=sf, fill=SLATE)
    return img.resize(size, Image.LANCZOS)

# ── what to regenerate: filename -> builder ──────────────────────────────────
JOBS = {
    # seen directly in the installer / Server Manager
    "SELOGO49x49.bmp":     lambda s: centered_mark(s, frac=0.96),
    "VPNServerFigure.bmp": protocol_figure,
    "ManagerLogo.bmp":     lambda s: banner(s, None, "VPN Server Manager"),
    "ClientBanner.bmp":    lambda s: banner(s, None, "VPN Client"),
    "AboutBox.bmp":        lambda s: banner(s, None, "Secure remote access"),
    "RouterBanner.bmp":    lambda s: banner(s, None, "VPN Router"),
    "RouterLogo.bmp":      lambda s: centered_mark(s),
    # university / regional emblems — replaced with our own wordmark
    "BMP_UT.bmp":          centered_wordmark,
    "UnivTsukuba.bmp":     centered_wordmark,
    "Tsukuba.bmp":         lambda s: centered_mark(s),
    "Ibaraki.bmp":         lambda s: centered_mark(s),
    # setup-wizard language banners
    "SW_LANG_1.bmp":       lambda s: banner(s, None, "Setup"),
    "SW_LANG_2.bmp":       lambda s: banner(s, None, "Setup"),
    "SW_LANG_3.bmp":       centered_wordmark,
    # art for features we disable (VPN Gate / VPN Azure / update check)
    "VPNGateBanner.bmp":   centered_wordmark,
    "VPNGateEN.bmp":       lambda s: centered_mark(s, frac=0.45),
    "VPNGateJA.bmp":       lambda s: centered_mark(s, frac=0.45),
    "Azure.bmp":           lambda s: centered_mark(s, frac=0.45),
    "AzureCn.bmp":         lambda s: centered_mark(s, frac=0.45),
    "AzureJa.bmp":         lambda s: centered_mark(s, frac=0.45),
    "Update.bmp":          lambda s: banner(s, None, "Software Update"),
    # diagrams whose upstream art labelled the server box "SoftEther VPN Server"
    "OpenVPN.bmp":         lambda s: protocol_diagram(s, "OpenVPN Client", "OpenVPN protocol"),
    "SSTP.bmp":            lambda s: protocol_diagram(s, "Windows client", "MS-SSTP protocol"),
    "VMBridge.bmp":        lambda s: protocol_diagram(s, "Virtual machine", "Bridged network"),
    "SpecialListener.bmp": lambda s: protocol_diagram(s, "VPN Client", "VPN over ICMP / DNS"),
    "setup_1.bmp":         lambda s: centered_mark(s, frac=0.62),
    "setup_2.bmp":         lambda s: protocol_diagram(s, "Branch site", "Site-to-site"),
    # University of Tsukuba lettering / mascot / smartcard photos carrying the old logo
    "Coins.bmp":           centered_wordmark,
    "Zurukko.bmp":         lambda s: centered_mark(s, frac=0.86),
    "Test.bmp":            lambda s: centered_mark(s, frac=0.86),
    "Secure.bmp":          lambda s: centered_mark(s, frac=0.50),
    "Secure2.bmp":         lambda s: centered_mark(s, frac=0.70),
    "Secure3.bmp":         lambda s: centered_mark(s, frac=0.70),
}

def main():
    print("Regenerating installer/GUI bitmaps from the ComfyConnect brand:")
    missing = []
    for name, build in JOBS.items():
        path = os.path.join(PEN, name)
        if not os.path.exists(path):
            missing.append(name); continue
        size = Image.open(path).size          # keep the exact original dimensions
        bmp(path, size, build(size))
    if missing:
        print("  (skipped, not present:", ", ".join(missing), ")")

    print("Generating Windows icon set:")
    for ico in ("vpnsmgr/vpnsmgr.ico", "vpnsmgr/VPNSvr.ico",
                "vpncmgr/VPN.ico", "vpncmgr/Server.ico", "vpncmgr/Server_Offline.ico",
                "PenCore/VPN.ico", "PenCore/VPNSvr.ico",
                "PenCore/Setup.ico", "PenCore/EasyInstaller.ico"):
        p = os.path.join(ROOT, "src", ico)
        if os.path.exists(p):
            save_ico(p); print(f"  {ico}")

    print("Web console assets:")
    web = os.path.join(ROOT, "src", "bin", "hamcore", "wwwroot", "admin", "default")
    if os.path.isdir(web):
        mark(256).save(os.path.join(web, "favicon.png"))
        wordmark(96, on_dark=True ).save(os.path.join(web, "logo.png"))        # navbar
        wordmark(96, on_dark=False).save(os.path.join(web, "logo-light.png"))  # cards
        print("  favicon.png, logo.png, logo-light.png")
    print("done.")

if __name__ == "__main__":
    main()
