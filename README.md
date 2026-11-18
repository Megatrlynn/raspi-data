# PiMobile (MOAP): Raspberry Pi Remote Management Mobile System

**PiMobile** is a fast, secure, and reliable mobile platform designed to manage and control Raspberry Pi devices over your local network and securely over the internet via Tailscale WireGuard mesh networking.

---

## 🌟 Core Features

- ⚡ **Real-Time Hardware Telemetry**: Live 60 FPS dashboard tracking CPU load per core, SoC temperature (°C), throttling flags (undervoltage, frequency capping), RAM usage, disk usage, and network throughput (KB/s).
- 💻 **Interactive SSH Shell**: Full-featured PTY terminal emulator powered by `dartssh2` and `xterm`, featuring a custom mobile programmer toolbar (`ESC`, `TAB`, `CTRL`, `ALT`, `^C`, pipes, arrows).
- 🖥️ **Remote GUI Desktop Access**: Direct access to the Raspberry Pi OS desktop UI (WayVNC for Bookworm/Wayland and RealVNC/TigerVNC for X11) with low-latency touch controls.
- 🔒 **Ironclad Security**:
  - Zero open router ports required.
  - End-to-end encrypted WireGuard mesh networking via Tailscale.
  - Token-authenticated REST & WebSocket endpoints with rate-limiting.
  - Secrets stored inside iOS Keychain and Android KeyStore via `flutter_secure_storage`.
- 🔄 **Smart Connection Failover**: Automatically connects to the local LAN IP (`.local` / `192.168.x.x`) for sub-millisecond latency when home, and falls back to Tailscale (`100.x.y.z`) anywhere on cellular or public Wi-Fi.

---

## 📁 Repository Structure

```
MOAP/
├── pi-agent/                  # Lightweight Raspberry Pi Daemon (Python 3 Async)
│   ├── main.py                # FastAPI REST & WebSocket server
│   ├── metrics.py             # Hardware & SoC telemetry engine
│   ├── desktop.py             # WayVNC / RealVNC manager & WebSocket bridge
│   ├── discovery.py           # mDNS / Zeroconf LAN broadcaster
│   ├── requirements.txt       # Python dependencies
│   ├── pi-agent.service       # systemd unit file for 24/7 reliability
│   └── install.sh             # One-step automated installer
│
├── mobile_app/                # Flutter Cross-Platform Mobile Client
│   ├── pubspec.yaml           # App dependencies
│   └── lib/
│       ├── main.dart          # Entry point & Cyber Dark theme
│       ├── models/            # Device & Telemetry data models
│       ├── services/          # API, SSH, and secure storage services
│       ├── providers/         # Riverpod reactive state managers
│       ├── screens/           # Dashboard, Terminal, Desktop, and Settings
│       └── widgets/           # Gauge cards, status indicators, accessory bars
│
└── TAILSCALE_GUIDE.md         # Guide for configuring secure internet access
```

---

## 🚀 Quick Start Guide

### 1. Set Up the Raspberry Pi Daemon (`pi-agent`)

Copy the `pi-agent/` directory to your Raspberry Pi, or clone this repository directly on your Pi:

```bash
cd pi-agent
chmod +x install.sh
sudo ./install.sh
```

The installer will:
1. Install system dependencies (`python3-venv`, `avahi-daemon`).
2. Create an isolated virtual environment in `/opt/pi-agent/venv`.
3. Check for or assist in setting up **Tailscale**.
4. Generate a secure random authentication token.
5. Install and enable `pi-agent.service` under `systemd` (auto-starts on boot and restarts on failure).

Save the **Authentication Token** printed at the end of installation.

---

### 2. Configure Internet Access (Tailscale)

Follow the instructions in [TAILSCALE_GUIDE.md](file:///c:/Users/r.igabineza/Downloads/Other/MOAP/TAILSCALE_GUIDE.md):
1. Install Tailscale on your Raspberry Pi: `sudo tailscale up`
2. Install Tailscale on your iOS or Android phone and log in.
3. Note your Pi's Tailscale IPv4 address (`100.x.y.z`).

---

### 3. Run the Flutter Mobile Application

Inside `mobile_app/`:

```bash
cd mobile_app
flutter pub get
flutter run
```

Add your device in **Settings**:
- **Name**: e.g. `Home Pi 5`
- **Local LAN Host**: `raspberrypi.local` or your Pi's local IP (e.g. `192.168.1.100`)
- **Tailscale Mesh IP**: Your Pi's `100.x.y.z` address
- **Auth Token**: The token generated during `sudo ./install.sh`
- **SSH Username & Password**: Your Pi credentials (default user is usually `pi` or custom created)

Tap **Test Connection**, then tap **Save**!
