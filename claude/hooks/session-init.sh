#!/bin/bash
# Session-Init Hook — Vault Context Loader (compact mode)
# Outputs Project Status + Project-scoped Decisions + Learning titles.
# Target: <2KB so harness inlines full output (no preview truncation).
#
# Lookup-Strategie (Performance): Discovery laeuft ueber den TSV-Index
# (00_Meta/system/vault-index.md, eine Datei) plus einen gezielten Scan
# NUR ueber 01_Inbox/ (unsortierte Neuzugaenge stehen noch nicht im Index).
# Kein Full-Vault-Grep mehr. Fallback auf Full-Grep, wenn der Index fehlt.

VAULT="$HOME/Documents/Second-Brain"
INDEX="$VAULT/00_Meta/system/vault-index.md"
INBOX="$VAULT/01_Inbox"

# --- Projekt-Slug aus CLAUDE.md (Vault-Integration Abschnitt) ---
PROJECT_SLUG=""
if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -f "$CLAUDE_PROJECT_DIR/CLAUDE.md" ]; then
  PROJECT_SLUG=$(grep 'Projekt-Tag:' "$CLAUDE_PROJECT_DIR/CLAUDE.md" 2>/dev/null | sed -E 's|.*project/([a-zA-Z0-9_-]+).*|\1|' | head -1)
fi

# Helper: Datum aus Dateiname (YYYY-MM-DD-*) extrahieren
path_date() {
  basename "$1" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1
}

# Helper: Discovery via TSV-Index — liefert "relpath<TAB>title"
# Spalten: path title type tags aliases topics updated
index_lookup() {
  local want_type="$1"
  awk -F'\t' -v t="$want_type" -v p="project/$PROJECT_SLUG" \
    'NF>=7 && $3==t && index($4,p) {print $1 "\t" $2}' "$INDEX" 2>/dev/null
}

# Helper: Discovery ueber 01_Inbox/ (noch nicht im Index) — "relpath<TAB>title"
inbox_lookup() {
  local want_type="$1"
  local f title
  for f in "$INBOX"/*.md; do
    [ -f "$f" ] || continue
    grep -q "type: $want_type" "$f" 2>/dev/null || continue
    grep -q "project/$PROJECT_SLUG" "$f" 2>/dev/null || continue
    title=$(grep "^title:" "$f" 2>/dev/null | head -1 | sed 's/title: *"*//;s/"*$//')
    [ -z "$title" ] && title=$(basename "$f" .md)
    printf '01_Inbox/%s\t%s\n' "$(basename "$f")" "$title"
  done
}

# Helper: Fallback-Discovery via Full-Grep (nur wenn Index fehlt)
fullgrep_lookup() {
  local want_type="$1"
  local f title
  for f in $(grep -rl "type: $want_type" "$VAULT" 2>/dev/null | xargs grep -l "project/$PROJECT_SLUG" 2>/dev/null); do
    title=$(grep "^title:" "$f" 2>/dev/null | head -1 | sed 's/title: *"*//;s/"*$//')
    [ -z "$title" ] && title=$(basename "$f" .md)
    printf '%s\t%s\n' "${f#$VAULT/}" "$title"
  done
}

# Helper: kombinierte Discovery
discover() {
  local want_type="$1"
  if [ -f "$INDEX" ]; then
    { index_lookup "$want_type"; inbox_lookup "$want_type"; } | sort -u
  else
    fullgrep_lookup "$want_type" | sort -u
  fi
}

echo "=== SESSION CONTEXT ==="
echo ""

# --- 1. PROJECT STATUS (from STATE.md) ---
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  STATE_FILE=""
  [ -f "$CLAUDE_PROJECT_DIR/.planning/STATE.md" ] && STATE_FILE="$CLAUDE_PROJECT_DIR/.planning/STATE.md"
  [ -z "$STATE_FILE" ] && [ -f "$CLAUDE_PROJECT_DIR/STATE.md" ] && STATE_FILE="$CLAUDE_PROJECT_DIR/STATE.md"

  if [ -n "$STATE_FILE" ]; then
    echo "[PROJECT STATUS]"
    PHASE=$(grep -m1 "^Phase:" "$STATE_FILE" 2>/dev/null | head -1)
    [ -z "$PHASE" ] && PHASE=$(grep -m1 "Phase:" "$STATE_FILE" 2>/dev/null | head -1)
    LAST=$(grep -m1 "Last activity:" "$STATE_FILE" 2>/dev/null | head -1)
    [ -z "$LAST" ] && LAST=$(grep -m1 "Letzte Aktualisierung:" "$STATE_FILE" 2>/dev/null | head -1)
    NEXT=$(grep -m1 "Naechster Schritt:" "$STATE_FILE" 2>/dev/null | head -1)
    [ -z "$NEXT" ] && NEXT=$(grep -m1 "Next step:" "$STATE_FILE" 2>/dev/null | head -1)
    PROGRESS=$(grep -m1 "Progress:" "$STATE_FILE" 2>/dev/null | head -1)
    STATUS_LINE=$(grep -m1 "^## Status:" "$STATE_FILE" 2>/dev/null | sed 's/^## //')

    [ -n "$STATUS_LINE" ] && echo "  $STATUS_LINE"
    [ -n "$PHASE" ] && echo "  $PHASE"
    [ -n "$PROGRESS" ] && echo "  $PROGRESS"
    [ -n "$LAST" ] && echo "  $LAST"
    [ -n "$NEXT" ] && echo "  $NEXT"
    echo ""
  fi
fi

# --- 2. DECISIONS (project-scoped, validity: active, one line each) ---
if [ -n "$PROJECT_SLUG" ] && [ -d "$VAULT" ]; then
  ACTIVE_LINES=""
  SKIPPED_COUNT=0
  while IFS=$'\t' read -r relpath title; do
    [ -z "$relpath" ] && continue
    f="$VAULT/$relpath"
    [ -f "$f" ] || continue
    VALIDITY=$(awk '/^---$/{n++; next} n==1 && /^validity:/{print; exit}' "$f" | sed 's/validity: *//;s/ *$//')
    if [ -z "$VALIDITY" ] || [ "$VALIDITY" = "active" ]; then
      TITLE=$(echo "$title" | sed 's/^Decision: *//')
      DATE=$(path_date "$relpath")
      [ -n "$TITLE" ] && ACTIVE_LINES="${ACTIVE_LINES}${DATE}|${TITLE}"$'\n'
    else
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
  done <<< "$(discover decision)"

  if [ -n "$ACTIVE_LINES" ]; then
    CAP=25
    SORTED=$(echo "$ACTIVE_LINES" | sed '/^$/d' | sort -r)
    TOTAL=$(echo "$SORTED" | wc -l | tr -d ' ')
    HEADER="[DECISIONS — project/$PROJECT_SLUG]"
    [ $SKIPPED_COUNT -gt 0 ] && HEADER="$HEADER ($SKIPPED_COUNT superseded)"
    echo "$HEADER"
    echo "$SORTED" | head -n $CAP | awk -F'|' '{printf "  - %s: %s\n", $1, $2}'
    HIDDEN=$((TOTAL - CAP))
    [ $HIDDEN -gt 0 ] && echo "  ... plus $HIDDEN aeltere (grep vault-index.md)"
    echo ""
  fi
fi

# --- 3. LEARNINGS (project-scoped only, newest first, cap 25) ---
if [ -n "$PROJECT_SLUG" ] && [ -d "$VAULT" ]; then
  LEARNING_LINES=""
  TOTAL=0
  while IFS=$'\t' read -r relpath title; do
    [ -z "$relpath" ] && continue
    TITLE=$(echo "$title" | sed 's/^Learning: *//')
    DATE=$(path_date "$relpath")
    if [ -n "$TITLE" ]; then
      LEARNING_LINES="${LEARNING_LINES}${DATE}|${TITLE}"$'\n'
      TOTAL=$((TOTAL + 1))
    fi
  done <<< "$(discover learning)"

  if [ -n "$LEARNING_LINES" ]; then
    CAP=25
    SORTED=$(echo "$LEARNING_LINES" | sed '/^$/d' | sort -r)
    SHOWN=$(echo "$SORTED" | head -n $CAP | awk -F'|' '{printf "  - %s: %s\n", $1, $2}')
    HIDDEN=$((TOTAL - CAP))

    echo "[LEARNINGS — project/$PROJECT_SLUG]"
    echo "$SHOWN"
    [ $HIDDEN -gt 0 ] && echo "  ... plus $HIDDEN aeltere Learnings (grep vault-index.md)"
    echo ""
  fi
fi

# --- 4. CLUSTER-UEBERSICHT (nur bei geclusterten Projekten, gruppierte Themen) ---
if [ -n "$PROJECT_SLUG" ] && [ -f "$INDEX" ]; then
  CLUSTER_SUMMARY=$(awk -F'\t' -v p="project/$PROJECT_SLUG" '
    NF>=7 && ($3=="decision" || $3=="learning") && index($4,p) {
      if (match($4, /cluster\/[a-zA-Z0-9_-]+/)) {
        c[substr($4, RSTART+8, RLENGTH-8)]++
      }
    }
    END { for (k in c) printf "%d|%s\n", c[k], k }' "$INDEX" 2>/dev/null \
    | sort -rn -t'|' | awk -F'|' '{printf "%s%s (%d)", sep, $2, $1; sep=", "}')
  if [ -n "$CLUSTER_SUMMARY" ]; then
    echo "[CLUSTER — project/$PROJECT_SLUG] (Decisions+Learnings je Cluster)"
    echo "  $CLUSTER_SUMMARY"
    echo "  Detail-Lookup: Zustand (flat/clustered) + Block-Index-Pfad siehe 00_Meta/clusters/vault-clusters.md"
    echo ""
  fi
fi

# --- Footer ---
echo "INFO: Volltext via 'grep \"<Title>\" ~/Documents/Second-Brain/00_Meta/system/vault-index.md' + Read."
echo "=== END SESSION CONTEXT ==="

exit 0
