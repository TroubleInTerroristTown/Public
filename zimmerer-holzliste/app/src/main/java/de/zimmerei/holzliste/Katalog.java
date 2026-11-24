package de.zimmerei.holzliste;

import android.content.Context;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/** Gespeicherte Händlerkataloge (aus DATANORM importiert) mit Suche. */
public final class Katalog {

    private Katalog() {}

    public static final class Info {
        public String id, name;
        public int anzahl;
        public long datum;
    }

    /** Artikel + Händlername + Suchtext (klein geschrieben). */
    public static final class Eintrag {
        public final Datanorm.Artikel a;
        public final String haendler, such;

        Eintrag(Datanorm.Artikel a, String haendler) {
            this.a = a;
            this.haendler = haendler;
            this.such = (a.text + " " + a.nr + " " + haendler).toLowerCase(Locale.GERMANY);
        }
    }

    private static List<Eintrag> cache;

    private static File dir(Context c) {
        File d = new File(c.getFilesDir(), "kataloge");
        if (!d.exists()) d.mkdirs();
        return d;
    }

    // Dateiformat: Kopfzeile "#<name>\t<anzahl>\t<datum>", danach je Artikel eine Zeile (Tab-getrennt)
    public static synchronized Info speichern(Context c, Datanorm.Ergebnis e) throws IOException {
        Info info = new Info();
        info.id = "k" + System.currentTimeMillis();
        info.name = e.haendler.isEmpty() ? "Händlerkatalog" : e.haendler;
        info.anzahl = e.artikel.size();
        info.datum = System.currentTimeMillis();
        File f = new File(dir(c), info.id + ".tsv");
        try (BufferedWriter w = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(f), StandardCharsets.UTF_8))) {
            w.write("#" + clean(info.name) + "\t" + info.anzahl + "\t" + info.datum + "\n");
            for (Datanorm.Artikel a : e.artikel) {
                w.write(clean(a.nr) + "\t" + clean(a.text) + "\t" + clean(a.einheit) + "\t" + n(a.preis) + "\t"
                        + (a.netto ? "1" : "0") + "\t" + (a.platte ? "1" : "0") + "\t"
                        + n(a.b) + "\t" + n(a.h) + "\t" + n(a.l) + "\t" + n(a.pb) + "\n");
            }
        }
        cache = null;
        return info;
    }

    public static synchronized List<Info> liste(Context c) {
        List<Info> out = new ArrayList<>();
        File[] files = dir(c).listFiles();
        if (files == null) return out;
        for (File f : files) {
            if (!f.getName().endsWith(".tsv")) continue;
            try (BufferedReader r = reader(f)) {
                String kopf = r.readLine();
                if (kopf == null || !kopf.startsWith("#")) continue;
                String[] k = kopf.substring(1).split("\t", -1);
                Info i = new Info();
                i.id = f.getName().replace(".tsv", "");
                i.name = k[0];
                i.anzahl = k.length > 1 ? parseInt(k[1]) : 0;
                i.datum = k.length > 2 ? parseLong(k[2]) : f.lastModified();
                out.add(i);
            } catch (IOException ignored) {
            }
        }
        Collections.sort(out, (a, b) -> Long.compare(b.datum, a.datum));
        return out;
    }

    public static synchronized void loeschen(Context c, String id) {
        new File(dir(c), id + ".tsv").delete();
        cache = null;
    }

    public static synchronized List<Eintrag> alle(Context c) {
        if (cache != null) return cache;
        List<Eintrag> out = new ArrayList<>();
        for (Info i : liste(c)) {
            try (BufferedReader r = reader(new File(dir(c), i.id + ".tsv"))) {
                r.readLine();
                String line;
                while ((line = r.readLine()) != null) {
                    String[] f = line.split("\t", -1);
                    if (f.length < 10) continue;
                    Datanorm.Artikel a = new Datanorm.Artikel();
                    a.nr = f[0]; a.text = f[1]; a.einheit = f[2]; a.preis = d(f[3]);
                    a.netto = "1".equals(f[4]); a.platte = "1".equals(f[5]);
                    a.b = d(f[6]); a.h = d(f[7]); a.l = d(f[8]); a.pb = d(f[9]);
                    out.add(new Eintrag(a, i.name));
                }
            } catch (IOException ignored) {
            }
        }
        cache = out;
        return out;
    }

    /**
     * Suche: alle Wörter müssen vorkommen. Maße wie "8/20" oder "80x200" werden auch über die
     * erkannten Maße gefunden. typFilter: null = alle, true = nur Platten, false = nur Hölzer.
     */
    public static List<Eintrag> suche(List<Eintrag> alle, String query, Boolean typFilter, int max) {
        String[] woerter = query.toLowerCase(Locale.GERMANY).trim().split("\\s+");
        List<Eintrag> out = new ArrayList<>();
        for (Eintrag e : alle) {
            if (typFilter != null && e.a.platte != typFilter) continue;
            boolean ok = true;
            for (String w : woerter) {
                if (w.isEmpty()) continue;
                if (!e.such.contains(w) && !passtMass(e.a, w)) { ok = false; break; }
            }
            if (ok) {
                out.add(e);
                if (out.size() >= max) break;
            }
        }
        return out;
    }

    /** "8/20", "8x20", "80/200" (mm) passen auf den erkannten Querschnitt. */
    private static boolean passtMass(Datanorm.Artikel a, String w) {
        String[] p = w.replace('x', '/').replace('×', '/').split("/");
        if (p.length != 2 || a.b == null || a.h == null) return false;
        Double x = Fmt.parse(p[0]), y = Fmt.parse(p[1]);
        if (x == null || y == null) return false;
        return (eq(x, a.b) && eq(y, a.h)) || (eq(x / 10, a.b) && eq(y / 10, a.h));
    }

    private static boolean eq(double a, double b) { return Math.abs(a - b) < 0.001; }

    private static BufferedReader reader(File f) throws IOException {
        return new BufferedReader(new InputStreamReader(new FileInputStream(f), StandardCharsets.UTF_8));
    }

    private static String clean(String s) { return s == null ? "" : s.replace('\t', ' ').replace('\n', ' ').replace('\r', ' '); }
    private static String n(Double d) { return d == null ? "" : Double.toString(d); }
    private static Double d(String s) { try { return s.isEmpty() ? null : Double.parseDouble(s); } catch (NumberFormatException e) { return null; } }
    private static int parseInt(String s) { try { return Integer.parseInt(s.trim()); } catch (NumberFormatException e) { return 0; } }
    private static long parseLong(String s) { try { return Long.parseLong(s.trim()); } catch (NumberFormatException e) { return 0; } }
}
