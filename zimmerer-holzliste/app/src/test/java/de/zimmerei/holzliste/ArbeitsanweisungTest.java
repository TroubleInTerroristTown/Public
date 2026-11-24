package de.zimmerei.holzliste;

import android.content.Intent;
import android.net.Uri;
import android.view.View;

import com.tom_roush.pdfbox.android.PDFBoxResourceLoader;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import com.tom_roush.pdfbox.pdmodel.PDPage;
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream;
import com.tom_roush.pdfbox.pdmodel.font.PDType1Font;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.GraphicsMode;
import org.robolectric.shadows.ShadowDialog;
import org.robolectric.shadows.ShadowLooper;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/** Arbeitsanweisung (PDF) → Überschriften + Materialvorschläge. Beispieltexte sind ausgedacht. */
@RunWith(RobolectricTestRunner.class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = 34, qualifiers = "w393dp-h851dp-port-xxhdpi")
public class ArbeitsanweisungTest {

    // Aufbau wie eine Arbeitsanweisung aus der Auftrags-Software (Pos. / Menge / Einh. / Beschreibung)
    static final String LV = String.join("\n",
            "Zimmerei Muster GmbH - Hauptstr. 1 - 12345 Musterstadt",
            "Herrn",
            "Max Mustermann",
            "Arbeitsanweisung",
            "Bauvorhaben : Musterweg 5, 12345 Musterstadt Seite :1",
            "Pos. Menge Einh. Beschreibung",
            "1",
            "Beschreibung",
            "\uF0B7 Demontage des alten Geländers",
            "\uF0B7 Erneuern der Konstruktion",
            "1",
            "Baustelleneinrichtung",
            "1.1 1,00 psch Baustelleneinrichtung,",
            "Standard",
            "1.2 4,00 Stück Anfahrtspauschale bis 20 km,",
            "2",
            "Zimmererarbeiten",
            "2.1 40,00 h Stundensatz Facharbeiter,",
            "2.2",
            "20,00 LFM",
            "Konstruktionsvollholz Fichte",
            "120x120x5000 mm",
            "2.3 30,00 LFM Balkonbretter Fi./Ta. 26x142x5100 mm",
            "2.4 2,50 Liter Adler Pullex Plus-Lasur 2,5 lt Palisander",
            "2.5 1,00 Materialkostenschätzung");

    static final String FREI = String.join("\n",
            "Bauvorhaben: EFH Maier, Dachsanierung",
            "Kunde: Familie Maier",
            "1. Dachstuhl",
            "Sparren 8/20 ergänzen, ca. 6 Stück, KVH C24.",
            "2. Dämmung",
            "Zwischensparrendämmung 200 mm, ca. 85 m² einbauen.",
            "Dampfbremse raumseitig verlegen und Stöße mit Klebeband abkleben.",
            "3. Lattung",
            "Konterlattung 40/60 und Dachlattung 30/50 aufbringen, ca. 320 lfm.",
            "Hinweise:",
            "Arbeitsschutz beachten.");

    static Katalog.Eintrag artikel(String nr, String text, String einheit, Double b, Double h) {
        Datanorm.Artikel a = new Datanorm.Artikel();
        a.nr = nr; a.text = text; a.einheit = einheit; a.b = b; a.h = h;
        a.kategorie = Kategorien.zuordnen(text);
        return new Katalog.Eintrag(a, "Inventar");
    }

    static List<Katalog.Eintrag> inventar() {
        List<Katalog.Eintrag> l = new ArrayList<>();
        l.add(artikel("1001", "KVH Fichte NSi C24 120/120 mm", "m", 12.0, 12.0));
        l.add(artikel("1002", "KVH Fichte NSi C24 80/200 mm", "m", 8.0, 20.0));
        l.add(artikel("1003", "Balkonbretter Fichte/Tanne 26x142 mm", "m", 2.6, 14.2));
        l.add(artikel("2001", "Adler Pullex Plus-Lasur Lärche 2,5 l", "Dose", null, null));
        l.add(artikel("2002", "Adler Pullex Plus-Lasur Palisander 2,5 l", "Dose", null, null));
        l.add(artikel("3001", "Isover Klemmfilz 035 140 mm", "m²", null, null));
        l.add(artikel("3002", "Isover Klemmfilz 035 200 mm", "m²", null, null));
        l.add(artikel("3003", "pro clima Intello Plus Dampfbremse 1,5x50 m", "Rolle", null, null));
        return l;
    }

    @Test
    public void leistungsverzeichnis() {
        Arbeitsanweisung.Ergebnis e = Arbeitsanweisung.auswerten(LV, inventar(), "26-00001-AW BV Mustermann Balkon.pdf");
        assertEquals("BV Mustermann Balkon", e.projekt);
        assertEquals("Max Mustermann", e.kunde);
        assertEquals(2, e.arbeitsschritte.size());
        assertEquals(4, e.uebersprungen); // Pauschale, Anfahrt, Stunden, Materialkostenschätzung
        assertEquals(1, e.abschnitte.size());
        assertEquals("Zimmererarbeiten", e.abschnitte.get(0).titel);
        List<Arbeitsanweisung.Vorschlag> v = e.abschnitte.get(0).vorschlaege;
        assertEquals(3, v.size());
        assertEquals(Position.LFM, v.get(0).typ);
        assertEquals(12.0, v.get(0).b, 0);
        assertEquals(20.0, v.get(0).menge, 0);
        assertEquals("1001", v.get(0).artikel.a.nr);
        assertEquals("1003", v.get(1).artikel.a.nr);
        assertEquals("2002", v.get(2).artikel.a.nr); // Palisander, nicht Lärche

        List<Position> p = Arbeitsanweisung.positionen(e);
        assertEquals(Position.TITEL, p.get(0).typ);
        assertEquals("20 m", p.get(1).bestellText());
        assertEquals("2,5 l", p.get(3).bestellText());
    }

    @Test
    public void freitext() {
        Arbeitsanweisung.Ergebnis e = Arbeitsanweisung.auswerten(FREI, inventar(), "Scan_0001.pdf");
        assertEquals("EFH Maier, Dachsanierung", e.projekt);
        assertEquals("Familie Maier", e.kunde);
        assertEquals(3, e.abschnitte.size());
        Arbeitsanweisung.Vorschlag sparren = e.abschnitte.get(0).vorschlaege.get(0);
        assertEquals("Sparren 8/20", sparren.name);
        assertEquals(6.0, sparren.menge, 0);
        assertEquals("1002", sparren.artikel.a.nr);
        assertEquals(1, e.abschnitte.get(0).vorschlaege.size()); // kein doppeltes „Kanthölzer“ wegen „KVH“
        Arbeitsanweisung.Vorschlag daemm = e.abschnitte.get(1).vorschlaege.get(0);
        assertEquals("Dämmung 200 mm", daemm.name);
        assertEquals(85.0, daemm.menge, 0);
        assertEquals("3002", daemm.artikel.a.nr);
        assertNull(e.abschnitte.get(2).vorschlaege.get(1).artikel); // Konterlatte 4/6 nicht im Inventar
        assertEquals(320.0, e.abschnitte.get(2).vorschlaege.get(0).menge, 0); // Dachlatten 3/5
        assertTrue(e.abschnitte.get(2).vorschlaege.get(1).menge == null);
    }

    /** Echte PDF erzeugen, über PdfText lesen, auswerten und die Vorschau als Bild speichern. */
    @Test
    public void pdfLesenUndVorschau() throws Exception {
        PDFBoxResourceLoader.init(RuntimeEnvironment.getApplication());
        File pdf = new File("build/screenshots/test-aw.pdf");
        pdf.getParentFile().mkdirs();
        try (PDDocument doc = new PDDocument()) {
            PDPage page = new PDPage();
            doc.addPage(page);
            try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                cs.setFont(PDType1Font.HELVETICA, 10);
                float y = 750;
                for (String z : LV.replace("\uF0B7 ", "- ").split("\n")) {
                    cs.beginText();
                    cs.newLineAtOffset(40, y);
                    cs.showText(z);
                    cs.endText();
                    y -= 14;
                }
            }
            doc.save(pdf);
        }
        String text = PdfText.lesen(RuntimeEnvironment.getApplication(), Uri.fromFile(pdf));
        assertTrue(text, text.contains("Balkonbretter"));
        Arbeitsanweisung.Ergebnis e = Arbeitsanweisung.auswerten(text, inventar(), "26-00001-AW BV Mustermann Balkon.pdf");
        assertEquals(3, e.anzahlVorschlaege());

        Holzliste h = new Holzliste();
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        AwImport.vorschau(ed, e, h, () -> {});
        ShadowLooper.idleMainLooper();
        assertNotNull(ShadowDialog.getLatestDialog());
        ScreenshotTest.png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "11_arbeitsanweisung");
    }

    /** Werkzeug-Reiter: Vorschläge, Speichern, Ansicht. */
    @Test
    public void werkzeug() throws Exception {
        Arbeitsanweisung.Ergebnis e = Arbeitsanweisung.auswerten(LV, inventar(), "26-00001-AW BV Mustermann Balkon.pdf");
        Holzliste h = new Holzliste();
        h.projekt = e.projekt;
        h.positionen.addAll(Arbeitsanweisung.positionen(e));
        List<Werkzeug.Vorschlag> v = Werkzeug.vorschlagen(h, e.arbeitsschritte);
        List<String> namen = new ArrayList<>();
        for (Werkzeug.Vorschlag x : v) namen.add(x.name);
        assertTrue(namen.toString(), namen.contains("Kappsäge"));            // wegen Holz
        assertTrue(namen.toString(), namen.contains("Pinsel & Farbroller")); // wegen Lasur
        assertTrue(namen.toString(), namen.contains("Säbelsäge"));           // wegen „Demontage des alten Geländers“
        for (String std : Werkzeug.GRUNDAUSSTATTUNG) assertTrue(std, !namen.contains(std)); // Standard nicht einzeln
        for (Werkzeug.Vorschlag x : v) if (x.name.equals("Kappsäge")) assertEquals(Werkzeug.ROT, x.prio); // vom Material
        for (int k = 1; k < v.size(); k++) assertTrue(v.get(k - 1).prio >= v.get(k).prio);                  // rot zuerst
        for (Werkzeug.Vorschlag x : v) { Werkzeug w = new Werkzeug(x.name, x.grund); w.prio = x.prio; h.werkzeug.add(w); }
        h.werkzeug.get(0).eingepackt = true;
        h.werkzeug.get(1).anzahl = 2;
        assertTrue(Werkzeug.vorschlagen(h, e.arbeitsschritte).isEmpty()); // nichts doppelt

        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Holzliste geladen = Storage.laden(RuntimeEnvironment.getApplication(), h.id);
        assertEquals(h.werkzeug.size(), geladen.werkzeug.size());
        assertTrue(geladen.werkzeug.get(0).eingepackt);
        assertEquals(Integer.valueOf(2), geladen.werkzeug.get(1).anzahl);
        assertEquals(h.werkzeug.get(0).prio, geladen.werkzeug.get(0).prio);

        android.app.Activity main = Robolectric.buildActivity(MainActivity.class).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(main.getWindow().getDecorView(), "12_start");

        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        i.putExtra(EditorActivity.EXTRA_REITER, EditorActivity.R_WERKZEUG);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(ed.getWindow().getDecorView(), "13_werkzeug");
    }

    /** To-do-Liste aus den Positionen und Arbeitsschritten. */
    @Test
    public void aufgaben() throws Exception {
        Arbeitsanweisung.Ergebnis e = Arbeitsanweisung.auswerten(LV, inventar(), "26-00001-AW BV Mustermann Balkon.pdf");
        List<String> texte = new ArrayList<>();
        for (Aufgabe a : e.aufgaben) texte.add(a.text);
        assertTrue(texte.toString(), texte.contains("Demontage des alten Geländers"));
        assertTrue(texte.toString(), texte.contains("Baustelleneinrichtung"));
        assertTrue(texte.toString(), texte.contains("Balkonbretter Fi./Ta. 26x142x5100 mm"));
        for (String t : texte) assertTrue(t, !t.toLowerCase().contains("stundensatz") && !t.toLowerCase().contains("anfahrt"));
        Aufgabe bretter = e.aufgaben.get(texte.indexOf("Balkonbretter Fi./Ta. 26x142x5100 mm"));
        assertEquals("Zimmererarbeiten", bretter.abschnitt);
        assertEquals("Pos. 2.3 · 30 m", bretter.info);

        Holzliste h = new Holzliste();
        h.projekt = e.projekt;
        h.positionen.addAll(Arbeitsanweisung.positionen(e));
        for (Aufgabe a : e.aufgaben) h.aufgaben.add(a.copy());
        h.aufgaben.get(0).erledigt = true;
        h.aufgaben.get(1).erledigt = true;
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Holzliste geladen = Storage.laden(RuntimeEnvironment.getApplication(), h.id);
        assertEquals(h.aufgaben.size(), geladen.aufgaben.size());
        assertEquals(2, geladen.anzahlErledigt());

        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        i.putExtra(EditorActivity.EXTRA_REITER, EditorActivity.R_AUFGABEN);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(ed.getWindow().getDecorView(), "14_aufgaben");

        // Tages-To-do: drei Aufgaben für heute, eine dringend
        Holzliste h2 = Storage.laden(RuntimeEnvironment.getApplication(), h.id);
        h2.aufgaben.get(2).heute = true;
        h2.aufgaben.get(3).heute = true;
        h2.aufgaben.get(3).prio = Werkzeug.ROT;
        h2.aufgaben.get(4).heute = true;
        h2.aufgaben.get(4).prio = Werkzeug.GRUEN;
        Storage.speichern(RuntimeEnvironment.getApplication(), h2);
        Holzliste g2 = Storage.laden(RuntimeEnvironment.getApplication(), h.id);
        assertTrue(g2.aufgaben.get(3).heute);
        assertEquals(Werkzeug.ROT, g2.aufgaben.get(3).prio);
        assertEquals(3, AufgabenAnsicht.anzahlHeute(g2, false));
        EditorActivity ed2 = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        assertTrue(AufgabenAnsicht.heuteModus(g2));
        ScreenshotTest.png(ed2.getWindow().getDecorView(), "14b_heute");
        AufgabenAnsicht.heuteWaehlen(ed2, g2, () -> {});
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "14c_heute_waehlen");
    }

    /** Material: Kästchen-Auswahl über langes Drücken. */
    @Test
    public void materialAuswahl() throws Exception {
        Arbeitsanweisung.Ergebnis e = Arbeitsanweisung.auswerten(LV, inventar(), "26-00001-AW BV Mustermann Balkon.pdf");
        Holzliste h = new Holzliste();
        h.projekt = e.projekt;
        h.positionen.addAll(Arbeitsanweisung.positionen(e));
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        android.view.ViewGroup karten = (android.view.ViewGroup) ((android.view.ViewGroup) ((android.view.ViewGroup) ((android.view.ViewGroup)
                ((android.view.ViewGroup) ed.findViewById(android.R.id.content)).getChildAt(0)).getChildAt(2)).getChildAt(0)).getChildAt(0);
        int vorher = h.positionen.size();
        // erste echte Karte (nicht Überschrift) lange drücken
        View karte = null;
        for (int k = 0; k < karten.getChildCount() && karte == null; k++)
            if (!h.positionen.get(k).isTitel()) karte = karten.getChildAt(k);
        assertNotNull(karte);
        karte.performLongClick();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(ed.getWindow().getDecorView(), "17_material_auswahl");
        assertTrue(vorher > 1);
    }

    /** Baustellen-Übersicht: Kacheln je Ast, die Kopfdaten oben; AW-Felder werden gespeichert. */
    @Test
    public void baustelle() throws Exception {
        Arbeitsanweisung.Ergebnis e = Arbeitsanweisung.auswerten(LV, inventar(), "26-00001-AW BV Mustermann Balkon.pdf");
        Holzliste h = new Holzliste();
        h.projekt = e.projekt;
        h.kunde = "Max Mustermann";
        h.bauteil = "Balkon";
        h.datum = "24.11.2026";
        h.awDatei = "26-00001-AW BV Mustermann Balkon.pdf";
        h.awDatum = "24.11.2026";
        h.positionen.addAll(Arbeitsanweisung.positionen(e));
        for (Aufgabe a : e.aufgaben) h.aufgaben.add(a.copy());
        h.aufgaben.get(0).erledigt = true;
        for (Werkzeug.Vorschlag x : Werkzeug.vorschlagen(h, e.arbeitsschritte)) h.werkzeug.add(new Werkzeug(x.name, x.grund));
        h.werkzeug.get(0).eingepackt = true;
        h.notiz = "Schlüssel beim Nachbarn (Hausnr. 3)";
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Holzliste geladen = Storage.laden(RuntimeEnvironment.getApplication(), h.id);
        assertEquals(h.awDatei, geladen.awDatei);
        assertEquals("24.11.2026", geladen.awDatum);
        assertEquals("", Storage.duplizieren(RuntimeEnvironment.getApplication(), geladen).awDatei);

        Intent i = new Intent(RuntimeEnvironment.getApplication(), BaustelleActivity.class);
        i.putExtra(BaustelleActivity.EXTRA_ID, h.id);
        BaustelleActivity b = Robolectric.buildActivity(BaustelleActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(b.getWindow().getDecorView(), "15_baustelle");

        // Kachel „Werkzeug“ öffnet die eigene Werkzeug-Seite
        android.view.ViewGroup scroll = (android.view.ViewGroup) ((android.view.ViewGroup) b.findViewById(android.R.id.content)).getChildAt(0);
        android.view.ViewGroup inhalt = (android.view.ViewGroup) scroll.getChildAt(0);
        ((android.view.ViewGroup) inhalt.getChildAt(2)).getChildAt(1).performClick();
        Intent naechste = org.robolectric.Shadows.shadowOf(b).getNextStartedActivity();
        assertEquals(EditorActivity.class.getName(), naechste.getComponent().getClassName());
        assertEquals(EditorActivity.R_WERKZEUG, naechste.getIntExtra(EditorActivity.EXTRA_REITER, -1));

        // Neue Baustelle: Start zeigt die Übersicht mit Kopfdaten-Dialog
        android.app.Activity main = Robolectric.buildActivity(MainActivity.class).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(main.getWindow().getDecorView(), "16_start");
    }

    /** Schlichte Bestellliste: Holz und Material getrennt, ohne Überschriften und Kundendaten. */
    @Test
    public void bestellliste() throws Exception {
        Holzliste h = new Holzliste();
        h.projekt = "BV Mustermann Balkon";
        h.kunde = "Max Mustermann";
        Position t = new Position(); t.typ = Position.TITEL; t.bezeichnung = "Zimmererarbeiten"; h.positionen.add(t);
        Position k = new Position(); k.typ = Position.HOLZ; k.bezeichnung = "KVH"; k.holzart = "Fichte";
        k.stueck = 4.0; k.breite = 12.0; k.hoehe = 12.0; k.laenge = 5.0; h.positionen.add(k);
        Position s = new Position(); s.typ = Position.MATERIAL; s.bezeichnung = "Terrassenschrauben 5x60";
        s.menge = 400.0; s.einheit = "Stk"; s.packInhalt = 200.0; s.packName = "Paket"; h.positionen.add(s);
        assertEquals(1, Bestellliste.anzahl(h, Bestellliste.HOLZ));
        assertEquals(1, Bestellliste.anzahl(h, Bestellliste.MATERIAL));
        assertEquals(2, Bestellliste.anzahl(h, Bestellliste.ALLES));
        Object[] zk = Bestellliste.zeile(k);
        assertEquals(4.0, (Double) zk[0], 0.001);
        assertEquals("KVH Fichte", zk[2]);
        assertEquals("12/12", zk[3]);
        Object[] zs = Bestellliste.zeile(s);
        assertEquals(2.0, (Double) zs[0], 0.001);
        assertEquals("Paket", zs[1]);
        assertEquals("à 200 Stk", zs[6]);
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        Bestellliste.write(h, Bestellliste.HOLZ, out);
        assertTrue(out.size() > 1000);
    }
}
