# Get the ComfyConnect Windows app (no build tools needed)

You do **not** need Visual Studio or Docker to test on Windows. Your GitHub repo builds the
Windows installers for you automatically, and you just download and run the `.exe`.

## Option 1 — Download the installer from GitHub Actions  ★ recommended

1. Open **https://github.com/Manan6506/ComfyConnect-redo/actions**
2. Click the most recent run of the **`windows.yml` / "windows"** workflow.
   (After a push it takes about **15–20 minutes**; wait for the green ✓ on the `x64` job.)
3. Scroll to the bottom, to **Artifacts**, and download **`Installers-x64`** — it's a `.zip`.
4. Copy the zip to your **Windows server**, unzip it. Inside you'll find:
   - **`ComfyConnect-Server-<version>.x64.exe`** → the VPN Server + Server Manager (install this on the server)
   - **`ComfyConnect-Client-<version>.x64.exe`** → the VPN Client (for employee machines)
5. Run **`ComfyConnect-Server-*.exe`**. It self-extracts and installs. Follow the wizard
   (choose *ComfyConnect VPN Server*).
6. Launch **"ComfyConnect VPN Server Manager"** from the Start menu → connect to `localhost`
   → set the administrator password. You're now in the full native app with every feature.

> Only the `x64` build matters for a normal Windows server. If the `x86` job is red, ignore it.

## Option 2 — Cut a Release for a clean download page

Prefer downloading from a proper Releases page instead of the Actions tab? Push a version tag
and GitHub publishes a Release with the installers attached:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The installers then appear at **https://github.com/Manan6506/ComfyConnect-redo/releases**.

## Option 3 — Just test the server + web console (fastest, needs Docker Desktop)

If you only want to see the server and the web Admin Console working (not the native Windows
GUI), and you have **Docker Desktop** on the machine:

```bash
git clone https://github.com/Manan6506/ComfyConnect-redo
cd ComfyConnect-redo/deploy
./setup.sh          # (in PowerShell: bash setup.sh, or run the docker compose commands)
```

Then open the Admin Console URL it prints. See [GETTING_STARTED.md](../GETTING_STARTED.md).

## If the build fails

The Windows build is involved (vcpkg, MSVC). If the Actions run shows a red ✗, open the failed
step, copy the error, and send it over — most failures are quick, repo-specific fixes.
