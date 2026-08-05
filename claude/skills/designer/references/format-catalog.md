# Format-Catalog — Maße fuer alle Formate

Pixel-Werte sind fuer `device-scale-factor 1`. Beim Render: scale-factor 2 (Standard) oder 3 (Print-Qualitaet).

## Print-Document (300 DPI implizit ueber scale-factor 3 oder Print-Emulation)

| Format | Maße (mm) | Maße (px @96dpi) | @page CSS | Template |
|---|---|---|---|---|
| A4-Portrait | 210 × 297 | 794 × 1123 | `@page { size: A4; }` | `print-document/a4-report.html` |
| A4-Landscape | 297 × 210 | 1123 × 794 | `@page { size: A4 landscape; }` | a4-report (rotated) |
| Letter | 216 × 279 | 816 × 1056 | `@page { size: letter; }` | letter-report (Custom) |
| A3-Poster | 297 × 420 | 1123 × 1587 | `@page { size: A3; }` | Custom |
| A5-Flyer | 148 × 210 | 559 × 794 | `@page { size: A5; }` | Custom |
| DL-Flyer | 99 × 210 | 374 × 794 | `@page { size: 99mm 210mm; }` | Custom |
| Visitenkarte | 85 × 55 | 321 × 208 | `@page { size: 85mm 55mm; margin: 0; }` | Custom |
| Postkarte | 148 × 105 | 559 × 397 | `@page { size: 148mm 105mm; }` | Custom |

## Slide-Deck

| Format | Maße (px) | Aspect | Template |
|---|---|---|---|
| 16:9 Standard | 1920 × 1080 | 1.778 | `slide-deck/16-9.html` |
| 4:3 Klassik | 1440 × 1080 | 1.333 | Custom (16-9 als Basis) |
| 9:16 Vertical (Reel/Story) | 1080 × 1920 | 0.563 | Custom |

## Web/Social-Image

| Format | Maße (px) | Notiz | Template |
|---|---|---|---|
| LinkedIn-Post | 1200 × 627 | Single Image | `web-social/linkedin-post.html` |
| LinkedIn-Carousel-Card | 1080 × 1080 | 1:1, Multi-Card | Custom (linkedin-post als Basis) |
| LinkedIn-Banner | 1584 × 396 | Profil-Header | Custom |
| Instagram-Post | 1080 × 1080 | 1:1 | Custom |
| Instagram-Story | 1080 × 1920 | 9:16 | Custom |
| Instagram-Reel-Cover | 1080 × 1920 | 9:16 | Custom |
| X-Card / OG-Image | 1200 × 630 | OpenGraph-Standard | Custom |
| YouTube-Thumbnail | 1280 × 720 | 16:9 | Custom |
| Pinterest-Pin | 1000 × 1500 | 2:3 | Custom |

## Long-Form

| Format | Maße | Notiz | Template |
|---|---|---|---|
| Newsletter (Email) | 600 × N | Email-Standard, max-width 600px | `long-form/newsletter.html` |
| Newsletter (Web) | 800 × N | Web-Lesen | newsletter (max-width auf 800) |
| One-Pager (A4) | 210 × 297 mm | A4-Portrait | a4-report |
| Whitepaper (A4) | 210 × 297 mm | Multi-Page A4 | a4-report |
| Sales-Angebot (A4) | 210 × 297 mm | Multi-Page A4 mit Cover | a4-report |
| Invoice (A4) | 210 × 297 mm | A4-Portrait, Tabellen-fokussiert | Custom |

## Custom-Format-Pattern

Wenn der User Maße direkt nennt (z.B. "Eventbrite-Cover 2160×1080"):

1. Kategorie raten (Web/Social wenn Pixel-Maße + Web-Kontext, Print wenn mm/cm).
2. Naechstliegendes Template als Basis nehmen.
3. Im Build-File: `<body style="width: <X>px; height: <Y>px; ...">` setzen, `@page` raus oder anpassen.
4. `device-scale-factor 2` (Web) oder `3` (Print).
5. Frame-Selector beibehalten (`.designer-canvas` fuer Single-Page, `.designer-page` fuer Multi).

## Multi-Frame-Konvention

| Output | Frames pro File | Selector | PDF-Assembly noetig |
|---|---|---|---|
| A4-Single-Page | 1 | `.designer-page` | Nein (ein PNG → PDF konvertieren) |
| A4-Multi-Page | N | `.designer-page:nth-of-type(i)` | Ja |
| 16:9-Slide-Deck | N | `.designer-slide:nth-of-type(i)` | Ja |
| LinkedIn-Carousel | N | `.designer-canvas:nth-of-type(i)` | Optional (PDF oder einzelne PNGs) |
| Single-Social-Image | 1 | `.designer-canvas` | Nein (PNG-Output) |

## DPI-Empfehlungen

| Endmedium | scale-factor | Begruendung |
|---|---|---|
| Web/Social | 2 | Retina-Displays, kein Druck |
| Office-Druck (A4-Report Home) | 2 | Reicht fuer Tonerlaserdrucker |
| Druckerei (Visitenkarte, A3-Poster) | 3 | 300 DPI-Standard |
| Slide-Deck (Beamer/Bildschirm) | 2 | 1080p oder 4K-Display |
