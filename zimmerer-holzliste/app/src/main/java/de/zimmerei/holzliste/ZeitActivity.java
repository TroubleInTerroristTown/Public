package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.app.TimePickerDialog;
import android.content.ClipData;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Zeiterfassung („⏱ Stunden“): Kommen / Pause / Wechseln / Gehen, Wochenübersicht, Nachtragen und
 * Excel-Stundenzettel für das Büro. Mit EXTRA_BAUSTELLE nur die Stunden dieser Baustelle.
 */
public class ZeitActivity extends Activity {

    public static final String EXTRA_BAUSTELLE = "baustelle_id";
    static final int ROT = Color.parseColor("#C62828");

    /** Nur für Tests: feste Uhrzeit statt der echten. */
    static long testJetzt;

    static long jetzt() { return testJetzt != 0 ? testJetzt : System.currentTimeMillis(); }

    private List<Zeiteintrag> alle = new ArrayList<>();
    private String baustelleId;      // null = alle Baustellen
    private String baustelleName = "";
    private long woche;              // Montag 0:00 der angezeigten Woche
    private LinearLayout inhalt;
    private LinearLayout status;
    private final Handler takt = new Handler(Looper.getMainLooper());
    private final Runnable tick = new Runnable() {
        @Override public void run() {
            statusAufbauen();
            takt.postDelayed(this, 20_000);
        }
    };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        baustelleId = getIntent().getStringExtra(EXTRA_BAUSTELLE);
        if (baustelleId != null) {
            Holzliste h = Storage.laden(this, baustelleId);
            if (h != null) baustelleName = h.titel();
        }
        woche = Zeiten.wochenStart(jetzt());
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
        setTitle(baustelleId == null ? "⏱ Stunden" : "⏱ Stunden – Baustelle");
    }

    @Override
    protected void onResume() {
        super.onResume();
        alle = Zeiten.alle(this);
        render();
        takt.removeCallbacks(tick);
        takt.postDelayed(tick, 20_000);
    }

    @Override
    protected void onPause() {
        super.onPause();
        takt.removeCallbacks(tick);
    }

    private void speichern() {
        try {
            Zeiten.speichern(this, alle);
        } catch (RuntimeException e) {
            Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG).show();
        }
        render();
    }

    // ================================================================ Darstellung

    void render() {
        inhalt.removeAllViews();
        status = new LinearLayout(this);
        status.setOrientation(LinearLayout.VERTICAL);
        inhalt.addView(status, zeile(12));
        statusAufbauen();
        if (baustelleId == null) inhalt.addView(tagesLeiste(), zeile(12));
        if (baustelleId != null) inhalt.addView(baustellenKarte(), zeile(12));
        wocheAufbauen();
        Button nach = knopf("＋  Nachtragen", Ui.WEISS, Ui.PRIMAER, true);
        nach.setOnClickListener(v -> bearbeiten(null));
        LinearLayout unten = new LinearLayout(this);
        LinearLayout.LayoutParams l1 = new LinearLayout.LayoutParams(0, Ui.dp(this, 52), 1);
        l1.setMarginEnd(Ui.dp(this, 8));
        unten.addView(nach, l1);
        Button abw = knopf("🌴  Abwesenheit", Ui.WEISS, Ui.LILA, true);
        abw.setOnClickListener(v -> abwesenheit());
        unten.addView(abw, new LinearLayout.LayoutParams(0, Ui.dp(this, 52), 1));
        inhalt.addView(unten, zeile(8));
        TextView hinweis = Ui.text(this, "Eintrag antippen zum Ändern, lange drücken zum Löschen.", 13, Ui.GRAU, false);
        hinweis.setGravity(Gravity.CENTER);
        inhalt.addView(hinweis, zeile(8));
    }

    /** Große Karte oben: läuft die Uhr? Mit den Knöpfen Kommen / Pause / Wechseln / Gehen. */
    private void statusAufbauen() {
        if (status == null) return;
        status.removeAllViews();
        long jetzt = jetzt();
        Zeiteintrag z = Zeiten.laufend(alle);
        long heute0 = tagesStart(jetzt);
        int heute = Zeiten.summeMin(Zeiten.zeitraum(alle, heute0, Zeiten.plusTage(heute0, 1), null), jetzt);

        int farbe = z == null ? Ui.LINIE : z.inPause() ? Ui.AKZENT : Ui.GRUEN;
        int p = Ui.dp(this, 16);
        status.setPadding(p, p, p, p);
        status.setBackground(Ui.rounded(Ui.WEISS, farbe, Ui.dp(this, 14), Ui.dp(this, z == null ? 1 : 3)));

        String zeile1 = z == null ? "Nicht eingestempelt"
                : z.inPause() ? "☕ Pause seit " + Zeiten.uhr(z.pauseSeit)
                : "● Läuft seit " + Zeiten.uhr(z.start);
        TextView t1 = Ui.text(this, zeile1, 16, z == null ? Ui.GRAU : farbe, true);
        status.addView(t1);
        TextView uhr = Ui.text(this, Zeiten.hMin(heute), 40, Ui.DUNKEL, true);
        status.addView(uhr);
        TextView t2 = Ui.text(this, "heute gearbeitet", 13, Ui.GRAU, false);
        status.addView(t2);
        if (z != null) {
            StringBuilder was = new StringBuilder();
            if (!z.baustelle.isEmpty()) was.append("🏠 ").append(z.baustelle);
            if (!z.taetigkeit.isEmpty()) was.append(was.length() > 0 ? "\n" : "").append("🔨 ").append(z.taetigkeit);
            if (was.length() > 0) {
                TextView t3 = Ui.text(this, was.toString(), 16, Ui.TEXT, false);
                t3.setPadding(0, Ui.dp(this, 8), 0, 0);
                status.addView(t3);
            }
        }

        LinearLayout knoepfe = new LinearLayout(this);
        knoepfe.setOrientation(LinearLayout.VERTICAL);
        knoepfe.setPadding(0, Ui.dp(this, 14), 0, 0);
        if (z == null) {
            Button k = knopf(baustelleId == null ? "▶  Kommen" : "▶  Kommen – auf dieser Baustelle", Ui.GRUEN, Ui.WEISS, false);
            k.setOnClickListener(v -> kommen(false));
            knoepfe.addView(k, hoch(60, 0));
        } else {
            LinearLayout r = new LinearLayout(this);
            Button pause = knopf(z.inPause() ? "▶  Weiter" : "☕  Pause", z.inPause() ? Ui.GRUEN : Ui.WEISS,
                    z.inPause() ? Ui.WEISS : Ui.AKZENT, !z.inPause());
            pause.setOnClickListener(v -> { Zeiten.pause(Zeiten.laufend(alle), jetzt()); speichern(); });
            Button wechsel = knopf("⇄  Wechseln", Ui.WEISS, Ui.PRIMAER, true);
            wechsel.setOnClickListener(v -> kommen(true));
            LinearLayout.LayoutParams l1 = new LinearLayout.LayoutParams(0, Ui.dp(this, 54), 1);
            l1.setMarginEnd(Ui.dp(this, 8));
            r.addView(pause, l1);
            r.addView(wechsel, new LinearLayout.LayoutParams(0, Ui.dp(this, 54), 1));
            knoepfe.addView(r, hoch(54, 8));
            Button g = knopf("■  Gehen", ROT, Ui.WEISS, false);
            g.setOnClickListener(v -> gehen());
            knoepfe.addView(g, hoch(58, 0));
        }
        status.addView(knoepfe);
    }

    /** Die letzten Arbeitstage als Leiste: grün = Zeit erfasst, rot = nichts eingetragen. Antippen springt hin. */
    private View tagesLeiste() {
        LinearLayout r = new LinearLayout(this);
        long jetzt = jetzt();
        long heute = tagesStart(jetzt);
        List<Long> tage = new ArrayList<>();
        for (long t = heute; tage.size() < 5; t = Zeiten.plusTage(t, -1))
            if (t == heute || Zeiten.sollTagMin(t, 40) > 0) tage.add(0, t);
        for (int i = 0; i < tage.size(); i++) {
            long t = tage.get(i);
            int min = Zeiten.summeMin(Zeiten.zeitraum(alle, t, Zeiten.plusTage(t, 1), null), jetzt);
            int farbe = min > 0 ? Ui.GRUEN : t == heute ? Ui.LINIE : ROT;
            LinearLayout k = new LinearLayout(this);
            k.setOrientation(LinearLayout.VERTICAL);
            k.setGravity(Gravity.CENTER_HORIZONTAL);
            k.setPadding(0, Ui.dp(this, 6), 0, Ui.dp(this, 8));
            k.setBackground(Ui.rounded(t == heute ? Ui.FLAECHE : Ui.WEISS, Ui.LINIE, Ui.dp(this, 10), Ui.dp(this, 1)));
            View balken = new View(this);
            balken.setBackground(Ui.rounded(farbe, 0, Ui.dp(this, 3), 0));
            k.addView(balken, new LinearLayout.LayoutParams(Ui.dp(this, 28), Ui.dp(this, 5)));
            TextView d = Ui.text(this, (t == heute ? "Heute" : new java.text.SimpleDateFormat("EE", Locale.GERMANY).format(t))
                    + "\n" + new java.text.SimpleDateFormat("dd.MM.", Locale.GERMANY).format(t), 13, Ui.DUNKEL, t == heute);
            d.setGravity(Gravity.CENTER);
            d.setPadding(0, Ui.dp(this, 4), 0, 0);
            k.addView(d);
            TextView h = Ui.text(this, min > 0 ? Zeiten.hMin(min).replace(" h", "") : "–", 13, min > 0 ? Ui.PRIMAER : Ui.GRAU, true);
            h.setGravity(Gravity.CENTER);
            k.addView(h);
            k.setOnClickListener(v -> { woche = Zeiten.wochenStart(t); render(); });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
            if (i < tage.size() - 1) lp.setMarginEnd(Ui.dp(this, 6));
            r.addView(k, lp);
        }
        return r;
    }

    /** Urlaub, Krank, Feiertag … für einen oder mehrere Arbeitstage eintragen (zählt mit dem Tages-Soll). */
    private void abwesenheit() {
        new AlertDialog.Builder(this).setTitle("Abwesenheit – was?")
                .setItems(Zeiten.ABWESENHEITEN, (d, w) -> {
                    String art = Zeiten.ABWESENHEITEN[w];
                    Calendar c = Calendar.getInstance(Locale.GERMANY);
                    c.setTimeInMillis(jetzt());
                    DatePickerDialog dp = new DatePickerDialog(this, (p, y, m, t) -> {
                        Calendar ab = Calendar.getInstance(Locale.GERMANY);
                        ab.set(y, m, t, 0, 0, 0);
                        ab.set(Calendar.MILLISECOND, 0);
                        EditText n = new EditText(this);
                        n.setText("1");
                        n.setInputType(InputType.TYPE_CLASS_NUMBER);
                        n.setSelectAllOnFocus(true);
                        new AlertDialog.Builder(this).setTitle(art + " ab " + Zeiten.datum(ab.getTimeInMillis()))
                                .setMessage("Wie viele Arbeitstage (Mo–Fr)?\nJe Tag werden " + Zeiten.hMin(Zeiten.sollTagMin(
                                        Zeiten.wochenStart(jetzt()), Zeiten.sollWoche(this))) + " gutgeschrieben (Wochen-Soll ÷ 5).")
                                .setView(rahmen(n))
                                .setPositiveButton("Eintragen", (x, y2) -> {
                                    int tage;
                                    try { tage = Integer.parseInt(n.getText().toString().trim()); } catch (NumberFormatException e) { tage = 1; }
                                    tage = Math.max(1, Math.min(60, tage));
                                    double soll = Zeiten.sollWoche(this);
                                    if (soll <= 0) soll = 40;
                                    Zeiten.abwesenheit(alle, art, ab.getTimeInMillis(), tage, soll, Zeiten.mitarbeiter(this));
                                    woche = Zeiten.wochenStart(ab.getTimeInMillis());
                                    speichern();
                                }).setNegativeButton("Abbrechen", null).show();
                    }, c.get(Calendar.YEAR), c.get(Calendar.MONTH), c.get(Calendar.DAY_OF_MONTH));
                    dp.setTitle(art + " – erster Tag");
                    dp.show();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    private View baustellenKarte() {
        LinearLayout k = new LinearLayout(this);
        k.setOrientation(LinearLayout.VERTICAL);
        int p = Ui.dp(this, 16);
        k.setPadding(p, Ui.dp(this, 12), p, Ui.dp(this, 12));
        k.setBackground(Ui.rounded(Ui.WEISS, Ui.LINIE, Ui.dp(this, 14), Ui.dp(this, 1)));
        List<Zeiteintrag> hier = Zeiten.zeitraum(alle, Long.MIN_VALUE, Long.MAX_VALUE, baustelleId);
        long jetzt = jetzt();
        k.addView(Ui.text(this, baustelleName.isEmpty() ? "Diese Baustelle" : baustelleName, 18, Ui.DUNKEL, true));
        k.addView(Ui.text(this, "Gesamt auf dieser Baustelle: " + Zeiten.hMin(Zeiten.summeMin(hier, jetzt)), 15, Ui.PRIMAER, true));
        for (Map.Entry<String, Integer> e : Zeiten.summeNach(hier, false, jetzt)) {
            k.addView(Ui.text(this, "   " + e.getKey() + ":  " + Zeiten.hMin(e.getValue()), 14, Ui.GRAU, false));
        }
        return k;
    }

    private void wocheAufbauen() {
        long jetzt = jetzt();
        long bis = Zeiten.plusTage(woche, 7);
        List<Zeiteintrag> l = Zeiten.zeitraum(alle, woche, bis, baustelleId);

        LinearLayout nav = new LinearLayout(this);
        nav.setGravity(Gravity.CENTER_VERTICAL);
        Button zurueck = knopf("◀", Ui.WEISS, Ui.PRIMAER, true);
        zurueck.setOnClickListener(v -> { woche = Zeiten.plusTage(woche, -7); render(); });
        Button vor = knopf("▶", Ui.WEISS, Ui.PRIMAER, true);
        vor.setOnClickListener(v -> { woche = Zeiten.plusTage(woche, 7); render(); });
        LinearLayout mitte = new LinearLayout(this);
        mitte.setOrientation(LinearLayout.VERTICAL);
        mitte.setGravity(Gravity.CENTER);
        TextView kw = Ui.text(this, "KW " + Zeiten.kalenderwoche(woche)
                + (woche == Zeiten.wochenStart(jetzt) ? " (diese Woche)" : ""), 17, Ui.DUNKEL, true);
        kw.setGravity(Gravity.CENTER);
        TextView von = Ui.text(this, new java.text.SimpleDateFormat("dd.MM.", Locale.GERMANY).format(woche)
                + " – " + Zeiten.datum(Zeiten.plusTage(woche, 6)), 13, Ui.GRAU, false);
        von.setGravity(Gravity.CENTER);
        mitte.addView(kw);
        mitte.addView(von);
        nav.addView(zurueck, new LinearLayout.LayoutParams(Ui.dp(this, 52), Ui.dp(this, 48)));
        nav.addView(mitte, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        nav.addView(vor, new LinearLayout.LayoutParams(Ui.dp(this, 52), Ui.dp(this, 48)));
        inhalt.addView(nav, zeile(8));

        int summe = Zeiten.summeMin(l, jetzt);
        double soll = Zeiten.sollWoche(this);
        String sumText = "Woche: " + Zeiten.hMin(summe);
        if (baustelleId == null && soll > 0) {
            int diff = summe - (int) Math.round(soll * 60);
            sumText += "  von " + Fmt.fix(soll, 1).replace(",0", "") + " h  ("
                    + (diff >= 0 ? "+" : "") + Zeiten.hMin(diff).replace(" h", "") + ")";
        }
        if (baustelleId == null && soll > 0 && !alle.isEmpty())
            sumText += "\nÜberstunden gesamt: " + (Zeiten.saldoMin(alle, soll, jetzt) >= 0 ? "+" : "")
                    + Zeiten.hMin(Zeiten.saldoMin(alle, soll, jetzt));
        TextView sum = Ui.text(this, sumText, 16, Ui.PRIMAER, true);
        sum.setGravity(Gravity.CENTER);
        sum.setPadding(0, Ui.dp(this, 8), 0, Ui.dp(this, 8));
        sum.setBackground(Ui.rounded(Ui.SUMME, 0, Ui.dp(this, 10), 0));
        inhalt.addView(sum, zeile(10));

        if (l.isEmpty()) {
            TextView leer = Ui.text(this, "Keine Zeiten in dieser Woche.", 15, Ui.GRAU, false);
            leer.setGravity(Gravity.CENTER);
            leer.setPadding(0, Ui.dp(this, 16), 0, Ui.dp(this, 16));
            inhalt.addView(leer, zeile(8));
            return;
        }
        for (List<Zeiteintrag> tag : Zeiten.nachTag(l).values()) {
            LinearLayout kopf = new LinearLayout(this);
            kopf.setPadding(Ui.dp(this, 4), Ui.dp(this, 6), Ui.dp(this, 4), Ui.dp(this, 4));
            kopf.addView(Ui.text(this, Zeiten.datumLang(tag.get(0).start), 15, Ui.DUNKEL, true),
                    new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            kopf.addView(Ui.text(this, Zeiten.hMin(Zeiten.summeMin(tag, jetzt)), 15, Ui.DUNKEL, true));
            inhalt.addView(kopf);
            for (Zeiteintrag z : tag) inhalt.addView(eintragZeile(z, jetzt), zeile(6));
        }
    }

    private View eintragZeile(Zeiteintrag z, long jetzt) {
        LinearLayout k = new LinearLayout(this);
        k.setGravity(Gravity.CENTER_VERTICAL);
        int p = Ui.dp(this, 12);
        k.setPadding(p, Ui.dp(this, 10), p, Ui.dp(this, 10));
        k.setBackground(Ui.rounded(Ui.WEISS, z.laeuft() ? Ui.GRUEN : Ui.LINIE, Ui.dp(this, 10), Ui.dp(this, z.laeuft() ? 2 : 1)));
        LinearLayout links = new LinearLayout(this);
        links.setOrientation(LinearLayout.VERTICAL);
        links.addView(Ui.text(this, z.istAbwesenheit() ? "ganzer Tag" : Zeiten.uhr(z.start) + " – " + (z.laeuft() ? "läuft" : Zeiten.uhr(z.ende)), 16,
                z.laeuft() ? Ui.GRUEN : Ui.TEXT, true));
        StringBuilder was = new StringBuilder();
        if (z.istAbwesenheit()) was.append("🌴 ").append(z.abwesenheit);
        if (!z.baustelle.isEmpty()) was.append(z.baustelle);
        if (!z.taetigkeit.isEmpty()) was.append(was.length() > 0 ? " · " : "").append(z.taetigkeit);
        if (z.regie) was.append(was.length() > 0 ? " · " : "").append("Ⓡ Regie");
        if (was.length() > 0) links.addView(Ui.text(this, was.toString(), 14, z.istAbwesenheit() ? Ui.LILA : Ui.GRAU, z.istAbwesenheit()));
        StringBuilder mehr = new StringBuilder();
        int pause = z.pauseMin(jetzt);
        if (pause > 0) mehr.append("☕ ").append(pause).append(" min Pause");
        if (!z.notiz.isEmpty()) mehr.append(mehr.length() > 0 ? " · " : "").append("📝 ").append(z.notiz);
        if (mehr.length() > 0) links.addView(Ui.text(this, mehr.toString(), 13, Ui.GRAU, false));
        k.addView(links, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        k.addView(Ui.text(this, Zeiten.hMin(z.nettoMin(jetzt)), 17, Ui.PRIMAER, true));
        k.setOnClickListener(v -> bearbeiten(z));
        k.setOnLongClickListener(v -> { loeschen(z); return true; });
        return k;
    }

    // ================================================================ Stempeln

    /** Kommen bzw. Wechseln: Baustelle (falls nicht fest) und Tätigkeit wählen, dann Uhr starten. */
    private void kommen(boolean wechsel) {
        if (baustelleId != null) {
            taetigkeitWaehlen(wechsel ? "Wechseln zu …" : "Was machst du?", t -> starten(baustelleId, baustelleName, t));
            return;
        }
        baustelleWaehlen(wechsel ? "Wechseln: welche Baustelle?" : "Auf welcher Baustelle?", (id, name) ->
                taetigkeitWaehlen("Was machst du?", t -> starten(id, name, t)));
    }

    private void starten(String id, String name, String taetigkeit) {
        Zeiten.kommen(alle, jetzt(), id, name, taetigkeit, Zeiten.mitarbeiter(this));
        speichern();
    }

    private void gehen() {
        long jetzt = jetzt();
        Zeiteintrag z = Zeiten.gehen(alle, jetzt);
        if (z == null) return;
        speichern();
        // gesetzliche Pause für den ganzen Tag prüfen
        long t0 = tagesStart(z.start);
        List<Zeiteintrag> tag = Zeiten.zeitraum(alle, t0, Zeiten.plusTage(t0, 1), null);
        int netto = Zeiten.summeMin(tag, jetzt), pause = 0;
        for (Zeiteintrag x : tag) pause += x.pauseMin(jetzt);
        int fehlt = Zeiten.fehlendePauseMin(netto, pause);
        if (fehlt <= 0) return;
        int finalPause = pause;
        new AlertDialog.Builder(this).setTitle("Pause vergessen?")
                .setMessage("Heute " + Zeiten.hMin(netto) + " gearbeitet, " + finalPause + " min Pause.\n\n"
                        + "Das Arbeitszeitgesetz verlangt ab 6 Stunden 30 min, ab 9 Stunden 45 min Pause.\n\n"
                        + fehlt + " min Pause nachtragen?")
                .setPositiveButton(fehlt + " min eintragen", (d, w) -> { z.pauseMin += fehlt; speichern(); })
                .setNegativeButton("So lassen", null).show();
    }

    private void loeschen(Zeiteintrag z) {
        new AlertDialog.Builder(this)
                .setMessage("Eintrag " + Zeiten.datum(z.start) + ", " + Zeiten.uhr(z.start) + " – "
                        + (z.laeuft() ? "läuft" : Zeiten.uhr(z.ende)) + " löschen?")
                .setPositiveButton("Löschen", (d, w) -> { alle.remove(z); speichern(); })
                .setNegativeButton("Abbrechen", null).show();
    }

    interface BaustelleGewaehlt { void gewaehlt(String id, String name); }
    interface TextGewaehlt { void gewaehlt(String text); }

    void baustelleWaehlen(String titel, BaustelleGewaehlt ok) {
        List<Holzliste> bs = Storage.alle(this);
        String[] namen = new String[bs.size() + 1];
        for (int i = 0; i < bs.size(); i++) namen[i] = "🏠  " + bs.get(i).titel();
        namen[bs.size()] = "—  ohne Baustelle (Werkstatt, Lager …)";
        new AlertDialog.Builder(this).setTitle(titel)
                .setItems(namen, (d, w) -> {
                    if (w < bs.size()) ok.gewaehlt(bs.get(w).id, bs.get(w).titel());
                    else ok.gewaehlt("", "");
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    void taetigkeitWaehlen(String titel, TextGewaehlt ok) {
        List<String> t = Zeiten.taetigkeiten(alle);
        String[] items = new String[t.size() + 2];
        for (int i = 0; i < t.size(); i++) items[i] = t.get(i);
        items[t.size()] = "✎  Andere …";
        items[t.size() + 1] = "—  keine Angabe";
        new AlertDialog.Builder(this).setTitle(titel)
                .setItems(items, (d, w) -> {
                    if (w < t.size()) ok.gewaehlt(t.get(w));
                    else if (w == t.size()) textEingabe("Tätigkeit", "", ok);
                    else ok.gewaehlt("");
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    private void textEingabe(String titel, String vorgabe, TextGewaehlt ok) {
        EditText e = new EditText(this);
        e.setText(vorgabe);
        e.setSingleLine(true);
        e.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        new AlertDialog.Builder(this).setTitle(titel).setView(rahmen(e))
                .setPositiveButton("OK", (d, w) -> ok.gewaehlt(e.getText().toString().trim()))
                .setNegativeButton("Abbrechen", null).show();
    }

    // ================================================================ Nachtragen / Ändern

    /** Eintrag ändern oder (z == null) einen neuen nachtragen. */
    void bearbeiten(Zeiteintrag original) {
        boolean neu = original == null;
        Zeiteintrag z;
        if (neu) {
            z = new Zeiteintrag();
            Calendar c = Calendar.getInstance(Locale.GERMANY);
            c.setTimeInMillis(jetzt());
            c.set(Calendar.HOUR_OF_DAY, 7); c.set(Calendar.MINUTE, 0); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0);
            z.start = c.getTimeInMillis();
            c.set(Calendar.HOUR_OF_DAY, 16);
            z.ende = c.getTimeInMillis();
            z.pauseMin = 30;
            z.mitarbeiter = Zeiten.mitarbeiter(this);
            if (baustelleId != null) { z.baustelleId = baustelleId; z.baustelle = baustelleName; }
        } else {
            z = original.copy();
        }
        boolean laeuft = z.laeuft();
        // Arbeitswerte: Tag, Von- und Bis-Minute
        Calendar tag = Calendar.getInstance(Locale.GERMANY);
        tag.setTimeInMillis(z.start);
        int[] von = {tag.get(Calendar.HOUR_OF_DAY) * 60 + tag.get(Calendar.MINUTE)};
        Calendar e0 = Calendar.getInstance(Locale.GERMANY);
        e0.setTimeInMillis(laeuft ? jetzt() : z.ende);
        int[] bis = {e0.get(Calendar.HOUR_OF_DAY) * 60 + e0.get(Calendar.MINUTE)};

        Runnable[] pruefer = {null};
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        Button bTag = feld("");
        Button bVon = feld("");
        Button bBis = feld("");
        Button bBau = feld("");
        Runnable beschriften = () -> {
            bTag.setText("📅  " + Zeiten.datumLang(tag.getTimeInMillis()) + tag.get(Calendar.YEAR));
            bVon.setText("Kommen:  " + hhmm(von[0]));
            bBis.setText(laeuft ? "Gehen:  läuft noch" : "Gehen:  " + hhmm(bis[0]) + (bis[0] <= von[0] ? "  (nächster Tag)" : ""));
            bBau.setText("🏠  " + (z.baustelle.isEmpty() ? "ohne Baustelle" : z.baustelle));
            if (pruefer[0] != null) pruefer[0].run();
        };
        beschriften.run();
        bTag.setOnClickListener(v -> new DatePickerDialog(this, (dp, y, m, d) -> { tag.set(y, m, d); beschriften.run(); },
                tag.get(Calendar.YEAR), tag.get(Calendar.MONTH), tag.get(Calendar.DAY_OF_MONTH)).show());
        bVon.setOnClickListener(v -> new TimePickerDialog(this, (tp, h, m) -> { von[0] = h * 60 + m; beschriften.run(); },
                von[0] / 60, von[0] % 60, true).show());
        bBis.setEnabled(!laeuft);
        bBis.setOnClickListener(v -> new TimePickerDialog(this, (tp, h, m) -> { bis[0] = h * 60 + m; beschriften.run(); },
                bis[0] / 60, bis[0] % 60, true).show());
        if (baustelleId == null) bBau.setOnClickListener(v -> baustelleWaehlen("Baustelle", (id, name) -> {
            z.baustelleId = id; z.baustelle = name; beschriften.run(); }));
        else bBau.setEnabled(false);

        EditText pause = new EditText(this);
        pause.setText(String.valueOf(z.pauseMin(jetzt())));
        pause.setInputType(InputType.TYPE_CLASS_NUMBER);
        pause.setSelectAllOnFocus(true);
        EditText taet = new EditText(this);
        taet.setText(z.taetigkeit);
        taet.setHint("z. B. Montage");
        taet.setSingleLine(true);
        Button bTaet = feld("🔨  Tätigkeit wählen …");
        bTaet.setOnClickListener(v -> taetigkeitWaehlen("Tätigkeit", t -> taet.setText(t)));
        android.widget.CheckBox regie = new android.widget.CheckBox(this);
        regie.setText("Ⓡ Regiestunden (Stundenlohn, extra abrechnen)");
        regie.setChecked(z.regie);
        TextView pflicht = Ui.text(this, "", 13, Ui.AKZENT, false);
        Runnable pruefen = () -> {
            int dauer = laeuft ? (int) ((jetzt() - z.start) / 60000L) : ((bis[0] - von[0] + 1440) % 1440 == 0 ? 1440 : (bis[0] - von[0] + 1440) % 1440);
            int pm;
            try { pm = Integer.parseInt(pause.getText().toString().trim()); } catch (NumberFormatException ex) { pm = 0; }
            int fehlt = Zeiten.fehlendePauseMin(Math.max(0, dauer - pm), pm);
            pflicht.setText("Arbeitszeit " + Zeiten.hMin(Math.max(0, dauer - pm))
                    + (fehlt > 0 ? "\n⚠ Gesetzlich fehlen noch " + fehlt + " min Pause (ab 6 h: 30 min, ab 9 h: 45 min)" : ""));
            pflicht.setTextColor(fehlt > 0 ? Ui.AKZENT : Ui.GRAU);
        };
        pause.addTextChangedListener(new android.text.TextWatcher() {
            @Override public void beforeTextChanged(CharSequence c, int a, int b, int d) {}
            @Override public void onTextChanged(CharSequence c, int a, int b, int d) {}
            @Override public void afterTextChanged(android.text.Editable e) { pruefen.run(); }
        });
        EditText notiz = new EditText(this);
        notiz.setText(z.notiz);
        notiz.setHint("Notiz (optional)");
        notiz.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES | InputType.TYPE_TEXT_FLAG_MULTI_LINE);

        box.addView(bTag);
        LinearLayout zeit = new LinearLayout(this);
        zeit.addView(bVon, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        zeit.addView(bBis, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        box.addView(zeit);
        pruefer[0] = pruefen;
        pruefen.run();
        if (z.istAbwesenheit()) {
            box.addView(beschriftung("🌴 " + z.abwesenheit + " – Kommen/Gehen bestimmen nur die Stundenzahl"));
        } else {
            box.addView(beschriftung("Pause in Minuten"));
            box.addView(pause);
            box.addView(pflicht);
            box.addView(bBau);
            box.addView(beschriftung("Tätigkeit"));
            box.addView(taet);
            box.addView(bTaet);
            box.addView(regie);
        }
        box.addView(notiz);
        ScrollView sv = new ScrollView(this);
        sv.addView(rahmen(box));

        AlertDialog.Builder b = new AlertDialog.Builder(this).setTitle(neu ? "Zeit nachtragen" : z.istAbwesenheit() ? z.abwesenheit + " ändern" : "Eintrag ändern").setView(sv)
                .setPositiveButton("Speichern", (d, w) -> {
                    Calendar s = (Calendar) tag.clone();
                    s.set(Calendar.HOUR_OF_DAY, von[0] / 60); s.set(Calendar.MINUTE, von[0] % 60);
                    s.set(Calendar.SECOND, 0); s.set(Calendar.MILLISECOND, 0);
                    z.start = s.getTimeInMillis();
                    if (!laeuft) {
                        Calendar e = (Calendar) s.clone();
                        e.set(Calendar.HOUR_OF_DAY, bis[0] / 60); e.set(Calendar.MINUTE, bis[0] % 60);
                        if (bis[0] <= von[0]) e.add(Calendar.DAY_OF_MONTH, 1); // über Mitternacht
                        z.ende = e.getTimeInMillis();
                    }
                    int pm;
                    try { pm = Integer.parseInt(pause.getText().toString().trim()); } catch (NumberFormatException ex) { pm = 0; }
                    if (z.inPause()) z.pauseSeit = 0; // beim Ändern zählt die eingetragene Pause
                    z.pauseMin = Math.max(0, pm);
                    z.taetigkeit = taet.getText().toString().trim();
                    z.notiz = notiz.getText().toString().trim();
                    z.regie = regie.isChecked() && !z.istAbwesenheit();
                    if (laeuft && z.start > jetzt()) {
                        Toast.makeText(this, "Kommen liegt in der Zukunft – nicht gespeichert", Toast.LENGTH_LONG).show();
                        return;
                    }
                    if (neu) alle.add(z);
                    else alle.set(alle.indexOf(original), z);
                    String ueber = ueberschneidung(z);
                    if (ueber != null) Toast.makeText(this, "Achtung: überschneidet sich mit " + ueber, Toast.LENGTH_LONG).show();
                    if (!neu || Zeiten.wochenStart(z.start) != woche) woche = Zeiten.wochenStart(z.start);
                    speichern();
                })
                .setNegativeButton("Abbrechen", null);
        if (!neu) b.setNeutralButton("Löschen", (d, w) -> loeschen(original));
        b.show();
    }

    /** Liefert die Uhrzeit eines anderen Eintrags, der sich mit z überschneidet, sonst null. */
    private String ueberschneidung(Zeiteintrag z) {
        long ze = z.laeuft() ? jetzt() : z.ende;
        for (Zeiteintrag x : alle) {
            if (x == z) continue;
            long xe = x.laeuft() ? jetzt() : x.ende;
            if (x.start < ze && z.start < xe)
                return Zeiten.datum(x.start) + " " + Zeiten.uhr(x.start) + "–" + (x.laeuft() ? "läuft" : Zeiten.uhr(x.ende));
        }
        return null;
    }

    // ================================================================ Export / Einstellungen

    private void exportieren() {
        if (Zeiten.mitarbeiter(this).isEmpty()) {
            textEingabe("Dein Name (steht auf dem Stundenzettel)", "", n -> {
                if (n.isEmpty()) return;
                Zeiten.setMitarbeiter(this, n);
                exportieren();
            });
            return;
        }
        long jetzt = jetzt();
        long w0 = Zeiten.wochenStart(jetzt), m0 = Zeiten.monatsStart(jetzt);
        long angezeigt = woche;
        String[] punkte = {
                "Angezeigte Woche (KW " + Zeiten.kalenderwoche(angezeigt) + ")",
                "Letzte Woche (KW " + Zeiten.kalenderwoche(Zeiten.plusTage(w0, -7)) + ")",
                "Dieser Monat (" + monat(m0) + ")",
                "Letzter Monat (" + monat(Zeiten.plusMonate(m0, -1)) + ")"};
        new AlertDialog.Builder(this).setTitle("Stundenzettel senden – welcher Zeitraum?")
                .setItems(punkte, (d, w) -> {
                    long von, bis;
                    String name, datei;
                    if (w == 0 || w == 1) {
                        von = w == 0 ? angezeigt : Zeiten.plusTage(w0, -7);
                        bis = Zeiten.plusTage(von, 7);
                        int kw = Zeiten.kalenderwoche(von);
                        name = "KW " + kw + " (" + Zeiten.datum(von) + " – " + Zeiten.datum(Zeiten.plusTage(von, 6)) + ")";
                        datei = "KW" + kw + "_" + Calendar.getInstance(Locale.GERMANY).get(Calendar.YEAR);
                    } else {
                        von = w == 2 ? m0 : Zeiten.plusMonate(m0, -1);
                        bis = Zeiten.plusMonate(von, 1);
                        name = monat(von);
                        datei = new java.text.SimpleDateFormat("yyyy-MM", Locale.GERMANY).format(von);
                    }
                    senden(Zeiten.zeitraum(alle, von, bis, baustelleId), name, datei);
                }).setNegativeButton("Abbrechen", null).show();
    }

    private static String monat(long t) {
        return new java.text.SimpleDateFormat("MMMM yyyy", Locale.GERMANY).format(t);
    }

    private void senden(List<Zeiteintrag> l, String zeitraum, String dateiTeil) {
        if (l.isEmpty()) {
            Toast.makeText(this, "Keine Zeiten im Zeitraum " + zeitraum, Toast.LENGTH_LONG).show();
            return;
        }
        String ma = Zeiten.mitarbeiter(this);
        if (baustelleId != null) zeitraum = zeitraum + " · " + baustelleName;
        try {
            File dir = new File(getCacheDir(), "export");
            if (!dir.exists()) dir.mkdirs();
            File[] alt = dir.listFiles();
            if (alt != null) for (File f : alt) f.delete();
            String dateiname = ("Stunden_" + ma + "_" + dateiTeil).replaceAll("[^A-Za-z0-9ÄÖÜäöüß_\\-]+", "_") + ".xlsx";
            File f = new File(dir, dateiname);
            try (FileOutputStream out = new FileOutputStream(f)) {
                ZeitExcel.write(l, zeitraum, ma, jetzt(), out);
            }
            Uri uri = ExportProvider.uriFor(f.getName());
            Intent s = new Intent(Intent.ACTION_SEND);
            s.setType(EditorActivity.XLSX_MIME);
            s.putExtra(Intent.EXTRA_STREAM, uri);
            String betreff = "Stundenzettel " + ma + " – " + zeitraum;
            s.putExtra(Intent.EXTRA_SUBJECT, betreff);
            s.putExtra(Intent.EXTRA_TEXT, betreff + "\nGesamt: " + Zeiten.hMin(Zeiten.summeMin(l, jetzt())));
            s.setClipData(ClipData.newRawUri("", uri));
            s.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(Intent.createChooser(s, "Stundenzettel senden an …"));
        } catch (Exception e) {
            Toast.makeText(this, "Fehler: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void sollAendern() {
        EditText e = new EditText(this);
        e.setText(Fmt.fix(Zeiten.sollWoche(this), 1).replace(",0", ""));
        Ui.decimalInput(e);
        new AlertDialog.Builder(this).setTitle("Soll-Stunden pro Woche").setView(rahmen(e))
                .setMessage("0 = keine Soll-Anzeige")
                .setPositiveButton("OK", (d, w) -> {
                    try { Zeiten.setSollWoche(this, Double.parseDouble(e.getText().toString().replace(',', '.'))); }
                    catch (NumberFormatException ex) { return; }
                    render();
                }).setNegativeButton("Abbrechen", null).show();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        menu.add(0, 1, 0, "📤 Stundenzettel senden (Excel) …");
        menu.add(0, 2, 1, "👤 Mein Name …");
        menu.add(0, 3, 2, "Soll-Stunden pro Woche …");
        menu.add(0, 4, 3, "Zur aktuellen Woche");
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home: finish(); return true;
            case 1: exportieren(); return true;
            case 2: textEingabe("Dein Name (steht auf dem Stundenzettel)", Zeiten.mitarbeiter(this), n -> {
                        Zeiten.setMitarbeiter(this, n);
                        Toast.makeText(this, "Gespeichert", Toast.LENGTH_SHORT).show(); });
                    return true;
            case 3: sollAendern(); return true;
            case 4: woche = Zeiten.wochenStart(jetzt()); render(); return true;
        }
        return super.onOptionsItemSelected(item);
    }

    // ================================================================ Helfer

    static long tagesStart(long t) { return Zeiten.tagesStart(t); }

    private static String hhmm(int min) {
        return String.format(Locale.GERMANY, "%02d:%02d", min / 60, min % 60);
    }

    private Button knopf(String text, int bg, int fg, boolean rand) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextSize(17);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setTextColor(fg);
        b.setBackground(Ui.rounded(bg, rand ? fg : 0, Ui.dp(this, 12), rand ? Ui.dp(this, 2) : 0));
        return b;
    }

    private Button feld(String text) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextSize(15);
        b.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        return b;
    }

    private TextView beschriftung(String s) {
        TextView t = Ui.text(this, s, 13, Ui.GRAU, false);
        t.setPadding(Ui.dp(this, 4), Ui.dp(this, 8), 0, 0);
        return t;
    }

    private View rahmen(View v) {
        LinearLayout box = new LinearLayout(this);
        int p = Ui.dp(this, 20);
        box.setPadding(p, Ui.dp(this, 8), p, 0);
        box.addView(v, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        return box;
    }

    private LinearLayout.LayoutParams zeile(int abstandDp) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.bottomMargin = Ui.dp(this, abstandDp);
        return lp;
    }

    private LinearLayout.LayoutParams hoch(int hoeheDp, int abstandDp) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, hoeheDp));
        lp.bottomMargin = Ui.dp(this, abstandDp);
        return lp;
    }
}
