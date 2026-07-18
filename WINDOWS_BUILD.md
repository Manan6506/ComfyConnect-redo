# Building ComfyConnect VPN on Windows

This produces the Windows binaries your clients install: the **VPN Server**, **VPN Client**,
the native **Server Manager / Client Manager GUIs**, and `vpncmd`. Do this on your Windows PC —
the branding is already baked into the source, so this is just a compile.

## 1. Install prerequisites (one time)

1. **Visual Studio 2019 or 2022** (Community Edition is free) —
   https://visualstudio.microsoft.com/downloads
   In the installer, select the **"Desktop development with C++"** workload, and under
   *Individual components* add **"C++ Clang tools for Windows"**.
2. **Git for Windows** — https://gitforwindows.org/
3. **vcpkg**:
   ```
   C:\> git clone https://github.com/microsoft/vcpkg
   C:\> cd vcpkg
   C:\vcpkg> bootstrap-vcpkg.bat
   C:\vcpkg> vcpkg integrate install
   ```

## 2. Get the ComfyConnect source

```
C:\> git clone https://github.com/Manan6506/ComfyConnect-redo
C:\> cd ComfyConnect-redo
C:\ComfyConnect-redo> git submodule update --init --recursive
```

## 3. (Optional) Drop in the final logo

If you have final logo art, generate the Windows icons first (needs ImageMagick):
```
C:\ComfyConnect-redo> branding\generate_brand_assets.sh branding\master-logo.svg
```
Otherwise the placeholder ComfyConnect icons are used. See
[branding/BRANDING_ASSETS.md](branding/BRANDING_ASSETS.md).

## 4. Build

1. Open Visual Studio → **Open a local folder** → select `C:\ComfyConnect-redo`.
2. Wait for it to detect the CMake project (bottom status bar shows "CMake generation finished").
3. In the configuration dropdown pick **x64-native**.
4. Menu **Build → Build All**.

Binaries land in `C:\ComfyConnect-redo\build\`:
`vpnserver.exe`, `vpnclient.exe`, `vpnbridge.exe`, `vpncmd.exe`, `vpnsmgr.exe`
(Server Manager), `vpncmgr.exe` (Client Manager), plus `hamcore.se2`.

## 5. Smoke test on the build machine

```
C:\ComfyConnect-redo\build> vpncmd.exe
```
You should see the banner:
```
ComfyConnect VPN Command Line Management Utility
...
Welcome to ComfyConnect VPN.
```
Then run `vpnsmgr.exe` — the Server Manager GUI opens branded as **ComfyConnect VPN Server Manager**.

## 6. Make the client installer

SoftEther's installer is produced by the internal `BuildUtil`/`vpnsetup` tooling. The simplest
path for distribution is to zip the `build\` output plus a small setup script, or use the
`vpnsetup.exe` self-installer target. Once you confirm the GUIs look right, tell me and I'll
prepare a signed-installer / packaging step tailored to how you want clients to install.

## Notes

- **No phone-home:** DDNS, VPN Azure, the update check, and keep-alive are disabled in this
  build, so clients' servers never contact external SoftEther infrastructure.
- **How clients connect:** point a DNS name or public IP / port-forward at each server. Employees
  connect with the ComfyConnect client, or the built-in OS VPN over OpenVPN / L2TP-IPsec / SSTP.
