<p align="center">
  <img src="resources/comfyconnect-vpn.svg" width="96" alt="ComfyConnect VPN">
</p>

# ComfyConnect VPN

**Secure remote access for teams — a managed work-from-home VPN service.**

ComfyConnect VPN is a white-label distribution built on the open-source
[SoftEther VPN](https://github.com/SoftEtherVPN/SoftEtherVPN) engine. It provides
a multi-protocol VPN server (OpenVPN, L2TP/IPsec, SSTP, and the native VPN
protocol) plus a browser-based administration console, rebranded and themed for
ComfyConnect.

## What's in this repository

| Component | Description | Platform |
|-----------|-------------|----------|
| VPN Server | The core service clients connect to | Windows, Linux, macOS |
| VPN Bridge / Client | Site-to-site and client daemons | Windows, Linux, macOS |
| `vpncmd` | Command-line admin tool | All |
| Web Admin Console | HTML5 browser console (blue/teal ComfyConnect theme) | All (served by the server) |
| Server / Client Manager (GUI) | Native management apps | Windows only |

## Building

- **Server / CLI (Linux, macOS):** see [src/BUILD_UNIX.md](src/BUILD_UNIX.md).
  In short: `./configure && make -C build`.
- **Windows GUI + installer:** see [src/BUILD_WINDOWS.md](src/BUILD_WINDOWS.md)
  and [WINDOWS_BUILD.md](WINDOWS_BUILD.md) in this repo.

## Branding

All product names, banners, the web console, and repo art are rebranded to
ComfyConnect. To swap in final logo art, see
[branding/BRANDING_ASSETS.md](branding/BRANDING_ASSETS.md).

## Attribution & license

ComfyConnect VPN is distributed under the **Apache License 2.0** (see
[LICENSE](LICENSE)) and is based on SoftEther VPN. Upstream copyright and
third-party component notices are retained in [NOTICE](NOTICE). "SoftEther" is a
trademark of its respective owner and is referenced only to attribute the
upstream project.

## Documentation

- **[User Manual & Administrator Guide](docs/USER_MANUAL.md)** — complete guide: deploy, administer (web console / native GUI / `vpncmd` / API), every feature module, and a full command reference.
