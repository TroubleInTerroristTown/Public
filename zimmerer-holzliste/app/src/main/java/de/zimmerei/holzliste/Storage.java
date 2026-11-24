package de.zimmerei.holzliste;

import android.content.Context;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/** Speichert Holzlisten als JSON-Dateien im internen App-Speicher. */
public final class Storage {

    private Storage() {}

    private static File dir(Context c) {
        File d = new File(c.getFilesDir(), "holzlisten");
        if (!d.exists()) d.mkdirs();
        return d;
    }

    public static List<Holzliste> alle(Context c) {
        List<Holzliste> out = new ArrayList<>();
        File[] files = dir(c).listFiles();
        if (files != null) {
            for (File f : files) {
                if (!f.getName().endsWith(".json")) continue;
                Holzliste h = read(f);
                if (h != null) out.add(h);
            }
        }
        Collections.sort(out, (a, b) -> Long.compare(b.geaendert, a.geaendert));
        return out;
    }

    public static Holzliste laden(Context c, String id) {
        if (id == null) return null;
        return read(new File(dir(c), id + ".json"));
    }

    public static void speichern(Context c, Holzliste h) {
        if (h.id == null) h.id = UUID.randomUUID().toString();
        h.geaendert = System.currentTimeMillis();
        File target = new File(dir(c), h.id + ".json");
        File tmp = new File(dir(c), h.id + ".tmp");
        try (FileOutputStream out = new FileOutputStream(tmp)) {
            out.write(h.toJson().toString().getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        } catch (Exception e) {
            throw new RuntimeException("Speichern fehlgeschlagen: " + e.getMessage(), e);
        }
        if (!tmp.renameTo(target)) {
            target.delete();
            tmp.renameTo(target);
        }
    }

    public static void loeschen(Context c, String id) {
        new File(dir(c), id + ".json").delete();
    }

    public static Holzliste duplizieren(Context c, Holzliste h) {
        Holzliste copy = Holzliste.fromJson(safeJson(h));
        copy.id = null;
        copy.projekt = (h.projekt == null ? "" : h.projekt) + " (Kopie)";
        for (Werkzeug w : copy.werkzeug) w.eingepackt = false; // Vorlage: neu abhaken
        speichern(c, copy);
        return copy;
    }

    private static JSONObject safeJson(Holzliste h) {
        try {
            return h.toJson();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static Holzliste read(File f) {
        if (!f.exists()) return null;
        try (InputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) bos.write(buf, 0, n);
            Holzliste h = Holzliste.fromJson(new JSONObject(bos.toString("UTF-8")));
            if (h.id == null) h.id = f.getName().replace(".json", "");
            return h;
        } catch (IOException | org.json.JSONException e) {
            return null;
        }
    }
}
