# Déploiement automatique sur le VPS Hetzner

Même principe que TrdEsk : à chaque merge sur `main`, si le CI est vert, le CD copie le projet sur le VPS (`/opt/market-regime`) et met à jour le venv. Le cron s'installe une seule fois à la main.

Les valeurs entre guillemets sont à taper telles quelles, sans chevrons.

## Étape 1. Sur le VPS, en root (une seule fois)

```bash
mkdir -p /opt/market-regime
chown deploy:deploy /opt/market-regime
```

Python 3.12 est déjà installé pour TrdEsk. Vérifier :

```bash
python3.12 --version
```

## Étape 2. Sur le Mac : clé SSH dédiée au CI

```bash
ssh-keygen -t ed25519 -f ~/.ssh/marketregime_ci -N "" -C "marketregime-ci"
cat ~/.ssh/marketregime_ci.pub
```

Sur le VPS, ajouter la ligne affichée (clé publique) au fichier `/home/deploy/.ssh/authorized_keys` de l'utilisateur `deploy`.

## Étape 3. Sur le Mac : secrets GitHub du dépôt

La clé privée est envoyée depuis un fichier, jamais collée dans le terminal.

```bash
gh secret set VPS_SSH_KEY --repo BenRaj/market-regime < ~/.ssh/marketregime_ci
gh secret set VPS_HOST --repo BenRaj/market-regime --body "62.238.63.39"
gh secret set VPS_USER --repo BenRaj/market-regime --body "deploy"
```

Optionnel, pour la notification Slack (saisie invisible, comme pour TrdEsk) :

```bash
read -rs HOOK && printf '%s' "$HOOK" | gh secret set SLACK_WEBHOOK_URL --repo BenRaj/market-regime
```

## Étape 4. Premier déploiement

Merger la PR de ce chantier. Le CI tourne, puis le CD copie les fichiers et crée le venv. Suivre l'exécution :

```bash
gh run list --repo BenRaj/market-regime --limit 4
```

## Étape 5. Sur le VPS, en tant que `deploy` : essai et cron (une seule fois)

```bash
cd /opt/market-regime
./run_daily.sh            # essai, doit se terminer par le résumé
./install_server.sh --no-test-run   # pose le cron 9h00 New York, lundi à vendredi
crontab -l
```

`CRON_TZ` doit être pris en charge par le cron du serveur. Si le rapport du lendemain est produit à une heure inattendue, vérifier le fuseau (`timedatectl`) : sans `CRON_TZ`, 9h correspond à l'heure du serveur.

## Vérification du lendemain

```bash
ls /opt/market-regime/reports/$(date +%Y-%m-%d)/ | grep exposure_posture
tail -5 /opt/market-regime/logs/run_$(date +%Y-%m-%d).log
```

## Ce que le CD ne fait pas

- Il ne modifie pas le cron.
- Il ne touche pas à `reports/`, `logs/`, `state/` ni `venv/` côté serveur.
- Le dépôt est public : ne jamais y mettre de clé ni de fichier `.env`.
