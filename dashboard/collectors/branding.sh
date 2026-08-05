#!/bin/bash
# branding.sh — deterministischer Content-Pipeline-Collector fuer das Dashboard (0 Tokens).
#
# Liest das konfigurierte Content-Projekt (posts/backlog, posts/drafts, posts/published,
# posts/analytics/SUMMARY.md) und schreibt data/branding.json. Kein PyYAML im Einsatz,
# stattdessen ein eigener Mini-Frontmatter-Parser (split-basiert), da PyYAML auf
# Teilnehmer-Rechnern nicht garantiert vorhanden ist.
#
# Config-Gate: Modul deaktiviert oder config.json fehlt -> available:false,
# reason "not_configured". content_path fehlt/kein Verzeichnis -> available:false,
# reason "path_missing". posts/ leer -> available:true mit leeren Arrays.
# Alles top-level in try/except, damit dieser Collector auf keinem fremden
# Teilnehmer-Rechner crasht (Fehlerfall schreibt weiterhin ein valides JSON).

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="${DASH_DIR:-$HOME/.claude/dashboard}"
DATA_DIR="$DASH_DIR/data"
CONFIG_FILE="$DASH_DIR/config.json"
mkdir -p "$DATA_DIR"
OUT_FILE="$DATA_DIR/branding.json"
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

$PYBIN - "$GENERATED_AT" "$OUT_FILE" "$CONFIG_FILE" <<'PYEOF'
import sys, json, os, re
from datetime import datetime

generated_at, out_file, config_file = sys.argv[1:4]


def write_out(payload):
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def clean_value(val):
    val = val.strip()
    if val == "":
        return None
    if len(val) >= 2 and ((val[0] == "'" and val[-1] == "'") or (val[0] == '"' and val[-1] == '"')):
        val = val[1:-1]
    if val.lower() in ("null", "~"):
        return None
    try:
        return int(val)
    except ValueError:
        pass
    try:
        return float(val)
    except ValueError:
        pass
    return val


def parse_frontmatter(text):
    # Block zwischen erster '---'-Zeile und der naechsten '---'-Zeile.
    data, metrics = {}, {}
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return data, metrics
    end = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end = idx
            break
    if end is None:
        return data, metrics
    block = lines[1:end]
    i = 0
    while i < len(block):
        line = block[i]
        if not line.strip():
            i += 1
            continue
        if line[0] in (" ", "\t"):
            # Fortsetzungszeile eines mehrzeiligen Blocks (z.B. "notes: |" oder gefaltete
            # Scalars wie "story_framework: ... \n  -> ..."), gehoert nicht zu uns -> ueberspringen.
            i += 1
            continue
        if ":" not in line:
            i += 1
            continue
        key, _, rest = line.partition(":")
        key = key.strip()
        val = rest.strip()
        if key == "metrics":
            # Unterblock: alle nachfolgenden eingerueckten Zeilen als key: value einlesen.
            i += 1
            while i < len(block) and block[i] and block[i][0] in (" ", "\t"):
                sub = block[i].strip()
                if ":" in sub:
                    sk, _, sv = sub.partition(":")
                    metrics[sk.strip()] = clean_value(sv.strip())
                i += 1
            continue
        data[key] = clean_value(val)
        i += 1
    return data, metrics


def read_frontmatter(path):
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return {}, {}
    try:
        return parse_frontmatter(text)
    except Exception:
        return {}, {}


def file_mtime_date(path):
    try:
        return datetime.fromtimestamp(os.path.getmtime(path)).strftime("%Y-%m-%d")
    except Exception:
        return None


try:
    cfg = {}
    if os.path.isfile(config_file):
        try:
            with open(config_file, encoding="utf-8") as f:
                cfg = json.load(f)
        except Exception:
            cfg = {}

    branding_cfg = (cfg.get("modules") or {}).get("branding") or {}
    if not branding_cfg.get("enabled"):
        write_out({"generated_at": generated_at, "available": False, "reason": "not_configured"})
        print("branding.json (Modul nicht konfiguriert) geschrieben")
        sys.exit(0)

    raw_path = branding_cfg.get("content_path") or ""
    content_path = os.path.expanduser(raw_path) if raw_path else ""
    if not content_path or not os.path.isdir(content_path):
        write_out({"generated_at": generated_at, "available": False, "reason": "path_missing",
                   "content_path": raw_path})
        print("branding.json (content_path fehlt) geschrieben")
        sys.exit(0)

    platforms = branding_cfg.get("platforms") or []
    posts_dir = os.path.join(content_path, "posts")

    backlog, drafts, published = [], [], []
    pillars_set = set()

    backlog_dir = os.path.join(posts_dir, "backlog")
    if os.path.isdir(backlog_dir):
        for name in sorted(os.listdir(backlog_dir)):
            if not name.endswith(".md"):
                continue
            path = os.path.join(backlog_dir, name)
            fm, _ = read_frontmatter(path)
            slug = name[:-3]
            pillar = fm.get("pillar")
            if pillar:
                pillars_set.add(pillar)
            backlog.append({
                "slug": slug,
                "title": fm.get("title") or slug,
                "pillar": pillar,
                "format": fm.get("format"),
                "virality_score": fm.get("virality_score"),
                "created_at": fm.get("created_at") or file_mtime_date(path),
            })

    drafts_dir = os.path.join(posts_dir, "drafts")
    if os.path.isdir(drafts_dir):
        for name in sorted(os.listdir(drafts_dir)):
            sub = os.path.join(drafts_dir, name)
            post_file = os.path.join(sub, "post.md")
            if not os.path.isdir(sub) or not os.path.isfile(post_file):
                continue
            fm, _ = read_frontmatter(post_file)
            pillar = fm.get("pillar")
            if pillar:
                pillars_set.add(pillar)
            drafts.append({
                "slug": name,
                "title": fm.get("title") or fm.get("hook") or fm.get("topic") or name,
                "pillar": pillar,
                "slot": fm.get("slot"),
            })

    published_dir = os.path.join(posts_dir, "published")
    folder_re = re.compile(r"^(\d{4}-\d{2}-\d{2})-(.+)$")
    if os.path.isdir(published_dir):
        for name in sorted(os.listdir(published_dir)):
            sub = os.path.join(published_dir, name)
            post_file = os.path.join(sub, "post.md")
            if not os.path.isdir(sub) or not os.path.isfile(post_file):
                continue
            fm, m = read_frontmatter(post_file)
            match = folder_re.match(name)
            folder_date = match.group(1) if match else None
            folder_slug = match.group(2) if match else name
            pillar = fm.get("pillar")
            if pillar:
                pillars_set.add(pillar)
            metrics = {
                "impressions": m.get("impressions") or 0,
                "members_reached": m.get("members_reached") or 0,
                "likes": m.get("likes") or 0,
                "comments": m.get("comments") or 0,
                "follows": m.get("follows") or 0,
            }
            published.append({
                "slug": folder_slug,
                "date": fm.get("date") or folder_date,
                "title": fm.get("title") or fm.get("hook") or fm.get("topic") or folder_slug,
                "pillar": pillar,
                "format": fm.get("format"),
                "platform": fm.get("platform") or "linkedin",
                "url": fm.get("url"),
                "metrics": metrics,
                "d_score": fm.get("d_score"),
            })

    # --- Analytics-Summary (posts/analytics/SUMMARY.md), Perioden-Ueberschriften +
    # nachfolgende Markdown-KPI-Tabelle. Einzelne nicht matchende Zeilen werden ignoriert.
    analytics = {"summary_available": False, "followers_total": 0, "periods": []}
    summary_path = os.path.join(posts_dir, "analytics", "SUMMARY.md")
    if os.path.isfile(summary_path):
        try:
            with open(summary_path, encoding="utf-8") as f:
                text = f.read()
            period_re = re.compile(r"^## (\d{4}-\d{2}-\d{2}) bis (\d{4}-\d{2}-\d{2}) \((\d+) Tage\)")
            label_map = {
                "impressions": "impressions",
                "members reached": "members_reached",
                "engagements": "engagements",
                "new followers": "new_followers",
                "total followers (ende)": "followers_total",
                "posts veroeffentlicht": "posts",
            }
            periods = []
            current = None
            for line in text.split("\n"):
                stripped = line.strip()
                m = period_re.match(stripped)
                if m:
                    if current:
                        periods.append(current)
                    current = {"from": m.group(1), "to": m.group(2), "days": int(m.group(3)),
                               "impressions": 0, "members_reached": 0, "engagements": 0,
                               "new_followers": 0, "followers_total": 0, "posts": 0}
                    continue
                if current is not None and stripped.startswith("|") and not stripped.startswith("|---"):
                    cells = [c.strip() for c in stripped.strip("|").split("|")]
                    if len(cells) >= 2:
                        label_key = cells[0].lower().strip()
                        if label_key == "kpi":
                            continue
                        field = label_map.get(label_key)
                        if field:
                            raw_val = cells[1].replace(".", "").strip()
                            try:
                                current[field] = int(raw_val)
                            except (ValueError, TypeError):
                                pass
            if current:
                periods.append(current)
            periods = periods[:12]  # neueste zuerst (Datei-Reihenfolge), max. 12
            analytics["periods"] = periods
            analytics["summary_available"] = len(periods) > 0
            if periods:
                analytics["followers_total"] = periods[0].get("followers_total", 0)
        except Exception:
            analytics = {"summary_available": False, "followers_total": 0, "periods": []}

    write_out({
        "generated_at": generated_at,
        "available": True,
        "content_path": content_path,
        "platforms": platforms,
        "pillars": sorted(pillars_set),
        "pipeline": {"backlog": backlog, "drafts": drafts, "published": published},
        "analytics": analytics,
    })
    print("branding.json geschrieben (backlog=%d, drafts=%d, published=%d, perioden=%d)" % (
        len(backlog), len(drafts), len(published), len(analytics["periods"])))
except SystemExit:
    raise
except Exception as e:
    try:
        write_out({"generated_at": generated_at, "available": False, "reason": "error", "error": str(e)[:300]})
    except Exception:
        pass
    print("branding.sh Fehler: %s" % e)
    sys.exit(0)
PYEOF
rc=$?

verify_json_output "$rc" "$OUT_FILE" "branding-collector" "$GENERATED_AT" || exit 1

chmod 644 "$OUT_FILE" 2>/dev/null || true
