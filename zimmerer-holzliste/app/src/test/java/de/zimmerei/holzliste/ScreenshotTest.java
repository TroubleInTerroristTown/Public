package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.Dialog;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.view.View;

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
import java.io.FileOutputStream;

import static org.junit.Assert.assertTrue;

/**
 * Rendert die wichtigsten Bildschirme als PNG (build/screenshots) und prüft Berechnung, DATANORM-Import und Excel-Export.
 * Ausführen: gradle testReleaseUnitTest
 */
@RunWith(RobolectricTestRunner.class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = 34, qualifiers = "w393dp-h851dp-port-xxhdpi")
public class ScreenshotTest {

    static Position p(String typ, String bez, Double stk, Double b, Double h, Double l, Double lfm,
                      Double fb, Double fh, String ha, String bem) {
        Position x = new Position();
        x.typ = typ; x.bezeichnung = bez; x.stueck = stk; x.breite = b; x.hoehe = h; x.laenge = l;
        x.laufmeter = lfm; x.fertigB = fb; x.fertigH = fh; x.holzart = ha; x.bemerkung = bem;
        return x;
    }

    static Holzliste beispiel() {
        Holzliste h = new Holzliste();
        h.projekt = "EFH Huber – Dachstuhl"; h.kunde = "Familie Huber"; h.bauteil = "Satteldach 38°";
        h.datum = "24.11.2026"; h.bearbeiter = "F. P.";
        h.positionen.add(p(Position.TITEL, "Dachstuhl", null, null, null, null, null, null, null, "", ""));
        h.positionen.add(p(Position.HOLZ, "Sparren", 24.0, 8.0, 20.0, 7.40, null, 7.5, 19.5, "KVH NSi C24", "gehobelt, gefast"));
        h.positionen.add(p(Position.HOLZ, "Firstpfette", 1.0, 16.0, 24.0, 12.50, null, null, null, "BSH GL24h", ""));
        h.positionen.add(p(Position.HOLZ, "Mittelpfette", 2.0, 14.0, 22.0, 12.50, null, null, null, "BSH GL24h", ""));
        h.positionen.add(p(Position.HOLZ, "Fußpfette", 2.0, 14.0, 14.0, 12.50, null, null, null, "KVH NSi C24", "imprägniert"));
        h.positionen.add(p(Position.HOLZ, "Kopfbänder", 8.0, 12.0, 12.0, 1.10, null, null, null, "KVH NSi C24", ""));
        h.positionen.add(p(Position.TITEL, "Lattung & Schalung", null, null, null, null, null, null, null, "", ""));
        h.positionen.add(p(Position.LFM, "Dachlatten", null, 3.0, 5.0, null, 620.0, null, null, "Fichte S10 imprägniert", "Bündel à 4,5 m"));
        h.positionen.add(p(Position.LFM, "Konterlatten", null, 4.0, 6.0, null, 185.0, null, null, "Fichte S10 imprägniert", ""));
        h.positionen.add(p(Position.LFM, "Rauhspund", null, 14.0, 2.4, null, 95.5, 13.5, 2.2, "Fichte", ""));
        h.positionen.add(p(Position.TITEL, "Plattenwerkstoffe", null, null, null, null, null, null, null, "", ""));
        h.positionen.add(platte("Dachschalung", 12.5, 9.0, null, 10.0, 2.50, 67.5, 22.0, "OSB/3 N+F", "N+F"));
        h.positionen.add(platte("Wandbeplankung innen", 7.5, 2.6, null, 10.0, 2.50, 125.0, 15.0, "OSB/3", ""));
        h.positionen.add(platte("Decke OG", null, null, 48.0, 15.0, 2.00, 125.0, 12.5, "Gipskarton GKB", ""));
        h.positionen.add(p(Position.TITEL, "Dämmung & Kleinteile", null, null, null, null, null, null, null, "", ""));
        Position d = material("Zwischensparrendämmung", 96.0, "m²", 5.0, 5.2, "Paket", "Mineralwolle 035 140 mm");
        d.preis = 8.90; d.preisEinheit = "m²"; d.artikelNr = "600100";
        h.positionen.add(d);
        Position s = material("Holzbauschrauben 8×240", 3.0, "Paket", null, null, "", "Senkkopf, 50 Stk/Paket");
        s.preis = 22.50;
        h.positionen.add(s);
        h.positionen.add(material("Dampfbremse", 2.0, "Rolle", null, null, "", "sd 2 m, 1,5 × 50 m"));
        h.positionen.add(material("Zementmörtel MG III", 11.5, "Sack", null, null, "", "25 kg"));
        return h;
    }

    static Position material(String bez, Double menge, String einh, Double vs, Double pack, String packName, String mat) {
        Position x = new Position();
        x.typ = Position.MATERIAL; x.bezeichnung = bez; x.menge = menge; x.einheit = einh; x.verschnitt = vs;
        x.packInhalt = pack; x.packName = packName; x.holzart = mat;
        return x;
    }

    /** n-ter HorizontalScrollView im Baum (0 = Kopf, 1 = Tabelle). */
    private static android.widget.HorizontalScrollView findHs(View v, int n) {
        java.util.List<android.widget.HorizontalScrollView> l = new java.util.ArrayList<>();
        sammle(v, l);
        return l.size() > n ? l.get(n) : null;
    }

    private static android.widget.ScrollView findSv(View v) {
        if (v instanceof android.widget.ScrollView) return (android.widget.ScrollView) v;
        if (v instanceof android.view.ViewGroup)
            for (int i = 0; i < ((android.view.ViewGroup) v).getChildCount(); i++) {
                android.widget.ScrollView s = findSv(((android.view.ViewGroup) v).getChildAt(i));
                if (s != null) return s;
            }
        return null;
    }

    private static void sammle(View v, java.util.List<android.widget.HorizontalScrollView> l) {
        if (v instanceof android.widget.HorizontalScrollView) l.add((android.widget.HorizontalScrollView) v);
        if (v instanceof android.view.ViewGroup)
            for (int i = 0; i < ((android.view.ViewGroup) v).getChildCount(); i++) sammle(((android.view.ViewGroup) v).getChildAt(i), l);
    }

    static Position platte(String bez, Double flL, Double flB, Double fl, Double vs,
                           Double lM, Double bCm, Double dMm, String mat, String bem) {
        Position x = new Position();
        x.typ = Position.PLATTE; x.bezeichnung = bez; x.flL = flL; x.flB = flB; x.flaeche = fl; x.verschnitt = vs;
        x.laenge = lM; x.breite = bCm; x.hoehe = dMm / 10.0; x.holzart = mat; x.bemerkung = bem;
        return x;
    }

    private static void png(View v, String name) throws Exception {
        Bitmap bmp = Bitmap.createBitmap(v.getWidth(), v.getHeight(), Bitmap.Config.ARGB_8888);
        v.draw(new Canvas(bmp));
        File dir = new File("build/screenshots");
        dir.mkdirs();
        try (FileOutputStream out = new FileOutputStream(new File(dir, name + ".png"))) {
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out);
        }
    }

    @Test
    public void screens() throws Exception {
        Holzliste h = beispiel();
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Holzliste h2 = beispiel();
        h2.projekt = "Carport Maier"; h2.kunde = "Hr. Maier"; h2.bauteil = "Flachdach"; h2.positionen.subList(0, 6).clear();
        Storage.speichern(RuntimeEnvironment.getApplication(), h2);

        Activity main = Robolectric.buildActivity(MainActivity.class).setup().get();
        ShadowLooper.idleMainLooper();
        png(main.getWindow().getDecorView(), "1_start");

        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        png(ed.getWindow().getDecorView(), "2_liste");

        new PositionDialog(ed, h.positionen.get(1).copy(), false, java.util.Collections.emptySet(), (x, y) -> {}).show();
        ShadowLooper.idleMainLooper();
        Dialog d = ShadowDialog.getLatestDialog();
        png(d.getWindow().getDecorView(), "3_position");
        d.dismiss();

        new PositionDialog(ed, h.positionen.get(11).copy(), false, java.util.Collections.emptySet(), (x, y) -> {}).show();
        ShadowLooper.idleMainLooper();
        png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "4_platte");

        ShadowDialog.getLatestDialog().dismiss();
        Position neuP = new Position();
        neuP.typ = Position.PLATTE;
        new PositionDialog(ed, neuP, true, java.util.Collections.emptySet(), (x, y) -> {}).show();
        ShadowLooper.idleMainLooper();
        png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "6_plattenauswahl");
        ShadowDialog.getLatestDialog().dismiss();
        ShadowLooper.idleMainLooper();
        png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "7_platte_neu");

        // Liste nach unten gescrollt (Material + Summe)
        android.widget.ScrollView sv = findSv(ed.getWindow().getDecorView());
        if (sv != null) { sv.scrollTo(0, 100000); ShadowLooper.idleMainLooper(); }
        png(ed.getWindow().getDecorView(), "5_liste_unten");

        // Auswahl „Was möchtest du hinzufügen?“
        ShadowDialog.getLatestDialog().dismiss();
        ed.hinzufuegen(h.positionen.size());
        ShadowLooper.idleMainLooper();
        png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "9_hinzufuegen");
        ShadowDialog.getLatestDialog().dismiss();

        // Material-Dialog
        new PositionDialog(ed, h.positionen.get(15).copy(), false, java.util.Collections.emptySet(), (x, y) -> {}).show();
        ShadowLooper.idleMainLooper();
        png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "10_material");

        // DATANORM-Katalog importieren und Auswahl anzeigen
        Datanorm.Ergebnis dn = Datanorm.lesen(getClass().getResourceAsStream("/DATANORM.001"), "DATANORM.001");
        org.junit.Assert.assertEquals("Holzhandel Mustermann GmbH", dn.haendler);
        org.junit.Assert.assertEquals(13, dn.artikel.size()); // 14 A-Sätze, einer gelöscht (L)
        Datanorm.Artikel kvh = dn.artikel.get(0);
        org.junit.Assert.assertEquals(6.0, kvh.b, 1e-9);
        org.junit.Assert.assertEquals(12.0, kvh.h, 1e-9);
        org.junit.Assert.assertEquals(13.0, kvh.l, 1e-9);
        org.junit.Assert.assertEquals(4.25, kvh.preis, 1e-9);
        Datanorm.Artikel osb = null;
        for (Datanorm.Artikel x : dn.artikel) if (x.nr.equals("300110")) osb = x;
        org.junit.Assert.assertTrue(osb.platte);
        org.junit.Assert.assertEquals(2.5, osb.l, 1e-9);
        org.junit.Assert.assertEquals(125.0, osb.pb, 1e-9);
        org.junit.Assert.assertEquals(1.5, osb.h, 1e-9);
        org.junit.Assert.assertTrue(dn.artikel.get(2).text.contains("imprägniert"));
        Katalog.speichern(ed, dn);

        // Excel-Inventarliste mit Kategorien
        Datanorm.Ergebnis inv = Datanorm.lesen(getClass().getResourceAsStream("/Inventar.xlsx"), "Inventar.xlsx");
        org.junit.Assert.assertEquals(11, inv.artikel.size());
        org.junit.Assert.assertEquals("Verankerungsmittel", inv.artikel.get(0).kategorie);
        org.junit.Assert.assertEquals("Bolzenanker M12x100", inv.artikel.get(0).text);
        org.junit.Assert.assertEquals(1.85, inv.artikel.get(0).preis, 1e-9);
        org.junit.Assert.assertEquals(Position.MATERIAL, inv.artikel.get(3).typ()); // Spanplattenschraube ist keine Platte
        org.junit.Assert.assertEquals("Dämmung", inv.artikel.get(5).kategorie);     // automatisch zugeordnet
        org.junit.Assert.assertEquals("Folien & Bänder", inv.artikel.get(6).kategorie); // aus Blattname
        org.junit.Assert.assertEquals("Verbindungsmittel", inv.artikel.get(8).kategorie); // aus Zwischenüberschrift
        // dieselbe Liste im alten Excel-Format (.xls)
        Datanorm.Ergebnis xls = Datanorm.lesen(getClass().getResourceAsStream("/Inventar.xls"), "Inventar.xls");
        org.junit.Assert.assertEquals(11, xls.artikel.size());
        for (int k = 0; k < 11; k++) {
            org.junit.Assert.assertEquals(inv.artikel.get(k).text, xls.artikel.get(k).text);
            org.junit.Assert.assertEquals(inv.artikel.get(k).kategorie, xls.artikel.get(k).kategorie);
        }
        org.junit.Assert.assertEquals("Verankerungsmittel", Kategorien.zuordnen("WDVS-Tellerschlagdübel NTK-U 8/60 190 mm"));
        org.junit.Assert.assertEquals("Trockenbau", Kategorien.zuordnen("Butler machts Tragschiene weiß Hacksystem, 3750x24x38 mm"));
        org.junit.Assert.assertEquals("Kleber, Schaum & Dichtstoffe", Kategorien.zuordnen("Butler machts Bau Acryl 310 ml, weiß"));
        Katalog.speichern(ed, inv);
        org.junit.Assert.assertEquals(3, Katalog.suche(Katalog.alle(ed), "", null, "Schrauben", 50).size()); // 2 Inventar + 1 DATANORM
        org.junit.Assert.assertEquals(1, Katalog.suche(Katalog.alle(ed), "kvh 6/12", Position.HOLZ, 10).size());
        org.junit.Assert.assertEquals(1, Katalog.suche(Katalog.alle(ed), "osb 15", Position.PLATTE, 10).size());
        org.junit.Assert.assertEquals(15, Katalog.suche(Katalog.alle(ed), "", Position.MATERIAL, 100).size()); // 4 DATANORM + 11 Inventar

        ShadowDialog.getLatestDialog().dismiss();
        KatalogAuswahl.zeigen(ed, null, a -> {});
        for (int k = 0; k < 10; k++) { ShadowLooper.idleMainLooper(); Thread.sleep(100); }
        ShadowLooper.idleMainLooper();
        png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "8_katalog");

        File xlsx = new File("build/screenshots/test.xlsx");
        try (FileOutputStream out = new FileOutputStream(xlsx)) { HolzlisteExcel.write(h, out); }
        assertTrue(xlsx.length() > 1000);
        // 12,5 × 9 = 112,5 m² + 10 % = 123,75 m² / (2,5 × 0,675 = 1,6875 m²) = 73,33 → 74 Platten
        org.junit.Assert.assertEquals(74.0, h.positionen.get(11).getPlattenAnzahl(), 0);
        // 7,5 × 2,6 = 19,5 m² + 10 % = 21,45 / 3,125 = 6,86 → 7 Platten
        org.junit.Assert.assertEquals(7.0, h.positionen.get(12).getPlattenAnzahl(), 0);
        // 48 m² + 15 % = 55,2 / 2,5 = 22,08 → 23 Platten
        org.junit.Assert.assertEquals(23.0, h.positionen.get(13).getPlattenAnzahl(), 0);
        // Dämmung 96 m² + 5 % = 100,8 m² / 5,2 = 19,38 → 20 Pakete; Preis je m²: 20 × 5,2 × 8,90
        org.junit.Assert.assertEquals(20.0, h.positionen.get(15).getPackungen(), 0);
        org.junit.Assert.assertEquals(925.60, h.positionen.get(15).getBetrag(), 1e-6);
        // Mörtel 11,5 Sack → 12 Sack
        org.junit.Assert.assertEquals("12 Sack", h.positionen.get(18).bestellText());
    }
}
