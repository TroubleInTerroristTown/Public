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
 * Rendert die wichtigsten Bildschirme als PNG (build/screenshots) und prüft den Excel-Export.
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
        return h;
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
        png(ed.getWindow().getDecorView(), "2_holzliste");

        new PositionDialog(ed, h.positionen.get(1).copy(), false, java.util.Collections.emptySet(), (x, y) -> {}).show();
        ShadowLooper.idleMainLooper();
        Dialog d = ShadowDialog.getLatestDialog();
        png(d.getWindow().getDecorView(), "3_position");

        File xlsx = new File("build/screenshots/test.xlsx");
        try (FileOutputStream out = new FileOutputStream(xlsx)) { HolzlisteExcel.write(h, out); }
        assertTrue(xlsx.length() > 1000);
    }
}
