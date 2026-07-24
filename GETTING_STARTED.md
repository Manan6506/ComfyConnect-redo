<p align="center"><img src="resources/comfyconnect-vpn.svg" width="72" alt="ComfyConnect"></p>

> 📘 **Full documentation:** the complete [ComfyConnect User Manual & Administrator Guide](docs/USER_MANUAL.md) covers every feature, all four admin tools, and a full command reference.

# ComfyConnect VPN — Getting Started

Everything you need to stand up a secure work-from-home VPN for a business client and
get their team connected. Three steps: **deploy → open the console → onboard employees.**

---

## 1. Deploy the server (one command)

On any Linux server with Docker installed:

```bash
git clone https://github.com/Manan6506/ComfyConnect-redo
cd ComfyConnect-redo/deploy
./setup.sh
```

That builds ComfyConnect, starts the VPN server, and turns on the connection protocols
(OpenVPN, L2TP/IPsec, SSTP). When it finishes it prints your **Admin Console URL** and a
generated **admin password** — save them.

> Point a DNS name (e.g. `vpn.acmecorp.com`) at this server, or use its public IP. Open
> the firewall/security-group for TCP **443, 992, 5555** and UDP **1194, 500, 4500**.

## 2. Open the Admin Console

Browse to the console URL from step 1 and sign in with the admin password:

```
https://YOUR-SERVER:5555/admin/
```

You get a live dashboard: **Overview** (sessions, traffic, uptime), **Employees**,
**Live Sessions**, and **Virtual Hubs**. (Prefer a native app? The Windows
**Server Manager** GUI works too — see [WINDOWS_BUILD.md](WINDOWS_BUILD.md).)

## 3. Onboard employees

**From the console:** *Employees → Add employee* — enter a username and password. Done.

**Or in bulk / with ready-to-send cards:**

```bash
cd onboarding
SERVER=https://YOUR-SERVER:5555 ADMIN_PW=<admin-password> HUB=ComfyConnect \
  ./add-employee.sh jane.doe
```

This creates the account and writes an `employee-jane.doe/` folder containing:
- **CONNECTION-CARD.txt** — server, username, password, and how to connect
- **openvpn-profiles.zip** — the OpenVPN profile to import

## How employees connect

They don't need any ComfyConnect-specific software — pick whichever is easiest:

| Method | What the employee does |
|--------|------------------------|
| **OpenVPN** (recommended) | Install the free OpenVPN Connect app, import the profile, enter username/password |
| **Windows / macOS built-in VPN** | Add an L2TP/IPsec VPN: server address, the pre-shared key, username/password |
| **SSTP** | Built into Windows; connect to the server address with username/password |

---

## The business model

- One ComfyConnect server can host many **Virtual Hubs** — use one hub per client company,
  fully isolated from each other.
- Charge per company or per seat. Provision employees in seconds from the console.
- Nothing phones home: DDNS, VPN Azure, NAT-traversal, keep-alive, and update checks are
  all disabled by default, so a client's server only talks to that client's employees.

## Under the hood

ComfyConnect is a white-label of the open-source [SoftEther VPN](https://github.com/SoftEtherVPN/SoftEtherVPN)
engine (Apache License 2.0). See [NOTICE](NOTICE) for attribution.
