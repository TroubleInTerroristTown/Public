package de.zimmerei.holzliste;

import android.app.Activity;
import android.content.Intent;

import org.junit.After;
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
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/** Zeiterfassung „⏱ Stunden“: Rechenregeln, Speichern, Excel und Screenshots. Namen sind ausgedacht. */
@RunWith(RobolectricTestRunner.class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = 34, qualifiers = "w393dp-h851dp-port-xxhdpi")
public class ZeiterfassungTest {

    static long um(int tag, int monat, int h, int m) {
        Calendar c = Calendar.getInstance(Locale.GERMANY);
        c.clear();
        c.set(2026, monat - 1, tag, h, m);
        return c.getTimeInMillis();
    }

    static Zeiteintrag block(long von, long bis, int pause, String bId, String b, String t) {
        Zeiteintrag z = new Zeiteintrag();
        z.start = von; z.ende = bis; z.pauseMin = pause; z.baustelleId = bId; z.baustelle = b; z.taetigkeit = t;
        z.mitarbeiter = "Max Muster";
        return z;
    }

    @After
    public void aufraeumen() {
        ZeitActivity.testJetzt = 0;
    }

    @Test
    public void regeln() {
        // § 4 ArbZG: über 6 h → 30 min, über 9 h → 45 min; nur so viel, bis die Grenze erreicht ist
        assertEquals(0, Zeiten.fehlendePauseMin(6 * 60, 0));
        assertEquals(20, Zeiten.fehlendePauseMin(6 * 60 + 20, 0));
        assertEquals(30, Zeiten.fehlendePauseMin(8 * 60, 0));
        assertEquals(0, Zeiten.fehlendePauseMin(8 * 60, 30));
        assertEquals(15, Zeiten.fehlendePauseMin(9 * 60 + 30, 30));
        assertEquals(45, Zeiten.fehlendePauseMin(10 * 60, 0));

        List<Zeiteintrag> l = new ArrayList<>();
        Zeiten.kommen(l, um(23, 11, 7, 0) + 35_000, "b1", "Huber", "Montage", "Max");
        Zeiteintrag z = Zeiten.laufend(l);
        assertEquals(um(23, 11, 7, 0), z.start); // auf die Minute gerundet
        Zeiten.pause(z, um(23, 11, 9, 0));
        assertTrue(z.inPause());
        assertEquals(10, z.pauseMin(um(23, 11, 9, 10)));
        Zeiten.pause(z, um(23, 11, 9, 30));
        assertEquals(30, z.pauseMin);
        // Wechsel: alter Block endet, neuer beginnt
        Zeiten.kommen(l, um(23, 11, 12, 0), "b2", "Maier", "Fahrt", "Max");
        assertEquals(2, l.size());
        assertEquals(um(23, 11, 12, 0), l.get(0).ende);
        assertEquals(4 * 60 + 30, l.get(0).nettoMin(0));
        // Gehen mit laufender Pause schließt die Pause mit ab
        Zeiten.pause(Zeiten.laufend(l), um(23, 11, 15, 0));
        Zeiten.gehen(l, um(23, 11, 15, 20));
        assertNull(Zeiten.laufend(l));
        assertEquals(20, l.get(1).pauseMin);
        assertEquals(3 * 60, l.get(1).nettoMin(0));

        assertEquals(48, Zeiten.kalenderwoche(um(24, 11, 12, 0)));
        assertEquals(um(23, 11, 0, 0), Zeiten.wochenStart(um(29, 11, 22, 0)));
        assertEquals("7:30 h", Zeiten.hMin(450));
        assertEquals(7.75, Zeiten.dezimal(465), 1e-9);

        // Urlaub ab Freitag für 3 Arbeitstage: Fr, Mo, Di – je 8 h bei 40 h/Woche
        List<Zeiteintrag> u = Zeiten.abwesenheit(l, "Urlaub", um(27, 11, 0, 0), 3, 40, "Max");
        assertEquals(3, u.size());
        assertEquals(um(30, 11, 7, 0), u.get(1).start);
        assertEquals(8 * 60, u.get(2).nettoMin(0));
        // Saldo 23.11.–2.12.: Ist 7:30 + 24:00 = 31:30, Soll 8 Arbeitstage × 8 h = 64 h
        assertEquals(31 * 60 + 30 - 64 * 60, Zeiten.saldoMin(l, 40, um(2, 12, 18, 0)));

        Zeiteintrag k = l.get(0).copy();
        assertEquals(l.get(0).baustelle, k.baustelle);
        assertEquals(l.get(0).pauseMin, k.pauseMin);
    }

    @Test
    public void bildschirme() throws Exception {
        android.content.Context ctx = RuntimeEnvironment.getApplication();
        Holzliste h = ScreenshotTest.beispiel();
        Storage.speichern(ctx, h);
        Holzliste h2 = ScreenshotTest.beispiel();
        h2.projekt = "Carport Maier"; h2.kunde = "Hr. Maier";
        Storage.speichern(ctx, h2);
        Zeiten.setMitarbeiter(ctx, "Max Muster");

        List<Zeiteintrag> l = new ArrayList<>();
        String bh = h.titel(), bm = h2.titel();
        l.add(block(um(18, 11, 7, 0), um(18, 11, 16, 15), 45, h.id, bh, "Abbund"));
        l.add(block(um(19, 11, 7, 0), um(19, 11, 15, 30), 30, h.id, bh, "Montage"));
        l.add(block(um(20, 11, 7, 0), um(20, 11, 12, 0), 0, h2.id, bm, "Montage"));
        l.get(2).regie = true;
        l.get(2).notiz = "Zusatzarbeit Ortgang";
        l.add(block(um(23, 11, 7, 0), um(23, 11, 11, 30), 15, h2.id, bm, "Dach"));
        l.add(block(um(23, 11, 11, 30), um(23, 11, 12, 15), 0, "", "", "Fahrt"));
        l.add(block(um(23, 11, 12, 15), um(23, 11, 16, 30), 30, h.id, bh, "Montage"));
        Zeiteintrag lauf = block(um(24, 11, 6, 45), 0, 0, h.id, bh, "Montage");
        Zeiten.pause(lauf, um(24, 11, 9, 0));
        Zeiten.pause(lauf, um(24, 11, 9, 15));
        l.add(lauf);
        Zeiten.speichern(ctx, l);
        ZeitActivity.testJetzt = um(24, 11, 10, 20);

        List<Zeiteintrag> geladen = Zeiten.alle(ctx);
        assertEquals(l.size(), geladen.size());
        assertNotNull(Zeiten.laufend(geladen));
        assertTrue(geladen.get(2).regie);

        Activity zeit = Robolectric.buildActivity(ZeitActivity.class).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(zeit.getWindow().getDecorView(), "18_stunden");

        ((ZeitActivity) zeit).bearbeiten(geladen.get(5));
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(ShadowDialog.getLatestDialog().getWindow().getDecorView(), "19_zeit_aendern");
        ShadowDialog.getLatestDialog().dismiss();

        Intent i = new Intent(ctx, ZeitActivity.class);
        i.putExtra(ZeitActivity.EXTRA_BAUSTELLE, h.id);
        Activity zb = Robolectric.buildActivity(ZeitActivity.class, i).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(zb.getWindow().getDecorView(), "20_stunden_baustelle");

        Activity main = Robolectric.buildActivity(MainActivity.class).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(main.getWindow().getDecorView(), "21_start_stunden");

        Intent ib = new Intent(ctx, BaustelleActivity.class);
        ib.putExtra(BaustelleActivity.EXTRA_ID, h.id);
        Activity b = Robolectric.buildActivity(BaustelleActivity.class, ib).setup().get();
        ShadowLooper.idleMainLooper();
        ScreenshotTest.png(b.getWindow().getDecorView(), "22_baustelle_stunden");

        File dir = new File("build/screenshots");
        dir.mkdirs();
        File xlsx = new File(dir, "stunden.xlsx");
        try (FileOutputStream out = new FileOutputStream(xlsx)) {
            ZeitExcel.write(Zeiten.zeitraum(geladen, um(16, 11, 0, 0), um(30, 11, 0, 0), null), "KW 47–48", "Max Muster",
                    ZeitActivity.testJetzt, out);
        }
        assertTrue(xlsx.length() > 1000);
    }
}
