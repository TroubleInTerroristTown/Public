package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.graphics.Typeface;
import android.os.Bundle;
import android.text.format.DateFormat;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/** Startbildschirm: Übersicht aller gespeicherten Materiallisten. */
public class MainActivity extends Activity {

    private final List<Holzliste> listen = new ArrayList<>();
    private BaseAdapter adapter;
    private TextView leer;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Ui.HINTERGRUND);

        ListView lv = new ListView(this);
        lv.setDivider(null);
        lv.setClipToPadding(false);
        int p = Ui.dp(this, 10);
        lv.setPadding(p, p, p, p);
        adapter = new Adapter();
        lv.setAdapter(adapter);
        lv.setOnItemClickListener((parent, v, pos, id) -> oeffnen(listen.get(pos), false));
        lv.setOnItemLongClickListener((parent, v, pos, id) -> { aktionen(listen.get(pos)); return true; });

        leer = Ui.text(this, "Noch keine Baustelle angelegt.\n\nTippe unten auf  „📄 Neue Baustelle aus PDF“ (Arbeitsanweisung)\noder auf  „＋ Neue Baustelle“.\n\nJede Baustelle hat Material, Werkzeug und Aufgaben.", 16, Ui.GRAU, false);
        leer.setGravity(Gravity.CENTER);
        leer.setPadding(Ui.dp(this, 32), 0, Ui.dp(this, 32), 0);

        android.widget.FrameLayout frame = new android.widget.FrameLayout(this);
        frame.addView(lv);
        frame.addView(leer, new android.widget.FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        root.addView(frame, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        // Arbeitsanweisung ganz oben: der schnellste Weg zur fertigen Liste
        Button aw = new Button(this);
        aw.setText("📄  Neue Baustelle aus PDF");
        aw.setAllCaps(false);
        aw.setTextSize(19);
        aw.setMaxLines(1);
        aw.setAutoSizeTextTypeUniformWithConfiguration(12, 19, 1, android.util.TypedValue.COMPLEX_UNIT_SP);
        aw.setTypeface(Typeface.DEFAULT_BOLD);
        aw.setTextColor(Ui.WEISS);
        aw.setBackground(Ui.rounded(Ui.AKZENT, 0, Ui.dp(this, 12), 0));
        LinearLayout.LayoutParams lpAw = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 58));
        lpAw.setMargins(Ui.dp(this, 14), Ui.dp(this, 8), Ui.dp(this, 14), 0);
        aw.setOnClickListener(v -> neueListe(true));
        root.addView(aw, lpAw);

        Button neu = new Button(this);
        neu.setText("＋  Neue Baustelle");
        neu.setAllCaps(false);
        neu.setTextSize(17);
        neu.setTypeface(Typeface.DEFAULT_BOLD);
        neu.setTextColor(Ui.PRIMAER);
        neu.setBackground(Ui.rounded(Ui.WEISS, Ui.PRIMAER, Ui.dp(this, 12), Ui.dp(this, 2)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 58));
        lp.setMargins(Ui.dp(this, 14), Ui.dp(this, 8), Ui.dp(this, 14), Ui.dp(this, 14));
        neu.setOnClickListener(v -> neueListe(false));
        root.addView(neu, lp);

        setContentView(root);
        setTitle("Meine Baustellen");
    }

    @Override
    protected void onResume() {
        super.onResume();
        listen.clear();
        listen.addAll(Storage.alle(this));
        adapter.notifyDataSetChanged();
        leer.setVisibility(listen.isEmpty() ? View.VISIBLE : View.GONE);
    }

    private void neueListe(boolean ausAw) {
        Holzliste h = new Holzliste();
        h.datum = new SimpleDateFormat("dd.MM.yyyy", Locale.GERMANY).format(new Date());
        h.bearbeiter = getSharedPreferences("einstellungen", MODE_PRIVATE).getString("bearbeiter", "");
        Storage.speichern(this, h);
        Intent i = new Intent(this, BaustelleActivity.class);
        i.putExtra(BaustelleActivity.EXTRA_ID, h.id);
        i.putExtra(BaustelleActivity.EXTRA_NEU, true);
        i.putExtra(BaustelleActivity.EXTRA_AW, ausAw);
        startActivity(i);
    }

    private void oeffnen(Holzliste h, boolean neu) {
        Intent i = new Intent(this, BaustelleActivity.class);
        i.putExtra(BaustelleActivity.EXTRA_ID, h.id);
        i.putExtra(BaustelleActivity.EXTRA_NEU, neu);
        startActivity(i);
    }

    private void aktionen(Holzliste h) {
        new AlertDialog.Builder(this).setTitle(h.titel())
                .setItems(new String[]{"Öffnen", "Kopieren (als Vorlage)", "Löschen"}, (d, w) -> {
                    if (w == 0) oeffnen(h, false);
                    else if (w == 1) { Storage.duplizieren(this, h); onResume(); }
                    else new AlertDialog.Builder(this).setMessage("Baustelle „" + h.titel() + "“ wirklich löschen?")
                                .setPositiveButton("Löschen", (x, y) -> { Storage.loeschen(this, h.id); onResume(); })
                                .setNegativeButton("Abbrechen", null).show();
                }).show();
    }

    @Override
    public boolean onCreateOptionsMenu(android.view.Menu menu) {
        menu.add(0, 1, 0, "Artikellisten (Inventar / DATANORM) …");
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(android.view.MenuItem item) {
        if (item.getItemId() == 1) { KatalogAuswahl.verwalten(this); return true; }
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        KatalogAuswahl.onActivityResult(this, req, res, data);
    }

    private class Adapter extends BaseAdapter {
        @Override public int getCount() { return listen.size(); }
        @Override public Object getItem(int i) { return listen.get(i); }
        @Override public long getItemId(int i) { return i; }

        @Override
        public View getView(int i, View convert, ViewGroup parent) {
            Holzliste h = listen.get(i);
            LinearLayout card = new LinearLayout(MainActivity.this);
            card.setOrientation(LinearLayout.HORIZONTAL);
            card.setGravity(Gravity.CENTER_VERTICAL);
            int p = Ui.dp(MainActivity.this, 14);
            card.setPadding(p, p, p, p);
            card.setBackground(Ui.rounded(Ui.WEISS, Ui.LINIE, Ui.dp(MainActivity.this, 10), 1));

            LinearLayout left = new LinearLayout(MainActivity.this);
            left.setOrientation(LinearLayout.VERTICAL);
            TextView t = Ui.text(MainActivity.this, h.titel(), 18, Ui.DUNKEL, true);
            StringBuilder sub = new StringBuilder();
            if (h.kunde != null && !h.kunde.isEmpty()) sub.append(h.kunde);
            if (h.bauteil != null && !h.bauteil.isEmpty()) sub.append(sub.length() > 0 ? " · " : "").append(h.bauteil);
            if (h.datum != null && !h.datum.isEmpty()) sub.append(sub.length() > 0 ? " · " : "").append(h.datum);
            TextView s = Ui.text(MainActivity.this, sub.toString(), 13, Ui.GRAU, false);
            TextView g = Ui.text(MainActivity.this, "geändert " + DateFormat.format("dd.MM.yyyy HH:mm", h.geaendert), 11, Ui.GRAU, false);
            left.addView(t);
            if (sub.length() > 0) left.addView(s);
            StringBuilder stand = new StringBuilder();
            if (!h.werkzeug.isEmpty()) stand.append("🔧 ").append(h.anzahlEingepackt()).append("/").append(h.werkzeug.size()).append(" dabei");
            if (!h.aufgaben.isEmpty()) stand.append(stand.length() > 0 ? "   " : "").append("✅ ").append(h.anzahlErledigt()).append("/")
                    .append(h.aufgaben.size()).append(" erledigt");
            if (stand.length() > 0) {
                TextView st = Ui.text(MainActivity.this, stand.toString(), 13, Ui.PRIMAER, true);
                st.setPadding(0, Ui.dp(MainActivity.this, 3), 0, Ui.dp(MainActivity.this, 1));
                left.addView(st);
            }
            left.addView(g);
            card.addView(left, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

            LinearLayout right = new LinearLayout(MainActivity.this);
            right.setOrientation(LinearLayout.VERTICAL);
            right.setGravity(Gravity.END);
            String wert = h.hatPreise() ? Fmt.euro(h.summeBetrag())
                    : h.summeVolumen(null) > 0 ? Fmt.fix(h.summeVolumen(null), 2) + " m³" : "";
            TextView m3 = Ui.text(MainActivity.this, wert, 16, Ui.PRIMAER, true);
            TextView n = Ui.text(MainActivity.this, h.anzahlPositionen() + (h.anzahlPositionen() == 1 ? " Position" : " Positionen"), 12, Ui.GRAU, false);
            m3.setGravity(Gravity.END);
            n.setGravity(Gravity.END);
            right.addView(m3);
            right.addView(n);
            card.addView(right);

            LinearLayout wrap = new LinearLayout(MainActivity.this);
            wrap.setPadding(0, Ui.dp(MainActivity.this, 4), 0, Ui.dp(MainActivity.this, 4));
            wrap.addView(card, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            return wrap;
        }
    }
}
