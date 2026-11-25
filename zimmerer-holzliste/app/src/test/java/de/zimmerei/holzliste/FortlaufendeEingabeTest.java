package de.zimmerei.holzliste;

import android.app.AlertDialog;
import android.content.Intent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AutoCompleteTextView;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowDialog;
import org.robolectric.shadows.ShadowLooper;

import java.lang.reflect.Method;

import static org.junit.Assert.*;

/** „Weiter ›“ speichert und öffnet sofort die nächste Eingabe; „Fertig“ ohne Eingabe speichert nichts. */
@RunWith(RobolectricTestRunner.class)
@org.robolectric.annotation.GraphicsMode(org.robolectric.annotation.GraphicsMode.Mode.NATIVE)
@Config(sdk = 34, qualifiers = "w393dp-h851dp-port-xxhdpi")
public class FortlaufendeEingabeTest {

    @Test
    public void weiterUndFertig() throws Exception {
        Holzliste h = new Holzliste();
        h.projekt = "Test";
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();

        Method neu = EditorActivity.class.getDeclaredMethod("neuePosition", Position.class, int.class);
        neu.setAccessible(true);
        Position p = new Position();
        p.typ = Position.PLATTE;
        p.holzart = "OSB/3"; p.laenge = 2.5; p.breite = 125.0; p.hoehe = 1.5; p.verschnitt = 10.0;
        neu.invoke(ed, p, 0);
        ShadowLooper.idleMainLooper();

        AlertDialog d1 = (AlertDialog) ShadowDialog.getLatestDialog();
        assertEquals("Weiter ›", d1.getButton(AlertDialog.BUTTON_POSITIVE).getText().toString());
        assertEquals("Fertig", d1.getButton(AlertDialog.BUTTON_NEUTRAL).getText().toString());

        // Leer + Weiter: nichts passiert, Dialog bleibt offen
        d1.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertTrue(d1.isShowing());
        assertEquals(0, Storage.laden(ed, h.id).positionen.size());

        // Bezeichnung eingeben + Weiter: gespeichert, nächste Eingabe offen (gleiches Format)
        findAuto(d1.getWindow().getDecorView()).setText("Wand Nord");
        d1.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertFalse(d1.isShowing());
        assertEquals(1, Storage.laden(ed, h.id).positionen.size());
        AlertDialog d2 = (AlertDialog) ShadowDialog.getLatestDialog();
        assertNotSame(d1, d2);
        assertTrue(d2.isShowing());
        png(d2.getWindow().getDecorView(), "11_weiter");

        // Zweite Position + Fertig: gespeichert, keine weitere Eingabe
        findAuto(d2.getWindow().getDecorView()).setText("Wand Süd");
        d2.getButton(AlertDialog.BUTTON_NEUTRAL).performClick();
        ShadowLooper.idleMainLooper();
        assertFalse(d2.isShowing());
        Holzliste gespeichert = Storage.laden(ed, h.id);
        assertEquals(2, gespeichert.positionen.size());
        Position zweite = gespeichert.positionen.get(1);
        assertEquals("Wand Süd", zweite.bezeichnung);
        assertEquals("OSB/3", zweite.holzart);           // Material übernommen
        assertEquals(125.0, zweite.breite, 1e-9);         // Plattenformat übernommen
        assertEquals(10.0, zweite.verschnitt, 1e-9);
        assertSame(d2, ShadowDialog.getLatestDialog());   // kein neuer Dialog
    }

    private EditorActivity editor(Holzliste h) {
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        return ed;
    }

    /** Sonstiges Material: „Weiter ›“ öffnet die nächste Eingabe, Material + Einheit werden übernommen. */
    @Test
    public void materialFortlaufend() throws Exception {
        Holzliste h = new Holzliste();
        EditorActivity ed = editor(h);
        Method neu = EditorActivity.class.getDeclaredMethod("neuePosition", Position.class, int.class);
        neu.setAccessible(true);
        Position p = new Position();
        p.typ = Position.MATERIAL;
        neu.invoke(ed, p, 0);
        ShadowLooper.idleMainLooper();

        AlertDialog d1 = (AlertDialog) ShadowDialog.getLatestDialog();
        assertEquals("Weiter ›", d1.getButton(AlertDialog.BUTTON_POSITIVE).getText().toString());
        java.util.List<android.widget.EditText> felder = new java.util.ArrayList<>();
        sammleEdit(d1.getWindow().getDecorView(), felder);
        findAuto(d1.getWindow().getDecorView()).setText("Holzbauschrauben 8x240");
        // Material + Einheit über die Felder setzen: Einheit/Material sind AutoCompleteTextViews
        java.util.List<AutoCompleteTextView> autos = new java.util.ArrayList<>();
        sammleAuto(d1.getWindow().getDecorView(), autos);
        for (android.widget.EditText e : felder)
            if ("Menge".equals(String.valueOf(e.getHint()))) e.setText("200");
        for (AutoCompleteTextView a : autos)
            if (String.valueOf(a.getHint()).toLowerCase().contains("stk") || String.valueOf(a.getHint()).toLowerCase().contains("einheit")) a.setText("Stk");
        d1.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertEquals(1, Storage.laden(ed, h.id).positionen.size());
        Position erste = Storage.laden(ed, h.id).positionen.get(0);
        assertEquals(Position.MATERIAL, erste.typ);
        AlertDialog d2 = (AlertDialog) ShadowDialog.getLatestDialog();
        assertNotSame(d1, d2);
        assertTrue(d2.isShowing());
        assertEquals("Weiter ›", d2.getButton(AlertDialog.BUTTON_POSITIVE).getText().toString());
        // nächste Eingabe ist wieder sonstiges Material mit gleicher Einheit
        d2.getButton(AlertDialog.BUTTON_NEUTRAL).performClick(); // Fertig ohne Eingabe
        ShadowLooper.idleMainLooper();
        assertEquals(1, Storage.laden(ed, h.id).positionen.size());
    }

    /** Aus der Artikelliste: „Weiter ›“ öffnet direkt wieder die Artikelsuche. */
    @Test
    public void artikellisteFortlaufend() throws Exception {
        Datanorm.Ergebnis dn = Datanorm.lesen(getClass().getResourceAsStream("/DATANORM.001"), "DATANORM.001");
        Katalog.speichern(RuntimeEnvironment.getApplication(), dn);
        Holzliste h = new Holzliste();
        EditorActivity ed = editor(h);
        Method neu = EditorActivity.class.getDeclaredMethod("neuePosition", Position.class, int.class, boolean.class);
        neu.setAccessible(true);
        Position p = new Position();
        PositionDialog.anwenden(p, dn.artikel.get(0));
        neu.invoke(ed, p, 0, true);
        ShadowLooper.idleMainLooper();

        AlertDialog d1 = (AlertDialog) ShadowDialog.getLatestDialog();
        assertEquals("Weiter ›", d1.getButton(AlertDialog.BUTTON_POSITIVE).getText().toString());
        d1.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertEquals(1, Storage.laden(ed, h.id).positionen.size());
        AlertDialog suche = (AlertDialog) ShadowDialog.getLatestDialog();
        assertNotSame(d1, suche);
        assertTrue(suche.isShowing());
        assertEquals("Artikel suchen", String.valueOf(org.robolectric.Shadows.shadowOf(suche).getTitle()));
    }

    private static void sammleEdit(View v, java.util.List<android.widget.EditText> l) {
        if (v instanceof android.widget.EditText) l.add((android.widget.EditText) v);
        if (v instanceof ViewGroup)
            for (int i = 0; i < ((ViewGroup) v).getChildCount(); i++) sammleEdit(((ViewGroup) v).getChildAt(i), l);
    }

    private static void sammleAuto(View v, java.util.List<AutoCompleteTextView> l) {
        if (v instanceof AutoCompleteTextView) l.add((AutoCompleteTextView) v);
        if (v instanceof ViewGroup)
            for (int i = 0; i < ((ViewGroup) v).getChildCount(); i++) sammleAuto(((ViewGroup) v).getChildAt(i), l);
    }

    private static void png(View v, String name) throws Exception {
        android.graphics.Bitmap bmp = android.graphics.Bitmap.createBitmap(v.getWidth(), v.getHeight(), android.graphics.Bitmap.Config.ARGB_8888);
        v.draw(new android.graphics.Canvas(bmp));
        java.io.File dir = new java.io.File("build/screenshots");
        dir.mkdirs();
        try (java.io.FileOutputStream out = new java.io.FileOutputStream(new java.io.File(dir, name + ".png"))) {
            bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out);
        }
    }

    private static AutoCompleteTextView findAuto(View v) {
        if (v instanceof AutoCompleteTextView) return (AutoCompleteTextView) v;
        if (v instanceof ViewGroup)
            for (int i = 0; i < ((ViewGroup) v).getChildCount(); i++) {
                AutoCompleteTextView a = findAuto(((ViewGroup) v).getChildAt(i));
                if (a != null) return a;
            }
        return null;
    }
}
