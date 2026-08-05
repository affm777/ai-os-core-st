---
name: briefing
description: Erstellt das tägliche Briefing des Nutzers (Kalender, Mail-Triage, fällige Deals, System-Health) und formuliert eine kurze Slack-Essenz. Wöchentlich zusätzlich Vollcheck plus maximal drei Tuning-Empfehlungen mit Beleg. Triggert bei "briefing", "morning briefing", "/briefing", "/briefing weekly".
when_to_use: |
  Trigger-Phrasen: "briefing", "tages-briefing", "morning briefing", "was steht heute an", "/briefing". Ohne Argument = täglicher Modus. Argument "weekly" = zusätzlich Vollcheck (/system-check full-Logik) und Tuning-Empfehlungen. Zustellung an Slack ist standardmäßig ein Dry-Run (nur Anzeige); echter Versand nur mit Argument "send" UND nachdem der Nutzer den Dry-Run-Text einmal explizit freigegeben hat.
allowed-tools: Bash(bash:*), Bash(gws:*), Read, mcp__claude_ai_Google_Calendar__list_events, mcp__claude_ai_Airtable__list_records_for_table, mcp__claude_ai_Airtable__get_table_schema, mcp__claude_ai_Slack__slack_send_message
---

# Briefing

Du bist der Tages-/Wochen-Briefer für den Nutzer. Du sammelst Fakten deterministisch, verdichtest sie zu Aggregat-Aussagen und zeigst sie standardmäßig nur an (Dry-Run). Echter Slack-Versand ist ein separater, bewusster Schritt.

## Modus bestimmen

- Kein Argument oder "daily"/"heute" → **Täglicher Modus** (Schritte 1-5).
- Argument "weekly" oder der Nutzer sagt "Wochen-Briefing", "voller Check" → **Täglicher Modus PLUS Wochen-Zusatz** (Schritt 6).
- Argument "send" (kann mit "weekly send" kombiniert sein) → am Ende NICHT nur anzeigen, sondern real über Slack-MCP senden, aber NUR wenn im aktuellen Gespräch bereits ein Dry-Run-Text gezeigt und vom Nutzer ausdrücklich freigegeben wurde (z. B. "schick das", "passt, sende"). Ohne diese Freigabe im selben Gesprächsverlauf: NICHT senden, stattdessen den Dry-Run-Text zeigen und um Freigabe bitten.

## Täglicher Modus

### 1. System-Check (light)

```bash
bash ~/.claude/dashboard/collectors/check.sh light
```
JSON lesen: `~/.claude/dashboard/data/system-check.json` (`summary.fail`, `summary.warn`, plus die einzelnen FAIL-Zeilen aus `checks[]`).

### 2. heute.json bauen

Ziel: `~/.claude/dashboard/data/heute.json`, Schema:
```json
{
  "generated_at": "<ISO-8601>",
  "kalender": [{"zeit": "HH:MM", "titel": "...", "konto": "privat|gws", "quelle": "privat|gws"}],
  "mail": {"handeln": 0, "warten": 0, "kenntnis": 0, "top": ["Betreff 1", "..."]},
  "deals": [{"name": "...", "next_step": "...", "faellig": "YYYY-MM-DD"}],
  "sources": {"gws_calendar": {"status": "ok"}, "privat_calendar": {"status": "ok"}}
}
```
oder `"deals": {"available": false, "hint": "<Grund>"}`, wenn die Airtable-Abfrage nicht möglich war.

**Zwei-Schreiber-Schutz (PFLICHT):** `heute.json` wird auch vom deterministischen Collector `~/.claude/dashboard/collectors/heute.sh` geschrieben (Kalender des optionalen gws-Zweitkontos, läuft bei jedem „Aktualisieren" ohne Tokens). Bevor du schreibst, **lies das bestehende `heute.json`** und erhalte daraus: alle `kalender`-Einträge mit `"quelle": "gws"` sowie `sources.gws_calendar`. Du schreibst nur die **privaten** Kalendereinträge (`"quelle": "privat"`), `mail`, `deals` und `sources.privat_calendar`. Das Endergebnis ist die Vereinigung aus erhaltenen gws-Einträgen und deinen Privat-Einträgen, nach Uhrzeit sortiert.

**a) Kalender.** Zwei Konten:
- **Privat (dein Hauptkalender):** über den **MCP-Connector** `mcp__claude_ai_Google_Calendar__list_events` — heutiger Tag (Zeitzone Europe/Berlin), primärer Kalender. Je Event Uhrzeit (HH:MM aus `start.dateTime`; ganztägig → `"ganztags"`) und Titel; als `{"zeit","titel","konto":"privat","quelle":"privat"}`. Ist der Connector nicht angemeldet: keine Privat-Einträge schreiben und `sources.privat_calendar.status = "auth_error"` setzen, in der Chat-Antwort nennen.
- **Zweitkonto (gws, optional):** wird bereits vom Collector `heute.sh` gepflegt. Führe zur Sicherheit `bash ~/.claude/dashboard/collectors/heute.sh` aus (aktualisiert den Zweitkonto-Kalender + `sources.gws_calendar`, erhält deine Privat-Einträge per Read-Merge), ODER übernimm die bestehenden gws-Einträge unverändert. Ist kein Zweitkonto eingerichtet, entfällt dieser Teil ersatzlos. NIEMALS `gws calendar` mit einem Schreib-Unterbefehl aufrufen.

`sources.privat_calendar.status` auf `"ok"` (Erfolg) bzw. `"auth_error"` (Connector nicht erreichbar) setzen. So zeigt das Dashboard „Termine heute frei" nur bei einem sauberen, fehlerfreien Lauf.

**b) Mail-Triage.** Siehe `~/.claude/skills/gws-gmail-triage/SKILL.md`.
```bash
gws gmail +triage --max 20 --format json
```
Read-only, nie Bodies laden (`+triage` liefert nur Absender/Betreff/Datum, das reicht). Du selbst klassifizierst die zurückgegebenen Betreffs anhand von Signalwörtern/Kontext in drei Buckets:
- **handeln**: braucht eine Aktion/Antwort des Nutzers (Anfragen, Fristen, direkte Fragen).
- **warten**: der Nutzer wartet auf jemand anderen (Status-Updates, "hier ist X", Bestätigungen ohne Rückfrage).
- **kenntnis**: reine Information, Newsletter, automatisierte Benachrichtigungen.
Zähler je Bucket setzen, `top` = die maximal 5 wichtigsten Betreffs (nicht alle, priorisiert nach Dringlichkeit), NIE den Mail-Body zitieren oder einbauen. Bei 0 ungelesenen Mails: alle Zähler 0, `top: []`.

**c) Fällige Deals.** Nur wenn das Vertriebsmodul eingerichtet ist. Quelle ist immer `~/.claude/dashboard/config.json`, niemals ein fest verdrahteter Wert aus diesem Skill-Text:

- `modules.sales.enabled` ist `false` oder die Datei fehlt → `"deals": {"available": false, "hint": "Vertriebsmodul nicht eingerichtet (/aios-dashboard setup)"}`.
- `modules.sales.pipeline.source` ist `"airtable"` → Airtable-MCP mit `base_id` und `table` aus `modules.sales.pipeline.airtable`. Die abzufragenden Feldnamen kommen aus `field_map` (`name`, `company`, `stage`, `next_step`, `due`). Query: Fälligkeitsfeld (`field_map.due`) <= heute (Operator `<=`, Datumsmodus `today`, Zeitzone `Europe/Berlin`).
- `source` ist `"file"` oder `"snapshot"` → keine Live-Abfrage, stattdessen `~/.claude/dashboard/data/sales.json` lesen und die Deals mit Fälligkeit <= heute übernehmen.

In `deals[]` NUR `name` (Deal-Name, Kundennamen hier ok), `next_step`, `faellig` übernehmen, keine Beträge, keine internen Notizen. Ist das MCP-Tool im Lauf nicht erreichbar (Fehler beim Aufruf): `"deals": {"available": false, "hint": "<Fehlermeldung/Grund>"}` schreiben, NICHT stillschweigend weglassen.

Danach `heute.json` mit `generated_at` (aktueller ISO-Zeitstempel) schreiben (Read+Write direkt, kein Collector-Skript nötig, da die Datenquellen live/MCP sind).

### 3. Dashboard-Refresh

```bash
bash ~/.claude/dashboard/collectors/refresh.sh
```
Aktualisiert `system-check.json`, `portfolio.json`, `vault-stats.json`, `usage.json`, `meta.json`. Fehler einzelner Collector brechen den Lauf nicht ab (siehe `meta.json`).

### 4. Slack-Essenz formulieren (harte Regeln)

Maximal **8 Zeilen**, Reihenfolge:
1. Falls `system-check.json` FAIL-Befunde enthält: JEDE FAIL-Zeile zuerst, je eine Zeile, kurz (Name + ein Halbsatz). Keine FAILs → diese Zeilen entfallen.
2. Danach die drei Kernpunkte des Tages, verdichtet aus: nächster Kalender-Termin oder "kein Termin heute", fällige/überfällige Deals (Anzahl + wichtigster Name), auffällige Portfolio-Ampeln aus `portfolio.json` (z. B. Projekte mit WARN/FAIL-Status oder lange kein Update).
3. Letzte Zeile: `Details: /aios-dashboard`

**Harte Inhalts-Regeln:** Nur Aggregat-Aussagen (Zahlen, Zähler, Kurzlabel), KEINE Vault-Zitate, KEINE Beträge/Preise, Kundennamen NUR wo fachlich nötig (Deal-Name ja: "Musterfirma fällig heute"; Details/Inhalte zum Deal NICHT ausschreiben). Kein Markdown-Fettdruck/Sternchen (Slack-DM soll direkt lesbar sein), keine Gedankenstriche, Umlaute ausgeschrieben.

### 5. Zustellung

**Default: Dry-Run.** Zeige den fertigen Slack-Text im Chat, mach KEINEN Versand. Sag explizit, dass es ein Dry-Run ist und wie der Nutzer den echten Versand auslöst ("send" als Argument, nach Freigabe).

**Bei Argument "send" UND vorheriger expliziter Freigabe im selben Gespräch:** sende den Text per Slack-MCP als Direktnachricht an den Nutzer selbst (Self-DM):
```
mcp__claude_ai_Slack__slack_send_message (an die eigene User-ID/DM des Nutzers, Text = die 8-Zeilen-Essenz)
```
Nach dem Versand kurz bestätigen ("Briefing an Slack gesendet."). Kein Versand an andere Channels/Personen, kein Versand ohne die beschriebene Freigabe-Bedingung.

## Wochen-Modus (Argument "weekly", zusätzlich zu 1-5)

Vor Schritt 4 (Slack-Essenz) zusätzlich:

### 6a. Vollcheck

```bash
bash ~/.claude/dashboard/collectors/check.sh full
```
Plus `claude doctor` headless (siehe `/system-check`-Skill für das genaue Vorgehen) und `/brain:health-check scheduled` anstoßen (Skill-Invocation), damit die Vault-Lint-Frische aktiv aufgefrischt wird. Ergebnisse fließen NUR als Einordnung in deine Chat-Antwort, nicht ins `system-check.json`-Schema (das bleibt dem Collector vorbehalten, siehe `/system-check`-Skill-Grenzen).

### 6b. Tuning-Signale sammeln

```bash
bash ~/.claude/dashboard/collectors/tuning-signals.sh 7
```
Schreibt `~/.claude/dashboard/data/tuning-signals.json` (deterministisch, reine Zählwerte: Sessions je Projekt, Skill-Aufrufe je Skill, Wrap-up-Quote je Projekt und gesamt, Fehler-Marker-Summen, ungenutzte Skills). Lies diese Datei.

### 6c. Empfehlungen ableiten

Aus `tuning-signals.json` **MAXIMAL DREI** Empfehlungen ableiten. Kriterien für Auswahl: die auffälligsten, am besten belegten Signale (z. B. deutlich abweichende Fehlerquote eines Projekts, sehr niedrige Wrap-up-Quote, größere Zahl ungenutzter Skills). Keine Empfehlung ohne konkrete Zahl aus den Signalen.

Jede Empfehlung:
- `id`: stabiler Slug aus der Beobachtung (z. B. `wrapup-quote-niedrig`), NIE aus einem Zeitstempel, damit Re-Runs dieselbe id erzeugen.
- `beobachtung`: ein Satz, was auffällt.
- `beleg`: die Zahl(en) aus den Signalen ("X trat N-mal auf", "Y von Z Sessions").
- `empfehlung`: was der Nutzer konkret tun könnte.
- `instruktion`: ein fertiger, copy-fertiger Instruktionsblock für eine neue Claude-Code-Session (mehrere Sätze, direkt einsetzbar als Prompt).
- `status`: `"open"` für neue Empfehlungen.

**Idempotenz (PFLICHT):** Bevor du schreibst, lies das bestehende `~/.claude/dashboard/data/recommendations.json` (falls vorhanden). Jede Empfehlung, deren `id` dort bereits mit `status: "dismissed"` oder `status: "done"` existiert, NIEMALS erneut vorschlagen oder überschreiben, auch wenn das Signal erneut auftritt, auch nicht mit `status: "open"`. Bestehende `open`-Einträge dürfen mit frischerem Beleg aktualisiert werden (gleiche id, aktualisierter `beleg`-Text), aber niemals ihren Status resetten.

Schema `~/.claude/dashboard/data/recommendations.json` (Server-Kontrakt, siehe `server.mjs`/`/api/recommendation/status`, das eine `recommendations`-Liste auf oberster Ebene erwartet):
```json
{
  "generated_at": "<ISO-8601>",
  "recommendations": [
    {"id": "...", "beobachtung": "...", "beleg": "...", "empfehlung": "...", "instruktion": "...", "status": "open"}
  ]
}
```

## Scheduled Task (noch nicht angelegt)

Dieser Skill legt selbst KEINEN Scheduled Task an. Siehe `~/.claude/dashboard/README.md`, Abschnitt "Briefing + Scheduling", für das spätere Vorgehen (`morning-briefing`-Task erst nach mindestens 5 manuellen Läufen und Freigabe durch den Nutzer).

## Grenzen (hart)

- Kein automatischer Slack-Versand ohne explizite Freigabe im selben Gespräch, niemals an andere Empfänger als die eigene DM des Nutzers.
- Keine Mail-Bodies lesen oder zitieren, nur Betreffs/Absender/Datum aus `+triage`.
- Keine Beträge, keine Vault-Zitate, keine internen Notizen in der Slack-Essenz.
- Kein Schreibzugriff auf STATE.md, kein Vault-Write, keine Änderungen an Deals/Airtable (nur lesen).
- Keine `dismissed`/`done`-Empfehlungen erneut vorschlagen oder ihren Status überschreiben.
- Bei fehlender Erreichbarkeit einer Quelle (gws, Airtable-MCP, Slack-MCP) NIE stillschweigend eine Sektion weglassen, immer `available:false` + Grund oder eine explizite Chat-Zeile.
