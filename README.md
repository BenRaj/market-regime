# market-regime

Outil de revue quotidienne du régime de marché, basé sur [claude-trading-skills](https://github.com/tradermonty/claude-trading-skills).

## Workflow : `market-regime-daily`

Revue de 15 minutes avant d'envisager un nouveau trade. Aucune API payante requise.

### Pipeline (3 steps)

| Step | Skill | Produit |
|------|-------|---------|
| 1 | `market-breadth-analyzer` | Score 0-100 sur 6 composantes (participation marché) |
| 2 | `uptrend-analyzer` | Score 0-100 sur 5 composantes (ratio de stocks en uptrend) |
| 3 | `exposure-coach` | Décision : `NEW_ENTRY_ALLOWED` / `REDUCE_ONLY` / `CASH_PRIORITY` |

### Décision finale

| Résultat | Action |
|----------|--------|
| `NEW_ENTRY_ALLOWED` | Nouveaux trades permis |
| `REDUCE_ONLY` | Pas de nouvelles entrées, réduire les positions sur la force |
| `CASH_PRIORITY` | Passer en cash agressivement |

---

## Installation

```bash
cd /path/to/market-regime
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Utilisation

```bash
# Revue du jour (exécuter avant l'ouverture ou dans les 30 premières minutes)
chmod +x run_daily.sh
./run_daily.sh
```

Les rapports sont sauvegardés dans `reports/YYYY-MM-DD/`, le journal d'exécution dans `logs/run_YYYY-MM-DD.log`.

Le workflow tourne sur 3 steps uniquement. `market-top-detector` (clé FMP) n'est pas installé : l'exposure-coach conclut donc avec une confiance `LOW` (entrées manquantes : regime, top_risk, institutional, sector, theme, ftd).

## Tests

```bash
pip install -r requirements-dev.txt
for s in market-breadth-analyzer uptrend-analyzer exposure-coach; do
  (cd skills/$s/scripts && python -m pytest tests -q --ignore=tests/test_provenance_contract.py)
done
```

Résultat au 2026-11-27 : breadth 168 OK, uptrend 224 OK, exposure-coach 378 OK et 4 échecs. Ces tests supposent des fichiers du dépôt amont non copiés ici (`scripts/validate_provenance.py` et les skills `sector-analyst`, `theme-detector`, `ftd-detector`). Ce sont des échecs d'environnement, pas de logique.

## Structure

```
market-regime/
├── run_daily.sh                  # Script principal
├── requirements.txt
├── requirements-dev.txt          # + pytest
├── logs/                         # Journaux d'exécution (gitignored)
├── workflows/
│   └── market-regime-daily.yaml  # Manifeste du workflow
├── skills/
│   ├── market-breadth-analyzer/  # Step 1
│   ├── uptrend-analyzer/         # Step 2
│   └── exposure-coach/           # Step 3
├── reports/                      # Sorties (gitignored)
│   └── YYYY-MM-DD/
│       ├── market_breadth_*.{json,md}
│       ├── uptrend_analysis_*.{json,md}
│       └── exposure_posture_*.{json,md}
└── docs/                         # Documentation des skills
```

## Déploiement serveur

Prérequis : Linux ou macOS avec `python3` (3.11 testé), `bash` et un accès sortant vers `tradermonty.github.io` et `raw.githubusercontent.com`. Aucune clé d'API.

```bash
git clone <url-du-depot> market-regime && cd market-regime
./install_server.sh     # prérequis, venv, essai, cron (options : --no-cron, --no-test-run, --hour, --minute)
```

Le script cherche un Python 3.11 ou plus récent (variable `PYTHON` pour en forcer un), vérifie l'accès aux sources de données, installe le venv, lance un essai, puis ajoute la tâche cron. Il peut être relancé sans risque. Pour une installation manuelle :

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
chmod +x run_daily.sh
./run_daily.sh        # essai manuel, doit se terminer par le résumé
```

Cron à 9h00 ET, du lundi au vendredi. `CRON_TZ` gère le passage heure d'été/hiver ; il est pris en charge par cronie (Linux), pas par le cron de macOS.

```cron
CRON_TZ=America/New_York
0 9 * * 1-5 /chemin/vers/market-regime/run_daily.sh
```

Le script s'exécute depuis son propre dossier, active le venv et écrit dans `logs/`. Sur macOS, `crontab` peut être refusé (permission) : utiliser alors `launchd` (`StartCalendarInterval`, Hour 9, Minute 0, Weekday 1 à 5).

Vérification du lendemain : `reports/<date>/exposure_posture_*.md` existe et `logs/run_<date>.log` ne contient pas d'erreur.

Déploiement automatique sur le VPS Hetzner (CI puis CD à chaque merge sur `main`) : voir `docs/DEPLOIEMENT_VPS.md`.

---

Source : [tradermonty/claude-trading-skills](https://github.com/tradermonty/claude-trading-skills) — MIT License
