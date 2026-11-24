package de.zimmerei.holzliste;

import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static de.zimmerei.holzliste.XlsxWriter.style;

/** Erstellt aus einer Materialliste eine formatierte Excel-Arbeitsmappe. */
public final class HolzlisteExcel {

    private HolzlisteExcel() {}

    // Farbpalette (ARGB)
    private static final String BRAUN = "FF5D4037";
    private static final String BRAUN_HELL = "FFD7CCC8";
    private static final String BEIGE = "FFEFEBE9";
    private static final String ZEBRA = "FFFAF7F5";
    private static final String WEISS = "FFFFFFFF";
    private static final String GRAU = "FF757575";
    private static final String SUMME = "FFFFF3E0";
    private static final String GESAMT = "FFFFE0B2";
    private static final String BLAU = "FF1565C0";

    // Spalten (A … S)
    static final int C_POS = 0, C_BEZ = 1, C_ART = 2, C_STK = 3, C_B = 4, C_H = 5, C_L = 6,
            C_LFM = 7, C_M2 = 8, C_VS = 9, C_M3 = 10, C_FB = 11, C_FH = 12, C_HOLZART = 13,
            C_MENGE = 14, C_EINH = 15, C_EP = 16, C_GP = 17, C_BEM = 18;
    static final int LAST_COL = C_BEM;

    // Spaltenbuchstaben für Formeln
    private static final String D = "D", E = "E", F = "F", G = "G", H = "H", I = "I", VS = "J", K = "K",
            O = "O", Q = "Q", RR = "R";
    private static final String GRUEN = "FF2E7D32";

    static final String ART_HOLZ = "Stk", ART_LFM = "lfm", ART_PLATTE = "Platte", ART_MAT = "Mat";
    static final String FMT_EUR = "#,##0.00 \"€\";-#,##0.00 \"€\";\"\"";
    static final String FMT_MENGE = "#,##0.##;-#,##0.##;\"\"";

    static final String FMT_L = "0.00";
    static final String FMT_LFM = "#,##0.00";
    static final String FMT_M2 = "#,##0.00";
    static final String FMT_M3 = "#,##0.000";
    static final String FMT_DIM = "0.##;-0.##;\"\"";   // 8 / 7,5 – ohne Nullen
    static final String FMT_STK = "#,##0;-#,##0;\"\"";

    public static void write(Holzliste h, OutputStream out) throws IOException {
        XlsxWriter wb = new XlsxWriter();
        wb.title = "Materialliste " + h.titel();
        wb.author = h.bearbeiter == null ? "" : h.bearbeiter;
        int[] dataRange = holzliste(wb, h);
        zusammenfassung(wb, h, dataRange[0], dataRange[1]);
        wb.write(out);
    }

    static String art(Position p) {
        return p.isPlatte() ? ART_PLATTE : p.isLfm() ? ART_LFM : p.isMaterial() ? ART_MAT : ART_HOLZ;
    }

    /** Materialname für Spalte N (bei sonstigem Material ersatzweise die Bezeichnung). */
    static String material(Position p) {
        String m = p.holzart == null ? "" : p.holzart.trim();
        if (m.isEmpty() && p.isMaterial()) m = p.bezeichnung == null ? "" : p.bezeichnung.trim();
        return m;
    }

    /** Menge + Einheit für die Spalten „Menge“/„Einheit“: in Preiseinheit, sonst Bestellmenge (Material). */
    static Object[] mengeEinheit(Position p) {
        if (p.preis != null) {
            Double m = p.getMengeIn(p.getPreisEinheit());
            if (m != null) return new Object[]{m, p.getPreisEinheit()};
        }
        if (p.isMaterial()) {
            Double pk = p.getPackungen();
            if (pk != null) return new Object[]{pk, p.packNameOderStandard()};
            return new Object[]{p.getBedarf(), Einheit.norm(p.einheit)};
        }
        return new Object[]{null, ""};
    }

    /** @return {erste Datenzeile, letzte Datenzeile} (0-basiert) */
    private static int[] holzliste(XlsxWriter wb, Holzliste h) {
        XlsxWriter.Sheet s = wb.addSheet("Materialliste");
        s.tabColor(BRAUN).hideGrid();

        // Spaltenbreiten (Zeichen)
        s.width(C_POS, 5.5).width(C_BEZ, 32).width(C_ART, 7).width(C_STK, 7)
                .width(C_B, 8).width(C_H, 11).width(C_L, 9).width(C_LFM, 11).width(C_M2, 11).width(C_VS, 10).width(C_M3, 11)
                .width(C_FB, 8).width(C_FH, 8).width(C_HOLZART, 24)
                .width(C_MENGE, 9).width(C_EINH, 8).width(C_EP, 10).width(C_GP, 12).width(C_BEM, 28);

        XlsxWriter.Style base = style();
        XlsxWriter.Style label = base.color(GRAU).size(9).align("right");
        XlsxWriter.Style value = base.bold().size(11).border(null);
        XlsxWriter.Style valueLine = value.bottomMedium().borderColor(BRAUN_HELL);

        // --- Titel
        s.set(0, C_POS, "MATERIALLISTE", base.bold().size(20).color(BRAUN));
        s.merge(0, C_POS, 0, C_ART + 2);
        s.height(0, 30);
        s.set(0, C_GP, "Erstellt mit Materialliste-App", base.italic().size(8).color(GRAU).align("right"));
        s.merge(0, C_GP, 0, C_BEM);

        // --- Kopfdaten (Label links, Wert rechts daneben)
        int r = 2;
        kopf(s, r, C_BEZ, "Projekt / Bauvorhaben", h.projekt, label, valueLine, C_ART, C_L);
        kopf(s, r, C_LFM, "Datum", h.datum, label, valueLine, C_M2, C_FH);
        r++;
        kopf(s, r, C_BEZ, "Kunde / Bauherr", h.kunde, label, valueLine, C_ART, C_L);
        kopf(s, r, C_LFM, "Bearbeiter", h.bearbeiter, label, valueLine, C_M2, C_FH);
        r++;
        kopf(s, r, C_BEZ, "Bauteil", h.bauteil, label, valueLine, C_ART, C_L);
        kopf(s, r, C_LFM, "Notiz", h.notiz, label, valueLine, C_M2, C_BEM);
        for (int i = 2; i <= 4; i++) s.height(i, 20);

        // --- Gruppenkopf
        r = 6;
        XlsxWriter.Style grp = base.bold().size(9).color(WEISS).fill(BRAUN).align("center")
                .border("thin").borderColor("FF8D6E63");
        gruppe(s, r, C_POS, C_STK, "Position", grp);
        gruppe(s, r, C_B, C_L, "Rohmaß", grp);
        gruppe(s, r, C_LFM, C_M3, "Menge", grp);
        gruppe(s, r, C_FB, C_FH, "Fertigmaß", grp);
        gruppe(s, r, C_HOLZART, C_HOLZART, "Material", grp);
        gruppe(s, r, C_MENGE, C_GP, "Bestellung & Preis", grp);
        gruppe(s, r, C_BEM, C_BEM, "", grp);
        s.height(r, 16);

        // --- Spaltenköpfe
        r = 7;
        XlsxWriter.Style head = base.bold().size(10).fill(BRAUN_HELL).align("center").wrap()
                .border("thin").borderColor("FFA1887F").bottomMedium();
        String[] heads = {"Pos.", "Bezeichnung", "Art", "Stück", "Breite\n[cm]", "Höhe/Dicke\n[cm]", "Länge\n[m]",
                "Laufmeter\n[m]", "Fläche\n[m²]", "Verschnitt\n[%]", "Volumen\n[m³]", "Breite\n[cm]", "Höhe\n[cm]", "Holzart / Material",
                "Menge", "Einheit", "Preis\n[€/Einh.]", "Betrag\n[€]", "Bemerkung"};
        for (int c = 0; c < heads.length; c++) s.set(r, c, heads[c], c == C_BEZ || c == C_HOLZART || c == C_BEM ? head.align("left") : head);
        s.height(r, 30);
        s.freeze(r + 1, C_BEZ + 1);
        s.printTitles(6, 7);

        // --- Daten
        int first = r + 1;
        r = first;
        XlsxWriter.Style cell = base.border("thin").borderColor("FFD0D0D0").size(10);
        XlsxWriter.Style cellZ = cell.fill(ZEBRA);
        XlsxWriter.Style titelSt = base.bold().size(11).color(BRAUN).fill(BEIGE)
                .border("thin").borderColor("FFBCAAA4");

        int zeile = 0;
        for (int i = 0; i < h.positionen.size(); i++) {
            Position p = h.positionen.get(i);
            int n = r + 1; // Excel-Zeilennummer
            if (p.isTitel()) {
                s.set(r, C_POS, null, titelSt);
                s.set(r, C_BEZ, p.bezeichnung.isEmpty() ? "Abschnitt" : p.bezeichnung, titelSt);
                for (int c = C_ART; c <= LAST_COL; c++) s.set(r, c, null, titelSt);
                s.merge(r, C_BEZ, r, LAST_COL);
                s.height(r, 20);
                r++;
                zeile = 0;
                continue;
            }
            XlsxWriter.Style c0 = (zeile++ % 2 == 1) ? cellZ : cell;
            XlsxWriter.Style ctr = c0.align("center");
            XlsxWriter.Style num = c0.align("right");

            s.set(r, C_POS, h.posNummer(i), ctr.color(GRAU));
            s.set(r, C_BEZ, p.bezeichnung, c0.bold());
            s.set(r, C_ART, art(p), ctr.color(GRAU).size(9));
            s.set(r, C_B, p.breite, num.fmt(FMT_DIM));
            s.set(r, C_H, p.hoehe, num.fmt(FMT_DIM));

            if (p.isMaterial()) {
                s.set(r, C_STK, null, ctr);
                s.set(r, C_L, null, num);
                s.set(r, C_LFM, null, num);
                s.set(r, C_M2, null, num);
                s.set(r, C_VS, p.verschnitt, num.fmt(FMT_DIM));
                s.set(r, C_M3, p.getVolumen() > 0 ? p.getVolumen() : null, num.fmt(FMT_M3).bold());
            } else if (p.isPlatte()) {
                s.set(r, C_L, p.laenge, num.fmt(FMT_L));
                s.set(r, C_LFM, null, num);
                Double anzahl = p.getPlattenAnzahl();
                if (p.hatFlaechenEingabe()) {
                    // zu belegende Fläche + Verschnitt → Plattenanzahl (aufgerundet)
                    s.set(r, C_M2, p.getFlaeche(), num.fmt(FMT_M2).bold());
                    s.set(r, C_VS, p.verschnitt, num.fmt(FMT_DIM));
                    s.formula(r, C_STK, "IF(OR(" + I + n + "=\"\"," + G + n + "=\"\"," + E + n + "=\"\"),\"\","
                                    + "ROUNDUP(" + I + n + "*(1+N(" + VS + n + ")/100)/(" + G + n + "*" + E + n + "/100)-0.000000001,0))",
                            anzahl, ctr.fmt(FMT_STK).bold().color(GRUEN));
                } else {
                    // ältere Einträge: Stückzahl direkt
                    s.set(r, C_STK, p.stueck, ctr.fmt(FMT_STK).bold());
                    s.formula(r, C_M2, "IF(AND(" + D + n + "=\"\"," + G + n + "=\"\"," + E + n + "=\"\"),\"\","
                                    + D + n + "*" + G + n + "*" + E + n + "/100)",
                            p.stueck == null ? null : p.getFlaeche(), num.fmt(FMT_M2).bold());
                    s.set(r, C_VS, null, num);
                }
                s.formula(r, C_M3, "IF(AND(N(" + D + n + ")>0," + G + n + "<>\"\"," + E + n + "<>\"\"),"
                                + D + n + "*" + G + n + "*" + E + n + "*" + F + n + "/10000,"
                                + "IF(" + I + n + "=\"\",\"\"," + I + n + "*(1+N(" + VS + n + ")/100)*" + F + n + "/100))",
                        p.getVolumen(), num.fmt(FMT_M3).bold());
            } else {
                if (p.isHolz()) {
                    s.set(r, C_STK, p.stueck, ctr.fmt(FMT_STK).bold());
                    s.set(r, C_L, p.laenge, num.fmt(FMT_L));
                    s.formula(r, C_LFM, "IF(AND(" + D + n + "=\"\"," + G + n + "=\"\"),\"\"," + D + n + "*" + G + n + ")",
                            p.stueck == null && p.laenge == null ? null : p.getLaufmeterGesamt(), num.fmt(FMT_LFM));
                } else {
                    s.set(r, C_STK, null, ctr);
                    s.set(r, C_L, null, num);
                    s.set(r, C_LFM, p.laufmeter, num.fmt(FMT_LFM).bold());
                }
                s.set(r, C_M2, null, num);
                s.set(r, C_VS, null, num);
                s.formula(r, C_M3, "IF(" + H + n + "=\"\",\"\"," + H + n + "*" + E + n + "*" + F + n + "/10000)",
                        p.getLaufmeterGesamt() == 0 && p.laufmeter == null && p.stueck == null ? null : p.getVolumen(),
                        num.fmt(FMT_M3).bold());
            }
            s.set(r, C_FB, p.fertigB, num.fmt(FMT_DIM).color(BLAU));
            s.set(r, C_FH, p.fertigH, num.fmt(FMT_DIM).color(BLAU));
            s.set(r, C_HOLZART, material(p), c0);
            Object[] me = mengeEinheit(p);
            s.set(r, C_MENGE, (Double) me[0], num.fmt(FMT_MENGE).bold());
            s.set(r, C_EINH, (String) me[1], c0.align("center"));
            s.set(r, C_EP, p.preis, num.fmt(FMT_EUR));
            s.formula(r, C_GP, "IF(OR(" + O + n + "=\"\"," + Q + n + "=\"\"),\"\"," + O + n + "*" + Q + n + ")",
                    p.getBetrag(), num.fmt(FMT_EUR).bold());
            String bem = p.bemerkung == null ? "" : p.bemerkung;
            if (p.isPlatte() && p.flL != null && p.flB != null)
                bem = "Fläche " + Fmt.num(p.flL) + " × " + Fmt.num(p.flB) + " m" + (bem.isEmpty() ? "" : "; " + bem);
            if (p.isMaterial() && p.hatPackung() && !p.packNameOderStandard().equals(me[1]))
                bem = p.bestellText() + " à " + Fmt.mengeText(p.packInhalt) + " " + Einheit.norm(p.einheit) + (bem.isEmpty() ? "" : "; " + bem);
            if (p.artikelNr != null && !p.artikelNr.isEmpty() && !bem.contains(p.artikelNr))
                bem = (bem.isEmpty() ? "" : bem + "; ") + "Art.-Nr. " + p.artikelNr;
            s.set(r, C_BEM, bem, c0.wrap().size(9));
            s.height(r, 18);
            r++;
        }
        if (r == first) { // leere Liste: eine leere Zeile mit Rahmen
            for (int c = 0; c <= LAST_COL; c++) s.set(r, c, null, cell);
            r++;
        }
        int last = r - 1;
        s.autoFilter(first - 1, C_POS, last, LAST_COL);

        // --- Summen
        int a = first + 1, b = last + 1;
        String art = "$C$" + a + ":$C$" + b;
        String stk = D + a + ":" + D + b;
        String lfm = H + a + ":" + H + b;
        String m2 = I + a + ":" + I + b;
        String m3 = K + a + ":" + K + b;
        String gp = RR + a + ":" + RR + b;

        XlsxWriter.Style sumLbl = base.bold().fill(SUMME).border("thin").borderColor("FFFFCC80");
        XlsxWriter.Style sumNum = sumLbl.align("right");
        r++;
        summe(s, r, "Summe Stückhölzer", sumLbl, sumNum,
                sumif(art, ART_HOLZ, stk), h.summeStueck(Position.HOLZ),
                sumif(art, ART_HOLZ, lfm), h.summeLaufmeter(Position.HOLZ),
                null, null,
                sumif(art, ART_HOLZ, m3), h.summeVolumen(Position.HOLZ),
                sumif(art, ART_HOLZ, gp), summeBetrag(h, Position.HOLZ));
        r++;
        summe(s, r, "Summe Laufmeterhölzer", sumLbl, sumNum,
                null, null,
                sumif(art, ART_LFM, lfm), h.summeLaufmeter(Position.LFM),
                null, null,
                sumif(art, ART_LFM, m3), h.summeVolumen(Position.LFM),
                sumif(art, ART_LFM, gp), summeBetrag(h, Position.LFM));
        if (h.hatPlatten()) {
            r++;
            summe(s, r, "Summe Plattenwerkstoffe", sumLbl, sumNum,
                    sumif(art, ART_PLATTE, stk), h.summeStueck(Position.PLATTE),
                    null, null,
                    sumif(art, ART_PLATTE, m2), h.summeFlaeche(),
                    sumif(art, ART_PLATTE, m3), h.summeVolumen(Position.PLATTE),
                    sumif(art, ART_PLATTE, gp), summeBetrag(h, Position.PLATTE));
        }
        if (h.hatTyp(Position.MATERIAL)) {
            r++;
            summe(s, r, "Summe sonstiges Material", sumLbl, sumNum,
                    null, null, null, null, null, null,
                    sumif(art, ART_MAT, m3), h.summeVolumen(Position.MATERIAL),
                    sumif(art, ART_MAT, gp), summeBetrag(h, Position.MATERIAL));
        }
        r++;
        XlsxWriter.Style gLbl = base.bold().size(11).fill(GESAMT).border("thin").borderColor("FFFFB74D")
                .topMedium().bottomMedium();
        summe(s, r, "GESAMT", gLbl, gLbl.align("right"),
                "SUM(" + stk + ")", h.summeStueck(null),
                "SUM(" + lfm + ")", h.summeLaufmeter(null),
                h.hatPlatten() ? "SUM(" + m2 + ")" : null, h.hatPlatten() ? h.summeFlaeche() : null,
                "SUM(" + m3 + ")", h.summeVolumen(null),
                "SUM(" + gp + ")", h.summeBetrag());
        s.height(r, 22);
        r += 2;
        s.set(r, C_POS, "Hinweis: Volumen nach Rohmaß (Breite × Höhe × Laufmeter); Platten: Plattenanzahl = "
                        + "Fläche × (1 + Verschnitt) ÷ Plattenformat, aufgerundet; Betrag = Menge × Preis (netto, laut Händler). Fertigmaße in Blau.",
                base.italic().size(8).color(GRAU));

        s.headerFooter("&\"Calibri,Fett\"Materialliste – " + h.titel(),
                "&8" + (h.kunde == null ? "" : h.kunde) + "  " + (h.datum == null ? "" : h.datum),
                "&8Seite &P von &N");
        return new int[]{first, last};
    }

    private static String sumif(String artRange, String art, String range) {
        return "SUMIF(" + artRange + ",\"" + art + "\"," + range + ")";
    }

    private static void kopf(XlsxWriter.Sheet s, int r, int cLabel, String label, String val,
                             XlsxWriter.Style lSt, XlsxWriter.Style vSt, int c1, int c2) {
        s.set(r, cLabel, label + "  ", lSt);
        s.set(r, c1, val == null ? "" : val, vSt);
        for (int c = c1 + 1; c <= c2; c++) s.set(r, c, null, vSt);
        if (c2 > c1) s.merge(r, c1, r, c2);
    }

    private static void gruppe(XlsxWriter.Sheet s, int r, int c1, int c2, String text, XlsxWriter.Style st) {
        s.set(r, c1, text, st);
        for (int c = c1 + 1; c <= c2; c++) s.set(r, c, null, st);
        if (c2 > c1) s.merge(r, c1, r, c2);
    }

    private static void summe(XlsxWriter.Sheet s, int r, String text, XlsxWriter.Style lbl, XlsxWriter.Style num,
                              String fStk, Double vStk, String fLfm, Double vLfm,
                              String fM2, Double vM2, String fM3, Double vM3, String fGp, Double vGp) {
        for (int c = 0; c <= LAST_COL; c++) s.set(r, c, null, lbl);
        s.set(r, C_BEZ, text, lbl);
        if (fStk != null) s.formula(r, C_STK, fStk, vStk, num.align("center").fmt("#,##0"));
        if (fLfm != null) s.formula(r, C_LFM, fLfm, vLfm, num.fmt(FMT_LFM));
        if (fM2 != null) s.formula(r, C_M2, fM2, vM2, num.fmt(FMT_M2));
        s.formula(r, C_M3, fM3, vM3, num.fmt(FMT_M3));
        if (fGp != null) s.formula(r, C_GP, fGp, vGp, num.fmt(FMT_EUR));
    }

    static double summeBetrag(Holzliste h, String typ) {
        double s = 0;
        for (Position p : h.positionen) {
            Double b = typ.equals(p.typ) ? p.getBetrag() : null;
            if (b != null) s += b;
        }
        return s;
    }

    // ------------------------------------------------------------ Zusammenfassung

    /** Bezeichnung des Formats für die Bestellübersicht. */
    static String format(Position p) {
        if (!p.isPlatte()) return Fmt.querschnitt(p.breite, p.hoehe) + " cm";
        String dicke = p.hoehe == null ? "" : Fmt.num(p.hoehe * 10) + " mm";
        if (p.laenge == null && p.breite == null) return dicke.isEmpty() ? "Platte" : dicke;
        String fmt = (p.laenge == null ? "–" : Fmt.num(p.laenge * 100)) + " × "
                + (p.breite == null ? "–" : Fmt.num(p.breite)) + " cm";
        return dicke.isEmpty() ? fmt : fmt + " · " + dicke;
    }

    private static void zusammenfassung(XlsxWriter wb, Holzliste h, int first, int last) {
        XlsxWriter.Sheet s = wb.addSheet("Bestellübersicht");
        s.tabColor("FFF9A825").hideGrid();
        s.width(0, 30).width(1, 20).width(2, 9).width(3, 12).width(4, 12).width(5, 12)
                .width(6, 10).width(7, 9).width(8, 13);

        XlsxWriter.Style base = style();
        s.set(0, 0, "BESTELLÜBERSICHT", base.bold().size(18).color(BRAUN));
        s.merge(0, 0, 0, 8);
        s.height(0, 28);
        s.set(1, 0, h.titel() + (h.datum == null || h.datum.isEmpty() ? "" : "  ·  " + h.datum),
                base.size(10).color(GRAU));
        s.merge(1, 0, 1, 8);

        XlsxWriter.Style head = base.bold().color(WEISS).fill(BRAUN).align("center").border("thin").borderColor("FF8D6E63");
        int r = 3;
        String[] heads = {"Material", "Querschnitt /\nFormat", "Stück", "Laufmeter\n[m]", "Fläche\n[m²]", "Volumen\n[m³]",
                "Menge", "Einheit", "Betrag\n[€]"};
        for (int c = 0; c < heads.length; c++) s.set(r, c, heads[c], c == 0 ? head.align("left").wrap() : head.wrap());
        s.height(r, 30);
        s.freeze(r + 1, 0);

        // Gruppieren: Hölzer nach Holzart + Querschnitt, Platten nach Material + Format + Dicke,
        // sonstiges Material nach Material + Einheit
        Map<String, List<Position>> gruppen = new LinkedHashMap<>();
        for (Position p : h.positionen) {
            if (p.isTitel()) continue;
            String key = p.isMaterial() ? "M\u0000" + norm(material(p)) + "\u0000" + mengeEinheit(p)[1]
                    : (p.isPlatte() ? "P" + Fmt.num(p.laenge) : "H")
                    + "\u0000" + norm(p.holzart) + "\u0000" + Fmt.num(p.breite) + "\u0000" + Fmt.num(p.hoehe);
            List<Position> l = gruppen.get(key);
            if (l == null) { l = new ArrayList<>(); gruppen.put(key, l); }
            l.add(p);
        }

        String sh = "Materialliste!";
        int a = first + 1, b = last + 1;
        String colC = col(sh, "C", a, b), colN = col(sh, "N", a, b), colE = col(sh, "E", a, b), colF = col(sh, "F", a, b);
        String colG = col(sh, "G", a, b), colD = col(sh, "D", a, b), colH = col(sh, "H", a, b);
        String colI = col(sh, "I", a, b), colK = col(sh, "K", a, b);
        String colO = col(sh, "O", a, b), colP = col(sh, "P", a, b), colR = col(sh, "R", a, b);

        XlsxWriter.Style cell = base.border("thin").borderColor("FFD0D0D0");
        int start = ++r;
        int z = 0;
        for (List<Position> l : gruppen.values()) {
            Position p0 = l.get(0);
            double stk = 0, lfm = 0, m2 = 0, m3 = 0, menge = 0, betrag = 0;
            for (Position p : l) {
                Double n = p.isPlatte() ? p.getPlattenAnzahl() : (p.isHolz() ? p.stueck : null);
                if (n != null) stk += n;
                lfm += p.getLaufmeterGesamt();
                m2 += p.getFlaeche();
                m3 += p.getVolumen();
                Object[] me = mengeEinheit(p);
                if (me[0] != null) menge += (Double) me[0];
                if (p.getBetrag() != null) betrag += p.getBetrag();
            }
            XlsxWriter.Style c0 = (z++ % 2 == 1) ? cell.fill(ZEBRA) : cell;
            String ha = norm(material(p0));
            StringBuilder crit = new StringBuilder();
            crit.append(colN).append(",\"").append(ha.isEmpty() ? "=" : ha.replace("\"", "\"\"")).append('"');
            if (p0.isMaterial()) {
                crit.append(',').append(colC).append(",\"").append(ART_MAT).append('"');
                String e = (String) mengeEinheit(p0)[1];
                crit.append(',').append(colP).append(",\"").append(e.isEmpty() ? "=" : e.replace("\"", "\"\"")).append('"');
            } else {
                if (p0.isPlatte()) crit.append(',').append(colC).append(",\"").append(ART_PLATTE).append('"');
                else crit.append(',').append(colC).append(",\"<>").append(ART_PLATTE).append('"')
                        .append(',').append(colC).append(",\"<>").append(ART_MAT).append('"');
                crit.append(',').append(colE).append(',').append(numCrit(p0.breite));
                crit.append(',').append(colF).append(',').append(numCrit(p0.hoehe));
                if (p0.isPlatte()) crit.append(',').append(colG).append(',').append(numCrit(p0.laenge));
            }
            String c = crit.toString();

            s.set(r, 0, ha.isEmpty() ? (p0.isPlatte() ? "Platte (ohne Angabe)" : "(ohne Angabe)") : ha, c0.bold());
            s.set(r, 1, p0.isMaterial() ? "" : format(p0), c0.align("center"));
            if (p0.isMaterial()) {
                for (int k = 2; k <= 4; k++) s.set(r, k, null, c0);
                s.formula(r, 5, "SUMIFS(" + colK + "," + c + ")", m3, c0.align("right").fmt(FMT_M3 + ";-" + FMT_M3 + ";\"\"").bold());
                s.formula(r, 6, "SUMIFS(" + colO + "," + c + ")", menge, c0.align("right").fmt(FMT_MENGE).bold());
                s.set(r, 7, (String) mengeEinheit(p0)[1], c0.align("center"));
            } else {
                s.formula(r, 2, "SUMIFS(" + colD + "," + c + ")", stk, c0.align("center").fmt(FMT_STK));
                s.formula(r, 3, "SUMIFS(" + colH + "," + c + ")", lfm, c0.align("right").fmt(FMT_LFM + ";-" + FMT_LFM + ";\"\""));
                s.formula(r, 4, "SUMIFS(" + colI + "," + c + ")", m2, c0.align("right").fmt(FMT_M2 + ";-" + FMT_M2 + ";\"\""));
                s.formula(r, 5, "SUMIFS(" + colK + "," + c + ")", m3, c0.align("right").fmt(FMT_M3).bold());
                s.set(r, 6, null, c0);
                s.set(r, 7, null, c0);
            }
            s.formula(r, 8, "SUMIFS(" + colR + "," + c + ")", betrag, c0.align("right").fmt(FMT_EUR).bold());
            r++;
        }
        if (r == start) { for (int c = 0; c < 9; c++) s.set(r, c, null, cell); r++; }
        int end = r - 1;
        XlsxWriter.Style g = base.bold().size(11).fill(GESAMT).border("thin").borderColor("FFFFB74D").topMedium().bottomMedium();
        s.set(r, 0, "GESAMT", g);
        s.set(r, 1, null, g);
        s.formula(r, 2, "SUM(C" + (start + 1) + ":C" + (end + 1) + ")", h.summeStueck(null), g.align("center").fmt("#,##0"));
        s.formula(r, 3, "SUM(D" + (start + 1) + ":D" + (end + 1) + ")", h.summeLaufmeter(null), g.align("right").fmt(FMT_LFM));
        s.formula(r, 4, "SUM(E" + (start + 1) + ":E" + (end + 1) + ")", h.summeFlaeche(), g.align("right").fmt(FMT_M2));
        s.formula(r, 5, "SUM(F" + (start + 1) + ":F" + (end + 1) + ")", h.summeVolumen(null), g.align("right").fmt(FMT_M3));
        s.set(r, 6, null, g);
        s.set(r, 7, null, g);
        s.formula(r, 8, "SUM(I" + (start + 1) + ":I" + (end + 1) + ")", h.summeBetrag(), g.align("right").fmt(FMT_EUR));
        s.height(r, 22);
        s.set(r + 2, 0, "Beträge netto laut Händler-Artikelliste (DATANORM), nur Positionen mit Preis.",
                base.italic().size(8).color(GRAU));
        s.headerFooter(null, "&8Materialliste – " + h.titel(), "&8Seite &P von &N");
    }

    private static String col(String sheet, String c, int a, int b) {
        return sheet + "$" + c + "$" + a + ":$" + c + "$" + b;
    }

    private static String numCrit(Double d) {
        return d == null ? "\"=\"" : num(d);
    }

    private static String norm(String s) { return s == null ? "" : s.trim(); }

    private static String num(double d) {
        if (d == Math.rint(d)) return Long.toString((long) d);
        return Double.toString(d);
    }
}
