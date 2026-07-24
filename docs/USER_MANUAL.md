# ComfyConnect VPN — User Manual & Administrator Guide

**The complete guide to deploying, operating, and selling ComfyConnect VPN** — a managed work-from-home VPN service built on the SoftEther VPN engine.

Version 5.02 · Covers the VPN Server, the web Admin Console, the native Server Manager, the `vpncmd` CLI, and the JSON-RPC API.

---

## Table of Contents

1. [Introduction & Core Concepts](#1-introduction-and-core-concepts)
2. [The Four Ways to Administer ComfyConnect](#2-the-four-ways-to-administer-comfyconnect)
3. [Installation & First Run](#3-installation-and-first-run)
4. [The Web Admin Console](#4-the-web-admin-console)
5. [Virtual Hubs](#5-virtual-hubs)
6. [Users, Groups & Authentication](#6-users-groups-and-authentication)
7. [Security Policies & Access Control](#7-security-policies-and-access-control)
8. [Certificates & TLS](#8-certificates-and-tls)
9. [Networking: SecureNAT, Bridges, Cascade & Routing](#9-networking-securenat-bridges-cascade-and-routing)
10. [VPN Protocols & Connecting Employees](#10-vpn-protocols-and-connecting-employees)
11. [Logging, Monitoring & Server Administration](#11-logging-monitoring-and-server-administration)
12. [Security & Hardening](#12-security-and-hardening)
13. [Tips, Tricks & Troubleshooting](#13-tips-tricks-and-troubleshooting)
A. [Command Reference](#appendix-a-command-reference)

---

## 1. Introduction & Core Concepts

### What ComfyConnect Is

ComfyConnect VPN is a managed work-from-home VPN service built on the SoftEther VPN engine. It gives a remote employee an encrypted tunnel from their laptop (at home, in a café, on hotel Wi-Fi) into a private company network, so they can reach internal servers, file shares, and applications as if they were sitting at a desk in the office.

For you — the vendor operating this service — ComfyConnect is a single VPN Server that you run once and then carve up to serve many separate client companies at the same time, each fully isolated from the others. Employees connect using standard, built-in protocols (OpenVPN, L2TP/IPsec, or SSTP), so there is no proprietary client to install and support.

### The Business Model: One Server, Many Companies

The service is multi-tenant by design. You stand up one ComfyConnect VPN Server and sell "a VPN" to Acme Corp, to Globex, to Initech — but under the hood they all share the same server process. What keeps them separate is the **Virtual Hub**: each client company gets its own Virtual Hub, which behaves like a private, isolated virtual switch. Traffic, users, and settings in Acme's hub never touch Globex's hub.

This is what makes the economics work: you provision new tenants in seconds by creating a new hub, rather than deploying a new server per customer. You manage the whole fleet from one place, patch one binary, and bill per hub or per employee.

### The Mental Model (A Diagram in Words)

Picture the system as three layers, top to bottom:

```
                    ComfyConnect VPN Server  (one process, one host)
                    ┌───────────────────────────────────────────────┐
                    │                                                 │
     Virtual Hub "Acme-Corp"        Virtual Hub "Globex"       Virtual Hub "Initech"
     (isolated virtual network)     (isolated network)         (isolated network)
     ┌───────────────────────┐      ┌──────────────────┐       ┌──────────────────┐
     │ Users: jane.doe,      │      │ Users: ...        │       │ Users: ...        │
     │        bob.smith      │      │                   │       │                   │
     │ Sessions: live conns  │      │                   │       │                   │
     │ SecureNAT  ──►  Internet /   │                   │       │                   │
     │ Local Bridge ──► office LAN  │                   │       │                   │
     └───────────────────────┘      └──────────────────┘       └──────────────────┘
            ▲          ▲
            │          │  (encrypted tunnels: OpenVPN / L2TP-IPsec / SSTP)
        jane.doe    bob.smith
        (laptop)    (laptop)
```

Each employee's laptop opens an encrypted tunnel to the server, authenticates, and lands inside exactly one Virtual Hub. Inside that hub they can reach whatever the hub is wired to — the open internet, the client's office LAN, or another site — depending on how you connected the hub.

### Core Concepts

**VPN Server** — The single service process at the center of everything. It listens for incoming connections, terminates the encrypted tunnels, hosts all the Virtual Hubs, and is where you (the vendor) do global administration with the server-admin password. In the Docker deploy its management port (5555) is bound to localhost, so you reach it over an SSH tunnel — the tenant-facing VPN ports stay public, but administration does not.

**Virtual Hub** — An isolated virtual Ethernet network living inside the server. This is the unit of multi-tenancy: **one hub per client company**. A hub has its own set of users, its own security policies, its own sessions, and its own connection to the outside world. Nothing crosses between hubs unless you deliberately wire them together. When you onboard a new client, you create a new hub (for example `Acme-Corp`).

**User / Employee** — An account that lives inside one specific hub and represents one person who is allowed to connect. In ComfyConnect the standard method is **password authentication** — you create the user, set (or reset) their password, and hand them a connection profile. A user in the `Acme-Corp` hub can only ever connect into `Acme-Corp`.

**Session** — One active, connected tunnel: a specific employee's live connection into a hub right now. Sessions are what you watch on the Overview and Live Sessions screens; each has a source, a user, and traffic counters, and you can forcibly disconnect one (for example, to kick off a departing employee immediately).

**SecureNAT** — A built-in, self-contained gateway you can switch on inside a hub. It gives connected employees an IP address (its own DHCP) and routes their traffic out to the internet or the surrounding network (its own NAT) — all in software, with no changes to the host's routing or kernel. It is the fastest way to get a hub "online" for employees, which is why the standard deploy enables it. The trade-off is that it is a software router, so for very high throughput a Local Bridge is leaner.

**Local Bridge** — A connection that joins a Virtual Hub directly to a physical network adapter on the server (or a tap device), placing VPN clients onto a real office LAN as if they were plugged into the office switch. Use this when employees need to be full first-class citizens of the corporate network (same subnet, reachable by internal DHCP and services) rather than sitting behind SecureNAT.

**Cascade** — A hub-to-hub link. A Cascade connection makes one Virtual Hub connect *as a client* into another Virtual Hub, possibly on a different server, merging the two into one Ethernet segment. This is how you build site-to-site setups — for example, joining a client's cloud hub to a hub running in their branch office so both sides share one network.

### How Employees Actually Connect

An employee never sees any of this internal structure. You (or the onboarding script) create their user in the right hub and generate a connection profile. They import that profile into a standard client — OpenVPN, their operating system's built-in L2TP/IPsec, or SSTP — enter their password, and connect. From that moment their laptop behaves as though it were on the company network, and you can see their session live in the console.

### The Four Ways to Administer (and What This Manual Assumes)

You have four tools for running the service, and they are not equal in reach:

- **ComfyConnect VPN Server Manager (vpnsmgr.exe)** — the full native Windows GUI; exposes every setting.
- **Web Admin Console** (`https://SERVER:5555/admin/`) — a new, deliberately simplified browser panel covering the everyday jobs only: sign-in, an Overview of live stats and hubs, managing Employees, watching Live Sessions, and creating or deleting Virtual Hubs. Anything deeper is intentionally not here.
- **vpncmd CLI** — the scriptable command line; every setting, 321 commands.
- **JSON-RPC API** (`/api/`) — the programmatic interface the web console itself uses, for automation.

Throughout this manual, each task tells you which tool to use. Where a job can be done in the Web console, we show that first because it is the quickest. Where the console cannot do it, we say so plainly — "not in the web console yet — use the Server Manager or vpncmd" — and give you the GUI menu path or a real CLI command instead. The remaining sections build directly on the concepts above: standing up a server, onboarding clients and employees, wiring hubs to networks, watching sessions, and locking the service down.

---

## 2. The Four Ways to Administer ComfyConnect

ComfyConnect gives you four separate doors into the same VPN engine. They all talk to the identical server — a hub you create in the CLI shows up instantly in the GUI, a user you add in the web console can be edited in the Server Manager, and so on. What differs is **how much** each door exposes. Pick the door that matches the job.

- **ComfyConnect VPN Server Manager (native Windows GUI)** — the full cockpit; every setting the engine has.
- **Web Admin Console (browser)** — a deliberately simplified panel for day-to-day employee and session management.
- **vpncmd (command-line)** — the full engine again, scriptable; 321 commands.
- **JSON-RPC API (`/api/`)** — 130 methods for automation and integrations; this is what the web console itself calls.

### 2.1 ComfyConnect VPN Server Manager (native GUI)

**What it is** — The `vpnsmgr.exe` desktop application that runs on Windows. It connects to your server over the management port and gives you a windowed interface to **every** configuration surface: hubs, users and groups, cascade connections, SecureNAT, local bridges, clustering, certificates, logging, and all the security toggles.

**Why it matters (for a WFH-VPN business)** — This is where you do the deep setup and the occasional advanced change that the simplified web console can't reach. When a customer needs RADIUS/LDAP auth, per-user security policies, or Layer-2 bridging, this is your tool.

**How to do it** — Install the ComfyConnect VPN Server Manager on a Windows machine, add a "New Setting" pointing at your server's host and management port, enter the server-admin password, and connect. From the hub list you double-click a hub to "Manage Virtual Hub" and reach users, groups, sessions, and hub-level security.

**Tip** — The GUI is the most discoverable way to learn the product: nearly every action it performs maps one-to-one to a vpncmd command, so it's a good place to figure out *what* to automate later.

### 2.2 Web Admin Console (browser)

**What it is** — A new, lightweight panel the vendor added on top of the engine. It is a **subset**, not a replacement. It does exactly these things and nothing more:

- Sign in with the server-admin password
- **Overview** — live server stats and the list of Virtual Hubs
- **Employees** — per-hub user list; add a user with **password** authentication; remove a user; reset a password
- **Live Sessions** — list connected sessions and disconnect one
- **Virtual Hubs** — create and delete hubs

Anything beyond that — certificate auth, RADIUS/LDAP, security policies, cascades, SecureNAT tuning, logging — is **not in the web console yet; use the Server Manager or vpncmd.**

**Why it matters** — It lets a non-technical admin (an office manager, an IT-lite person at the customer) handle the routine 90%: onboard a new hire, kill a stuck session, reset a forgotten password — without installing Windows software or learning the CLI.

**How to reach it — SSH tunnel to the management port.** In the Docker deploy the management port **5555** is bound to `localhost` on the server (no phone-home, not exposed to the internet). Open an SSH tunnel from your laptop, then browse to the console locally:

```bash
# Forward local :5555 to the server's localhost:5555
ssh -L 5555:localhost:5555 admin@vpn.acme-corp.example

# Then open in your browser:
#   https://localhost:5555/admin/
```

**Gotcha** — Because 5555 is localhost-only, the console is unreachable without the tunnel by design. If a customer says "the admin page won't load," check the tunnel first. (The console can also be served on :443 depending on how the deploy was configured.)

### 2.3 vpncmd (command-line)

**What it is** — The command-line administration utility. It exposes the full engine — the same 321 commands the GUI drives — and is the right tool for scripting, onboarding automation, and anything you want repeatable.

**Why it matters** — Everything the vendor's `deploy/setup.sh` and `onboarding/add-employee.sh` scripts do, they do through vpncmd. When you need to provision ten hubs or bulk-create users, this is the door.

**Invocation pattern** — Point vpncmd at the server in Server-admin mode, pass the admin password, and give it a command with its arguments:

```
vpncmd <host> /SERVER /PASSWORD:<adminpw> /CMD <Command> <args...>
```

For commands that operate **inside a specific hub**, add `/ADMINHUB:<HubName>` so vpncmd knows which hub to manage.

**Examples** — Every command below is a real engine command:

```bash
# Server-wide: live status and the hub list
vpncmd 127.0.0.1 /SERVER /PASSWORD:s3cret /CMD ServerStatusGet
vpncmd 127.0.0.1 /SERVER /PASSWORD:s3cret /CMD HubList

# Create a hub
vpncmd 127.0.0.1 /SERVER /PASSWORD:s3cret /CMD HubCreate Acme-Corp

# Hub-scoped: create a user and list live sessions in that hub
vpncmd 127.0.0.1 /SERVER /PASSWORD:s3cret /ADMINHUB:Acme-Corp /CMD UserCreate jane.doe
vpncmd 127.0.0.1 /SERVER /PASSWORD:s3cret /ADMINHUB:Acme-Corp /CMD SessionList
```

For reference, `ServerStatusGet` returns "the current status of the currently connected VPN Server" — real-time traffic and object counts — while `SessionList` returns "a list of the sessions connected to the Virtual Hub currently being managed," which is why it needs `/ADMINHUB`.

**Tip** — Run vpncmd on the server itself (against `127.0.0.1`) or over the same SSH tunnel you use for the console. Every CLI command carries a built-in help string; from an interactive vpncmd prompt, type a command name with `/HELP` to read it before you use it.

### 2.4 JSON-RPC API (`/api/`)

**What it is** — A JSON-RPC 2.0 HTTP API exposing 130 methods over the management port. It authenticates with the same server-admin password and is what the **web console itself is built on**.

**Why it matters** — This is the integration surface. Wire ComfyConnect into a customer portal, a provisioning pipeline, or a monitoring dashboard — pull live session counts, create hubs, add users — all programmatically, without shelling out to vpncmd.

**How to do it** — POST JSON-RPC requests to `/api/` on the management port (reached through the same SSH tunnel). The method names mirror the CLI concepts (for example, getting server status or enumerating hubs).

**Example**

```bash
curl -k -X POST https://localhost:5555/api/ \
  -H "Content-Type: application/json" \
  -H "X-VPNADMIN-PASSWORD: s3cret" \
  -d '{"jsonrpc":"2.0","id":"1","method":"GetServerStatus","params":{}}'
```

**Gotcha** — The API is powerful but only lightly documented for this white-label; when in doubt, confirm behavior against the equivalent vpncmd command, which carries authoritative built-in help.

### 2.5 Capability comparison — which door does what

The key thing to internalize: **the web console is a simplified subset; the Server Manager and vpncmd are full-featured; the API sits behind the console.** Use this table to route any task.

| Task | Web Console | Server Manager (GUI) | vpncmd | JSON-RPC API |
|---|---|---|---|---|
| Sign in with admin password | Yes | Yes | Yes | Yes |
| Overview: live stats + hub list | Yes | Yes | Yes (`ServerStatusGet`, `HubList`) | Yes |
| Create / delete Virtual Hubs | Yes | Yes | Yes (`HubCreate`) | Yes |
| List employees per hub | Yes | Yes | Yes | Yes |
| Add user (password auth) | Yes | Yes | Yes (`UserCreate`) | Yes |
| Remove user / reset password | Yes | Yes | Yes | Yes |
| List / disconnect live sessions | Yes | Yes | Yes (`SessionList`, `SessionDisconnect`) | Yes |
| Certificate / RADIUS / LDAP auth | **No** | Yes | Yes | Yes |
| Per-user & per-group security policies | **No** | Yes | Yes | Yes |
| Groups, cascades, SecureNAT tuning, local bridge | **No** | Yes | Yes | Yes |
| Clustering, logging, listener ports, certs | **No** | Yes | Yes | Yes |
| Scripting / bulk provisioning | **No** | Limited | Yes | Yes |

**Rule of thumb** — Reach for the **web console** for daily people-and-session tasks; drop to the **Server Manager** when you need a setting the console doesn't show; use **vpncmd** when you want it scripted; call the **API** when another system needs to drive ComfyConnect for you. Whenever the console can't do something, the honest answer is: *not in the web console yet — use the Server Manager or vpncmd.*

---

## 3. Installation & First Run

This section takes you from an empty Linux host to a running, signed-in ComfyConnect VPN Server. There are two things you can build: the **server** (a one-command Docker deploy — this is what your employees connect to) and the optional **Windows Server Manager GUI** (the full-featured admin app you run on your own PC). Most administrators only need the server plus the web console; build the GUI only when you want every setting SoftEther exposes.

### 3.1 Deploy the server — one command

**What it is** — `deploy/setup.sh` builds and starts the ComfyConnect VPN Server in Docker, sets the admin password, creates your first Virtual Hub, turns on SecureNAT, and enables OpenVPN, SSTP, and L2TP/IPsec — then prints the console URL and credentials.

**Why it matters** — one command gets you a working WFH-VPN your team can connect to, with no hand-editing of config files and no guessable default secrets.

**How to do it** — on a Linux host with Docker and the Docker Compose plugin installed, run the script from the `deploy/` directory. You can accept the defaults or pass a hub name and admin password up front.

**Example**

```bash
cd /opt/comfyconnect/deploy

# Simplest: sensible defaults, secrets auto-generated
./setup.sh

# Or choose your own hub name and admin password
ADMIN_PW='S0me-Strong-Passphrase' HUB='Acme-Corp' ./setup.sh
```

**What it configures, step by step**

1. **Builds and starts** the server container (`docker compose up -d --build`). The first build pulls dependencies and takes a few minutes; later runs are fast.
2. **Waits** for the server to answer management calls before continuing.
3. **Sets the administrator password** (via `ServerPasswordSet`). If you did not pass `ADMIN_PW`, a strong 20-character random password is generated for you.
4. **Creates the Virtual Hub** (`HubCreate`) — default name `ComfyConnect`, or whatever you set in `HUB`.
5. **Enables SecureNAT** (`SecureNatEnable`) on that hub, which hands connecting employees an IP address and routes their traffic — no separate DHCP or router config needed.
6. **Enables OpenVPN and SSTP** (`ProtoOptionsSet`) so employees can connect with the built-in OS clients.
7. **Enables L2TP/IPsec** (`IPsecEnable`) with an auto-generated pre-shared key, tied to your default hub.

**The printed output** — on success you get a summary like this:

```text
============================================================
  ✅  ComfyConnect VPN Server is up.
============================================================
  Admin Console : https://203.0.113.10:5555/admin/
                  (or https://203.0.113.10:443/admin/)
  Default hub   : Acme-Corp

  Credentials (admin password + IPsec PSK) were written to:
      /opt/comfyconnect/deploy/comfyconnect-credentials.txt   (chmod 600)
============================================================
```

The admin password and IPsec PSK are also written to an owner-only file, `comfyconnect-credentials.txt` (permissions `600`), so they survive even if your terminal scrollback is lost.

**Gotcha** — that credentials file is plaintext by design. Read it once, copy the admin password and IPsec PSK into your password manager, then delete the file:

```bash
cat /opt/comfyconnect/deploy/comfyconnect-credentials.txt
rm /opt/comfyconnect/deploy/comfyconnect-credentials.txt
```

**Tip** — to re-run cleanly, the hub-create step is idempotent-ish: if the hub already exists the script continues rather than failing.

### 3.2 Firewall and ports

**What it is** — the set of ports the server needs open at your cloud firewall / security group so employees (and you) can reach it.

**Why it matters** — if these are closed, clients silently fail to connect and the console is unreachable; if the management port is exposed, your whole server is at risk.

**How to do it** — open these inbound, and leave the management port closed to the internet:

| Port | Protocol | Purpose |
|------|----------|---------|
| 443  | TCP | HTTPS — SSTP, SoftEther SSL-VPN, and the web console |
| 992  | TCP | SoftEther SSL-VPN (legacy/alternate control port) |
| 1194 | UDP | OpenVPN |
| 500  | UDP | L2TP/IPsec (IKE) |
| 4500 | UDP | L2TP/IPsec (NAT-T) |
| 5555 | TCP | **Management / web console — localhost only, do NOT open to the internet** |

**Gotcha** — in the Docker deploy, port **5555 is bound to `127.0.0.1`** on purpose. Do not add a firewall rule to expose it. Reach the console over an SSH tunnel instead (see 3.4).

### 3.3 Build the Windows Server Manager GUI (optional)

**What it is** — the native **ComfyConnect VPN Server Manager** (`vpnsmgr.exe`), the full desktop admin app that exposes every server setting — far more than the web console. Building it also produces `vpncmd.exe` and the Windows client binaries.

**Why it matters** — the web console is deliberately simplified; for advanced configuration (cascades, access lists, detailed logging, certificate management, and so on) you administer from this GUI or from `vpncmd`.

**How to do it** — this is a straight compile on a Windows PC; the ComfyConnect branding is already baked into the source. Full prerequisites and steps are in **[WINDOWS_BUILD.md](WINDOWS_BUILD.md)**; in brief:

1. Install **Visual Studio 2019/2022** with the *Desktop development with C++* workload (plus *C++ Clang tools*), **Git for Windows**, and **vcpkg** (`bootstrap-vcpkg.bat` then `vcpkg integrate install`).
2. Clone the repo and its submodules:
   ```
   C:\> git clone https://github.com/Manan6506/ComfyConnect-redo
   C:\> cd ComfyConnect-redo
   C:\ComfyConnect-redo> git submodule update --init --recursive
   ```
3. Open the folder in Visual Studio, let it detect the CMake project, pick the **x64-native** configuration, and choose **Build → Build All**.
4. Binaries land in `build\`: `vpnserver.exe`, `vpnclient.exe`, `vpnbridge.exe`, `vpncmd.exe`, `vpnsmgr.exe` (Server Manager), `vpncmgr.exe` (Client Manager), plus `hamcore.se2`.

**Example — smoke test**

```
C:\ComfyConnect-redo\build> vpncmd.exe
ComfyConnect VPN Command Line Management Utility
...
Welcome to ComfyConnect VPN.
```

Then launch `vpnsmgr.exe`; the GUI opens branded as **ComfyConnect VPN Server Manager**. Point it at your deployed server's IP and management port to administer it. (When connecting to the Docker deploy, first open the SSH tunnel from 3.4 and connect the GUI to `localhost:5555`.)

**Tip** — you do not need to build on the same machine that runs the server. Build once on your admin PC and reuse `vpnsmgr.exe` to manage any ComfyConnect server.

### 3.4 First login to the web console

**What it is** — the browser-based Web Admin Console, the day-to-day panel for overview stats, employees, live sessions, and hubs.

**Why it matters** — it is the fastest way to confirm the deploy worked and to start adding employees, without any desktop software.

**How to do it** — because the management port is bound to localhost, first open an SSH tunnel from your workstation to the server, then browse to the tunneled port.

**Example**

```bash
# From your laptop — forward local :5555 to the server's localhost:5555
ssh -L 5555:127.0.0.1:5555 user@203.0.113.10
```

With the tunnel up, open **https://127.0.0.1:5555/admin/** in your browser. Your browser will warn about the certificate (see 3.6) — proceed for now. Sign in with the **server admin password** from the deploy output. You should land on the **Overview** page showing live stats and your hub. From here, go to **Employees → Add employee** to create your first VPN account.

**Gotcha** — the web console authenticates with the *server administrator* password, not a per-hub password. If sign-in fails, you are almost certainly using the wrong secret — re-check `comfyconnect-credentials.txt` (or your password manager).

### 3.5 Set or change the admin password

**What it is** — `ServerPasswordSet` sets the VPN Server administrator password — the credential that unlocks the web console, the Server Manager GUI, and `vpncmd`.

**Why it matters** — this single password guards every management action; rotate it whenever it may have been exposed (for example, if it was printed to a CI log during deploy).

**How to do it** — not in the web console yet — use `vpncmd`. In the Docker deploy, run it inside the container. Omit the new password on the command line so `vpncmd` prompts for it privately rather than leaving it in your shell history.

**Example**

```bash
# Inside the Docker deploy — you'll be prompted for the current admin password,
# then for the new password (typed twice, not echoed)
docker exec -it comfyconnect \
  vpncmd localhost /SERVER /CMD ServerPasswordSet
```

**Gotcha** — SoftEther's own guidance is explicit here: passing the password as a parameter briefly displays it on screen, which is a risk. Whenever possible let the command prompt you for it instead of writing `ServerPasswordSet 'newpass'` on the command line.

### 3.6 Get a real TLS certificate

**What it is** — by default the server presents a **self-signed** SSL certificate, which is why your browser and clients warn on first connect. `ServerCertSet` installs a real, CA-issued certificate and its private key.

**Why it matters** — a trusted certificate removes the browser warnings for the console and, more importantly, lets SSTP and SSL-VPN clients validate your server instead of being trained to click through warnings.

**How to do it** — obtain a certificate for your server's DNS name from a CA (for example Let's Encrypt), then install the X.509 certificate and its Base64-encoded private key with `ServerCertSet`. This is not in the web console — use `vpncmd` or the Server Manager GUI (*Encryption and Network* → *Server Certificate*).

**Example**

```bash
docker exec -it comfyconnect \
  vpncmd localhost /SERVER /PASSWORD: /CMD \
  ServerCertSet /LOADCERT:/certs/vpn.example.com.cer /LOADKEY:/certs/vpn.example.com.key
```

**Tip** — issue the certificate for the exact hostname employees connect to (e.g. `vpn.acme-corp.example`), and point that DNS name at your server's public IP. You can confirm what is currently installed with `ServerCertGet`. Until you install a real certificate, the localhost/SSH-tunnel warning in 3.4 is expected and safe to bypass — but do not ship a self-signed cert to production clients.

---

## 4. The Web Admin Console

**What it is** — The Web Admin Console is a simplified, browser-based control panel that the ComfyConnect vendor added on top of the SoftEther engine. It covers the handful of tasks a small IT team performs every day — checking status, managing employees, watching live sessions, and creating hubs — without installing anything. It is served at `https://SERVER:5555/admin/` (or `:443`).

**Why it matters** — Most day-to-day WFH-VPN administration (onboarding a new hire, resetting a password, kicking a stuck session) can be done from any laptop's browser, so you don't need the Windows Server Manager for routine work.

**Important — this console is deliberately small.** It does **not** replace the full toolset. Anything beyond the five screens below is *not in the web console yet* — use the **ComfyConnect VPN Server Manager (GUI)** or **vpncmd**. See the end of this section for the exact "not here — go there" list.

> **Access note (Docker deploy):** In the standard `deploy/setup.sh` deployment the management port `5555` is bound to `localhost`, so the console isn't reachable directly over the network. Open an SSH tunnel to the server first, then browse to the console through the tunnel:
> ```bash
> ssh -L 5555:localhost:5555 admin@vpn.acme-corp.example
> # then open https://localhost:5555/admin/ in your browser
> ```
> The server uses a self-signed TLS certificate by default, so your browser will warn on first visit; accept it (or install your own certificate via the Server Manager) to proceed.

### 4.1 Signing in

The console authenticates with the **VPN Server administrator password** — the same password set by `deploy/setup.sh` (and changeable any time with the `ServerPasswordSet` command). There are no per-admin accounts in the web console; anyone with the server-admin password gets full console access.

There are two ways you'll reach the sign-in:

- **Served by the server (browser session).** You navigate directly to `https://SERVER:5555/admin/`, the server hands you the console, and you enter the server-admin password to start a session. This is the normal path.
- **Standalone.** If you're running the console page separately from the server it manages, you supply the **server URL (host and management port)** *and* the **admin password** on the sign-in screen, and the console connects out to that server. Useful when one console page administers a server reached over a tunnel.

Either way you are signing in as the **server administrator** — the console does not offer Virtual-Hub-admin-only login. Sessions are password-only; there is no SSO, no MFA, and no user roles in the console.

**Gotcha:** A wrong-password attempt just fails the sign-in — there's no account lockout in the console itself. Protect the console by keeping the management port on localhost/behind the SSH tunnel as shipped.

### 4.2 Overview (KPIs + hubs)

**What it is** — The landing screen after sign-in. It shows live server KPIs (such as running status, uptime, and current totals) and a list of every Virtual Hub on the server with its at-a-glance counts (users, sessions, etc.).

**Why it matters** — One glance tells you the server is up and how many employees are connected right now — the daily "is everything healthy?" check.

**How to do it** — Web console: sign in; the Overview loads automatically. The hub list here is the same data the CLI returns from `HubList` (*Get List of Virtual Hubs* — Virtual Hub Name, Status, Type, number of Users/Groups/Sessions, last login and last communication).

**Equivalent in CLI** (for scripting or when the console isn't reachable):
```bash
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /CMD HubList
```

**Tip:** The Overview is read-only — it's a dashboard. You act on things from the Employees, Live Sessions, and Virtual Hubs screens.

### 4.3 Employees

**What it is** — Per-hub user management. Pick a hub, and you can list its employees with online status, add a new employee (with **password authentication only**), reset an employee's password, and remove an employee.

**Why it matters** — This is the onboarding/offboarding screen: create a login for a new hire, rotate a forgotten password, or cut off access when someone leaves.

**How to do it — Web console:**
- **Add employee.** Choose the hub, click Add, enter a username and an initial password. The console creates the user with **Password Authentication** — equivalent to `UserCreate` followed immediately by `UserPasswordSet`. (This matters because `UserCreate` on its own assigns a *random* password the user can't know; the console always sets a real password so the account is usable right away.)
- **Reset password.** Select the employee and set a new password — this is `UserPasswordSet` (*Set Password Authentication for User Auth Type and Set Password*). Note that passwords are stored only as a hash, so a reset replaces the password; the old one can't be read back.
- **Remove employee.** Deletes the user from the hub's security account database (`UserDelete`), after which they can no longer connect.
- **Online status.** Each employee row shows whether they currently have a session on the hub.

**Example — the same three operations at the CLI** (note the hub is targeted with `/ADMINHUB:`):
```bash
# Add a password-auth employee to the Acme-Corp hub
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp \
  /CMD UserCreate jane.doe /GROUP:none /REALNAME:"Jane Doe" /NOTE:"Sales"
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp \
  /CMD UserPasswordSet jane.doe /PASSWORD:'Initial-Pass-123'

# Reset her password later
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp \
  /CMD UserPasswordSet jane.doe /PASSWORD:'New-Pass-456'

# Remove her when she leaves
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp \
  /CMD UserDelete jane.doe
```

**Gotcha — password auth only.** The web console only creates and manages **password** users. Certificate, RADIUS/NT-domain, anonymous, and NTLM authentication are *not in the web console* — set those up with the Server Manager or with `UserCertSet` / `UserRadiusSet` / `UserNTLMSet` / `UserAnonymousSet` in vpncmd. Likewise, groups, per-user security policies, and multi-factor settings aren't on this screen.

**Gotcha — removing vs. suspending.** "Remove" permanently deletes the user object. If you only want to *temporarily* block someone (e.g., a leave of absence) without losing their settings, that's a policy change (`UserPolicySet`) done in the Server Manager or vpncmd, not the console.

### 4.4 Live Sessions

**What it is** — A live list of the VPN sessions connected to a hub, with the ability to forcibly disconnect any one of them.

**Why it matters** — When an employee's connection is stuck, a device won't reconnect cleanly, or you need to immediately cut off access, you can see and kill the session in seconds.

**How to do it — Web console:** Open Live Sessions for the hub to see connected sessions (session name, the user, source host, and transfer counters — the data behind `SessionList`, *Get List of Connected Sessions*). Click a session and choose Disconnect to force it off (`SessionDisconnect`).

**Example — CLI equivalent:**
```bash
# List live sessions on the hub
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp \
  /CMD SessionList

# Forcibly disconnect one by its session name
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp \
  /CMD SessionDisconnect SID-JANE.DOE-3
```

**Gotcha:** Disconnecting doesn't ban the user. If that client has auto-reconnect enabled, it may simply dial back in. To stop them from returning, reset their password or remove/suspend the user (Employees screen), or apply an access-deny policy in the Server Manager.

### 4.5 Virtual Hubs

**What it is** — Create a new Virtual Hub or delete an existing one.

**Why it matters** — A hub is the isolated virtual network your employees connect into; you might run one per client, per department, or per site, and this screen lets you spin one up or tear one down.

**How to do it — Web console:** Use Create to add a hub (`HubCreate` — it begins operating immediately), or Delete to remove one (`HubDelete`).

**Example — CLI equivalent:**
```bash
# Create a new hub
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /CMD HubCreate Acme-Corp

# Delete a hub
vpncmd vpn.acme-corp.example /SERVER /PASSWORD:'AdminPass!' /CMD HubDelete Acme-Corp
```

**Gotcha — deletion is destructive and permanent.** Deleting a hub instantly disconnects every session on it and erases *all* of that hub's settings — its users, groups, certificates, and cascade connections — and it cannot be recovered. Double-check the hub name before confirming.

**Gotcha — a new hub isn't reachable yet.** The console creates the hub, but it doesn't configure connectivity. To actually route employee traffic you still need to enable **SecureNAT** (`SecureNatEnable`) or a local bridge, and enable the client protocols (OpenVPN/SSTP/L2TP-IPsec) — the `deploy/setup.sh` script does this for the initial hub, but for hubs you create later you'll set it up with the Server Manager or vpncmd. It's *not in the web console yet.*

### 4.6 What the console does NOT do — and where to go instead

Be honest with your expectations: the five screens above are the whole console. For everything else, use the **ComfyConnect VPN Server Manager (GUI)** or **vpncmd** (and, for automation, the JSON-RPC API):

| You want to… | Not in the web console — use instead |
|---|---|
| Certificate, RADIUS/NT-domain, NTLM, or anonymous user auth | Server Manager / `UserCertSet`, `UserRadiusSet`, `UserNTLMSet`, `UserAnonymousSet` |
| Groups, per-user security policies, access lists | Server Manager / `GroupCreate`, `UserPolicySet`, `AccessAdd` |
| Enable SecureNAT / DHCP, local bridge, cascade connections | Server Manager / `SecureNatEnable`, `BridgeCreate`, `CascadeCreate` |
| Configure OpenVPN / SSTP / L2TP-IPsec listeners | Server Manager / `OpenVpnEnable`, `SstpEnable`, `IPsecEnable` |
| Change the server-admin password | `ServerPasswordSet` (or Server Manager) |
| Logging, hub/server logs, config backup | Server Manager / `LogGet`, `ConfigGet` |
| DDNS, VPN Azure, NAT-traversal, clustering, listeners/ports | Server Manager / vpncmd (these are also disabled by default in this deploy) |
| Suspend a user without deleting them | `UserPolicySet` (Server Manager / vpncmd) |

**Rule of thumb:** if a task involves auth types other than password, network plumbing, policies, protocols, or server-level settings, it lives in the Server Manager or vpncmd — the web console intentionally keeps to the daily essentials.

---

## 5. Virtual Hubs

A Virtual Hub is the isolation boundary in ComfyConnect. Each hub is a self-contained Layer-2 switch with its own users, groups, sessions, security policies, and SecureNAT. Traffic never crosses between hubs. For a WFH-VPN business this is the core multi-tenancy primitive: **one hub per client company** means Acme's employees can never see Globex's network, and you can hand each client their own hub admin without exposing anyone else.

The web console covers the three everyday operations — create, delete, and list hubs. Everything else in this section (online/offline, session caps, options, connect messages, cluster hub types) is **not in the web console yet — use the Server Manager or vpncmd**.

> All `vpncmd` examples below assume the server-admin connection pattern:
> `vpncmd <host> /SERVER /PASSWORD:<adminpw> /CMD <Command> <args>`
> Hub-scoped commands (Online, Offline, SetMaxSession, OptionsGet) also need `/ADMINHUB:<HubName>` so vpncmd knows which hub you mean.

### 5.1 Listing hubs

**What it is** — An inventory of every Virtual Hub on the server, with each hub's status, type, and counts of users, groups, sessions, MAC/IP table entries, and logins.

**Why it matters** — It's your at-a-glance tenant roster: which client hubs exist, which are online, and how many people are connected right now.

**How to do it**
- **Web console:** open **Overview** — the hub list is shown there alongside live stats.
- **CLI:** `HubList` (server-admin mode shows all hubs).

**Example**
```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD HubList
```

**Gotcha** — In Virtual Hub Admin Mode you only see hubs you administer, and a hub with "Don't Enumerate for Anonymous Users" set won't appear. In Server Admin Mode you see everything.

### 5.2 Creating a hub (new tenant)

**What it is** — `HubCreate` makes a new Virtual Hub that begins operating immediately. The hub name is its identity; you also set a **hub administrator password** at creation (used for Virtual Hub Admin Mode).

**Why it matters** — Spinning up a new client is one command: a fresh, fully isolated network for their workforce.

**How to do it**
- **Web console:** **Virtual Hubs → create**, give it a name.
- **CLI:** `HubCreate [name] /PASSWORD:<hubadminpw>`

**Example** — onboard Acme:
```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD HubCreate Acme-Corp /PASSWORD:AcmeHubPw!
```

**Tip** — Pick a stable, human-readable name per client (e.g. `Acme-Corp`, `Globex`). The name is what you pass to every hub-scoped command afterward, and it shows up in connection profiles — renaming later is disruptive. After creating a hub, enable SecureNAT / the protocols you need on it (covered in the networking sections); a bare new hub has no NAT or DHCP until you turn it on.

### 5.3 Deleting a hub

**What it is** — `HubDelete` permanently removes a Virtual Hub. All connected sessions are dropped, and every setting, user, group, certificate, and cascade connection inside the hub is destroyed.

**Why it matters** — Off-boarding a departed client. It's clean and total — but irreversible.

**How to do it**
- **Web console:** **Virtual Hubs → delete**.
- **CLI:** `HubDelete [name]`

**Example**
```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD HubDelete Globex
```

**Gotcha** — Once deleted, a hub **cannot be recovered**. There is no trash or undo. Export the hub's config first if you might need it (see the backup/config section), and confirm you typed the right tenant name before you run it.

### 5.4 Selecting a hub in an interactive session

**What it is** — Inside an interactive `vpncmd` session, `Hub` chooses which Virtual Hub subsequent management commands act on.

**Why it matters** — When you're doing several operations on one client, select once instead of repeating `/ADMINHUB:` on every command.

**How to do it**
- **CLI (interactive):**
```
VPN Server> Hub Acme-Corp
VPN Server/Acme-Corp> Online
VPN Server/Acme-Corp> SetMaxSession 50
```

**Tip** — For scripted one-liners you don't need `Hub`; just pass `/ADMINHUB:Acme-Corp` on the single command. `Hub` is for the interactive prompt.

### 5.5 Taking a hub online / offline

**What it is** — `Online` and `Offline` toggle whether a hub accepts VPN connections. An offline hub refuses all client connections; switching it offline immediately disconnects any current sessions.

**Why it matters** — A maintenance switch per tenant: take one client's hub down for changes without touching anyone else, or park a hub you've provisioned but not yet activated.

**How to do it**
- **Server Manager (GUI):** select the hub → **Online / Offline** button.
- **CLI:** `Online` or `Offline` (hub-scoped).

**Example** — take Acme offline for a maintenance window, then bring it back:
```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD Offline
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD Online
```

**Gotcha** — `Offline` is not graceful: every session on the hub is dropped at once. Warn the client's users first.

### 5.6 Capping concurrent sessions

**What it is** — `SetMaxSession` limits how many sessions can be connected to a hub at the same time. Once the cap is reached, further clients are refused. Sessions created internally by Local Bridges, Virtual NAT (SecureNAT), and Cascade Connections **do not count** toward the limit.

**Why it matters** — Enforce per-tenant seat limits that match what the client is paying for, and protect one hub from starving the others.

**How to do it**
- **Server Manager (GUI):** hub **Properties → Max concurrent sessions**.
- **CLI:** `SetMaxSession [max_session]` (hub-scoped). Read the current value with `OptionsGet`.

**Example** — cap Acme at 50 seats, then verify:
```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD SetMaxSession 50
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD OptionsGet
```

**Tip** — `OptionsGet` returns the hub's key options in one shot: enumeration allow/deny, max concurrent connections, online/offline status, and (in a cluster) the hub type. It's the quickest way to confirm a hub's current state.

### 5.7 Connect message (hub MOTD)

**What it is** — An optional message shown to clients when they connect to the hub — useful for an acceptable-use notice or a "you are connecting to Acme-Corp VPN" banner.

**Why it matters** — A per-tenant way to surface policy or branding at connect time.

**How to do it** — **Not in the web console, and there is no dedicated `vpncmd` command for it.** Set it in the **Server Manager (GUI)** hub properties, or via the **JSON-RPC API** methods `SetHubMsg` / `GetHubMsg` for automation.

**Gotcha** — Whether the message is displayed depends on the connecting client; the built-in ComfyConnect client honors it, but L2TP/IPsec, SSTP, and OpenVPN clients generally won't show it.

### 5.8 Static vs. dynamic hub type (clustering only)

**What it is** — `HubSetStatic` and `HubSetDynamic` change a hub's type in a **clustered** deployment. A static hub exists on all cluster members at once (good for large remote-access pools); a dynamic hub is hosted on whichever member has the lowest load and only exists while someone is connected.

**Why it matters** — These are cluster load-distribution controls — relevant only if you scale ComfyConnect across multiple clustered servers.

**How to do it** — `HubSetStatic` / `HubSetDynamic` (server-admin).

**Gotcha** — These do **not** apply to the standard single-server ComfyConnect deploy: they only run on a cluster controller, not on a standalone server, VPN Bridge, or cluster member, and they are unavailable on builds newer than 5190. On a normal deployment you can ignore hub type entirely — every hub is just a hub. Changing the type also disconnects all current sessions on that hub.

### 5.9 Multi-tenant setup example

Provision two isolated client tenants — Acme-Corp and Globex — from scratch, each with its own hub password and a 50-seat cap:

```bash
HOST=127.0.0.1
ADMIN=AdminPass

# Create the two tenant hubs
vpncmd $HOST /SERVER /PASSWORD:$ADMIN /CMD HubCreate Acme-Corp /PASSWORD:AcmeHubPw!
vpncmd $HOST /SERVER /PASSWORD:$ADMIN /CMD HubCreate Globex    /PASSWORD:GlobexHubPw!

# Cap each tenant at 50 concurrent sessions
vpncmd $HOST /SERVER /PASSWORD:$ADMIN /ADMINHUB:Acme-Corp /CMD SetMaxSession 50
vpncmd $HOST /SERVER /PASSWORD:$ADMIN /ADMINHUB:Globex    /CMD SetMaxSession 50

# Make sure both are online, then confirm the roster
vpncmd $HOST /SERVER /PASSWORD:$ADMIN /ADMINHUB:Acme-Corp /CMD Online
vpncmd $HOST /SERVER /PASSWORD:$ADMIN /ADMINHUB:Globex    /CMD Online
vpncmd $HOST /SERVER /PASSWORD:$ADMIN /CMD HubList
```

At this point you have two fully isolated networks. Next, enable SecureNAT and your connection protocols (OpenVPN / SSTP / L2TP-IPsec) on each hub, then add employees — see the Employees / Users and Networking sections. Acme's users and Globex's users share the same physical server but can never route to, discover, or authenticate against each other's hub.

**Tip** — Standardize your per-tenant steps (create → SetMaxSession → enable SecureNAT/protocols → add users) into a script so every new client hub is provisioned identically. The `onboarding/add-employee.sh` helper handles the user side once the hub exists.

---

## 6. Users, Groups & Authentication

Every employee who connects to ComfyConnect is a **user** in a specific Virtual Hub's security account database. This section covers the full user lifecycle, how to organize users into **groups**, and — most importantly — the five **authentication types** the engine supports, so you can match each customer to the right one (a small business on simple passwords vs. an enterprise that wants everyone to log in against their existing corporate directory).

All commands below are hub-scoped: they act on the Virtual Hub you point them at, so every example includes `/ADMINHUB:<HubName>`. The web console covers only the common case — **password users in one hub** — so anything involving certificates, RADIUS, NT-domain, groups, or expiration dates means the Server Manager GUI or `vpncmd`.

> Every user/group command in this section cannot be run on a VPN Bridge, nor on a Virtual Hub of a server acting as a cluster member server.

### 6.1 The user lifecycle

**What it is** — Creating, listing, inspecting, editing, and deleting the user accounts in a hub.

**Why it matters** — This is employee onboarding and offboarding: the day-one grant and the day-you-leave revoke that keep a WFH VPN's access list honest.

#### Create a user

**What it is** — `UserCreate` registers a new user object in the hub's account database.

**Gotcha you must know** — When you create a user, it starts as a Password Authentication user **with a random, unknown password** — the account exists but nobody can connect with it yet. You must immediately follow up with `UserPasswordSet` (or switch the auth type with one of the `User*Set` commands in 6.3). Onboarding is therefore always at least two commands: create, then set auth.

**How to do it** —
- **Web console:** Employees tab → *Add user* (password auth only; it creates the account and sets the password in one step).
- **CLI:** `UserCreate <name> /GROUP:<group|none> /REALNAME:<fullname|none> /NOTE:<note|none>`

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserCreate jane.doe /GROUP:Engineering /REALNAME:"Jane Doe" /NOTE:"Backend team"

vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserPasswordSet jane.doe /PASSWORD:Str0ng-Temp-Pass
```

**Tip** — If a user with the name `*` (a single asterisk) exists, it is automatically a RADIUS user and acts as a **catch-all**: any user name that isn't found locally but authenticates against your RADIUS server or NT domain controller is admitted using the `*` user's auth and security-policy settings. This is the trick that makes directory-based login (6.3) work without pre-creating every employee.

#### List and inspect users

**What they are** — `UserList` returns every user in the hub; `UserGet` returns one user's full record: user name, full name, group, expiration date, security policy, auth type (plus that auth type's attributes) and traffic statistics.

**How to do it** —
- **Web console:** Employees tab shows the per-hub list.
- **CLI:** `UserList` / `UserGet <name>`

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD UserList
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD UserGet jane.doe
```

#### Edit a user

**What it is** — `UserSet` changes exactly three fields: **group**, **full name**, and **description/note**. It does **not** change the auth type or password — those have their own commands (6.3).

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserSet jane.doe /GROUP:Platform /REALNAME:"Jane Doe" /NOTE:"Moved to Platform"
```

#### Delete a user

**What it is** — `UserDelete` removes the account so that user can no longer connect.

**Gotcha** — Deletion is permanent and drops the account's settings. If you only need to **temporarily** block someone (suspension, investigation, unpaid invoice), don't delete — either set a security policy that denies access (`UserPolicySet`, covered in the security-policy section) or set an expiration date in the past (6.4). Reserve `UserDelete` for genuine offboarding.

**How to do it** —
- **Web console:** Employees tab → *Remove*.
- **CLI:** `UserDelete <name>`

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserDelete former.employee
```

### 6.2 Groups

**What it is** — A group is a named container of users in the hub's account database. A user belongs to at most one group. Groups exist so you can apply one **security policy** to many users at once and to map VPN accounts onto real departments.

**Why it matters** — For a WFH-VPN business, groups let you say "everyone in *Contractors* gets a stricter policy" or "the *Finance* group can reach the accounting subnet" without editing users one by one.

**How to do it (not in the web console — use Server Manager or vpncmd):**

| Command | Purpose |
|---|---|
| `GroupCreate <name> /REALNAME:<full> /NOTE:<note>` | Create a group |
| `GroupList` | List groups |
| `GroupGet <name>` | Show a group's info **and its member users** |
| `GroupSet <name> /REALNAME:<full> /NOTE:<note>` | Edit a group's full name/note |
| `GroupJoin <groupname> /USERNAME:<user>` | Add a user to a group |
| `GroupUnjoin <username>` | Remove that user from whatever group it's in |
| `GroupDelete <name>` | Delete the group (its members become ungrouped) |

Note the argument shapes: `GroupJoin` takes the **group** name plus `/USERNAME:`, whereas `GroupUnjoin` takes the **user** name directly (a user is only ever in one group, so no group name is needed to remove them). Deleting a group does not delete its users — they simply become unassigned.

**Example — create a department group and move a user into it**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD GroupCreate Finance /REALNAME:"Finance Dept" /NOTE:"Accounting subnet access"

vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD GroupJoin Finance /USERNAME:jane.doe

vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD GroupGet Finance
```

**Tip** — Assigning a user to a group at creation time is often cleaner: `UserCreate jane.doe /GROUP:Finance ...`. Use `GroupJoin`/`GroupUnjoin` for later moves.

### 6.3 Authentication types — which to use and when

Each user has exactly one **auth type**. Setting an auth type is a single command that both selects the method and configures its attributes; running a different `User*Set` command switches the user to that method. Here are all five, with the business case for each.

#### Password authentication — the default for small teams

**What it is** — `UserPasswordSet` stores a password (as a salted hash — the plaintext is never recoverable from the server's config file) and prompts the connecting user for it.

**Why/when** — The simplest option and the only one the web console offers. Ideal for small businesses that don't run a central directory. You own the password lifecycle (resets, rotation).

**How to do it** —
- **Web console:** *Add user* / *Reset password* on the Employees tab.
- **CLI:** `UserPasswordSet <name> /PASSWORD:<password>` (omit `/PASSWORD:` to be prompted instead of putting it on the command line).

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserPasswordSet jane.doe /PASSWORD:Corr3ct-Horse-Battery
```

#### RADIUS authentication — corporate directory login (recommended for enterprises)

**What it is** — `UserRadiusSet` marks the user so that, at connect time, the entered user name and password are forwarded to an external RADIUS server, which decides yes/no. The VPN Server stores no password for these users.

**Why/when** — This is the go-to for a business that already has a **central identity system** (Active Directory via NPS, Okta, FreeRADIUS, etc.) — employees log in with the same credentials they use everywhere else, and disabling them in the directory instantly cuts VPN access. Combine with the `*` catch-all user (6.1) so you don't pre-create every employee.

**Prerequisite** — You must first register the RADIUS server on the hub with `RadiusServerSet` (covered in the authentication-server configuration material). Without it, RADIUS users can't be verified.

**How to do it (not in the web console — use vpncmd/Server Manager):**
`UserRadiusSet <name> /ALIAS:<alias_name>` — the optional alias is the user name actually sent to the RADIUS server, when it differs from the VPN user name.

**Example — a catch-all RADIUS user for the whole company**

```bash
# Point the hub at your RADIUS/NPS server first (see the auth-server section):
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD RadiusServerSet radius.acme.internal /PORT:1812 /SECRET:sharedsecret /RETRY_INTERVAL:5

# Create the catch-all and set it to RADIUS:
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD UserCreate *
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD UserRadiusSet *
```

#### NT Domain authentication — Windows-hosted, domain-joined servers only

**What it is** — `UserNTLMSet` sends the user name and password to a Windows Domain Controller / Active Directory for verification.

**Why/when** — Same corporate-directory goal as RADIUS, but it talks to the domain **directly** instead of via a RADIUS server. Use it when the customer runs ComfyConnect on Windows.

**Hard requirement (be honest with the customer)** — NT Domain authentication only works when the **VPN Server itself runs on a domain-joined Windows machine**. The ComfyConnect Docker deploy is Linux-based, so on that deploy NT Domain auth is unavailable — steer those customers to **RADIUS** (via NPS) to reach the same Active Directory. NT Domain is for on-prem Windows installs of the Server Manager build.

**How to do it (Server Manager on Windows, or vpncmd):**
`UserNTLMSet <name>`

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserNTLMSet jane.doe
```

#### Individual certificate authentication — one pinned certificate per user

**What it is** — `UserCertSet` pins one specific X.509 certificate to the user. At connect time, RSA verification confirms the client presents that exact certificate **and** holds its matching private key. `UserCertGet` exports the pinned certificate back out to a file.

**Why/when** — Strong, passwordless, device-bound access for a specific high-value account or a service/machine account. You issue and distribute the cert; losing the device means revoking one cert.

**How to do it (not in the web console — use vpncmd/Server Manager):**
- `UserCertSet <name> /LOADCERT:<cert.cer>` — pin the certificate from an X.509 file.
- `UserCertGet <name> /SAVECERT:<out.cer>` — export the pinned cert (errors if the user isn't an individual-certificate user).

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserCertSet jane.doe /LOADCERT:/certs/jane.doe.cer

vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserCertGet jane.doe /SAVECERT:/tmp/jane.doe-exported.cer
```

#### Signed certificate authentication — scale certificates with your own CA

**What it is** — `UserSignedSet` accepts **any** certificate signed by a CA in the hub's list of trusted CA certificates (rather than one pinned cert). Optionally, you can require the certificate's **Common Name (CN)** and/or **serial number** to match expected values for that specific user.

**Why/when** — The scalable version of certificate auth: stand up your own CA, issue a client cert per employee, and the hub trusts them all without you pinning each one. Adding the CN check ties a given user name to a given issued certificate, so Jane can't log in as Bob with Bob's cert.

**How to do it (not in the web console — use vpncmd/Server Manager):**
`UserSignedSet <name> /CN:<cn|none> /SERIAL:<serial|none>` — use `none` to skip a check; the trusted CA list is managed with the hub's CA commands (see the certificate/CA section).

**Example — trust the corporate CA, and require the CN to equal the user name**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserSignedSet jane.doe /CN:jane.doe /SERIAL:none
```

#### Anonymous authentication — public hubs only (avoid for WFH)

**What it is** — `UserAnonymousSet` lets anyone connecting with that user name in with **no authentication at all**.

**Why/when** — Meant for deliberately public VPN servers. For a work-from-home business this is almost always the wrong choice — documented here so you recognize and avoid it. Don't leave anonymous users on a corporate hub.

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Guest-Hub \
  /CMD UserAnonymousSet guest
```

#### Quick chooser

| Situation | Use |
|---|---|
| Small business, no central directory | **Password** (web console) |
| Enterprise with Active Directory / IdP, any OS | **RADIUS** (+ `*` catch-all user) |
| Enterprise AD, server runs on domain-joined Windows | **NT Domain** |
| A few high-value or machine accounts, device-bound | **Individual certificate** |
| Company-wide certs issued by your own CA | **Signed certificate** |
| Public/open hub (rare) | **Anonymous** |

### 6.4 Account expiration

**What it is** — `UserExpiresSet` sets a date/time after which the user can no longer connect, regardless of auth type.

**Why it matters** — Perfect for contractors, interns, and temporary access: set the end date up front and the account self-disables, so nobody has to remember to revoke it. Also handy as a "soft delete" — set an expiry in the past to instantly block a user without deleting their account.

**How to do it (not in the web console — use vpncmd/Server Manager):**
`UserExpiresSet <name> /EXPIRES:"YYYY/MM/DD HH:MM:SS"` — the value is **local time** to the machine running vpncmd, in the exact format `2026/12/31 23:59:59` (four-digit year, slashes, a space, then colons; quote the whole value because of the space). Use `/EXPIRES:none` to remove the limit and make the account permanent.

**Example — a contractor account that expires at year end**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserExpiresSet contractor.sam /EXPIRES:"2026/12/31 23:59:59"

# Later, make it permanent:
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD UserExpiresSet contractor.sam /EXPIRES:none
```

**Tip** — Expiration is independent of authentication: an expired RADIUS or certificate user is refused locally before the credential is ever checked. Combine expiration with a group and a security policy to hand contractors a fully time-boxed, least-privilege account in a few commands.

---

## 7. Security Policies & Access Control

Once employees can sign in, the next job is deciding *what each one is allowed to do once connected* and *what traffic is allowed to cross the hub*. ComfyConnect gives you two independent, complementary tools for this:

- **Security policies** — per-user and per-group rules that shape the *VPN session itself* (bandwidth caps, concurrent-login limits, and switches that block bridging, routing, DHCP servers, and other lateral-movement tricks).
- **Access lists** — an ordered packet-filter that decides which *packets* may flow through a Virtual Hub, letting you fence an employee into just the subnets they need.

A third, connection-level control — the **Source IP Address Limit List** — decides which *client IP addresses* are even allowed to attempt a VPN connection to a hub.

> **None of this is in the web console yet.** The web console covers sign-in, Overview, Employees, Live Sessions, and Virtual Hubs only. For everything in this section, use the **Server Manager (GUI)** — right-click a hub → **Manage Virtual Hub** → **Security Settings** (Access List) or the **Users/Groups** dialogs (Security Policy) — or the **vpncmd** CLI shown throughout. All CLI examples assume you have already entered admin mode for a hub, e.g. `vpncmd localhost /SERVER /PASSWORD:<adminpw> /ADMINHUB:Acme-Corp /CMD <command> ...`. All of these commands run per-Virtual-Hub and cannot be run on a VPN Bridge or on a cluster member server.

### 7.1 Security policies: what they are

**What it is** — A security policy is a bundle of ~30 settings attached to a *user* or a *group* in a hub's account database. Some are on/off switches (yes/no), others take a number (a bandwidth in bits/sec, a login count, a timeout). When a user connects, their session inherits the user's policy; if the user has none, they inherit their group's policy; if neither exists, the built-in defaults apply (**Allow Access: Enabled, Maximum Number of TCP Connections: 32, Time-out Period: 20 seconds**).

**Why it matters** — This is where a WFH-VPN business enforces fair-use bandwidth, stops one shared login from becoming ten, and prevents a remote laptop from quietly bridging your corporate network to a home LAN.

**How to see every available policy — CLI:** run `PolicyList` with no arguments to list every policy name and description; add a name to see its type and allowed range.

```bash
# List all policy items
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD PolicyList

# Inspect one policy's type and range
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD PolicyList MaxUpload
```

The policy names you will use most often:

| Policy name | Type | What it does |
|---|---|---|
| `Access` | yes/no | Master switch — allow this user to make a VPN connection at all. |
| `MaxUpload` / `MaxDownload` | bits/sec | Cap traffic into / out of the hub for the session (bandwidth limit). |
| `MultiLogins` | number | Maximum concurrent logins for the same user. |
| `MaxConnection` | number | Max physical TCP connections bundled into one VPN session. |
| `TimeOut` | seconds | How long to wait before dropping a session after a comms fault. |
| `NoBridge` | yes/no | Deny bridge-mode operation from the client. |
| `NoRouting` | yes/no | Deny IPv4 routing from the client. |
| `DHCPFilter` | yes/no | Filter all IPv4 DHCP packets in the session. |
| `DHCPNoServer` | yes/no | Forbid the client from acting as a DHCP server. |
| `DHCPForce` | yes/no | Force the client to use only DHCP-allocated addresses. |
| `NoServer` | yes/no | Deny operating as a TCP/IP server (client can't accept inbound TCP). |
| `FixPassword` | yes/no | Deny the user changing their own password. |
| `MultiLogins`, `NoBroadcastLimiter`, `NoQoS`, `AutoDisconnect` | various | Broadcast limiting, VoIP/QoS, and idle auto-disconnect controls. |

> **Gotcha — bandwidth is in bits per second, not bytes.** `MaxUpload` and `MaxDownload` are `POL_INT_BPS` values. For a 10 Mbps cap, set `10000000`, not `10`. Divide the marketing "megabits" figure accordingly: 5 Mbps = `5000000`.

### 7.2 Setting a per-user policy

**What it is** — `UserPolicySet` changes one policy value on one user. If the user had no policy yet, a default policy is created first and then your value is applied.

**Why it matters** — Per-user policies handle exceptions: the one contractor who should never touch internal routing, or the power user who needs a higher login count.

**How to do it — CLI:** `UserPolicySet [username] /NAME:policy_name /VALUE:num|yes|no`

**Example** — Give `jane.doe` a 10 Mbps download / 3 Mbps upload cap and forbid bridging:

```bash
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp \
  /CMD UserPolicySet jane.doe /NAME:MaxDownload /VALUE:10000000
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp \
  /CMD UserPolicySet jane.doe /NAME:MaxUpload /VALUE:3000000
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp \
  /CMD UserPolicySet jane.doe /NAME:NoBridge /VALUE:yes
```

**Remove a user policy — CLI:** `UserPolicyRemove jane.doe` deletes the user's own policy. The user then falls back to their group's policy, or to the built-in defaults if the group has none.

> **Tip** — Each `UserPolicySet` sets exactly one item. Script the values you want as a small batch (as above) rather than expecting a single command to take many flags.

### 7.3 Setting a per-group policy (the scalable way)

**What it is** — `GroupPolicySet` applies a policy to a *group*, so every user assigned to that group inherits it. Same syntax and same policy names as the user version.

**Why it matters** — You do not want to hand-edit 200 users. Define policy once per role — `Employees`, `Contractors`, `Admins` — assign users to groups (see the Users & Authentication section), and manage security by role.

**How to do it — CLI:** `GroupPolicySet [groupname] /NAME:policy_name /VALUE:num|yes|no`

**Example** — Lock the `Contractors` group down hard: 5 Mbps each way, one concurrent login, no bridging, no routing, no acting as a server:

```bash
HUB="/ADMINHUB:Acme-Corp"
CRED="localhost /SERVER /PASSWORD:pass"
vpncmd $CRED $HUB /CMD GroupPolicySet Contractors /NAME:MaxDownload  /VALUE:5000000
vpncmd $CRED $HUB /CMD GroupPolicySet Contractors /NAME:MaxUpload    /VALUE:5000000
vpncmd $CRED $HUB /CMD GroupPolicySet Contractors /NAME:MultiLogins  /VALUE:1
vpncmd $CRED $HUB /CMD GroupPolicySet Contractors /NAME:NoBridge     /VALUE:yes
vpncmd $CRED $HUB /CMD GroupPolicySet Contractors /NAME:NoRouting    /VALUE:yes
vpncmd $CRED $HUB /CMD GroupPolicySet Contractors /NAME:NoServer     /VALUE:yes
```

**Remove a group policy — CLI:** `GroupPolicyRemove Contractors`. Users in that group who have no policy of their own then drop to the built-in defaults.

> **Gotcha — precedence.** A value set directly on a user *overrides* the group. If a user seems to ignore a group cap, check for a leftover `UserPolicySet` on that account and clear it with `UserPolicyRemove`.

### 7.4 Blocking lateral movement

The single biggest risk in a WFH VPN is a compromised home machine using the tunnel to reach places it shouldn't. Three policies neutralize the common tricks, and they cost nothing to leave on for standard employees:

- **`NoBridge: yes`** — even if the client has an Ethernet bridge configured, it cannot bridge the home LAN into your hub.
- **`NoRouting: yes`** — even if the client is running as an IP router, it cannot route third-party traffic through the session.
- **`NoServer: yes`** — the client cannot listen for and accept inbound TCP connections over the VPN, so it can't quietly host services on your internal network.

Add **`DHCPNoServer: yes`** (client can't hand out addresses) and **`DHCPFilter: yes`** where clients have no business speaking DHCP at all. Apply these to your baseline `Employees` group and grant exceptions only where a real business case exists.

### 7.5 Access lists: restricting which subnets an employee can reach

**What it is** — The access list is an ordered set of packet-filter rules on a Virtual Hub. Every packet crossing the hub is tested against the rules in priority order (lower number = higher priority); the **first matching rule** decides `pass` or `discard`. **Packets that match no rule are implicitly passed.** Rules can match on source/destination IP+mask, protocol, ports, MAC, and even source/destination *username* — so you can write per-employee filters.

**Why it matters** — This is how you say "Contractors may reach the app servers on `10.1.20.0/24` but nothing else on the corporate network" — micro-segmentation enforced at the hub, independent of the client OS.

**How to do it — CLI:** `AccessAdd pass|discard [/MEMO:] [/PRIORITY:] [/SRCUSERNAME:] [/DESTUSERNAME:] [/SRCIP:ip/mask] [/DESTIP:ip/mask] [/PROTOCOL:tcp|udp|icmpv4|icmpv6|ip|num] [/SRCPORT:start-end] [/DESTPORT:start-end] [/TCPSTATE:established|unestablished]`. Use `AccessAdd6` for IPv6 rules and `AccessAddEx` if you deliberately want to inject delay/jitter/loss (network-emulation testing — rarely used in production).

**Because unmatched packets pass by default, a lock-down pattern is: allow what you need at high priority, then a catch-all `discard` at the lowest priority.**

**Example** — Confine users in the `Contractors` group to the app subnet `10.1.20.0/24` and drop everything else they send:

```bash
HUB="/ADMINHUB:Acme-Corp"
CRED="localhost /SERVER /PASSWORD:pass"

# 1) Allow contractors -> app servers (high priority = evaluated first)
vpncmd $CRED $HUB /CMD AccessAdd pass /MEMO:"Contractors to app subnet" \
  /PRIORITY:100 /SRCUSERNAME:Contractors /DESTIP:10.1.20.0/255.255.255.0 /PROTOCOL:ip

# 2) Catch-all: discard anything else those contractors send (low priority = last)
vpncmd $CRED $HUB /CMD AccessAdd discard /MEMO:"Contractors default deny" \
  /PRIORITY:9000 /SRCUSERNAME:Contractors /PROTOCOL:ip
```

**Example — block a sensitive subnet from everyone** (e.g. keep all VPN users away from the server-management VLAN `10.1.99.0/24`):

```bash
vpncmd $CRED $HUB /CMD AccessAdd discard /MEMO:"No VPN to mgmt VLAN" \
  /PRIORITY:50 /DESTIP:10.1.99.0/255.255.255.0 /PROTOCOL:ip
```

**Managing rules:**

```bash
# List all rules with their IDs and priorities
vpncmd $CRED $HUB /CMD AccessList

# Temporarily disable rule ID 3 (keeps it, stops applying it)
vpncmd $CRED $HUB /CMD AccessDisable 3
# Re-enable it later
vpncmd $CRED $HUB /CMD AccessEnable 3

# Permanently delete rule ID 3
vpncmd $CRED $HUB /CMD AccessDelete 3
```

> **Tip — leave gaps in your priority numbers** (100, 200, 9000). You will inevitably need to slot a rule *between* two existing ones, and gaps let you do that without renumbering.
>
> **Gotcha — the implicit-allow trap.** Because unmatched packets pass, an access list with only `pass` rules changes nothing. Segmentation only takes effect when you add a low-priority `discard` catch-all. Test with the `AccessDisable`/`AccessEnable` toggle before deleting, so you can back out instantly if you fence off something you needed.
>
> **Gotcha — `SRCUSERNAME` matches the logged-in VPN user or their group name**, so you can write filters against `Contractors` (a group) or `jane.doe` (a user) directly. This is what makes per-employee segmentation practical.

### 7.6 Restricting where employees can connect *from* (Source IP Address Limit List)

**What it is** — A separate, connection-time gate. Before a VPN session is even established, the hub checks the client's *source IP address* against the Source IP Address Limit List and decides allow or deny. Like the access list, rules are evaluated by priority and the first match wins.

**Why it matters** — If your workforce only ever connects from known office egress IPs or a corporate mobile range, you can refuse connection attempts from everywhere else — cutting off credential-stuffing and brute-force attempts before authentication.

**How to do it — CLI:** `AcAdd allow|deny [/PRIORITY:priority] [/IP:ip/mask]`. Specify a single IP for one host, or an IP with a net/subnet mask for a whole range. Use `AcList` to view rules and `AcDel` to remove one by its number.

**Example** — Allow the office (`203.0.113.0/24`) and a trusted admin host, deny all other sources:

```bash
HUB="/ADMINHUB:Acme-Corp"
CRED="localhost /SERVER /PASSWORD:pass"

vpncmd $CRED $HUB /CMD AcAdd allow /PRIORITY:10 /IP:203.0.113.0/255.255.255.0
vpncmd $CRED $HUB /CMD AcAdd allow /PRIORITY:20 /IP:198.51.100.7
vpncmd $CRED $HUB /CMD AcAdd deny  /PRIORITY:1000 /IP:0.0.0.0/0.0.0.0

# Review, then remove rule #2 if needed
vpncmd $CRED $HUB /CMD AcList
vpncmd $CRED $HUB /CMD AcDel 2
```

> **Gotcha — this locks by *network location*, not identity.** A legitimate employee travelling or on a new home IP will be refused. Only use a deny-all Source IP list when your users genuinely connect from a predictable set of addresses; otherwise rely on strong per-user authentication and the session/access-list controls above. Do not lock yourself out either — make sure the address you administer from is covered by an `allow` rule (or manage over the localhost-bound mgmt port via the SSH tunnel).

### 7.7 Putting it together — a baseline for a WFH deployment

A sensible default posture for a standard employee hub:

1. **Group policy on `Employees`**: `NoBridge: yes`, `NoRouting: yes`, `NoServer: yes`, `DHCPNoServer: yes`, a fair-use `MaxUpload`/`MaxDownload`, and `MultiLogins: 2` (laptop + phone).
2. **Access list**: high-priority `pass` rules to the subnets employees legitimately use, a `discard` covering any sensitive management subnet, and — if you want true segmentation — a low-priority `discard` catch-all per restricted group.
3. **Source IP list**: leave open for a mobile workforce, or lock to known egress ranges if your users are geographically predictable.

Everything here is per-hub, so different customer hubs on the same server can run entirely different postures. For deeper packet inspection, logging, and per-session monitoring, see the relevant sections — this section owns only *policy* and *access control*.

---

## 8. Certificates & TLS

Every TLS connection to your ComfyConnect server — the Web Admin Console, SSTP tunnels, and the native SoftEther/OpenVPN control channel — is protected by the server's SSL certificate and its negotiated cipher. Out of the box the server presents a **self-signed** certificate, which works but makes browsers and Windows SSTP clients throw trust warnings. This section covers viewing and replacing that certificate, tuning the cipher suite, and running a client-certificate authority with revocation for hubs that authenticate users by certificate.

All commands below run through the vpncmd CLI against the server. The general pattern is:

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /CMD <Command> <args...>
```

Certificate and cipher commands (`ServerCert*`, `ServerCipher*`) are **server-wide** and need no `/ADMINHUB`. The CRL commands are **per-hub** — add `/ADMINHUB:Acme-Corp` to target a specific Virtual Hub.

> Gotcha: The management port is bound to localhost in the Docker deploy, so run vpncmd from inside the container or over your SSH tunnel (`127.0.0.1`). None of these commands are available in the Web Admin Console yet — certificates and TLS are Server Manager / vpncmd territory.

### 8.1 The server certificate

**What it is** — The X.509 certificate and RSA private key the VPN Server presents to every client that opens a TLS connection.

**Why it matters** — A self-signed cert triggers "not trusted" warnings in the admin browser and, more importantly, makes **SSTP** connections fail on Windows unless the CN matches the hostname and the CA is trusted. A real CA-issued cert (commercial or Let's Encrypt) removes both problems.

#### Viewing and backing up what's installed

`ServerCertGet` exports the current certificate; `ServerKeyGet` exports the matching private key. Always back up both before you replace anything.

```bash
# Save the current certificate (X.509) and private key (Base64) to disk
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /CMD ServerCertGet ~/backup/current_cert.cer
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /CMD ServerKeyGet  ~/backup/current_key.pem
```

**Tip:** `ServerCertGet` writes only the public certificate — safe to hand to a client for pinning. `ServerKeyGet` writes the secret key; store it with the same care as any private key.

#### Installing a real certificate (recommended)

`ServerCertSet` loads a certificate **and** its private key onto the server. The certificate must be X.509 and the key must be Base64-encoded (PEM). This is how you install a Let's Encrypt or commercial-CA cert.

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /CMD ServerCertSet \
  /LOADCERT:/etc/letsencrypt/live/vpn.acme.com/fullchain.pem \
  /LOADKEY:/etc/letsencrypt/live/vpn.acme.com/privkey.pem
```

**Why it matters for SSTP:** the certificate's **CN (Common Name)** must equal the hostname your employees' SSTP clients dial (e.g. `vpn.acme.com`). If it doesn't match, Windows refuses the connection.

**Gotcha:** If your CA issues an intermediate chain, load the **full chain** (leaf + intermediates) as the cert file so SSTP and browser clients can build a path to the trusted root. Let's Encrypt certs renew every 90 days — script `ServerCertSet` into your renewal hook so the server always serves the fresh key pair.

#### Regenerating a self-signed certificate

`ServerCertRegenerate` replaces the current certificate with a **new self-signed** one carrying the CN you specify. Use it when you don't have a CA cert yet but need the CN to match a hostname (again, important for SSTP clone-server compatibility).

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /CMD ServerCertRegenerate vpn.acme.com
```

**Gotcha:** This **deletes the existing certificate and key** — back them up first with `ServerCertGet` / `ServerKeyGet`. It cannot run on a VPN Bridge or on hubs in a cluster. A self-signed cert still shows trust warnings; treat regenerate as a stopgap and move to `ServerCertSet` with a CA cert when you can.

### 8.2 Cipher suite

**What it is** — The encryption and signature algorithm negotiated for the SSL control channel between the server and its clients.

**Why it matters** — Setting a modern cipher keeps the tunnel compliant with your customers' security policies and drops weak legacy algorithms.

**How to do it (CLI):** `ServerCipherGet` prints the current algorithm plus the full list of algorithms this build supports. `ServerCipherSet` selects one by name.

```bash
# See the current cipher and everything available
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /CMD ServerCipherGet

# Set a specific algorithm (pick a name from the list above)
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /CMD ServerCipherSet AES256-SHA
```

**Tip:** Always run `ServerCipherGet` first and copy an exact name from its output — `ServerCipherSet` only accepts names the server reports as usable, and the list varies by build. The setting applies to VPN Client and VPN Bridge connections negotiated after the change.

### 8.3 Client-certificate authentication: CA and revocation

If a hub authenticates employees by **client certificate** (rather than password), you manage which certificates are trusted at the hub level and maintain a Certificate Revocation List (CRL) to lock out compromised or ex-employee certificates. These commands are per-hub — always include `/ADMINHUB:<HubName>`.

#### Revoking certificates (CRL)

The CRL denies connection to any client whose certificate matches a registered entry. `CrlAdd` registers a revocation; a certificate that matches **all** the fields you specify is judged invalid.

`CrlAdd` accepts: `/SERIAL` (hex serial), `/MD5` (128-bit hex digest), `/SHA1` (160-bit hex digest), and the subject fields `/CN`, `/O`, `/OU`, `/C`, `/ST`, `/L`.

```bash
# Revoke by fingerprint — the most precise way to kill one exact certificate
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp /CMD CrlAdd \
  /SHA1:00112233445566778899AABBCCDDEEFF00112233

# Revoke by subject fields (e.g. a departed employee's cert)
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp /CMD CrlAdd \
  /CN:'jane.doe' /O:'Acme Corp' /SERIAL:1A2B3C
```

**Tip:** When you supply an MD5 or SHA-1 digest, you normally don't need the other fields — the digest pins one exact certificate. Use the subject fields when you want to revoke by identity rather than by a specific issued cert.

Manage the list with the companion commands:

```bash
# List all revocation entries (each has an ID)
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp /CMD CrlList

# Inspect one entry by its ID
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp /CMD CrlGet 2

# Remove an entry by its ID (e.g. cert reissued to a rehired employee)
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass!' /ADMINHUB:Acme-Corp /CMD CrlDel 2
```

**Why it matters:** When a private key is lost or an employee leaves, adding their certificate to the hub's CRL immediately blocks certificate-mode logins with that cert — no password change or re-issuance of everyone else's certs required.

**Gotcha:** CRL commands can't run on a VPN Bridge or on hubs in a cluster. The list is scoped to the one hub in `/ADMINHUB` — repeat per hub if the same cert is trusted in several.

#### Minting certificates for testing

`MakeCert` (RSA 1024-bit) and `MakeCert2048` (RSA 2048-bit) create an X.509 certificate and private key **locally**, either self-signed (a root) or signed by an existing CA cert.

```bash
# Self-signed root/CA certificate, ~10 years, 2048-bit
vpncmd /TOOLS /CMD MakeCert2048 \
  /CN:'Acme-VPN-CA' /O:'Acme Corp' /C:US /ST:CA /L:'San Jose' \
  /SERIAL:0100 /EXPIRES:3650 \
  /SAVECERT:~/pki/ca_cert.cer /SAVEKEY:~/pki/ca_key.pem

# A client certificate signed by that CA
vpncmd /TOOLS /CMD MakeCert2048 \
  /CN:'jane.doe' /O:'Acme Corp' \
  /SIGNCERT:~/pki/ca_cert.cer /SIGNKEY:~/pki/ca_key.pem \
  /SAVECERT:~/pki/jane_cert.cer /SAVEKEY:~/pki/jane_key.pem
```

Omit `/SIGNCERT` and `/SIGNKEY` to create a self-signed root; supply both to issue a cert signed by that root. `/EXPIRES` takes days (max 10950 ≈ 30 years; `none` or `0` defaults to 3650).

**Gotcha:** `MakeCert` is deliberately rudimentary and runs on the *local* machine — the RSA computation and file writes happen wherever vpncmd runs, with no relationship to the remote server you may be managing. For a production CA, ComfyConnect's own docs point you to OpenSSL or commercial CA software rather than `MakeCert`. Prefer `MakeCert2048` over `MakeCert` — 1024-bit keys are no longer considered adequate.

---

## 9. Networking: SecureNAT, Bridges, Cascade & Routing

This section covers how employee traffic actually reaches its destination once a session is up — whether that's just the internet, the full office LAN, or another office. These are Layer-2/Layer-3 plumbing features. **None of this is in the web console yet** — everything here is done with the Server Manager GUI or `vpncmd`. Reach the management port through the deploy's SSH tunnel (`localhost:5555`), and remember most of these commands are hub-scoped, so add `/ADMINHUB:<HubName>` to the connection.

> **Command shape used throughout:**
> ```bash
> vpncmd localhost /SERVER /PASSWORD:<adminpw> /ADMINHUB:Acme-Corp /CMD <Command> <args...>
> ```

### 9.1 Choose the pattern first: SecureNAT vs. Local Bridge

Before touching any command, decide what employees need to reach. This choice drives everything else in the section.

- **SecureNAT (internet-only / self-contained access)** — The Virtual Hub runs its own virtual NAT router and DHCP server entirely in software. Employees get a private IP, and their traffic is NAT'd out through the VPN Server's own network stack. Nothing needs to be configured on your physical office network. This is what `deploy/setup.sh` turns on by default. Best when employees mostly need internet egress and a handful of cloud/hosted resources, and you can't (or don't want to) touch the office switch.

- **Local Bridge (full office-LAN access)** — The Virtual Hub is bridged at Layer 2 directly onto a physical network adapter in the office, so VPN employees appear as if they're plugged into the office switch. They pull IPs from the office's real DHCP server and can reach file servers, printers, and internal hosts natively. Best when employees need to behave exactly like in-office machines.

- **Cascade (site-to-site)** — Links two offices' hubs together at Layer 2 so the two LANs merge into one VPN fabric. Not for individual employees — for joining branch offices.

- **Layer-3 Switch / Router (routing between hubs)** — Routes IP between multiple hubs that live on *different* subnets, instead of bridging them into one flat segment. For larger multi-hub deployments.

> **Gotcha:** Don't enable SecureNAT *and* Local Bridge onto the same office LAN at the same time unless you know exactly what you're doing — you'll have two DHCP servers (the virtual one and the office's real one) answering on the same segment. For a bridged hub, disable the virtual DHCP server (see 9.2).

---

### 9.2 SecureNAT & the virtual DHCP server

**What it is** — SecureNAT bundles a virtual NAT router and a virtual DHCP server that run inside a Virtual Hub, giving connected employees IP addresses and internet egress without any physical network setup.

**Why it matters** — It's the fastest path to a working WFH-VPN: one command and employees have addressing and internet access, ideal for a managed service where you don't control the customer's office switch.

**How to do it (CLI):** SecureNAT is the master switch; the Virtual NAT and Virtual DHCP sub-functions can each be toggled independently, but neither operates until SecureNAT itself is enabled.

```bash
# Turn the whole SecureNAT function on for a hub
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD SecureNatEnable

# Check whether it's actually running (live status)
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD SecureNatStatusGet
```

**Tune the virtual DHCP scope** with `DhcpSet` before or after enabling — this is where you set the address pool, gateway, DNS, and (importantly) pushed routes:

```bash
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD DhcpSet \
  /START:192.168.30.10 /END:192.168.30.200 /MASK:255.255.255.0 \
  /EXPIRE:7200 /GW:192.168.30.1 /DNS:192.168.30.1 /DOMAIN:acme.internal \
  /LOG:yes /PUSHROUTE:"10.0.0.0/255.0.0.0/192.168.30.1"
```

- `/PUSHROUTE` is the key WFH lever: it hands connecting clients extra routes via DHCP classless-static-route option, so you can push *only* the office subnets down the tunnel (split tunnel) instead of all traffic.
- Inspect and adjust related settings with **`NatGet`** / **`NatSet`** (MTU, TCP/UDP session timeouts), **`DhcpGet`** (read current DHCP config), and the virtual host's own adapter with **`SecureNatHostGet`** / **`SecureNatHostSet`** (its MAC/IP/mask on the segment):

```bash
# Give the SecureNAT virtual router a fixed IP on the segment
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD SecureNatHostSet \
  /IP:192.168.30.1 /MASK:255.255.255.0

# Shorten UDP session timeout, raise MTU
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD NatSet \
  /MTU:1500 /TCPTIMEOUT:1800 /UDPTIMEOUT:60 /LOG:yes
```

**Monitor live translation and leases:**

```bash
# Current TCP/UDP NAT sessions
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD NatTable

# IP addresses currently leased to clients
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD DhcpTable
```

**Turning sub-functions on/off** — `NatEnable` / `NatDisable` control just the virtual NAT; `DhcpEnable` / `DhcpDisable` control just the virtual DHCP server. Common WFH use: on a **bridged** hub you want addressing from the *office* DHCP, so keep the L2 SecureNAT path off, or if you enable SecureNAT for NAT-only, disable its DHCP:

```bash
# Use SecureNAT's NAT but let the office DHCP server assign addresses
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD DhcpDisable
```

**To stop it entirely:**

```bash
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Acme-Corp /CMD SecureNatDisable
```

> **Gotcha:** `SecureNatDisable` immediately tears down NAT and wipes the DHCP lease database — every connected employee loses their session's addressing at once. Change it during a maintenance window. Also note: none of the SecureNAT/NAT/DHCP commands work on a hub in a **clustered** VPN Server.

> **Tip:** SoftEther's own help flags SecureNAT as an admin-level feature — misconfigured, it can leak or bridge networks you didn't intend. Push narrow routes and a scoped DHCP range rather than opening everything.

---

### 9.3 Local Bridge — put employees on the office LAN

**What it is** — A Local Bridge connects a Virtual Hub to a physical Ethernet adapter (or a Linux `tap` device) on the VPN Server, creating a Layer-2 bridge between the VPN and the real office network.

**Why it matters** — It's the option that makes remote employees behave exactly like desk workers — same subnet, same DHCP, native access to file shares and printers — which is what most "real" WFH deployments want.

**How to do it (CLI):** First list the adapters the server can bridge onto, then create the bridge. Bridge commands are **server-wide**, not hub-scoped, but you name the hub to bridge.

```bash
# See which physical adapters (or tap) are available
vpncmd localhost /SERVER /PASSWORD:pass /CMD BridgeDeviceList

# Bridge the Acme-Corp hub onto physical adapter "eth1"
vpncmd localhost /SERVER /PASSWORD:pass /CMD BridgeCreate Acme-Corp /DEVICE:eth1 /TAP:no

# On Linux, create a tap device instead of using a physical NIC
vpncmd localhost /SERVER /PASSWORD:pass /CMD BridgeCreate Acme-Corp /DEVICE:soft-tap /TAP:yes
```

**List and remove:**

```bash
vpncmd localhost /SERVER /PASSWORD:pass /CMD BridgeList
vpncmd localhost /SERVER /PASSWORD:pass /CMD BridgeDelete Acme-Corp /DEVICE:eth1
```

> **Tip:** Under load, dedicate a NIC to the bridge rather than sharing the server's primary adapter — SoftEther's own guidance recommends a dedicated adapter for high-traffic bridges.

> **Gotcha (Docker deploy):** Layer-2 bridging onto a host NIC requires the container to have real access to that interface (host networking / privileged NIC). In a locked-down container-only deploy, the `tap` device is often the practical route, paired with host-side routing. When you bridge onto the office LAN, disable SecureNAT's virtual DHCP (9.2) so the office DHCP server is the only one leasing addresses.

---

### 9.4 Cascade — link two offices (site-to-site)

**What it is** — A Cascade Connection is an outbound Layer-2 link from one Virtual Hub to another hub on the same or a different VPN Server, merging the two into one bridged segment.

**Why it matters** — It joins a branch office's hub to headquarters so employees at either site — and their VPN users — sit on one unified network, without per-user tunnels between sites.

**How to do it (CLI):** Create the cascade on the *initiating* hub, set its authentication (new cascades default to Anonymous auth), then bring it online.

```bash
# 1) Create the cascade from Branch-East up to HQ's Acme-Corp hub
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Branch-East /CMD CascadeCreate HQ-Link \
  /SERVER:hq.example.com:443 /HUB:Acme-Corp /USERNAME:branch-east

# 2) Switch it to password authentication with the credentials HQ expects
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Branch-East /CMD CascadePasswordSet HQ-Link \
  /PASSWORD:S3cretLink /TYPE:standard

# 3) Bring it online (it will keep retrying until it connects or you take it offline)
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Branch-East /CMD CascadeOnline HQ-Link
```

**Manage and inspect:**

```bash
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Branch-East /CMD CascadeList
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Branch-East /CMD CascadeStatusGet HQ-Link
vpncmd localhost /SERVER /PASSWORD:pass /ADMINHUB:Branch-East /CMD CascadeOffline HQ-Link
```

The broader `Cascade*` family (e.g. `CascadeUsernameSet`, `CascadeCertSet`, and proxy/server-certificate-verification options) tunes an existing cascade — set those before going online.

> **Gotcha:** Because a cascade is a Layer-2 bridge, a misconfigured topology can create a loop between hubs. Cascade only one direction between any two hubs and keep the map of who-connects-to-whom deliberate. Cascade commands don't work on clustered VPN Servers.

---

### 9.5 Virtual Layer-3 Switch — route between hubs on different subnets

**What it is** — A Virtual Layer-3 Switch performs IP routing *between* multiple Virtual Hubs on this server that live on different IP networks, instead of flattening them into one segment.

**Why it matters** — For a multi-department or multi-tenant deployment where each hub is its own subnet, it lets you route between them centrally rather than bridging everything together.

**How to do it (CLI):** Define the switch, add a virtual interface per hub (each with an IP in that hub's subnet), optionally add static routes, then start it. Interfaces and routes can only be edited while the switch is **stopped**.

```bash
# Define a switch and give it interfaces in two hubs
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterAdd L3-Core
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterIfAdd L3-Core /HUB:Acme-Corp   /IP:192.168.30.1/255.255.255.0
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterIfAdd L3-Core /HUB:Acme-Finance /IP:192.168.40.1/255.255.255.0

# Optional: static route to a network reachable via a gateway on one of those subnets
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterTableAdd L3-Core \
  /NETWORK:10.50.0.0/255.255.0.0 /GATEWAY:192.168.30.254 /METRIC:1

# Start routing
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterStart L3-Core
```

**Inspect and manage:**

```bash
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterList
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterIfList L3-Core
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterTableList L3-Core
vpncmd localhost /SERVER /PASSWORD:pass /CMD RouterStop L3-Core
```

Remove pieces with `RouterIfDel`, `RouterTableDel`, and `RouterDelete` (all require the switch stopped first).

> **Gotcha:** To change interfaces or routes, run `RouterStop` first — `RouterIfAdd`, `RouterTableAdd`, and their delete counterparts refuse to run on a running switch. The Layer-3 Switch is an advanced, IP-routing-savvy feature and **does not operate on a VPN Bridge**; for ordinary WFH access you usually won't need it — SecureNAT or a Local Bridge is enough.

---

### 9.6 Listeners & ports

**What it is** — TCP Listeners are the ports the VPN Server accepts connections on. SoftEther multiplexes its native protocol plus OpenVPN/SSTP over these TCP ports.

**Why it matters** — Employees often connect from networks that only allow 443; controlling listeners lets you make sure the VPN is reachable through restrictive firewalls.

**How to do it (CLI):** Listener commands are **server-wide**.

```bash
# List listeners and their status (operating / error)
vpncmd localhost /SERVER /PASSWORD:pass /CMD ListenerList

# Add a listener on 443 (best for employees behind restrictive firewalls)
vpncmd localhost /SERVER /PASSWORD:pass /CMD ListenerCreate 443

# Temporarily stop / restart a listener without deleting it
vpncmd localhost /SERVER /PASSWORD:pass /CMD ListenerDisable 5555
vpncmd localhost /SERVER /PASSWORD:pass /CMD ListenerEnable 5555

# Remove a listener entirely
vpncmd localhost /SERVER /PASSWORD:pass /CMD ListenerDelete 992
```

> **Tip:** Keeping a listener on **443** gives you the widest reach — it looks like ordinary HTTPS and passes through most corporate and hotel firewalls, and it's the port OpenVPN-over-TCP and SSTP clients expect. `ListenerDisable` stops a listener while preserving its definition, which is safer than deleting when you just need to close a port briefly.

> **Gotcha:** These listeners are separate from the L2TP/IPsec and raw-UDP OpenVPN endpoints (those are enabled per-protocol, not as TCP listeners). Don't disable the listener your live employees are currently connected through — check `ListenerList` and Live Sessions first.

---

## 10. VPN Protocols & Connecting Employees

One of the biggest advantages of ComfyConnect for a work-from-home business is that **employees need no ComfyConnect-specific app**. The server speaks the VPN protocols already built into Windows, macOS, iOS, and Android, plus the free, open-source OpenVPN client. You turn the protocols on once at the server, hand each employee a username, a password, and (optionally) an OpenVPN profile, and they connect with software they either already have or can install in a minute.

This section covers the four protocols the server offers, how to enable each one, and step-by-step connection guides per operating system.

### 10.1 Which protocol should employees use?

| Protocol | Client needed | Best for | Notes |
|---|---|---|---|
| **OpenVPN** | OpenVPN Connect (free) | Most WFH setups | Most reliable across firewalls; import a profile, no manual config. Recommended default. |
| **L2TP/IPsec** | None — built into the OS | Employees who can't install software | Uses the OS's native VPN dialog. Needs a pre-shared key (PSK). |
| **SSTP** | None on Windows — built in | Locked-down Windows fleets | Rides HTTPS (TCP 443), so it passes through most restrictive networks. Windows only for the native client. |
| **SoftEther (native)** | ComfyConnect VPN Client / SoftEther client | Power users, site-to-site | The engine's own protocol; highest performance and full option set, but requires the dedicated client. |

**Tip:** Recommend OpenVPN first. If an employee is on a corporate machine where they can't install anything, fall back to L2TP/IPsec (macOS, Windows, mobile) or SSTP (Windows).

### 10.2 Enabling the protocols on the server

If you ran `deploy/setup.sh`, OpenVPN, SSTP, and L2TP/IPsec are **already enabled** — the script turns them on for you and prints the IPsec pre-shared key. The subsections below show how to enable or re-check each one manually.

#### OpenVPN

**What it is** — the server's OpenVPN-compatible listener, controlled as a protocol option rather than a dedicated on/off command.

**Why it matters** — OpenVPN is the most firewall-friendly, cross-platform way for a remote employee to connect, and it needs no OS configuration.

**How to do it** — Web console: not in the web console yet — use vpncmd or the Server Manager. CLI: toggle the protocol option `Enabled` for the `OpenVPN` protocol.

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass' \
  /CMD ProtoOptionsSet OpenVPN /NAME:Enabled /VALUE:true
```

`ProtoOptionsSet` "Sets an option's value for the specified protocol"; its syntax is `ProtoOptionsSet [protocol] [/NAME:option_name] [/VALUE:string/true/false]`. To see every option and its current value first, run `ProtoOptionsGet OpenVPN` ("Lists the options for the specified protocol").

**Gotcha:** Protocol options like this are server-wide (they aren't scoped to a single hub), so you don't add `/ADMINHUB:` for `ProtoOptionsSet`.

#### Generating an OpenVPN profile

**What it is** — `OpenVpnMakeConfig` "Generate a Sample Setting File for OpenVPN Client" — it produces a ready-to-import `.ovpn` configuration bundle so employees never hand-write OpenVPN config.

**How to do it** — CLI: write the profile bundle to a ZIP.

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass' \
  /CMD OpenVpnMakeConfig acme-openvpn.zip
```

Syntax is `OpenVpnMakeConfig [ZIP_FileName]`. Per its help: "the OpenVPN Client requires a user to write a very difficult configuration file manually. This tool helps you to make a useful configuration sample." The generated ZIP contains ready-made `.ovpn` files (typically one for UDP and one for TCP); the employee imports one and supplies their own username and password. Requires VPN Server administrator privileges, cannot run on a VPN Bridge, and cannot be run against a hub in a cluster.

**Tip:** `onboarding/add-employee.sh` calls the equivalent JSON-RPC method (`MakeOpenVpnConfigFile`) for you and saves it as `openvpn-profiles.zip` in the employee's folder — see 10.5.

#### L2TP/IPsec

**What it is** — `IPsecEnable` "Enable or Disable IPsec VPN Server Function." Turning it on lets hubs "accept Remote-Access VPN connections from L2TP-compatible PCs, Mac OS X and Smartphones."

**Why it matters** — this is the protocol employees use with the **native** VPN dialog on Windows, macOS, iPhone, and Android — no client install.

**How to do it** — CLI:

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass' \
  /CMD IPsecEnable /L2TP:yes /L2TPRAW:no /ETHERIP:no \
       /PSK:'Comfy9x' /DEFAULTHUB:Acme-Corp
```

Full syntax: `IPsecEnable [/L2TP:yes|no] [/L2TPRAW:yes|no] [/ETHERIP:yes|no] [/PSK:pre-shared-key] [/DEFAULTHUB:default_hub]`.
- `/L2TP:yes` — the option employees' phones, Macs, and Windows PCs use. Enable this.
- `/L2TPRAW` — raw L2TP with no encryption; leave `no` unless you have a special client.
- `/ETHERIP` — EtherIP/L2TPv3 for site-to-site router bridging; leave `no` for WFH.
- `/PSK` — the pre-shared key every L2TP/IPsec user must enter alongside their username/password.
- `/DEFAULTHUB` — the hub that L2TP users land in when their username has no `user@hub` suffix.

**Gotcha:** Keep the PSK to **9 characters or fewer**. The server explicitly warns that "several versions of Google Android has a serious bug with 10 or more letters pre-shared key," and recommends 9 or fewer. Treat the PSK as a shared secret — distribute it over a secure channel, not in the same message as the password.

#### SSTP

**What it is** — the server's SSTP listener, an SSL-VPN protocol that Windows supports natively over HTTPS. It's controlled the same way as OpenVPN, via a protocol option.

**Why it matters** — SSTP runs over TCP 443, so it slips through restrictive networks that block other VPN ports; it's ideal for locked-down Windows machines.

**How to do it** — CLI:

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass' \
  /CMD ProtoOptionsSet SSTP /NAME:Enabled /VALUE:true
```

**Gotcha:** SSTP validates the server's TLS certificate. For a smooth employee experience, install a certificate whose CN/SAN matches the address employees dial (see the server-certificate section); with the default self-signed cert, Windows will refuse to connect until the cert is trusted.

#### The native SoftEther protocol

**What it is** — ComfyConnect's own high-performance VPN protocol (the SoftEther engine's native transport). It's always available to the dedicated ComfyConnect/SoftEther VPN Client and needs no separate enable step.

**Why it matters** — it delivers the best throughput and exposes the full client option set (multiple TCP connections, compression, detailed policies), which suits power users and administrators, though it requires the dedicated client rather than a built-in OS VPN.

**How to do it** — the employee installs the ComfyConnect VPN Client (Windows/Linux/macOS), creates a connection setting pointing at the server address, hub name, and their username/password. Most WFH employees won't need this — steer them to OpenVPN or L2TP unless they specifically need native-client features.

### 10.3 Creating an employee account

Every protocol above authenticates against the same per-hub user database, so an employee needs exactly one account. Use password authentication for the simplest onboarding.

```bash
# 1) Create the account in the hub
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass' /ADMINHUB:Acme-Corp \
  /CMD UserCreate jane.doe /REALNAME:"Jane Doe" /NOTE:"Sales"

# 2) Set (or reset) her password
vpncmd 127.0.0.1 /SERVER /PASSWORD:'AdminPass' /ADMINHUB:Acme-Corp \
  /CMD UserPasswordSet jane.doe /PASSWORD:'her-strong-password'
```

`UserCreate` syntax is `UserCreate [name] [/GROUP:group] [/REALNAME:realname] [/NOTE:note]`. **Important:** a freshly created user gets a *random* password and cannot log in until you set one — the help notes you "must always use the UserPasswordSet command to specify the user password." `UserPasswordSet` ("Set Password Authentication for User Auth Type and Set Password") stores the password only as a hash, so "even if the VPN Server setting file is analyzed, the original password cannot be deciphered."

**Web console:** creating a user with password auth, resetting a password, and removing a user *are* supported — go to **Employees**, pick the hub, and add the user there. Anything beyond password auth (certificate, RADIUS, NTLM) is not in the web console yet — use vpncmd or the Server Manager.

### 10.4 Employee connection guides

Give the employee their **server address**, **hub name**, **username**, and **password** — plus the OpenVPN profile (for OpenVPN) or the IPsec PSK (for L2TP). Then point them at the matching guide below.

#### OpenVPN Connect (Windows, macOS, iOS, Android)

1. Install the free **OpenVPN Connect** app from openvpn.net or the device's app store.
2. Open the app and choose **Import Profile → File (Upload File)**.
3. Select the `.ovpn` file from the profile ZIP you sent (the UDP profile is the usual choice; use the TCP one if UDP is blocked).
4. Enter the **username** and **password** from the connection card.
5. Tap/click **Connect**.

**Tip:** If the connection fails on a hotel or café network, switch to the **TCP** `.ovpn` profile — it uses TCP 443 and gets through almost anywhere.

#### Windows built-in VPN (L2TP/IPsec)

1. **Settings → Network & Internet → VPN → Add a VPN connection.**
2. **VPN provider:** Windows (built-in).
3. **Connection name:** ComfyConnect.
4. **Server name or address:** the server address from the card.
5. **VPN type:** *L2TP/IPsec with pre-shared key*.
6. **Pre-shared key:** the IPsec PSK.
7. **Sign-in info:** User name and password → enter the employee's credentials.
8. Save, then click **Connect**.

**Gotcha:** Windows clients behind a NAT router sometimes need the L2TP-over-NAT registry fix (`AssumeUDPEncapsulationContextOnSendRule = 2`) before L2TP/IPsec will connect. If OpenVPN is available, it avoids this entirely.

#### macOS built-in VPN (L2TP/IPsec)

1. **System Settings → Network → ⋯ (or +) → Add VPN Configuration → L2TP over IPsec.**
2. **Display Name:** ComfyConnect.
3. **Server Address:** the server address from the card.
4. **Account Name:** the employee's username.
5. **Authentication Settings → Password:** the employee's password; **Shared Secret:** the IPsec PSK.
6. Apply, then **Connect**.

**Tip:** Enable "Show VPN status in menu bar" so employees can connect/disconnect with one click.

#### SSTP on Windows

Windows has no built-in SSTP importer that takes a profile, so configure it manually:

1. **Settings → Network & Internet → VPN → Add a VPN connection.**
2. **VPN provider:** Windows (built-in).
3. **Server name or address:** the address employees dial — it must match the server certificate's name.
4. **VPN type:** *Secure Socket Tunneling Protocol (SSTP)*.
5. **Sign-in info:** User name and password.
6. Save and **Connect**.

**Gotcha:** SSTP will refuse to connect if the server certificate isn't trusted by Windows or its name doesn't match the address. Install a proper certificate (or push the self-signed cert into the machine's Trusted Root store) before rolling SSTP out.

### 10.5 One-command onboarding: `add-employee.sh`

**What it is** — `onboarding/add-employee.sh` creates the account, generates the OpenVPN profile, and writes a ready-to-send **connection card** in a single step, using the server's JSON-RPC API.

**Why it matters** — it turns onboarding a remote employee into one command, with the credentials and profile bundled for secure hand-off.

**How to do it:**

```bash
cd onboarding
ADMIN_PW='AdminPass' HUB='Acme-Corp' HOST='vpn.acme.example.com' \
  ./add-employee.sh jane.doe
```

- **Username** is the one required argument; pass a password as the second argument or let the script generate a strong random one.
- **Admin password** is read from the `ADMIN_PW` env var or prompted — never passed on the command line (so it can't leak via `ps`).
- Config via env: `SERVER` (default `https://127.0.0.1:5555`), `HUB` (default `ComfyConnect`), `HOST` (the address employees dial, derived from `SERVER` if unset).

It creates the account with **password authentication** (updating the password if the account already exists), then produces a folder `employee-<username>/` containing:
- **`CONNECTION-CARD.txt`** — server address, username, password, hub, and how-to-connect instructions for OpenVPN and L2TP/IPsec.
- **`openvpn-profiles.zip`** — the OpenVPN profile to import.

All output files are written owner-readable only (`umask 077`, `chmod 600`).

**Gotcha:** The connection card deliberately prints the **password** but says *"Pre-shared key: (ask your administrator)"* for L2TP — the IPsec PSK is a shared server secret and isn't embedded in per-employee cards. Send the card and profile over a **secure channel** (encrypted file share or password manager, not plain email), and delete your local copies once the employee has connected, as the script's final message reminds you.

---

## 11. Logging, Monitoring & Server Administration

This section covers day-to-day operations: watching who is connected, capturing logs for troubleshooting and compliance, shipping those logs to your SIEM, reading server health, and backing up or restoring the whole server configuration. The web console handles the everyday session view; everything deeper lives in the Server Manager GUI or `vpncmd`.

Throughout, the CLI pattern is:

```bash
vpncmd <host> /SERVER /PASSWORD:<adminpw> /CMD <Command> <args...>
```

Session and log commands are **Virtual Hub-scoped** — add `/ADMINHUB:<HubName>`. Server-wide commands (server status, syslog, config, keep-alive, clustering) are run in **server-admin mode** with no `/ADMINHUB`.

---

### 11.1 Monitoring live sessions

**What it is** — The list of VPN sessions currently connected to a hub, the details of any one session, and the ability to forcibly disconnect one.

**Why it matters** — For a WFH-VPN service this is your front-line operational view: who is online right now, from where, how much they are transferring, and the ability to cut off a stale or suspicious connection immediately.

**How to do it**

- **Web console:** Open **Live Sessions** to see the per-hub session list, and click **Disconnect** on any row. This is the one monitoring surface the simplified console fully covers.
- **CLI — list:** `SessionList` returns each session's Session Name, source host name, user name, TCP connection count, and transferred bytes/packets for the managed hub.
- **CLI — detail:** `SessionGet [name]` returns the full record for one session — source host and user name, client/server version, connection times, communication parameters, the session key, and transfer statistics.
- **CLI — disconnect:** `SessionDisconnect [name]` forcibly drops a session using admin privileges.

**Example**

```bash
# List everyone connected to the Acme-Corp hub
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD SessionList

# Inspect one session in detail
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD SessionGet SID-JANE.DOE-3

# Forcibly disconnect it
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD SessionDisconnect SID-JANE.DOE-3
```

**Gotcha** — If the client has auto-reconnect enabled, a disconnected session may simply come back. To keep a user out, also disable or delete the user account (see the Users & Authentication section) before disconnecting.

---

### 11.2 Security logs and packet logs

**What it is** — Each Virtual Hub can keep two log streams: a **security log** (administrative and authentication events — logins, user/hub changes, connection accept/deny) and a **packet log** (a record of packets passing through the hub, with per-protocol detail control).

**Why it matters** — The security log is your audit trail for compliance (who authenticated, when, from where); the packet log is a troubleshooting and forensics tool for connectivity and routing issues.

**How to do it** — Not in the web console yet — use the Server Manager or `vpncmd`.

- **Enable/disable:** `LogEnable [security|packet]` / `LogDisable [security|packet]`.
- **Review current settings:** `LogGet` shows the save settings for both security and packet logs on the hub.
- **Packet detail level:** `LogPacketSaveType /TYPE:<type> /SAVE:<none|header|full>` sets how much of each packet type is recorded. Types are `tcpconn`, `tcpdata`, `dhcp`, `udp`, `icmp`, `ip`, `arp`, `ether`. `header` logs headers only; `full` logs the whole packet.
- **Rotation:** `LogSwitchSet [security|packet] /SWITCH:<sec|min|hour|day|month|none>` sets the log file switch cycle.

**Example**

```bash
# Turn on the security (audit) log for a hub
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD LogEnable security

# Log TCP connection events with header detail only
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD LogPacketSaveType /TYPE:tcpconn /SAVE:header

# Rotate the security log daily
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp \
  /CMD LogSwitchSet security /SWITCH:day
```

**Tip** — For compliance, enable the **security log** and set `/SWITCH:day` so each day lands in its own file — easy to archive and retain. Reserve **full** packet logging for active troubleshooting; at scale it consumes disk quickly.

---

### 11.3 Retrieving log files

**What it is** — The server writes logs to files on the server computer; you list them and download individual files.

**Why it matters** — You need the raw files to hand to auditors, feed a forensics workflow, or diagnose an incident after the fact.

**How to do it** — Not in the web console yet — use the Server Manager or `vpncmd`.

- **List:** `LogFileList` shows the log files stored on the server. In server-admin mode you see packet and security logs for **all** hubs plus the server log; in hub-admin mode, only that hub's logs.
- **Download:** `LogFileGet [name]` downloads one file. With a destination filename it saves there; without one it prints to screen. On a cluster, use `/SERVER:<name>` to pull the file from a specific member.

**Example**

```bash
# See which log files exist on the server
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD LogFileList

# Download one to a local file
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass \
  /CMD LogFileGet "security_log/Acme-Corp/20260724.log" /path/to/save/20260724.log
```

**Gotcha** — Log files can be very large. Always download to a file (not the screen) for packet logs, and make sure the destination has room.

---

### 11.4 Shipping logs to a SIEM (syslog)

**What it is** — The server can forward its logs to an external syslog server instead of (or in addition to) writing local files.

**Why it matters** — Centralizing logs in a SIEM (Splunk, Elastic, Graylog, etc.) is how you meet retention, alerting, and audit requirements across a fleet of hubs — and it keeps the record off the VPN host itself.

**How to do it** — Not in the web console yet — use the Server Manager or `vpncmd`.

- **Enable:** `SyslogEnable [1|2|3] /HOST:<host:port>`. The level controls what is sent:
  - `1` — server log only
  - `2` — server log + Virtual Hub security logs
  - `3` — server log + security logs + packet logs
- **Check:** `SyslogGet` returns the current mode and the configured syslog host/port.
- **Disable:** `SyslogDisable` turns forwarding off.

**Example**

```bash
# Send server + security logs to the SIEM on UDP 514
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass \
  /CMD SyslogEnable 2 /HOST:siem.acme.internal:514

# Verify
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD SyslogGet
```

**Tip** — Level `2` is the right default for compliance: it captures the audit-relevant security events without the volume of full packet logs. Reach the syslog collector over a trusted path — plain syslog is unencrypted UDP.

---

### 11.5 Server information and health

**What it is** — Two read-only snapshots of the server: static build/OS information and live operational status.

**Why it matters** — Version and build info are what you quote in a support case; live status (session counts, object counts, memory) is your at-a-glance health check.

**How to do it**

- **Web console:** **Overview** shows live stats and the hub list — the everyday health view.
- **CLI — build/OS:** `ServerInfoGet` returns version number, build number, build info, current operation mode, and host OS details.
- **CLI — live status:** `ServerStatusGet` returns real-time data-communication statistics, counts of the various objects on the server, and OS memory usage.

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD ServerInfoGet
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD ServerStatusGet
```

**Tip** — `ServerStatusGet` is cheap and safe to poll — a natural source for an external monitoring dashboard alongside your syslog feed.

---

### 11.6 Keep-alive (internet connection keep-alive)

**What it is** — A function that sends small packets to a nominated host at set intervals so an idle upstream link is not torn down by an ISP or NAT gateway.

**Why it matters** — On connections that drop after periods of silence, keep-alive holds the server's upstream path open so remote workers do not hit dead links.

**How to do it** — Not in the web console yet — use the Server Manager or `vpncmd`. `KeepEnable` / `KeepDisable` toggle the function; `KeepGet` shows the current destination host, port, interval, protocol, and enabled state.

**Example**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD KeepGet
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD KeepEnable
```

**Gotcha** — ComfyConnect ships with keep-alive **disabled by default** as part of the no-phone-home security posture. Enable it only if your specific hosting link actually drops idle connections; a normal always-on server host does not need it.

---

### 11.7 Backing up and restoring the server configuration

**What it is** — The entire server configuration — hubs, users, listeners, certificates, settings — as a single editable `.config` text file. `ConfigGet` exports it; `ConfigSet` imports it.

**Why it matters** — This is your full-server backup and disaster-recovery mechanism, and the fastest way to clone a known-good setup to a new host.

**How to do it** — Not in the web console yet — use the Server Manager or `vpncmd` in server-admin mode.

- **Export:** `ConfigGet [path]` writes the current config to the given file (save as UTF-8); with no path it prints to screen.
- **Import:** `ConfigSet [path]` applies a config file — **the server restarts automatically** and comes back on the new configuration.

**Example**

```bash
# Nightly backup
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass \
  /CMD ConfigGet /backups/comfyconnect-$(date +%F).config

# Restore (server will restart on apply)
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass \
  /CMD ConfigSet /backups/comfyconnect-2026-07-24.config
```

**Gotcha** — `ConfigSet` restarts the server and **overwrites all current settings** — every active session drops. Only apply a config you exported with `ConfigGet` and understand; a malformed file can lose settings. Schedule restores in a maintenance window, and always take a fresh `ConfigGet` immediately before applying one.

---

### 11.8 Verifying the operating environment

**What it is** — A self-test that checks whether the machine running `vpncmd` is a suitable platform for ComfyConnect VPN.

**Why it matters** — Run it before commissioning a new server (or after an OS change) to catch platform problems before users depend on the host.

**How to do it** — CLI: `Check` runs the suite (memory, network, filesystem, and related tests). It runs against the local machine and needs no server connection.

**Example**

```bash
vpncmd /CMD Check
```

**Tip** — A clean pass strongly predicts correct operation; a failure flags host trouble to fix before go-live.

---

### 11.9 Clustering / server farm (advanced)

> **Advanced — most WFH-VPN deployments do not need this.** A single standalone server handles typical workforces. Consider clustering only for large-scale, high-availability, or load-balanced deployments.

**What it is** — Multiple VPN Servers operating as one farm. One server is the **cluster controller** (the central coordinator); the others join as **cluster members**. A hub's session list on a static hub can then be viewed farm-wide from the controller.

**Why it matters** — Clustering provides load balancing and redundancy across servers for very large or always-available services.

**How to do it** — Not in the web console — Server Manager or `vpncmd`, server-admin mode. Each of these restarts the server and **cannot run on a VPN Bridge**:

- `ClusterSettingController` — make this server the cluster controller.
- `ClusterSettingMember` — join this server to a controller (you'll need the controller's IP/port, this server's public IP/port, and the cluster password).
- `ClusterSettingStandalone` — return to standalone (the default).
- `ClusterSettingGet` — show this server's current clustering configuration.
- `ClusterMemberList` — on the controller, list all members with their type, host name, points, session/TCP/hub counts, and license usage.

**Example**

```bash
# Promote a server to cluster controller
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD ClusterSettingController

# From the controller, review the farm
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD ClusterMemberList
```

**Gotcha** — Switching cluster role restarts the server and drops sessions. Plan the controller and its addressing before adding members, and coordinate the change in a maintenance window.

---

### 11.10 Audit logging for compliance — recommended baseline

For a managed WFH-VPN service, wire these together into a repeatable posture:

1. **Enable the security log on every hub** (`LogEnable security`) — this is your authentication and administration audit trail.
2. **Rotate daily** (`LogSwitchSet security /SWITCH:day`) so each day archives cleanly for your retention policy.
3. **Forward to your SIEM** (`SyslogEnable 2 /HOST:...`) for centralized, tamper-resistant retention and alerting.
4. **Back up the config nightly** (`ConfigGet`) and store off-host.
5. **Keep packet logging lean** — headers or off in steady state; full only during active troubleshooting.

This gives you a defensible record of who connected and what administrators changed, retained centrally, without saturating the VPN host's disk.

---

## 12. Security & Hardening

ComfyConnect ships with a deliberately locked-down default posture: no outbound "phone-home", a least-privilege container, and the management surface bound to localhost. This section explains what the vendor changed and why, then gives you a concrete checklist to keep a production deployment tight. Because the engine underneath is SoftEther VPN, treat this as VPN-server hardening — most of it is done from the **Server Manager (GUI)** or **vpncmd**, not the simplified web console.

### 12.1 What the vendor disabled (and why)

By default the deploy turns off every feature that would make the server reach out to the internet on its own or advertise itself to a third-party service. For a work-from-home VPN that fronts a company's internal network, silent outbound connections and public registration are attack surface and a compliance headache — you want a server that only does what you told it to.

Disabled by default:

- **Dynamic DNS (DDNS)** — no automatic public hostname registration. SoftEther's DDNS assigns a permanent public hostname and tracks your IP; the vendor disables it so the server never announces itself. It is switched off in the server configuration file (the `declare DDnsClient` block has `bool Disable set to true`), not via a single CLI toggle.
- **VPN Azure** — off. This is a cloud relay ("VPN Azure is a cloud VPN service") that lets a server behind NAT be reached without a global IP; convenient for a home PC, wrong for a managed corporate gateway.
- **NAT traversal / UDP acceleration outbound registration** — off, so the server does not register with public relay servers.
- **Keep-alive internet connection** — off. This feature periodically sends packets to a nominated internet host to keep a link up; a datacenter-hosted server does not need it and it is one more outbound flow.
- **Update check** — off. No calling home to check for new engine versions.

**How to verify / re-assert.** These are the CLI commands that govern the phone-home features, so you can confirm state or re-disable after any config restore:

```bash
# Disable the keep-alive internet connection function
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /CMD KeepDisable

# Disable VPN Azure (takes an enable/disable argument)
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /CMD VpnAzureSetEnable no
```

**Gotcha:** DDNS cannot be turned off with a one-shot command — its help explicitly says to disable it you "modify the configuration file of VPN Server" and reboot. The vendor image already ships it disabled; if you ever restore a hand-edited config, re-check that `DDnsClient`'s `Disable` is still `true`.

### 12.2 Container hardening

The Docker deploy (`deploy/docker-compose.yml`) runs the engine with least privilege so a compromise of the VPN process can't easily become a compromise of the host.

**What's in place:**

- **`cap_drop: [ALL]`** then add back only `NET_ADMIN`, `NET_BIND_SERVICE`, `SETUID`, `SETGID` — the minimum a VPN server needs to manage interfaces, bind low ports, and drop privilege.
- **`security_opt: no-new-privileges:true`** — processes inside the container can't gain new privileges via setuid binaries.
- **Resource ceilings** — `mem_limit: 1g`, `pids_limit: 512`, `cpus: 2.0`, `nofile: 65535`, so a connection flood or fork storm is contained rather than exhausting the host (basic DoS containment).
- **Management port on localhost only** — the RPC/management port `5555` is published as `127.0.0.1:5555:5555`. Only the employee-facing endpoints (`443`, `992`, `1194/udp`, `500/udp`, `4500/udp`) are public.

**How to reach the console safely.** Since `5555` is not exposed on the public interface, tunnel it over SSH:

```bash
ssh -L 5555:127.0.0.1:5555 user@your-server
# then open https://127.0.0.1:5555/admin/  in your browser
```

**Tip:** Keep the port map exactly this way. If you ever change `127.0.0.1:5555:5555` to `5555:5555`, you have just published the full admin/RPC surface to the internet. The web console and JSON-RPC API both answer on that port.

### 12.3 Best-practice checklist

Work through these on every new deployment. They go beyond the defaults and are where most real-world risk is closed.

#### Set a strong server administrator password

**What it is** — the master credential for the whole VPN Server (the web console sign-in and full admin access).

**Why it matters** — it protects every hub, user, and setting on the box.

**How** — `setup.sh` sets one at install; rotate it with a strong value. Prefer the interactive prompt so the password never appears on screen or in shell history.

```bash
# Prompts for the password (recommended — nothing echoed)
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<currentpw>' /CMD ServerPasswordSet
```

**Gotcha:** the command's own help warns that passing the password as a parameter "will be displayed momentarily on the screen, which poses a risk." Use the prompt form.

#### Replace the self-signed certificate with a real one

**What it is** — the SSL certificate the server presents to connecting clients and to the admin console.

**Why it matters** — a CA-issued cert with the right hostname stops certificate-warning fatigue (which trains users to click through) and enables clean SSTP client connections, where the CN must match the hostname.

**How** — install your real certificate and key, or regenerate the self-signed cert with the correct Common Name in the meantime:

```bash
# Install a CA-issued cert + Base64 private key
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /CMD ServerCertSet /LOADCERT:server.crt /LOADKEY:server.key

# Or regenerate a self-signed cert with the correct hostname as CN
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /CMD ServerCertRegenerate vpn.acme-corp.com
```

**Tip:** back up the current key first with `ServerKeyGet` — `ServerCertRegenerate` deletes the existing SSL certificate.

#### Firewall the management port

Keep `5555` bound to localhost (as shipped) and, at the host/cloud firewall, block it entirely from the outside. Publish only the employee VPN ports. This is not in the web console — it's your host firewall and the compose port map.

#### Use per-hub administrator passwords

**What it is** — a separate admin password scoped to a single Virtual Hub.

**Why it matters** — you can delegate day-to-day management of one company/hub (e.g. `Acme-Corp`) without handing over the whole server. Hub admins manage their hub and can view but not change server-wide administration options.

**How (CLI, hub-scoped):**

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /ADMINHUB:Acme-Corp /CMD SetHubPassword
```

**Gotcha:** setting a hub admin password also enables connecting to that hub as user `Administrator` with that password. Treat hub admin passwords as strong secrets, and pair delegation with `AdminOptionSet` to cap what a hub admin may change.

#### Enforce user security policies

**What it is** — per-user and per-group rules that constrain what a connected client can do (the settable items are listed by `PolicyList`).

**Why it matters** — for a WFH VPN you typically want to prevent employees from bridging, running DHCP servers, or otherwise abusing the tunnel; policies are how you cap sessions, bandwidth, and network behavior.

**How** — list the available policy items first, then apply to a user:

```bash
# See every policy name, description, and allowed values
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /ADMINHUB:Acme-Corp /CMD PolicyList

# Apply a policy value to a user (repeat per policy item)
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /ADMINHUB:Acme-Corp /CMD UserPolicySet jane.doe /NAME:MaxConnection /VALUE:2
```

**Tip:** for network-level filtering (e.g. block a hub's clients from reaching each other, or restrict them to specific subnets), add access-list rules with `AccessAdd` on the hub. Policies and access lists are not in the web console yet — use the Server Manager or vpncmd.

#### Enable syslog audit

**What it is** — forwarding server/security/packet logs to an external syslog server.

**Why it matters** — off-box logs give you tamper-resistant audit trails for who connected, when, and from where — important for incident response and compliance in a business VPN.

**How** — pick a send level (`1` = server log, `2` = + hub security logs, `3` = + packet logs) and a destination:

```bash
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /CMD SyslogEnable 2 /HOST:logs.acme-corp.com:514
# Check current setting:
vpncmd 127.0.0.1 /SERVER /PASSWORD:'<adminpw>' /CMD SyslogGet
```

**Gotcha:** level `3` (packet logs) is verbose and can be sensitive — use `2` for most audit needs.

#### Keep the host and image patched

Rebuild the image and update the host OS on a regular cadence. Because update-check is intentionally disabled (no phone-home), you own patch tracking — don't wait for the server to tell you.

### 12.4 Track the upstream engine's advisories

Be honest with yourself about what you're running: ComfyConnect is a rebrand of the open-source **SoftEther VPN** engine, with all of its protocol code intact. Any security advisory or CVE that affects SoftEther VPN affects ComfyConnect. Watch the SoftEther VPN project's release notes and security advisories, and rebuild the deploy image when a fix lands. The vendor's hardening (no phone-home, least-privilege container, localhost management) reduces exposure, but it does not replace patching the underlying engine.

---

## 13. Tips, Tricks & Troubleshooting

This section collects field-tested practices for running ComfyConnect as a WFH-VPN service, plus a quick troubleshooting FAQ. Entries are deliberately short — each points you at the right tool (web console, Server Manager, or `vpncmd`).

### 13.1 Operating Tips

**One Virtual Hub per client.**
Give every business its own hub. Users, groups, sessions, and traffic counters are all scoped to the hub, so one-hub-per-client gives you clean multi-tenancy, per-client billing from the hub's traffic stats, and blast-radius isolation if one tenant is compromised.
- **How:** Web console: Virtual Hubs > Create. CLI: `HubCreate`.
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD HubCreate Acme-Corp
```
- **Gotcha:** Hubs can't be merged later. Decide your tenant boundary before onboarding a client's employees.

**Use groups for shared policies.**
A group lets you apply one set of security-policy settings (bandwidth, session limits, no-bridge, etc.) to many users at once instead of editing each user.
- **How:** CLI: `GroupCreate` to make the group, then `GroupJoin` to add each user. Not in the web console yet — use `vpncmd` or the Server Manager.
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD GroupCreate Sales
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD GroupJoin Sales /USERNAME:jane.doe
```
- **Tip:** Change the group's policy once and every member inherits it — ideal for "all contractors get 10 Mbps, no LAN bridging."

**Script bulk onboarding.**
For more than a handful of employees, don't click through the console. Loop the vendor's `onboarding/add-employee.sh` over a CSV so each hire gets a user plus a ready-to-send OpenVPN profile and connection card.
```
while IFS=, read -r user hub; do
  ./onboarding/add-employee.sh "$hub" "$user"
done < new-hires.csv
```
- **Tip:** Keep the generated `.ovpn` files out of shared drives — they contain the user's connection config.

**Back up the configuration regularly.**
`ConfigGet` returns the entire server configuration — hubs, users, certs, listeners — as a single text file you can archive and later restore with `ConfigSet`.
- **How:** CLI:
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD ConfigGet backup-$(date +%F).config
```
- **Why it matters:** One file restores an entire tenant estate onto a fresh server — your disaster-recovery insurance.
- **Gotcha:** The backup contains password hashes and private keys. Store it encrypted, and remember `ConfigSet` restarts the server on restore.

**Pick the right client protocol.**
- **OpenVPN** — most reliable, cross-platform experience (Windows/macOS/Linux/iOS/Android). Make this your default; the onboarding script already generates OpenVPN profiles.
- **L2TP/IPsec** — zero-install on managed devices, since the client is built into every modern OS. Best when employees can't install software.
- **SSTP** — useful behind strict firewalls that only allow TCP 443.

### 13.2 Troubleshooting FAQ

**"I can't reach the web console."**
The management port (5555) is bound to localhost in the Docker deploy — it is not exposed to the internet by design. Reach it through an SSH tunnel, then open the console against your local end:
```
ssh -L 5555:localhost:5555 you@vpn.acme.example
# then browse to https://localhost:5555/admin/
```
If the page loads but warns about the certificate, see the self-signed cert entry below.

**"An employee can't connect."**
Check, in order:
1. **Protocol enabled?** Confirm OpenVPN/SSTP/L2TP is turned on (the deploy's `setup.sh` enables them). CLI: `OpenVpnGet` / `SstpGet` to verify.
2. **Port open?** OpenVPN default UDP 1194, SSTP/HTTPS TCP 443, L2TP/IPsec UDP 500 + 4500. Make sure the firewall/cloud security group allows them.
3. **Right hub?** The user must exist in the hub they're connecting to. Web console: Employees (select the hub).
4. **Password correct?** Reset it — Web console: Employees > Reset password, or CLI `UserPasswordSet`.
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD UserPasswordSet jane.doe /PASSWORD:NewPass123
```

**"There's a self-signed certificate warning."**
Fresh servers ship a self-signed SSL cert, so browsers and some VPN clients warn. It's expected. Options:
- For the admin console over the SSH tunnel, accept the warning — the tunnel already secures the channel.
- For production clients, install a proper cert (Server Manager: Encryption and Network settings), or regenerate the self-signed cert with a matching hostname CN — important for SSTP, whose clients require the CN to match the server name.
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /CMD ServerCertRegenerate vpn.acme.example
```
- **Gotcha:** `ServerCertRegenerate` replaces the existing cert. Back up the current key first with `ServerKeyGet`.

**"How do I reset the server admin password?"**
Use `ServerPasswordSet`. Omit the password on the command line so it prompts (safer — it won't appear in shell history).
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:OldAdminPass /CMD ServerPasswordSet
```
This is the login for both the web console and the Server Manager, so update your stored credentials afterward.

**"Who's online right now?"**
- **Web console:** Live Sessions — lists active sessions per hub, with a Disconnect button.
- **CLI:** `SessionList` shows session name, user, source host, and transfer counters; `SessionDisconnect` forcibly drops one.
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD SessionList
```
- **Gotcha:** If a disconnected client has auto-reconnect enabled, it may come straight back — disable the user or reset their password to keep them out.

**"How do I give a client's IT their own admin access?"**
Set a per-hub administrator password with `SetHubPassword`. They can then log in in **Virtual Hub Admin Mode** — full control of *their* hub only, with no visibility into other tenants or server-wide settings.
```
vpncmd 127.0.0.1 /SERVER /PASSWORD:AdminPass /ADMINHUB:Acme-Corp /CMD SetHubPassword /PASSWORD:AcmeItPass
```
Give Acme's IT the server hostname, the hub name (`Acme-Corp`), and this password — they connect with the Server Manager or `vpncmd` in hub-admin mode.
- **Tip:** Use `AdminOptionList` / `AdminOptionSet` to cap what a hub admin can change (max users, session limits, etc.), so a delegated admin can't over-provision.

---

## Appendix A. Command Reference

This appendix lists every `vpncmd` command grouped by module, with its authoritative one-line summary. Unless noted, commands run in **VPN Server management mode**:

```
vpncmd <host> /SERVER /PASSWORD:<adminpw> /CMD <Command> <args...>
```

Hub-scoped commands (Virtual Hub, Users & Groups, Security Policy, SecureNAT, Sessions, etc.) additionally need `/ADMINHUB:<HubName>`, or you select the hub first with `Hub <HubName>`. The final three groups run in different modes: **Cert Tools** in `/TOOLS` mode, and **VPN Client** in `/CLIENT` mode. Omit `/CMD` to enter an interactive prompt.

### A.1 Server & Farm

| Command | What it does |
|---|---|
| `ServerInfoGet` | Get server information |
| `ServerStatusGet` | Get Current Server Status |
| `ServerPasswordSet` | Set VPN Server Administrator Password |
| `ServerCipherGet` | Get the Encrypted Algorithm Used for VPN Communication |
| `ServerCipherSet` | Set the Encrypted Algorithm Used for VPN Communication |
| `KeepEnable` | Enable the Keep Alive Internet Connection Function |
| `KeepDisable` | Disable the Keep Alive Internet Connection Function |
| `KeepSet` | Set the Keep Alive Internet Connection Function |
| `KeepGet` | Get the Keep Alive Internet Connection Function |
| `Caps` | Get List of Server Functions/Capability |
| `ConfigGet` | Get the current configuration of the VPN Server |
| `ConfigSet` | Write Configuration File to VPN Server |
| `Flush` | Save All Volatile Data of VPN Server / Bridge to the Configuration File |
| `Reboot` | Reboot VPN Server Service |
| `Crash` | Raise an error on the VPN Server / Bridge to terminate the process forcefully |
| `Debug` | Execute a Debug Command |
| `Check` | Check whether ComfyConnect VPN Operation is Possible |
| `About` | Display the version information |
| `ClusterSettingGet` | Get Clustering Configuration of Current VPN Server |
| `ClusterSettingStandalone` | Set VPN Server Type as Standalone |
| `ClusterSettingController` | Set VPN Server Type as Cluster Controller |
| `ClusterSettingMember` | Set VPN Server Type as Cluster Member |
| `ClusterMemberList` | Get List of Cluster Members |
| `ClusterMemberInfoGet` | Get Cluster Member Information |
| `ClusterMemberCertGet` | Get Cluster Member Certificate |
| `ClusterConnectionStatusGet` | Get Connection Status to Cluster Controller |
| `LicenseAdd` | Add License Key Registration |
| `LicenseDel` | Delete Registered License |
| `LicenseList` | Get List of Registered Licenses |
| `LicenseStatus` | Get License Status of Current VPN Server |
| `DynamicDnsGetStatus` | Show the Current Status of Dynamic DNS Function |
| `DynamicDnsSetHostname` | Set the Dynamic DNS Hostname |
| `VpnAzureGetStatus` | Show the current status of VPN Azure function |
| `VpnAzureSetEnable` | Enable / Disable VPN Azure Function |

> Note: In the ComfyConnect deploy, `DynamicDns*`, `VpnAzure*`, and Keep-Alive are disabled by default (no phone-home).

### A.2 Virtual Hub

| Command | What it does |
|---|---|
| `HubCreate` | Create New Virtual Hub |
| `HubCreateDynamic` | Create New Dynamic Virtual Hub (For Clustering) |
| `HubCreateStatic` | Create New Static Virtual Hub (For Clustering) |
| `HubDelete` | Delete Virtual Hub |
| `HubSetStatic` | Change Virtual Hub Type to Static Virtual Hub |
| `HubSetDynamic` | Change Virtual Hub Type to Dynamic Virtual Hub |
| `HubList` | Get List of Virtual Hubs |
| `Hub` | Select Virtual Hub to Manage |
| `Online` | Switch Virtual Hub to Online |
| `Offline` | Switch Virtual Hub to Offline |
| `SetStaticNetwork` | Set Virtual Hub static IPv4 network parameters |
| `SetMaxSession` | Set the Max Number of Concurrently Connected Sessions for Virtual Hub |
| `SetHubPassword` | Set Virtual Hub Administrator Password |
| `SetEnumAllow` | Allow Enumeration by Virtual Hub Anonymous Users |
| `SetEnumDeny` | Deny Enumeration by Virtual Hub Anonymous Users |
| `OptionsGet` | Get Options Setting of Virtual Hubs |
| `StatusGet` | Get Current Status of Virtual Hub |
| `AdminOptionList` | Get List of Virtual Hub Administration Options |
| `AdminOptionSet` | Set Values of Virtual Hub Administration Options |
| `ExtOptionList` | Get List of Virtual Hub Extended Options |
| `ExtOptionSet` | Set a Value of Virtual Hub Extended Options |
| `RadiusServerSet` | Set RADIUS Server to use for User Authentication |
| `RadiusServerDelete` | Delete Setting to Use RADIUS Server for User Authentication |
| `RadiusServerGet` | Get Setting of RADIUS Server Used for User Authentication |

### A.3 Users & Groups

| Command | What it does |
|---|---|
| `UserList` | Get List of Users |
| `UserCreate` | Create User |
| `UserSet` | Change User Information |
| `UserDelete` | Delete User |
| `UserGet` | Get User Information |
| `UserAnonymousSet` | Set Anonymous Authentication for User Auth Type |
| `UserPasswordSet` | Set Password Authentication for User Auth Type and Set Password |
| `UserCertSet` | Set Individual Certificate Authentication for User Auth Type and Set Certificate |
| `UserCertGet` | Get Certificate Registered for Individual Certificate Authentication User |
| `UserSignedSet` | Set Signed Certificate Authentication for User Auth Type |
| `UserRadiusSet` | Set RADIUS Authentication for User Auth Type |
| `UserNTLMSet` | Set NT Domain Authentication for User Auth Type |
| `UserExpiresSet` | Set User's Expiration Date |
| `UserPolicySet` | Set User Security Policy |
| `UserPolicyRemove` | Delete User Security Policy |
| `GroupList` | Get List of Groups |
| `GroupCreate` | Create Group |
| `GroupSet` | Set Group Information |
| `GroupDelete` | Delete Group |
| `GroupGet` | Get Group Information and List of Assigned Users |
| `GroupJoin` | Add User to Group |
| `GroupUnjoin` | Delete User from Group |
| `GroupPolicySet` | Set Group Security Policy |
| `GroupPolicyRemove` | Delete Group Security Policy |

### A.4 Security Policy & Access List

| Command | What it does |
|---|---|
| `PolicyList` | Display List of Security Policy Types and Settable Values |
| `AccessList` | Get Access List Rule List |
| `AccessAdd` | Add Access List Rules (IPv4) |
| `AccessAdd6` | Add Access List Rules (IPv6) |
| `AccessAddEx` | Add Extended Access List Rules (IPv4: Delay, Jitter and Packet Loss Generating) |
| `AccessAddEx6` | Add Extended Access List Rules (IPv6: Delay, Jitter and Packet Loss Generating) |
| `AccessDelete` | Delete Rule from Access List |
| `AccessEnable` | Enable Access List Rule |
| `AccessDisable` | Disable Access List Rule |
| `AcList` | Get List of Rule Items of Source IP Address Limit List |
| `AcAdd` | Add Rule to Source IP Address Limit List (IPv4) |
| `AcAdd6` | Add Rule to Source IP Address Limit List (IPv6) |
| `AcDel` | Delete Rule from Source IP Address Limit List |

### A.5 SecureNAT & DHCP

| Command | What it does |
|---|---|
| `SecureNatEnable` | Enable the Virtual NAT and DHCP Server Function (SecureNat Function) |
| `SecureNatDisable` | Disable the Virtual NAT and DHCP Server Function (SecureNat Function) |
| `SecureNatStatusGet` | Get the Operating Status of the Virtual NAT and DHCP Server Function (SecureNat Function) |
| `SecureNatHostGet` | Get Network Interface Setting of Virtual Host of SecureNAT Function |
| `SecureNatHostSet` | Change Network Interface Setting of Virtual Host of SecureNAT Function |
| `NatGet` | Get Virtual NAT Function Setting of SecureNAT Function |
| `NatEnable` | Enable Virtual NAT Function of SecureNAT Function |
| `NatDisable` | Disable Virtual NAT Function of SecureNAT Function |
| `NatSet` | Change Virtual NAT Function Setting of SecureNAT Function |
| `NatTable` | Get Virtual NAT Function Session Table of SecureNAT Function |
| `DhcpGet` | Get Virtual DHCP Server Function Setting of SecureNAT Function |
| `DhcpEnable` | Enable Virtual DHCP Server Function of SecureNAT Function |
| `DhcpDisable` | Disable Virtual DHCP Server Function of SecureNAT Function |
| `DhcpSet` | Change Virtual DHCP Server Function Setting of SecureNAT Function |
| `DhcpTable` | Get Virtual DHCP Server Function Lease Table of SecureNAT Function |

### A.6 Local Bridge

| Command | What it does |
|---|---|
| `BridgeDeviceList` | Get List of Network Adapters Usable as Local Bridge |
| `BridgeList` | Get List of Local Bridge Connection |
| `BridgeCreate` | Create Local Bridge Connection |
| `BridgeDelete` | Delete Local Bridge Connection |

### A.7 Cascade Connections

| Command | What it does |
|---|---|
| `CascadeList` | Get List of Cascade Connections |
| `CascadeCreate` | Create New Cascade Connection |
| `CascadeSet` | Set the Destination for Cascade Connection |
| `CascadeGet` | Get the Cascade Connection Setting |
| `CascadeDelete` | Delete Cascade Connection Setting |
| `CascadeRename` | Change Name of Cascade Connection |
| `CascadeUsernameSet` | Set User Name to Use Connection of Cascade Connection |
| `CascadeAnonymousSet` | Set User Authentication Type of Cascade Connection to Anonymous Authentication |
| `CascadePasswordSet` | Set User Authentication Type of Cascade Connection to Password Authentication |
| `CascadeCertSet` | Set User Authentication Type of Cascade Connection to Client Certificate Authentication |
| `CascadeCertGet` | Get Client Certificate to Use for Cascade Connection |
| `CascadeEncryptEnable` | Enable Encryption when Communicating by Cascade Connection |
| `CascadeEncryptDisable` | Disable Encryption when Communicating by Cascade Connection |
| `CascadeCompressEnable` | Enable Data Compression when Communicating by Cascade Connection |
| `CascadeCompressDisable` | Disable Data Compression when Communicating by Cascade Connection |
| `CascadeProxyNone` | Specify Direct TCP/IP Connection as the Connection Method of Cascade Connection |
| `CascadeProxyHttp` | Set Connection Method of Cascade Connection to be via an HTTP Proxy Server |
| `CascadeProxySocks` | Set Connection Method of Cascade Connection to be via a SOCKS4 Proxy Server |
| `CascadeProxySocks5` | Set Connection Method of Cascade Connection to be via a SOCKS5 Proxy Server |
| `CascadeHttpHeaderAdd` | Add a custom value in the HTTP header sent to the proxy server |
| `CascadeHttpHeaderDelete` | Delete a custom value in the HTTP header sent to the proxy server |
| `CascadeHttpHeaderGet` | Get the list of custom values in the HTTP header sent to the proxy server |
| `CascadeServerCertEnable` | Enable Cascade Connection Server Certificate Verification Option |
| `CascadeServerCertDisable` | Disable Cascade Connection Server Certificate Verification Option |
| `CascadeDefaultCAEnable` | Enable Trust System Certificate Store Option |
| `CascadeServerCertSet` | Set the Server Individual Certificate for Cascade Connection |
| `CascadeServerCertDelete` | Delete the Server Individual Certificate for Cascade Connection |
| `CascadeServerCertGet` | Get the Server Individual Certificate for Cascade Connection |
| `CascadeDetailSet` | Set Advanced Settings for Cascade Connection |
| `CascadePolicySet` | Set Cascade Connection Session Security Policy |
| `CascadeStatusGet` | Get Current Cascade Connection Status |
| `CascadeOnline` | Switch Cascade Connection to Online Status |
| `CascadeOffline` | Switch Cascade Connection to Offline Status |

### A.8 Virtual Layer-3 Switch

| Command | What it does |
|---|---|
| `RouterList` | Get List of Virtual Layer 3 Switches |
| `RouterAdd` | Define New Virtual Layer 3 Switch |
| `RouterDelete` | Delete Virtual Layer 3 Switch |
| `RouterStart` | Start Virtual Layer 3 Switch Operation |
| `RouterStop` | Stop Virtual Layer 3 Switch Operation |
| `RouterIfList` | Get List of Interfaces Registered on the Virtual Layer 3 Switch |
| `RouterIfAdd` | Add Virtual Interface to Virtual Layer 3 Switch |
| `RouterIfDel` | Delete Virtual Interface of Virtual Layer 3 Switch |
| `RouterTableList` | Get List of Routing Tables of Virtual Layer 3 Switch |
| `RouterTableAdd` | Add Routing Table Entry for Virtual Layer 3 Switch |
| `RouterTableDel` | Delete Routing Table Entry of Virtual Layer 3 Switch |

### A.9 Listeners & Protocols

| Command | What it does |
|---|---|
| `ListenerList` | Get List of TCP Listeners |
| `ListenerCreate` | Create New TCP Listener |
| `ListenerDelete` | Delete TCP Listener |
| `ListenerEnable` | Begin TCP Listener Operation |
| `ListenerDisable` | Stop TCP Listener Operation |
| `PortsUDPGet` | Lists the UDP ports that the server is listening on |
| `PortsUDPSet` | Sets the UDP ports that the server should listen on |
| `ProtoOptionsGet` | Lists the options for the specified protocol |
| `ProtoOptionsSet` | Sets an option's value for the specified protocol |
| `IPsecEnable` | Enable or Disable IPsec VPN Server Function |
| `IPsecGet` | Get the Current IPsec VPN Server Settings |
| `EtherIpClientAdd` | Add New EtherIP / L2TPv3 over IPsec Client Setting to Accept EtherIP / L2TPv3 Client Devices |
| `EtherIpClientDelete` | Delete an EtherIP / L2TPv3 over IPsec Client Setting |
| `EtherIpClientList` | Get the Current List of EtherIP / L2TPv3 Client Device Entry Definitions |
| `OpenVpnMakeConfig` | Generate a Sample Setting File for OpenVPN Client |
| `VpnOverIcmpDnsEnable` | Enable / Disable the VPN over ICMP / VPN over DNS Server Function |
| `VpnOverIcmpDnsGet` | Get Current Setting of the VPN over ICMP / VPN over DNS Function |
| `WgkEnum` | List the WireGuard keys |
| `WgkAdd` | Add a WireGuard key |
| `WgkDelete` | Delete a WireGuard key |

### A.10 Certificates & CRL

| Command | What it does |
|---|---|
| `ServerCertGet` | Get SSL Certificate of VPN Server |
| `ServerKeyGet` | Get SSL Certificate Private Key of VPN Server |
| `ServerCertSet` | Set SSL Certificate and Private Key of VPN Server |
| `ServerCertRegenerate` | Generate New Self-Signed Certificate with Specified CN (Common Name) and Register on VPN Server |
| `CAList` | Get List of Trusted CA Certificates |
| `CAAdd` | Add Trusted CA Certificate |
| `CADelete` | Delete Trusted CA Certificate |
| `CAGet` | Get Trusted CA Certificate |
| `CrlList` | Get List of Certificates Revocation List |
| `CrlAdd` | Add a Revoked Certificate |
| `CrlDel` | Delete a Revoked Certificate |
| `CrlGet` | Get a Revoked Certificate |

### A.11 Logging & Syslog

| Command | What it does |
|---|---|
| `LogGet` | Get Log Save Setting of Virtual Hub |
| `LogEnable` | Enable Security Log or Packet Log |
| `LogDisable` | Disable Security Log or Packet Log |
| `LogSwitchSet` | Set Log File Switch Cycle |
| `LogPacketSaveType` | Set Save Contents and Type of Packet to Save to Packet Log |
| `LogFileList` | Get List of Log Files |
| `LogFileGet` | Download Log file |
| `SyslogEnable` | Set syslog Send Function |
| `SyslogDisable` | Disable syslog Send Function |
| `SyslogGet` | Get syslog Send Function |

### A.12 Sessions & Connections

| Command | What it does |
|---|---|
| `SessionList` | Get List of Connected Sessions |
| `SessionGet` | Get Session Information |
| `SessionDisconnect` | Disconnect Session |
| `ConnectionList` | Get List of TCP Connections Connecting to the VPN Server |
| `ConnectionGet` | Get Information of TCP Connections Connecting to the VPN Server |
| `ConnectionDisconnect` | Disconnect TCP Connections Connecting to the VPN Server |
| `MacTable` | Get the MAC Address Table Database |
| `MacDelete` | Delete MAC Address Table Entry |
| `IpTable` | Get the IP Address Table Database |
| `IpDelete` | Delete IP Address Table Entry |

### A.13 Cert Tools (vpncmd /TOOLS)

Run these in Tools mode: `vpncmd /TOOLS /CMD <Command> ...`. They operate locally and need no server connection.

| Command | What it does |
|---|---|
| `MakeCert` | Create New X.509 Certificate and Private Key (1024 bit) |
| `MakeCert2048` | Create New X.509 Certificate and Private Key (2048 bit) |
| `GenX25519` | Create new X25519 keypair |
| `GetPublicX25519` | Retrieve public X25519 key from a private one |
| `TrafficClient` | Run Network Traffic Speed Test Tool in Client Mode |
| `TrafficServer` | Run Network Traffic Speed Test Tool in Server Mode |
| `Check` | Check whether ComfyConnect VPN Operation is Possible |

### A.14 VPN Client (vpncmd /CLIENT)

These manage a local ComfyConnect **client** service (outbound connection profiles), not the server. Run in Client mode: `vpncmd <host> /CLIENT /CMD <Command> ...`.

| Command | What it does |
|---|---|
| `VersionGet` | Get Version Information of VPN Client Service |
| `PasswordSet` | Set the password to connect to the VPN Client service |
| `PasswordGet` | Get Password Setting to Connect to VPN Client Service |
| `RemoteEnable` | Allow Remote Management of VPN Client Service |
| `RemoteDisable` | Deny Remote Management of VPN Client Service |
| `NicList` | Get List of Virtual Network Adapters |
| `NicCreate` | Create New Virtual Network Adapter |
| `NicDelete` | Delete Virtual Network Adapter |
| `NicUpgrade` | Upgrade Virtual Network Adapter Device Driver |
| `NicGetSetting` | Get Virtual Network Adapter Setting |
| `NicSetSetting` | Change Virtual Network Adapter Setting |
| `NicEnable` | Enable Virtual Network Adapter |
| `NicDisable` | Disable Virtual Network Adapter |
| `AccountList` | Get List of VPN Connection Settings |
| `AccountCreate` | Create New VPN Connection Setting |
| `AccountSet` | Set the VPN Connection Setting Connection Destination |
| `AccountGet` | Get Setting of VPN Connection Setting |
| `AccountDelete` | Delete VPN Connection Setting |
| `AccountRename` | Change VPN Connection Setting Name |
| `AccountUsernameSet` | Set User Name of User to Use Connection of VPN Connection Setting |
| `AccountAnonymousSet` | Set User Authentication Type of VPN Connection Setting to Anonymous Authentication |
| `AccountPasswordSet` | Set User Authentication Type of VPN Connection Setting to Password Authentication |
| `AccountCertSet` | Set User Authentication Type of VPN Connection Setting to Client Certificate Authentication |
| `AccountCertGet` | Get Client Certificate to Use for the Connection |
| `AccountSecureCertSet` | Set User Authentication Type of VPN Connection Setting to Smart Card Authentication |
| `AccountEncryptEnable` | Enable Encryption when Communicating by VPN Connection Setting |
| `AccountEncryptDisable` | Disable Encryption when Communicating by VPN Connection Setting |
| `AccountCompressEnable` | Enable Data Compression when Communicating by VPN Connection Setting |
| `AccountCompressDisable` | Disable Data Compression when Communicating by VPN Connection Setting |
| `AccountProxyNone` | Specify Direct TCP/IP Connection as the Connection Method of VPN Connection Setting |
| `AccountProxyHttp` | Set Connection Method of VPN Connection Setting to be via an HTTP Proxy Server |
| `AccountProxySocks` | Set Connection Method of VPN Connection Setting to be via a SOCKS4 Proxy Server |
| `AccountProxySocks5` | Set Connection Method of VPN Connection Setting to be via a SOCKS5 Proxy Server |
| `AccountHttpHeaderAdd` | Add a custom value in the HTTP header sent to the proxy server |
| `AccountHttpHeaderDelete` | Delete a custom value in the HTTP header sent to the proxy server |
| `AccountHttpHeaderGet` | Get the list of custom values in the HTTP header sent to the proxy server |
| `AccountServerCertEnable` | Enable VPN Connection Setting Server Certificate Verification Option |
| `AccountServerCertDisable` | Disable VPN Connection Setting Server Certificate Verification Option |
| `AccountRetryOnServerCertEnable` | Enable VPN connection retry if server certificate is invalid |
| `AccountRetryOnServerCertDisable` | Disable VPN connection retry if server certificate is invalid |
| `AccountDefaultCAEnable` | Enable Trust System Certificate Store Option |
| `AccountServerCertSet` | Set Server Individual Certificate for VPN Connection Setting |
| `AccountServerCertDelete` | Delete Server Individual Certificate for VPN Connection Setting |
| `AccountServerCertGet` | Get Server Individual Certificate for VPN Connection Setting |
| `AccountDetailSet` | Set Advanced Settings for VPN Connection Setting |
| `AccountNicSet` | Set Virtual Network Adapter for VPN Connection Setting to Use |
| `AccountStatusShow` | Set Connection Status and Error Screen to Display when Connecting to VPN Server |
| `AccountStatusHide` | Set Connection Status and Error Screen to be Hidden when Connecting to VPN Server |
| `AccountRetrySet` | Set Interval between Connection Retries for Connection Failures or Disconnections |
| `AccountStartupSet` | Set VPN Connection Setting as Startup Connection |
| `AccountStartupRemove` | Remove Startup Connection of VPN Connection Setting |
| `AccountConnect` | Start Connection to VPN Server using VPN Connection Setting |
| `AccountDisconnect` | Disconnect VPN Connection Setting During Connection |
| `AccountStatusGet` | Get Current VPN Connection Setting Status |
| `AccountExport` | Export VPN Connection Setting |
| `AccountImport` | Import VPN Connection Setting |
| `CertList` | Get List of Trusted CA Certificates |
| `CertAdd` | Add Trusted CA Certificate |
| `CertDelete` | Delete Trusted CA Certificate |
| `CertGet` | Get Trusted CA Certificate |
| `SecureList` | Get List of Usable Smart Card Types |
| `SecureSelect` | Select the Smart Card Type to Use |
| `SecureGet` | Get ID of Smart Card Type to Use |

> Gotcha: The `/CLIENT` and `/TOOLS` groups run against a local client/tools process, not the ComfyConnect VPN Server. Employees on OpenVPN, L2TP/IPsec, or SSTP do not need any of these — they only matter if you deliberately run the SoftEther client on a machine.

---

## About this product

ComfyConnect VPN is a white-label distribution of the open-source [SoftEther VPN](https://github.com/SoftEtherVPN/SoftEtherVPN) engine, licensed under the Apache License 2.0. "SoftEther" is a trademark of its respective owner and is referenced only to attribute the upstream project. See the NOTICE file for full attribution.
