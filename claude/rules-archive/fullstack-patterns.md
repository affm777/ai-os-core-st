---
description: Full-Stack Tech Stack Defaults, API Design, Testing Strategie und Projekt-Templates
---

# Full-Stack Development Patterns

## Tech Stack Preferences (falls nicht anders spezifiziert)

| Layer | Default | Alternativen |
|-------|---------|--------------|
| Frontend | Next.js + React | Astro (static), SvelteKit |
| Styling | Tailwind CSS | shadcn/ui für Components |
| Backend | Next.js API Routes | Hono (Edge), FastAPI (Python) |
| Database | PostgreSQL + Prisma | Supabase (BaaS), SQLite (local) |
| Auth | NextAuth.js | Clerk, Supabase Auth |
| Hosting | Vercel | Cloudflare, Railway |

## API Design

- REST für CRUD, WebSockets für Realtime
- Versionierung: `/api/v1/...`
- Rate Limiting immer implementieren
- Response-Format konsistent (envelope pattern)

## Testing Strategie

| Test-Typ | Wann | Tool |
|----------|------|------|
| Unit | Isolierte Funktionen | Vitest/Jest |
| Integration | API Endpoints | Playwright API |
| E2E | Kritische User Flows | Playwright |
| Security | Vor Release | OWASP ZAP, npm audit |

## Projekt-Templates

**Für neue Projekte sofort erstellen:**
```
PROJECT_ROOT/
├── CLAUDE.md          # Projekt-spezifische Anweisungen
├── .env.example       # Benötigte Env-Vars (ohne Werte)
├── .gitignore         # Secrets ausschließen
└── .planning/         # Planungs-Struktur (STATE.md) wenn komplex
```

## Session-Continuity

**Am Ende:** STATE.md aktualisieren (done, next steps, open questions)
**Am Anfang:** STATE.md lesen, Kontext wiederherstellen, Prioritäten bestätigen
