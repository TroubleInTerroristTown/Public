# Materialliste – Android-App für Holz, Platten und Baustoffe

(früher „Holzliste“) – Materiallisten direkt am Handy erfassen, mit Artikeln und Preisen aus den
**DATANORM-Dateien deiner Holz- und Baustoffhändler**, und als formatierte **Excel-Datei (.xlsx)** speichern oder senden.

## So einfach geht's

1. **＋ Neue Liste** – eine Liste je Baustelle/Projekt (Projekt, Kunde, Datum oben antippen)
2. **＋ Hinzufügen** – große Auswahl, was dazukommt:
   - 🪵 **Balken & Kanthölzer** – Stückzahl × Länge, Querschnitt → m und m³
   - 📏 **Latten & Bretter** – Meter gesamt, Querschnitt → m³
   - ▦ **Platten** (OSB, Gips, Dreischicht …) – zu belegende Fläche + Verschnitt → **Plattenanzahl wird berechnet**
   - 📦 **Sonstiges Material** – Schrauben, Dämmung, Folie, Mörtel … mit Menge und Einheit
     (Stk, m, m², kg, Sack, Paket, Rolle …), Reserve in % und optional Packungsinhalt
     (z. B. „Paket à 5,2 m²“ → **Anzahl Pakete wird berechnet**)
   - 🔍 **Beim Händler suchen** – Artikel aus der Händler-Artikelliste, Art und Maße werden erkannt, Preis übernommen
   - ≡ **Überschrift** – z. B. „Dachstuhl“, „Dämmung“
3. Jede Position erscheint als gut lesbare Karte: links **was bestellt wird** (z. B. „24 Stk“, „74 Platten“, „20 Paket“),
   daneben Bezeichnung, Material, Maße und Preis. Antippen = ändern, **⋮** = kopieren, verschieben, löschen.
4. Unten stehen Summen (antippen für Details) – mit Preisen auch der **Gesamtbetrag netto**.

Weitere Angaben wie Preis, Artikelnummer, Bemerkung und Fertigmaß (gehobelt) liegen im Eingabedialog unter
„Weitere Angaben“, damit die Eingabe übersichtlich bleibt.

## Händler-Artikellisten (DATANORM 4)

Menü → „Händler-Artikellisten (DATANORM) …“ → Datei laden (DATANORM.001 … oder ZIP vom Händler).
Die App erkennt automatisch Hölzer (Querschnitt/Länge), Platten (Format/Dicke) und sonstiges Material
(Einheiten wie Sack, Paket, Rolle, kg). Beispieldatei: `beispiel/Beispiel-DATANORM.001`

## Excel-Export

Menü oben rechts: **Speichern** (Diskette), **Senden** (WhatsApp, E-Mail …), **In Excel öffnen**.
Die Arbeitsmappe enthält:
1. **Materialliste** – alle Positionen mit Formeln für Laufmeter, Volumen, Plattenanzahl, Menge × Preis = Betrag und Summen
2. **Bestellübersicht** – nach Material und Querschnitt/Format bzw. Einheit zusammengefasst, mit Beträgen

Beispiel: [`beispiel/Beispiel-Materialliste.xlsx`](beispiel/Beispiel-Materialliste.xlsx)

Zeilen aus der Zwischenablage einfügen (z. B. aus Excel kopiert, Tab- oder Semikolon-getrennt):
`Bezeichnung; Stück/Menge; Breite; Höhe; Länge; Material; Bemerkung; Einheit`

## Installation

Die APK wird automatisch per GitHub Actions gebaut (`.github/workflows/holzliste-android.yml`)
und als Release „Materialliste App 2.0.x“ veröffentlicht:

1. Am Handy die Release-Seite des Repositorys öffnen und `Materialliste.apk` herunterladen
2. Datei öffnen, ggf. „Installation aus unbekannten Quellen“ erlauben
3. Die App installiert sich **über die alte Holzliste** – alle Listen und Kataloge bleiben erhalten

Mindestens Android 8.0.

## Selbst bauen

```
cd zimmerer-holzliste
gradle assembleRelease      # benötigt Android SDK (ANDROID_HOME) und JDK 17
gradle testReleaseUnitTest  # Tests + Screenshots nach app/build/screenshots
```

Die App kommt ohne externe Bibliotheken aus; die .xlsx-Datei wird von `XlsxWriter.java` selbst erzeugt.
Paket- und Klassennamen (`de.zimmerei.holzliste`) sind bewusst geblieben, damit Updates über die alte Version funktionieren.
Hinweis: `app/holzliste.keystore` ist ein bewusst mitgelieferter Signaturschlüssel nur für diese private
App (damit Updates ohne Deinstallation funktionieren) – für den Play Store einen eigenen, geheimen Schlüssel verwenden.
