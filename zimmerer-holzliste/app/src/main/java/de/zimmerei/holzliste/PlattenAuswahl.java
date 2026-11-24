package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.graphics.Typeface;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** Schnellauswahl gängiger Plattenwerkstoffe inkl. eigener, gespeicherter Vorlagen. */
public final class PlattenAuswahl {

    /** Eine Plattenvorlage: Material + Format (Länge m, Breite cm, Dicke mm). */
    public static final class Vorlage {
        final String material, bezeichnung;
        final Double laenge, breite, dicke;
        final boolean eigene;

        Vorlage(String material, String bezeichnung, Double laengeM, Double breiteCm, Double dickeMm, boolean eigene) {
            this.material = material; this.bezeichnung = bezeichnung;
            this.laenge = laengeM; this.breite = breiteCm; this.dicke = dickeMm; this.eigene = eigene;
        }

        String format() {
            StringBuilder sb = new StringBuilder();
            if (laenge != null || breite != null) {
                sb.append(laenge == null ? "–" : Fmt.num(laenge * 100)).append(" × ")
                        .append(breite == null ? "–" : Fmt.num(breite)).append(" cm");
            }
            if (dicke != null) sb.append(sb.length() > 0 ? "  ·  " : "").append(Fmt.num(dicke)).append(" mm");
            return sb.toString();
        }

        JSONObject toJson() throws Exception {
            JSONObject o = new JSONObject();
            o.put("m", material); o.put("bez", bezeichnung);
            if (laenge != null) o.put("l", laenge);
            if (breite != null) o.put("b", breite);
            if (dicke != null) o.put("d", dicke);
            return o;
        }

        static Vorlage fromJson(JSONObject o) {
            return new Vorlage(o.optString("m", ""), o.optString("bez", ""),
                    o.has("l") ? o.optDouble("l") : null, o.has("b") ? o.optDouble("b") : null,
                    o.has("d") ? o.optDouble("d") : null, true);
        }
    }

    public interface Callback { void onAuswahl(Vorlage v); }

    // Gängige Platten (Länge in m, Breite in cm, Dicke in mm)
    private static final Object[][] STANDARD = {
            {"OSB/3 – Typ 3", null},
            {"OSB/3", "OSB-Platten", 2.50, 125.0, 12.0},
            {"OSB/3", "OSB-Platten", 2.50, 125.0, 15.0},
            {"OSB/3", "OSB-Platten", 2.50, 125.0, 18.0},
            {"OSB/3", "OSB-Platten", 2.50, 125.0, 22.0},
            {"OSB/3 N+F", "OSB-Verlegeplatten N+F", 2.50, 67.5, 18.0},
            {"OSB/3 N+F", "OSB-Verlegeplatten N+F", 2.50, 67.5, 22.0},
            {"OSB/3 N+F", "OSB-Verlegeplatten N+F", 2.50, 67.5, 25.0},
            {"Gipsplatten", null},
            {"Gipskarton GKB", "Gipskartonplatten", 2.00, 125.0, 12.5},
            {"Gipskarton GKB", "Gipskartonplatten", 2.50, 125.0, 12.5},
            {"Gipskarton GKF (Feuerschutz)", "Gipskartonplatten GKF", 2.00, 125.0, 12.5},
            {"Gipskarton GKF (Feuerschutz)", "Gipskartonplatten GKF", 2.00, 125.0, 15.0},
            {"Gipskarton GKBI (imprägniert)", "Gipskartonplatten GKBI", 2.00, 125.0, 12.5},
            {"Gipsfaserplatte", "Gipsfaserplatten", 1.50, 100.0, 12.5},
            {"Gipsfaserplatte", "Gipsfaserplatten", 2.54, 124.5, 12.5},
            {"Dreischichtplatten", null},
            {"Dreischichtplatte Fichte", "Dreischichtplatten", 5.00, 205.0, 19.0},
            {"Dreischichtplatte Fichte", "Dreischichtplatten", 5.00, 205.0, 27.0},
            {"Dreischichtplatte Fichte", "Dreischichtplatten", 5.00, 205.0, 42.0},
            {"Dreischichtplatte Fichte", "Dreischichtplatten", 2.50, 125.0, 19.0},
            {"Dreischicht-Schalungsplatte", "Schalungsplatten", 2.00, 50.0, 27.0},
    };

    private static final String PREFS = "einstellungen", KEY = "plattenvorlagen";

    private PlattenAuswahl() {}

    // Einträge der Liste: Überschrift (String), Vorlage oder Aktion (Integer)
    private static final int A_FREI = 1, A_SPEICHERN = 2, A_LOESCHEN = 3;

    /**
     * @param aktuell aktuelle Eingabe im Dialog (für „als Vorlage speichern“), darf null sein
     */
    public static void zeigen(Activity act, Vorlage aktuell, Callback cb) {
        List<Vorlage> eigene = laden(act);
        List<Object> items = new ArrayList<>();
        items.add(A_FREI);
        if (!eigene.isEmpty()) {
            items.add("Eigene Platten");
            items.addAll(eigene);
        }
        for (Object[] s : STANDARD) {
            if (s[1] == null) items.add(s[0]);
            else items.add(new Vorlage((String) s[0], (String) s[1], (Double) s[2], (Double) s[3], (Double) s[4], false));
        }
        items.add("Eigene Platten");
        items.add(A_FREI);
        if (aktuell != null && (aktuell.material.length() > 0 || aktuell.dicke != null || aktuell.laenge != null)) items.add(A_SPEICHERN);
        if (!eigene.isEmpty()) items.add(A_LOESCHEN);

        final AlertDialog[] dlg = new AlertDialog[1];
        BaseAdapter adapter = new BaseAdapter() {
            @Override public int getCount() { return items.size(); }
            @Override public Object getItem(int i) { return items.get(i); }
            @Override public long getItemId(int i) { return i; }
            @Override public boolean isEnabled(int i) { return !(items.get(i) instanceof String); }
            @Override public boolean areAllItemsEnabled() { return false; }

            @Override
            public View getView(int i, View convert, ViewGroup parent) {
                Object o = items.get(i);
                int pad = Ui.dp(act, 20);
                if (o instanceof String) {
                    TextView t = Ui.text(act, ((String) o).toUpperCase(), 12, Ui.PRIMAER, true);
                    t.setPadding(pad, Ui.dp(act, 14), pad, Ui.dp(act, 4));
                    t.setBackgroundColor(Ui.FLAECHE);
                    return t;
                }
                LinearLayout l = new LinearLayout(act);
                l.setOrientation(LinearLayout.VERTICAL);
                l.setPadding(pad, Ui.dp(act, 10), pad, Ui.dp(act, 10));
                if (o instanceof Vorlage) {
                    Vorlage v = (Vorlage) o;
                    TextView a = Ui.text(act, (v.eigene ? "★ " : "") + v.material, 16, Ui.TEXT, true);
                    TextView b = Ui.text(act, v.format(), 14, Ui.GRAU, false);
                    l.addView(a);
                    if (b.getText().length() > 0) l.addView(b);
                } else {
                    int aktion = (Integer) o;
                    String txt = aktion == A_FREI ? "✎  Eigene Platte eintragen (Felder frei ausfüllen)"
                            : aktion == A_SPEICHERN ? "＋  Aktuelle Eingabe als eigene Platte speichern"
                            : "🗑  Eigene Platten löschen …";
                    TextView a = Ui.text(act, txt, 15, aktion == A_LOESCHEN ? Ui.GRAU : Ui.PRIMAER, true);
                    l.addView(a);
                }
                return l;
            }
        };

        dlg[0] = new AlertDialog.Builder(act)
                .setTitle("Platte auswählen")
                .setAdapter(adapter, (d, which) -> {
                    Object o = items.get(which);
                    if (o instanceof Vorlage) { cb.onAuswahl((Vorlage) o); return; }
                    if (!(o instanceof Integer)) return;
                    int aktion = (Integer) o;
                    if (aktion == A_SPEICHERN && aktuell != null) {
                        eigene.add(0, new Vorlage(aktuell.material, aktuell.bezeichnung, aktuell.laenge, aktuell.breite, aktuell.dicke, true));
                        speichern(act, eigene);
                        Toast.makeText(act, "Eigene Platte gespeichert – steht jetzt oben in der Auswahl", Toast.LENGTH_LONG).show();
                    } else if (aktion == A_LOESCHEN) {
                        loeschenDialog(act, eigene);
                    }
                    // A_FREI: nichts vorbelegen, Felder bleiben frei
                })
                .setNegativeButton("Abbrechen", null)
                .create();
        dlg[0].show();
    }

    private static void loeschenDialog(Activity act, List<Vorlage> eigene) {
        String[] namen = new String[eigene.size()];
        boolean[] check = new boolean[eigene.size()];
        for (int i = 0; i < namen.length; i++) namen[i] = eigene.get(i).material + "  (" + eigene.get(i).format() + ")";
        new AlertDialog.Builder(act).setTitle("Eigene Platten löschen")
                .setMultiChoiceItems(namen, check, (d, w, c) -> check[w] = c)
                .setPositiveButton("Löschen", (d, w) -> {
                    List<Vorlage> rest = new ArrayList<>();
                    for (int i = 0; i < eigene.size(); i++) if (!check[i]) rest.add(eigene.get(i));
                    speichern(act, rest);
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    static List<Vorlage> laden(Activity act) {
        List<Vorlage> out = new ArrayList<>();
        try {
            JSONArray a = new JSONArray(act.getSharedPreferences(PREFS, Activity.MODE_PRIVATE).getString(KEY, "[]"));
            for (int i = 0; i < a.length(); i++) out.add(Vorlage.fromJson(a.getJSONObject(i)));
        } catch (Exception ignored) {
        }
        return out;
    }

    private static void speichern(Activity act, List<Vorlage> l) {
        try {
            JSONArray a = new JSONArray();
            for (Vorlage v : l) a.put(v.toJson());
            SharedPreferences.Editor e = act.getSharedPreferences(PREFS, Activity.MODE_PRIVATE).edit();
            e.putString(KEY, a.toString()).apply();
        } catch (Exception ignored) {
        }
    }

    public static Vorlage neu(String material, String bezeichnung, Double laengeM, Double breiteCm, Double dickeMm) {
        return new Vorlage(material == null ? "" : material, bezeichnung == null ? "" : bezeichnung, laengeM, breiteCm, dickeMm, true);
    }
}
