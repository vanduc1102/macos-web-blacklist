# Web Blacklist 🛡️ (macOS Apple Silicon Native)

A lightweight, native macOS menu bar (system tray) application built for Apple Silicon (M-series chips). It blocks distracting social networks and custom websites at the system level using `/etc/hosts`, and features **Touch ID fingerprint authentication** to easily unlock websites when needed.

---

## ✨ Features

- 🍏 **Apple Silicon Native (arm64)**: Optimized for M1, M2, M3, M4 Macs with minimal memory and CPU footprint.
- 🔒 **System Tray (Menu Bar) Status**:
  - Live icon in the macOS menu bar indicating current state (Locked / Unlocked).
  - Click to open the dashboard popover or right-click for quick actions.
- 👆 **Touch ID Fingerprint Unlocking**:
  - Easily unblock websites with a single touch of your finger using Apple's `LocalAuthentication` framework.
  - Device passcode fallback if Touch ID is temporarily unavailable.
- 🚫 **System-Level Blocking via `/etc/hosts`**:
  - Null routes domains to `0.0.0.0` (IPv4) and `::1` (IPv6) with zero network latency.
  - Automatically flushes macOS DNS cache (`dscacheutil -flushcache`) upon locking and unlocking.
  - **Non-destructive**: Preserves all existing `/etc/hosts` entries inside clean, demarcated markers (`# === BEGIN WEB-BLACKLIST MANAGED BLOCK ===`).
- 🌐 **Built-in Social Network Presets (External JSON Config)**:
  - Preset websites are defined in [`Resources/sites.json`](file:///Users/ducnguyen/Workspace/personal/web-blacklist/Resources/sites.json), making them easily readable, editable, and customizable without touching Swift code!
  - Includes presets for:
    - Facebook & Messenger
    - Instagram
    - Threads
    - X (Twitter)
    - TikTok
    - YouTube
    - Reddit
    - LinkedIn
    - Pinterest
    - Twitch
    - Discord
    - Distraction news / classifieds sites (e.g. `vnexpress.net`, `genk.vn`, `chotot.com`)
- ➕ **Custom Website Management**:
  - Add any domain or URL (automatically normalizes bare domains and handles `www.` subdomains).
  - Toggle individual websites or all websites with one click.
- ⏱️ **Auto-Lock Productivity Timer**:
  - Option to automatically re-lock websites after 5 minutes, 15 minutes, 30 minutes, or 1 hour after unlocking with Touch ID.
- 🚀 **Auto-Start on Login & Machine Restart**:
  - Automatically launches whenever you log in or restart your Mac.
  - Can be toggled on/off in the popover dashboard or right-click context menu.
  - Setup script ensures `/etc/hosts` write access persists seamlessly across system restarts.

---

## 🚀 Quick Start

### 1. One-Time Setup for Touch ID & Auto-Start on Restart
To enable Touch ID to modify `/etc/hosts` instantly and configure auto-start when you log in or after your machine restarts:

```bash
make setup
# OR: sudo ./scripts/setup-permissions.sh
```

> **Note:** This configures `/etc/hosts` write permissions, enables Touch ID for sudo, installs a boot hook so permissions persist across macOS restarts, and registers the app to launch at login.

### 2. Build the Application
```bash
make build
```

This compiles a release arm64 binary and bundles it into `WebBlacklist.app`.

### 3. Launch or Install
- **Run directly**:
  ```bash
  make run
  # OR: open WebBlacklist.app
  ```
- **Install to `/Applications`**:
  ```bash
  make install
  ```

---

## 🖥️ How It Works

1. **Locking (Blocking Sites)**:
   - When you click **"Lock Blacklist Now"**, the app writes the enabled blocked domains into `/etc/hosts` between managed markers and flushes the macOS DNS cache.
   - The menu bar icon changes to a locked shield 🔒.
   - Any attempt to access the blacklisted domains (in Safari, Chrome, Firefox, etc.) will immediately fail to resolve.

2. **Unlocking with Touch ID**:
   - Click the menu bar icon and press **"Unlock with Touch ID"** (or use the right-click menu).
   - Touch your finger on the Touch ID sensor on your Mac keyboard.
   - Upon verification, the app immediately removes the blocked block from `/etc/hosts`, flushes DNS cache, and switches to the unlocked state 🔓.
   - If an auto-lock duration is set (e.g. 15 minutes), the countdown timer begins, automatically re-locking when expired.

---

## 🛠️ Project Structure

```
├── Package.swift                  # Swift Package Manager definition (macOS 13+)
├── Makefile                       # Convenient build & install targets
├── Sources/
│   └── WebBlacklist/
│       ├── main.swift             # Main application entry point
│       ├── AppDelegate.swift      # Application lifecycle & accessory mode
│       ├── StatusBarController.swift # NSStatusItem & menu bar popover manager
│       ├── Models/
│       │   └── BlockedSite.swift  # Data models and domain normalization
│       ├── Services/
│       │   ├── HostsManager.swift # /etc/hosts parser, updater, & DNS flusher
│       │   ├── TouchIDManager.swift # LocalAuthentication biometric handler
│       │   └── BlacklistStore.swift # Reactive state store & auto-lock timer
│       └── Views/
│           ├── PopoverView.swift  # Main dashboard UI
│           ├── SiteRowView.swift  # Individual site toggle row
│           ├── AddSiteView.swift  # Custom domain entry form
│           └── PermissionsBannerView.swift # One-click permission setup banner
├── Resources/
│   ├── Info.plist                 # macOS bundle metadata (LSUIElement=true)
│   └── AppIcon.icns               # Custom native application icon
└── scripts/
    ├── build-app.sh               # Release compiler and bundle packager
    └── setup-permissions.sh       # One-time /etc/hosts & Touch ID configuration
```

---

## 📄 License
MIT License
# macos-web-blacklist
