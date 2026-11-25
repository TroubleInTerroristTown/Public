package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Paint;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.Locale;

/** Reiter „Aufgaben“ im Editor: To-do-Liste zum Abhaken, gruppiert nach Abschnitten der Arbeitsanweisung. */
final class AufgabenAnsicht {

    private AufgabenAnsicht() {}

    /** null = automatisch (Heute, wenn etwas für heute ausgewählt ist). */
    static Boolean modusHeute;

    static boolean heuteModus(Holzliste liste) {
        if (modusHeute != null) return modusHeute;
        for (Aufgabe a : liste.aufgaben) if (a.heute) return true;
        return false;
    }

    static int anzahlHeute(Holzliste liste, boolean nurErledigt) {
        int n = 0;
        for (Aufgabe a : liste.aufgaben) if (a.heute && (!nurErledigt || a.erledigt)) n++;
        return n;
    }

    /** Umschalter „Heute / Alle“ und die passenden Karten in den Container legen. */
    static void zeigen(Activity act, Holzliste liste, LinearLayout karten, Runnable geaendert) {
        if (liste.aufgaben.isEmpty()) return;
        boolean heute = heuteModus(liste);
        LinearLayout umschalter = new LinearLayout(act);
        umschalter.setPadding(0, Ui.dp(act, 4), 0, Ui.dp(act, 4));
        int nH = anzahlHeute(liste, false), eH = anzahlHeute(liste, true);
        TextView tH = WerkzeugAnsicht.reiter(act, "☀️ Heute", nH == 0 ? "nichts ausgewählt" : eH + "/" + nH + " erledigt", heute);
        TextView tA = WerkzeugAnsicht.reiter(act, "📋 Alle Aufgaben", liste.anzahlErledigt() + "/" + liste.aufgaben.size() + " erledigt", !heute);
        tH.setOnClickListener(v -> { modusHeute = true; geaendert.run(); });
        tA.setOnClickListener(v -> { modusHeute = false; geaendert.run(); });
        LinearLayout.LayoutParams lpH = new LinearLayout.LayoutParams(0, Ui.dp(act, 52), 1);
        lpH.setMarginEnd(Ui.dp(act, 6));
        umschalter.addView(tH, lpH);
        umschalter.addView(tA, new LinearLayout.LayoutParams(0, Ui.dp(act, 52), 1));
        karten.addView(umschalter);

        if (heute) {
            if (nH == 0) {
                TextView hinweis = Ui.text(act, "Noch nichts für heute ausgewählt.\n\nTippe unten auf  „☀️ Für heute wählen“ und hake an, "
                        + "was du heute erledigen willst. 🔴 Dringendes steht oben.", 16, Ui.GRAU, false);
                hinweis.setGravity(Gravity.CENTER);
                int p = Ui.dp(act, 24);
                hinweis.setPadding(p, p, p, p);
                karten.addView(hinweis);
                return;
            }
            // dringende zuerst, erledigte nach unten
            for (int e = 0; e <= 1; e++)
                for (int pr = Werkzeug.ROT; pr >= Werkzeug.GRUEN; pr--)
                    for (int i = 0; i < liste.aufgaben.size(); i++) {
                        Aufgabe a = liste.aufgaben.get(i);
                        if (a.heute && a.prio == pr && a.erledigt == (e == 1)) karten.addView(karte(act, liste, i, true, geaendert));
                    }
            return;
        }
        String letzter = null;
        for (int i = 0; i < liste.aufgaben.size(); i++) {
            Aufgabe a = liste.aufgaben.get(i);
            if (!a.abschnitt.equals(letzter) && !a.abschnitt.isEmpty()) {
                int offen = 0, gesamt = 0;
                for (Aufgabe x : liste.aufgaben) if (x.abschnitt.equals(a.abschnitt)) { gesamt++; if (!x.erledigt) offen++; }
                TextView t = Ui.text(act, a.abschnitt.toUpperCase(Locale.GERMANY) + (offen == 0 ? "  ✓" : "  (" + (gesamt - offen) + "/" + gesamt + ")"),
                        15, offen == 0 ? Ui.GRUEN : Ui.PRIMAER, true);
                t.setLetterSpacing(0.04f);
                t.setPadding(Ui.dp(act, 6), Ui.dp(act, 14), 0, Ui.dp(act, 4));
                karten.addView(t);
            }
            letzter = a.abschnitt;
            karten.addView(karte(act, liste, i, false, geaendert));
        }
    }

    /** Morgens aus der großen Liste die Arbeit für heute picken. */
    static void heuteWaehlen(Activity act, Holzliste liste, Runnable geaendert) {
        java.util.List<Integer> idx = new java.util.ArrayList<>();
        for (int pr = Werkzeug.ROT; pr >= Werkzeug.GRUEN; pr--)
            for (int i = 0; i < liste.aufgaben.size(); i++) {
                Aufgabe a = liste.aufgaben.get(i);
                if (!a.erledigt && a.prio == pr) idx.add(i);
            }
        if (idx.isEmpty()) {
            new AlertDialog.Builder(act).setMessage(liste.aufgaben.isEmpty() ? "Es gibt noch keine Aufgaben." : "Alle Aufgaben sind erledigt ✓")
                    .setPositiveButton("OK", null).show();
            return;
        }
        String[] texte = new String[idx.size()];
        boolean[] an = new boolean[idx.size()];
        for (int k = 0; k < idx.size(); k++) {
            Aufgabe a = liste.aufgaben.get(idx.get(k));
            texte[k] = Werkzeug.prioSymbol(a.prio) + "  " + a.text + (a.abschnitt.isEmpty() ? "" : "  · " + a.abschnitt);
            an[k] = a.heute;
        }
        new AlertDialog.Builder(act).setTitle("☀️ Was machst du heute?")
                .setMultiChoiceItems(texte, an, (d, k, wert) -> an[k] = wert)
                .setPositiveButton("Übernehmen", (d, w) -> {
                    for (int k = 0; k < idx.size(); k++) liste.aufgaben.get(idx.get(k)).heute = an[k];
                    modusHeute = true;
                    geaendert.run();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    /** Neuer Tag: erledigte Aufgaben aus der Heute-Liste nehmen (sie bleiben in „Alle“ abgehakt). */
    static void neuerTag(Activity act, Holzliste liste, Runnable geaendert) {
        int n = anzahlHeute(liste, true);
        if (n == 0) { heuteWaehlen(act, liste, geaendert); return; }
        new AlertDialog.Builder(act).setMessage("Neuer Tag: " + n + (n == 1 ? " erledigte Aufgabe" : " erledigte Aufgaben")
                        + " aus „Heute“ wegräumen? Offene bleiben für heute ausgewählt.")
                .setPositiveButton("Wegräumen", (d, w) -> {
                    for (Aufgabe a : liste.aufgaben) if (a.erledigt) a.heute = false;
                    geaendert.run();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    private static View karte(Activity act, Holzliste liste, int idx, boolean heuteAnsicht, Runnable geaendert) {
        Aufgabe a = liste.aufgaben.get(idx);
        LinearLayout card = new LinearLayout(act);
        card.setOrientation(LinearLayout.HORIZONTAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        android.graphics.drawable.GradientDrawable bg = Ui.rounded(a.erledigt ? Ui.ZEBRA : Ui.WEISS, Ui.LINIE, Ui.dp(act, 10), 1);
        card.setBackground(new android.graphics.drawable.RippleDrawable(
                android.content.res.ColorStateList.valueOf(Ui.HELL), bg, null));
        card.setMinimumHeight(Ui.dp(act, 64));

        View streifen = new View(act);
        streifen.setBackground(Ui.rounded(WerkzeugAnsicht.prioFarbe(a.prio), 0, Ui.dp(act, 3), 0));
        LinearLayout.LayoutParams lpS = new LinearLayout.LayoutParams(Ui.dp(act, 6), ViewGroup.LayoutParams.MATCH_PARENT);
        lpS.setMargins(Ui.dp(act, 4), Ui.dp(act, 8), 0, Ui.dp(act, 8));
        card.addView(streifen, lpS);

        CheckBox cb = new CheckBox(act);
        cb.setChecked(a.erledigt);
        cb.setScaleX(1.3f);
        cb.setScaleY(1.3f);
        cb.setOnClickListener(v -> { a.erledigt = cb.isChecked(); geaendert.run(); });
        card.addView(cb, new LinearLayout.LayoutParams(Ui.dp(act, 52), ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout mitte = new LinearLayout(act);
        mitte.setOrientation(LinearLayout.VERTICAL);
        mitte.setPadding(Ui.dp(act, 4), Ui.dp(act, 10), 0, Ui.dp(act, 10));
        TextView t = Ui.text(act, a.text.isEmpty() ? "(ohne Text)" : a.text, 16, a.erledigt ? Ui.GRAU : Ui.TEXT, true);
        if (a.erledigt) t.setPaintFlags(t.getPaintFlags() | Paint.STRIKE_THRU_TEXT_FLAG);
        mitte.addView(t);
        String info = a.info;
        if (heuteAnsicht && !a.abschnitt.isEmpty()) info = info.isEmpty() ? a.abschnitt : a.abschnitt + " · " + info;
        if (!heuteAnsicht && a.heute) info = "☀️ heute" + (info.isEmpty() ? "" : " · " + info);
        if (!info.isEmpty()) mitte.addView(Ui.text(act, info, 13, Ui.GRAU, false));
        card.addView(mitte, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        TextView mehr = Ui.text(act, "⋮", 26, Ui.GRAU, true);
        mehr.setGravity(Gravity.CENTER);
        mehr.setBackground(Ui.touchBg(android.graphics.Color.TRANSPARENT));
        mehr.setOnClickListener(v -> aktionen(act, liste, idx, geaendert));
        card.addView(mehr, new LinearLayout.LayoutParams(Ui.dp(act, 44), Ui.dp(act, 56)));

        card.setOnClickListener(v -> { a.erledigt = !a.erledigt; geaendert.run(); });
        card.setOnLongClickListener(v -> { aktionen(act, liste, idx, geaendert); return true; });
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, Ui.dp(act, 3), 0, Ui.dp(act, 3));
        card.setLayoutParams(lp);
        return card;
    }

    static void aktionen(Activity act, Holzliste liste, int i, Runnable geaendert) {
        Aufgabe a = liste.aufgaben.get(i);
        String[] items = {"✎   Ändern", a.heute ? "☀️  Nicht mehr für heute" : "☀️  Für heute vormerken",
                "🔴  Dringend", "🟡  Normal", "🟢  Hat Zeit",
                "＋  Neue Aufgabe darunter", "↑   Nach oben schieben", "↓   Nach unten schieben", "🗑   Löschen"};
        new AlertDialog.Builder(act).setTitle(a.text.length() > 40 ? a.text.substring(0, 38) + "…" : a.text).setItems(items, (d, x) -> {
            switch (x) {
                case 0: bearbeiten(act, liste, i, -1, geaendert); break;
                case 1: a.heute = !a.heute; geaendert.run(); break;
                case 2: a.prio = Werkzeug.ROT; geaendert.run(); break;
                case 3: a.prio = Werkzeug.GELB; geaendert.run(); break;
                case 4: a.prio = Werkzeug.GRUEN; geaendert.run(); break;
                case 5: bearbeiten(act, liste, -1, i + 1, geaendert); break;
                case 6: if (i > 0) { liste.aufgaben.add(i - 1, liste.aufgaben.remove(i)); geaendert.run(); } break;
                case 7: if (i < liste.aufgaben.size() - 1) { liste.aufgaben.add(i + 1, liste.aufgaben.remove(i)); geaendert.run(); } break;
                case 8: liste.aufgaben.remove(i); geaendert.run(); break;
            }
        }).show();
    }

    /** Aufgabe ändern (idx ≥ 0) oder neu an Position einfuegenBei anlegen (idx < 0; -1 = ans Ende). */
    static void bearbeiten(Activity act, Holzliste liste, int idx, int einfuegenBei, Runnable geaendert) {
        Aufgabe a;
        if (idx >= 0) a = liste.aufgaben.get(idx).copy();
        else {
            a = new Aufgabe();
            int vor = einfuegenBei < 0 ? liste.aufgaben.size() - 1 : einfuegenBei - 1;
            if (vor >= 0 && vor < liste.aufgaben.size()) a.abschnitt = liste.aufgaben.get(vor).abschnitt;
            a.heute = heuteModus(liste);
            if (letzte != null) {
                a.abschnitt = letzte.abschnitt;
                a.prio = letzte.prio;
                a.heute = letzte.heute;
                letzte = null;
            }
        }
        ScrollView sv = new ScrollView(act);
        LinearLayout l = new LinearLayout(act);
        l.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 20);
        l.setPadding(pad, Ui.dp(act, 8), pad, 0);
        sv.addView(l);
        EditText eText = feld(act, l, "Was ist zu tun?", a.text);
        eText.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        EditText eAbschn = feld(act, l, "Abschnitt (z. B. Zimmererarbeiten)", a.abschnitt);
        EditText eInfo = feld(act, l, "Info (z. B. Pos. 2.5, Menge, wer)", a.info);
        TextView lp = Ui.text(act, "Wie dringend?", 12, Ui.GRAU, false);
        lp.setPadding(Ui.dp(act, 4), Ui.dp(act, 10), 0, 0);
        l.addView(lp);
        android.widget.RadioGroup rg = new android.widget.RadioGroup(act);
        rg.setOrientation(LinearLayout.HORIZONTAL);
        for (int p : new int[]{Werkzeug.ROT, Werkzeug.GELB, Werkzeug.GRUEN}) {
            android.widget.RadioButton rb = new android.widget.RadioButton(act);
            rb.setId(View.generateViewId());
            rb.setText(Werkzeug.prioSymbol(p) + " " + Aufgabe.prioName(p));
            rb.setTag(p);
            rg.addView(rb, new android.widget.RadioGroup.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            if (a.prio == p) rb.setChecked(true);
        }
        l.addView(rg);
        CheckBox cHeute = new CheckBox(act);
        cHeute.setText("☀️ Heute erledigen");
        cHeute.setChecked(a.heute);
        l.addView(cHeute);
        AlertDialog d = new AlertDialog.Builder(act).setTitle(idx >= 0 ? "✅ Aufgabe ändern" : "✅ Neue Aufgabe").setView(sv)
                .setPositiveButton(idx >= 0 ? "Übernehmen" : "Hinzufügen", (x, y) -> {
                    a.text = eText.getText().toString().trim();
                    if (a.text.isEmpty()) return;
                    a.abschnitt = eAbschn.getText().toString().trim();
                    a.info = eInfo.getText().toString().trim();
                    View sel = rg.findViewById(rg.getCheckedRadioButtonId());
                    if (sel != null) a.prio = (Integer) sel.getTag();
                    a.heute = cHeute.isChecked();
                    int neuBei = -1;
                    if (idx >= 0) liste.aufgaben.set(idx, a);
                    else if (einfuegenBei < 0 || einfuegenBei > liste.aufgaben.size()) liste.aufgaben.add(a);
                    else { liste.aufgaben.add(einfuegenBei, a); neuBei = einfuegenBei + 1; }
                    geaendert.run();
                    // Neue Aufgabe: gleich das Fenster für die nächste Aufgabe öffnen (beenden mit „Abbrechen“)
                    if (idx < 0) {
                        android.widget.Toast.makeText(act, "✓ Aufgabe hinzugefügt – nächste Aufgabe", android.widget.Toast.LENGTH_SHORT).show();
                        naechste(act, liste, neuBei, a, geaendert);
                    }
                })
                .setNegativeButton("Abbrechen", null).create();
        d.getWindow().setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE);
        d.show();
        eText.requestFocus();
    }

    /** Öffnet die Eingabe für die nächste Aufgabe mit gleichem Abschnitt, gleicher Dringlichkeit und „Heute“. */
    private static void naechste(Activity act, Holzliste liste, int einfuegenBei, Aufgabe vorher, Runnable geaendert) {
        letzte = vorher;
        bearbeiten(act, liste, -1, einfuegenBei, geaendert);
    }

    /** Vorlage für die nächste Aufgabe bei fortlaufender Eingabe (wird nach Gebrauch gelöscht). */
    private static Aufgabe letzte;

    private static EditText feld(Activity act, LinearLayout parent, String label, String wert) {
        TextView t = Ui.text(act, label, 12, Ui.GRAU, false);
        t.setPadding(Ui.dp(act, 4), Ui.dp(act, 10), 0, 0);
        parent.addView(t);
        EditText e = new EditText(act);
        e.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        e.setText(wert);
        parent.addView(e);
        return e;
    }
}
