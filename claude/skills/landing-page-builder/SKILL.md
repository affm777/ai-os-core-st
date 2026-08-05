---
name: landing-page-builder
description: Baut lauffaehige, produktionsreife Web-Seiten, Landingpages und Web-UI als echten HTML/CSS/JS-Code (oder React/Vue), der nicht nach generischem "AI-Slop" aussieht. Liest eine projekt-eigene STYLE-GUIDE.md im aktuellen Verzeichnis als Brand-Token-Quelle (Farben, Fonts), wenn vorhanden, sonst leitet er einen distinctive Archetyp ab. Triggert bei "bau mir eine Landingpage", "Webseite bauen", "Hero-Section", "Marketing-Page", "Web-Komponente", "Landing fuer X", "render die Seite im Browser".
when_to_use: |
  Trigger: Landingpage, Landing-Page, Webseite, Website, Marketing-Page, Hero-Section, Pricing-Page, Web-UI, Web-Komponente, Web-App-Seite, HTML-Seite, "bau/designe/render mir eine Seite/Landing/Website", React/Vue/Next/Tailwind-Komponente fuer eine Seite. Auch wenn der User vorher Content geliefert hat und "mach daraus eine Landingpage" sagt.
  NICHT triggern bei: Print/PDF/Slide/Flyer/Carousel/Social-Image/Newsletter (das ist der `designer`-Skill). Bei reinem Datei-Visual zu `designer` delegieren.
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(playwright-cli:*), Bash(python3:*), Bash(python:*), Bash(py:*), Bash(node:*), Bash(npx:*), Bash(mkdir:*), Bash(ls:*), Bash(cp:*), Bash(open:*), Bash(powershell.exe:*)
---

# Landing-Page-Builder

Du baust **lauffaehige, lebende Web-Seiten**: HTML/CSS/JS oder Framework-Code, der im Browser laeuft, responsive ist und interaktiv. Nicht statische Render-Bilder (das ist `designer`). Dein Output ist Code plus optionaler Browser-Screenshot-Check.

## Scope-Abgrenzung (zuerst pruefen)

| User will | Pfad |
|---|---|
| Landingpage, Website, Web-UI, Hero, Pricing, Marketing-Seite, Web-Komponente | **Dieser Skill** |
| Flyer, Report, Slide-Deck, LinkedIn-Carousel, Social-Image, Newsletter-PDF | An `designer`-Skill delegieren |
| Unklar (Web-Seite oder Datei-Visual?) | Einmal kurz fragen, dann routen |

## Schritt 1 — Brand-Token-Quelle klaeren

Pruefe `./STYLE-GUIDE.md` im aktuellen Working-Directory (auch `./style/STYLE-GUIDE.md`).

- **STYLE-GUIDE.md existiert:** Lies die Farb-Tokens und Typografie-Tokens daraus. Das sind die verbindlichen Brand-Farben und Fonts. Du schreibst KEINE eigenen Hex-Werte oder Fonts fest, du nutzt die aus dem Guide. Layout-Idiome (Responsive, Motion, States) kommen aus der Best-Practice-Referenz (Schritt 2), denn ein print/social STYLE-GUIDE deckt Web-Layout nicht ab.
- **Kein STYLE-GUIDE.md:** Du leitest Archetyp, Font-Pairing und Palette aus der Best-Practice-Referenz ab (Schritt 2 + 3). Biete dem User optional an, danach via `designer`-Skill ("update style-guide") einen echten Style-Guide aufzubauen.

## Schritt 2 — Best Practices laden

Lies `references/web-design-best-practices.md` (relativ zu diesem SKILL.md). Das ist die SoT fuer Archetypen, distinctive Fonts (Inter-Verbot), Type-Scale, 8px-Raster, Motion, Komponenten-States, Accessibility und die AI-Slop-Anti-Patterns. Pflicht vor jedem Build.

## Schritt 3 — Pre-Code: Archetyp und Job-To-Be-Done

Bevor du Code schreibst, lege fest und nenne es im Output:
1. **Archetyp** (aus der Referenz-Tabelle) plus ein Satz Begruendung.
2. **Job-To-Be-Done** (Conversion / Utility / Delight) plus daraus die Layout-Strategie.
3. **Font-Pairing** und **Farbpalette** mit Hex-Werten. Bei STYLE-GUIDE.md: die Tokens von dort, nicht erfinden.

## Schritt 4 — Bauen

Schreibe vollstaendigen, lauffaehigen Code:
- Default: eine eigenstaendige `index.html` mit eingebettetem `<style>` und `<script>` (CSS-only-Motion bevorzugt). Bei explizitem Framework-Wunsch React/Vue/Next entsprechend.
- CSS-Variablen fuer alle Tokens im `:root`. Fonts via Google-Fonts-`<link>` im `<head>`.
- Mobile-first, responsive, alle interaktiven States (Hover/Focus/Active/Disabled), WCAG-AA-Kontrast, semantisches HTML, Lucide-Icons statt Emojis.
- Komplexitaet an die Vision koppeln: Maximalismus braucht aufwendige Effekte, Minimalismus braucht Praezision. Keine Inter/Roboto-Defaults, kein Purple-on-White.

Output-Ort: Default `./` (Projekt-Root, z.B. `index.html`) oder ein vom User genannter Pfad. Bei Multi-File-Build (Framework) ein sinnvolles `./web/` oder vom User genanntes Verzeichnis. Nenne den Pfad im Output.

## Schritt 5 — Browser-Check (Pflicht bei sichtbarem UI)

Verifiziere visuell, bevor du "fertig" sagst (siehe globale CLAUDE.md-Regel "Verifikation mit Playwright"). Browser-Steuerung via `playwright-cli` (separater Skill).

`file://` ist geblockt, also lokalen HTTP-Server starten:
```bash
PYBIN=python3
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN=python
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN="py -3"
cd "$(pwd)" && $PYBIN -m http.server 8765 &>/tmp/lpb-http.log &
```
Unter Windows ist `python3` oft nur der Microsoft-Store-Stub (Exit-Code 49, keine Ausgabe): der Server läuft im Hintergrund, daher proben die drei Zeilen oben vorab den funktionierenden Interpreter (gleiches Muster wie `dashboard/collectors/python-bin.sh`), statt erst nach einem stillen Fehlschlag nachzubessern.

PID merken. Dann:
```bash
playwright-cli open "http://localhost:8765/index.html"
playwright-cli screenshot "body" --filename "/tmp/lpb-desktop.png"
```
Fuer Responsive-Check Viewport auf Mobile verkleinern (falls playwright-cli `resize` unterstuetzt) und erneut screenshotten. Screenshot visuell pruefen, bei Layout-Problemen iterativ fixen (Fix, Screenshot, Verify). Screenshots danach loeschen (globale Regel). Server am Ende killen:

Soll die fertige Seite zusätzlich manuell im Standard-Browser geöffnet werden: macOS `open index.html`, unter Windows (Git Bash) `powershell.exe -NoProfile -Command Start-Process 'index.html'`.
```bash
kill <pid> 2>/dev/null || true; playwright-cli close 2>/dev/null || true
```

## Schritt 6 — Output-Verhalten

Nenne: gewaehlter Archetyp + Begruendung, Font-Pairing, Palette (Hex), Layout-Strategie in einem Satz, Output-Pfad. Bei STYLE-GUIDE-Nutzung: sag explizit "Brand-Tokens aus STYLE-GUIDE.md uebernommen". Bei abgeleiteter Palette ohne Guide: sag, dass kein Style-Guide vorlag und biete den `designer`-"update style-guide"-Pfad an.

## Was du nicht tust

- Keine statischen PDF/PNG-Render (das ist `designer`). Du baust lebenden Web-Code.
- Keine eigenen Brand-Farben/Fonts festschreiben, wenn eine STYLE-GUIDE.md existiert. Eine Quelle, kein Duplikat.
- Keine Inter/Roboto/Open-Sans-Defaults, kein generisches Purple-on-White. Anti-Pattern-Check aus der Referenz vor "fertig".
- Den `designer`-Skill nicht duplizieren: Print/Social bleibt dort, du machst nur Web.
