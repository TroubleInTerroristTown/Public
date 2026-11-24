package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.res.ColorStateList;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.ArrayAdapter;
import android.widget.AutoCompleteTextView;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;

/** Eingabe-Dialog für eine Position (Holz, Laufmeterholz oder Abschnitt). */
public class PositionDialog {

    public interface Callback {
        /** @param weitere true = "Speichern & nächste" gedrückt */
        void onSave(Position p, boolean weitere);
    }

    static final String[] BEZEICHNUNGEN = {
            "Sparren", "Firstpfette", "Mittelpfette", "Fußpfette", "Pfette", "Schwelle", "Rähm", "Stiel",
            "Riegel", "Strebe", "Kopfband", "Zange", "Kehlbalken", "Deckenbalken", "Wechsel", "Gratsparren",
            "Kehlsparren", "Aufschiebling", "Stichbalken", "Bundbalken", "Ortgangbrett", "Traufbohle",
            "Dachlatten", "Konterlatten", "Traglattung", "Rauhspund", "Schalung", "Rhombusleisten",
            "Bretter", "Bohlen", "Stützen", "Unterzug", "Kantholz", "Lattung"
    };

    static final String[] HOLZARTEN = {
            "KVH NSi C24", "KVH Si C24", "BSH GL24h", "BSH GL28h", "Duobalken C24", "Triobalken C24",
            "Fichte/Tanne S10", "Fichte S10 imprägniert", "Fichte", "Lärche", "Douglasie", "Eiche",
            "Kiefer", "Brettsperrholz", "OSB/3"
    };

    private final Activity act;
    private final Position p;
    private final Callback cb;
    private final boolean neu;
    private final Collection<String> bekannteHolzarten;

    private RadioGroup typGroup;
    private AutoCompleteTextView eBez;
    private EditText eStk, eL, eLfm, eB, eH, eFb, eFh, eBem;
    private AutoCompleteTextView eHolzart;
    private LinearLayout rowStkL, rowLfm, groupMasse;
    private TextView tLabelBez, tErgebnis;

    public PositionDialog(Activity act, Position p, boolean neu, Collection<String> bekannteHolzarten, Callback cb) {
        this.act = act;
        this.p = p;
        this.neu = neu;
        this.cb = cb;
        this.bekannteHolzarten = bekannteHolzarten;
    }

    public void show() {
        ScrollView sv = new ScrollView(act);
        LinearLayout root = new LinearLayout(act);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 20);
        root.setPadding(pad, Ui.dp(act, 8), pad, Ui.dp(act, 4));
        sv.addView(root);

        // --- Typ
        typGroup = new RadioGroup(act);
        typGroup.setOrientation(RadioGroup.HORIZONTAL);
        addTyp("Stückholz", Position.HOLZ, 1);
        addTyp("Laufmeter", Position.LFM, 2);
        addTyp("Abschnitt", Position.TITEL, 3);
        root.addView(typGroup);

        // --- Bezeichnung
        tLabelBez = label("Bezeichnung");
        root.addView(tLabelBez);
        eBez = new AutoCompleteTextView(act);
        eBez.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        eBez.setAdapter(new ArrayAdapter<>(act, android.R.layout.simple_dropdown_item_1line, BEZEICHNUNGEN));
        eBez.setThreshold(1);
        eBez.setText(p.bezeichnung);
        eBez.setHint("z. B. Sparren");
        root.addView(eBez, full());

        groupMasse = new LinearLayout(act);
        groupMasse.setOrientation(LinearLayout.VERTICAL);
        root.addView(groupMasse);

        // --- Stück / Länge
        rowStkL = row();
        eStk = num(Fmt.num(p.stueck), "Stück");
        eL = num(Fmt.num(p.laenge), "m");
        rowStkL.addView(field("Stück", eStk));
        rowStkL.addView(field("Länge [m]", eL));
        groupMasse.addView(rowStkL);

        // --- Laufmeter
        rowLfm = row();
        eLfm = num(Fmt.num(p.laufmeter), "m");
        rowLfm.addView(field("Laufmeter gesamt [m]", eLfm));
        groupMasse.addView(rowLfm);

        // --- Rohmaß
        groupMasse.addView(section("Rohmaß (Querschnitt)"));
        LinearLayout rq = row();
        eB = num(Fmt.num(p.breite), "cm");
        eH = num(Fmt.num(p.hoehe), "cm");
        rq.addView(field("Breite [cm]", eB));
        rq.addView(field("Höhe [cm]", eH));
        groupMasse.addView(rq);

        // --- Fertigmaß
        groupMasse.addView(section("Fertigmaß (optional, z. B. gehobelt)"));
        LinearLayout rf = row();
        eFb = num(Fmt.num(p.fertigB), "cm");
        eFh = num(Fmt.num(p.fertigH), "cm");
        rf.addView(field("Breite [cm]", eFb));
        rf.addView(field("Höhe [cm]", eFh));
        groupMasse.addView(rf);

        // --- Holzart / Bemerkung
        groupMasse.addView(label("Holzart / Qualität"));
        eHolzart = new AutoCompleteTextView(act);
        Set<String> ha = new LinkedHashSet<>(bekannteHolzarten);
        for (String s : HOLZARTEN) ha.add(s);
        eHolzart.setAdapter(new ArrayAdapter<>(act, android.R.layout.simple_dropdown_item_1line, ha.toArray(new String[0])));
        eHolzart.setThreshold(0);
        eHolzart.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        eHolzart.setText(p.holzart);
        eHolzart.setHint("z. B. KVH NSi C24");
        eHolzart.setOnFocusChangeListener((v, has) -> { if (has && eHolzart.getText().length() == 0) eHolzart.showDropDown(); });
        eHolzart.setOnClickListener(v -> eHolzart.showDropDown());
        groupMasse.addView(eHolzart, full());

        groupMasse.addView(label("Bemerkung"));
        eBem = new EditText(act);
        eBem.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        eBem.setText(p.bemerkung);
        eBem.setHint("z. B. gehobelt, imprägniert, gefast");
        groupMasse.addView(eBem, full());

        // --- Ergebnis
        tErgebnis = Ui.text(act, "", 15, Ui.BRAUN, true);
        tErgebnis.setGravity(Gravity.CENTER);
        int pp = Ui.dp(act, 10);
        tErgebnis.setPadding(pp, pp, pp, pp);
        tErgebnis.setBackground(Ui.rounded(Ui.BEIGE, 0, Ui.dp(act, 8), 0));
        LinearLayout.LayoutParams lpE = full();
        lpE.topMargin = Ui.dp(act, 12);
        groupMasse.addView(tErgebnis, lpE);

        TextWatcher tw = new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            public void onTextChanged(CharSequence s, int a, int b, int c) {}
            public void afterTextChanged(Editable s) { updateErgebnis(); }
        };
        for (EditText e : new EditText[]{eStk, eL, eLfm, eB, eH}) e.addTextChangedListener(tw);

        typGroup.setOnCheckedChangeListener((g, id) -> updateTyp());
        typGroup.check(p.isTitel() ? 3 : p.isLfm() ? 2 : 1);
        updateTyp();

        AlertDialog.Builder b = new AlertDialog.Builder(act)
                .setTitle(neu ? "Neue Position" : "Position bearbeiten")
                .setView(sv)
                .setPositiveButton("Speichern", null)
                .setNegativeButton("Abbrechen", null);
        if (neu) b.setNeutralButton("+ Nächste", null);
        AlertDialog d = b.create();
        d.setOnShowListener(x -> {
            Button ok = d.getButton(AlertDialog.BUTTON_POSITIVE);
            ok.setOnClickListener(v -> { if (uebernehmen()) { d.dismiss(); cb.onSave(p, false); } });
            Button next = d.getButton(AlertDialog.BUTTON_NEUTRAL);
            if (next != null) next.setOnClickListener(v -> { if (uebernehmen()) { d.dismiss(); cb.onSave(p, true); } });
        });
        if (d.getWindow() != null) d.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
                | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        d.show();
        eBez.requestFocus();
    }

    private String typ() {
        int id = typGroup.getCheckedRadioButtonId();
        return id == 3 ? Position.TITEL : id == 2 ? Position.LFM : Position.HOLZ;
    }

    private void updateTyp() {
        String t = typ();
        boolean titel = Position.TITEL.equals(t);
        groupMasse.setVisibility(titel ? View.GONE : View.VISIBLE);
        rowStkL.setVisibility(Position.HOLZ.equals(t) ? View.VISIBLE : View.GONE);
        rowLfm.setVisibility(Position.LFM.equals(t) ? View.VISIBLE : View.GONE);
        tLabelBez.setText(titel ? "Abschnitt / Überschrift (z. B. Dachstuhl, Decke EG)" : "Bezeichnung");
        updateErgebnis();
    }

    private void updateErgebnis() {
        Position tmp = new Position();
        tmp.typ = typ();
        tmp.stueck = Fmt.parse(eStk.getText().toString());
        tmp.laenge = Fmt.parse(eL.getText().toString());
        tmp.laufmeter = Fmt.parse(eLfm.getText().toString());
        tmp.breite = Fmt.parse(eB.getText().toString());
        tmp.hoehe = Fmt.parse(eH.getText().toString());
        tErgebnis.setText("= " + Fmt.fix(tmp.getLaufmeterGesamt(), 2) + " lfm   ·   " + Fmt.fix(tmp.getVolumen(), 3) + " m³");
    }

    private boolean uebernehmen() {
        String t = typ();
        String bez = eBez.getText().toString().trim();
        if (Position.TITEL.equals(t) && bez.isEmpty()) {
            Toast.makeText(act, "Bitte eine Überschrift eingeben", Toast.LENGTH_SHORT).show();
            return false;
        }
        for (EditText e : new EditText[]{eStk, eL, eLfm, eB, eH, eFb, eFh}) {
            String s = e.getText().toString().trim();
            if (!s.isEmpty() && Fmt.parse(s) == null) {
                e.setError("Ungültige Zahl");
                e.requestFocus();
                return false;
            }
        }
        p.typ = t;
        p.bezeichnung = bez;
        if (Position.TITEL.equals(t)) return true;
        p.stueck = Position.HOLZ.equals(t) ? Fmt.parse(eStk.getText().toString()) : null;
        p.laenge = Position.HOLZ.equals(t) ? Fmt.parse(eL.getText().toString()) : null;
        p.laufmeter = Position.LFM.equals(t) ? Fmt.parse(eLfm.getText().toString()) : null;
        p.breite = Fmt.parse(eB.getText().toString());
        p.hoehe = Fmt.parse(eH.getText().toString());
        p.fertigB = Fmt.parse(eFb.getText().toString());
        p.fertigH = Fmt.parse(eFh.getText().toString());
        p.holzart = eHolzart.getText().toString().trim();
        p.bemerkung = eBem.getText().toString().trim();
        return true;
    }

    // ---------------------------------------------------------------- Layout-Helfer

    private void addTyp(String text, String typ, int id) {
        RadioButton rb = new RadioButton(act);
        rb.setId(id);
        rb.setText(text);
        rb.setTextSize(13);
        rb.setButtonTintList(ColorStateList.valueOf(Ui.BRAUN));
        RadioGroup.LayoutParams lp = new RadioGroup.LayoutParams(0, RadioGroup.LayoutParams.WRAP_CONTENT, 1);
        typGroup.addView(rb, lp);
    }

    private TextView label(String s) {
        TextView t = Ui.text(act, s, 12, Ui.GRAU, false);
        t.setPadding(Ui.dp(act, 4), Ui.dp(act, 10), 0, 0);
        return t;
    }

    private TextView section(String s) {
        TextView t = Ui.text(act, s, 13, Ui.BRAUN, true);
        t.setPadding(Ui.dp(act, 4), Ui.dp(act, 14), 0, 0);
        return t;
    }

    private LinearLayout row() {
        LinearLayout l = new LinearLayout(act);
        l.setOrientation(LinearLayout.HORIZONTAL);
        return l;
    }

    private LinearLayout field(String label, EditText e) {
        LinearLayout l = new LinearLayout(act);
        l.setOrientation(LinearLayout.VERTICAL);
        l.addView(label(label));
        l.addView(e, full());
        l.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        return l;
    }

    private EditText num(String value, String hint) {
        EditText e = new EditText(act);
        Ui.decimalInput(e);
        e.setText(value);
        e.setHint(hint);
        e.setGravity(Gravity.END);
        return e;
    }

    private static LinearLayout.LayoutParams full() {
        return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    }
}
