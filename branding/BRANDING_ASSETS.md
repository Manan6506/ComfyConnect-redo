# ComfyConnect VPN — Branding Assets Guide

This document lists every visual asset that carries the product brand, and how to
regenerate them from a single master logo when you upload the final ComfyConnect art.

## Palette (locked)

| Role | Hex |
|------|-----|
| Primary blue | `#1E5EFF` |
| Teal accent | `#14B8A6` |
| Ink (dark) | `#0F172A` |
| Surface (light) | `#F8FAFC` |

## What is already rebranded (no art needed)

- **Web admin console** — `src/bin/hamcore/wwwroot/admin/default/logo.svg` (wordmark),
  `theme.css` (blue/teal theme), templates, and favicon. Already ComfyConnect.
- **Repo art** — `resources/comfyconnect-vpn.svg`, `resources/comfyconnect-vpn-server.svg`.
- **All in-app text** — product names, banners, About boxes (server/CLI already verified).

## Windows GUI icons/bitmaps to replace (needs your master logo)

These are compiled into the Windows GUI apps (Server Manager, Client Manager, installer).
Replace them **in place, keeping the exact filename and pixel dimensions**, then rebuild the
GUI on Windows. Only the brand-carrying assets are listed — the ~90 functional glyph icons
(NIC, Memory, Protocol, etc.) do not carry the brand and can stay as-is.

| File | Size | Where it shows |
|------|------|----------------|
| `src/PenCore/SELOGO49x49.bmp` | 49×49 (8-bit BMP) | Logo strip inside GUI dialogs / wizard header |
| `src/vpnsmgr/vpnsmgr.ico` | multi-size .ico | Server Manager app / taskbar icon |
| `src/vpnsmgr/VPNSvr.ico` | multi-size .ico | Server Manager server icon |
| `src/vpncmgr/VPN.ico` | multi-size .ico | Client Manager app / taskbar icon |
| `src/vpncmgr/Server.ico` | multi-size .ico | Client "connected" state |
| `src/vpncmgr/Server_Offline.ico` | multi-size .ico | Client "offline" state |
| `src/PenCore/VPN.ico` | multi-size .ico | Shared VPN icon |
| `src/PenCore/VPNSvr.ico` | multi-size .ico | Shared server icon |
| `src/PenCore/Setup.ico` | multi-size .ico | Installer / setup wizard |
| `src/PenCore/EasyInstaller.ico` | multi-size .ico | Easy Installer output |

> `.ico` files should contain 16, 32, 48, and 256 px frames. `SELOGO49x49.bmp` must remain a
> 49×49 Windows 3.x BMP (8-bit) or the resource compiler layout will shift.

## Do NOT change

- `resources/icons8.png` — Icons8 attribution banner (required by the Icons8 license).
- The ~90 functional glyph icons in `src/PenCore/` that are not in the table above.

## Regenerating from a master logo

Put your master art at `branding/master-logo.svg` (square, transparent) and a horizontal
wordmark at `branding/master-wordmark.svg`, then run:

```sh
branding/generate_brand_assets.sh branding/master-logo.svg
```

The script produces every `.ico`/`.bmp`/favicon at the correct sizes and copies them into place.
It needs ImageMagick (`brew install imagemagick` on macOS, or `choco install imagemagick` on Windows).
