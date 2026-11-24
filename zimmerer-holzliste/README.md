# Holzliste – Android-App für Zimmerer

Holzlisten direkt am Handy erfassen und als formatierte **Excel-Datei (.xlsx)** speichern oder versenden.
Die Datei öffnet sich am PC in Microsoft Excel mit fertiger Tabellenformatierung (Kopfdaten, Spaltengruppen,
Zebra-Streifen, Summen, fixierte Kopfzeile, AutoFilter, Druckeinrichtung A4 quer).

## Funktionen

- **Mehrere Holzlisten** (Projekte) mit Kopfdaten: Projekt/Bauvorhaben, Kunde, Bauteil, Datum, Bearbeiter, Notiz
- **Tabelle wie in Excel**: Bezeichnung links fixiert, restliche Spalten seitlich wischbar
- **Positionsarten**
  - *Holz (Stück)*: Stück × Länge, Querschnitt B/H → Laufmeter und m³ automatisch
  - *Laufmeterholz*: Latten, Schalung, Bretter … mit Gesamt-Laufmeter → m³ automatisch
  - *Platten* (Plattenwerkstoffe wie OSB, Spanplatte, Dreischicht, Holzfaser): Stück × Länge [m] × Breite [cm]
    → **m²**, mit Dicke [mm] → m³. Alternativ die Fläche direkt in m² eingeben.
  - *Abschnitt*: Überschrift wie „Dachstuhl“, „Decke EG“ (über langes Drücken → Einfügen oder Menü)
- **Fertigmaß** (z. B. gehobelt) zusätzlich zum Rohmaß
- Holzart/Qualität und Bemerkung je Position, Vorschlagslisten für Bezeichnungen und Holzarten
- Zeile antippen = bearbeiten; **lange drücken** = darüber/darunter einfügen, duplizieren, verschieben, löschen
- „+ Nächste“ im Eingabedialog für schnelle Erfassung vieler Positionen
- **Zeilen aus der Zwischenablage einfügen** (Tab- oder Semikolon-getrennt, z. B. aus Excel kopiert):
  `Bezeichnung; Stück; Breite; Höhe; Länge; Holzart; Bemerkung`
- Laufende Summen: m³ Stückhölzer, Laufmeter/m³ Laufmeterhölzer, m²/m³ Platten, Gesamt-m³
- Automatisches Speichern am Gerät

## Excel-Export

Menü oben rechts:
- **Speichern** (Diskette): Speicherort wählen (Downloads, Google Drive, OneDrive …)
- **Teilen**: per E-Mail, WhatsApp, Teams usw. senden
- **In Excel öffnen**: direkt in der Excel-App am Handy

Die Arbeitsmappe enthält zwei Blätter:
1. **Holzliste** – alle Positionen mit Formeln für Laufmeter und Volumen sowie Summen
2. **Zusammenfassung** – Bestellübersicht nach Holzart/Querschnitt bzw. Plattenmaterial/Format

Ein Beispiel liegt unter [`beispiel/Beispiel-Holzliste.xlsx`](beispiel/Beispiel-Holzliste.xlsx).

## Installation

Die APK wird automatisch per GitHub Actions gebaut (`.github/workflows/holzliste-android.yml`)
und als Release „Holzliste App 1.0.x“ veröffentlicht:

1. Am Handy die Release-Seite des Repositorys öffnen und `Holzliste.apk` herunterladen
2. Datei öffnen, ggf. „Installation aus unbekannten Quellen“ erlauben
3. Updates einfach über die alte Version installieren (Daten bleiben erhalten)

Mindestens Android 8.0.

## Selbst bauen

```
cd zimmerer-holzliste
gradle assembleRelease      # benötigt Android SDK (ANDROID_HOME) und JDK 17
```

Die App kommt ohne externe Bibliotheken aus; die .xlsx-Datei wird von `XlsxWriter.java` selbst erzeugt.
Hinweis: `app/holzliste.keystore` ist ein bewusst mitgelieferter Signaturschlüssel nur für diese private
App (damit Updates ohne Deinstallation funktionieren) – für den Play Store einen eigenen, geheimen Schlüssel verwenden.
