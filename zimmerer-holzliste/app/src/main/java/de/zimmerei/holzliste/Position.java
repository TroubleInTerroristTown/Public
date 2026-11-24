package de.zimmerei.holzliste;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Eine Zeile der Holzliste.
 *
 * Typen:
 *  - HOLZ   : Stückholz mit Stückzahl, Querschnitt (B/H in cm) und Länge (m)
 *  - LFM    : Laufmeterholz (Latten, Bretter, Schalung ...) – Querschnitt + Gesamt-Laufmeter
 *  - TITEL  : Abschnitts-Überschrift (z. B. "Dachstuhl", "Pfetten")
 */
public class Position {

    public static final String HOLZ = "holz";
    public static final String LFM = "lfm";
    public static final String TITEL = "titel";

    public String typ = HOLZ;
    public String bezeichnung = "";
    public Double stueck;
    public Double breite;     // cm (Rohmaß)
    public Double hoehe;      // cm (Rohmaß)
    public Double laenge;     // m  (nur HOLZ)
    public Double laufmeter;  // m  (nur LFM, Eingabe)
    public Double fertigB;    // cm (Fertigmaß)
    public Double fertigH;    // cm (Fertigmaß)
    public String holzart = "";
    public String bemerkung = "";

    public boolean isTitel() { return TITEL.equals(typ); }
    public boolean isLfm() { return LFM.equals(typ); }
    public boolean isHolz() { return HOLZ.equals(typ); }

    private static double v(Double d) { return d == null ? 0 : d; }

    /** Gesamt-Laufmeter der Zeile in m. */
    public double getLaufmeterGesamt() {
        if (isHolz()) return v(stueck) * v(laenge);
        if (isLfm()) return v(laufmeter);
        return 0;
    }

    /** Volumen (Rohmaß) in m³. */
    public double getVolumen() {
        if (isTitel()) return 0;
        return getLaufmeterGesamt() * v(breite) * v(hoehe) / 10000.0;
    }

    public boolean hasFertigmass() { return fertigB != null || fertigH != null; }

    public Position copy() {
        Position p = new Position();
        p.typ = typ; p.bezeichnung = bezeichnung; p.stueck = stueck; p.breite = breite;
        p.hoehe = hoehe; p.laenge = laenge; p.laufmeter = laufmeter; p.fertigB = fertigB;
        p.fertigH = fertigH; p.holzart = holzart; p.bemerkung = bemerkung;
        return p;
    }

    public JSONObject toJson() throws JSONException {
        JSONObject o = new JSONObject();
        o.put("typ", typ);
        o.put("bez", bezeichnung);
        put(o, "stk", stueck);
        put(o, "b", breite);
        put(o, "h", hoehe);
        put(o, "l", laenge);
        put(o, "lfm", laufmeter);
        put(o, "fb", fertigB);
        put(o, "fh", fertigH);
        o.put("holzart", holzart);
        o.put("bem", bemerkung);
        return o;
    }

    public static Position fromJson(JSONObject o) {
        Position p = new Position();
        p.typ = o.optString("typ", HOLZ);
        p.bezeichnung = o.optString("bez", "");
        p.stueck = get(o, "stk");
        p.breite = get(o, "b");
        p.hoehe = get(o, "h");
        p.laenge = get(o, "l");
        p.laufmeter = get(o, "lfm");
        p.fertigB = get(o, "fb");
        p.fertigH = get(o, "fh");
        p.holzart = o.optString("holzart", "");
        p.bemerkung = o.optString("bem", "");
        return p;
    }

    private static void put(JSONObject o, String k, Double d) throws JSONException {
        if (d != null) o.put(k, d.doubleValue());
    }

    private static Double get(JSONObject o, String k) {
        if (!o.has(k) || o.isNull(k)) return null;
        double d = o.optDouble(k, Double.NaN);
        return Double.isNaN(d) ? null : d;
    }
}
