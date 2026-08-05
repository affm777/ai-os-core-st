# Troubleshooting — AI Operating System

Die zwei häufigsten Stolpersteine, jeweils mit Fix.

---

## 1) Routine in der Claude Desktop App scheitert am Zugriff auf den Second Brain (nur macOS)

**Symptom:** Du hast in der **Claude Desktop App** eine Routine angelegt, z.B. für `/brain:sync-meetings`. Das Anlegen klappt, aber beim Ausführen kommt ein Fehler, dass auf den Second-Brain-Ordner (`~/Documents/Second-Brain/`) nicht zugegriffen werden kann. **Im Terminal** (Claude Code / Cursor) läuft dieselbe Routine problemlos.

**Ursache (in >90 % der Fälle):** macOS schirmt Apps über sein Datenschutz-System (TCC) vom `~/Documents`-Ordner ab. Dein Terminal hat diesen Zugriff meist längst, die Claude Desktop App als eigenständige App aber noch nicht. Deshalb die Asymmetrie: Terminal ja, Desktop App nein.

### Fix 1: Der Claude Desktop App Zugriff auf den Dokumente-Ordner geben (Regelfall)

1. **Systemeinstellungen** öffnen (Apfel-Menü oben links).
2. Links **Datenschutz & Sicherheit** wählen, dann **Dateien & Ordner** öffnen.
3. In der Liste die App **Claude** finden (mit dem Anthropic-Stern-Icon, das ist die Desktop App).
4. Den Schalter für **Ordner „Dokumente"** einschalten (dein Second Brain liegt unter `~/Documents`).
5. Die Claude Desktop App **komplett beenden und neu starten** (Cmd+Q, nicht nur Fenster schließen).
6. Routine erneut mit **„Run now"** testen.

Hinweis: In „Dateien & Ordner" gibt es **kein Plus-Symbol** zum Hinzufügen. Apps erscheinen hier automatisch, sobald sie einmal Zugriff angefragt haben. Falls **Claude** noch nicht in der Liste steht, führe die Routine einmal aus, macOS fragt dann nach dem Zugriff, danach taucht der Eintrag mit dem Schalter auf.

### Fix 2: Zugriff in den Settings hinterlegen (falls Fix 1 nicht reicht)

Gib Claude einfach den folgenden Befehl. Die Instruktion für die Änderung an der `settings.json` steckt schon drin, Claude erledigt sie für dich:

```
Bitte trage in meiner ~/.claude/settings.json unter permissions.allow die beiden Einträge Read(~/Documents/Second-Brain/**) und Edit(~/Documents/Second-Brain/**) ein und starte neu.
```

---

## 2) `/remote-control` startet nicht

**Symptom:** Der Befehl `/remote-control` taucht im Slash-Command-Dropdown gar nicht auf, oder er wird angezeigt, lässt sich aber nicht starten.

**Ursache:** Der Eintrag `"DISABLE_TELEMETRY": "1"` im `env`-Block von `~/.claude/settings.json` kann das auslösen. Er schaltet nicht nur die Telemetrie ab (anonyme Nutzungsdaten an Anthropic, ursprünglich aus Datenschutzgründen deaktiviert), sondern auch die Feature-Flag-Auswertung, über die Remote Control seine Verfügbarkeit prüft. Deswegen entfernen wir ihn an dieser Stelle.

**Fix:** Gib Claude einfach den folgenden Befehl. Die Instruktion steckt schon drin, Claude ändert die `settings.json` für dich:

```
Bitte entferne den Eintrag DISABLE_TELEMETRY aus dem env-Block meiner ~/.claude/settings.json.
```

Danach die Session einmal neu starten: `exit` (falls du mitten in der Arbeit warst, vorher `/wrap-up`), dann eine neue Session starten. Jetzt wird `/remote-control` angezeigt und lässt sich starten.

---

## Noch ein Problem?

Falls keine der obigen Lösungen hilft: Terminal-Output oder Fehlermeldung an Affom schicken.
