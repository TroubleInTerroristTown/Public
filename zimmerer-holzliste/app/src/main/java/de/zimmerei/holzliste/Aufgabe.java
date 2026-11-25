package de.zimmerei.holzliste;

import org.json.JSONException;
import org.json.JSONObject;

/** Ein Punkt der To-do-Liste (Reiter „Aufgaben“), z. B. aus einer Position der Arbeitsanweisung. */
public class Aufgabe {

    public String text = "";
    public String abschnitt = "";   // Überschrift, unter der die Aufgabe steht (z. B. „Zimmererarbeiten“)
    public String info = "";        // z. B. „Pos. 2.5 · 20 m“
    public boolean erledigt;
    /** Dringlichkeit: Werkzeug.ROT = dringend, GELB = normal, GRUEN = hat Zeit. */
    public int prio = Werkzeug.GELB;
    /** Für heute ausgewählt (Tages-To-do). */
    public boolean heute;

    public static String prioName(int p) { return p == Werkzeug.ROT ? "Dringend" : p == Werkzeug.GRUEN ? "Hat Zeit" : "Normal"; }

    public Aufgabe() {}

    public Aufgabe(String abschnitt, String text, String info) {
        this.abschnitt = abschnitt == null ? "" : abschnitt;
        this.text = text == null ? "" : text;
        this.info = info == null ? "" : info;
    }

    public Aufgabe copy() {
        Aufgabe a = new Aufgabe(abschnitt, text, info);
        a.erledigt = erledigt;
        a.prio = prio;
        a.heute = heute;
        return a;
    }

    public JSONObject toJson() throws JSONException {
        JSONObject o = new JSONObject();
        o.put("text", text);
        o.put("abschnitt", abschnitt);
        o.put("info", info);
        o.put("erledigt", erledigt);
        o.put("prio", prio);
        o.put("heute", heute);
        return o;
    }

    public static Aufgabe fromJson(JSONObject o) {
        Aufgabe a = new Aufgabe(o.optString("abschnitt", ""), o.optString("text", ""), o.optString("info", ""));
        a.erledigt = o.optBoolean("erledigt", false);
        a.prio = o.optInt("prio", Werkzeug.GELB);
        a.heute = o.optBoolean("heute", false);
        return a;
    }
}
