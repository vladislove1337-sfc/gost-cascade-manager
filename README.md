# GOST Cascade Menu

Emergency independent cascade based on GOST v3:

```text
Client -> RU VPS SOCKS5 -> Foreign VPS -> Internet
```

This does **not** touch Xray, sing-box, 3x-ui, nginx, or existing configs. It creates only:

- `/usr/local/bin/gost`
- `/usr/local/bin/gost-menu`
- `/etc/gost-cascade/`
- `/etc/systemd/system/gost.service`

## Install

```bash
sudo bash gost-menu.sh
```

Or after uploading to GitHub:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/gost-cascade-menu/main/gost-menu.sh)
```

## Recommended setup

### 1. On Foreign VPS

Run menu item:

```text
1) Install FOREIGN exit node: relay+tls
```

or:

```text
2) Install FOREIGN exit node: relay+wss self-signed
```

The script will print the forward URL for the RU server.

### 2. On RU VPS

Run menu item:

```text
3) Install RU middle node: local SOCKS5 -> foreign
```

Paste the foreign forward URL.

### 3. On PC/client

Use SOCKS5:

```text
Host: RU_VPS_IP
Port: 1080
```

Check external IP. It should be the Foreign VPS IP.

## Update from GitHub

Menu item 9 downloads the raw script URL and replaces `/usr/local/bin/gost-menu`.

Before publishing, replace this placeholder in `gost-menu.sh`:

```text
https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/gost-cascade-menu/main/gost-menu.sh
```

## Remove

Menu item 10 removes only this GOST cascade installation.
