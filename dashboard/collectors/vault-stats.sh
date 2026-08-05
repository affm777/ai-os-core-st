#!/bin/bash
# vault-stats.sh — Statistik aus dem Vault-Index (TSV). Read-only auf den Vault.
# Nutzt NUR awk/wc gegen vault-index.md, gibt die Datei nie komplett aus.

set -euo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="$HOME/.claude/dashboard"
DATA_DIR="$DASH_DIR/data"
VAULT_INDEX="$HOME/Documents/Second-Brain/00_Meta/system/vault-index.md"
INBOX_DIR="$HOME/Documents/Second-Brain/01_Inbox"
mkdir -p "$DATA_DIR"

OUT_FILE="$DATA_DIR/vault-stats.json"
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

if [[ ! -f "$VAULT_INDEX" ]]; then
  cat > "$OUT_FILE" <<EOF
{
  "generated_at": "$GENERATED_AT",
  "available": false,
  "hint": "vault-index.md nicht gefunden unter $VAULT_INDEX"
}
EOF
  echo "vault-stats.json (nicht verfuegbar) geschrieben: $OUT_FILE"
  exit 0
fi

TOTAL=$(awk -F'\t' 'BEGIN{c=0} /^```tsv/{f=1;next} /^```/{if(f)exit} f && NR>0 && $1!="path" {c++} END{print c}' "$VAULT_INDEX")

TYPE_COUNTS=$(awk -F'\t' '
  /^```tsv/{f=1;next}
  /^```/{if(f)exit}
  f && $1!="path" && $3!="" {count[$3]++}
  END{for (t in count) printf "%s\t%d\n", t, count[t]}
' "$VAULT_INDEX" | sort)

CLUSTER_COUNTS=$(awk -F'\t' '
  /^```tsv/{f=1;next}
  /^```/{if(f)exit}
  f && $1!="path" {
    n = split($4, tags, " ");
    for (i=1;i<=n;i++) {
      if (index(tags[i], "cluster/") == 1) {
        c = substr(tags[i], 9);
        count[c]++;
      }
    }
  }
  END{for (c in count) printf "%s\t%d\n", c, count[c]}
' "$VAULT_INDEX" | sort)

CUTOFF_DATE=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d "-30 days" +%Y-%m-%d)

NEW_30D=$(awk -F'\t' -v cutoff="$CUTOFF_DATE" '
  /^```tsv/{f=1;next}
  /^```/{if(f)exit}
  f && $1!="path" {
    n = split($1, parts, "/");
    fname = parts[n];
    if (match(fname, /^[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
      d = substr(fname, 1, 10);
      if (d >= cutoff) c++;
    }
  }
  END{print c+0}
' "$VAULT_INDEX")

INBOX_COUNT=0
if [[ -d "$INBOX_DIR" ]]; then
  INBOX_COUNT=$(find "$INBOX_DIR" -maxdepth 1 -type f -name "*.md" | wc -l | tr -d ' ')
fi

TYPE_TMP="$(mktemp)"
CLUSTER_TMP="$(mktemp)"
printf '%s\n' "$TYPE_COUNTS" > "$TYPE_TMP"
printf '%s\n' "$CLUSTER_COUNTS" > "$CLUSTER_TMP"
trap 'rm -f "$TYPE_TMP" "$CLUSTER_TMP"' EXIT

# "set -e" beendet das Skript bei einem abstuerzenden Python-Payload zwar
# sofort (Grundschutz), aber "> $OUT_FILE" leert die Datei schon beim Parsen
# der Umleitung, bevor Python laeuft. Ohne eigene Pruefung bliebe dann eine
# leere/kaputte vault-stats.json zurueck, ohne verstaendliche Fehlermeldung.
# Deshalb "set -e" fuer diesen Aufruf gezielt aussetzen und selbst pruefen.
set +e
$PYBIN - "$GENERATED_AT" "$TOTAL" "$NEW_30D" "$INBOX_COUNT" "$TYPE_TMP" "$CLUSTER_TMP" <<'PYEOF' > "$OUT_FILE"
import sys, json

generated_at, total, new_30d, inbox_count, type_tmp, cluster_tmp = sys.argv[1:7]

def load_counts(path):
    counts = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            t, n = line.split("\t")
            counts[t] = int(n)
    return counts

print(json.dumps({
    "generated_at": generated_at,
    "available": True,
    "total": int(total),
    "by_type": load_counts(type_tmp),
    "by_cluster": load_counts(cluster_tmp),
    "new_last_30_days": int(new_30d),
    "inbox_count": int(inbox_count),
}, ensure_ascii=False, indent=2))
PYEOF
rc=$?
set -e

verify_json_output "$rc" "$OUT_FILE" "vault-stats-collector" "$GENERATED_AT" || exit 1

chmod 644 "$OUT_FILE"
echo "vault-stats.json geschrieben: $OUT_FILE"
