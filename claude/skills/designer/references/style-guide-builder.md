# Style-Guide-Builder — Frage-Flow + Token-Schema

Diese Reference baut den `./STYLE-GUIDE.md` im Projekt-Root des Users. Output-Schema ist verbindlich: der Render-Mode des Designer-Skills liest exakt diese Slot-Namen.

## Output-Schema (Vertrag mit Render-Mode)

```yaml
---
project: "<name>"
version: 1
created: <YYYY-MM-DD>
brand_personality: ["<adj1>", "<adj2>", "<adj3>"]
---

# STYLE-GUIDE — <name>

## 1. Brand-Personality

<3-5 Adjektive ausformuliert in 1-2 Saetzen.>

## 2. Color-Tokens

| Token | Wert | Verwendung |
|---|---|---|
| `--color-bg` | `<hex>` | Page-Background |
| `--color-fg` | `<hex>` | Body-Text |
| `--color-primary` | `<hex>` | Headlines, primaere Akzente |
| `--color-secondary` | `<hex>` | Sekundaere Akzente, Subheads |
| `--color-accent` | `<hex>` | Highlights, CTAs, Italic-Inline |
| `--color-muted` | `<hex oder rgba>` | Captions, Meta, Timestamps |

## 3. Typography-Tokens

| Rolle | Font | Weight | Groesse |
|---|---|---|---|
| Heading | `<font-family>` | `<weight>` | h1 `<px>` / h2 `<px>` / h3 `<px>` / h4 `<px>` |
| Body | `<font-family>` | `<weight>` | `<px>` |
| Caption | `<font-family>` | `<weight>` | `<px>` |
| Mono | `<font-family>` | `<weight>` | `<px>` |

**Google Fonts Load-String:**
```
<URL>
```

## 4. Spacing + Layout

| Token | Wert | Notiz |
|---|---|---|
| `--space-base` | `<px>` | Basis-Einheit (4 oder 8) |
| `--gutter` | `<px>` | Abstand zwischen Spalten |
| `--max-width` | `<px>` | Content-Max-Width |
| `--radius-base` | `<px>` | Border-Radius Standard |
| `--radius-pill` | `999px` | Pill-Radius fuer Tags/Badges |

## 5. Komponenten-Patterns

### 5.1 Button (Primary)

```html
<button class="btn btn-primary">Action</button>
```
Token-Bindung: `background: var(--color-primary)`, `color: var(--color-bg)`, `padding: 12px 24px`, `border-radius: var(--radius-base)`.

### 5.2 Card

```html
<div class="card">...</div>
```
Token-Bindung: `background: var(--color-card-bg)`, `border: 1px solid var(--color-border)`, `padding: var(--space-base) calc(var(--space-base) * 3)`.

### 5.3 Quote-Block

```html
<blockquote>...</blockquote>
```
Token-Bindung: `border-left: 4px solid var(--color-accent)`, `padding-left: var(--gutter)`, `font-style: italic`.

### 5.4 Code-Block

```html
<pre><code>...</code></pre>
```
Token-Bindung: `background: var(--color-fg)`, `color: var(--color-bg)`, `font-family: var(--font-mono)`, `padding: var(--space-base)`.

## 6. Anti-Patterns

- Nie mehr als 3 Akzent-Farben kombinieren.
- Nie mehr als 2 Schriftfamilien (1 Heading + 1 Body, evtl. 1 Mono).
- Heading-Italic nur fuer den emotionalen Kern (max 1 pro Heading).
```

## Frage-Flow (B-Pfad, interaktiv)

Nutze AskUserQuestion. Eine Frage pro Aufruf, 3-4 Optionen + "Bin mir nicht sicher".

### Frage 1 — Brand-Personality

```
question: "Wie soll der Look sich anfuehlen?"
options:
  - "Editorial / ruhig / hochwertig (wie ein Magazin oder Geschaeftsbericht)"
  - "Tech / klar / strukturiert (wie ein SaaS-Dashboard)"
  - "Bold / Statement / Energie (wie eine Kampagne, ein Startup-Pitch)"
  - "Classic / formell / vertrauenswuerdig (wie eine Kanzlei, Beratung)"
  - "Bin mir nicht sicher"
```

Bei "nicht sicher": Folge-Frage offen "Beschreib mir 3 Marken/Webseiten, deren Look dir gefaellt." → daraus die Kategorie ableiten.

→ Mappt auf 3-5 Adjektive in `brand_personality`.

### Frage 2 — Farb-Stimmung

```
question: "Was ist die dominierende Farb-Stimmung?"
options:
  - "Warm Neutral (Beige/Cream/Off-White Hintergrund, Schwarz/Anthrazit Text, ein warmer Akzent wie Orange/Rot/Terracotta)"
  - "Cool Neutral (Weiss/Grau Hintergrund, Schwarz/Navy Text, kuehler Akzent wie Blau/Petrol/Mint)"
  - "Dark Mode (Schwarz/Anthrazit Hintergrund, hell, ein leuchtender Akzent wie Lime/Cyan/Magenta)"
  - "Erdig (gedaempfte Naturfarben, Olive/Rost/Ocker)"
  - "Mein Brand hat schon Farben — ich tippe sie ein"
```

Bei eigenen Farben: nach 6 Hex-Werten fragen (bg, fg, primary, secondary, accent, muted).

Bei Kategorie: schlage 3 konkrete Hex-Sets vor, User waehlt.

### Frage 3 — Typografie

```
question: "Welcher Typografie-Stil?"
options:
  - "Serif Headlines + Sans Body (klassisch editorial — z.B. Instrument Serif + Inter)"
  - "Sans Headlines + Sans Body (moderner Tech-Look — z.B. Inter + Inter, oder Geist + Geist)"
  - "Bold Display Headlines + Sans Body (Statement — z.B. Bricolage Grotesque + Inter)"
  - "Mono fuer alles (Developer/Technical-Look — z.B. JetBrains Mono)"
  - "Mein Brand hat schon Schriften — ich tippe sie ein"
```

→ Liefert die Google-Fonts-Load-URL gleich mit (kennt der Skill aus dem Mapping unten).

### Frage 4 — Spacing-Grundton

```
question: "Wie dicht oder grosszuegig soll das Layout sein?"
options:
  - "Grosszuegig / luftig (viel Whitespace, base 8px, max-width 720px)"
  - "Standard (base 8px, max-width 960px)"
  - "Kompakt / dicht (base 4px, max-width 1100px, kleine Margins)"
  - "Bin mir nicht sicher — nimm Standard"
```

### Frage 5 — Akzent-Charakter

```
question: "Wie aggressiv darf der Akzent eingesetzt werden?"
options:
  - "Sparsam (nur Highlights, Italic-Worte, Dots, Buttons)"
  - "Mittel (zusaetzlich fuer Tags, Timestamps, kleine Ornamente)"
  - "Bold (zusaetzlich fuer ganze Headline-Worte, grosse Flaechen, Glow-Elemente)"
```

→ Beeinflusst Komponenten-Patterns (Section 5).

## Font-Mapping (Quick-Reference)

| Kategorie | Heading | Body | Mono | Google-Fonts-URL |
|---|---|---|---|---|
| Editorial | Instrument Serif | Inter | JetBrains Mono | `https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Inter:wght@400;500;600;700&family=JetBrains+Mono&display=swap` |
| Tech | Inter | Inter | JetBrains Mono | `https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono&display=swap` |
| Bold Display | Bricolage Grotesque | Inter | JetBrains Mono | `https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:wght@400;700&family=Inter:wght@400;500;600;700&family=JetBrains+Mono&display=swap` |
| Mono | JetBrains Mono | JetBrains Mono | JetBrains Mono | `https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap` |

## Color-Set-Vorschlaege (Quick-Reference)

### Warm Neutral
- bg `#f4f1ea`, fg `#0f0f0f`, primary `#0f0f0f`, secondary `#1a1a1a`, accent `#ff4500`, muted `rgba(15,15,15,0.55)`

### Cool Neutral
- bg `#ffffff`, fg `#0a0a0a`, primary `#0a0a0a`, secondary `#404040`, accent `#0066ff`, muted `rgba(10,10,10,0.55)`

### Dark Mode
- bg `#0a0a0a`, fg `#fafafa`, primary `#fafafa`, secondary `#a3a3a3`, accent `#a3e635`, muted `rgba(250,250,250,0.55)`

### Erdig
- bg `#f5efe6`, fg `#2a2118`, primary `#2a2118`, secondary `#5a4a3a`, accent `#9d4b1c`, muted `rgba(42,33,24,0.55)`

## Update-Modus

User sagt "update style-guide" → lies die existierende `./STYLE-GUIDE.md`, erkenne welche Section geupdated werden soll, frage gezielt nur fuer diese Section. Nicht den ganzen Flow neu durchlaufen.
