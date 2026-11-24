package de.zimmerei.holzliste;

import org.json.JSONException;
import org.json.JSONObject;

/** Ein Punkt der To-do-Liste (Reiter „Aufgaben“), z. B. aus einer Position der Arbeitsanweisung. */
public class Aufgabe {

    public String text = "";
    public String abschnitt = "";   // Überschrift, unter der die Aufgabe steht (z. B. „Zimmererarbeiten“)
    public String info = "";        // z. B. „Pos. 2.5 · 20 m“
    public boolean erledigt;

    public Aufgabe() {}

    public Aufgabe(String abschnitt, String text, String info) {
        this.abschnitt = abschnitt == null ? "" : abschnitt;
        this.text = text == null ? "" : text;
        this.info = info == null ? "" : info;
    }

    public Aufgabe copy() {
        Aufgabe a = new Aufgabe(abschnitt, text, info);
        a.erledigt = erledigt;
        return a;
    }

    public JSONObject toJson() throws JSONException {
        JSONObject o = new JSONObject();
        o.put("text", text);
        o.put("abschnitt", abschnitt);
        o.put("info", info);
        o.put("erledigt", erledigt);
        return o;
    }

    public static Aufgabe fromJson(JSONObject o) {
        Aufgabe a = new Aufgabe(o.optString("abschnitt", ""), o.optString("text", ""), o.optString("info", ""));
        a.erledigt = o.optBoolean("erledigt", false);
        return a;
    }
}
