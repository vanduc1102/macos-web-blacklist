#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔐 Configuring permissions and auto-start for Web Blacklist..."

if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This setup script needs superuser permissions. Running with sudo..."
    exec sudo "$0" "$@"
fi

# 1. Ensure /etc/hosts is writable by the admin group
echo "👉 Setting /etc/hosts group to 'admin' with read-write permissions (chmod 664)..."
chgrp admin /etc/hosts
chmod 664 /etc/hosts

# 2. Enable Touch ID for sudo if not already enabled
if [ ! -f /etc/pam.d/sudo_local ]; then
    echo "👉 Creating /etc/pam.d/sudo_local to enable Touch ID for sudo..."
    cat << 'EOF' > /etc/pam.d/sudo_local
# sudo_local: enable Touch ID for sudo
auth       sufficient     pam_tid.so
EOF
    chmod 444 /etc/pam.d/sudo_local
    chown root:wheel /etc/pam.d/sudo_local
    echo "✅ Touch ID for sudo enabled!"
else
    if ! grep -q "pam_tid.so" /etc/pam.d/sudo_local; then
        echo "👉 Adding pam_tid.so to /etc/pam.d/sudo_local..."
        echo "auth       sufficient     pam_tid.so" >> /etc/pam.d/sudo_local
        echo "✅ Touch ID for sudo enabled!"
    else
        echo "ℹ️  Touch ID for sudo is already enabled in /etc/pam.d/sudo_local."
    fi
fi

# 3. Ensure permissions persist across reboots / macOS system updates
echo "👉 Setting up system boot hook for /etc/hosts permission persistence..."
HOSTS_DAEMON_PLIST="/Library/LaunchDaemons/com.ducnguyen.webblacklist.hostsfix.plist"
cat << 'EOF' > "$HOSTS_DAEMON_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ducnguyen.webblacklist.hostsfix</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>chmod 664 /etc/hosts &amp;&amp; chgrp admin /etc/hosts</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
chown root:wheel "$HOSTS_DAEMON_PLIST"
chmod 644 "$HOSTS_DAEMON_PLIST"
launchctl load "$HOSTS_DAEMON_PLIST" 2>/dev/null || true
echo "✅ /etc/hosts permissions will persist across machine restarts!"

# 4. Configure auto-start when login or after machine restart
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(eval echo "~$TARGET_USER")
TARGET_UID=$(id -u "$TARGET_USER" 2>/dev/null || echo "501")

APP_PATH="/Applications/WebBlacklist.app"
if [ ! -d "$APP_PATH" ] && [ -d "$DIR/WebBlacklist.app" ]; then
    APP_PATH="$DIR/WebBlacklist.app"
fi

echo "👉 Configuring auto-start at login / restart for user '$TARGET_USER'..."

# A. Register macOS Login Item via System Events
if [ -d "$APP_PATH" ]; then
    sudo -u "$TARGET_USER" osascript -e "tell application \"System Events\"
        delete (every login item whose name is \"Web Blacklist\")
        make login item at end with properties {path:\"$APP_PATH\", hidden:false, name:\"Web Blacklist\"}
    end tell" 2>/dev/null || true
    echo "✅ Registered in macOS Login Items: $APP_PATH"
fi

# B. Install user LaunchAgent for reliable launchd auto-start upon login/restart
USER_LAUNCH_AGENTS="$TARGET_HOME/Library/LaunchAgents"
AGENT_PLIST="$USER_LAUNCH_AGENTS/com.ducnguyen.webblacklist.plist"

mkdir -p "$USER_LAUNCH_AGENTS"
chown "$TARGET_USER" "$USER_LAUNCH_AGENTS"

cat << EOF > "$AGENT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ducnguyen.webblacklist</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-a</string>
        <string>$APP_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF
chown "$TARGET_USER" "$AGENT_PLIST"
chmod 644 "$AGENT_PLIST"

# Bootstrap / reload LaunchAgent for the user's GUI session
sudo -u "$TARGET_USER" launchctl bootout "gui/$TARGET_UID/$AGENT_PLIST" 2>/dev/null || true
sudo -u "$TARGET_USER" launchctl bootstrap "gui/$TARGET_UID" "$AGENT_PLIST" 2>/dev/null || true
echo "✅ Installed and activated LaunchAgent: $AGENT_PLIST"

# 5. Flush DNS cache
dscacheutil -flushcache

echo ""
echo "🎉 Setup complete!"
echo "• Web Blacklist will automatically launch whenever you log in or restart."
echo "• Touch ID and /etc/hosts write permissions will persist across reboots."
