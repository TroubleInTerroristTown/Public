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

    /** Alle Aufgaben-Karten (mit Abschnitts-Überschriften) in den Container legen. */
    static void zeigen(Activity act, Holzliste liste, LinearLayout karten, Runnable geaendert) {
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
            karten.addView(karte(act, liste, i, geaendert));
        }
    }

    private static View karte(Activity act, Holzliste liste, int idx, Runnable geaendert) {
        Aufgabe a = liste.aufgaben.get(idx);
        LinearLayout card = new LinearLayout(act);
        card.setOrientation(LinearLayout.HORIZONTAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        android.graphics.drawable.GradientDrawable bg = Ui.rounded(a.erledigt ? Ui.ZEBRA : Ui.WEISS, Ui.LINIE, Ui.dp(act, 10), 1);
        card.setBackground(new android.graphics.drawable.RippleDrawable(
                android.content.res.ColorStateList.valueOf(Ui.HELL), bg, null));
        card.setMinimumHeight(Ui.dp(act, 64));
        card.setPadding(Ui.dp(act, 6), 0, 0, 0);

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
        if (!a.info.isEmpty()) mitte.addView(Ui.text(act, a.info, 13, Ui.GRAU, false));
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
        String[] items = {"✎   Ändern", "＋  Neue Aufgabe darunter", "↑   Nach oben schieben", "↓   Nach unten schieben", "🗑   Löschen"};
        new AlertDialog.Builder(act).setTitle(a.text.length() > 40 ? a.text.substring(0, 38) + "…" : a.text).setItems(items, (d, x) -> {
            switch (x) {
                case 0: bearbeiten(act, liste, i, -1, geaendert); break;
                case 1: bearbeiten(act, liste, -1, i + 1, geaendert); break;
                case 2: if (i > 0) { liste.aufgaben.add(i - 1, liste.aufgaben.remove(i)); geaendert.run(); } break;
                case 3: if (i < liste.aufgaben.size() - 1) { liste.aufgaben.add(i + 1, liste.aufgaben.remove(i)); geaendert.run(); } break;
                case 4: liste.aufgaben.remove(i); geaendert.run(); break;
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
        AlertDialog d = new AlertDialog.Builder(act).setTitle(idx >= 0 ? "✅ Aufgabe ändern" : "✅ Neue Aufgabe").setView(sv)
                .setPositiveButton(idx >= 0 ? "Übernehmen" : "Hinzufügen", (x, y) -> {
                    a.text = eText.getText().toString().trim();
                    if (a.text.isEmpty()) return;
                    a.abschnitt = eAbschn.getText().toString().trim();
                    a.info = eInfo.getText().toString().trim();
                    if (idx >= 0) liste.aufgaben.set(idx, a);
                    else if (einfuegenBei < 0 || einfuegenBei > liste.aufgaben.size()) liste.aufgaben.add(a);
                    else liste.aufgaben.add(einfuegenBei, a);
                    geaendert.run();
                })
                .setNegativeButton("Abbrechen", null).create();
        d.getWindow().setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE);
        d.show();
        eText.requestFocus();
    }

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
