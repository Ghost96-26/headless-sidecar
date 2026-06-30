# Headless Sidecar 🏍️ — Ein iPad automatisch als Hauptbildschirm für einen Mac mit defektem Display nutzen

> **In einem Satz**: Defektes MacBook-Display? iPad anstecken, und direkt nach der Anmeldung **verbindet es sich automatisch per Sidecar und macht das iPad zum alleinigen Hauptbildschirm** — kein manuelles Klicken durchs Kontrollzentrum mehr. Gebaut für Macs ohne Kopf / mit defektem internem Display.

[![Platform](https://img.shields.io/badge/platform-macOS%2010.15%2B-blue)]()
[![Shell](https://img.shields.io/badge/shell-bash-green)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

**🌐 语言 / Language / Sprache:** [中文](README.md) · [English](README.en.md) · **Deutsch**

---

## 📑 Inhaltsverzeichnis
- [Welches Problem es löst](#-welches-problem-es-löst)
- [Wichtige Voraussetzungen & Grenzen (zuerst lesen)](#️-wichtige-voraussetzungen--grenzen-zuerst-lesen)
- [Funktionsweise](#-funktionsweise)
- [Schnellstart (anfängerfreundlich)](#-schnellstart-anfängerfreundlich)
- [Selbsttest: doctor](#-selbsttest-doctor)
- [Konfiguration](#️-konfiguration)
- [Wie es intern läuft (für Entwickler)](#-wie-es-intern-läuft-für-entwickler)
- [FAQ](#-faq)
- [Deinstallation](#-deinstallation)
- [Danksagung & Abhängigkeiten](#-danksagung--abhängigkeiten)
- [Lizenz](#-lizenz)

---

## 🎯 Welches Problem es löst

Viele haben ein MacBook mit gesprungenem / wassergeschädigtem / kabeldefektem Display, das ansonsten noch einwandfrei läuft. Es an ein iPad anzuschließen und **Sidecar** als Bildschirm zu nutzen, ist die günstigste Wiederbelebung — doch das native Sidecar hat Schmerzpunkte:

- Man muss jedes Mal **manuell** auf **Kontrollzentrum → Bildschirmsynchronisierung → iPad** klicken;
- Mit defektem Display sieht man nichts und kann nicht klicken;
- Selbst nach dem Verbinden **bleibt der Hauptbildschirm (Menüleiste / Dock) auf dem defekten internen Display** — alles ist verschoben.

Dieses Tool **automatisiert** die gesamte Abfolge „nach der Anmeldung" vollständig: iPad erkennen → Sidecar automatisch verbinden → iPad zum alleinigen Hauptbildschirm machen → das defekte interne Display trennen.

---

## ⚠️ Wichtige Voraussetzungen & Grenzen (zuerst lesen)

1. **Der Anmeldebildschirm lässt sich nicht umgehen.** Sidecar funktioniert nur **nach der Anmeldung am Schreibtisch**. Beim Passwort-Prompt nach dem Start ist das iPad also noch schwarz, und du musst das **Passwort blind eingeben**. Was dieses Tool automatisiert, ist alles „nach der Anmeldung".
   > Soll auch der Anmeldebildschirm sichtbar sein? Dann brauchst du ein **echtes externes Display** (HDMI-Monitor / TV / Display-Dongle / AR-Brille wie Xreal). Für dieses Szenario braucht man dieses Tool nicht.
2. **Sidecars harte Voraussetzungen müssen erfüllt sein:**
   - Mac und iPad **mit derselben Apple-ID** angemeldet, beide mit Zwei-Faktor-Authentifizierung;
   - Bei beiden **Bluetooth + WLAN** an (der Handshake nutzt sie selbst über USB-C) und Handoff aktiviert;
   - Modell und Betriebssystem erfüllen Apples Sidecar-Anforderungen (macOS 10.15+ / iPadOS 13+).
3. **Es hängt von zwei Drittanbieter-Tools ab** (der Installer holt sie automatisch):
   - [SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher): startet eine Sidecar-Verbindung über die Kommandozeile (nutzt eine private API, **kann bei macOS-Updates kaputtgehen**);
   - [BetterDisplay](https://github.com/waydabber/BetterDisplay): setzt den Hauptbildschirm und trennt das interne Display.
4. **Die Ersteinrichtung braucht einmal ein sichtbares Bild**: um Berechtigungen zu erteilen, BetterDisplays „Beim Anmelden öffnen" anzuhaken usw. Mach das, solange das Display noch funktioniert, oder leih dir einmal einen externen Monitor/TV/Dongle — danach gilt es dauerhaft.

---

## 🔧 Funktionsweise

```
       Start → Passwort blind eingeben zum Anmelden (iPad noch schwarz, dieser Schritt nicht automatisierbar)
                         │
                         ▼
   LaunchAgent startet nach der Anmeldung den Daemon (daemon.sh)
                         │  leichtgewichtige ioreg-Prüfung alle 5s
                         ▼
            iPad per USB angesteckt?
                         │ ja
                         ▼
        SidecarLauncher connect "iPad" -wired   ← Verbindung initiieren
                         │
                         ▼
        BetterDisplay: ① iPad als Hauptbildschirm setzen
                       ② das defekte interne Display trennen   ← arrange.sh
                         │
                         ▼
            iPad = alleiniger Hauptbildschirm, Menüleiste / Dock am Platz ✅
```

Design-Highlights:
- **Leichtgewichtig & energieschonend**: nutzt `ioreg` statt `system_profiler`, Abfrage alle 5s mit vernachlässigbarem Akkueinfluss; nach dem Verbinden werden Aktionen nicht wiederholt.
- **Keine UI-Automation**: nutzt das SidecarLauncher-Binary statt AppleScript-Klicks im Kontrollzentrum und umgeht so die wackelige „Bedienungshilfen"-Berechtigung unter launchd.
- **Modellübergreifend adaptiv**: iPad-Name, UUIDs von Sidecar- / internem Display werden alle **zur Laufzeit automatisch erkannt** — nichts ist fest codiert.
- **Alles über UUID gesteuert**: In BetterDisplay heißt der Sidecar-Bildschirm tatsächlich `Sidecar Display` (nicht `iPad`); daher erfolgen das Setzen des Hauptbildschirms und Statusprüfungen alle über die UUID, um Namensabgleich zu vermeiden, der auf echter Hardware fehlschlägt.
- **Fehler-Backoff + Abkühlung (gibt nie auf)**: Verbindungsfehler werden exponentiell zurückgestellt (4→8→… begrenzt durch `BACKOFF_MAX`); nach `FAIL_LIMIT` aufeinanderfolgenden Fehlern geht es in eine Abkühlphase und warnt nur einmal, statt das Log zu fluten — **versucht es aber im `BACKOFF_MAX`-Intervall weiterhin still und stellt sich automatisch wieder her, sobald es verbindet**.
- **Lieferketten-Sicherheit**: Abhängigkeiten werden aus **fest gepinnten Versionen mit eingebauter, verpflichtender sha256-Prüfung** installiert (SidecarLauncher `1.2` / BetterDisplay `v4.3.4`); ein Fingerprint-Unterschied bricht die Installation ab. Die Quarantäne wird **nur** beim verifizierten SidecarLauncher entfernt; BetterDisplay überlässt man Gatekeeper. Zum Überspringen der Prüfung (nicht empfohlen) `ALLOW_UNVERIFIED=1` setzen.
- **Desktop-Benachrichtigungen**: zeigt eine macOS-Benachrichtigung, wenn das Setzen des Hauptbildschirms gelingt oder wenn es wiederholt fehlschlägt (so kennst du das Ergebnis auch bei totem Display).
- **Log-Rotation**: `run.log` wird rotiert, sobald es `MAX_LOG_BYTES` überschreitet, damit ein dauerhaft laufender Daemon es nicht aufbläht.
- **Robusteres Parsen**: bevorzugt `jq` zum Parsen der BetterDisplay-Ausgabe und fällt auf `awk` zurück, wenn `jq` fehlt.

---

## 🚀 Schnellstart (anfängerfreundlich)

> Folge einfach Schritt für Schritt; kopiere die Befehle ins Terminal.

### Schritt 0: Stelle zuerst sicher, dass du etwas siehst
Wenn das Display defekt ist, schließe vorübergehend etwas Anzeigefähiges an (HDMI-Monitor / TV / USB-C-Dongle / AR-Brille), damit du den macOS-Schreibtisch zur Einrichtung sehen kannst.

### Schritt 1: Bestätige, dass Sidecar selbst funktioniert (30-Sekunden-Test von Hand)
Klicke oben rechts auf **Kontrollzentrum → Bildschirmsynchronisierung**, prüfe, ob dein iPad gelistet ist, klicke darauf und bestätige, dass das iPad zu einem erweiterten Display wird.
> Keine Verbindung? Behebe zuerst die Ursache: dieselbe Apple-ID, Bluetooth/WLAN an, iPad entsperrt. **Scheitert dieser Schritt, nützt auch die Automation nichts.**

### Schritt 2: Dieses Projekt herunterladen
```bash
git clone https://github.com/Ghost96-26/headless-sidecar.git
cd headless-sidecar
```

### Schritt 3: Installation mit einem Befehl
```bash
chmod +x install.sh
./install.sh
```
Der Installer lädt automatisch SidecarLauncher herunter, installiert BetterDisplay, erzeugt die Konfiguration, richtet den Autostart ein und führt einen Selbsttest aus.

### Schritt 4: Zwei manuelle Bestätigungen abschließen (wichtig)
1. Öffne **BetterDisplay** (beim ersten Start werden Berechtigungen abgefragt — alle erlauben) → Einstellungen → hake **Launch at login (Beim Anmelden öffnen)** an.
   - Empfohlen wird, zusätzlich **„Auto-disconnect built-in screen upon connecting an external display"** anzuhaken (Apple Silicon).
2. Falls der Selbsttest das iPad nicht gefunden hat: prüfe dieselbe Apple-ID / Bluetooth / WLAN / iPad entsperrt.

### Schritt 5: Überprüfen
Stecke das iPad an (ein USB-C-Kabel ist am zuverlässigsten), warte ein paar Sekunden, und das iPad sollte automatisch zum Hauptbildschirm werden. Oder manuell ausführen:
```bash
./src/doctor.sh          # Selbsttest
tail -f logs/run.log     # Daemon-Log beobachten
```

### Schritt 6: Neustart-Test
Starte den Mac neu (während das externe Display noch angeschlossen ist), melde dich an, indem du das Passwort blind eingibst, und das iPad sollte automatisch erscheinen. Sobald es funktioniert, kannst du das vorübergehende externe Display entfernen und im Alltag nur das iPad anstecken.

---

## 🩺 Selbsttest: doctor

Führe bei jeder Fehlersuche zuerst dies aus:
```bash
./src/doctor.sh
```
Es prüft und gibt farbig aus: macOS-Version, Chip/Modell, SidecarLauncher, BetterDisplay, iPad-Verbindung, Konfiguration, Autostart-Status — mit gezielten Empfehlungen.

---

## ⚙️ Konfiguration

Kopiere das Beispiel und passe es bei Bedarf an (es funktioniert auch ohne Änderungen; standardmäßig wird alles automatisch erkannt):
```bash
cp config.example.sh config.sh
```

| Option | Standard | Beschreibung |
|---|---|---|
| `IPAD_NAME` | leer (auto-erkannt) | iPad-Gerätename; bei mehreren iPads ausdrücklich setzen |
| `POLL_INTERVAL` | `5` | Abfrageintervall des Daemons (Sekunden) |
| `DISABLE_BUILTIN` | `auto` | `auto`/`off`: ob das interne Display per Skript getrennt wird |
| `BUILTIN_UUID` | leer (auto-erkannt) | UUID des internen Displays; manuell setzen, wenn die Erkennung daneben liegt |
| `SIDECAR_WIRED` | `on` | Ob kabelgebundenes Sidecar erzwungen wird (stabiler) |
| `NOTIFY` | `on` | Ob bei Erfolg / Fehler eine macOS-Benachrichtigung erscheint |
| `MAX_LOG_BYTES` | `1048576` | Schwelle für Log-Rotation (Bytes) |
| `BACKOFF_MAX` | `60` | Obergrenze des Backoffs bei Verbindungsfehlern (Sekunden) |
| `FAIL_LIMIT` | `5` | Aufeinanderfolgende Fehler bis zur Abkühlphase und Warnung |
| `SIDECAR_SHA256` / `BD_SHA256` | leer | Optional: Integrität der Abhängigkeits-Binärdateien bei der Installation prüfen |

> `config.sh` enthält deine persönlichen Daten; es wird von `.gitignore` ignoriert und nie hochgeladen.

---

## 🛠 Wie es intern läuft (für Entwickler)

```
headless-sidecar/
├── install.sh                 # Installation mit einem Befehl: Abhängigkeiten + Konfig + Autostart + Selbsttest
├── uninstall.sh               # Autostart entfernen, internes Display wiederherstellen
├── config.example.sh          # Konfigurationsvorlage (Nutzer kopieren sie zu config.sh)
├── launchagent/
│   └── com.headless-sidecar.daemon.plist.template  # Autostart-Vorlage (mit Platzhaltern)
└── src/
    ├── common.sh              # gemeinsame Funktionen + Auto-Erkennung (iPad-Name / interne UUID / Pfade)
    ├── daemon.sh              # Daemon-Schleife: erkennen → verbinden → Hauptbildschirm setzen
    ├── arrange.sh             # iPad als Hauptbildschirm setzen + internes Display trennen
    └── doctor.sh              # schreibgeschützter Selbsttest
```

**Wichtige Auto-Erkennungslogik (`src/common.sh`)**
- `detect_ipad_name`: liest zuerst `config.sh`, andernfalls das erste Gerät aus `SidecarLauncher devices`.
- `detect_sidecar_uuid`: findet aus `BetterDisplay get --identifiers` die UUID des Displays, dessen name/productName `Sidecar` enthält.
- `detect_builtin_uuid`: trifft anhand interner Panel-Merkmale — registryLocation enthält `disp0@` und nicht `dispext`, oder productName ist `Color LCD`, oder der Name enthält `Built-in`.
- Das obige Parsen bevorzugt `jq` (umschließt die Ausgabe mit `[]` zu einem gültigen JSON-Array) und fällt auf `awk` zurück, wenn `jq` fehlt.
- `ipad_plugged`: `ioreg -p IOUSB`, das `USB Product Name` mit „iPad" präzise abgleicht (um Fehltreffer bei Hub-/Lesegerät-Beschreibungen zu vermeiden).
- `sidecar_active` / `sidecar_is_main`: beide anhand der UUID des Sidecar-Displays beurteilt, nicht anhand des Namens.

**Autostart**: `install.sh` ersetzt `__DAEMON_PATH__` / `__LOG_DIR__` in der Vorlage durch echte Pfade, schreibt
`~/Library/LaunchAgents/com.headless-sidecar.daemon.plist` und bevorzugt das moderne `launchctl bootstrap gui/$UID` (mit Rückfall auf das ältere `launchctl load`). `RunAtLoad + KeepAlive` halten es nach der Anmeldung resident.

**Warum kein AppleScript-Klick im Kontrollzentrum?** Osascript unter launchd die „Bedienungshilfen"-Berechtigung zu erteilen, ist sehr unzuverlässig (macOS lehnt mit `-1719 Not allowed to send Apple events` ab). Mit dem SidecarLauncher-Binary braucht das Initiieren einer Verbindung gar keine UI-Berechtigung.

**Mitwirken**: PRs willkommen. Stelle nach Skriptänderungen sicher, dass `bash -n` und `shellcheck` durchlaufen (CI führt `.github/workflows/ci.yml` aus), und führe `./src/doctor.sh` einmal auf echter Hardware aus. Kompatibilitätsberichte über Modelle / macOS-Versionen sind besonders willkommen (bitte `sw_vers`, `uname -m`, `hw.model` anhängen).

---

## ❓ FAQ

**F: Kann beim Start sogar der Anmeldebildschirm auf dem iPad angezeigt werden?**
A: Nein. Sidecar ist eine Fähigkeit nach der Anmeldung — das ist eine Apple-Einschränkung, die keine Software umgeht. Für volle Sichtbarkeit nutze ein echtes externes Display / Dongle / AR-Brille.

**F: SidecarLauncher läuft nicht / Verbindung schlägt fehl?**
A: Es nutzt eine private API und kann über große macOS-Versionen hinweg kaputtgehen. Beobachte das [Upstream-Repo](https://github.com/Ocasio-J/SidecarLauncher) für Updates; dieses Tool bevorzugt die Version unter deinem `bin/`.

**F: Das iPad ist verbunden, aber der Hauptbildschirm wechselte nicht?**
A: Höchstwahrscheinlich läuft BetterDisplay nicht im Hintergrund. Öffne es und aktiviere Launch at login; oder führe `./src/doctor.sh` für Hinweise aus.

**F: Das interne Display wird nicht erkannt / nicht getrennt?**
A: Führe `BetterDisplay get --identifiers` aus, finde die UUID des internen Displays und trage sie in `config.sh` unter `BUILTIN_UUID` ein; oder nutze einfach BetterDisplays Schalter „auto-disconnect built-in screen" (Apple Silicon).

**F: Funktioniert es auf Intel-Macs?**
A: Ja. Sidecar-Verbindung und das Setzen des Hauptbildschirms funktionieren beide, aber „internes Display automatisch trennen" verhält sich auf Intel anders — nutze einen Dongle oder die Skript-Trennung.

**F: Verbraucht es viel Strom? Schadet es dem Gerät?**
A: Nein. `ioreg`-Prüfungen sind extrem leicht, einmal alle 5s, mit vernachlässigbarem Akkueinfluss und ohne Auswirkung auf die Hardware-Lebensdauer.

---

## 🧹 Deinstallation
```bash
./uninstall.sh
```
Es stoppt und entfernt den Autostart, beendet den Daemon, versucht die interne Display-Verbindung wiederherzustellen und löscht Logs. `BetterDisplay.app` und `bin/SidecarLauncher` werden **nicht** gelöscht — entferne sie bei Bedarf manuell.

---

## 🙏 Danksagung & Abhängigkeiten
- [Ocasio-J/SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) — Sidecar-Verbindung über die Kommandozeile
- [waydabber/BetterDisplay](https://github.com/waydabber/BetterDisplay) — Display-Verwaltung / Trennen des internen Displays
- Ähnliche Ansätze als Referenz: [wberry9813/SideLinker](https://github.com/wberry9813/SideLinker), [raonehere/sidecar-autoconnect](https://github.com/raonehere/sidecar-autoconnect)

Dieses Projekt orchestriert nur die obigen Tools; es verändert oder verbreitet ihren Quellcode nicht. Die Urheberrechte liegen bei den jeweiligen Autoren.

---

## 📄 Lizenz
MIT-Lizenz, siehe [LICENSE](LICENSE).

> Haftungsausschluss: Dieses Tool wird „wie besehen" bereitgestellt. Drittanbieter-Komponenten, die auf private APIs setzen, können kaputtgehen. Schätze das Risiko selbst ein; der Autor haftet nicht für Datenverlust oder Geräteschäden.
