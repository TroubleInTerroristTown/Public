package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

/** Bearbeitung einer Holzliste in Tabellenform mit fixierter Bezeichnungs-Spalte. */
public class EditorActivity extends Activity {

    public static final String EXTRA_ID = "id";
    public static final String EXTRA_NEU = "neu";
    static final String XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private static final int REQ_SAVE = 42;

    // Spalten rechts neben der fixierten Bezeichnung
    private static final String[] COL_HEAD = {"Stk", "B\ncm", "H/D\ncm", "L\nm", "Lfm\nm", "Fläche\nm²", "Vol.\nm³", "Fertig\nB/H cm", "Holzart / Material", "Bemerkung"};
    private static final int[] COL_W = {42, 46, 50, 56, 70, 70, 70, 80, 140, 180};
    private static final int COL_TEXT = 8; // ab hier linksbündige Textspalten
    private static final int LEFT_W = 140;
    private static final int ROW_H = 50, TITEL_H = 38;

    private Holzliste liste;
    private LinearLayout leftCol, rightCol;
    private HorizontalScrollView hHead, hBody;
    private TextView kopfTitel, kopfInfo, sumText, emptyText;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        liste = Storage.laden(this, getIntent().getStringExtra(EXTRA_ID));
        if (liste == null) {
            Toast.makeText(this, "Holzliste nicht gefunden", Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        if (getActionBar() != null) getActionBar().setDisplayHomeAsUpEnabled(true);
        setContentView(buildLayout());
        render();
        if (state == null && getIntent().getBooleanExtra(EXTRA_NEU, false)) kopfdatenDialog();
    }

    // ================================================================ Layout

    private View buildLayout() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Ui.HINTERGRUND);

        // --- Kopfbereich
        LinearLayout kopf = new LinearLayout(this);
        kopf.setOrientation(LinearLayout.VERTICAL);
        int p = Ui.dp(this, 14);
        kopf.setPadding(p, Ui.dp(this, 10), p, Ui.dp(this, 10));
        kopf.setBackground(Ui.touchBg(Ui.WEISS));
        kopf.setOnClickListener(v -> kopfdatenDialog());
        kopfTitel = Ui.text(this, "", 18, Ui.BRAUN_DUNKEL, true);
        kopfInfo = Ui.text(this, "", 13, Ui.GRAU, false);
        kopf.addView(kopfTitel);
        kopf.addView(kopfInfo);
        root.addView(kopf);
        root.addView(Ui.divider(this, false));

        // --- Tabellenkopf
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setBackgroundColor(Ui.BRAUN);
        TextView hl = Ui.cell(this, "Pos.  Bezeichnung", LEFT_W, Gravity.START, true, Ui.WEISS);
        hl.setTextSize(13);
        hl.setElevation(Ui.dp(this, 2));
        hl.setBackgroundColor(Ui.BRAUN);
        head.addView(hl);
        head.addView(sep(Ui.BRAUN_DUNKEL));
        hHead = new HorizontalScrollView(this);
        hHead.setHorizontalScrollBarEnabled(false);
        LinearLayout headCells = new LinearLayout(this);
        headCells.setOrientation(LinearLayout.HORIZONTAL);
        for (int i = 0; i < COL_HEAD.length; i++) {
            TextView t = Ui.cell(this, COL_HEAD[i], COL_W[i], i >= COL_TEXT ? Gravity.START : Gravity.END, true, Ui.WEISS);
            t.setSingleLine(false);
            t.setMaxLines(2);
            t.setTextSize(12);
            headCells.addView(t);
        }
        hHead.addView(headCells, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, Ui.dp(this, 44)));
        head.addView(hHead, new LinearLayout.LayoutParams(0, Ui.dp(this, 44), 1));
        root.addView(head, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 44)));

        // --- Tabellenkörper
        ScrollView vScroll = new ScrollView(this);
        vScroll.setFillViewport(true);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        LinearLayout table = new LinearLayout(this);
        table.setOrientation(LinearLayout.HORIZONTAL);
        leftCol = new LinearLayout(this);
        leftCol.setOrientation(LinearLayout.VERTICAL);
        leftCol.setElevation(Ui.dp(this, 2));
        leftCol.setBackgroundColor(Ui.WEISS);
        table.addView(leftCol, new LinearLayout.LayoutParams(Ui.dp(this, LEFT_W), ViewGroup.LayoutParams.WRAP_CONTENT));
        hBody = new HorizontalScrollView(this);
        rightCol = new LinearLayout(this);
        rightCol.setOrientation(LinearLayout.VERTICAL);
        hBody.addView(rightCol);
        table.addView(hBody, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        body.addView(table);

        emptyText = Ui.text(this, "Noch keine Positionen.\n\nUnten über „+ Stückholz“, „+ Laufmeter“ oder „+ Platten m²“ hinzufügen.\n\nTipp: Eine Zeile antippen zum Bearbeiten, lange drücken für Einfügen (auch Abschnitts-Überschriften), Verschieben, Kopieren, Löschen.",
                15, Ui.GRAU, false);
        emptyText.setGravity(Gravity.CENTER);
        int ep = Ui.dp(this, 32);
        emptyText.setPadding(ep, ep, ep, ep);
        body.addView(emptyText);

        vScroll.addView(body);
        root.addView(vScroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        hBody.setOnScrollChangeListener((v, x, y, ox, oy) -> { if (hHead.getScrollX() != x) hHead.scrollTo(x, 0); });
        hHead.setOnScrollChangeListener((v, x, y, ox, oy) -> { if (hBody.getScrollX() != x) hBody.scrollTo(x, 0); });

        // --- Summenleiste
        root.addView(Ui.divider(this, false));
        sumText = Ui.text(this, "", 14, Ui.BRAUN_DUNKEL, false);
        sumText.setBackgroundColor(Ui.SUMME);
        sumText.setPadding(p, Ui.dp(this, 8), p, Ui.dp(this, 8));
        root.addView(sumText, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        // --- Buttonleiste
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setBackgroundColor(Ui.WEISS);
        int bp = Ui.dp(this, 6);
        bar.setPadding(bp, bp, bp, bp);
        bar.addView(addButton("+ Stückholz", Position.HOLZ));
        bar.addView(addButton("+ Laufmeter", Position.LFM));
        bar.addView(addButton("+ Platten m²", Position.PLATTE));
        root.addView(bar);
        return root;
    }

    private View sep(int color) {
        View v = new View(this);
        v.setBackgroundColor(color);
        v.setLayoutParams(new LinearLayout.LayoutParams(1, ViewGroup.LayoutParams.MATCH_PARENT));
        return v;
    }

    private Button addButton(String text, String typ) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextSize(14);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        boolean primary = Position.HOLZ.equals(typ);
        b.setTextColor(primary ? Ui.WEISS : Ui.BRAUN);
        b.setBackground(Ui.rounded(primary ? Ui.BRAUN : Ui.BEIGE, primary ? 0 : Ui.BRAUN_HELL, Ui.dp(this, 8), Ui.dp(this, 1)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, Ui.dp(this, 46), 1);
        lp.setMargins(Ui.dp(this, 4), 0, Ui.dp(this, 4), 0);
        b.setLayoutParams(lp);
        b.setOnClickListener(v -> neuePosition(typ, liste.positionen.size()));
        return b;
    }

    // ================================================================ Darstellung

    private void render() {
        setTitle("Holzliste");
        kopfTitel.setText(liste.titel());
        StringBuilder info = new StringBuilder();
        anhang(info, liste.kunde);
        anhang(info, liste.bauteil);
        anhang(info, liste.datum);
        if (info.length() == 0) info.append("Kopfdaten antippen zum Bearbeiten (Projekt, Kunde, Datum …)");
        kopfInfo.setText(info);

        leftCol.removeAllViews();
        rightCol.removeAllViews();
        int zeile = 0;
        for (int i = 0; i < liste.positionen.size(); i++) {
            Position p = liste.positionen.get(i);
            final int idx = i;
            View.OnClickListener click = v -> bearbeiten(idx);
            View.OnLongClickListener longClick = v -> { aktionen(idx); return true; };

            if (p.isTitel()) {
                zeile = 0;
                int h = Ui.dp(this, TITEL_H);
                TextView l = Ui.text(this, p.bezeichnung, 14, Ui.BRAUN, true);
                l.setMaxLines(2);
                l.setLineSpacing(0, 0.9f);
                l.setEllipsize(android.text.TextUtils.TruncateAt.END);
                l.setGravity(Gravity.CENTER_VERTICAL);
                l.setPadding(Ui.dp(this, 10), 0, Ui.dp(this, 4), 0);
                l.setBackground(Ui.touchBg(Ui.BEIGE));
                l.setOnClickListener(click);
                l.setOnLongClickListener(longClick);
                leftCol.addView(l, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, h));
                View r = new View(this);
                r.setBackground(Ui.touchBg(Ui.BEIGE));
                r.setOnClickListener(click);
                r.setOnLongClickListener(longClick);
                rightCol.addView(r, new LinearLayout.LayoutParams(totalRightWidth(), h));
                leftCol.addView(Ui.divider(this, false));
                rightCol.addView(line());
                continue;
            }

            int bg = (zeile++ % 2 == 1) ? Ui.ZEBRA : Ui.WEISS;
            int h = Ui.dp(this, ROW_H);

            // linke, fixierte Zelle: Pos + Bezeichnung + Holzart
            LinearLayout l = new LinearLayout(this);
            l.setOrientation(LinearLayout.HORIZONTAL);
            l.setBackground(Ui.touchBg(bg));
            l.setOnClickListener(click);
            l.setOnLongClickListener(longClick);
            TextView pos = Ui.text(this, String.valueOf(liste.posNummer(i)), 12, Ui.GRAU, false);
            pos.setGravity(Gravity.CENTER);
            l.addView(pos, new LinearLayout.LayoutParams(Ui.dp(this, 30), ViewGroup.LayoutParams.MATCH_PARENT));
            LinearLayout txt = new LinearLayout(this);
            txt.setOrientation(LinearLayout.VERTICAL);
            txt.setGravity(Gravity.CENTER_VERTICAL);
            TextView bez = Ui.text(this, p.bezeichnung.isEmpty() ? "(ohne Bezeichnung)" : p.bezeichnung, 15,
                    p.bezeichnung.isEmpty() ? Ui.GRAU : Ui.TEXT, true);
            bez.setSingleLine(true);
            bez.setEllipsize(android.text.TextUtils.TruncateAt.END);
            Double anz = p.isPlatte() ? p.getPlattenAnzahl() : null;
            String sub = (p.isPlatte() ? (anz != null ? Fmt.fix(anz, 0) + " Platten" : "Platte")
                    + (p.verschnitt != null && p.verschnitt != 0 ? " +" + Fmt.num(p.verschnitt) + "%" : "")
                    : p.isLfm() ? "Laufmeter" : "Stück") + (p.holzart.isEmpty() ? "" : " · " + p.holzart);
            TextView art = Ui.text(this, sub, 11, p.isPlatte() ? Ui.GRUEN : p.isLfm() ? Ui.AKZENT : Ui.GRAU, false);
            art.setSingleLine(true);
            art.setEllipsize(android.text.TextUtils.TruncateAt.END);
            txt.addView(bez);
            txt.addView(art);
            txt.setPadding(0, 0, Ui.dp(this, 6), 0);
            l.addView(txt, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1));
            leftCol.addView(l, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, h));
            leftCol.addView(Ui.divider(this, false));

            // rechte Zellen
            LinearLayout r = new LinearLayout(this);
            r.setOrientation(LinearLayout.HORIZONTAL);
            r.setBackground(Ui.touchBg(bg));
            r.setOnClickListener(click);
            r.setOnLongClickListener(longClick);
            boolean platte = p.isPlatte();
            Double stk = platte ? p.getPlattenAnzahl() : p.stueck;
            boolean mitStk = p.isHolz() || (platte && stk != null);
            boolean mitL = p.isHolz() || (platte && p.laenge != null);
            r.addView(Ui.cell(this, mitStk ? Fmt.num(stk) : "–", COL_W[0], Gravity.END, true, mitStk ? (platte ? Ui.GRUEN : Ui.TEXT) : Ui.LINIE));
            r.addView(Ui.cell(this, Fmt.num(p.breite), COL_W[1], Gravity.END, false, Ui.TEXT));
            r.addView(Ui.cell(this, Fmt.num(p.hoehe), COL_W[2], Gravity.END, false, Ui.TEXT));
            r.addView(Ui.cell(this, mitL ? (p.laenge == null ? "" : Fmt.fix(p.laenge, 2)) : "–", COL_W[3], Gravity.END, false, mitL ? Ui.TEXT : Ui.LINIE));
            r.addView(Ui.cell(this, platte ? "–" : Fmt.fix(p.getLaufmeterGesamt(), 2), COL_W[4], Gravity.END, p.isLfm(),
                    platte ? Ui.LINIE : p.isLfm() ? Ui.TEXT : Ui.GRAU));
            r.addView(Ui.cell(this, platte ? Fmt.fix(p.getFlaeche(), 2) : "–", COL_W[5], Gravity.END, platte, platte ? Ui.GRUEN : Ui.LINIE));
            r.addView(Ui.cell(this, Fmt.fix(p.getVolumen(), 3), COL_W[6], Gravity.END, true, Ui.BRAUN));
            r.addView(Ui.cell(this, p.hasFertigmass() ? Fmt.querschnitt(p.fertigB, p.fertigH) : "", COL_W[7], Gravity.END, false, Ui.BLAU));
            r.addView(Ui.cell(this, p.holzart, COL_W[8], Gravity.START, false, Ui.TEXT));
            TextView bem = Ui.cell(this, p.bemerkung, COL_W[9], Gravity.START, false, Ui.GRAU);
            bem.setTextSize(13);
            r.addView(bem);
            rightCol.addView(r, new LinearLayout.LayoutParams(totalRightWidth(), h));
            rightCol.addView(line());
        }
        emptyText.setVisibility(liste.positionen.isEmpty() ? View.VISIBLE : View.GONE);

        sumText.setText("Stückhölzer: " + Fmt.fix(liste.summeVolumen(Position.HOLZ), 3) + " m³  (" + Fmt.fix(liste.summeStueck(), 0) + " Stk)\n"
                + "Laufmeterhölzer: " + Fmt.fix(liste.summeLaufmeter(Position.LFM), 2) + " lfm · " + Fmt.fix(liste.summeVolumen(Position.LFM), 3) + " m³\n"
                + (liste.hatPlatten() ? "Platten: " + Fmt.fix(liste.summeFlaeche(), 2) + " m² Fläche → " + Fmt.fix(liste.summeStueck(Position.PLATTE), 0)
                        + " Stk · " + Fmt.fix(liste.summeVolumen(Position.PLATTE), 3) + " m³\n" : "")
                + "GESAMT: " + Fmt.fix(liste.summeVolumen(null), 3) + " m³");
    }

    private View line() {
        View v = new View(this);
        v.setBackgroundColor(Ui.LINIE);
        v.setLayoutParams(new LinearLayout.LayoutParams(totalRightWidth(), 1));
        return v;
    }

    private int totalRightWidth() {
        int w = 0;
        for (int c : COL_W) w += c;
        return Ui.dp(this, w);
    }

    private static void anhang(StringBuilder sb, String s) {
        if (s == null || s.trim().isEmpty()) return;
        if (sb.length() > 0) sb.append("  ·  ");
        sb.append(s.trim());
    }

    private void speichern() {
        try {
            Storage.speichern(this, liste);
        } catch (RuntimeException e) {
            Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG).show();
        }
        render();
    }

    // ================================================================ Bearbeiten

    private Set<String> bekannteHolzarten() {
        Set<String> s = new LinkedHashSet<>();
        for (int i = liste.positionen.size() - 1; i >= 0; i--) {
            String h = liste.positionen.get(i).holzart;
            if (h != null && !h.trim().isEmpty()) s.add(h.trim());
        }
        return s;
    }

    /** Neue Position an Index einfügen. Holzart/Querschnitt werden von der vorherigen gleichartigen Position übernommen. */
    private void neuePosition(String typ, int index) {
        Position p = new Position();
        p.typ = typ;
        if (!Position.TITEL.equals(typ)) {
            for (int i = Math.min(index, liste.positionen.size()) - 1; i >= 0; i--) {
                Position v = liste.positionen.get(i);
                if (v.isTitel() || v.isPlatte() != Position.PLATTE.equals(typ)) continue;
                p.holzart = v.holzart;
                break;
            }
        }
        new PositionDialog(this, p, true, bekannteHolzarten(), (pos, weitere) -> {
            int at = Math.min(index, liste.positionen.size());
            liste.positionen.add(at, pos);
            speichern();
            if (weitere) neuePosition(Position.TITEL.equals(pos.typ) ? Position.HOLZ : pos.typ, at + 1);
        }).show();
    }

    private void bearbeiten(int i) {
        Position p = liste.positionen.get(i).copy();
        new PositionDialog(this, p, false, bekannteHolzarten(), (pos, weitere) -> {
            liste.positionen.set(i, pos);
            speichern();
        }).show();
    }

    private void aktionen(int i) {
        Position p = liste.positionen.get(i);
        String name = p.bezeichnung.isEmpty() ? "Position" : p.bezeichnung;
        String[] items = {"Bearbeiten", "Neue Zeile darüber einfügen", "Neue Zeile darunter einfügen",
                "Duplizieren (Kopie darunter)", "Nach oben verschieben", "Nach unten verschieben", "Löschen"};
        new AlertDialog.Builder(this).setTitle(name).setItems(items, (d, w) -> {
            switch (w) {
                case 0: bearbeiten(i); break;
                case 1: typWahl(i); break;
                case 2: typWahl(i + 1); break;
                case 3: liste.positionen.add(i + 1, p.copy()); speichern(); break;
                case 4: if (i > 0) { liste.positionen.add(i - 1, liste.positionen.remove(i)); speichern(); } break;
                case 5: if (i < liste.positionen.size() - 1) { liste.positionen.add(i + 1, liste.positionen.remove(i)); speichern(); } break;
                case 6:
                    new AlertDialog.Builder(this).setMessage("„" + name + "“ löschen?")
                            .setPositiveButton("Löschen", (x, y) -> { liste.positionen.remove(i); speichern(); })
                            .setNegativeButton("Abbrechen", null).show();
                    break;
            }
        }).show();
    }

    private void typWahl(int index) {
        String[] items = {"Stückholz", "Laufmeterholz", "Plattenwerkstoff", "Abschnitt / Überschrift"};
        String[] typen = {Position.HOLZ, Position.LFM, Position.PLATTE, Position.TITEL};
        new AlertDialog.Builder(this).setTitle("Was einfügen?")
                .setItems(items, (d, w) -> neuePosition(typen[w], index)).show();
    }

    private void kopfdatenDialog() {
        SharedPreferences prefs = getSharedPreferences("einstellungen", MODE_PRIVATE);
        ScrollView sv = new ScrollView(this);
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(this, 20);
        l.setPadding(pad, Ui.dp(this, 8), pad, 0);
        sv.addView(l);
        EditText eProjekt = feld(l, "Projekt / Bauvorhaben", liste.projekt);
        EditText eKunde = feld(l, "Kunde / Bauherr", liste.kunde);
        EditText eBauteil = feld(l, "Bauteil (z. B. Dachstuhl, Carport)", liste.bauteil);
        EditText eDatum = feld(l, "Datum", liste.datum);
        String bearb = liste.bearbeiter == null || liste.bearbeiter.isEmpty() ? prefs.getString("bearbeiter", "") : liste.bearbeiter;
        EditText eBearb = feld(l, "Bearbeiter", bearb);
        EditText eNotiz = feld(l, "Notiz", liste.notiz);
        eNotiz.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        new AlertDialog.Builder(this).setTitle("Kopfdaten").setView(sv)
                .setPositiveButton("Übernehmen", (d, w) -> {
                    liste.projekt = eProjekt.getText().toString().trim();
                    liste.kunde = eKunde.getText().toString().trim();
                    liste.bauteil = eBauteil.getText().toString().trim();
                    liste.datum = eDatum.getText().toString().trim();
                    liste.bearbeiter = eBearb.getText().toString().trim();
                    liste.notiz = eNotiz.getText().toString().trim();
                    prefs.edit().putString("bearbeiter", liste.bearbeiter).apply();
                    speichern();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    private EditText feld(LinearLayout parent, String label, String value) {
        TextView t = Ui.text(this, label, 12, Ui.GRAU, false);
        t.setPadding(Ui.dp(this, 4), Ui.dp(this, 10), 0, 0);
        parent.addView(t);
        EditText e = new EditText(this);
        e.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        e.setText(value);
        parent.addView(e);
        return e;
    }

    // ================================================================ Einfügen aus Zwischenablage

    private void ausZwischenablage() {
        ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        CharSequence txt = null;
        if (cm != null && cm.hasPrimaryClip() && cm.getPrimaryClip() != null && cm.getPrimaryClip().getItemCount() > 0)
            txt = cm.getPrimaryClip().getItemAt(0).coerceToText(this);
        String hilfe = "Jede Zeile = eine Position, Spalten getrennt mit Tabulator (z. B. aus Excel kopiert) oder Semikolon:\n\n"
                + "Bezeichnung; Stück; Breite; Höhe; Länge; Holzart; Bemerkung\n\n"
                + "• Ohne Stück, aber mit Länge → Laufmeterholz (Länge = Laufmeter)\n"
                + "• Nur Text in der Zeile → Abschnitt\n\n"
                + "Beispiel:\nSparren;24;8;20;7,40;KVH C24\nDachlatten;;3;5;620;Fichte S10";
        if (txt == null || txt.toString().trim().isEmpty()) {
            new AlertDialog.Builder(this).setTitle("Zwischenablage ist leer").setMessage(hilfe)
                    .setPositiveButton("OK", null).show();
            return;
        }
        java.util.List<Position> neu = ClipboardImport.parse(txt.toString());
        if (neu.isEmpty()) {
            new AlertDialog.Builder(this).setTitle("Keine Positionen erkannt").setMessage(hilfe)
                    .setPositiveButton("OK", null).show();
            return;
        }
        new AlertDialog.Builder(this).setTitle(neu.size() + " Zeilen einfügen?")
                .setMessage("Die Positionen werden am Ende der Liste angefügt.")
                .setPositiveButton("Einfügen", (d, w) -> { liste.positionen.addAll(neu); speichern(); })
                .setNeutralButton("Format-Hilfe", (d, w) -> new AlertDialog.Builder(this).setMessage(hilfe).setPositiveButton("OK", null).show())
                .setNegativeButton("Abbrechen", null).show();
    }

    // ================================================================ Excel-Export

    private String dateiname() {
        String n = liste.projekt == null ? "" : liste.projekt.trim();
        n = n.replaceAll("[^A-Za-z0-9ÄÖÜäöüß _-]", "").trim().replace(' ', '_');
        if (n.length() > 40) n = n.substring(0, 40);
        String d = new SimpleDateFormat("yyyy-MM-dd", Locale.GERMANY).format(new Date());
        return "Holzliste_" + (n.isEmpty() ? "" : n + "_") + d + ".xlsx";
    }

    private void exportSpeichern() {
        Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType(XLSX_MIME);
        i.putExtra(Intent.EXTRA_TITLE, dateiname());
        try {
            startActivityForResult(i, REQ_SAVE);
        } catch (ActivityNotFoundException e) {
            Toast.makeText(this, "Kein Datei-Dialog verfügbar – bitte „Teilen“ verwenden", Toast.LENGTH_LONG).show();
        }
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req == REQ_SAVE && res == RESULT_OK && data != null && data.getData() != null) {
            Uri uri = data.getData();
            try (OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
                if (out == null) throw new java.io.IOException("Datei kann nicht geöffnet werden");
                HolzlisteExcel.write(liste, out);
                Toast.makeText(this, "Excel-Datei gespeichert ✓", Toast.LENGTH_LONG).show();
            } catch (Exception e) {
                Toast.makeText(this, "Fehler beim Speichern: " + e.getMessage(), Toast.LENGTH_LONG).show();
            }
        }
    }

    private Uri exportTemp() throws Exception {
        File dir = new File(getCacheDir(), "export");
        if (!dir.exists()) dir.mkdirs();
        File[] alt = dir.listFiles();
        if (alt != null) for (File f : alt) f.delete();
        File f = new File(dir, dateiname());
        try (FileOutputStream out = new FileOutputStream(f)) {
            HolzlisteExcel.write(liste, out);
        }
        return ExportProvider.uriFor(f.getName());
    }

    private void exportTeilen() {
        try {
            Uri uri = exportTemp();
            Intent s = new Intent(Intent.ACTION_SEND);
            s.setType(XLSX_MIME);
            s.putExtra(Intent.EXTRA_STREAM, uri);
            s.putExtra(Intent.EXTRA_SUBJECT, "Holzliste " + liste.titel());
            s.putExtra(Intent.EXTRA_TEXT, "Holzliste " + liste.titel() + " – " + Fmt.fix(liste.summeVolumen(null), 3) + " m³");
            s.setClipData(ClipData.newRawUri("", uri));
            s.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(Intent.createChooser(s, "Excel-Datei senden an …"));
        } catch (Exception e) {
            Toast.makeText(this, "Fehler: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void exportOeffnen() {
        try {
            Uri uri = exportTemp();
            Intent v = new Intent(Intent.ACTION_VIEW);
            v.setDataAndType(uri, XLSX_MIME);
            v.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(v);
        } catch (ActivityNotFoundException e) {
            Toast.makeText(this, "Keine App zum Öffnen von Excel-Dateien installiert (z. B. Microsoft Excel)", Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Toast.makeText(this, "Fehler: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    // ================================================================ Menü

    private static final int M_SAVE = 1, M_SHARE = 2, M_OPEN = 3, M_KOPF = 4, M_PASTE = 5, M_TITEL = 6;

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuItem s = menu.add(0, M_SAVE, 0, "Excel speichern");
        s.setIcon(R.drawable.ic_save);
        s.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        MenuItem t = menu.add(0, M_SHARE, 1, "Excel teilen / senden");
        t.setIcon(R.drawable.ic_share);
        t.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        menu.add(0, M_OPEN, 2, "In Excel öffnen");
        menu.add(0, M_KOPF, 3, "Kopfdaten bearbeiten");
        menu.add(0, M_PASTE, 4, "Zeilen aus Zwischenablage einfügen");
        menu.add(0, M_TITEL, 5, "Abschnitt-Überschrift anfügen");
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home: finish(); return true;
            case M_SAVE: exportSpeichern(); return true;
            case M_SHARE: exportTeilen(); return true;
            case M_OPEN: exportOeffnen(); return true;
            case M_KOPF: kopfdatenDialog(); return true;
            case M_PASTE: ausZwischenablage(); return true;
            case M_TITEL: neuePosition(Position.TITEL, liste.positionen.size()); return true;
        }
        return super.onOptionsItemSelected(item);
    }
}
