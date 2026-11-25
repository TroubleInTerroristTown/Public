package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
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
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Eingabe-Dialog für eine Position. Zeigt nur die Felder, die für die gewählte Art nötig sind;
 * Preis, Bemerkung und Fertigmaß liegen unter „Weitere Angaben“.
 */
public class PositionDialog {

    public interface Callback {
        /** @param weitere true = „Weiter ›“ gedrückt (nächste Eingabe öffnen) */
        void onSave(Position p, boolean weitere);

        /** Wird aufgerufen, wenn in der Eingabe ein Artikel aus der Artikelliste übernommen wurde. */
        default void artikelGewaehlt() {}
    }

    static final String[] BEZ_HOLZ = {
            "Sparren", "Firstpfette", "Mittelpfette", "Fußpfette", "Pfette", "Schwelle", "Rähm", "Stiel",
            "Riegel", "Strebe", "Kopfband", "Zange", "Kehlbalken", "Deckenbalken", "Wechsel", "Gratsparren",
            "Kehlsparren", "Aufschiebling", "Stichbalken", "Bundbalken", "Stützen", "Unterzug", "Kantholz",
            "Ortgangbrett", "Traufbohle", "Bohlen"
    };
    static final String[] BEZ_LFM = {
            "Dachlatten", "Konterlatten", "Traglattung", "Lattung", "Rauhspund", "Schalung", "Rhombusleisten",
            "Bretter", "Boden-/Fasebretter", "Deckleisten", "Fassadenschalung", "Kantholz"
    };
    static final String[] BEZ_PLATTE = {
            "Dachschalung", "Wandbeplankung", "Bodenplatten", "Deckenbekleidung", "OSB-Platten", "Gipskartonplatten",
            "Gipsfaserplatten", "Dreischichtplatten", "Holzfaserdämmplatten", "Unterdeckplatten", "Spanplatten"
    };
    static final String[] BEZ_MATERIAL = {
            "Schrauben", "Nägel", "Klammern", "Winkelverbinder", "Balkenschuhe", "Sparrenpfettenanker", "Lochband",
            "Dämmung", "Zwischensparrendämmung", "Dampfbremse", "Unterspannbahn", "Klebeband", "Dichtband",
            "Kartuschen Kleber", "Montageschaum", "Silikon", "Mörtel", "Beton", "Estrich", "Dachziegel",
            "Dachrinne", "Fallrohr", "Bauschrauben", "Holzschutz/Lasur", "Folie"
    };

    static final String[] PLATTEN = {
            "OSB/3", "OSB/3 N+F", "OSB/4", "Gipskarton GKB", "Gipskarton GKF (Feuerschutz)", "Gipskarton GKBI (imprägniert)",
            "Gipsfaserplatte", "Dreischichtplatte Fichte", "Dreischicht-Schalungsplatte", "Spanplatte P5 (V100)",
            "Sperrholz Birke", "Holzfaserdämmplatte", "DWD/MDF-Unterdeckplatte", "MDF", "Zementgebundene Spanplatte"
    };

    static final String[] HOLZARTEN = {
            "KVH NSi C24", "KVH Si C24", "BSH GL24h", "BSH GL28h", "Duobalken C24", "Triobalken C24",
            "Fichte/Tanne S10", "Fichte S10 imprägniert", "Fichte", "Lärche", "Douglasie", "Eiche",
            "Kiefer", "Brettsperrholz"
    };

    static final String[] MATERIALIEN = {
            "Holzbauschraube 6×200", "Spanplattenschraube 5×60", "Mineralwolle WLG 035", "Holzfaser flexibel",
            "Dampfbremsfolie sd 2 m", "Unterdeckbahn diffusionsoffen", "Klebeband innen", "Zementmörtel",
            "Transportbeton C25/30"
    };

    private final Activity act;
    private final Position p;
    private final Callback cb;
    private final boolean neu;
    private final Collection<String> bekannteMaterialien;

    private String typ;
    private AlertDialog dialog;
    private TextView tTyp, tLabelBez, tLabelMat, tErgebnis, tMehr;
    private AutoCompleteTextView eBez, eMat, eEinh, ePackName, ePreisEinh;
    private EditText eStk, eL, eLfm, eB, eH, eFb, eFh, eBem, ePL, ePB, eDicke, eFl, eFlL, eFlB, eVs,
            eMenge, eMatVs, ePack, ePreis, eArtNr;
    private LinearLayout rowStkL, rowLfm, groupQuer, groupPlatte, groupMaterial, groupFertig, groupMehr, groupMasse;

    public PositionDialog(Activity act, Position p, boolean neu, Collection<String> bekannteMaterialien, Callback cb) {
        this.act = act;
        this.p = p;
        this.neu = neu;
        this.cb = cb;
        this.bekannteMaterialien = bekannteMaterialien;
        this.typ = p.typ;
    }

    public void show() {
        ScrollView sv = new ScrollView(act);
        LinearLayout root = new LinearLayout(act);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 20);
        root.setPadding(pad, Ui.dp(act, 4), pad, Ui.dp(act, 4));
        sv.addView(root);

        // --- Art (mit „ändern“)
        tTyp = Ui.text(act, "", 14, Ui.PRIMAER, true);
        tTyp.setPadding(Ui.dp(act, 12), Ui.dp(act, 8), Ui.dp(act, 12), Ui.dp(act, 8));
        tTyp.setBackground(Ui.rounded(Ui.FLAECHE, 0, Ui.dp(act, 8), 0));
        tTyp.setOnClickListener(v -> artWaehlen());
        if (!p.isTitel()) root.addView(tTyp, full());

        // --- Händlerkatalog
        Button katalogBtn = button("🔍  Aus Artikelliste suchen", Ui.WEISS, Ui.PRIMAER, Ui.PRIMAER);
        katalogBtn.setOnClickListener(v -> ausKatalog());
        LinearLayout.LayoutParams lpK = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, Ui.dp(act, 48));
        lpK.topMargin = Ui.dp(act, 10);
        if (!p.isTitel()) root.addView(katalogBtn, lpK);

        // --- Bezeichnung
        tLabelBez = label("Was?");
        root.addView(tLabelBez);
        eBez = new AutoCompleteTextView(act);
        eBez.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        eBez.setThreshold(1);
        eBez.setTextSize(18);
        eBez.setText(p.bezeichnung);
        root.addView(eBez, full());

        groupMasse = vertical();
        root.addView(groupMasse);

        // --- Balken: Stück / Länge
        rowStkL = row();
        eStk = num(Fmt.num(p.stueck), "Stück");
        eL = num(Fmt.num(p.laenge), "m");
        rowStkL.addView(field("Wie viele Stück?", eStk));
        rowStkL.addView(field("Länge je Stück [m]", eL));
        groupMasse.addView(rowStkL);

        // --- Latten: Laufmeter
        rowLfm = row();
        eLfm = num(Fmt.num(p.laufmeter), "m");
        rowLfm.addView(field("Wie viele Meter insgesamt?", eLfm));
        groupMasse.addView(rowLfm);

        // --- Querschnitt (Balken + Latten)
        groupQuer = vertical();
        groupQuer.addView(section("Querschnitt"));
        LinearLayout rq = row();
        eB = num(p.isPlatte() ? "" : Fmt.num(p.breite), "cm");
        eH = num(p.isPlatte() ? "" : Fmt.num(p.hoehe), "cm");
        rq.addView(field("Breite [cm]", eB));
        rq.addView(field("Höhe [cm]", eH));
        groupQuer.addView(rq);
        groupMasse.addView(groupQuer);

        // --- Platten
        groupPlatte = vertical();
        Button waehlen = button("▦  Platte auswählen (OSB, Gips …)", Ui.WEISS, Ui.GRUEN, Ui.GRUEN);
        LinearLayout.LayoutParams lpW = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, Ui.dp(act, 46));
        lpW.topMargin = Ui.dp(act, 12);
        waehlen.setOnClickListener(v -> plattenAuswahl());
        groupPlatte.addView(waehlen, lpW);
        groupPlatte.addView(section("Welche Fläche wird belegt?"));
        boolean altEintrag = p.isPlatte() && !p.hatFlaechenEingabe() && p.stueck != null; // ältere Version
        LinearLayout rfl = row();
        eFlL = num(p.isPlatte() ? Fmt.num(p.flL) : "", "m");
        eFlB = num(p.isPlatte() ? Fmt.num(p.flB) : "", "m");
        rfl.addView(field("Länge [m]", eFlL));
        rfl.addView(field("Breite [m]", eFlB));
        groupPlatte.addView(rfl);
        LinearLayout rfd = row();
        eFl = num(p.isPlatte() ? (altEintrag ? Fmt.num(p.getFlaeche()) : Fmt.num(p.flaeche)) : "", "m²");
        String vs = p.isPlatte() && p.verschnitt != null ? Fmt.num(p.verschnitt) : (altEintrag ? "0" : "10");
        eVs = num(vs, "%");
        rfd.addView(field("oder gleich m²", eFl));
        rfd.addView(field("Verschnitt [%]", eVs));
        groupPlatte.addView(rfd);
        groupPlatte.addView(section("Plattengröße"));
        LinearLayout rp = row();
        ePL = num(p.isPlatte() && p.laenge != null ? Fmt.num(p.laenge * 100) : "", "cm");
        ePB = num(p.isPlatte() ? Fmt.num(p.breite) : "", "cm");
        eDicke = num(p.isPlatte() && p.hoehe != null ? Fmt.num(p.hoehe * 10) : "", "mm");
        rp.addView(field("Länge [cm]", ePL));
        rp.addView(field("Breite [cm]", ePB));
        rp.addView(field("Dicke [mm]", eDicke));
        groupPlatte.addView(rp);
        groupMasse.addView(groupPlatte);

        // --- Material
        groupMaterial = vertical();
        LinearLayout rm = row();
        eMenge = num(Fmt.num(p.menge), "Menge");
        eEinh = auto(Einheit.ALLE, p.einheit, "Stk");
        rm.addView(field("Wie viel?", eMenge));
        rm.addView(field("Einheit", eEinh));
        groupMaterial.addView(rm);
        LinearLayout rmv = row();
        eMatVs = num(p.isMaterial() ? Fmt.num(p.verschnitt) : "", "0");
        rmv.addView(field("Reserve / Verschnitt [%]", eMatVs));
        groupMaterial.addView(rmv);
        groupMaterial.addView(section("Packung (optional) – z. B. Paket à 5,2 m²"));
        LinearLayout rpk = row();
        ePack = num(Fmt.num(p.packInhalt), "Inhalt");
        ePackName = auto(Einheit.PACKUNGEN, p.packName, "Paket");
        rpk.addView(field("Inhalt je Packung", ePack));
        rpk.addView(field("Packung", ePackName));
        groupMaterial.addView(rpk);
        groupMasse.addView(groupMaterial);

        // --- Material / Qualität
        tLabelMat = label("");
        groupMasse.addView(tLabelMat);
        eMat = new AutoCompleteTextView(act);
        eMat.setThreshold(0);
        eMat.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        eMat.setText(p.holzart);
        eMat.setOnFocusChangeListener((v, has) -> { if (has && eMat.getText().length() == 0) eMat.showDropDown(); });
        eMat.setOnClickListener(v -> eMat.showDropDown());
        groupMasse.addView(eMat, full());

        // --- Ergebnis
        tErgebnis = Ui.text(act, "", 16, Ui.DUNKEL, true);
        tErgebnis.setGravity(Gravity.CENTER);
        int pp = Ui.dp(act, 12);
        tErgebnis.setPadding(pp, pp, pp, pp);
        tErgebnis.setBackground(Ui.rounded(Ui.SUMME, 0, Ui.dp(act, 8), 0));
        LinearLayout.LayoutParams lpE = full();
        lpE.topMargin = Ui.dp(act, 14);
        groupMasse.addView(tErgebnis, lpE);

        // --- Weitere Angaben (Preis, Bemerkung, Fertigmaß)
        tMehr = Ui.text(act, "", 15, Ui.PRIMAER, true);
        tMehr.setPadding(Ui.dp(act, 4), Ui.dp(act, 16), 0, Ui.dp(act, 8));
        tMehr.setOnClickListener(v -> setMehr(groupMehr.getVisibility() != View.VISIBLE));
        groupMasse.addView(tMehr);
        groupMehr = vertical();
        LinearLayout rpr = row();
        ePreis = num(p.preis == null ? "" : Fmt.fix(p.preis, 2), "€");
        ePreisEinh = auto(Einheit.ALLE, p.preisEinheit, "");
        rpr.addView(field("Preis [€]", ePreis));
        rpr.addView(field("je", ePreisEinh));
        groupMehr.addView(rpr);
        groupMehr.addView(label("Artikelnummer"));
        eArtNr = new EditText(act);
        eArtNr.setInputType(InputType.TYPE_CLASS_TEXT);
        eArtNr.setText(p.artikelNr);
        groupMehr.addView(eArtNr, full());
        groupMehr.addView(label("Bemerkung"));
        eBem = new EditText(act);
        eBem.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        eBem.setText(p.bemerkung);
        eBem.setHint("z. B. gehobelt, imprägniert, Farbe …");
        groupMehr.addView(eBem, full());
        groupFertig = vertical();
        groupFertig.addView(section("Fertigmaß (z. B. gehobelt)"));
        LinearLayout rf = row();
        eFb = num(Fmt.num(p.fertigB), "cm");
        eFh = num(Fmt.num(p.fertigH), "cm");
        rf.addView(field("Breite [cm]", eFb));
        rf.addView(field("Höhe [cm]", eFh));
        groupFertig.addView(rf);
        groupMehr.addView(groupFertig);
        groupMasse.addView(groupMehr);
        setMehr(p.preis != null || !leer(p.bemerkung) || !leer(p.artikelNr) || p.hasFertigmass());

        TextWatcher tw = new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            public void onTextChanged(CharSequence s, int a, int b, int c) {}
            public void afterTextChanged(Editable s) { updateErgebnis(); }
        };
        for (EditText e : zahlenFelder()) e.addTextChangedListener(tw);
        for (EditText e : new EditText[]{eEinh, ePackName, ePreisEinh}) e.addTextChangedListener(tw);

        updateTyp();

        AlertDialog.Builder b = new AlertDialog.Builder(act)
                .setTitle(p.isTitel() ? "Überschrift" : neu ? "Neu hinzufügen" : "Ändern")
                .setView(sv)
                .setPositiveButton(fortlaufend() ? "Weiter ›" : "Speichern", null)
                .setNegativeButton("Abbrechen", null);
        if (fortlaufend()) b.setNeutralButton("Fertig", null);
        dialog = b.create();
        dialog.setOnShowListener(x -> {
            Button ok = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
            for (int bt : new int[]{AlertDialog.BUTTON_POSITIVE, AlertDialog.BUTTON_NEGATIVE, AlertDialog.BUTTON_NEUTRAL}) {
                Button k = dialog.getButton(bt);
                if (k != null) { k.setAllCaps(false); k.setTextSize(15); }
            }
            ok.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
            if (fortlaufend()) {
                // Neue Position: speichern und sofort die nächste Eingabe öffnen
                ok.setOnClickListener(v -> {
                    if (eingabeLeer()) {
                        Toast.makeText(act, "Noch nichts eingegeben – zum Beenden „Fertig“ tippen", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    if (uebernehmen()) { dialog.dismiss(); cb.onSave(p, true); }
                });
                // Fertig: aktuelle Eingabe (falls vorhanden) speichern und beenden
                dialog.getButton(AlertDialog.BUTTON_NEUTRAL).setOnClickListener(v -> {
                    if (eingabeLeer()) { dialog.dismiss(); return; }
                    if (uebernehmen()) { dialog.dismiss(); cb.onSave(p, false); }
                });
            } else {
                ok.setOnClickListener(v -> { if (uebernehmen()) { dialog.dismiss(); cb.onSave(p, false); } });
            }
        });
        if (dialog.getWindow() != null) dialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
                | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        dialog.show();
        eBez.requestFocus();
        if (neu && p.isPlatte() && ePL.getText().length() == 0 && ePB.getText().length() == 0) plattenAuswahl();
    }

    // ---------------------------------------------------------------- Aktionen

    private void artWaehlen() {
        String[] typen = {Position.HOLZ, Position.LFM, Position.PLATTE, Position.MATERIAL};
        String[] namen = new String[typen.length];
        for (int i = 0; i < typen.length; i++) namen[i] = Ui.symbol(typen[i]) + "  " + Position.typName(typen[i]);
        new AlertDialog.Builder(act).setTitle("Art ändern")
                .setItems(namen, (d, w) -> { typ = typen[w]; updateTyp(); }).show();
    }

    /** Sucht einen Artikel im Händlerkatalog und öffnet den Dialog mit den übernommenen Werten neu. */
    private void ausKatalog() {
        if (!zahlenOk()) return;
        lesen(p);
        KatalogAuswahl.zeigen(act, typ, a -> {
            anwenden(p, a);
            cb.artikelGewaehlt();
            dialog.dismiss();
            new PositionDialog(act, p, neu, bekannteMaterialien, cb).show();
            Toast.makeText(act, "Übernommen: " + a.text + (a.preis != null ? " (" + a.preisText() + ")" : ""), Toast.LENGTH_LONG).show();
        });
    }

    /** Übernimmt einen Händlerartikel in die Position (Art, Material, Maße, Preis, Artikelnummer). */
    static void anwenden(Position p, Datanorm.Artikel a) {
        String t = a.typ();
        p.typ = t;
        p.holzart = a.text;
        if (p.bezeichnung == null || p.bezeichnung.trim().isEmpty()) p.bezeichnung = a.text;
        switch (t) {
            case Position.PLATTE:
                p.laenge = a.l; p.breite = a.pb; p.hoehe = a.h;
                if (p.verschnitt == null) p.verschnitt = 10.0;
                break;
            case Position.HOLZ:
                p.breite = a.b; p.hoehe = a.h;
                if (a.l != null) p.laenge = a.l;
                break;
            case Position.LFM:
                p.breite = a.b; p.hoehe = a.h;
                break;
            default:
                p.einheit = a.einheit == null || a.einheit.isEmpty() ? "Stk" : a.einheit;
        }
        p.preis = a.preis;
        p.preisEinheit = a.einheit == null ? "" : a.einheit;
        p.artikelNr = a.nr;
    }

    /** Öffnet die Schnellauswahl gängiger / eigener Platten und übernimmt die Werte in die Felder. */
    private void plattenAuswahl() {
        Position akt = new Position();
        akt.typ = Position.PLATTE;
        lesePlatte(akt);
        PlattenAuswahl.Vorlage aktuell = PlattenAuswahl.neu(txt(eMat), txt(eBez), akt.laenge, akt.breite,
                akt.hoehe == null ? null : akt.hoehe * 10);
        PlattenAuswahl.zeigen(act, aktuell, v -> {
            eMat.setText(v.material);
            eMat.dismissDropDown();
            ePL.setText(v.laenge == null ? "" : Fmt.num(v.laenge * 100));
            ePB.setText(Fmt.num(v.breite));
            eDicke.setText(Fmt.num(v.dicke));
            if (txt(eBez).isEmpty() && v.bezeichnung != null) {
                eBez.setText(v.bezeichnung);
                eBez.dismissDropDown();
            }
            (eFlL.getText().length() == 0 && eFl.getText().length() == 0 ? eFlL : eVs).requestFocus();
        });
    }

    // ---------------------------------------------------------------- Anzeige

    private void setMehr(boolean offen) {
        groupMehr.setVisibility(offen ? View.VISIBLE : View.GONE);
        tMehr.setText((offen ? "▾  " : "▸  ") + "Weitere Angaben (Preis, Bemerkung" + (holzig() ? ", Fertigmaß)" : ")"));
    }

    private boolean holzig() {
        return Position.HOLZ.equals(typ) || Position.LFM.equals(typ);
    }

    private void updateTyp() {
        boolean titel = Position.TITEL.equals(typ);
        boolean platte = Position.PLATTE.equals(typ), material = Position.MATERIAL.equals(typ);
        tTyp.setText(Ui.symbol(typ) + "  " + Position.typName(typ) + "      ändern ▾");
        tTyp.setTextColor(Ui.farbe(typ));
        groupMasse.setVisibility(titel ? View.GONE : View.VISIBLE);
        rowStkL.setVisibility(Position.HOLZ.equals(typ) ? View.VISIBLE : View.GONE);
        rowLfm.setVisibility(Position.LFM.equals(typ) ? View.VISIBLE : View.GONE);
        groupQuer.setVisibility(holzig() ? View.VISIBLE : View.GONE);
        groupFertig.setVisibility(holzig() ? View.VISIBLE : View.GONE);
        groupPlatte.setVisibility(platte ? View.VISIBLE : View.GONE);
        groupMaterial.setVisibility(material ? View.VISIBLE : View.GONE);
        if (groupMehr != null) setMehr(groupMehr.getVisibility() == View.VISIBLE);

        tLabelBez.setText(titel ? "Überschrift (z. B. Dachstuhl, Dämmung, Decke EG)" : "Was? (Bezeichnung)");
        String[] bez = platte ? BEZ_PLATTE : material ? BEZ_MATERIAL : Position.LFM.equals(typ) ? BEZ_LFM : BEZ_HOLZ;
        eBez.setAdapter(new ArrayAdapter<>(act, android.R.layout.simple_dropdown_item_1line, bez));
        eBez.setHint(titel ? "z. B. Dachstuhl" : "z. B. " + bez[0]);

        tLabelMat.setText(platte ? "Plattenmaterial" : material ? "Produkt / Material" : "Holzart / Qualität");
        Set<String> ha = new LinkedHashSet<>(bekannteMaterialien);
        for (String s : platte ? PLATTEN : material ? MATERIALIEN : HOLZARTEN) ha.add(s);
        eMat.setAdapter(new ArrayAdapter<>(act, android.R.layout.simple_dropdown_item_1line, ha.toArray(new String[0])));
        eMat.setHint(platte ? "z. B. OSB/3" : material ? "z. B. Mineralwolle 140 mm" : "z. B. KVH NSi C24");
        updateErgebnis();
    }

    private void updateErgebnis() {
        if (tErgebnis == null || ePreisEinh == null) return;
        Position t = new Position();
        lesen(t);
        ePreisEinh.setHint(t.getPreisEinheit().isEmpty() ? "Einheit" : t.getPreisEinheit());
        StringBuilder e = new StringBuilder();
        switch (typ) {
            case Position.PLATTE: {
                double fl = t.getFlaeche(), vsp = t.verschnitt == null ? 0 : t.verschnitt;
                Double n = t.getPlattenAnzahl();
                e.append(Fmt.fix(fl, 2)).append(" m²");
                if (vsp != 0) e.append(" + ").append(Fmt.num(vsp)).append(" % = ").append(Fmt.fix(fl * (1 + vsp / 100), 2)).append(" m²");
                if (n != null) {
                    e.append("\n→ Du brauchst ").append(Fmt.fix(n, 0)).append(n == 1 ? " Platte" : " Platten");
                    e.append("\n(je ").append(Fmt.fix(t.getPlattenFlaecheEinzeln(), 3)).append(" m², zusammen ")
                            .append(Fmt.fix(t.getPlattenFlaecheGesamt(), 2)).append(" m²)");
                } else if (fl > 0) {
                    e.append("\nPlattengröße eingeben → Anzahl wird berechnet");
                } else {
                    e.append("\nFläche eingeben: Länge × Breite oder m²");
                }
                break;
            }
            case Position.MATERIAL: {
                Double bed = t.getBedarf();
                if (bed == null) { e.append("Menge eingeben"); break; }
                String einh = Einheit.norm(t.einheit);
                if (t.verschnitt != null && t.verschnitt != 0)
                    e.append(Fmt.mengeText(t.menge)).append(" ").append(einh).append(" + ").append(Fmt.num(t.verschnitt)).append(" % = ");
                e.append(Fmt.mengeText(bed)).append(" ").append(einh);
                Double pk = t.getPackungen();
                if (pk != null) e.append("\n→ Du brauchst ").append(Fmt.num(pk)).append(" ").append(t.packNameOderStandard())
                        .append(" à ").append(Fmt.mengeText(t.packInhalt)).append(" ").append(einh);
                break;
            }
            case Position.LFM:
                e.append("= ").append(Fmt.fix(t.getLaufmeterGesamt(), 2)).append(" m  ·  ").append(Fmt.fix(t.getVolumen(), 3)).append(" m³");
                break;
            default:
                e.append("= ").append(Fmt.fix(t.getLaufmeterGesamt(), 2)).append(" m  ·  ").append(Fmt.fix(t.getVolumen(), 3)).append(" m³");
        }
        if (t.preis != null) {
            Double b = t.getBetrag();
            e.append("\n").append(b != null ? "Preis: " + Fmt.euro(b)
                    : "Preis: Einheit „" + t.getPreisEinheit() + "“ passt nicht zur Menge");
        }
        tErgebnis.setText(e.toString());
    }

    // ---------------------------------------------------------------- Werte lesen

    /** Liest alle Felder der aktuellen Art in x (nicht passende Felder werden geleert). */
    private void lesen(Position x) {
        x.typ = typ;
        x.bezeichnung = txt(eBez);
        if (Position.TITEL.equals(typ)) return;
        x.holzart = txt(eMat);
        x.bemerkung = txt(eBem);
        x.artikelNr = txt(eArtNr);
        x.preis = Fmt.parse(ePreis.getText().toString());
        x.preisEinheit = txt(ePreisEinh);
        x.stueck = null; x.laenge = null; x.laufmeter = null; x.breite = null; x.hoehe = null;
        x.flaeche = null; x.flL = null; x.flB = null; x.verschnitt = null; x.fertigB = null; x.fertigH = null;
        x.menge = null; x.einheit = ""; x.packInhalt = null; x.packName = "";
        switch (typ) {
            case Position.HOLZ:
                x.stueck = Fmt.parse(eStk.getText().toString());
                x.laenge = Fmt.parse(eL.getText().toString());
                // fall through
            case Position.LFM:
                if (Position.LFM.equals(typ)) x.laufmeter = Fmt.parse(eLfm.getText().toString());
                x.breite = Fmt.parse(eB.getText().toString());
                x.hoehe = Fmt.parse(eH.getText().toString());
                x.fertigB = Fmt.parse(eFb.getText().toString());
                x.fertigH = Fmt.parse(eFh.getText().toString());
                break;
            case Position.PLATTE:
                lesePlatte(x);
                break;
            case Position.MATERIAL:
                x.menge = Fmt.parse(eMenge.getText().toString());
                x.einheit = txt(eEinh).isEmpty() ? "Stk" : Einheit.norm(txt(eEinh));
                x.verschnitt = Fmt.parse(eMatVs.getText().toString());
                x.packInhalt = Fmt.parse(ePack.getText().toString());
                x.packName = txt(ePackName);
                break;
        }
    }

    /** Plattenfelder (Länge cm → m, Breite cm, Dicke mm → cm, Fläche m²). */
    private void lesePlatte(Position x) {
        Double cm = Fmt.parse(ePL.getText().toString());
        x.laenge = cm == null ? null : cm / 100.0;
        x.breite = Fmt.parse(ePB.getText().toString());
        Double mm = Fmt.parse(eDicke.getText().toString());
        x.hoehe = mm == null ? null : mm / 10.0;
        x.flL = Fmt.parse(eFlL.getText().toString());
        x.flB = Fmt.parse(eFlB.getText().toString());
        x.flaeche = Fmt.parse(eFl.getText().toString());
        x.verschnitt = Fmt.parse(eVs.getText().toString());
        x.stueck = null; // wird aus Fläche + Verschnitt berechnet
    }

    private EditText[] zahlenFelder() {
        return new EditText[]{eStk, eL, eLfm, eB, eH, eFb, eFh, ePL, ePB, eDicke, eFl, eFlL, eFlB, eVs, eMenge, eMatVs, ePack, ePreis};
    }

    private boolean zahlenOk() {
        for (EditText e : zahlenFelder()) {
            String s = e.getText().toString().trim();
            if (!s.isEmpty() && Fmt.parse(s) == null) {
                if (e.getParent() != null) setMehr(groupMehr.getVisibility() == View.VISIBLE || e == ePreis);
                e.setError("Ungültige Zahl");
                e.requestFocus();
                return false;
            }
        }
        return true;
    }

    /** Neue Einträge (außer Überschriften) werden fortlaufend erfasst: „Weiter ›“ öffnet die nächste Eingabe. */
    private boolean fortlaufend() { return neu && !p.isTitel(); }

    /** true, wenn in der Eingabe noch nichts Wesentliches steht (vorbelegtes Material/Format zählt nicht). */
    private boolean eingabeLeer() {
        if (!txt(eBez).isEmpty()) return false;
        EditText[] felder;
        if (Position.PLATTE.equals(typ)) felder = new EditText[]{eFl, eFlL, eFlB};
        else if (Position.LFM.equals(typ)) felder = new EditText[]{eLfm, eB, eH};
        else if (Position.MATERIAL.equals(typ)) felder = new EditText[]{eMenge};
        else felder = new EditText[]{eStk, eL, eB, eH};
        for (EditText e : felder)
            if (e != null && !txt(e).isEmpty()) return false;
        return true;
    }

    private boolean uebernehmen() {
        String bez = txt(eBez);
        if (Position.TITEL.equals(typ) && bez.isEmpty()) {
            Toast.makeText(act, "Bitte eine Überschrift eingeben", Toast.LENGTH_SHORT).show();
            return false;
        }
        if (!zahlenOk()) return false;
        lesen(p);
        return true;
    }

    // ---------------------------------------------------------------- Layout-Helfer

    private static boolean leer(String s) { return s == null || s.trim().isEmpty(); }

    private static String txt(EditText e) { return e.getText().toString().trim(); }

    private Button button(String text, int textColor, int fill, int stroke) {
        Button b = new Button(act);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextSize(15);
        b.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        b.setTextColor(textColor);
        b.setBackground(Ui.rounded(fill, stroke, Ui.dp(act, 8), Ui.dp(act, 1)));
        return b;
    }

    private AutoCompleteTextView auto(String[] werte, String wert, String hint) {
        AutoCompleteTextView a = new AutoCompleteTextView(act);
        a.setAdapter(new ArrayAdapter<>(act, android.R.layout.simple_dropdown_item_1line, werte));
        a.setThreshold(0);
        a.setInputType(InputType.TYPE_CLASS_TEXT);
        a.setText(wert == null ? "" : wert);
        a.setHint(hint);
        a.setTextSize(17);
        a.setOnFocusChangeListener((v, has) -> { if (has) a.showDropDown(); });
        a.setOnClickListener(v -> a.showDropDown());
        return a;
    }

    private TextView label(String s) {
        TextView t = Ui.text(act, s, 13, Ui.GRAU, false);
        t.setPadding(Ui.dp(act, 4), Ui.dp(act, 12), 0, 0);
        return t;
    }

    private TextView section(String s) {
        TextView t = Ui.text(act, s, 14, Ui.PRIMAER, true);
        t.setPadding(Ui.dp(act, 4), Ui.dp(act, 16), 0, 0);
        return t;
    }

    private LinearLayout row() {
        LinearLayout l = new LinearLayout(act);
        l.setOrientation(LinearLayout.HORIZONTAL);
        return l;
    }

    private LinearLayout vertical() {
        LinearLayout l = new LinearLayout(act);
        l.setOrientation(LinearLayout.VERTICAL);
        return l;
    }

    private LinearLayout field(String label, EditText e) {
        LinearLayout l = vertical();
        l.addView(label(label));
        l.addView(e, full());
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
        lp.setMarginEnd(Ui.dp(act, 6));
        l.setLayoutParams(lp);
        return l;
    }

    private EditText num(String value, String hint) {
        EditText e = new EditText(act);
        Ui.decimalInput(e);
        e.setText(value);
        e.setHint(hint);
        e.setTextSize(18);
        e.setGravity(Gravity.END);
        return e;
    }

    private static LinearLayout.LayoutParams full() {
        return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    }
}
