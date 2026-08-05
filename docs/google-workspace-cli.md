# Google Workspace CLI — Claude arbeitet direkt in deinen Google-Apps

Mit der Google Workspace CLI (`gws`) bekommt Claude einen direkten Draht zu Gmail, Kalender, Drive, Docs, Sheets, Slides und Tasks. Kein Connector-Umweg, kein Klicken in Oberflächen: Claude liest deine Termine, legt Dateien an, beantwortet Mails und baut Tabellen — über die offizielle Google-API.

Danach hast du 53 zusätzliche Skills in Claude Code, verteilt auf sieben Anwendungen.

Rechne mit 20 bis 30 Minuten. Der Google-Cloud-Teil ist der zähe Abschnitt, der Rest geht schnell.

---

## Was du brauchst

- **Ein Google-Konto**, mit dem du auf ein Google-Cloud-Projekt zugreifen darfst. Ein eigenes Projekt anzulegen reicht, das ist kostenlos.
- **Homebrew** auf dem Mac (hast du nach dem Bootstrap bereits).
- Rund 15 Minuten Geduld beim OAuth-Teil.

> **Wenn deine Domain zentral verwaltet wird:** In manchen Organisationen dürfen nur Administratoren OAuth-Clients anlegen oder externe Apps freigeben. Wenn du bei Schritt 3 an einer Freigabe hängen bleibst, brauchst du jemanden mit Administrationsrechten auf eurer Domain.

---

## Schritt 1 — Die CLI installieren

```bash
brew install googleworkspace-cli
```

Prüfen, ob es geklappt hat:

```bash
gws --version
```

Erwartet: eine Versionsnummer wie `gws 0.22.5`. Kommt `command not found`, ist Homebrew nicht in deinem PATH — dann hilft [troubleshooting.md](troubleshooting.md).

> **Unter Windows:** Es gibt keinen `brew`-Weg, `gws` wird stattdessen über npm installiert (Node.js ist über `windows/bootstrap.sh` bereits vorhanden):
> ```bash
> npm install -g @googleworkspace/cli
> gws --version
> ```
> Der Rest dieser Anleitung (Schritt 2 bis 6) läuft unter Windows identisch in Git Bash, mit einer Einschränkung: der `gws auth setup`-Ablauf aus Schritt 3 gilt in der Community als weniger robust unter Windows als unter macOS. Bricht er ohne verwertbare Fehlermeldung ab, hilft oft ein zweiter Versuch oder das manuelle Setup des OAuth-Clients direkt in der Google Cloud Console (siehe Google-eigene `gws`-Dokumentation, verlinkt unten). Klappt `gws` am Ende gar nicht: die Kalender-Kachel im Dashboard bleibt dann einfach leer, alle anderen Kacheln (System, Vault, Projekte) laufen unabhängig davon normal weiter, der zugehörige Collector degradiert sauber.

---

## Schritt 2 — Die gcloud CLI installieren

`gws` kann dein Google-Cloud-Projekt automatisch anlegen und konfigurieren. Dafür braucht es Googles eigene CLI.

```bash
brew install --cask google-cloud-sdk
```

> **Unter Windows** (in Git Bash):
> ```bash
> winget install --id Google.CloudSDK --accept-source-agreements --accept-package-agreements
> ```
> Danach Terminal komplett neu öffnen (siehe [windows/troubleshooting.md](windows/troubleshooting.md#3-befehl-nach-der-installation-nicht-gefunden)), damit `gcloud` im PATH auftaucht.

Danach einmal anmelden:

```bash
gcloud auth login
```

Es öffnet sich ein Browserfenster. Melde dich mit dem Google-Konto an, mit dem du arbeiten willst.

---

## Schritt 3 — `gws` mit deinem Google-Konto verbinden

Der einmalige Aufbau. Der Befehl legt ein Cloud-Projekt an, schaltet die nötigen APIs frei und meldet dich an:

```bash
gws auth setup
```

Danach die eigentliche Anmeldung mit Auswahl der Berechtigungen:

```bash
gws auth login -s gmail,calendar,drive,docs,sheets,slides,tasks
```

> **Die eine Stolperstelle:** Lass das `-s …` nicht weg. Ohne diese Einschränkung fragt `gws` die Voreinstellung `recommended` an, und die umfasst über 85 Berechtigungen. Google erlaubt einer nicht verifizierten App aber nur rund 25. Ohne `-s` bricht die Anmeldung also ab, und die Fehlermeldung sagt dir nicht, warum.

Im Browser wirst du eine Warnung sehen, dass die App nicht verifiziert ist. Das ist deine eigene App — über „Erweitert" kommst du weiter.

Falls Google dich abweist: Du musst dich in der Cloud Console im OAuth-Zustimmungsbildschirm **selbst als Testnutzer eintragen**. Ohne diesen Eintrag verweigert Google die Anmeldung, auch beim eigenen Projekt.

Verbindung testen:

```bash
gws calendar events list --params '{"calendarId": "primary", "maxResults": 3}'
```

Erwartet: JSON mit deinen nächsten Terminen.

---

## Schritt 4 — Die Skills erzeugen

Die CLI bringt die Skills nicht fertig mit, sie generiert sie aus den APIs deiner Version.

> **Achtung, echte Falle:** `gws generate-skills` kennt **kein** `--help`. Wer das anhängt, bekommt keine Hilfe angezeigt, sondern der Befehl läuft los und schreibt 95 Ordner ins aktuelle Verzeichnis. Führe ihn deshalb nur in einem leeren Ordner aus, den du danach wieder löschst.

```bash
mkdir -p ~/Desktop/gws-skills-temp
cd ~/Desktop/gws-skills-temp
gws generate-skills
```

Erwartet: `Done. Skills written to skills/` und darin 95 Unterordner. Davon brauchst du 53.

---

## Schritt 5 — Die relevanten Skills installieren

Jetzt übernimmt Claude. **Sag Claude** (im Chat von Claude Code, während du im Ordner `gws-skills-temp` bist):

```
Ich habe mit der Google Workspace CLI Skills generiert. Sie liegen in ./skills/ in meinem aktuellen Verzeichnis, es sind 95 Stück.

Kopiere daraus GENAU die folgenden 53 Ordner nach ~/.claude/skills/. Alle anderen lässt du liegen.

Querschnitt:
gws-shared

Gmail:
gws-gmail, gws-gmail-send, gws-gmail-read, gws-gmail-reply, gws-gmail-reply-all,
gws-gmail-forward, gws-gmail-triage, gws-gmail-watch,
recipe-create-gmail-filter, recipe-create-vacation-responder, recipe-draft-email-from-doc,
recipe-forward-labeled-emails, recipe-label-and-archive-emails,
recipe-save-email-attachments, recipe-save-email-to-doc

Kalender:
gws-calendar, gws-calendar-agenda, gws-calendar-insert,
recipe-batch-invite-to-event, recipe-block-focus-time, recipe-create-events-from-sheet,
recipe-find-free-time, recipe-plan-weekly-schedule, recipe-reschedule-meeting,
recipe-schedule-recurring-event, recipe-share-event-materials

Drive:
gws-drive, gws-drive-upload,
recipe-bulk-download-folder, recipe-create-shared-drive, recipe-email-drive-link,
recipe-find-large-files, recipe-organize-drive-folder, recipe-share-folder-with-team

Docs:
gws-docs, gws-docs-write,
recipe-create-doc-from-template, recipe-generate-report-from-sheet, recipe-share-doc-and-notify

Sheets:
gws-sheets, gws-sheets-read, gws-sheets-append,
recipe-backup-sheet-as-csv, recipe-compare-sheet-tabs, recipe-copy-sheet-for-new-month,
recipe-create-expense-tracker, recipe-log-deal-update

Slides:
gws-slides, recipe-create-presentation

Tasks:
gws-tasks, recipe-create-task-list, recipe-review-overdue-tasks

Zähle mir danach, wie viele Ordner tatsächlich in ~/.claude/skills/ angekommen sind, und nenne mir alle, die gefehlt haben.
```

Claude sollte 53 bestätigen. Kommt eine kleinere Zahl, fehlen Skills in deiner Generierung — meist, weil bei Schritt 3 eine Berechtigung nicht erteilt wurde.

Danach den Temp-Ordner wegräumen:

```bash
cd ~ && rm -rf ~/Desktop/gws-skills-temp
```

---

## Schritt 6 — Neu starten und ausprobieren

Claude Code beenden mit `/exit`, dann `claude` neu starten. Erst danach sind die Skills geladen.

Test im Chat:

```
Was steht diese Woche in meinem Kalender? Fasse es kurz zusammen.
```

Läuft das durch, bist du fertig.

---

## Aktualisieren

Die Skills sind eine Momentaufnahme deiner CLI-Version. Ein `brew upgrade googleworkspace-cli` aktualisiert **nur die CLI**, nicht die Skills — die bleiben auf dem alten Stand, bis du sie neu erzeugst.

Nach einem Upgrade also Schritt 4 und 5 wiederholen. Die alten Ordner in `~/.claude/skills/` werden dabei überschrieben.

---

## Wenn es nicht läuft

Häufigste Ursachen, in dieser Reihenfolge:

1. **Du bist nicht als Testnutzer eingetragen.** Der häufigste Abbruch bei der Anmeldung. Im OAuth-Zustimmungsbildschirm der Cloud Console nachtragen.
2. **`-s …` bei `gws auth login` vergessen.** Dann fragt die App zu viele Berechtigungen an und Google lehnt ab.
3. **`gcloud` fehlt oder ist nicht angemeldet.** `gws auth setup` bricht ohne brauchbare Meldung ab. Prüfen mit `gcloud auth list`.
4. **Skills erzeugt, aber nicht kopiert.** Schritt 4 lief, Schritt 5 nicht. Prüfen mit `ls ~/.claude/skills | grep -c gws`.
5. **Claude nicht neu gestartet.** Skills werden beim Start geladen, nicht währenddessen.

Alles andere: [troubleshooting.md](troubleshooting.md).

---

## Wo die Dateien liegen

```
~/.config/gws/        # deine Anmeldedaten, verschlüsselt
~/.claude/skills/     # die 53 Skills
```

Der Ordner `~/.config/gws/` enthält Zugangsdaten zu deinem Google-Konto. Er gehört nicht in ein Repository, nicht in eine Cloud-Synchronisation und in keinen Chat.
