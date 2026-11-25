package de.zimmerei.holzliste;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.UUID;

/**
 * Ein Arbeitszeit-Block: von Kommen bis Gehen (bzw. bis zum Wechsel von Baustelle oder Tätigkeit).
 * Solange {@link #ende} 0 ist, läuft der Block noch.
 */
public class Zeiteintrag {

    public String id = UUID.randomUUID().toString();
    /** Start und Ende in Millisekunden (System.currentTimeMillis); ende = 0 → läuft noch. */
    public long start;
    public long ende;
    /** Bereits abgeschlossene Pausen in Minuten. */
    public int pauseMin;
    /** Beginn einer gerade laufenden Pause (0 = keine Pause). */
    public long pauseSeit;
    /** Baustelle: ID der Materialliste (darf fehlen) und Name zum Zeitpunkt der Buchung. */
    public String baustelleId = "";
    public String baustelle = "";
    public String taetigkeit = "";
    public String mitarbeiter = "";
    public String notiz = "";
    /** Regiestunden (Stundenlohnarbeit, wird extra abgerechnet). */
    public boolean regie;
    /** "" = Arbeit, sonst Abwesenheit: Urlaub, Krank, Feiertag, Berufsschule … (zählt als Soll-Zeit). */
    public String abwesenheit = "";

    public boolean istAbwesenheit() { return abwesenheit != null && !abwesenheit.isEmpty(); }

    public boolean laeuft() { return ende == 0; }

    public boolean inPause() { return laeuft() && pauseSeit > 0; }

    /** Pause in Minuten inkl. einer gerade laufenden Pause. */
    public int pauseMin(long jetzt) {
        int p = pauseMin;
        if (inPause() && jetzt > pauseSeit) p += (int) ((jetzt - pauseSeit) / 60000L);
        return p;
    }

    /** Anwesenheit (Kommen bis Gehen bzw. bis jetzt) in Minuten, ohne Pausenabzug. */
    public int bruttoMin(long jetzt) {
        long bis = laeuft() ? jetzt : ende;
        return bis <= start ? 0 : (int) ((bis - start) / 60000L);
    }

    /** Arbeitszeit in Minuten (Anwesenheit minus Pause), nie negativ. */
    public int nettoMin(long jetzt) {
        return Math.max(0, bruttoMin(jetzt) - pauseMin(jetzt));
    }

    public Zeiteintrag copy() {
        try {
            return fromJson(toJson());
        } catch (JSONException e) {
            throw new RuntimeException(e);
        }
    }

    public JSONObject toJson() throws JSONException {
        JSONObject o = new JSONObject();
        o.put("id", id);
        o.put("start", start);
        o.put("ende", ende);
        o.put("pauseMin", pauseMin);
        o.put("pauseSeit", pauseSeit);
        o.put("baustelleId", baustelleId);
        o.put("baustelle", baustelle);
        o.put("taetigkeit", taetigkeit);
        o.put("mitarbeiter", mitarbeiter);
        o.put("notiz", notiz);
        o.put("regie", regie);
        o.put("abwesenheit", abwesenheit);
        return o;
    }

    public static Zeiteintrag fromJson(JSONObject o) {
        Zeiteintrag z = new Zeiteintrag();
        z.id = o.optString("id", z.id);
        z.start = o.optLong("start", 0);
        z.ende = o.optLong("ende", 0);
        z.pauseMin = o.optInt("pauseMin", 0);
        z.pauseSeit = o.optLong("pauseSeit", 0);
        z.baustelleId = o.optString("baustelleId", "");
        z.baustelle = o.optString("baustelle", "");
        z.taetigkeit = o.optString("taetigkeit", "");
        z.mitarbeiter = o.optString("mitarbeiter", "");
        z.notiz = o.optString("notiz", "");
        z.regie = o.optBoolean("regie", false);
        z.abwesenheit = o.optString("abwesenheit", "");
        return z;
    }
}
