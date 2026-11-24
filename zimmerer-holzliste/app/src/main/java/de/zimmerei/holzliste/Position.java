package de.zimmerei.holzliste;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Eine Zeile der Materialliste.
 *
 * Typen:
 *  - HOLZ     : Balken/Kantholz mit Stückzahl, Querschnitt (B/H in cm) und Länge (m)
 *  - LFM      : Latten, Bretter, Schalung … – Querschnitt + Gesamt-Laufmeter
 *  - PLATTE   : Plattenwerkstoff (OSB, Gips, Dreischicht …). Eingabe der zu belegenden Fläche
 *               (Länge × Breite in m oder direkt m²) + Verschnitt %; Plattenformat in laenge (m),
 *               breite (cm), hoehe (cm = Dicke). Die Plattenanzahl wird aufgerundet berechnet.
 *  - MATERIAL : sonstiges Material (Schrauben, Dämmung, Folie, Mörtel …): Menge + Einheit,
 *               optional Reserve/Verschnitt % und Packungsinhalt (→ Anzahl Packungen)
 *  - TITEL    : Abschnitts-Überschrift (z. B. "Dachstuhl", "Dämmung")
 *
 * Für alle Typen optional: Preis je Einheit (z. B. aus DATANORM) → Betrag.
 */
public class Position {

    public static final String HOLZ = "holz";
    public static final String LFM = "lfm";
    public static final String PLATTE = "platte";
    public static final String MATERIAL = "material";
    public static final String TITEL = "titel";

    public String typ = HOLZ;
    public String bezeichnung = "";
    public Double stueck;
    public Double breite;     // cm (Rohmaß; bei Platten: Plattenbreite)
    public Double hoehe;      // cm (Rohmaß; bei Platten: Dicke)
    public Double laenge;     // m  (HOLZ und PLATTE)
    public Double flaeche;    // m² (nur PLATTE: zu belegende Fläche direkt)
    public Double flL, flB;   // m  (nur PLATTE: zu belegende Fläche Länge × Breite)
    public Double verschnitt; // %  (PLATTE und MATERIAL)
    public Double laufmeter;  // m  (nur LFM, Eingabe)
    public Double fertigB;    // cm (Fertigmaß)
    public Double fertigH;    // cm (Fertigmaß)
    public String holzart = "";   // Material / Qualität
    public String bemerkung = "";

    // Material
    public Double menge;          // Bedarf in einheit
    public String einheit = "";   // Stk, kg, m², Sack …
    public Double packInhalt;     // Inhalt je Packung in einheit (optional)
    public String packName = "";  // Paket, Sack, Rolle …

    // Preis (alle Typen)
    public Double preis;              // € je preisEinheit
    public String preisEinheit = "";  // leer = Standard je Typ
    public String artikelNr = "";

    public boolean isTitel() { return TITEL.equals(typ); }
    public boolean isLfm() { return LFM.equals(typ); }
    public boolean isHolz() { return HOLZ.equals(typ); }
    public boolean isPlatte() { return PLATTE.equals(typ); }
    public boolean isMaterial() { return MATERIAL.equals(typ); }

    /** Name der Positionsart für die Anzeige. */
    public static String typName(String typ) {
        switch (typ) {
            case LFM: return "Latten & Bretter";
            case PLATTE: return "Platten";
            case MATERIAL: return "Material";
            case TITEL: return "Überschrift";
            default: return "Balken & Kanthölzer";
        }
    }

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

    // ------------------------------------------------------------------ Material

    /** Material: Bedarf inkl. Reserve in einheit (Stk, Sack … aufgerundet). */
    public Double getBedarf() {
        if (!isMaterial() || menge == null) return null;
        double b = Math.round(menge * (1 + v(verschnitt) / 100.0) * 1e6) / 1e6;
        if (Einheit.ganzzahlig(einheit) && packInhalt == null) b = Math.ceil(b - 1e-9);
        return b;
    }

    public boolean hatPackung() {
        return isMaterial() && packInhalt != null && packInhalt > 0;
    }

    /** Material mit Packungsinhalt: Anzahl Packungen (aufgerundet). */
    public Double getPackungen() {
        Double b = getBedarf();
        if (b == null || !hatPackung()) return null;
        return Math.ceil(b / packInhalt - 1e-9);
    }

    public String packNameOderStandard() {
        return packName == null || packName.trim().isEmpty() ? "Packung" : packName.trim();
    }

    /** Was bestellt wird, z. B. "3 Paket", "12 Sack", "620 m", "24 Stk" (ohne Abschnitte). */
    public String bestellText() {
        if (isMaterial()) {
            Double pk = getPackungen();
            if (pk != null) return Fmt.num(pk) + " " + packNameOderStandard();
            Double b = getBedarf();
            return b == null ? "" : Fmt.mengeText(b) + " " + Einheit.norm(einheit);
        }
        if (isPlatte()) {
            Double n = getPlattenAnzahl();
            return n == null ? "" : Fmt.num(n) + (n == 1 ? " Platte" : " Platten");
        }
        if (isLfm()) return laufmeter == null ? "" : Fmt.mengeText(laufmeter) + " m";
        if (isHolz()) return stueck == null ? "" : Fmt.num(stueck) + " Stk";
        return "";
    }

    // ------------------------------------------------------------------ Preis

    /** Einheit, auf die sich der Preis bezieht (Standard je Typ, wenn nichts angegeben). */
    public String getPreisEinheit() {
        if (preisEinheit != null && !preisEinheit.trim().isEmpty()) return Einheit.norm(preisEinheit);
        switch (typ) {
            case PLATTE: return "m²";
            case MATERIAL: return hatPackung() ? packNameOderStandard() : Einheit.norm(einheit);
            case HOLZ: case LFM: return "m";
            default: return "";
        }
    }

    /** Bestellmenge umgerechnet in die gegebene Einheit, null wenn nicht umrechenbar. */
    public Double getMengeIn(String einh) {
        String u = Einheit.norm(einh);
        switch (typ) {
            case MATERIAL: {
                Double pk = getPackungen();
                if (pk != null && u.equalsIgnoreCase(packNameOderStandard())) return pk;
                if (u.equalsIgnoreCase(Einheit.norm(einheit)) || u.isEmpty())
                    return pk != null ? pk * packInhalt : getBedarf();
                if (pk != null && "Stk".equals(u)) return pk;
                return null;
            }
            case PLATTE:
                if ("Stk".equals(u)) return getPlattenAnzahl();
                if ("m²".equals(u)) return getPlattenAnzahl() != null && getPlattenFlaecheEinzeln() > 0
                        ? getPlattenFlaecheGesamt() : getFlaeche() * (1 + v(verschnitt) / 100.0);
                if ("m³".equals(u)) return getVolumen();
                return null;
            case HOLZ: case LFM:
                if ("m".equals(u)) return getLaufmeterGesamt();
                if ("m³".equals(u)) return getVolumen();
                if ("Stk".equals(u)) return isHolz() ? stueck : null;
                return null;
            default:
                return null;
        }
    }

    /** Betrag in € (Preis × Menge), null wenn kein Preis oder Menge nicht umrechenbar. */
    public Double getBetrag() {
        if (preis == null || isTitel()) return null;
        Double m = getMengeIn(getPreisEinheit());
        return m == null ? null : m * preis;
    }

    private static double v(Double d) { return d == null ? 0 : d; }

    /** Gesamt-Laufmeter der Zeile in m. */
    public double getLaufmeterGesamt() {
        if (isHolz()) return v(stueck) * v(laenge);
        if (isLfm()) return v(laufmeter);
        return 0;
    }

    /** Volumen (Rohmaß) in m³ – Material in m³ wird mitgezählt. */
    public double getVolumen() {
        if (isTitel()) return 0;
        if (isMaterial()) {
            if (!"m³".equals(Einheit.norm(einheit))) return 0;
            Double m = getMengeIn("m³");
            return m == null ? 0 : m;
        }
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
        p.menge = menge; p.einheit = einheit; p.packInhalt = packInhalt; p.packName = packName;
        p.preis = preis; p.preisEinheit = preisEinheit; p.artikelNr = artikelNr;
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
        put(o, "menge", menge);
        if (!leer(einheit)) o.put("einh", einheit);
        put(o, "pack", packInhalt);
        if (!leer(packName)) o.put("packName", packName);
        put(o, "preis", preis);
        if (!leer(preisEinheit)) o.put("preisEinh", preisEinheit);
        if (!leer(artikelNr)) o.put("artNr", artikelNr);
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
        p.menge = get(o, "menge");
        p.einheit = o.optString("einh", "");
        p.packInhalt = get(o, "pack");
        p.packName = o.optString("packName", "");
        p.preis = get(o, "preis");
        p.preisEinheit = o.optString("preisEinh", "");
        p.artikelNr = o.optString("artNr", "");
        return p;
    }

    private static boolean leer(String s) { return s == null || s.isEmpty(); }

    private static void put(JSONObject o, String k, Double d) throws JSONException {
        if (d != null) o.put(k, d.doubleValue());
    }

    private static Double get(JSONObject o, String k) {
        if (!o.has(k) || o.isNull(k)) return null;
        double d = o.optDouble(k, Double.NaN);
        return Double.isNaN(d) ? null : d;
    }
}
