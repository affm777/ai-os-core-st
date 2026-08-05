---
name: designer
description: Generiert druckreife Print-Dokumente, Slide-Decks, Social-Media-Visuals und Long-Form-Assets aus Markdown/Text als HTML→PDF/PNG. Nutzt einen projekt-eigenen STYLE-GUIDE.md als Single-Source-of-Truth fuer Farben/Typo/Layout (oder baut ihn interaktiv auf, wenn keiner existiert). Triggert wenn jemand sagt "bau mir einen Flyer/Report/Slide/LinkedIn-Post/Newsletter/Visitenkarte", "render das zu PDF", "designe mir ein A4/16:9/Reel", "wie sieht das gedruckt aus", "mach das druckreif", "exportiere zu PDF/PNG", oder "update style-guide".
when_to_use: |
  Trigger: Format-Begriffe (A4, Letter, A3-Poster, A5-Flyer, 16:9, 4:3, 9:16, LinkedIn-Post, LinkedIn-Carousel, LinkedIn-Banner, Instagram-Post, Instagram-Story, X-Card, Newsletter, Whitepaper, One-Pager, Visitenkarte, Postkarte, Reel) + Verben "render, exportiere, baue, designe, drucke, generiere PDF, mach mir ein". Auch wenn der User nur "mach mir mal schnell" sagt und vorher Inhalt geliefert hat. Nicht triggern bei UI/App/Component/Page-Anfragen, das gehoert zu landing-page-builder (Web-Code), nicht zu designer (Print/Social/Slide).
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(playwright-cli:*), Bash(node:*), Bash(npx:*), Bash(mkdir:*), Bash(ls:*), Bash(cp:*), Bash(python3:*), Bash(python:*), Bash(py:*), WebFetch
---

# Designer

Du verwandelst Text/Markdown in druckreife visuelle Deliverables: Print-Dokumente, Slide-Decks, Social-Visuals, Long-Form-Assets. Output ist HTML → PDF und/oder PNG. Browser-Steuerung delegierst du an `playwright-cli` (von Microsoft, liegt als separater Skill in `~/.claude/skills/playwright-cli/`). Du machst die Komposition.

## Drei Pfade — entscheide als erstes

| User-Intent | Pfad |
|---|---|
| "update style-guide" / "bau mir einen Style-Guide" | **Style-Guide-Mode** |
| Render-Wunsch + `./STYLE-GUIDE.md` fehlt | **Style-Guide-Aufbau** dann Render |
| Render-Wunsch + `./STYLE-GUIDE.md` existiert | **Render-Mode** |

Pruefe `./STYLE-GUIDE.md` immer im Projekt-Root des aktuellen Working Directory.

## Style-Guide-Mode (interaktiv)

Lade Frage-Flow + Token-Schema aus `references/style-guide-builder.md`. Schreibe das Ergebnis nach `./STYLE-GUIDE.md`. Frontmatter + 5 Sektionen Pflicht: Brand-Personality, Color-Tokens, Typography-Tokens, Spacing+Layout, Komponenten-Patterns. **Nie ohne References-File arbeiten — der Token-Schema-Slot-Name muss exakt stimmen, sonst broken Render.**

### Wie du fragst (HARTE REGEL)

Stelle jede der 5 Fragen aus `references/style-guide-builder.md` **mit dem AskUserQuestion-Tool** (Multiple-Choice-Pills im UI). Pro Frage ein eigener AskUserQuestion-Aufruf, in der Reihenfolge Brand-Personality → Farb-Stimmung → Typografie → Spacing → Akzent-Charakter.

**Verboten:**
- Freitext-Aufzählungen wie "a) ... b) ... c) ..." im Chat-Output. Das umgeht die Multiple-Choice-UI und erzeugt schlechtere User-Antworten.
- Eigene Bypass-Optionen wie "minimaler Default-Style-Guide", "Smoke-Test-Default", "schnelle Variante ohne Fragen". Solche Optionen stehen NICHT im References-File und sind nicht erlaubt.
- Mehrere Fragen in einem AskUserQuestion-Aufruf bündeln. Eine Frage pro Aufruf.

**Eine Ausnahme:** Wenn der User von sich aus explizit sagt "skip style-guide", "nimm einen Default", "keine Fragen jetzt", darfst du das Cool-Neutral-Default-Set aus `references/style-guide-builder.md` nehmen. Du sagst dann aber im Output explizit: "Kein Style-Guide-Builder gelaufen, ich habe Cool-Neutral-Default genommen. Du kannst später `update style-guide` aufrufen, um deinen echten Style-Guide aufzubauen."

Sample-Upload-Pfad (Inspo-Files multimodal lesen) ist v2-Backlog. Wenn der User Inspo-Files hochlaedt: kurz erklaeren "Sample-Upload kommt in v2, fuer jetzt nutze ich die Bilder als Referenz im Frage-Flow" und dann zur interaktiven Variante.

## Render-Mode

### Schritt 1 — Format klaeren

Wenn aus dem User-Prompt Format + Kategorie eindeutig sind (z.B. "A4-Report", "LinkedIn-Carousel"): direkt weiter.

Sonst AskUserQuestion mit den 5 Kategorien:
- Print-Document (A4/Letter/A3/A5/Flyer/Visitenkarte/Postkarte)
- Slide-Deck (16:9 / 4:3 / 9:16)
- Web/Social-Image (LinkedIn / Instagram / X)
- Long-Form (Newsletter / Sales-Angebot / Invoice / Whitepaper / One-Pager)
- Custom (User gibt Maße direkt)

Bei Custom: User-Maße in Pixel + Zielmedium erfragen (Print = 300dpi, Web = 96dpi).

Vollstaendige Maße-Tabelle: `references/format-catalog.md`. **Nur laden wenn unklar welche Pixelwerte zu einem Format gehoeren.**

### Schritt 2 — Content-Source klaeren

Drei Faelle:
- **Markdown-File:** User nennt Pfad → Read.
- **Freier Text:** User schreibt Content direkt in den Prompt → 1:1 uebernehmen.
- **Strukturierte Daten** (Slides mit mehreren Frames, Carousel mit mehreren Cards): User gibt entweder File oder strukturierten Inline-Block.

Bei Slide-Decks/Carousels: pro Frame eine Section im Source. Konvention: `## Slide 1 — Titel` / `## Card 1`.

### Schritt 3 — Frischer Build aus Template

**Frischer Build heisst: das vorhandene `./build/<name>.html` wird ueberschrieben, nicht gepatcht.**

1. `mkdir -p ./build ./out`
2. Template kopieren: `cp <skill-dir>/templates/<kategorie>/<format>.html ./build/<name>.html`
3. Tokens aus `./STYLE-GUIDE.md` lesen, in CSS-Vars im `<style>`-Block des Build-Files injizieren (Edit-Tool).
4. Content in Slot-Marker injizieren: `<!-- DESIGNER:TITLE -->`, `<!-- DESIGNER:CONTENT -->`, `<!-- DESIGNER:META -->` (siehe Template-Konvention unten).

Bei Custom-Format ohne passendes Template: bau ad-hoc ein minimales HTML-Skelett mit den gleichen Slot-Markern und Frame-Selectoren. Vorlage: kopiere das Template, das maßlich am naechsten ist, und passe nur die Geometrie an.

### Schritt 4 — HTTP-Server starten (file:// ist blocked)

playwright-cli oeffnet keine `file://`-URLs. Starte einen lokalen HTTP-Server im Projekt-Root:

```bash
PYBIN=python3
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN=python
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN="py -3"
cd "$(pwd)" && $PYBIN -m http.server 8765 &>/tmp/designer-http.log &
```

Unter Windows ist `python3` oft nur der Microsoft-Store-Stub (Exit-Code 49, keine Ausgabe, `command -v` findet ihn trotzdem): der Server läuft im Hintergrund, ein gescheiterter Start fällt sonst erst beim Verbindungsversuch in Schritt 5 auf. Die drei Zeilen oben proben deshalb vorab, welcher Interpreter tatsächlich läuft (gleiches Muster wie `dashboard/collectors/python-bin.sh`), statt erst nach einem Fehlschlag nachzubessern.

Merke dir die PID, killst du am Ende. Dann arbeitest du mit `http://localhost:8765/build/<name>.html`.

### Schritt 5 — Pre-Render-Check

```bash
playwright-cli open "http://localhost:8765/build/<name>.html"
playwright-cli eval "Array.from(document.querySelectorAll('.designer-page, .designer-slide, .designer-canvas')).map((el,i)=>{const kids=Array.from(el.children).filter(c=>getComputedStyle(c).position!=='absolute');const h=kids.reduce((m,c)=>Math.max(m,c.offsetTop+c.offsetHeight),0);return h>el.clientHeight ? 'Frame '+(i+1)+' overflow '+(h-el.clientHeight)+'px' : 'Frame '+(i+1)+' OK'})"
```

**Eval-Regeln (HARTE REGEL, kein Verstoss erlaubt):**
- `playwright-cli eval` erwartet eine **einzelne JavaScript-Expression**. **Kein Semikolon ausserhalb von Arrow-Function-Bodies.** Nicht `foo(); bar()` als zwei Statements. Nicht `document.fonts.ready.then(...); Array.from(...)`. Wenn du Font-Settle willst, mach das in einem **separaten** eval-Aufruf vorher.
- Verboten sind: top-level `;` zwischen Statements, top-level `var`/`let`/`const`, top-level `if`/`for`/`while`. Erlaubt sind: Array-Map mit Arrow-Bodies (die intern `;` enthalten duerfen), IIFE `(()=>{...})()`, ternaere Ausdruecke.
- Bei einem SyntaxError: nicht zwanghaft retry — die Expression umbauen.

**Absolute-Children-Filter:** Der Pre-Check oben ignoriert absolute-positionierte Children (`.designer-ornament` etc.), weil die per Definition aus dem Container ragen koennen ohne dass das ein Layout-Problem ist. Nur in-flow-Children zaehlen fuer Overflow.

Wenn ein Eintrag "Frame N overflow Xpx" zeigt: User informieren ("Frame 3 schneidet 142px ab — Content kuerzen oder Long-Form-Layout?"). Bei Werten unter 30px: meistens Rundungs-Rauschen, ignorieren.

Workarounds bei konkretem Bug: `references/pdf-gotchas.md` (border-radius, Position-Override, Font-Settle, Banding).

### Schritt 6 — Frame-Screenshots

Pro Frame ein PNG. Selector-Konvention je Kategorie:

| Kategorie | Frame-Selector |
|---|---|
| Print-Document | `.designer-page` (1-N pro Doc) |
| Slide-Deck | `.designer-slide` (N pro Deck) |
| Web/Social-Image | `.designer-canvas` (1 oder N bei Carousel) |
| Long-Form | `.designer-page` (N bei Multi-Page) |

Single-Frame:
```bash
playwright-cli screenshot ".designer-page" --filename "build/<name>-01.png"
```

Multi-Frame (z.B. 3 Slides) — pro Slide ein eigener Aufruf mit `:nth-of-type`:
```bash
playwright-cli screenshot ".designer-slide:nth-of-type(1)" --filename "build/<name>-01.png"
playwright-cli screenshot ".designer-slide:nth-of-type(2)" --filename "build/<name>-02.png"
playwright-cli screenshot ".designer-slide:nth-of-type(3)" --filename "build/<name>-03.png"
```

**Auflösung:** playwright-cli liefert PNGs in CSS-Pixel-Aufloesung des Selectors. Fuer Druck-Qualitaet (Visitenkarte, A3-Poster) im Template größere Pixel-Maße setzen (z.B. A4 als `794×1123` ist 96dpi — fuer 300dpi-Druck Template auf `2480×3508` skalieren oder Print-CSS-Inch-Maße nutzen). Fuer Web/Social und Standard-A4 reicht 96dpi.

**Font-Settle:** Wenn Web-Fonts geladen werden, kurz warten vor Screenshot. Sicherer Weg: im Template ein `<script>document.fonts.ready.then(()=>document.body.classList.add('fonts-loaded'))</script>` einbauen und vor screenshot mit `playwright-cli eval "document.body.classList.contains('fonts-loaded')"` pruefen, ggf. `playwright-cli wait` (oder `sleep 1` als Fallback).

### Schritt 7 — PDF- oder PNG-Output

Drei Wege. **Fuer Print-Document und Long-Form ist Vektor (Pfad B) der Standard** — scharf beim Zoomen, kleine Datei, Text suchbar/markierbar. **Slide-Deck default Raster (Pfad A)** (visuell komplex). **Web/Social = PNG.**

#### Pfad B — Vektor-PDF (STANDARD fuer Print-Document + Long-Form)

Chromium druckt direkt aus dem laufenden HTML. **Schritt 6 (Frame-Screenshots) entfällt hier als Render-Weg** — Vektor rendert ohne PNGs. Ein einzelner Screenshot der HTML-Vorstufe wird aber weiterhin für die Sichtprüfung gebraucht (siehe Pflicht-Check unten). Schritt 5 (Overflow-Check) bleibt Pflicht (ein überlaufender Frame splittet sonst auf zwei Seiten).

Voraussetzung im Build-HTML (sonst Split / fehlende Hintergruende): `@page{size:<A4|...>;margin:0}`, pro Frame `page-break-after:always;break-after:page` + feste `height:<seitenhoehe>` + `overflow:hidden` (letztes Frame `page-break-after:auto`), und `print-color-adjust:exact` (+ `-webkit-`) auf body/Frame. Die Templates `a4-report` und `newsletter` bringen das mit; bei eigenen Build-Erweiterungen selbst sicherstellen.

```bash
# HTTP-Server aus Schritt 4 muss laufen. Plattformneutral über Playwrights
# Node-API (kein System-Browser-Pfad, kein Channel-Lookup — nutzt das über
# `npx playwright install chromium` gebündelte Chromium):
node "$HOME/.claude/skills/designer/scripts/render-pdf.mjs" \
  --url "http://localhost:8765/build/<name>.html" \
  --output "./out/<name>.pdf" \
  --format A4
```

**Pflicht-Check nach Vektor-Render** (sonst still kaputt): strukturelle PDF-Prüfung PLUS Sichtprüfung. Sichtprüfung läuft über einen Playwright-Screenshot der HTML-Vorstufe (`playwright-cli screenshot`, siehe Schritt 6), nicht über direktes PDF-Öffnen (auf Windows fehlt poppler, das Read-Tool kann PDFs dort nicht anzeigen). Struktur-Check:
```bash
PYBIN=python3
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN=python
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN="py -3"
$PYBIN -c "import re;d=open('out/<name>.pdf','rb').read();print('Pages',len(re.findall(rb'/Type\s*/Page[^s]',d)));print('MediaBox',re.findall(rb'/MediaBox\s*\[([^\]]+)\]',d)[:1])"
```
Unter Windows ist `python3` oft nur der Microsoft-Store-Stub: die drei Zeilen oben lösen das auf denselben Interpreter auf, der schon in Schritt 4 funktioniert hat.

Pages == Frame-Zahl? MediaBox ~ Zielformat (A4 = `0 0 595 842`, Toleranz ±1pt)? Screenshot der HTML-Vorstufe sieht sauber aus (Hintergruende sichtbar, kein URL/Datum-Header, kein Inhalts-Split)? **Splittet/fehlt etwas → Pfad A (Fallback).**

#### Pfad A — Raster-Assembly (FALLBACK + Slide-Decks)

Wenn Pfad B Inhalte splittet / Hintergruende verliert, oder bei visuell komplexen Slide-Decks: Frame-Screenshots (Schritt 6) zu PDF assemblen.
```bash
node ~/.claude/skills/designer/scripts/assemble-pdf.mjs \
  --inputs "./build/<name>-*.png" \
  --output "./out/<name>.pdf" \
  --format <a4|letter|16-9|...>
```

#### PNG-Only (Web/Social-Image)
`./build/<name>-*.png` nach `./out/` kopieren mit aussagekraeftigen Namen.

### Schritt 8 — Cleanup + Bestaetigung

HTTP-Server killen (PID merken):
```bash
kill <pid> 2>/dev/null || true
playwright-cli close 2>/dev/null || true
```

Output-Pfad nennen. Bei Slide-Deck/Multi-Page: Anzahl Frames + Gesamt-PDF-Pages. User auf visuellen Check hinweisen ("Schau dir das PDF in Preview an, sag was nicht passt").

## Template-Konvention (Vertrag mit Stub-Files)

Jedes Template ist eine eigenstaendige HTML-Datei mit:

- `<body data-format="<format-key>">`
- Top-Level CSS-Vars im `<style>`-Block: `--color-primary, --color-bg, --color-fg, --color-accent, --color-muted, --font-heading, --font-body, --space-base, --radius-base, --max-width`
- Slot-Marker als HTML-Kommentare:
  - `<!-- DESIGNER:TITLE -->` (Pflicht in jedem Template)
  - `<!-- DESIGNER:CONTENT -->` (Pflicht)
  - `<!-- DESIGNER:META -->` (Optional: Datum/Author/Footer)
  - `<!-- DESIGNER:FRAMES -->` (Multi-Frame-Templates: Slide-Deck, Carousel — du replizierst die Frame-Struktur N-mal)
- Frame-Container mit Klasse `.designer-page` / `.designer-slide` / `.designer-canvas`
- `@media print { ... }` Block mit korrekten `@page`-Maßen — UND (Voraussetzung fuer Vektor-PDF / Pfad B in Schritt 7) pro Frame `page-break-after:always`/`break-after:page`, feste Seitenhoehe + `overflow:hidden`, sowie `print-color-adjust:exact` (+ `-webkit-`) auf body/Frame. Sonst splittet der Vektor-Export Inhalte oder verliert Hintergruende.
- Print-Gotcha-Workarounds bereits drin (background-clip, transform, font-smoothing)

**Templates enthalten KEINE Design-Entscheidungen** (keine konkreten Farben, Schriften, Logos). Nur Geometrie + Slots + CSS-Var-Hooks. Design kommt aus `./STYLE-GUIDE.md`.

**Erlaubte Template-Erweiterungen beim Render:** Wenn der Content eigenstaendige Bauteile braucht, die im Template nicht vorgesehen sind (Stat-Tiles, Cover-Layout, Hint-Listen, Section-Title-Hierarchien, Tabellen-Badges), darfst du sie in das `./build/<name>.html` einfuegen. Bedingung: sie nutzen **nur die existierenden CSS-Vars aus dem Style-Guide** (keine eigenen Farben/Schriften, keine `#hexCodes`, keine `font-family: "Foo"` ohne Var-Hook). Sag im Output-Verhalten kurz "Cover + Stat-Tiles + Lese-Hinweise eingefuegt", damit der User weiss was du dazuerfunden hast. Das Template selbst (`<skill-dir>/templates/...`) wird dabei NICHT veraendert — nur das einmalige Build-File.

## Trigger-Disziplin (Anti-Doppelung mit landing-page-builder)

Du triggerst auf: Print, PDF, Slide, Deck, Flyer, Report, Social-Image, Carousel, Newsletter, Visitenkarte, Poster, Reel, Banner, Card.

Du triggerst NICHT auf: UI, Component, Page (im Sinn von Web-Page-App), App, Frontend, Tailwind, React, Next, Button, Form, Login, Dashboard, Landingpage, Website. Diese gehoeren zu `landing-page-builder` (baut lebenden Web-Code, liest dieselbe STYLE-GUIDE.md wie du).

Wenn unklar: Frage einmal kurz "Print/Social oder Web-Seite?" und delegiere bei Web an `landing-page-builder`.

## Skill-Selbst-Lokation

Die Templates und Skripte liegen relativ zu diesem SKILL.md unter `<skill-dir>/templates/` und `<skill-dir>/scripts/`. `<skill-dir>` ist `~/.claude/skills/designer/` nach Bootstrap-Install. Wenn du den Pfad brauchst und unsicher bist:

```bash
ls ~/.claude/skills/designer/templates/
```

## Runtime-Deps (assemble-pdf.mjs braucht pdf-lib, render-pdf.mjs braucht playwright)

Voraussetzung: Node 22+ (`assemble-pdf.mjs` importiert `glob` aus `node:fs/promises`, das gibt es erst ab Node 22).

`bootstrap.sh` installiert die Node-Deps automatisch beim Skill-Copy. Falls beim ersten Render-Lauf `pdf-lib`- oder `playwright`-Module fehlen (Skill manuell kopiert, kein Bootstrap-Run):

```bash
cd ~/.claude/skills/designer && npm install --silent
```

Prüfe `~/.claude/skills/designer/node_modules/pdf-lib/` einmalig vor dem ersten PDF-Assembly. `render-pdf.mjs` braucht zusätzlich das gebündelte Chromium; fehlt es, meldet das Skript selbst den Nachhol-Befehl `npx playwright install chromium` (auch von `bootstrap.sh` bereits erledigt).

## Was du nicht tust

- Du schreibst keine Design-Entscheidungen in `./STYLE-GUIDE.md` ohne den User zu fragen — Source-of-Truth-Disziplin.
- Du baust kein neues Template-Format ohne Slot-Marker-Vertrag — sonst broken Render bei naechstem Rebuild.
- **Output landet IMMER in `./out/`. Nicht in `./exports/`, `./output/`, `./pdf/`, oder einem anderen erfundenen Pfad.** Wenn der User explizit einen anderen Pfad nennt: nutze diesen und nenne ihn im Output. Aber niemals eigenmaechtig `./out/` umbenennen.
- Du nutzt nicht WebFetch fuer Inspo-Sample-Upload (das ist v2-Backlog).

## Output-Verhalten

Sag dem User in 1 Satz welchen Pfad du gewaehlt hast (Style-Guide-Mode / Render). Bei Render: nenne Format + Anzahl Frames + Output-Pfad. Bei scrollHeight-Warning: konkret "Frame 3 schneidet 142px unten ab — willst du den Content kuerzen oder Long-Form-Layout statt Slide?"

**Accent-Targets-Hinweis:** Wenn der gerenderte Content keine Akzent-Targets nutzt (kein `*kursiv*`/`em`, kein `[Link]`, kein `> Blockquote`, kein `<span class="accent">`) → sag dem User am Ende explizit: "Style-Guide ist angewendet, aber dein Content nutzt keine Akzent-Elemente. Darum sieht das Resultat sehr schwarz/weiß aus. Wenn du den Akzent visuell sehen willst, fuege Italic/Links/Blockquotes ein." Verhindert dass der User "leerer Style-Guide" annimmt obwohl er greift.

Erfolg ist nicht "Render lief durch" sondern "PDF sieht in Preview druckreif aus, der User nickt". Bei Zweifel: visuellen Check anfordern.
