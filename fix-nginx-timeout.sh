#!/bin/bash
# Fix nginx proxy timeout for n8n webhook
# Run on your Hostinger VPS: sudo bash fix-nginx-timeout.sh

echo "=== Nginx Timeout Fix for n8n ==="
echo ""

# Find all nginx config files that mention n8n or the webhook
echo "Searching for nginx config files..."
CONFIGS=$(grep -rl "n8n\|srv923061\|proxy_pass" /etc/nginx/ 2>/dev/null)

if [ -z "$CONFIGS" ]; then
    echo "No nginx config files found with n8n settings."
    echo "Listing all nginx configs:"
    ls -la /etc/nginx/sites-available/ 2>/dev/null
    ls -la /etc/nginx/sites-enabled/ 2>/dev/null
    ls -la /etc/nginx/conf.d/ 2>/dev/null
    echo ""
    echo "Try running: grep -r 'proxy_pass' /etc/nginx/"
    exit 1
fi

echo "Found config files:"
echo "$CONFIGS"
echo ""

for CONFIG in $CONFIGS; do
    echo "--- Processing: $CONFIG ---"

    # Check if timeout is already set
    if grep -q "proxy_read_timeout 300" "$CONFIG"; then
        echo "  Already has 300s timeout. Skipping."
        continue
    fi

    # Backup
    cp "$CONFIG" "${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    echo "  Backup created."

    # Add timeout settings after proxy_pass lines
    sed -i '/proxy_pass/a\        proxy_read_timeout 300s;\n        proxy_connect_timeout 300s;\n        proxy_send_timeout 300s;' "$CONFIG"

    echo "  Timeout settings added (300s)."
done

echo ""
echo "Testing nginx config..."
nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "Config OK. Reloading nginx..."
    systemctl reload nginx
    echo "Done! Nginx timeout is now 300 seconds (5 minutes)."
else
    echo ""
    echo "ERROR: nginx config test failed!"
    echo "Restoring backups..."
    for CONFIG in $CONFIGS; do
        BACKUP=$(ls -t "${CONFIG}.bak."* 2>/dev/null | head -1)
        if [ -n "$BACKUP" ]; then
            cp "$BACKUP" "$CONFIG"
            echo "  Restored: $CONFIG"
        fi
    done
    systemctl reload nginx
    echo "Backups restored."
fi
