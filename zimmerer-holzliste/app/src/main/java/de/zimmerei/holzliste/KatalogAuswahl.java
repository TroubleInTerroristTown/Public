package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.database.Cursor;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.OpenableColumns;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.text.format.DateFormat;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/** Auswahl eines Artikels aus den importierten Händlerkatalogen + Verwaltung/Import. */
public final class KatalogAuswahl {

    public interface Callback { void onAuswahl(Datanorm.Artikel a); }

    public static final int REQ_IMPORT = 77;

    private KatalogAuswahl() {}

    // ------------------------------------------------------------------ Suche / Auswahl

    /** @param typ Positionsart, nach der vorgefiltert wird (abschaltbar), null = alle */
    public static void zeigen(Activity act, String typ, Callback cb) {
        if (Katalog.liste(act).isEmpty()) {
            new AlertDialog.Builder(act).setTitle("Noch keine Artikelliste geladen")
                    .setMessage("Lade zuerst deine Artikelliste in die App:\n\n"
                            + "• deine Inventarliste als Excel-Datei (.xlsx) oder CSV\n"
                            + "• oder eine DATANORM-Datei vom Händler (DATANORM.001 oder ZIP)\n\n"
                            + "Danach kannst du hier nach Kategorien sortiert suchen und Artikel übernehmen.")
                    .setPositiveButton("Datei laden", (d, w) -> importStarten(act))
                    .setNegativeButton("Abbrechen", null).show();
            return;
        }

        LinearLayout root = new LinearLayout(act);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 16);
        root.setPadding(pad, Ui.dp(act, 4), pad, 0);

        EditText such = new EditText(act);
        such.setHint("Suchen: z. B. KVH 8/20, OSB 22, Schrauben, Dämmung …");
        such.setTextSize(18);
        such.setInputType(InputType.TYPE_CLASS_TEXT);
        such.setSingleLine(true);
        root.addView(such, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        CheckBox nurTyp = new CheckBox(act);
        nurTyp.setText(typ == null ? "" : "Nur " + Position.typName(Position.LFM.equals(typ) ? Position.HOLZ : typ)
                + (Position.HOLZ.equals(typ) || Position.LFM.equals(typ) ? ", Latten & Bretter" : "") + " zeigen");
        nurTyp.setChecked(typ != null);
        nurTyp.setButtonTintList(ColorStateList.valueOf(Ui.PRIMAER));
        nurTyp.setVisibility(typ == null ? View.GONE : View.VISIBLE);
        root.addView(nurTyp);

        TextView info = Ui.text(act, "", 12, Ui.GRAU, false);
        root.addView(info);

        // Kategorien als Knöpfe zum Antippen
        android.widget.HorizontalScrollView katScroll = new android.widget.HorizontalScrollView(act);
        katScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout katLeiste = new LinearLayout(act);
        katLeiste.setOrientation(LinearLayout.HORIZONTAL);
        katLeiste.setPadding(0, Ui.dp(act, 6), 0, Ui.dp(act, 6));
        katScroll.addView(katLeiste);
        root.addView(katScroll);
        final String[] kategorie = {null};

        ProgressBar lade = new ProgressBar(act);
        root.addView(lade);

        ListView lv = new ListView(act);
        List<Katalog.Eintrag> treffer = new ArrayList<>();
        BaseAdapter adapter = new BaseAdapter() {
            @Override public int getCount() { return treffer.size(); }
            @Override public Object getItem(int i) { return treffer.get(i); }
            @Override public long getItemId(int i) { return i; }

            @Override
            public View getView(int i, View convert, ViewGroup parent) {
                Katalog.Eintrag e = treffer.get(i);
                LinearLayout l = new LinearLayout(act);
                l.setOrientation(LinearLayout.VERTICAL);
                l.setPadding(Ui.dp(act, 4), Ui.dp(act, 8), Ui.dp(act, 4), Ui.dp(act, 8));
                TextView t = Ui.text(act, Ui.symbol(e.a.typ()) + "  " + e.a.text, 16, Ui.TEXT, true);
                l.addView(t);
                StringBuilder sb = new StringBuilder();
                String m = e.a.masse();
                if (!m.isEmpty()) sb.append(m).append("  ·  ");
                if (e.a.preis != null) sb.append(e.a.preisText()).append("  ·  ");
                if (e.a.bestand != null) sb.append("Lager: ").append(Fmt.num(e.a.bestand)).append("  ·  ");
                if (!e.a.nr.startsWith("INV-")) sb.append("Nr. ").append(e.a.nr);
                TextView s = Ui.text(act, sb.toString(), 13, Ui.farbe(e.a.typ()), false);
                l.addView(s);
                TextView h = Ui.text(act, Kategorien.symbol(e.a.kategorie) + " " + e.a.kategorie + "  ·  " + e.haendler, 12, Ui.GRAU, false);
                l.addView(h);
                return l;
            }
        };
        lv.setAdapter(adapter);
        root.addView(lv, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(act, 380)));

        AlertDialog d = new AlertDialog.Builder(act).setTitle("Artikel suchen")
                .setView(root)
                .setNegativeButton("Abbrechen", null)
                .setNeutralButton("Listen …", (x, y) -> verwalten(act))
                .create();

        Handler ui = new Handler(Looper.getMainLooper());
        final List<Katalog.Eintrag>[] alle = new List[1];
        final int[] gen = {0};
        Runnable suchen = () -> {
            if (alle[0] == null) return;
            int g = ++gen[0];
            String q = such.getText().toString();
            String filter = nurTyp.isChecked() ? typ : null;
            new Thread(() -> {
                List<Katalog.Eintrag> r = Katalog.suche(alle[0], q, filter, kategorie[0], 300);
                ui.post(() -> {
                    if (g != gen[0]) return;
                    treffer.clear();
                    treffer.addAll(r);
                    adapter.notifyDataSetChanged();
                    info.setText(r.size() >= 300 ? "Mehr als 300 Treffer – Suche verfeinern"
                            : r.isEmpty() ? "Keine Treffer" : r.size() + " Treffer");
                });
            }).start();
        };
        such.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            public void onTextChanged(CharSequence s, int a, int b, int c) {}
            public void afterTextChanged(Editable s) { ui.removeCallbacks(suchen); ui.postDelayed(suchen, 250); }
        });
        nurTyp.setOnCheckedChangeListener((b, c) -> suchen.run());
        lv.setOnItemClickListener((p, v, pos, id) -> { d.dismiss(); cb.onAuswahl(treffer.get(pos).a); });

        d.show();
        new Thread(() -> {
            List<Katalog.Eintrag> l = Katalog.alle(act);
            ui.post(() -> {
                alle[0] = l;
                java.util.Map<String, Integer> kats = Katalog.kategorien(l);
                List<TextView> chips = new ArrayList<>();
                Runnable[] markieren = new Runnable[1];
                java.util.List<String> namen = new ArrayList<>();
                namen.add(null);
                namen.addAll(kats.keySet());
                for (String k : namen) {
                    TextView c = Ui.text(act, k == null ? "Alle (" + l.size() + ")"
                            : Kategorien.symbol(k) + " " + k + " (" + kats.get(k) + ")", 15, Ui.PRIMAER, true);
                    c.setPadding(Ui.dp(act, 14), Ui.dp(act, 8), Ui.dp(act, 14), Ui.dp(act, 8));
                    c.setTag(k);
                    c.setOnClickListener(v -> { kategorie[0] = (String) v.getTag(); markieren[0].run(); suchen.run(); });
                    LinearLayout.LayoutParams lpc = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                    lpc.setMarginEnd(Ui.dp(act, 8));
                    katLeiste.addView(c, lpc);
                    chips.add(c);
                }
                markieren[0] = () -> {
                    for (TextView c : chips) {
                        boolean an = java.util.Objects.equals(c.getTag(), kategorie[0]);
                        c.setTextColor(an ? Ui.WEISS : Ui.PRIMAER);
                        c.setBackground(Ui.rounded(an ? Ui.PRIMAER : Ui.FLAECHE, Ui.HELL, Ui.dp(act, 20), Ui.dp(act, 1)));
                    }
                };
                markieren[0].run();
                katScroll.setVisibility(kats.size() > 1 ? View.VISIBLE : View.GONE);
                lade.setVisibility(View.GONE);
                suchen.run();
            });
        }).start();
    }

    // ------------------------------------------------------------------ Verwaltung

    public static void verwalten(Activity act) {
        List<Katalog.Info> l = Katalog.liste(act);
        List<String> items = new ArrayList<>();
        items.add("＋  Artikelliste laden (Excel-Inventar oder DATANORM) …");
        for (Katalog.Info i : l)
            items.add(i.name + "\n" + i.anzahl + " Artikel · importiert " + DateFormat.format("dd.MM.yyyy", i.datum));
        new AlertDialog.Builder(act).setTitle("Artikellisten (Inventar / DATANORM)")
                .setItems(items.toArray(new String[0]), (d, w) -> {
                    if (w == 0) { importStarten(act); return; }
                    Katalog.Info i = l.get(w - 1);
                    new AlertDialog.Builder(act).setTitle(i.name)
                            .setMessage(i.anzahl + " Artikel. Katalog löschen?")
                            .setPositiveButton("Löschen", (x, y) -> {
                                Katalog.loeschen(act, i.id);
                                Toast.makeText(act, "Katalog gelöscht", Toast.LENGTH_SHORT).show();
                            })
                            .setNegativeButton("Abbrechen", null).show();
                })
                .setNegativeButton("Schließen", null).show();
    }

    // ------------------------------------------------------------------ Import

    public static void importStarten(Activity act) {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("*/*");
        try {
            act.startActivityForResult(i, REQ_IMPORT);
        } catch (ActivityNotFoundException e) {
            Toast.makeText(act, "Kein Datei-Dialog verfügbar", Toast.LENGTH_LONG).show();
        }
    }

    /** Aus Activity.onActivityResult aufrufen. @return true wenn behandelt */
    public static boolean onActivityResult(Activity act, int req, int res, Intent data) {
        if (req != REQ_IMPORT) return false;
        if (res != Activity.RESULT_OK || data == null || data.getData() == null) return true;
        Uri uri = data.getData();
        String name = dateiname(act, uri);

        LinearLayout l = new LinearLayout(act);
        int p = Ui.dp(act, 24);
        l.setPadding(p, p, p, p);
        l.addView(new ProgressBar(act));
        TextView t = Ui.text(act, "  Katalog wird eingelesen …", 15, Ui.TEXT, false);
        t.setGravity(android.view.Gravity.CENTER_VERTICAL);
        l.addView(t, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT));
        AlertDialog warte = new AlertDialog.Builder(act).setView(l).setCancelable(false).create();
        warte.show();

        Handler ui = new Handler(Looper.getMainLooper());
        new Thread(() -> {
            String meldung;
            boolean ok = false;
            try (InputStream in = act.getContentResolver().openInputStream(uri)) {
                if (in == null) throw new java.io.IOException("Datei kann nicht geöffnet werden");
                Datanorm.Ergebnis e = Datanorm.lesen(in, name);
                if (e.artikel.isEmpty()) {
                    meldung = "In der Datei „" + name + "“ wurden keine Artikel gefunden.\n\n"
                            + "Unterstützt werden Excel-Listen (.xlsx, Überschrift z. B. „Bezeichnung“, „Einheit“, „Preis“, „Kategorie“), "
                            + "CSV-Dateien und DATANORM 4 (DATANORM.001 … oder als ZIP).";
                } else {
                    Katalog.Info info = Katalog.speichern(act, e);
                    int holz = 0, platten = 0, material = 0;
                    for (Datanorm.Artikel a : e.artikel) {
                        String at = a.typ();
                        if (Position.PLATTE.equals(at)) platten++;
                        else if (Position.MATERIAL.equals(at)) material++;
                        else holz++;
                    }
                    meldung = info.anzahl + " Artikel von „" + info.name + "“ importiert.\n\n"
                            + Katalog.kategorien(Katalog.wrap(e.artikel)).size() + " Kategorien\n"
                            + holz + " Hölzer (Balken, Latten, Bretter)\n"
                            + platten + " Platten\n"
                            + material + " sonstige Materialien";
                    ok = true;
                }
            } catch (Exception ex) {
                meldung = "Fehler beim Einlesen: " + ex.getMessage();
            }
            String m = meldung;
            boolean erfolg = ok;
            ui.post(() -> {
                warte.dismiss();
                new AlertDialog.Builder(act).setTitle(erfolg ? "Katalog importiert ✓" : "Import nicht möglich")
                        .setMessage(m).setPositiveButton("OK", null).show();
            });
        }).start();
        return true;
    }

    private static String dateiname(Activity act, Uri uri) {
        try (Cursor c = act.getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (c != null && c.moveToFirst()) return c.getString(0);
        } catch (Exception ignored) {
        }
        String s = uri.getLastPathSegment();
        return s == null ? "Katalog" : s;
    }
}
