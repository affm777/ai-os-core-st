# Web-Design Best Practices (Referenz fuer landing-page-builder)

Struktur und Tokens fuer den Bau von Web-UI, Landingpages und Web-Apps. Liefert das, was generische Web-Generierung vermissen laesst: Archetyp-Disziplin, distinctive Fonts, Type-Scale, 8px-Raster, Motion, States, Anti-AI-Slop.

**Token-Quelle:** Wenn das Projekt eine `./STYLE-GUIDE.md` hat, kommen Farben und Fonts VON DORT (nicht aus dieser Datei). Diese Datei liefert dann nur die Web-Layout-Prinzipien (Responsive, Motion, States, Hierarchie). Ohne Style-Guide leitest du Palette und Fonts aus den Tabellen hier ab.

---

## 1. Pre-Code: Archetyp und Job-To-Be-Done

### Design-Archetyp (einen waehlen, konsequent durchziehen)

| Archetyp | Charakter | Font-Richtung (distinctive) | Farb-Richtung |
|---|---|---|---|
| SaaS/Tech | clean, systematisch, vertrauensbildend | Space Grotesk, Plus Jakarta Sans, Geist | cool neutrals, ein Akzent |
| Luxury/Editorial | hoher Kontrast, ruhig, edel | Playfair Display, Cormorant, Fraunces, Instrument Serif | gedeckte Erdtoene, Creme/Anthrazit |
| Brutalist/Dev | roh, bewusst kantig, monospace | JetBrains Mono, IBM Plex Mono | harter Kontrast, Primaerfarben |
| Playful/Consumer | rund, freundlich, zugaenglich | Outfit, Nunito, Quicksand | gesaettigt, multi-color |
| Corporate/Enterprise | konservativ, autoritaer, barrierearm | Source Sans 3, Noto Sans, Libre Franklin | Navy, Forest, Burgundy als Anker |
| Creative/Portfolio | experimentell, asymmetrisch, einpraegsam | Syne, Clash Display, Cabinet Grotesk | mutig oder monochrom extrem |

Klare konzeptionelle Richtung waehlen und mit Praezision ausfuehren. Mutiger Maximalismus und reduzierter Minimalismus funktionieren beide. Entscheidend ist Intentionalitaet, nicht Intensitaet. Nie ueber mehrere Builds auf denselben Default konvergieren (z.B. nicht reflexartig Space Grotesk).

### Job-To-Be-Done (bestimmt Layout-Strategie)

| Kontext | Ziel | Layout-Strategie |
|---|---|---|
| Conversion/Landing | ueberzeugen, ein klarer CTA | Hero, Value-Prop, Social-Proof, CTA. F-Pattern, klare Hierarchie, wenige CTAs |
| Utility/Dashboard | scannen, handeln | Informationsdichte, minimaler Chrome, Cards |
| Delight/Brand | begeistern | scroll-driven Storytelling, immersiv |

---

## 2. Typografie

### Font-Wahl (haerteste AI-Slop-Regel)

**NIEMALS:** Inter, Roboto, Open Sans, Lato, Arial, Helvetica, system-ui als Default. Das ist die Nummer-1-Signatur fuer "generisch KI-generiert".

**STATTDESSEN:** eine distinctive Schrift aus der Archetyp-Tabelle. Display-Font mit Charakter plus ruhiger Body-Font paaren. Wenn STYLE-GUIDE.md existiert: dessen Fonts nehmen (auch wenn dort Inter als Body steht, das ist dann eine bewusste Brand-Entscheidung, kein Slop). Per Google Fonts im `<head>` importieren:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=[FONT]:wght@400;500;600;700&display=swap" rel="stylesheet">
```

### Type-Scale (starker Kontrast, nicht inkrementell)

Modulare Skala mit deutlichem Sprung zwischen Body und Headline. Beispiel: 14 / 16 / 20 / 32 / 56 / 72 px. Kleiner Body, massive Headlines.

| Rolle | Groesse | Line-Height |
|---|---|---|
| Body | 16px | 1.5 |
| Body small | 14px | 1.45 |
| Sub | 20px | 1.4 |
| H2 | 32px | 1.2 |
| H1 | 48-56px | 1.1 |
| Display/Hero | 72-120px | 1.0-1.05 |

Zeilenlaenge 45-75 Zeichen (Optimum 65), Textspalten nie breiter als 800px. Headlines `letter-spacing: -0.02em`, Labels/Caps `+0.05em` bis `+0.1em`. Maximal 2 Schriftarten, 3-4 Gewichte, 4 sichtbare Hierarchie-Stufen pro View.

---

## 3. Farbe

**NIEMALS:** reines `#FFFFFF` als einzige Flaeche plus generisches Blau (`#3B82F6`) oder Violett-Gradient als Primaer. Das ist die zweite AI-Slop-Signatur (purple-on-white).

**STATTDESSEN** (falls keine STYLE-GUIDE.md, sonst dortige Tokens): auf eine Palette-Richtung committen.

- Off-Whites: `#FAFAFA`, `#F5F5F4`, `#FBF9F7` (warm) oder `#F8FAFC` (cool). Cards auf reinem `#FFFFFF` heben sich dann ab.
- Off-Blacks: `#0A0A0A`, `#171717`, `#1C1917`. Dark-Mode mit Rich-Blacks (`#0C0C0C` bis `#121212`), nie washed-out Grau.
- Palette-Richtungen: Warm-Minimal (Creme, Terracotta, Anthrazit), Cool-Tech (Slate, Cyan-Akzent, Near-Black), Paper/Editorial (Sepia, Tinten-Schwarz, roter Akzent).

### 60-30-10-Regel

60% dominante Flaeche, 30% Sekundaer (Content-Flaechen, Text), 10% genau ein Akzent (CTAs, Links, Highlights). Nie mehr als 3 Hauptfarben plus 2 Grautoene. Dominante Farben mit scharfen Akzenten schlagen zaghafte, gleichverteilte Paletten.

---

## 4. Spacing, Layout, Responsive

### 8px-Raster (strikt)

Vielfache: 4, 8, 12, 16, 24, 32, 48, 64, 96, 128. Keine willkuerlichen Werte (nie 13px, 37px, 50px).

| Token | Wert |
|---|---|
| `--space-2` | 8px |
| `--space-4` | 16px |
| `--space-6` | 24px (Standard Card-Padding) |
| `--space-8` | 32px |
| `--space-12` | 48px (Sektions-Trennung) |
| `--space-16` | 64px |
| `--space-24` | 96px (Page-Level-Trennung) |

### Whitespace und Breite

- Negativraum zwischen Sektionen: 96px+ auf Desktop. Enge Layouts wirken billig.
- Max Content-Width: 1280px Marketing, 1440px Dashboard, 720px textlastig.
- 12-Spalten-Grid bewusst brechen: asymmetrische Splits (7/5, 8/4) erzeugen Spannung, wirken handgemacht. Overlap und diagonaler Fluss erlaubt.

### Responsive (Mobile-First)

```css
@media (min-width: 640px)  { /* sm */ }
@media (min-width: 768px)  { /* md */ }
@media (min-width: 1024px) { /* lg */ }
@media (min-width: 1280px) { /* xl */ }
```

---

## 5. Interaktion, Motion, Komponenten

### Motion-Philosophie

| Kontext | Ansatz | Timing |
|---|---|---|
| Landing/Marketing | gestaffelte Reveals, scroll-triggered, cinematic | 300-500ms ease-out |
| Dashboard/App | snappy Micro-Interactions, sofortiges Feedback | 100-200ms |
| Hover | subtiler Lift plus Shadow | 200ms ease |

High-Impact statt verstreut: ein gut orchestrierter Page-Load mit gestaffelten Reveals (`animation-delay`) wirkt staerker als zehn beliebige Micro-Interactions. CSS-only fuer HTML bevorzugen, Motion-Library fuer React wenn verfuegbar. `prefers-reduced-motion` respektieren.

### Tactile Feedback

```css
.interactive { transition: transform 0.2s ease, box-shadow 0.2s ease; }
.interactive:hover  { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,0.12); }
.interactive:active { transform: translateY(0) scale(0.98); }
```

### Komponenten-Pflichten

- **Buttons:** alle States (Default, Hover, Focus, Active, Disabled). Padding 12px 24px, Min-Height 44px (Touch).
- **Cards:** EIN Border-Radius im ganzen Design (8, 12 oder 16px, nie mischen). Shadow subtil (`0 1px 3px rgba(0,0,0,0.08)`), nie ueber 15% Opacity. Cards einer Gruppe gleiche Breite/Hoehe, Primaer-Card groesser fuer Hierarchie (nie alle identisch).
- **Forms:** Labels UEBER dem Input, nie Placeholder als Label-Ersatz. Input-Padding 12-16px. Focus `2px solid [Akzent]`, Error rote Border plus Meldung unter dem Feld.
- **Nav:** Sidebar ODER Topbar, nie beides. Max 7 Items. Sticky-Nav darf auf Mobile keinen Content verdecken.

---

## 6. Anti-Patterns (AI-Slop-Check vor "fertig")

NIEMALS:
- Reines `#FFFFFF` plus generisches Blau/Violett als einzige Farbe.
- Inter/Roboto/Open Sans/Arial als Default-Font.
- Gradient-Backgrounds im Stripe-2020-Stil, Rainbow-Gradient-Text.
- Floating Blobs/Orbs als sinnlose Deko (ausser explizit gewuenscht).
- Default "Hero mit Laptop-Mockup".
- Card-Grids ohne visuelle Hierarchie (alle identisch).
- Sticky-Nav die auf Mobile Content verdeckt.
- Mehr als 3 verschiedene Border-Radii, Schatten ueber 15% Opacity, willkuerliches Spacing ausserhalb 8px-Raster.
- 3D-Charts, ALL-CAPS ueber 3 Woerter, zentrierte lange Absaetze.

STATTDESSEN: intentionale Palette mit Off-Whites, asymmetrische Layouts, starker Type-Scale-Kontrast, grosszuegiger Whitespace, echte Icons (Lucide), Motion nur wo sie UX verbessert.

---

## 7. Icons und Accessibility

### Icons: Lucide (keine Emojis als UI-Elemente)

```html
<script src="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"></script>
<script>lucide.createIcons();</script>
<!-- <i data-lucide="arrow-right"></i> -->
```
Outlined, 1.5px Stroke. Nie Outline und Filled mischen. 20px inline, 24px in Cards, 32px Feature.

### Accessibility (WCAG 2.2 AA, immer)

| Anforderung | Wert |
|---|---|
| Kontrast Body (< 18px) | 4.5:1 |
| Kontrast grosser Text (>= 18px Bold / 24px) | 3:1 |
| Touch-Target | 44 x 44px |
| Fokus-Ring | sichtbar, `2px solid [Akzent]`, 2px Offset |
| Semantik | `<button>`, `<nav>`, `<main>`, `<section>` korrekt |
| Bilder/Icon-Buttons | Alt-Text, `aria-label` |

---

## 8. Output-Format (beim Generieren nennen)

1. Gewaehlter **Archetyp** plus ein Satz Begruendung.
2. **Font-Pairing** und **Farbpalette** (Hex). Bei STYLE-GUIDE.md: "Tokens aus STYLE-GUIDE.md".
3. **Layout-Strategie** in einem Satz.
4. Dann vollstaendiger, lauffaehiger Code.

Komplexitaet an die aesthetische Vision koppeln. Eleganz entsteht durch saubere Ausfuehrung der Vision, nicht durch Effekt-Masse.
