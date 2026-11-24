package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

/**
 * Baustellen-Übersicht: die Mitte der App. Oben die Kopfdaten, darunter große Kacheln –
 * jeder Ast (Material, Werkzeug, Aufgaben, Arbeitsanweisung …) hat seine eigene Seite.
 */
public class BaustelleActivity extends Activity {

    public static final String EXTRA_ID = EditorActivity.EXTRA_ID;
    public static final String EXTRA_NEU = EditorActivity.EXTRA_NEU;
    public static final String EXTRA_AW = EditorActivity.EXTRA_AW;

    private Holzliste liste;
    private LinearLayout inhalt;
    /** Nur nach der Rückkehr aus einem Ast neu laden (nicht nach der PDF-Auswahl – deren Dialog hält die Liste). */
    private boolean astOffen;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        liste = Storage.laden(this, getIntent().getStringExtra(EXTRA_ID));
        if (liste == null) {
            Toast.makeText(this, "Baustelle nicht gefunden", Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        if (getActionBar() != null) getActionBar().setDisplayHomeAsUpEnabled(true);
        ScrollView sv = new ScrollView(this);
        sv.setFillViewport(true);
        sv.setBackgroundColor(Ui.HINTERGRUND);
        inhalt = new LinearLayout(this);
        inhalt.setOrientation(LinearLayout.VERTICAL);
        int p = Ui.dp(this, 12);
        inhalt.setPadding(p, p, p, p);
        sv.addView(inhalt);
        setContentView(sv);
        render();
        if (state == null && getIntent().getBooleanExtra(EXTRA_AW, false)) AwImport.starten(this, 0);
        else if (state == null && getIntent().getBooleanExtra(EXTRA_NEU, false)) EditorActivity.kopfdatenDialog(this, liste, this::speichern);
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Nach der Rückkehr aus einem Ast neu laden – dort wurde ggf. geändert.
        if (!astOffen) return;
        astOffen = false;
        Holzliste neu = Storage.laden(this, liste.id);
        if (neu != null) liste = neu;
        render();
    }

    private void speichern() {
        try {
            Storage.speichern(this, liste);
        } catch (RuntimeException e) {
            Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG).show();
        }
        render();
    }

    // ================================================================ Darstellung

    void render() {
        setTitle("Baustelle");
        inhalt.removeAllViews();
        inhalt.addView(kopf());

        // Arbeitsanweisung ganz oben – sie füllt alle anderen Äste.
        boolean hatAw = liste.awDatei != null && !liste.awDatei.isEmpty();
        View aw = kachel("📄", "Arbeitsanweisung",
                hatAw ? liste.awDatei + (liste.awDatum.isEmpty() ? "" : "\neingelesen am " + liste.awDatum)
                        : "PDF einlesen – füllt Material, Werkzeug und Aufgaben",
                hatAw ? Ui.PRIMAER : Ui.AKZENT, !hatAw, v -> arbeitsanweisung());
        inhalt.addView(aw, zeile(Ui.dp(this, 10)));

        int nPos = liste.anzahlPositionen();
        int nW = liste.werkzeug.size(), eW = liste.anzahlEingepackt();
        int nA = liste.aufgaben.size(), eA = liste.anzahlErledigt();
        LinearLayout r1 = reihe();
        r1.addView(kachel("📦", "Material",
                nPos == 0 ? "noch leer" : nPos + (nPos == 1 ? " Position" : " Positionen"),
                Ui.HOLZ, false, v -> ast(EditorActivity.R_MATERIAL)), spalte(true));
        r1.addView(kachel("🔧", "Werkzeug",
                nW == 0 ? "noch leer" : eW == nW ? "✓ alles dabei (" + nW + ")" : eW + " von " + nW + " dabei",
                Ui.BLAU, false, v -> ast(EditorActivity.R_WERKZEUG)), spalte(false));
        inhalt.addView(r1, zeile(Ui.dp(this, 10)));

        LinearLayout r2 = reihe();
        r2.addView(kachel("✅", "Aufgaben",
                nA == 0 ? "noch leer" : eA == nA ? "✓ alles erledigt (" + nA + ")" : eA + " von " + nA + " erledigt",
                Ui.GRUEN, false, v -> ast(EditorActivity.R_AUFGABEN)), spalte(true));
        r2.addView(kachel("📝", "Notiz",
                liste.notiz == null || liste.notiz.trim().isEmpty() ? "leer" : kurz(liste.notiz),
                Ui.LILA, false, v -> notiz()), spalte(false));
        inhalt.addView(r2, zeile(Ui.dp(this, 18)));

        // Was noch kommt – ehrlich als „später“ gekennzeichnet.
        TextView spaeter = Ui.text(this, "KOMMT SPÄTER", 13, Ui.GRAU, true);
        spaeter.setLetterSpacing(0.05f);
        spaeter.setPadding(Ui.dp(this, 4), 0, 0, Ui.dp(this, 6));
        inhalt.addView(spaeter);
        LinearLayout r3 = reihe();
        String[][] bald = {{"📖", "Lexikon"}, {"📷", "Fotos"}, {"⏱", "Stunden"}};
        for (int i = 0; i < bald.length; i++) {
            TextView t = Ui.text(this, bald[i][0] + "\n" + bald[i][1], 14, Ui.GRAU, false);
            t.setGravity(Gravity.CENTER);
            t.setPadding(0, Ui.dp(this, 10), 0, Ui.dp(this, 10));
            t.setAlpha(0.6f);
            t.setBackground(Ui.rounded(Ui.ZEBRA, Ui.LINIE, Ui.dp(this, 12), Ui.dp(this, 1)));
            String name = bald[i][1];
            t.setOnClickListener(v -> Toast.makeText(this, name + " kommt in einer späteren Version", Toast.LENGTH_SHORT).show());
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
            if (i < bald.length - 1) lp.setMarginEnd(Ui.dp(this, 8));
            r3.addView(t, lp);
        }
        inhalt.addView(r3, zeile(0));
    }

    private View kopf() {
        LinearLayout k = new LinearLayout(this);
        k.setOrientation(LinearLayout.VERTICAL);
        int p = Ui.dp(this, 16);
        k.setPadding(p, Ui.dp(this, 14), p, Ui.dp(this, 14));
        k.setBackground(Ui.rounded(Ui.WEISS, Ui.LINIE, Ui.dp(this, 14), Ui.dp(this, 1)));
        k.addView(Ui.text(this, liste.titel(), 22, Ui.DUNKEL, true));
        StringBuilder info = new StringBuilder();
        anhang(info, liste.kunde);
        anhang(info, liste.bauteil);
        anhang(info, liste.datum);
        TextView t = Ui.text(this, info.length() == 0 ? "✎ Antippen: Projekt, Kunde, Datum eintragen" : info + "   ✎", 15, Ui.GRAU, false);
        t.setPadding(0, Ui.dp(this, 4), 0, 0);
        k.addView(t);
        k.setOnClickListener(v -> EditorActivity.kopfdatenDialog(this, liste, this::speichern));
        LinearLayout.LayoutParams lp = zeile(Ui.dp(this, 12));
        k.setLayoutParams(lp);
        return k;
    }

    /** Große Kachel: Symbol, Name, Stand. Farbiger Rand links zeigt den Ast. */
    private View kachel(String symbol, String titel, String stand, int farbe, boolean betont, View.OnClickListener klick) {
        LinearLayout k = new LinearLayout(this);
        k.setOrientation(LinearLayout.HORIZONTAL);
        k.setGravity(Gravity.CENTER_VERTICAL);
        int p = Ui.dp(this, 14);
        k.setPadding(p, p, p, p);
        k.setMinimumHeight(Ui.dp(this, 96));
        k.setBackground(Ui.rounded(betont ? Ui.SUMME : Ui.WEISS, farbe, Ui.dp(this, 14), Ui.dp(this, betont ? 3 : 2)));
        TextView s = Ui.text(this, symbol, 30, Ui.TEXT, false);
        s.setPadding(0, 0, Ui.dp(this, 10), 0);
        k.addView(s);
        LinearLayout txt = new LinearLayout(this);
        txt.setOrientation(LinearLayout.VERTICAL);
        TextView n = Ui.text(this, titel, 18, farbe, true);
        n.setTypeface(Typeface.DEFAULT_BOLD);
        txt.addView(n);
        TextView st = Ui.text(this, stand, 14, Ui.GRAU, false);
        st.setMaxLines(3);
        txt.addView(st);
        k.addView(txt, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        k.setOnClickListener(klick);
        return k;
    }

    private LinearLayout reihe() {
        LinearLayout r = new LinearLayout(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        return r;
    }

    private LinearLayout.LayoutParams spalte(boolean links) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1);
        if (links) lp.setMarginEnd(Ui.dp(this, 10));
        return lp;
    }

    private LinearLayout.LayoutParams zeile(int abstandUnten) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.bottomMargin = abstandUnten;
        return lp;
    }

    private static void anhang(StringBuilder sb, String s) {
        if (s == null || s.trim().isEmpty()) return;
        if (sb.length() > 0) sb.append(" · ");
        sb.append(s.trim());
    }

    private static String kurz(String s) {
        String t = s.trim().replace('\n', ' ');
        return t.length() > 60 ? t.substring(0, 57) + " …" : t;
    }

    // ================================================================ Aktionen

    private void ast(int reiter) {
        Intent i = new Intent(this, EditorActivity.class);
        i.putExtra(EditorActivity.EXTRA_ID, liste.id);
        i.putExtra(EditorActivity.EXTRA_REITER, reiter);
        astOffen = true;
        startActivity(i);
    }

    private void arbeitsanweisung() {
        if (liste.awDatei == null || liste.awDatei.isEmpty()) {
            AwImport.starten(this, liste.positionen.size());
            return;
        }
        boolean pdf = AwImport.hatPdf(this, liste);
        String[] punkte = pdf ? new String[]{"📄 PDF ansehen", "➕ Weitere / neue PDF einlesen"}
                : new String[]{"➕ Weitere / neue PDF einlesen"};
        new AlertDialog.Builder(this).setTitle(liste.awDatei)
                .setItems(punkte, (d, w) -> {
                    if (pdf && w == 0) AwImport.pdfOeffnen(this, liste);
                    else AwImport.starten(this, liste.positionen.size());
                })
                .setNegativeButton("Schließen", null).show();
    }

    private void notiz() {
        android.widget.EditText e = new android.widget.EditText(this);
        e.setText(liste.notiz);
        e.setMinLines(4);
        e.setGravity(Gravity.TOP);
        e.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE
                | android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        LinearLayout box = new LinearLayout(this);
        int p = Ui.dp(this, 20);
        box.setPadding(p, Ui.dp(this, 8), p, 0);
        box.addView(e, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        new AlertDialog.Builder(this).setTitle("Notiz zur Baustelle").setView(box)
                .setPositiveButton("Übernehmen", (d, w) -> { liste.notiz = e.getText().toString().trim(); speichern(); })
                .setNegativeButton("Abbrechen", null).show();
    }

    // ================================================================ Menü

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        menu.add(0, 1, 0, "Projekt / Kunde / Datum ändern");
        menu.add(0, 2, 1, "📄 Arbeitsanweisung (PDF) einlesen …");
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home: finish(); return true;
            case 1: EditorActivity.kopfdatenDialog(this, liste, this::speichern); return true;
            case 2: AwImport.starten(this, liste.positionen.size()); return true;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        AwImport.onActivityResult(this, req, res, data, liste, this::speichern);
    }
}
