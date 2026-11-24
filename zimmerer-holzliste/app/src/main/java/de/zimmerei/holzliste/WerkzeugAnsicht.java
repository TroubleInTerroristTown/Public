package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.AutoCompleteTextView;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/** Reiter „Werkzeug“ im Editor: Karten zum Abhaken, Bearbeiten und automatische Vorschläge. */
final class WerkzeugAnsicht {

    private WerkzeugAnsicht() {}

    /** Karte: großes Häkchen (eingepackt), Name, Anzahl/Bemerkung, ⋮ für Aktionen. Antippen = abhaken. */
    static View karte(Activity act, Holzliste liste, int idx, Runnable geaendert) {
        Werkzeug w = liste.werkzeug.get(idx);
        LinearLayout card = new LinearLayout(act);
        card.setOrientation(LinearLayout.HORIZONTAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        android.graphics.drawable.GradientDrawable bg = Ui.rounded(w.eingepackt ? Ui.ZEBRA : Ui.WEISS, Ui.LINIE, Ui.dp(act, 10), 1);
        card.setBackground(new android.graphics.drawable.RippleDrawable(
                android.content.res.ColorStateList.valueOf(Ui.HELL), bg, null));
        card.setMinimumHeight(Ui.dp(act, 64));
        card.setPadding(Ui.dp(act, 6), 0, 0, 0);

        CheckBox cb = new CheckBox(act);
        cb.setChecked(w.eingepackt);
        cb.setScaleX(1.3f);
        cb.setScaleY(1.3f);
        cb.setOnClickListener(v -> { w.eingepackt = cb.isChecked(); geaendert.run(); });
        card.addView(cb, new LinearLayout.LayoutParams(Ui.dp(act, 52), ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout mitte = new LinearLayout(act);
        mitte.setOrientation(LinearLayout.VERTICAL);
        mitte.setPadding(Ui.dp(act, 4), Ui.dp(act, 10), 0, Ui.dp(act, 10));
        String titel = (w.anzahl != null && w.anzahl > 1 ? w.anzahl + " × " : "") + (w.name.isEmpty() ? "(ohne Namen)" : w.name);
        TextView t = Ui.text(act, titel, 17, w.eingepackt ? Ui.GRAU : Ui.TEXT, true);
        if (w.eingepackt) t.setPaintFlags(t.getPaintFlags() | Paint.STRIKE_THRU_TEXT_FLAG);
        mitte.addView(t);
        if (!w.bemerkung.isEmpty()) mitte.addView(Ui.text(act, w.bemerkung, 13, Ui.GRAU, false));
        card.addView(mitte, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        TextView mehr = Ui.text(act, "⋮", 26, Ui.GRAU, true);
        mehr.setGravity(Gravity.CENTER);
        mehr.setBackground(Ui.touchBg(android.graphics.Color.TRANSPARENT));
        mehr.setOnClickListener(v -> aktionen(act, liste, idx, geaendert));
        card.addView(mehr, new LinearLayout.LayoutParams(Ui.dp(act, 44), Ui.dp(act, 56)));

        card.setOnClickListener(v -> { w.eingepackt = !w.eingepackt; geaendert.run(); });
        card.setOnLongClickListener(v -> { aktionen(act, liste, idx, geaendert); return true; });
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, Ui.dp(act, 3), 0, Ui.dp(act, 3));
        card.setLayoutParams(lp);
        return card;
    }

    static void aktionen(Activity act, Holzliste liste, int i, Runnable geaendert) {
        Werkzeug w = liste.werkzeug.get(i);
        String[] items = {"✎   Ändern", "↑   Nach oben schieben", "↓   Nach unten schieben", "🗑   Löschen"};
        new AlertDialog.Builder(act).setTitle(w.name.isEmpty() ? "Werkzeug" : w.name).setItems(items, (d, x) -> {
            switch (x) {
                case 0: bearbeiten(act, liste, i, geaendert); break;
                case 1: if (i > 0) { liste.werkzeug.add(i - 1, liste.werkzeug.remove(i)); geaendert.run(); } break;
                case 2: if (i < liste.werkzeug.size() - 1) { liste.werkzeug.add(i + 1, liste.werkzeug.remove(i)); geaendert.run(); } break;
                case 3: liste.werkzeug.remove(i); geaendert.run(); break;
            }
        }).show();
    }

    /** Neues Werkzeug (idx < 0) oder vorhandenes ändern. */
    static void bearbeiten(Activity act, Holzliste liste, int idx, Runnable geaendert) {
        Werkzeug w = idx < 0 ? new Werkzeug() : liste.werkzeug.get(idx).copy();
        ScrollView sv = new ScrollView(act);
        LinearLayout l = new LinearLayout(act);
        l.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 20);
        l.setPadding(pad, Ui.dp(act, 8), pad, 0);
        sv.addView(l);

        l.addView(label(act, "Werkzeug / Gerät"));
        AutoCompleteTextView eName = new AutoCompleteTextView(act);
        eName.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        eName.setThreshold(1);
        eName.setAdapter(new ArrayAdapter<>(act, android.R.layout.simple_dropdown_item_1line, Werkzeug.alleNamen()));
        eName.setText(w.name);
        l.addView(eName);
        l.addView(label(act, "Anzahl (leer = 1)"));
        EditText eAnz = new EditText(act);
        eAnz.setInputType(InputType.TYPE_CLASS_NUMBER);
        eAnz.setText(w.anzahl == null ? "" : String.valueOf(w.anzahl));
        l.addView(eAnz);
        l.addView(label(act, "Bemerkung (z. B. Akku laden, von Kollege holen)"));
        EditText eBem = new EditText(act);
        eBem.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        eBem.setText(w.bemerkung);
        l.addView(eBem);

        AlertDialog.Builder b = new AlertDialog.Builder(act).setTitle(idx < 0 ? "🔧 Werkzeug hinzufügen" : "🔧 Werkzeug ändern").setView(sv)
                .setPositiveButton(idx < 0 ? "Hinzufügen" : "Übernehmen", (d, x) -> {
                    w.name = eName.getText().toString().trim();
                    if (w.name.isEmpty()) return;
                    try {
                        String a = eAnz.getText().toString().trim();
                        w.anzahl = a.isEmpty() ? null : Integer.valueOf(a);
                    } catch (NumberFormatException e) {
                        w.anzahl = null;
                    }
                    w.bemerkung = eBem.getText().toString().trim();
                    if (idx < 0) liste.werkzeug.add(w); else liste.werkzeug.set(idx, w);
                    geaendert.run();
                })
                .setNegativeButton("Abbrechen", null);
        if (idx < 0) b.setNeutralButton("Weiteres", (d, x) -> {
            String n = eName.getText().toString().trim();
            if (!n.isEmpty()) {
                w.name = n;
                w.bemerkung = eBem.getText().toString().trim();
                try { w.anzahl = eAnz.getText().toString().trim().isEmpty() ? null : Integer.valueOf(eAnz.getText().toString().trim()); }
                catch (NumberFormatException e) { w.anzahl = null; }
                liste.werkzeug.add(w);
                geaendert.run();
            }
            bearbeiten(act, liste, -1, geaendert);
        });
        AlertDialog d = b.create();
        d.getWindow().setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE);
        d.show();
        eName.requestFocus();
    }

    /** Vorschläge aus Material und Arbeitsschritten mit Häkchen anzeigen. */
    static void vorschlaege(Activity act, Holzliste liste, List<String> zusatz, Runnable geaendert) {
        List<Werkzeug.Vorschlag> v = Werkzeug.vorschlagen(liste, zusatz);
        if (v.isEmpty()) {
            new AlertDialog.Builder(act).setTitle("💡 Werkzeug-Vorschläge")
                    .setMessage("Keine weiteren Vorschläge – alles Passende steht schon auf der Liste.\n\n"
                            + "Die Vorschläge kommen aus dem Material (z. B. Dämmung → Dämmstoffmesser) und den Arbeitsschritten in der Notiz.")
                    .setPositiveButton("OK", null).show();
            return;
        }
        ScrollView sv = new ScrollView(act);
        LinearLayout box = new LinearLayout(act);
        box.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 18);
        box.setPadding(pad, Ui.dp(act, 6), pad, Ui.dp(act, 6));
        sv.addView(box);
        TextView info = Ui.text(act, "Abgeleitet aus Material und Arbeitsschritten. Häkchen weg = nicht übernehmen.", 14, Ui.GRAU, false);
        info.setPadding(0, 0, 0, Ui.dp(act, 6));
        box.addView(info);
        List<CheckBox> boxen = new ArrayList<>();
        for (Werkzeug.Vorschlag x : v) {
            CheckBox c = AwImport.checkbox(act, "🔧  " + x.name, x.grund, true, false);
            box.addView(c);
            boxen.add(c);
        }
        new AlertDialog.Builder(act).setTitle("💡 Werkzeug-Vorschläge (" + v.size() + ")").setView(sv)
                .setPositiveButton("Übernehmen", (d, w) -> {
                    int n = 0;
                    for (int i = 0; i < v.size(); i++) {
                        if (!boxen.get(i).isChecked()) continue;
                        liste.werkzeug.add(new Werkzeug(v.get(i).name, ""));
                        n++;
                    }
                    geaendert.run();
                    Toast.makeText(act, n + " Werkzeuge übernommen", Toast.LENGTH_SHORT).show();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    private static TextView label(Activity act, String s) {
        TextView t = Ui.text(act, s, 12, Ui.GRAU, false);
        t.setPadding(Ui.dp(act, 4), Ui.dp(act, 10), 0, 0);
        return t;
    }

    /** Reiter-Knopf: Name (fett) und darunter klein der Stand, z. B. „3/12 dabei“. */
    static TextView reiter(Activity act, String name, String stand, boolean aktiv) {
        android.text.SpannableStringBuilder sb = new android.text.SpannableStringBuilder(name + "\n" + stand);
        sb.setSpan(new android.text.style.StyleSpan(Typeface.BOLD), 0, name.length(), 0);
        sb.setSpan(new android.text.style.RelativeSizeSpan(0.8f), name.length() + 1, sb.length(), 0);
        TextView t = Ui.text(act, "", 15, aktiv ? Ui.WEISS : Ui.PRIMAER, false);
        t.setText(sb);
        t.setGravity(Gravity.CENTER);
        t.setMaxLines(2);
        t.setBackground(Ui.rounded(aktiv ? Ui.PRIMAER : Ui.WEISS, Ui.PRIMAER, Ui.dp(act, 10), Ui.dp(act, 1.5f)));
        return t;
    }
}
