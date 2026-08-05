# PDF-Gotchas — HTML→PDF Render-Bugs und Workarounds

Konsolidiert aus Praxis-Learnings (Vault `cluster/common-gotchas`). Lade dieses File nur, wenn ein konkreter Render-Bug auftritt — nicht prophylaktisch.

## 1. Border-Radius schluckt Border-Color (Chromium)

**Symptom:** `border-radius` + Border zusammen rendert in `page.pdf()` mit Artefakten oder verschluckter Border-Farbe.

**Ursache:** Chromium-PDF-Engine hat Bug bei border-radius-Stacking ohne Background-Clip.

**Workaround (immer im Template-CSS drin):**
```css
.designer-page, .designer-slide, .designer-canvas {
  background-clip: padding-box;
  -webkit-background-clip: padding-box;
  transform: translateZ(0);  /* GPU-Layer erzwingen */
}
```

**Alternative wenn Workaround nicht hilft:** statt `page.pdf()` den Screenshot-Assembly-Pfad nutzen (`playwright-cli screenshot` pro Frame → `assemble-pdf.mjs`). Genau das ist der Default-Pfad hier, deshalb tritt der Bug selten auf.

## 2. Print-Emulation aendert Layout (Overflow erst sichtbar in PDF)

**Symptom:** Im Browser sieht alles passend aus, im PDF schneidet Content unten ab oder bricht in eine zweite Page.

**Ursache:** `@media print { ... }` greift nur in Print-Emulation. Default-Browser-Render zeigt Screen-Layout.

**Pre-Render-Check (Pflicht vor Screenshot):**

`file://` ist in playwright-cli blocked. Erst HTTP-Server starten:
```bash
PYBIN=python3
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN=python
$PYBIN -c "import sys" </dev/null >/dev/null 2>&1 || PYBIN="py -3"
cd "$(pwd)" && $PYBIN -m http.server 8765 &>/tmp/designer-http.log &
playwright-cli open "http://localhost:8765/build/<name>.html"
```
Unter Windows ist `python3` oft nur der Microsoft-Store-Stub (Exit-Code 49, keine Ausgabe): die drei Zeilen oben proben vorab den funktionierenden Interpreter (gleiches Muster wie `dashboard/collectors/python-bin.sh`).

Dann scrollHeight via eval pruefen:
```bash
playwright-cli eval "document.querySelectorAll('.designer-page, .designer-slide, .designer-canvas').forEach((el,i)=>{ if(el.scrollHeight>el.clientHeight) console.log('Frame '+(i+1)+' overflow: '+(el.scrollHeight-el.clientHeight)+'px'); });"
```

**Loesung:** Content kuerzen oder Long-Form-Template statt Single-Page.

## 3. Position-Override-Bug (Absolute Children werden Flex-Children)

**Symptom:** Glow-/Arc-Ornamente rutschen aus der Position, ueberlappen Content statt im Hintergrund zu liegen.

**Ursache (Lesson 2026-05-01):** Absolute-positionierte Ornamente (z.B. `.glow`-Klasse) werden in Flex-Container-Kontext als Flex-Children behandelt, wenn ihre Parent-Hierarchie nicht klar `position: relative` setzt.

**Workaround:**
```css
.designer-slide, .designer-page, .designer-canvas {
  position: relative;  /* PFLICHT — sonst rutschen Children */
  overflow: hidden;    /* Ornamente bleiben im Frame */
}
.designer-ornament, .glow {
  position: absolute;
  pointer-events: none;
}
```

**Beim Pre-Render prufen:** `.glow`/`.designer-ornament` sollte nicht in der Tab-Order und nicht klickbar sein.

## 4. Font-Settle vor Screenshot (FOUT/FOIT)

**Symptom:** Erstes PNG nutzt Fallback-Font, weil Google-Fonts noch nicht geladen waren.

**Workaround — Document-Fonts-Ready im Template + eval-Check:**

Im Template:
```html
<script>
  document.fonts.ready.then(() => document.body.classList.add('fonts-loaded'));
</script>
```

Vor Screenshot pruefen:
```bash
playwright-cli eval "document.body.classList.contains('fonts-loaded')"
# Erwartung: true. Wenn false: kurz warten und erneut.
```

**Pragmatischer Fallback:** `sleep 1` zwischen open und screenshot. Reicht in 95% der Faelle bei Google-Fonts.

## 5. Background-Gradients + PDF (Truncate/Banding)

**Symptom:** Radial-Gradients zeigen Banding im PDF, oder werden bei `background-attachment: fixed` abgeschnitten.

**Workaround:**
```css
.designer-ornament {
  background: radial-gradient(circle, var(--color-accent) 0%, transparent 75%);
  filter: blur(10px);  /* Banding kaschieren */
  background-attachment: scroll;  /* nie fixed in PDF */
}
```

## 6. SVG-Icons inline vs. extern

**Empfehlung:** SVG-Icons inline einbetten, nicht via `<img src="...svg">` referenzieren. PDF-Renderer hat manchmal SVG-File-Loading-Race-Conditions.

## 7. Page-Break-Disziplin (Multi-Page)

```css
.designer-page {
  page-break-after: always;
  break-after: page;  /* moderne Variante */
}
.designer-page:last-child {
  page-break-after: auto;
}
```

## 8. Pixel-Aufloesung vs. PDF-Page-Maße

playwright-cli's `screenshot` liefert PNGs in CSS-Pixel-Aufloesung des Selectors. `assemble-pdf.mjs` skaliert das PNG auf die `--format`-Maße in pt (z.B. 595×842 pt fuer A4) — die Page-Maße sind unabhaengig von der PNG-Pixel-Aufloesung.

**Folge:** Fuer 300dpi-Druck (Visitenkarte, A3-Poster) im Template größere Pixel-Maße setzen (z.B. A4 statt 794×1123 dann 2480×3508). Sonst sieht der Druck unscharf aus, obwohl PDF-Maße korrekt sind.

## 9. Multi-Page PDF mit unterschiedlichen Maßen (z.B. Cover + Content)

Aktuell out-of-scope. Alle Pages eines PDFs haben dieselben Maße. Wenn Mixed-Format gewuenscht: User soll zwei separate PDFs anfordern oder Cover als Single-Page-Image in das Multi-Page-Doc einbetten.
