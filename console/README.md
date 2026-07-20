# ComfyConnect Admin Console

A branded, self-contained web dashboard for managing a ComfyConnect VPN Server:
sign-in, live overview (sessions / traffic / uptime), **employee management**
(add / remove / reset password), **live session monitoring**, and Virtual Hubs.

It talks to the server's JSON-RPC API — no build step, no dependencies.

## Two ways to use it

**1. Built into the server (default).** Every ComfyConnect VPN Server already serves
this console. Just browse to:

```
https://YOUR-SERVER:5555/admin/
```

Sign in with your **server administrator password**. (The browser asks once; the
dashboard loads straight after.)

**2. Hosted separately (multi-server / nicer login).** Host this `console/` folder on
any static web host, or open `index.html` locally. On the sign-in screen click
*"Connect to a different server"*, enter `https://YOUR-SERVER:5555`, and your admin
password.

> When connecting from a different origin, your browser must trust the server's TLS
> certificate first. For production, give the server a real certificate (e.g. Let's
> Encrypt) via the Server Manager or `vpncmd`. For a quick test, open the server URL
> once and accept its self-signed certificate.

## What you can do

| Section | Actions |
|---|---|
| **Overview** | Live KPIs: active sessions, TCP connections, employees, data in/out, uptime; hub status |
| **Employees** | List users per hub, add an employee (username + password), reset password, remove |
| **Live Sessions** | See who is connected (user, source IP, type, traffic, duration); disconnect a session |
| **Virtual Hubs** | Create / delete hubs (one per team or client) |

Authentication uses the server-admin password over the API's `X-VPNADMIN-PASSWORD`
header (or the browser session when embedded). Nothing is stored on disk.
