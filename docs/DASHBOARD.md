# Dashboard : installation sur le VPS

Prototype : uvicorn écoute directement sur le port 8081, sans nginx. Le port 8000 reste réservé à TrdEsk.

## Architecture

```
navigateur  →  uvicorn / FastAPI (0.0.0.0:8081)
systemd : market-regime-web.service (utilisateur deploy)
```

Le dashboard lit les rapports de `/opt/market-regime/reports/`. Il n'écrit rien.

Le CD (`.github/workflows/deploy.yml`) copie le code, met à jour le venv, puis redémarre le service s'il est actif. Il ne crée ni le service, ni la règle sudo, ni la règle de pare-feu : ces trois points se font une seule fois, à la main.

Les commandes ci-dessous se lancent **sur le VPS**, en `root` (`ssh root@62.238.63.39`).

## 1. Service systemd (une seule fois)

```bash
cat > /etc/systemd/system/market-regime-web.service << 'EOF'
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

systemctl daemon-reload
systemctl enable --now market-regime-web
systemctl status market-regime-web --no-pager
```

Vérifier que le port 8081 est libre avant de démarrer : `ss -ltnp | grep 8081`.

## 2. Droit de redémarrage pour le CD (une seule fois)

L'utilisateur `deploy` n'a pas sudo. Cette règle l'autorise à redémarrer ce seul service :

```bash
echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart market-regime-web' > /etc/sudoers.d/market-regime-web
chmod 440 /etc/sudoers.d/market-regime-web
visudo -c
```

Vérification : `sudo -l -U deploy` doit afficher la ligne `/usr/bin/systemctl restart market-regime-web`.

## 3. Accès au dashboard

Le dashboard n'a **aucune authentification**. Ne pas ouvrir le port à tout internet.

Option A, recommandée : n'autoriser que votre adresse IP.

```bash
ufw allow from VOTRE_IP to any port 8081 proto tcp
```

Remplacer VOTRE_IP par votre adresse publique, sans chevrons. Si le pare-feu Hetzner (console cloud) est actif, y ouvrir aussi le port 8081 pour cette adresse.

Option B : tunnel SSH, sans ouvrir le port. Sur le **Mac** :

```bash
ssh -L 8081:127.0.0.1:8081 deploy@62.238.63.39
```

Puis ouvrir `http://127.0.0.1:8081` dans le navigateur. Le port 8081 ne doit alors pas être ouvert dans `ufw`.

## 4. Vérification

Sur le VPS :

```bash
systemctl is-active market-regime-web
curl -s http://127.0.0.1:8081/ | head -5
```

## Après un déploiement

Le CD redémarre le service seul. En cas d'échec, relancer à la main, en root : `systemctl restart market-regime-web`.

## Limites connues (prototype)

- Pas d'authentification ni de HTTPS.
- Pas de validation du format de la date dans `/reports/{date}` (test de traversée de chemin : 404).
- Pas de tests ni de CI pour le dashboard.
