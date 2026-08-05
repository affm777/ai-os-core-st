---
title: "Learning: {{title}}"
created_date: {{date:YYYY-MM-DD}}
type: learning
status: done
tags:
  - type/learning
  - project/SLUG-HIER
aliases: []
topics: []
---

<!--
CAPTURE WENN: Ein Bug/Gotcha wurde geloest und koennte beim naechsten Frischblick
erneut auftauchen, ODER ein Pattern wurde erstmals erfolgreich bestaetigt.
NICHT WENN: Standard-API-Nutzung, Code-Pattern das in der Codebase selbst steht,
oder Fix-Rezept das in die Commit-Message gehoert.
STRUKTUR: Context (was war das Problem) | Pattern/Solution (was funktioniert)
          | Why (warum funktioniert es) | When to Apply (wann wieder relevant).
CLUSTER-TAG: Darf beim Capture gesetzt werden, WENN die Zuordnung eindeutig ist
(klares Thema, passender Slug aus 00_Meta/clusters/vault-clusters.md, Ziel-Projekt ist
clustered oder scope ist cross-project). Bei Unsicherheit leer lassen —
/brain:sort-inbox ergaenzt beim Einsortieren. Flat-Projekte bekommen keinen cluster-Tag.
TOPICS: semantische Schlagworte als Array, freitext und granularer als Cluster
(z.B. "pg_dump", "upsert-conflict"). Fuer grep / Dedup-Check und cross-cluster-Suche.
-->

## Context

[Was war das Problem oder die Situation? Kurz, konkret.]

## Pattern / Solution

[Was funktioniert konkret? Code-Snippet, Config-Schnipsel, Vorgehensweise.]

## Why

[Warum funktioniert das? Nicht nur dass es funktioniert.]

## When to Apply

[In welchen Szenarien wird das wieder relevant?]
