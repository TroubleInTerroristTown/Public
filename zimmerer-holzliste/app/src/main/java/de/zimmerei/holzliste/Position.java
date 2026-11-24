package de.zimmerei.holzliste;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Eine Zeile der Holzliste.
 *
 * Typen:
 *  - HOLZ   : Stückholz mit Stückzahl, Querschnitt (B/H in cm) und Länge (m)
 *  - LFM    : Laufmeterholz (Latten, Bretter, Schalung ...) – Querschnitt + Gesamt-Laufmeter
 *  - PLATTE : Plattenwerkstoff (OSB, Gips, Dreischicht ...). Eingabe der zu belegenden Fläche
 *             (Länge × Breite in m oder direkt m²) + Verschnitt %; Plattenformat in laenge (m),
 *             breite (cm), hoehe (cm = Dicke). Die Plattenanzahl wird aufgerundet berechnet.
 *  - TITEL  : Abschnitts-Überschrift (z. B. "Dachstuhl", "Pfetten")
 */
public class Position {

    public static final String HOLZ = "holz";
    public static final String LFM = "lfm";
    public static final String PLATTE = "platte";
    public static final String TITEL = "titel";

    public String typ = HOLZ;
    public String bezeichnung = "";
    public Double stueck;
    public Double breite;     // cm (Rohmaß; bei Platten: Plattenbreite)
    public Double hoehe;      // cm (Rohmaß; bei Platten: Dicke)
    public Double laenge;     // m  (HOLZ und PLATTE)
    public Double flaeche;    // m² (nur PLATTE: zu belegende Fläche direkt)
    public Double flL, flB;   // m  (nur PLATTE: zu belegende Fläche Länge × Breite)
    public Double verschnitt; // %  (nur PLATTE)
    public Double laufmeter;  // m  (nur LFM, Eingabe)
    public Double fertigB;    // cm (Fertigmaß)
    public Double fertigH;    // cm (Fertigmaß)
    public String holzart = "";
    public String bemerkung = "";

    public boolean isTitel() { return TITEL.equals(typ); }
    public boolean isLfm() { return LFM.equals(typ); }
    public boolean isHolz() { return HOLZ.equals(typ); }
    public boolean isPlatte() { return PLATTE.equals(typ); }

    /** Platte: zu belegende Fläche wurde angegeben (L × B oder m²). */
    public boolean hatFlaechenEingabe() {
        return isPlatte() && ((flL != null && flB != null) || flaeche != null);
    }

    /** Zu belegende Netto-Fläche in m² (nur Platten). */
    public double getFlaeche() {
        if (!isPlatte()) return 0;
        if (flL != null && flB != null) return flL * flB;
        if (flaeche != null) return flaeche;
        return v(stueck) * v(laenge) * v(breite) / 100.0; // ältere Einträge: Stück × Format
    }

    /** Fläche einer Platte in m² (0 wenn Format unbekannt). */
    public double getPlattenFlaecheEinzeln() {
        return isPlatte() && laenge != null && breite != null ? laenge * breite / 100.0 : 0;
    }

    /** Benötigte Plattenanzahl inkl. Verschnitt (aufgerundet), null wenn nicht berechenbar. */
    public Double getPlattenAnzahl() {
        if (!isPlatte()) return null;
        if (!hatFlaechenEingabe()) return stueck;
        double pf = getPlattenFlaecheEinzeln();
        if (pf <= 0) return null;
        return Math.ceil(getFlaeche() * (1 + v(verschnitt) / 100.0) / pf - 1e-9);
    }

    /** Bestellte Plattenfläche in m² (Anzahl × Plattenfläche). */
    public double getPlattenFlaecheGesamt() {
        Double n = getPlattenAnzahl();
        return n == null ? 0 : n * getPlattenFlaecheEinzeln();
    }

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
        if (isPlatte()) {
            Double n = getPlattenAnzahl();
            if (n != null && getPlattenFlaecheEinzeln() > 0) return n * getPlattenFlaecheEinzeln() * v(hoehe) / 100.0;
            return getFlaeche() * (1 + v(verschnitt) / 100.0) * v(hoehe) / 100.0;
        }
        return getLaufmeterGesamt() * v(breite) * v(hoehe) / 10000.0;
    }

    public boolean hasFertigmass() { return fertigB != null || fertigH != null; }

    public Position copy() {
        Position p = new Position();
        p.typ = typ; p.bezeichnung = bezeichnung; p.stueck = stueck; p.breite = breite;
        p.hoehe = hoehe; p.laenge = laenge; p.laufmeter = laufmeter; p.flaeche = flaeche; p.flL = flL; p.flB = flB; p.verschnitt = verschnitt; p.fertigB = fertigB;
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
        put(o, "fl", flaeche);
        put(o, "flL", flL);
        put(o, "flB", flB);
        put(o, "vs", verschnitt);
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
        p.flaeche = get(o, "fl");
        p.flL = get(o, "flL");
        p.flB = get(o, "flB");
        p.verschnitt = get(o, "vs");
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
