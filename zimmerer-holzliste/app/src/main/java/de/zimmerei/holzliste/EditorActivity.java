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
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Bearbeitung einer Materialliste: Positionen als große, gut lesbare Karten. */
public class EditorActivity extends Activity {

    public static final String EXTRA_ID = "id";
    public static final String EXTRA_NEU = "neu";
    /** Neue Liste direkt aus einer Arbeitsanweisung (PDF-Auswahl öffnet sich sofort). */
    public static final String EXTRA_AW = "aw";
    /** Welcher Ast der Baustelle gezeigt wird: R_MATERIAL, R_WERKZEUG oder R_AUFGABEN. */
    public static final String EXTRA_REITER = "reiter";
    static final String XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private static final int REQ_SAVE = 42;

    private Holzliste liste;
    private LinearLayout karten;
    private TextView kopfTitel, kopfInfo, sumText, emptyText;
    static final int R_MATERIAL = 0, R_WERKZEUG = 1, R_AUFGABEN = 2;
    private int reiter = R_MATERIAL;
    private Button addBtn, vorschlagBtn;
    /** Material: Auswahl-Modus mit Kästchen (mehrere Zeilen auf einmal löschen oder bestellen). */
    private boolean auswahlModus;
    private final Set<Position> auswahl = java.util.Collections.newSetFromMap(new java.util.IdentityHashMap<>());

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        liste = Storage.laden(this, getIntent().getStringExtra(EXTRA_ID));
        if (liste == null) {
            Toast.makeText(this, "Liste nicht gefunden", Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        if (getActionBar() != null) getActionBar().setDisplayHomeAsUpEnabled(true);
        reiter = getIntent().getIntExtra(EXTRA_REITER, R_MATERIAL);
        AufgabenAnsicht.modusHeute = null; // je Baustelle neu: Heute, wenn etwas für heute ausgewählt ist
        setContentView(buildLayout());
        render();
        if (state == null && getIntent().getBooleanExtra(EXTRA_AW, false)) AwImport.starten(this, 0);
        else if (state == null && getIntent().getBooleanExtra(EXTRA_NEU, false)) kopfdatenDialog(this, liste, this::speichern);
    }

    // ================================================================ Layout

    private View buildLayout() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Ui.HINTERGRUND);

        // --- Kopfbereich (antippen = Kopfdaten ändern)
        LinearLayout kopf = new LinearLayout(this);
        kopf.setOrientation(LinearLayout.VERTICAL);
        int p = Ui.dp(this, 16);
        kopf.setPadding(p, Ui.dp(this, 12), p, Ui.dp(this, 12));
        kopf.setBackground(Ui.touchBg(Ui.WEISS));
        kopf.setOnClickListener(v -> kopfdatenDialog(this, liste, this::speichern));
        kopfTitel = Ui.text(this, "", 20, Ui.DUNKEL, true);
        kopfInfo = Ui.text(this, "", 14, Ui.GRAU, false);
        kopf.addView(kopfTitel);
        kopf.addView(kopfInfo);
        root.addView(kopf);
        root.addView(Ui.divider(this, false));

        // --- Positionen als Karten
        ScrollView vScroll = new ScrollView(this);
        vScroll.setFillViewport(true);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        int lp = Ui.dp(this, 10);
        body.setPadding(lp, Ui.dp(this, 6), lp, Ui.dp(this, 12));
        karten = new LinearLayout(this);
        karten.setOrientation(LinearLayout.VERTICAL);
        body.addView(karten);

        emptyText = Ui.text(this, LEER_MATERIAL, 17, Ui.GRAU, false);
        emptyText.setGravity(Gravity.CENTER);
        int ep = Ui.dp(this, 28);
        emptyText.setPadding(ep, ep * 2, ep, ep);
        body.addView(emptyText);
        vScroll.addView(body);
        root.addView(vScroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        // --- Summenleiste (antippen = Details)
        root.addView(Ui.divider(this, false));
        sumText = Ui.text(this, "", 15, Ui.DUNKEL, false);
        sumText.setBackground(Ui.touchBg(Ui.SUMME));
        sumText.setPadding(p, Ui.dp(this, 10), p, Ui.dp(this, 10));
        sumText.setOnClickListener(v -> summenDetails());
        root.addView(sumText, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        // --- Ein großer Knopf zum Hinzufügen
        LinearLayout bar = new LinearLayout(this);
        bar.setBackgroundColor(Ui.WEISS);
        int bp = Ui.dp(this, 10);
        bar.setPadding(bp, bp, bp, bp);
        vorschlagBtn = new Button(this);
        vorschlagBtn.setText("💡 Vorschlagen");
        vorschlagBtn.setAllCaps(false);
        vorschlagBtn.setTextSize(17);
        vorschlagBtn.setTypeface(Typeface.DEFAULT_BOLD);
        vorschlagBtn.setTextColor(Ui.PRIMAER);
        vorschlagBtn.setBackground(Ui.rounded(Ui.WEISS, Ui.PRIMAER, Ui.dp(this, 12), Ui.dp(this, 2)));
        vorschlagBtn.setOnClickListener(v -> {
            if (reiter == R_MATERIAL && auswahlModus) auswahlBeenden();
            else if (reiter == R_AUFGABEN && AufgabenAnsicht.heuteModus(liste) && !liste.aufgaben.isEmpty()) AufgabenAnsicht.heuteWaehlen(this, liste, this::speichern);
            else if (reiter == R_AUFGABEN) AwImport.starten(this, liste.positionen.size());
            else WerkzeugAnsicht.vorschlaege(this, liste, null, this::speichern);
        });
        LinearLayout.LayoutParams lpV = new LinearLayout.LayoutParams(0, Ui.dp(this, 58), 1);
        lpV.setMarginEnd(Ui.dp(this, 8));
        bar.addView(vorschlagBtn, lpV);
        addBtn = new Button(this);
        addBtn.setText("＋  Hinzufügen");
        addBtn.setAllCaps(false);
        addBtn.setTextSize(19);
        addBtn.setTypeface(Typeface.DEFAULT_BOLD);
        addBtn.setTextColor(Ui.WEISS);
        addBtn.setBackground(Ui.rounded(Ui.AKZENT, 0, Ui.dp(this, 12), 0));
        addBtn.setOnClickListener(v -> {
            if (reiter == R_WERKZEUG) WerkzeugAnsicht.bearbeiten(this, liste, -1, this::speichern);
            else if (reiter == R_AUFGABEN) AufgabenAnsicht.bearbeiten(this, liste, -1, -1, this::speichern);
            else if (auswahlModus) auswahlLoeschen();
            else hinzufuegen(liste.positionen.size());
        });
        bar.addView(addBtn, new LinearLayout.LayoutParams(0, Ui.dp(this, 58), 1));
        root.addView(bar);
        return root;
    }

    // ================================================================ Darstellung

    private void render() {
        setTitle(reiter == R_WERKZEUG ? "🔧 Werkzeug" : reiter == R_AUFGABEN ? "✅ Aufgaben" : "📦 Material");
        kopfTitel.setText(liste.titel());
        StringBuilder info = new StringBuilder();
        anhang(info, liste.kunde);
        anhang(info, liste.bauteil);
        anhang(info, liste.datum);
        kopfInfo.setText(info.length() == 0 ? "✎ Antippen: Projekt, Kunde, Datum eintragen" : info + "   ✎");

        karten.removeAllViews();
        boolean heute = reiter == R_AUFGABEN && AufgabenAnsicht.heuteModus(liste) && !liste.aufgaben.isEmpty();
        vorschlagBtn.setVisibility(reiter == R_MATERIAL && !auswahlModus ? View.GONE : View.VISIBLE);
        vorschlagBtn.setText(reiter == R_MATERIAL ? "✕ Fertig" : heute ? "☀️ Für heute wählen" : reiter == R_AUFGABEN ? "📄 Aus PDF" : "💡 Vorschlagen");
        addBtn.setText(reiter == R_WERKZEUG ? "＋  Werkzeug" : reiter == R_AUFGABEN ? "＋  Aufgabe"
                : auswahlModus ? "🗑  Löschen (" + auswahl.size() + ")" : "＋  Hinzufügen");
        addBtn.setBackground(Ui.rounded(auswahlModus && reiter == R_MATERIAL ? android.graphics.Color.parseColor("#C62828") : Ui.AKZENT,
                0, Ui.dp(this, 12), 0));
        if (reiter == R_WERKZEUG) {
            WerkzeugAnsicht.zeigen(this, liste, karten, this::speichern);
            emptyText.setText("Noch kein Werkzeug eingetragen.\n\nTippe auf  „💡 Vorschlagen“ – die App schlägt Werkzeug passend zum Material "
                    + "und zu den Arbeitsschritten vor.\n\nBeim Laden: Karte antippen = eingepackt ✓");
            emptyText.setVisibility(liste.werkzeug.isEmpty() ? View.VISIBLE : View.GONE);
            int n = liste.werkzeug.size(), e = liste.anzahlEingepackt();
            sumText.setText(n == 0 ? "Noch kein Werkzeug" : e == n ? "✓ Alles eingepackt (" + n + ")   ›" : e + " von " + n + " eingepackt   ›");
            return;
        }
        if (reiter == R_AUFGABEN) {
            AufgabenAnsicht.zeigen(this, liste, karten, this::speichern);
            emptyText.setText("Noch keine Aufgaben.\n\nTippe auf  „📄 Aus PDF“ – aus den Positionen und Arbeitsschritten der "
                    + "Arbeitsanweisung wird eine To-do-Liste.\n\nErledigt: Karte antippen ✓");
            emptyText.setVisibility(liste.aufgaben.isEmpty() ? View.VISIBLE : View.GONE);
            int n = liste.aufgaben.size(), e = liste.anzahlErledigt();
            if (heute) {
                int nH = AufgabenAnsicht.anzahlHeute(liste, false), eH = AufgabenAnsicht.anzahlHeute(liste, true);
                sumText.setText(nH == 0 ? "Heute: noch nichts ausgewählt   ›" : eH == nH ? "☀️ Heute alles erledigt (" + nH + ") · Neuer Tag   ›"
                        : "☀️ Heute: " + eH + " von " + nH + " erledigt   ›");
            } else {
                sumText.setText(n == 0 ? "Noch keine Aufgaben" : e == n ? "✓ Alles erledigt (" + n + ")   ›" : e + " von " + n + " erledigt   ›");
            }
            return;
        }
        for (int i = 0; i < liste.positionen.size(); i++) {
            Position p = liste.positionen.get(i);
            karten.addView(p.isTitel() ? ueberschrift(p, i) : karte(p, i));
        }
        emptyText.setText(LEER_MATERIAL);
        emptyText.setVisibility(liste.positionen.isEmpty() ? View.VISIBLE : View.GONE);
        sumText.setText(auswahlModus ? auswahl.size() + " ausgewählt  ·  Alle / keine   ›" : summenKurz());
    }

    private View ueberschrift(Position p, int idx) {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.HORIZONTAL);
        l.setGravity(Gravity.CENTER_VERTICAL);
        l.setPadding(Ui.dp(this, 6), Ui.dp(this, 14), 0, Ui.dp(this, 2));
        TextView t = Ui.text(this, p.bezeichnung.toUpperCase(Locale.GERMANY), 15, Ui.PRIMAER, true);
        t.setLetterSpacing(0.04f);
        l.addView(t, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        if (auswahlModus) {
            CheckBox cb = auswahlKaestchen(p);
            cb.setOnClickListener(v -> abschnittWaehlen(idx, cb.isChecked()));
            l.addView(cb);
            l.setOnClickListener(v -> abschnittWaehlen(idx, !auswahl.contains(p)));
            return l;
        }
        l.addView(mehrKnopf(idx));
        l.setOnClickListener(v -> bearbeiten(idx));
        l.setOnLongClickListener(v -> { auswahlStarten(p); return true; });
        return l;
    }

    private View karte(Position p, int idx) {
        int farbe = Ui.farbe(p.typ);
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.HORIZONTAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        android.graphics.drawable.GradientDrawable bg = Ui.rounded(Ui.WEISS, Ui.LINIE, Ui.dp(this, 10), 1);
        card.setBackground(new android.graphics.drawable.RippleDrawable(
                android.content.res.ColorStateList.valueOf(Ui.HELL), bg, null));
        boolean gewaehlt = auswahlModus && auswahl.contains(p);
        if (gewaehlt) bg.setColor(Ui.FLAECHE);
        if (auswahlModus) card.setOnClickListener(v -> umschalten(p));
        else card.setOnClickListener(v -> bearbeiten(idx));
        card.setOnLongClickListener(v -> { if (!auswahlModus) auswahlStarten(p); return true; });
        card.setMinimumHeight(Ui.dp(this, 84));

        // links: Symbol + Bestellmenge
        LinearLayout links = new LinearLayout(this);
        links.setOrientation(LinearLayout.VERTICAL);
        links.setGravity(Gravity.CENTER);
        links.setBackground(Ui.rounded(Ui.FLAECHE, 0, Ui.dp(this, 10), 0));
        links.setPadding(Ui.dp(this, 4), Ui.dp(this, 8), Ui.dp(this, 4), Ui.dp(this, 8));
        TextView sym = Ui.text(this, Ui.symbol(p.typ), 22, farbe, false);
        sym.setGravity(Gravity.CENTER);
        String menge = p.bestellText();
        TextView m = Ui.text(this, menge.isEmpty() ? "?" : menge, 15, menge.isEmpty() ? Ui.GRAU : farbe, true);
        m.setGravity(Gravity.CENTER);
        m.setMaxLines(2);
        links.addView(sym);
        links.addView(m);
        LinearLayout.LayoutParams lpL = new LinearLayout.LayoutParams(Ui.dp(this, 96), ViewGroup.LayoutParams.MATCH_PARENT);
        lpL.setMargins(Ui.dp(this, 6), Ui.dp(this, 6), Ui.dp(this, 4), Ui.dp(this, 6));
        card.addView(links, lpL);

        // Mitte: Bezeichnung + Details
        LinearLayout mitte = new LinearLayout(this);
        mitte.setOrientation(LinearLayout.VERTICAL);
        mitte.setPadding(Ui.dp(this, 8), Ui.dp(this, 10), 0, Ui.dp(this, 10));
        String bezText = p.bezeichnung.isEmpty() ? (p.holzart.isEmpty() ? "(ohne Bezeichnung)" : p.holzart) : p.bezeichnung;
        TextView bez = Ui.text(this, liste.posNummer(idx) + ".  " + bezText, 17, Ui.TEXT, true);
        bez.setMaxLines(2);
        bez.setEllipsize(android.text.TextUtils.TruncateAt.END);
        mitte.addView(bez);
        String det = details(p);
        if (!det.isEmpty()) {
            TextView d = Ui.text(this, det, 14, Ui.GRAU, false);
            d.setMaxLines(3);
            mitte.addView(d);
        }
        String werte = werte(p);
        if (!werte.isEmpty()) {
            TextView w = Ui.text(this, werte, 14, Ui.DUNKEL, true);
            w.setPadding(0, Ui.dp(this, 2), 0, 0);
            mitte.addView(w);
        }
        card.addView(mitte, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        if (auswahlModus) {
            CheckBox cb = auswahlKaestchen(p);
            cb.setOnClickListener(v -> umschalten(p));
            card.addView(cb);
        } else {
            card.addView(mehrKnopf(idx));
        }

        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, Ui.dp(this, 4), 0, Ui.dp(this, 4));
        card.setLayoutParams(lp);
        return card;
    }

    // ---------------------------------------------------------------- Auswahl-Modus (Material)

    private CheckBox auswahlKaestchen(Position p) {
        CheckBox cb = new CheckBox(this);
        cb.setChecked(auswahl.contains(p));
        cb.setScaleX(1.3f);
        cb.setScaleY(1.3f);
        cb.setLayoutParams(new LinearLayout.LayoutParams(Ui.dp(this, 52), Ui.dp(this, 56)));
        return cb;
    }

    private void auswahlStarten(Position erste) {
        auswahlModus = true;
        auswahl.clear();
        if (erste != null) {
            int i = liste.positionen.indexOf(erste);
            if (erste.isTitel() && i >= 0) { abschnittWaehlen(i, true); return; }
            auswahl.add(erste);
        }
        invalidateOptionsMenu();
        render();
    }

    private void auswahlBeenden() {
        auswahlModus = false;
        auswahl.clear();
        invalidateOptionsMenu();
        render();
    }

    private void umschalten(Position p) {
        if (!auswahl.remove(p)) auswahl.add(p);
        render();
    }

    /** Überschrift antippen = ganzen Abschnitt (bis zur nächsten Überschrift) an- oder abwählen. */
    private void abschnittWaehlen(int idx, boolean an) {
        for (int i = idx; i < liste.positionen.size(); i++) {
            Position p = liste.positionen.get(i);
            if (i > idx && p.isTitel()) break;
            if (an) auswahl.add(p); else auswahl.remove(p);
        }
        auswahlModus = true;
        invalidateOptionsMenu();
        render();
    }

    private void auswahlLoeschen() {
        if (auswahl.isEmpty()) { Toast.makeText(this, "Erst Zeilen ankreuzen", Toast.LENGTH_SHORT).show(); return; }
        int n = auswahl.size();
        new AlertDialog.Builder(this).setMessage(n + (n == 1 ? " Zeile" : " Zeilen") + " wirklich löschen?")
                .setPositiveButton("Löschen", (d, w) -> {
                    liste.positionen.removeIf(auswahl::contains);
                    auswahlModus = false;
                    auswahl.clear();
                    invalidateOptionsMenu();
                    speichern();
                    Toast.makeText(this, n + " gelöscht", Toast.LENGTH_SHORT).show();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    /** Nur die angekreuzten Zeilen als Bestellliste senden. */
    private void auswahlSenden() {
        if (auswahl.isEmpty()) { Toast.makeText(this, "Erst Zeilen ankreuzen", Toast.LENGTH_SHORT).show(); return; }
        Holzliste teil = new Holzliste();
        teil.id = liste.id;
        teil.projekt = liste.projekt;
        teil.kunde = liste.kunde;
        teil.bauteil = liste.bauteil;
        teil.datum = liste.datum;
        teil.bearbeiter = liste.bearbeiter;
        for (Position p : liste.positionen) if (auswahl.contains(p)) teil.positionen.add(p);
        exportQuelle = teil;
        exportArt = Bestellliste.ALLES;
        exportTeilen();
        exportQuelle = null;
    }

    @Override
    public void onBackPressed() {
        if (auswahlModus) { auswahlBeenden(); return; }
        super.onBackPressed();
    }

    private TextView mehrKnopf(int idx) {
        TextView t = Ui.text(this, "⋮", 26, Ui.GRAU, true);
        t.setGravity(Gravity.CENTER);
        t.setBackground(Ui.touchBg(android.graphics.Color.TRANSPARENT));
        t.setOnClickListener(v -> aktionen(idx));
        t.setLayoutParams(new LinearLayout.LayoutParams(Ui.dp(this, 44), Ui.dp(this, 56)));
        return t;
    }

    /** Zeile unter der Bezeichnung: Material und Maße in Klartext. */
    static String details(Position p) {
        StringBuilder sb = new StringBuilder();
        if (!p.holzart.isEmpty() && !p.holzart.equals(p.bezeichnung)) sb.append(p.holzart);
        String mass = "";
        if (p.isHolz() || p.isLfm()) {
            if (p.breite != null || p.hoehe != null) mass = Fmt.num(p.breite) + " × " + Fmt.num(p.hoehe) + " cm";
            if (p.isHolz() && p.laenge != null) mass += (mass.isEmpty() ? "" : ", ") + Fmt.fix(p.laenge, 2) + " m lang";
            if (p.hasFertigmass()) mass += " (fertig " + Fmt.querschnitt(p.fertigB, p.fertigH) + ")";
        } else if (p.isPlatte()) {
            if (p.laenge != null && p.breite != null) mass = Fmt.num(p.laenge * 100) + " × " + Fmt.num(p.breite) + " cm";
            if (p.hoehe != null) mass += (mass.isEmpty() ? "" : ", ") + Fmt.num(p.hoehe * 10) + " mm";
            mass += (mass.isEmpty() ? "" : "  ·  ") + "für " + Fmt.fix(p.getFlaeche(), 2) + " m²"
                    + (p.verschnitt != null && p.verschnitt != 0 ? " + " + Fmt.num(p.verschnitt) + " %" : "");
        } else if (p.isMaterial()) {
            Double b = p.getBedarf();
            if (p.hatPackung() && b != null)
                mass = "Bedarf " + Fmt.mengeText(b) + " " + Einheit.norm(p.einheit) + ", " + p.packNameOderStandard()
                        + " à " + Fmt.mengeText(p.packInhalt) + " " + Einheit.norm(p.einheit);
            else if (p.verschnitt != null && p.verschnitt != 0 && p.menge != null)
                mass = Fmt.mengeText(p.menge) + " " + Einheit.norm(p.einheit) + " + " + Fmt.num(p.verschnitt) + " % Reserve";
        }
        if (!mass.isEmpty()) sb.append(sb.length() > 0 ? "\n" : "").append(mass);
        if (!p.bemerkung.isEmpty()) sb.append(sb.length() > 0 ? "\n" : "").append("„").append(p.bemerkung).append("“");
        return sb.toString();
    }

    /** Rechenwerte (m, m³, €) für die Karte. */
    static String werte(Position p) {
        StringBuilder sb = new StringBuilder();
        if (p.isHolz() || p.isLfm()) {
            if (p.getLaufmeterGesamt() > 0 && p.isHolz()) sb.append(Fmt.fix(p.getLaufmeterGesamt(), 2)).append(" m  ·  ");
            if (p.getVolumen() > 0) sb.append(Fmt.fix(p.getVolumen(), 3)).append(" m³");
        } else if (p.isPlatte() && p.getPlattenFlaecheGesamt() > 0) {
            sb.append(Fmt.fix(p.getPlattenFlaecheGesamt(), 2)).append(" m² Platten");
        }
        Double b = p.getBetrag();
        if (b != null) {
            String s = sb.toString().replaceAll("[ ·]+$", "");
            sb.setLength(0);
            sb.append(s).append(s.isEmpty() ? "" : "  ·  ").append(Fmt.euro(b));
        }
        return sb.toString().replaceAll("[ ·]+$", "");
    }

    private String summenKurz() {
        if (liste.anzahlPositionen() == 0) return "Noch keine Positionen";
        StringBuilder sb = new StringBuilder();
        sb.append(liste.anzahlPositionen()).append(" Positionen");
        double holz = liste.summeVolumen(Position.HOLZ) + liste.summeVolumen(Position.LFM);
        if (holz > 0) sb.append("  ·  Holz ").append(Fmt.fix(holz, 2)).append(" m³");
        if (liste.hatPlatten()) sb.append("  ·  ").append(Fmt.fix(liste.summeStueck(Position.PLATTE), 0)).append(" Platten");
        if (liste.hatPreise()) sb.append("\nSumme: ").append(Fmt.euro(liste.summeBetrag())).append(" (netto)");
        sb.append("   ›");
        return sb.toString();
    }

    private static final String LEER_MATERIAL = "Die Liste ist noch leer.\n\nTippe unten auf  „＋ Hinzufügen“ – "
            + "oder lies eine Arbeitsanweisung (PDF) ein.\n\n"
            + "Tipp: Eine Zeile antippen = ändern.\nÜber  ⋮  kannst du kopieren, verschieben oder löschen.";

    private void summenDetails() {
        if (reiter == R_MATERIAL && auswahlModus) {
            boolean alle = true;
            for (Position p : liste.positionen) if (!auswahl.contains(p)) alle = false;
            auswahl.clear();
            if (!alle) auswahl.addAll(liste.positionen);
            render();
            return;
        }
        if (reiter == R_AUFGABEN && AufgabenAnsicht.heuteModus(liste)) {
            AufgabenAnsicht.neuerTag(this, liste, this::speichern);
            return;
        }
        if (reiter == R_AUFGABEN) {
            if (liste.anzahlErledigt() == 0) return;
            new AlertDialog.Builder(this).setMessage("Alle Aufgaben wieder als offen markieren?")
                    .setPositiveButton("Häkchen entfernen", (d, w) -> { for (Aufgabe x : liste.aufgaben) x.erledigt = false; speichern(); })
                    .setNegativeButton("Abbrechen", null).show();
            return;
        }
        if (reiter == R_WERKZEUG) {
            if (liste.anzahlEingepackt() == 0) return;
            new AlertDialog.Builder(this).setMessage("Alle Häkchen beim Werkzeug entfernen (für die nächste Fahrt)?")
                    .setPositiveButton("Häkchen entfernen", (d, w) -> { for (Werkzeug x : liste.werkzeug) x.eingepackt = false; speichern(); })
                    .setNegativeButton("Abbrechen", null).show();
            return;
        }
        StringBuilder sb = new StringBuilder();
        if (liste.hatTyp(Position.HOLZ))
            sb.append("Balken & Kanthölzer:\n   ").append(Fmt.fix(liste.summeStueck(Position.HOLZ), 0)).append(" Stück · ")
                    .append(Fmt.fix(liste.summeLaufmeter(Position.HOLZ), 2)).append(" m · ")
                    .append(Fmt.fix(liste.summeVolumen(Position.HOLZ), 3)).append(" m³\n\n");
        if (liste.hatTyp(Position.LFM))
            sb.append("Latten & Bretter:\n   ").append(Fmt.fix(liste.summeLaufmeter(Position.LFM), 2)).append(" m · ")
                    .append(Fmt.fix(liste.summeVolumen(Position.LFM), 3)).append(" m³\n\n");
        if (liste.hatPlatten())
            sb.append("Platten:\n   ").append(Fmt.fix(liste.summeStueck(Position.PLATTE), 0)).append(" Platten für ")
                    .append(Fmt.fix(liste.summeFlaeche(), 2)).append(" m² Fläche · ")
                    .append(Fmt.fix(liste.summeVolumen(Position.PLATTE), 3)).append(" m³\n\n");
        if (liste.hatTyp(Position.MATERIAL)) {
            sb.append("Sonstiges Material:\n");
            for (Position p : liste.positionen)
                if (p.isMaterial()) sb.append("   ").append(p.bestellText()).append("  ")
                        .append(p.bezeichnung.isEmpty() ? p.holzart : p.bezeichnung).append("\n");
            sb.append("\n");
        }
        double m3 = liste.summeVolumen(null);
        if (m3 > 0) sb.append("Holz gesamt: ").append(Fmt.fix(m3, 3)).append(" m³\n");
        if (liste.hatPreise()) sb.append("Summe: ").append(Fmt.euro(liste.summeBetrag())).append(" netto\n(nur Positionen mit Preis)");
        new AlertDialog.Builder(this).setTitle("Zusammenfassung")
                .setMessage(sb.length() == 0 ? "Noch keine Positionen." : sb.toString().trim())
                .setPositiveButton("OK", null)
                .setNeutralButton("Excel senden", (d, w) -> exportTeilen())
                .show();
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

    private Set<String> bekannteMaterialien() {
        Set<String> s = new LinkedHashSet<>();
        for (int i = liste.positionen.size() - 1; i >= 0; i--) {
            String h = liste.positionen.get(i).holzart;
            if (h != null && !h.trim().isEmpty()) s.add(h.trim());
        }
        return s;
    }

    private static final String KATALOG = "katalog";
    private static final String AW = "aw";

    /** Auswahl „Was möchtest du hinzufügen?“ mit großen Kacheln. */
    void hinzufuegen(int index) {
        String[][] items = {
                {AW, "📄", "Aus Arbeitsanweisung (PDF)", "Überschriften, Material und Werkzeug aus einer PDF vorschlagen lassen"},
                {Position.HOLZ, Ui.symbol(Position.HOLZ), "Balken & Kanthölzer", "Sparren, Pfetten, Stiele … – Stückzahl × Länge"},
                {Position.LFM, Ui.symbol(Position.LFM), "Latten & Bretter", "Dachlatten, Schalung, Bretter … – in Metern"},
                {Position.PLATTE, Ui.symbol(Position.PLATTE), "Platten", "OSB, Gipskarton, Dreischicht … – Fläche eingeben, Anzahl wird berechnet"},
                {Position.MATERIAL, Ui.symbol(Position.MATERIAL), "Sonstiges Material", "Schrauben, Dämmung, Folie, Mörtel, Säcke …"},
                {KATALOG, "🔍", "Aus Artikelliste suchen", "Deine Inventarliste oder Händlerliste – nach Kategorien sortiert"},
                {Position.TITEL, Ui.symbol(Position.TITEL), "Überschrift", "z. B. „Dachstuhl“ oder „Dämmung“ – macht die Liste übersichtlicher"},
        };
        android.widget.BaseAdapter ad = new android.widget.BaseAdapter() {
            @Override public int getCount() { return items.length; }
            @Override public Object getItem(int i) { return items[i]; }
            @Override public long getItemId(int i) { return i; }

            @Override
            public View getView(int i, View convert, ViewGroup parent) {
                String[] it = items[i];
                LinearLayout l = new LinearLayout(EditorActivity.this);
                l.setOrientation(LinearLayout.HORIZONTAL);
                l.setGravity(Gravity.CENTER_VERTICAL);
                int pd = Ui.dp(EditorActivity.this, 12);
                l.setPadding(Ui.dp(EditorActivity.this, 20), pd, pd, pd);
                int farbe = KATALOG.equals(it[0]) || AW.equals(it[0]) ? Ui.PRIMAER : Position.TITEL.equals(it[0]) ? Ui.GRAU : Ui.farbe(it[0]);
                TextView sym = Ui.text(EditorActivity.this, it[1], 28, farbe, true);
                sym.setGravity(Gravity.CENTER);
                l.addView(sym, new LinearLayout.LayoutParams(Ui.dp(EditorActivity.this, 48), ViewGroup.LayoutParams.WRAP_CONTENT));
                LinearLayout t = new LinearLayout(EditorActivity.this);
                t.setOrientation(LinearLayout.VERTICAL);
                t.setPadding(Ui.dp(EditorActivity.this, 12), 0, 0, 0);
                t.addView(Ui.text(EditorActivity.this, it[2], 18, Ui.TEXT, true));
                t.addView(Ui.text(EditorActivity.this, it[3], 14, Ui.GRAU, false));
                l.addView(t);
                return l;
            }
        };
        new AlertDialog.Builder(this).setTitle("Was möchtest du hinzufügen?")
                .setAdapter(ad, (d, w) -> {
                    String typ = items[w][0];
                    if (AW.equals(typ)) {
                        AwImport.starten(this, index);
                    } else if (KATALOG.equals(typ)) {
                        KatalogAuswahl.zeigen(this, null, a -> {
                            Position p = new Position();
                            PositionDialog.anwenden(p, a);
                            neuePosition(p, index);
                        });
                    } else {
                        Position p = new Position();
                        p.typ = typ;
                        neuePosition(p, index);
                    }
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    /** Neue Position an Index einfügen. Das Material wird von der vorherigen gleichartigen Position übernommen. */
    private void neuePosition(Position p, int index) {
        if (!p.isTitel() && p.holzart.isEmpty()) {
            for (int i = Math.min(index, liste.positionen.size()) - 1; i >= 0; i--) {
                Position v = liste.positionen.get(i);
                if (!v.typ.equals(p.typ)) continue;
                p.holzart = v.holzart;
                if (p.isMaterial() && p.einheit.isEmpty()) p.einheit = v.einheit;
                break;
            }
        }
        new PositionDialog(this, p, true, bekannteMaterialien(), (pos, weitere) -> {
            int at = Math.min(index, liste.positionen.size());
            liste.positionen.add(at, pos);
            speichern();
            // Neue Position (außer Überschrift): gleich die nächste Eingabe öffnen (beenden mit „Abbrechen“)
            if (weitere || !pos.isTitel()) {
                Position n = new Position();
                n.typ = pos.typ;
                if (pos.isMaterial()) n.einheit = pos.einheit;
                Toast.makeText(this, "✓ Gespeichert – nächste Eingabe", Toast.LENGTH_SHORT).show();
                neuePosition(n, at + 1);
            }
        }).show();
    }

    private void bearbeiten(int i) {
        Position p = liste.positionen.get(i).copy();
        new PositionDialog(this, p, false, bekannteMaterialien(), (pos, weitere) -> {
            liste.positionen.set(i, pos);
            speichern();
        }).show();
    }

    private void aktionen(int i) {
        Position p = liste.positionen.get(i);
        String name = p.bezeichnung.isEmpty() ? "Position" : p.bezeichnung;
        String[] items = {"✎   Ändern", "⧉   Kopieren (Kopie darunter)", "↑   Nach oben schieben", "↓   Nach unten schieben",
                "＋  Neue Zeile hier darüber", "＋  Neue Zeile hier darunter", "🗑   Löschen"};
        new AlertDialog.Builder(this).setTitle(name).setItems(items, (d, w) -> {
            switch (w) {
                case 0: bearbeiten(i); break;
                case 1: liste.positionen.add(i + 1, p.copy()); speichern(); break;
                case 2: if (i > 0) { liste.positionen.add(i - 1, liste.positionen.remove(i)); speichern(); } break;
                case 3: if (i < liste.positionen.size() - 1) { liste.positionen.add(i + 1, liste.positionen.remove(i)); speichern(); } break;
                case 4: hinzufuegen(i); break;
                case 5: hinzufuegen(i + 1); break;
                case 6:
                    new AlertDialog.Builder(this).setMessage("„" + name + "“ wirklich löschen?")
                            .setPositiveButton("Löschen", (x, y) -> { liste.positionen.remove(i); speichern(); })
                            .setNegativeButton("Abbrechen", null).show();
                    break;
            }
        }).show();
    }

    /** Kopfdaten der Baustelle bearbeiten (auch von der Baustellen-Übersicht aus). */
    static void kopfdatenDialog(Activity act, Holzliste liste, Runnable fertig) {
        SharedPreferences prefs = act.getSharedPreferences("einstellungen", MODE_PRIVATE);
        ScrollView sv = new ScrollView(act);
        LinearLayout l = new LinearLayout(act);
        l.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 20);
        l.setPadding(pad, Ui.dp(act, 8), pad, 0);
        sv.addView(l);
        EditText eProjekt = feld(act, l, "Projekt / Bauvorhaben", liste.projekt);
        EditText eKunde = feld(act, l, "Kunde / Bauherr", liste.kunde);
        EditText eBauteil = feld(act, l, "Bauteil (z. B. Dachstuhl, Carport)", liste.bauteil);
        EditText eDatum = feld(act, l, "Datum", liste.datum);
        String bearb = liste.bearbeiter == null || liste.bearbeiter.isEmpty() ? prefs.getString("bearbeiter", "") : liste.bearbeiter;
        EditText eBearb = feld(act, l, "Bearbeiter", bearb);
        EditText eNotiz = feld(act, l, "Notiz", liste.notiz);
        eNotiz.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        new AlertDialog.Builder(act).setTitle("Kopfdaten").setView(sv)
                .setPositiveButton("Übernehmen", (d, w) -> {
                    liste.projekt = eProjekt.getText().toString().trim();
                    liste.kunde = eKunde.getText().toString().trim();
                    liste.bauteil = eBauteil.getText().toString().trim();
                    liste.datum = eDatum.getText().toString().trim();
                    liste.bearbeiter = eBearb.getText().toString().trim();
                    liste.notiz = eNotiz.getText().toString().trim();
                    prefs.edit().putString("bearbeiter", liste.bearbeiter).apply();
                    fertig.run();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    private static EditText feld(Activity act, LinearLayout parent, String label, String value) {
        TextView t = Ui.text(act, label, 12, Ui.GRAU, false);
        t.setPadding(Ui.dp(act, 4), Ui.dp(act, 10), 0, 0);
        parent.addView(t);
        EditText e = new EditText(act);
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
                + "Bezeichnung; Stück/Menge; Breite; Höhe; Länge; Material; Bemerkung; Einheit\n\n"
                + "• Ohne Stück, aber mit Länge → Latten & Bretter (Länge = Meter gesamt)\n"
                + "• Mit Einheit (z. B. Sack, kg, Paket) → sonstiges Material\n"
                + "• Nur Text in der Zeile → Überschrift\n\n"
                + "Beispiel:\nSparren;24;8;20;7,40;KVH C24\nDachlatten;;3;5;620;Fichte S10\nSchrauben 6×200;3;;;;;;Paket";
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

    /** -1 = komplette Liste (wie bisher), sonst Bestellliste.HOLZ / MATERIAL / ALLES. */
    private int exportArt = -1;

    /** Fragt, was exportiert wird: schlichte Bestellliste(n) oder die komplette Liste. */
    private void exportWahl(Runnable weiter) {
        int nH = Bestellliste.anzahl(liste, Bestellliste.HOLZ), nM = Bestellliste.anzahl(liste, Bestellliste.MATERIAL);
        List<String> texte = new ArrayList<>();
        List<Integer> arten = new ArrayList<>();
        if (nH > 0) { texte.add("🪵 Holzliste zum Bestellen (" + nH + " Pos.)\nBalken, Latten, Bretter, Platten"); arten.add(Bestellliste.HOLZ); }
        if (nM > 0) { texte.add("🧱 Materialliste zum Bestellen (" + nM + " Pos.)\nBaustoffe, Schrauben, Dämmung …"); arten.add(Bestellliste.MATERIAL); }
        if (nH > 0 && nM > 0) { texte.add("📋 Holz + Material in einer Bestellliste"); arten.add(Bestellliste.ALLES); }
        texte.add("📑 Komplett (mit Abschnitten, Volumen, Preisen)");
        arten.add(-1);
        new AlertDialog.Builder(this).setTitle("Was soll in die Excel-Datei?")
                .setItems(texte.toArray(new String[0]), (d, w) -> { exportArt = arten.get(w); weiter.run(); })
                .setNegativeButton("Abbrechen", null).show();
    }

    /** Was exportiert wird (null = die ganze Liste; sonst z. B. nur die angekreuzten Zeilen). */
    private Holzliste exportQuelle;

    private void schreiben(OutputStream out) throws java.io.IOException {
        Holzliste q = exportQuelle == null ? liste : exportQuelle;
        if (exportArt < 0) HolzlisteExcel.write(q, out);
        else Bestellliste.write(q, exportArt, out);
    }

    private String dateiname() {
        String n = liste.projekt == null ? "" : liste.projekt.trim();
        n = n.replaceAll("[^A-Za-z0-9ÄÖÜäöüß _-]", "").trim().replace(' ', '_');
        if (n.length() > 40) n = n.substring(0, 40);
        String d = new SimpleDateFormat("yyyy-MM-dd", Locale.GERMANY).format(new Date());
        String art = exportArt < 0 ? "Materialliste" : Bestellliste.titel(exportArt);
        return art + "_" + (n.isEmpty() ? "" : n + "_") + d + ".xlsx";
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
        if (KatalogAuswahl.onActivityResult(this, req, res, data)) return;
        if (AwImport.onActivityResult(this, req, res, data, liste, this::speichern)) return;
        if (req == REQ_SAVE && res == RESULT_OK && data != null && data.getData() != null) {
            Uri uri = data.getData();
            try (OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
                if (out == null) throw new java.io.IOException("Datei kann nicht geöffnet werden");
                schreiben(out);
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
            schreiben(out);
        }
        return ExportProvider.uriFor(f.getName());
    }

    private void exportTeilen() {
        try {
            Uri uri = exportTemp();
            Intent s = new Intent(Intent.ACTION_SEND);
            s.setType(XLSX_MIME);
            s.putExtra(Intent.EXTRA_STREAM, uri);
            String betreff = (exportArt < 0 ? "Materialliste" : Bestellliste.titel(exportArt)) + " " + liste.titel();
            s.putExtra(Intent.EXTRA_SUBJECT, betreff);
            s.putExtra(Intent.EXTRA_TEXT, betreff);
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

    private static final int M_SAVE = 1, M_SHARE = 2, M_OPEN = 3, M_KOPF = 4, M_PASTE = 5, M_TITEL = 6, M_KATALOG = 7, M_AW = 8, M_WZ = 9,
            M_AUSWAHL = 10, M_AUSW_SENDEN = 11, M_AUSW_LOESCHEN = 12;

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        if (reiter != R_MATERIAL) { // Werkzeug & Aufgaben: kein Excel-Export, der ist nur fürs Material
            if (reiter == R_WERKZEUG) menu.add(0, M_WZ, 0, "💡 Werkzeug vorschlagen …");
            else menu.add(0, M_AW, 0, "📄 Arbeitsanweisung (PDF) einlesen …");
            menu.add(0, M_KOPF, 1, "Projekt / Kunde / Datum ändern");
            return true;
        }
        if (auswahlModus) {
            menu.add(0, M_AUSW_SENDEN, 0, "📤 Angekreuzte als Bestellliste senden");
            menu.add(0, M_AUSW_LOESCHEN, 1, "🗑 Angekreuzte löschen");
            return true;
        }
        menu.add(0, M_AUSWAHL, 1, "☑ Mehrere auswählen …");
        MenuItem s = menu.add(0, M_SAVE, 0, "Als Excel speichern");
        s.setIcon(R.drawable.ic_save);
        s.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        MenuItem t = menu.add(0, M_SHARE, 1, "Excel senden (WhatsApp, E-Mail …)");
        t.setIcon(R.drawable.ic_share);
        t.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        menu.add(0, M_OPEN, 2, "In Excel öffnen");
        menu.add(0, M_KOPF, 3, "Projekt / Kunde / Datum ändern");
        menu.add(0, M_TITEL, 4, "Überschrift anfügen");
        menu.add(0, M_AW, 2, "📄 Arbeitsanweisung (PDF) einlesen …");
        menu.add(0, M_PASTE, 5, "Zeilen aus Zwischenablage einfügen");
        menu.add(0, M_KATALOG, 6, "Artikellisten (Inventar / DATANORM) …");
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home: if (auswahlModus) auswahlBeenden(); else finish(); return true;
            case M_AUSWAHL: auswahlStarten(null); return true;
            case M_AUSW_SENDEN: auswahlSenden(); return true;
            case M_AUSW_LOESCHEN: auswahlLoeschen(); return true;
            case M_SAVE: exportWahl(this::exportSpeichern); return true;
            case M_SHARE: exportWahl(this::exportTeilen); return true;
            case M_OPEN: exportWahl(this::exportOeffnen); return true;
            case M_KOPF: kopfdatenDialog(this, liste, this::speichern); return true;
            case M_PASTE: ausZwischenablage(); return true;
            case M_KATALOG: KatalogAuswahl.verwalten(this); return true;
            case M_AW: AwImport.starten(this, liste.positionen.size()); return true;
            case M_WZ: WerkzeugAnsicht.vorschlaege(this, liste, null, this::speichern); return true;
            case M_TITEL: { Position t = new Position(); t.typ = Position.TITEL; neuePosition(t, liste.positionen.size()); } return true;
        }
        return super.onOptionsItemSelected(item);
    }
}
