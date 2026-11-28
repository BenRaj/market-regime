"""market-regime dashboard — FastAPI + Jinja2.

Lit les rapports JSON/MD produits par run_daily.sh et les affiche.
Aucune dépendance externe autre que fastapi, uvicorn, jinja2.
"""
from __future__ import annotations

import glob
import json
import os
from datetime import date, datetime
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent   # racine du projet
REPORTS_DIR = BASE_DIR / "reports"
TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"
STATIC_DIR = Path(__file__).resolve().parent / "static"

app = FastAPI(title="market-regime dashboard", docs_url=None, redoc_url=None)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _latest_json(date_str: str, pattern: str) -> Optional[dict]:
    """Retourne le JSON le plus récent correspondant au pattern du jour."""
    matches = sorted(
        glob.glob(str(REPORTS_DIR / date_str / pattern)),
        reverse=True,
    )
    if not matches:
        return None
    try:
        with open(matches[0]) as f:
            return json.load(f)
    except Exception:
        return None


def _latest_md(date_str: str, pattern: str) -> Optional[str]:
    matches = sorted(
        glob.glob(str(REPORTS_DIR / date_str / pattern)),
        reverse=True,
    )
    if not matches:
        return None
    try:
        return Path(matches[0]).read_text()
    except Exception:
        return None


def _available_dates() -> list[str]:
    """Liste des dates avec un rapport exposure, triées du plus récent au plus ancien."""
    dirs = sorted(
        [p.name for p in REPORTS_DIR.iterdir() if p.is_dir()],
        reverse=True,
    )
    result = []
    for d in dirs:
        if glob.glob(str(REPORTS_DIR / d / "exposure_posture_*.json")):
            result.append(d)
    return result


def _day_summary(date_str: str) -> Optional[dict]:
    """Résumé d'un jour pour l'historique."""
    data = _latest_json(date_str, "exposure_posture_*.json")
    if not data:
        return None
    return {
        "date": date_str,
        "recommendation": data.get("recommendation", "—"),
        "confidence": data.get("confidence", "—"),
        "exposure_ceiling_pct": data.get("exposure_ceiling_pct", "—"),
        "composite_score": data.get("composite_score"),
        "breadth_score": data.get("component_scores", {}).get("breadth_score"),
        "uptrend_score": data.get("component_scores", {}).get("uptrend_score"),
        "sector_score": data.get("component_scores", {}).get("sector_score"),
        "inputs_missing": data.get("inputs_missing", []),
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    dates = _available_dates()
    today = dates[0] if dates else None
    exposure = _latest_json(today, "exposure_posture_*.json") if today else None
    breadth  = _latest_json(today, "market_breadth_*.json") if today else None
    uptrend  = _latest_json(today, "uptrend_analysis_*.json") if today else None
    sector   = _latest_json(today, "sector_rotation_*.json") if today else None

    return templates.TemplateResponse(request, "index.html", {
        "today": today,
        "exposure": exposure,
        "breadth": breadth,
        "uptrend": uptrend,
        "sector": sector,
        "recent_dates": dates[:7],
    })


@app.get("/history", response_class=HTMLResponse)
async def history(request: Request):
    dates = _available_dates()
    rows = [_day_summary(d) for d in dates]
    rows = [r for r in rows if r]
    return templates.TemplateResponse(request, "history.html", {
        "rows": rows,
    })


@app.get("/reports/{date_str}", response_class=HTMLResponse)
async def report_detail(request: Request, date_str: str):
    if not (REPORTS_DIR / date_str).is_dir():
        raise HTTPException(status_code=404, detail="Date introuvable")

    exposure = _latest_json(date_str, "exposure_posture_*.json")
    breadth  = _latest_json(date_str, "market_breadth_*.json")
    uptrend  = _latest_json(date_str, "uptrend_analysis_*.json")
    sector   = _latest_json(date_str, "sector_rotation_*.json")
    exposure_md = _latest_md(date_str, "exposure_posture_*.md")
    breadth_md  = _latest_md(date_str, "market_breadth_*.md")
    uptrend_md  = _latest_md(date_str, "uptrend_analysis_*.md")

    if not exposure:
        raise HTTPException(status_code=404, detail="Rapport exposure introuvable")

    return templates.TemplateResponse(request, "detail.html", {
        "date_str": date_str,
        "exposure": exposure,
        "breadth": breadth,
        "uptrend": uptrend,
        "sector": sector,
        "exposure_md": exposure_md,
        "breadth_md": breadth_md,
        "uptrend_md": uptrend_md,
    })


@app.get("/api/today")
async def api_today():
    dates = _available_dates()
    if not dates:
        raise HTTPException(status_code=404, detail="Aucun rapport disponible")
    return _latest_json(dates[0], "exposure_posture_*.json")
