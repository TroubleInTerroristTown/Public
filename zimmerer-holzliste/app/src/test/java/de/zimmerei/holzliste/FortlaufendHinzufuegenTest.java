package de.zimmerei.holzliste;

import android.app.AlertDialog;
import android.content.Intent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;

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

/** Nach dem Hinzufügen einer Aufgabe bzw. eines Materials öffnet sich sofort die nächste Eingabe. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34, qualifiers = "w393dp-h851dp-port-xxhdpi")
public class FortlaufendHinzufuegenTest {

    private EditorActivity editor(Holzliste h) {
        Storage.speichern(RuntimeEnvironment.getApplication(), h);
        Intent i = new Intent(RuntimeEnvironment.getApplication(), EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, h.id);
        EditorActivity ed = Robolectric.buildActivity(EditorActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        return ed;
    }

    @Test
    public void aufgabenNacheinander() {
        Holzliste h = new Holzliste();
        h.projekt = "Test";
        EditorActivity ed = editor(h);
        int[] geaendert = {0};
        AufgabenAnsicht.bearbeiten(ed, h, -1, -1, () -> geaendert[0]++);
        ShadowLooper.idleMainLooper();

        AlertDialog d1 = (AlertDialog) ShadowDialog.getLatestDialog();
        EditText[] f1 = felder(d1);
        f1[0].setText("Sparren abbinden");
        f1[1].setText("Zimmererarbeiten");
        d1.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertEquals(1, h.aufgaben.size());

        // nächste Aufgabe ist sofort offen, Abschnitt übernommen
        AlertDialog d2 = (AlertDialog) ShadowDialog.getLatestDialog();
        assertNotSame(d1, d2);
        assertTrue(d2.isShowing());
        EditText[] f2 = felder(d2);
        assertEquals("", f2[0].getText().toString());
        assertEquals("Zimmererarbeiten", f2[1].getText().toString());
        f2[0].setText("Pfetten auflegen");
        d2.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertEquals(2, h.aufgaben.size());
        assertEquals("Pfetten auflegen", h.aufgaben.get(1).text);

        // Abbrechen beendet die Eingabe
        AlertDialog d3 = (AlertDialog) ShadowDialog.getLatestDialog();
        d3.getButton(AlertDialog.BUTTON_NEGATIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertFalse(d3.isShowing());
        assertEquals(2, h.aufgaben.size());
        assertSame(d3, ShadowDialog.getLatestDialog());
    }

    @Test
    public void materialNacheinander() throws Exception {
        Holzliste h = new Holzliste();
        h.projekt = "Test";
        EditorActivity ed = editor(h);
        Method neu = EditorActivity.class.getDeclaredMethod("neuePosition", Position.class, int.class);
        neu.setAccessible(true);
        Position p = new Position();
        p.typ = Position.MATERIAL;
        neu.invoke(ed, p, 0);
        ShadowLooper.idleMainLooper();

        AlertDialog d1 = (AlertDialog) ShadowDialog.getLatestDialog();
        felder(d1)[0].setText("Holzbauschrauben 8x240");
        d1.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        ShadowLooper.idleMainLooper();
        assertEquals(1, Storage.laden(ed, h.id).positionen.size());

        // nächste Material-Eingabe ist sofort offen
        AlertDialog d2 = (AlertDialog) ShadowDialog.getLatestDialog();
        assertNotSame(d1, d2);
        assertTrue(d2.isShowing());
        d2.getButton(AlertDialog.BUTTON_NEGATIVE).performClick(); // Abbrechen = fertig
        ShadowLooper.idleMainLooper();
        assertFalse(d2.isShowing());
        assertEquals(1, Storage.laden(ed, h.id).positionen.size());
    }

    private static EditText[] felder(AlertDialog d) {
        java.util.List<EditText> l = new java.util.ArrayList<>();
        sammle(d.getWindow().getDecorView(), l);
        return l.toArray(new EditText[0]);
    }

    private static void sammle(View v, java.util.List<EditText> l) {
        if (v instanceof EditText && v.getVisibility() == View.VISIBLE) l.add((EditText) v);
        if (v instanceof ViewGroup)
            for (int i = 0; i < ((ViewGroup) v).getChildCount(); i++) sammle(((ViewGroup) v).getChildAt(i), l);
    }
}
