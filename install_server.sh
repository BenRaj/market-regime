#!/usr/bin/env bash
# ============================================================
# Installation de market-regime sur un serveur (Linux ou macOS).
# Idempotent : peut être relancé sans risque.
#
# Usage : ./install_server.sh [--no-cron] [--no-test-run] [--hour H] [--minute M]
#   --no-cron      n'installe pas la tâche cron
#   --no-test-run  ne lance pas un essai de run_daily.sh
#   --hour/--minute heure locale ET de l'exécution (défaut 9:00)
# ============================================================
set -euo pipefail

INSTALL_CRON=1
TEST_RUN=1
HOUR=9
MINUTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-cron)     INSTALL_CRON=0 ;;
    --no-test-run) TEST_RUN=0 ;;
    --hour)        HOUR="${2:?--hour demande une valeur}"; shift ;;
    --minute)      MINUTE="${2:?--minute demande une valeur}"; shift ;;
    -h|--help)     sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

[[ "$HOUR" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]   || { echo "Heure invalide : $HOUR" >&2; exit 2; }
[[ "$MINUTE" =~ ^([0-9]|[1-5][0-9])$ ]]    || { echo "Minute invalide : $MINUTE" >&2; exit 2; }

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$APP_DIR"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'ERREUR : %s\n' "$*" >&2; exit 1; }

# ── 1. Prérequis ─────────────────────────────────────────────
step "Vérification des prérequis"
# PYTHON=/chemin/vers/python3.12 ./install_server.sh pour forcer un interpréteur.
PY_BIN=""
for cand in "${PYTHON:-}" python3.13 python3.12 python3.11 python3; do
  [[ -n "$cand" ]] || continue
  command -v "$cand" >/dev/null || continue
  if "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
    PY_BIN="$(command -v "$cand")"
    break
  fi
done
[[ -n "$PY_BIN" ]] || fail "Python 3.11 ou plus récent introuvable (python3 actuel : $(python3 --version 2>&1 || echo absent))"
echo "interpréteur : $PY_BIN ($("$PY_BIN" --version))"

for f in run_daily.sh requirements.txt skills/market-breadth-analyzer skills/uptrend-analyzer skills/exposure-coach; do
  [[ -e "$f" ]] || fail "fichier manquant : $f (lancer depuis la racine du dépôt)"
done

# Accès réseau sortant (sources de données publiques)
if command -v curl >/dev/null; then
  for url in \
    https://tradermonty.github.io/market-breadth-analysis/market_breadth_summary.csv \
    https://raw.githubusercontent.com/tradermonty/uptrend-dashboard/main/data/sector_summary.csv; do
    if curl -fsS -m 20 -o /dev/null -I "$url"; then
      echo "accès OK : $url"
    else
      fail "source de données inaccessible : $url"
    fi
  done
else
  echo "curl absent : test réseau ignoré"
fi

# ── 2. Environnement Python ──────────────────────────────────
step "Environnement virtuel"
[[ -x venv/bin/python ]] || "$PY_BIN" -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo "dépendances installées"

chmod +x run_daily.sh
mkdir -p logs reports state/journal

# ── 3. Essai manuel ──────────────────────────────────────────
if [[ "$TEST_RUN" -eq 1 ]]; then
  step "Essai de run_daily.sh"
  ./run_daily.sh >/dev/null
  latest="$(ls -t reports/*/exposure_posture_*.md 2>/dev/null | head -1 || true)"
  [[ -n "$latest" ]] || fail "aucun rapport exposure_posture généré, voir logs/"
  echo "rapport généré : $latest"
fi

# ── 4. Cron ──────────────────────────────────────────────────
MARK_BEGIN="# BEGIN market-regime"
MARK_END="# END market-regime"

if [[ "$INSTALL_CRON" -eq 1 ]]; then
  step "Tâche cron (${HOUR}:$(printf '%02d' "$MINUTE") America/New_York, lundi-vendredi)"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macOS : CRON_TZ n'est pas pris en charge, cron non installé."
    echo "Utiliser launchd (StartCalendarInterval, Weekday 1 à 5) ou relancer avec --no-cron."
  elif ! command -v crontab >/dev/null; then
    echo "crontab absent : installer cron (cronie) puis relancer."
  else
    # Retire l'ancien bloc géré par ce script, conserve le reste.
    current="$(crontab -l 2>/dev/null || true)"
    cleaned="$(printf '%s\n' "$current" | sed "/^${MARK_BEGIN}\$/,/^${MARK_END}\$/d")"
    # Le bloc va en fin de fichier : CRON_TZ s'applique aux lignes qui suivent.
    {
      [[ -n "${cleaned//[[:space:]]/}" ]] && printf '%s\n' "$cleaned"
      printf '%s\n' "$MARK_BEGIN"
      printf 'CRON_TZ=America/New_York\n'
      printf '%s %s * * 1-5 %s/run_daily.sh\n' "$MINUTE" "$HOUR" "$APP_DIR"
      printf '%s\n' "$MARK_END"
    } | crontab -
    echo "cron installé :"
    crontab -l | sed -n "/^${MARK_BEGIN}\$/,/^${MARK_END}\$/p"
    echo "Note : CRON_TZ est géré par cronie ; avec un autre cron, le fuseau serait celui du serveur."
  fi
fi

step "Terminé"
echo "Dossier        : $APP_DIR"
echo "Essai manuel   : $APP_DIR/run_daily.sh"
echo "Vérification   : reports/<date>/exposure_posture_*.md et logs/run_<date>.log"
