#!/usr/bin/env bash
set -e

echo "🔐 Configuring permissions for Web Blacklist..."

if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This setup script needs superuser permissions. Running with sudo..."
    exec sudo "$0" "$@"
fi

# Ensure /etc/hosts is writable by the admin group
echo "👉 Setting /etc/hosts group to 'admin' with read-write permissions (chmod 664)..."
chgrp admin /etc/hosts
chmod 664 /etc/hosts

# Optional: Enable Touch ID for sudo if not already enabled
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

# Flush DNS cache
dscacheutil -flushcache

echo ""
echo "🎉 Setup complete! Web Blacklist can now lock and unlock /etc/hosts with Touch ID instantly without entering a password every time."
