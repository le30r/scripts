#!/bin/bash

# Использование: curl -sSL url | DOMAIN=api.example.com PORT=3000 bash
# Опционально: UPSTREAM=http://custom-upstream:port bash

if [ -z "$DOMAIN" ]; then
    echo "Error: DOMAIN variable is required"
    echo "Usage: curl -sSL script-url | DOMAIN=api.example.com PORT=3000 bash"
    echo "Optional: UPSTREAM=http://service:port (default: http://127.0.0.1:PORT)"
    exit 1
fi

if [ -z "$PORT" ] && [ -z "$UPSTREAM" ]; then
    echo "Error: Either PORT or UPSTREAM variable is required"
    echo "Usage: curl -sSL script-url | DOMAIN=api.example.com PORT=3000 bash"
    exit 1
fi

UPSTREAM=${UPSTREAM:-http://127.0.0.1:$PORT}

echo "Setting up nginx reverse proxy for $DOMAIN"
echo "Upstream: $UPSTREAM"

# Создаём конфиг
sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null << EOF
map \$status \$header_content_type_options {
    204 "";
    default "nosniff";
}

server {
    listen 80;
    listen [::]:80;
    
    server_name $DOMAIN;
    
    location / {
        proxy_pass $UPSTREAM;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Для websockets (если нужно)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        add_header X-Content-Type-Options \$header_content_type_options;
    }
    
    location ~ /.well-known {
        allow all;
    }
    
    client_max_body_size 50m;
    
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
    echo "Next step:"
    echo "  sudo certbot --nginx -d $DOMAIN"
else
    echo "✗ Nginx config test failed"
    exit 1
fi