#!/bin/bash

# Использование: curl -sSL url | DOMAIN=example.com bash
# Или: curl -sSL url | DOMAIN=example.com ROOT=/custom/path bash

if [ -z "$DOMAIN" ]; then
    echo "Error: DOMAIN variable is required"
    echo "Usage: curl -sSL script-url | DOMAIN=example.com bash"
    echo "Optional: curl -sSL script-url | DOMAIN=example.com ROOT=/custom/path bash"
    exit 1
fi

ROOT_PATH=${ROOT:-/var/www/$DOMAIN}

echo "Setting up nginx config for $DOMAIN"
echo "Root directory: $ROOT_PATH"

# Создаём директорию если её нет
sudo mkdir -p $ROOT_PATH

# Создаём конфиг
sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null << EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name $DOMAIN;
    
    root $ROOT_PATH;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log /var/log/nginx/$DOMAIN.error.log;
}
EOF

# Создаём симлинк
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Проверяем конфиг
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx config is valid"
    sudo systemctl reload nginx
    echo "✓ Nginx reloaded"
    echo ""
    echo "Next steps:"
    echo "1. Put your files in $ROOT_PATH"
    echo "2. Run: sudo certbot --nginx -d $DOMAIN"
else
    echo "✗ Nginx config test failed"
    exit 1
fi