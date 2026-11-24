# Materialliste – Android-App für Holz, Platten und Baustoffe

(früher „Holzliste“) – Materiallisten direkt am Handy erfassen, mit Artikeln und Preisen aus den
**DATANORM-Dateien deiner Holz- und Baustoffhändler**, und als formatierte **Excel-Datei (.xlsx)** speichern oder senden.

## So einfach geht's

1. **＋ Neue Liste** – eine Liste je Baustelle/Projekt (Projekt, Kunde, Datum oben antippen)
2. **＋ Hinzufügen** – große Auswahl, was dazukommt:
   - 🌲 **Balken & Kanthölzer** – Stückzahl × Länge, Querschnitt → m und m³
   - 📏 **Latten & Bretter** – Meter gesamt, Querschnitt → m³
   - ▦ **Platten** (OSB, Gips, Dreischicht …) – zu belegende Fläche + Verschnitt → **Plattenanzahl wird berechnet**
   - 📦 **Sonstiges Material** – Schrauben, Dämmung, Folie, Mörtel … mit Menge und Einheit
     (Stk, m, m², kg, Sack, Paket, Rolle …), Reserve in % und optional Packungsinhalt
     (z. B. „Paket à 5,2 m²“ → **Anzahl Pakete wird berechnet**)
   - 🔍 **Aus Artikelliste suchen** – aus deiner Inventarliste oder Händlerliste, nach Kategorien; Art, Maße und Preis werden übernommen
   - ≡ **Überschrift** – z. B. „Dachstuhl“, „Dämmung“
3. Jede Position erscheint als gut lesbare Karte: links **was bestellt wird** (z. B. „24 Stk“, „74 Platten“, „20 Paket“),
   daneben Bezeichnung, Material, Maße und Preis. Antippen = ändern, **⋮** = kopieren, verschieben, löschen.
4. Unten stehen Summen (antippen für Details) – mit Preisen auch der **Gesamtbetrag netto**.

Weitere Angaben wie Preis, Artikelnummer, Bemerkung und Fertigmaß (gehobelt) liegen im Eingabedialog unter
„Weitere Angaben“, damit die Eingabe übersichtlich bleibt.

## Artikellisten: eigene Inventarliste (Excel) oder DATANORM

Menü → „Artikellisten (Inventar / DATANORM) …“ → Datei laden:
- **Excel-Inventarliste (.xlsx) oder CSV**: Spalten werden über die Überschriften erkannt
  (z. B. „Bezeichnung“, „Art.-Nr.“, „Einheit“, „Bestand“, „Preis“, „Kategorie“). Kategorien kommen aus einer
  Kategorie-Spalte, aus Zwischenüberschriften, aus den Blattnamen oder werden automatisch aus der Bezeichnung
  erkannt (Verankerungsmittel, Schrauben, Dämmung, Folien …). Beispiel: `beispiel/Beispiel-Inventarliste.xlsx`
- **DATANORM 4** vom Holz-/Baustoffhändler (DATANORM.001 … oder ZIP). Beispiel: `beispiel/Beispiel-DATANORM.001`

Bei „🔍 Aus Artikelliste suchen“ kann man oben eine Kategorie antippen und sieht nur deren Artikel.
Die App erkennt automatisch Hölzer (Querschnitt/Länge), Platten (Format/Dicke) und sonstiges Material.

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
