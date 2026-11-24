package de.zimmerei.holzliste;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Eine komplette Holzliste (Kopfdaten + Positionen). */
public class Holzliste {

    public String id;
    public String projekt = "";
    public String kunde = "";
    public String bauteil = "";
    public String datum = "";
    public String bearbeiter = "";
    public String notiz = "";
    public long geaendert;
    public final List<Position> positionen = new ArrayList<>();

    public double summeVolumen(String typ) {
        double s = 0;
        for (Position p : positionen) if (typ == null || typ.equals(p.typ)) s += p.getVolumen();
        return s;
    }

    public double summeLaufmeter(String typ) {
        double s = 0;
        for (Position p : positionen) if (typ == null || typ.equals(p.typ)) s += p.getLaufmeterGesamt();
        return s;
    }

    public double summeStueck() { return summeStueck(Position.HOLZ); }

    public double summeStueck(String typ) {
        double s = 0;
        for (Position p : positionen) {
            if (!(typ == null ? (p.isHolz() || p.isPlatte()) : typ.equals(p.typ))) continue;
            Double n = p.isPlatte() ? p.getPlattenAnzahl() : (p.isHolz() ? p.stueck : null);
            if (n != null) s += n;
        }
        return s;
    }

    public double summeFlaeche() {
        double s = 0;
        for (Position p : positionen) s += p.getFlaeche();
        return s;
    }

    public double summePlattenFlaecheGesamt() {
        double s = 0;
        for (Position p : positionen) s += p.getPlattenFlaecheGesamt();
        return s;
    }

    public boolean hatPlatten() {
        for (Position p : positionen) if (p.isPlatte()) return true;
        return false;
    }

    public int anzahlPositionen() {
        int n = 0;
        for (Position p : positionen) if (!p.isTitel()) n++;
        return n;
    }

    /** Laufende Positionsnummer (Abschnitte zählen nicht mit). 0 für Abschnitte. */
    public int posNummer(int index) {
        if (positionen.get(index).isTitel()) return 0;
        int n = 0;
        for (int i = 0; i <= index; i++) if (!positionen.get(i).isTitel()) n++;
        return n;
    }

    /** Zusammenfassung je Holzart + Querschnitt. */
    public Map<String, double[]> zusammenfassung() {
        Map<String, double[]> m = new LinkedHashMap<>();
        for (Position p : positionen) {
            if (p.isTitel()) continue;
            String key = (p.holzart == null || p.holzart.trim().isEmpty()) ? "(ohne Holzart)" : p.holzart.trim();
            double[] v = m.get(key);
            if (v == null) { v = new double[3]; m.put(key, v); }
            v[0] += p.isHolz() && p.stueck != null ? p.stueck : 0;
            v[1] += p.getLaufmeterGesamt();
            v[2] += p.getVolumen();
        }
        return m;
    }

    public String titel() {
        if (projekt != null && !projekt.trim().isEmpty()) return projekt.trim();
        return "Holzliste ohne Namen";
    }

    public JSONObject toJson() throws JSONException {
        JSONObject o = new JSONObject();
        o.put("version", 1);
        o.put("id", id);
        o.put("projekt", projekt);
        o.put("kunde", kunde);
        o.put("bauteil", bauteil);
        o.put("datum", datum);
        o.put("bearbeiter", bearbeiter);
        o.put("notiz", notiz);
        o.put("geaendert", geaendert);
        JSONArray a = new JSONArray();
        for (Position p : positionen) a.put(p.toJson());
        o.put("positionen", a);
        return o;
    }

    public static Holzliste fromJson(JSONObject o) {
        Holzliste h = new Holzliste();
        h.id = o.optString("id", null);
        h.projekt = o.optString("projekt", "");
        h.kunde = o.optString("kunde", "");
        h.bauteil = o.optString("bauteil", "");
        h.datum = o.optString("datum", "");
        h.bearbeiter = o.optString("bearbeiter", "");
        h.notiz = o.optString("notiz", "");
        h.geaendert = o.optLong("geaendert", 0);
        JSONArray a = o.optJSONArray("positionen");
        if (a != null) {
            for (int i = 0; i < a.length(); i++) {
                JSONObject p = a.optJSONObject(i);
                if (p != null) h.positionen.add(Position.fromJson(p));
            }
        }
        return h;
    }
}
