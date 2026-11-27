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

Les rapports sont sauvegardés dans `reports/YYYY-MM-DD/`.

## Structure

```
market-regime/
├── run_daily.sh                  # Script principal
├── requirements.txt
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

Voir section déploiement — cron job recommandé à 9h00 ET (avant ouverture NYSE).

```cron
0 9 * * 1-5 /path/to/market-regime/venv/bin/python3 ... 
```

---

Source : [tradermonty/claude-trading-skills](https://github.com/tradermonty/claude-trading-skills) — MIT License
