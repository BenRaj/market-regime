#!/usr/bin/env bash
# ============================================================
# market-regime daily run — market-regime-daily workflow
# Exécute les 4 steps sans API requise.
# Compatible bash (serveur Linux) et macOS ; sortie dupliquée dans logs/.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR"

# Active le venv Python si présent
source "${SCRIPT_DIR}/venv/bin/activate" 2>/dev/null || true

# Journal d'exécution (utile sous cron, où la sortie est sinon perdue)
mkdir -p logs
exec > >(tee -a "logs/run_$(date +%Y-%m-%d).log") 2>&1

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M%S)
RUN_ID="daily-${DATE}-${TIME}"
REPORT_DIR="reports/${DATE}"

mkdir -p "$REPORT_DIR"

echo "========================================"
echo " Market Regime Daily — ${DATE}"
echo " run_id: ${RUN_ID}"
echo "========================================"

# ── Step 1 : Market Breadth Analyzer ─────────────────────────
echo ""
echo "[1/4] Market Breadth Analyzer..."
python3 skills/market-breadth-analyzer/scripts/market_breadth_analyzer.py \
  --detail-url "https://tradermonty.github.io/market-breadth-analysis/market_breadth_data.csv" \
  --summary-url "https://tradermonty.github.io/market-breadth-analysis/market_breadth_summary.csv" \
  --output-dir "${REPORT_DIR}" \
  --run-id "${RUN_ID}"

BREADTH_JSON=$(ls -t "${REPORT_DIR}"/market_breadth_*.json 2>/dev/null | head -1)
echo "   → ${BREADTH_JSON}"

# ── Step 2 : Uptrend Analyzer ────────────────────────────────
echo ""
echo "[2/4] Uptrend Analyzer..."
python3 skills/uptrend-analyzer/scripts/uptrend_analyzer.py \
  --output-dir "${REPORT_DIR}" \
  --run-id "${RUN_ID}"

UPTREND_JSON=$(ls -t "${REPORT_DIR}"/uptrend_analysis_*.json 2>/dev/null | head -1)
echo "   → ${UPTREND_JSON}"

# ── Step 3 : Sector Analyst ──────────────────────────────────
echo ""
echo "[3/4] Sector Analyst..."
python3 skills/sector-analyst/scripts/analyze_sector_rotation.py \
  --json \
  --save \
  --output-dir "${REPORT_DIR}"

SECTOR_JSON=$(ls -t "${REPORT_DIR}"/sector_rotation_*.json 2>/dev/null | head -1)
echo "   → ${SECTOR_JSON}"

# ── Step 4 : Exposure Coach ───────────────────────────────────
# --as-of est décalé de +5 min pour être postérieur au retrieved_at des steps 1 et 2
AS_OF=$(python3 -c "from datetime import datetime, timezone, timedelta; print((datetime.now(timezone.utc)+timedelta(minutes=5)).strftime('%Y-%m-%dT%H:%M:%SZ'))")

echo ""
echo "[4/4] Exposure Coach (as-of: ${AS_OF})..."
python3 skills/exposure-coach/scripts/calculate_exposure.py \
  --breadth  "${BREADTH_JSON}" \
  --uptrend  "${UPTREND_JSON}" \
  --sector   "${SECTOR_JSON}" \
  --output-dir "${REPORT_DIR}" \
  --require-provenance \
  --run-id "${RUN_ID}" \
  --as-of "${AS_OF}" \
  --max-age-days 3

EXPOSURE_MD=$(ls -t "${REPORT_DIR}"/exposure_posture_*.md 2>/dev/null | head -1)
echo "   → ${EXPOSURE_MD}"

# ── Résumé final ─────────────────────────────────────────────
echo ""
echo "========================================"
echo " RÉSUMÉ DU JOUR"
echo "========================================"
if [[ -f "${EXPOSURE_MD}" ]]; then
  cat "${EXPOSURE_MD}"
else
  echo "Rapport exposure non généré — vérifier les logs ci-dessus."
fi

echo ""
echo "Rapports complets : ${REPORT_DIR}/"
