package de.zimmerei.holzliste;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Zeiterfassung: Speicher (eine JSON-Datei im App-Speicher) und Rechenregeln.
 * Die Zeiten hängen bewusst nicht an der Baustellen-Datei – ein Arbeitstag kann über mehrere
 * Baustellen gehen, und gelöschte Baustellen sollen die Stunden nicht mitnehmen.
 */
public final class Zeiten {

    private Zeiten() {}

    /** Vorschläge für die Tätigkeit – eigene Eingaben kommen automatisch dazu. */
    public static final String[] TAETIGKEITEN = {
            "Montage", "Abbund", "Dach", "Innenausbau", "Fahrt", "Werkstatt", "Lager / Material holen", "Aufräumen"};

    /** Arten von Abwesenheit – sie zählen mit den Soll-Stunden des Tages. */
    public static final String[] ABWESENHEITEN = {"Urlaub", "Krank", "Feiertag", "Berufsschule", "Zeitausgleich", "Schlechtwetter"};

    private static final Locale DE = Locale.GERMANY;

    // ================================================================ Speicher

    private static File datei(Context c) {
        return new File(c.getFilesDir(), "zeiten.json");
    }

    public static List<Zeiteintrag> alle(Context c) {
        List<Zeiteintrag> out = new ArrayList<>();
        File f = datei(c);
        if (!f.exists()) return out;
        try (InputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) bos.write(buf, 0, n);
            JSONArray a = new JSONObject(bos.toString("UTF-8")).optJSONArray("eintraege");
            if (a != null) for (int i = 0; i < a.length(); i++) out.add(Zeiteintrag.fromJson(a.getJSONObject(i)));
        } catch (Exception e) {
            // defekte Datei: lieber leer anzeigen als abstürzen – die Datei bleibt liegen
        }
        sortieren(out);
        return out;
    }

    public static void speichern(Context c, List<Zeiteintrag> liste) {
        sortieren(liste);
        File ziel = datei(c);
        File tmp = new File(c.getFilesDir(), "zeiten.tmp");
        try (FileOutputStream out = new FileOutputStream(tmp)) {
            JSONArray a = new JSONArray();
            for (Zeiteintrag z : liste) a.put(z.toJson());
            JSONObject o = new JSONObject();
            o.put("version", 1);
            o.put("eintraege", a);
            out.write(o.toString().getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        } catch (Exception e) {
            throw new RuntimeException("Speichern fehlgeschlagen: " + e.getMessage(), e);
        }
        if (!tmp.renameTo(ziel)) {
            ziel.delete();
            tmp.renameTo(ziel);
        }
    }

    public static void sortieren(List<Zeiteintrag> l) {
        Collections.sort(l, (a, b) -> Long.compare(a.start, b.start));
    }

    /** Name für neue Einträge – derselbe wie „Bearbeiter“ in den Kopfdaten. */
    public static String mitarbeiter(Context c) {
        return c.getSharedPreferences("einstellungen", Context.MODE_PRIVATE).getString("bearbeiter", "");
    }

    public static void setMitarbeiter(Context c, String name) {
        c.getSharedPreferences("einstellungen", Context.MODE_PRIVATE).edit().putString("bearbeiter", name).apply();
    }

    /** Wochen-Soll in Stunden (0 = keine Soll-Anzeige). */
    public static double sollWoche(Context c) {
        return c.getSharedPreferences("einstellungen", Context.MODE_PRIVATE).getFloat("sollWoche", 40f);
    }

    public static void setSollWoche(Context c, double h) {
        c.getSharedPreferences("einstellungen", Context.MODE_PRIVATE).edit().putFloat("sollWoche", (float) h).apply();
    }

    // ================================================================ Stempeln

    public static Zeiteintrag laufend(List<Zeiteintrag> l) {
        for (int i = l.size() - 1; i >= 0; i--) if (l.get(i).laeuft()) return l.get(i);
        return null;
    }

    /** Neuen Block beginnen. Ein noch laufender Block wird vorher beendet (= Wechsel). */
    public static Zeiteintrag kommen(List<Zeiteintrag> l, long jetzt, String baustelleId, String baustelle,
                                     String taetigkeit, String mitarbeiter) {
        gehen(l, jetzt);
        Zeiteintrag z = new Zeiteintrag();
        z.start = runden(jetzt);
        z.baustelleId = baustelleId == null ? "" : baustelleId;
        z.baustelle = baustelle == null ? "" : baustelle;
        z.taetigkeit = taetigkeit == null ? "" : taetigkeit;
        z.mitarbeiter = mitarbeiter == null ? "" : mitarbeiter;
        l.add(z);
        return z;
    }

    /** Laufenden Block beenden (eine laufende Pause wird mit abgeschlossen). */
    public static Zeiteintrag gehen(List<Zeiteintrag> l, long jetzt) {
        Zeiteintrag z = laufend(l);
        if (z == null) return null;
        if (z.inPause()) pause(z, jetzt);
        z.ende = Math.max(z.start, runden(jetzt));
        return z;
    }

    /** Pause beginnen bzw. beenden. */
    public static void pause(Zeiteintrag z, long jetzt) {
        if (z == null || !z.laeuft()) return;
        if (z.pauseSeit > 0) {
            z.pauseMin = z.pauseMin(jetzt);
            z.pauseSeit = 0;
        } else {
            z.pauseSeit = jetzt;
        }
    }

    /** Auf volle Minuten abrunden – Sekunden interessieren auf dem Stundenzettel niemanden. */
    static long runden(long t) {
        return t - (t % 60000L);
    }

    // ================================================================ Rechnen

    /**
     * Fehlende Pause nach § 4 ArbZG für einen Tag: über 6 h Arbeit mindestens 30 min, über 9 h mindestens 45 min.
     * Gibt höchstens so viel zurück, dass die Arbeitszeit auf die jeweilige Grenze fällt.
     */
    public static int fehlendePauseMin(int tagNettoMin, int tagPauseMin) {
        int noetig, grenze;
        if (tagNettoMin > 9 * 60) { noetig = 45; grenze = 9 * 60; }
        else if (tagNettoMin > 6 * 60) { noetig = 30; grenze = 6 * 60; }
        else return 0;
        int fehlt = noetig - tagPauseMin;
        if (fehlt <= 0) return 0;
        return Math.min(fehlt, tagNettoMin - grenze);
    }

    /** Tag als Schlüssel „yyyy-MM-dd“ (Tag des Beginns – Nachtschichten zählen zum Anfangstag). */
    public static String tag(long t) {
        return new SimpleDateFormat("yyyy-MM-dd", DE).format(new Date(t));
    }

    /** 0:00 Uhr des Tages, in dem t liegt. */
    public static long tagesStart(long t) {
        Calendar c = Calendar.getInstance(DE);
        c.setTimeInMillis(t);
        c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0);
        return c.getTimeInMillis();
    }

    /** Montag 0:00 der Woche, in der t liegt. */
    public static long wochenStart(long t) {
        Calendar c = Calendar.getInstance(DE);
        c.setFirstDayOfWeek(Calendar.MONDAY);
        c.setTimeInMillis(t);
        c.set(Calendar.HOUR_OF_DAY, 0);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        while (c.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) c.add(Calendar.DAY_OF_MONTH, -1);
        return c.getTimeInMillis();
    }

    /** t verschoben um n Tage (sommerzeitfest über den Kalender). */
    public static long plusTage(long t, int n) {
        Calendar c = Calendar.getInstance(DE);
        c.setTimeInMillis(t);
        c.add(Calendar.DAY_OF_MONTH, n);
        return c.getTimeInMillis();
    }

    /** Erster Tag des Monats 0:00. */
    public static long monatsStart(long t) {
        Calendar c = Calendar.getInstance(DE);
        c.setTimeInMillis(t);
        c.set(Calendar.DAY_OF_MONTH, 1);
        c.set(Calendar.HOUR_OF_DAY, 0);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        return c.getTimeInMillis();
    }

    public static long plusMonate(long t, int n) {
        Calendar c = Calendar.getInstance(DE);
        c.setTimeInMillis(t);
        c.add(Calendar.MONTH, n);
        return c.getTimeInMillis();
    }

    public static int kalenderwoche(long t) {
        Calendar c = Calendar.getInstance(DE);
        c.setFirstDayOfWeek(Calendar.MONDAY);
        c.setMinimalDaysInFirstWeek(4);
        c.setTimeInMillis(t);
        return c.get(Calendar.WEEK_OF_YEAR);
    }

    /** Einträge mit Beginn in [von, bis), optional nur eine Baustelle. */
    public static List<Zeiteintrag> zeitraum(List<Zeiteintrag> l, long von, long bis, String baustelleId) {
        List<Zeiteintrag> out = new ArrayList<>();
        for (Zeiteintrag z : l) {
            if (z.start < von || z.start >= bis) continue;
            if (baustelleId != null && !baustelleId.equals(z.baustelleId)) continue;
            out.add(z);
        }
        return out;
    }

    public static int summeMin(List<Zeiteintrag> l, long jetzt) {
        int s = 0;
        for (Zeiteintrag z : l) s += z.nettoMin(jetzt);
        return s;
    }

    /** Nach Tag gruppiert (Reihenfolge wie in der Liste). */
    public static Map<String, List<Zeiteintrag>> nachTag(List<Zeiteintrag> l) {
        Map<String, List<Zeiteintrag>> m = new LinkedHashMap<>();
        for (Zeiteintrag z : l) {
            String k = tag(z.start);
            List<Zeiteintrag> t = m.get(k);
            if (t == null) m.put(k, t = new ArrayList<>());
            t.add(z);
        }
        return m;
    }

    /** Summe in Minuten je Schlüssel (Baustelle oder Tätigkeit), größte zuerst. */
    public static List<Map.Entry<String, Integer>> summeNach(List<Zeiteintrag> l, boolean nachBaustelle, long jetzt) {
        Map<String, Integer> m = new LinkedHashMap<>();
        for (Zeiteintrag z : l) {
            String k = z.istAbwesenheit() ? z.abwesenheit : nachBaustelle ? z.baustelle : z.taetigkeit;
            if (k == null || k.trim().isEmpty()) k = nachBaustelle ? "(ohne Baustelle)" : "(ohne Tätigkeit)";
            Integer alt = m.get(k);
            m.put(k, (alt == null ? 0 : alt) + z.nettoMin(jetzt));
        }
        List<Map.Entry<String, Integer>> out = new ArrayList<>(m.entrySet());
        Collections.sort(out, (a, b) -> Integer.compare(b.getValue(), a.getValue()));
        return out;
    }

    /** Vorschlagsliste: zuletzt benutzte eigene Tätigkeiten zuerst, dann die Standardliste. */
    public static List<String> taetigkeiten(List<Zeiteintrag> l) {
        Set<String> s = new LinkedHashSet<>();
        for (int i = l.size() - 1; i >= 0 && s.size() < 6; i--) {
            String t = l.get(i).taetigkeit;
            if (t != null && !t.trim().isEmpty()) s.add(t.trim());
        }
        Collections.addAll(s, TAETIGKEITEN);
        return new ArrayList<>(s);
    }

    /** Soll-Minuten eines Arbeitstags (Mo–Fr = Wochen-Soll / 5, Sa/So = 0). */
    public static int sollTagMin(long tag, double sollWoche) {
        Calendar c = Calendar.getInstance(DE);
        c.setTimeInMillis(tag);
        int wt = c.get(Calendar.DAY_OF_WEEK);
        if (wt == Calendar.SATURDAY || wt == Calendar.SUNDAY) return 0;
        return (int) Math.round(sollWoche * 60 / 5.0);
    }

    /**
     * Überstunden-Saldo in Minuten: Ist minus Soll für alle Tage vom ersten Eintrag bis einschließlich heute.
     * Feiertage kennt die App nicht – die muss man als Abwesenheit „Feiertag“ eintragen, sonst fehlen sie im Saldo.
     */
    public static int saldoMin(List<Zeiteintrag> l, double sollWoche, long jetzt) {
        if (l.isEmpty() || sollWoche <= 0) return 0;
        long tag = tagesStart(l.get(0).start);
        long ende = plusTage(tagesStart(jetzt), 1);
        int soll = 0;
        for (long t = tag; t < ende; t = plusTage(t, 1)) soll += sollTagMin(t, sollWoche);
        return summeMin(zeitraum(l, tag, ende, null), jetzt) - soll;
    }

    /** Abwesenheit (Urlaub, Krank …) ab Tag „von“ für n Arbeitstage (Mo–Fr) mit je dem Tages-Soll eintragen. */
    public static List<Zeiteintrag> abwesenheit(List<Zeiteintrag> l, String art, long von, int arbeitstage,
                                                double sollWoche, String mitarbeiter) {
        List<Zeiteintrag> neu = new ArrayList<>();
        long t = tagesStart(von);
        for (int sicher = 0; neu.size() < arbeitstage && sicher < 400; sicher++, t = plusTage(t, 1)) {
            int min = sollTagMin(t, sollWoche);
            if (min == 0) continue;
            Zeiteintrag z = new Zeiteintrag();
            z.start = t + 7 * 3600_000L;  // 7:00 Uhr, nur damit es in der Liste sauber steht
            z.ende = z.start + min * 60_000L;
            z.abwesenheit = art;
            z.mitarbeiter = mitarbeiter == null ? "" : mitarbeiter;
            neu.add(z);
        }
        l.addAll(neu);
        sortieren(l);
        return neu;
    }

    // ================================================================ Anzeige

    /** Minuten als „7:45 h“. */
    public static String hMin(int min) {
        String v = min < 0 ? "−" : "";
        min = Math.abs(min);
        return v + (min / 60) + ":" + String.format(DE, "%02d", min % 60) + " h";
    }

    /** Minuten als Dezimalstunden „7,75“ (für den Lohn). */
    public static double dezimal(int min) {
        return Math.round(min / 60.0 * 100) / 100.0;
    }

    public static String uhr(long t) {
        return new SimpleDateFormat("HH:mm", DE).format(new Date(t));
    }

    public static String datumLang(long t) {
        return new SimpleDateFormat("EEEE, dd.MM.", DE).format(new Date(t));
    }

    public static String datum(long t) {
        return new SimpleDateFormat("dd.MM.yyyy", DE).format(new Date(t));
    }
}
