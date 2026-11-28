# Dashboard — Installation sur le VPS

## Architecture

```
nginx (port 80)  →  uvicorn/FastAPI (127.0.0.1:8000)
systemd : market-regime-web.service
```

## 1. Mettre à jour le venv (après le déploiement CD)

```bash
cd /opt/market-regime
./install_server.sh --no-cron --no-test-run
```

## 2. Créer le service systemd

```bash
sudo tee /etc/systemd/system/market-regime-web.service > /dev/null << 'EOF'
[Unit]
Description=market-regime dashboard
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/opt/market-regime
ExecStart=/opt/market-regime/dashboard/start.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable market-regime-web
sudo systemctl start market-regime-web
sudo systemctl status market-regime-web
```

## 3. Configurer nginx

```bash
sudo tee /etc/nginx/sites-available/market-regime > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;          # remplacer par ton domaine si tu en as un

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /static/ {
        alias /opt/market-regime/dashboard/static/;
        expires 1d;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/market-regime /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 4. Vérification

```bash
# Service en marche
sudo systemctl status market-regime-web

# Réponse locale
curl -s http://127.0.0.1:8000/ | head -5

# Depuis l'extérieur
curl -s http://62.238.63.39/ | head -5
```

## Redémarrage après déploiement CD

Ajouter dans `.github/workflows/deploy.yml`, à la fin du step SSH :

```bash
sudo systemctl restart market-regime-web
```

Et autoriser `deploy` à redémarrer ce service sans mot de passe :

```bash
echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart market-regime-web' \
  | sudo tee /etc/sudoers.d/market-regime-web
```
