package de.zimmerei.holzliste;

import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static de.zimmerei.holzliste.XlsxWriter.ref;
import static de.zimmerei.holzliste.XlsxWriter.style;

/** Erstellt aus einer Holzliste eine formatierte Excel-Arbeitsmappe. */
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

    // Spalten
    static final int C_POS = 0, C_BEZ = 1, C_ART = 2, C_STK = 3, C_B = 4, C_H = 5, C_L = 6,
            C_LFM = 7, C_M3 = 8, C_FB = 9, C_FH = 10, C_HOLZART = 11, C_BEM = 12;
    static final int LAST_COL = C_BEM;

    static final String FMT_L = "0.00";
    static final String FMT_LFM = "#,##0.00";
    static final String FMT_M3 = "#,##0.000";
    static final String FMT_DIM = "0.##;-0.##;\"\"";   // 8 / 7,5 – ohne Nullen
    static final String FMT_STK = "#,##0;-#,##0;\"\"";

    public static void write(Holzliste h, OutputStream out) throws IOException {
        XlsxWriter wb = new XlsxWriter();
        wb.title = "Holzliste " + h.titel();
        wb.author = h.bearbeiter == null ? "" : h.bearbeiter;
        int[] dataRange = holzliste(wb, h);
        zusammenfassung(wb, h, dataRange[0], dataRange[1]);
        wb.write(out);
    }

    /** @return {erste Datenzeile, letzte Datenzeile} (0-basiert) */
    private static int[] holzliste(XlsxWriter wb, Holzliste h) {
        XlsxWriter.Sheet s = wb.addSheet("Holzliste");
        s.tabColor(BRAUN).hideGrid();

        // Spaltenbreiten (Zeichen)
        s.width(C_POS, 5.5).width(C_BEZ, 34).width(C_ART, 7).width(C_STK, 7)
                .width(C_B, 8).width(C_H, 8).width(C_L, 9).width(C_LFM, 11).width(C_M3, 11)
                .width(C_FB, 8).width(C_FH, 8).width(C_HOLZART, 22).width(C_BEM, 30);

        XlsxWriter.Style base = style();
        XlsxWriter.Style label = base.color(GRAU).size(9).align("right");
        XlsxWriter.Style value = base.bold().size(11).border(null);
        XlsxWriter.Style valueLine = value.bottomMedium().borderColor(BRAUN_HELL);

        // --- Titel
        s.set(0, C_POS, "HOLZLISTE", base.bold().size(20).color(BRAUN));
        s.merge(0, C_POS, 0, C_ART + 2);
        s.height(0, 30);
        s.set(0, C_HOLZART, "Erstellt mit Holzliste-App", base.italic().size(8).color(GRAU).align("right"));
        s.merge(0, C_HOLZART, 0, C_BEM);

        // --- Kopfdaten (Label links, Wert rechts daneben)
        int r = 2;
        kopf(s, r, C_BEZ, "Projekt / Bauvorhaben", h.projekt, label, valueLine, C_ART, C_L);
        kopf(s, r, C_LFM, "Datum", h.datum, label, valueLine, C_M3, C_FH);
        r++;
        kopf(s, r, C_BEZ, "Kunde / Bauherr", h.kunde, label, valueLine, C_ART, C_L);
        kopf(s, r, C_LFM, "Bearbeiter", h.bearbeiter, label, valueLine, C_M3, C_FH);
        r++;
        kopf(s, r, C_BEZ, "Bauteil", h.bauteil, label, valueLine, C_ART, C_L);
        kopf(s, r, C_LFM, "Notiz", h.notiz, label, valueLine, C_M3, C_BEM);
        for (int i = 2; i <= 4; i++) s.height(i, 20);

        // --- Gruppenkopf
        r = 6;
        XlsxWriter.Style grp = base.bold().size(9).color(WEISS).fill(BRAUN).align("center")
                .border("thin").borderColor("FF8D6E63");
        gruppe(s, r, C_POS, C_STK, "Position", grp);
        gruppe(s, r, C_B, C_L, "Rohmaß", grp);
        gruppe(s, r, C_LFM, C_M3, "Menge", grp);
        gruppe(s, r, C_FB, C_FH, "Fertigmaß", grp);
        gruppe(s, r, C_HOLZART, C_BEM, "Angaben", grp);
        s.height(r, 16);

        // --- Spaltenköpfe
        r = 7;
        XlsxWriter.Style head = base.bold().size(10).fill(BRAUN_HELL).align("center").wrap()
                .border("thin").borderColor("FFA1887F").bottomMedium();
        String[] heads = {"Pos.", "Bezeichnung", "Art", "Stück", "Breite\n[cm]", "Höhe\n[cm]", "Länge\n[m]",
                "Laufmeter\n[m]", "Volumen\n[m³]", "Breite\n[cm]", "Höhe\n[cm]", "Holzart / Qualität", "Bemerkung"};
        for (int c = 0; c < heads.length; c++) s.set(r, c, heads[c], c == C_BEZ || c >= C_HOLZART ? head.align("left") : head);
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
            s.set(r, C_ART, p.isLfm() ? "lfm" : "Stk", ctr.color(GRAU).size(9));
            s.set(r, C_B, p.breite, num.fmt(FMT_DIM));
            s.set(r, C_H, p.hoehe, num.fmt(FMT_DIM));
            if (p.isHolz()) {
                s.set(r, C_STK, p.stueck, ctr.fmt(FMT_STK).bold());
                s.set(r, C_L, p.laenge, num.fmt(FMT_L));
                s.formula(r, C_LFM, "IF(AND(D" + n + "=\"\",G" + n + "=\"\"),\"\",D" + n + "*G" + n + ")",
                        p.stueck == null && p.laenge == null ? null : p.getLaufmeterGesamt(), num.fmt(FMT_LFM));
            } else {
                s.set(r, C_STK, null, ctr);
                s.set(r, C_L, null, num);
                s.set(r, C_LFM, p.laufmeter, num.fmt(FMT_LFM).bold());
            }
            s.formula(r, C_M3, "IF(H" + n + "=\"\",\"\",H" + n + "*E" + n + "*F" + n + "/10000)",
                    p.getLaufmeterGesamt() == 0 && p.laufmeter == null && p.stueck == null ? null : p.getVolumen(),
                    num.fmt(FMT_M3).bold());
            s.set(r, C_FB, p.fertigB, num.fmt(FMT_DIM).color("FF1565C0"));
            s.set(r, C_FH, p.fertigH, num.fmt(FMT_DIM).color("FF1565C0"));
            s.set(r, C_HOLZART, p.holzart, c0);
            s.set(r, C_BEM, p.bemerkung, c0.wrap().size(9));
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
        String rng = "$" + (first + 1) + ":$" + (last + 1);
        String art = "$C$" + (first + 1) + ":$C$" + (last + 1);
        String stk = "D" + (first + 1) + ":D" + (last + 1);
        String lfm = "H" + (first + 1) + ":H" + (last + 1);
        String m3 = "I" + (first + 1) + ":I" + (last + 1);

        XlsxWriter.Style sumLbl = base.bold().fill(SUMME).border("thin").borderColor("FFFFCC80");
        XlsxWriter.Style sumNum = sumLbl.align("right");
        r++;
        summe(s, r, "Summe Stückhölzer", sumLbl, sumNum,
                "SUMIF(" + art + ",\"Stk\"," + stk + ")", h.summeStueck(),
                "SUMIF(" + art + ",\"Stk\"," + lfm + ")", h.summeLaufmeter(Position.HOLZ),
                "SUMIF(" + art + ",\"Stk\"," + m3 + ")", h.summeVolumen(Position.HOLZ));
        r++;
        summe(s, r, "Summe Laufmeterhölzer", sumLbl, sumNum, null, null,
                "SUMIF(" + art + ",\"lfm\"," + lfm + ")", h.summeLaufmeter(Position.LFM),
                "SUMIF(" + art + ",\"lfm\"," + m3 + ")", h.summeVolumen(Position.LFM));
        r++;
        XlsxWriter.Style gLbl = base.bold().size(11).fill(GESAMT).border("thin").borderColor("FFFFB74D")
                .topMedium().bottomMedium();
        summe(s, r, "GESAMT", gLbl, gLbl.align("right"),
                "SUM(" + stk + ")", h.summeStueck(),
                "SUM(" + lfm + ")", h.summeLaufmeter(null),
                "SUM(" + m3 + ")", h.summeVolumen(null));
        s.height(r, 22);
        r += 2;
        s.set(r, C_POS, "Hinweis: Volumen nach Rohmaß (Breite × Höhe × Laufmeter). Fertigmaße in Blau.",
                base.italic().size(8).color(GRAU));

        s.headerFooter("&\"Calibri,Fett\"Holzliste – " + h.titel(),
                "&8" + (h.kunde == null ? "" : h.kunde) + "  " + (h.datum == null ? "" : h.datum),
                "&8Seite &P von &N");
        return new int[]{first, last};
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
                              String fStk, Double vStk, String fLfm, Double vLfm, String fM3, Double vM3) {
        for (int c = 0; c <= LAST_COL; c++) s.set(r, c, null, lbl);
        s.set(r, C_BEZ, text, lbl);
        if (fStk != null) s.formula(r, C_STK, fStk, vStk, num.align("center").fmt("#,##0"));
        s.formula(r, C_LFM, fLfm, vLfm, num.fmt(FMT_LFM));
        s.formula(r, C_M3, fM3, vM3, num.fmt(FMT_M3));
    }

    // ------------------------------------------------------------ Zusammenfassung

    private static void zusammenfassung(XlsxWriter wb, Holzliste h, int first, int last) {
        XlsxWriter.Sheet s = wb.addSheet("Zusammenfassung");
        s.tabColor("FFF9A825").hideGrid().portrait();
        s.width(0, 24).width(1, 14).width(2, 10).width(3, 13).width(4, 13);

        XlsxWriter.Style base = style();
        s.set(0, 0, "BESTELLÜBERSICHT", base.bold().size(18).color(BRAUN));
        s.merge(0, 0, 0, 4);
        s.height(0, 28);
        s.set(1, 0, h.titel() + (h.datum == null || h.datum.isEmpty() ? "" : "  ·  " + h.datum),
                base.size(10).color(GRAU));
        s.merge(1, 0, 1, 4);

        XlsxWriter.Style head = base.bold().color(WEISS).fill(BRAUN).align("center").border("thin").borderColor("FF8D6E63");
        int r = 3;
        String[] heads = {"Holzart / Qualität", "Querschnitt\nB/H [cm]", "Stück", "Laufmeter\n[m]", "Volumen\n[m³]"};
        for (int c = 0; c < heads.length; c++) s.set(r, c, heads[c], c == 0 ? head.align("left").wrap() : head.wrap());
        s.height(r, 30);
        s.freeze(r + 1, 0);

        // Gruppieren nach Holzart + Querschnitt
        Map<String, List<Position>> gruppen = new LinkedHashMap<>();
        for (Position p : h.positionen) {
            if (p.isTitel()) continue;
            String key = norm(p.holzart) + "\u0000" + Fmt.num(p.breite) + "\u0000" + Fmt.num(p.hoehe);
            List<Position> l = gruppen.get(key);
            if (l == null) { l = new ArrayList<>(); gruppen.put(key, l); }
            l.add(p);
        }

        String sh = "Holzliste!";
        int a = first + 1, b = last + 1;
        String colL = sh + "$L$" + a + ":$L$" + b, colE = sh + "$E$" + a + ":$E$" + b, colF = sh + "$F$" + a + ":$F$" + b;
        String colD = sh + "$D$" + a + ":$D$" + b, colH = sh + "$H$" + a + ":$H$" + b, colI = sh + "$I$" + a + ":$I$" + b;

        XlsxWriter.Style cell = base.border("thin").borderColor("FFD0D0D0");
        int start = ++r;
        int z = 0;
        for (List<Position> l : gruppen.values()) {
            Position p0 = l.get(0);
            double stk = 0, lfm = 0, m3 = 0;
            for (Position p : l) {
                if (p.isHolz() && p.stueck != null) stk += p.stueck;
                lfm += p.getLaufmeterGesamt();
                m3 += p.getVolumen();
            }
            XlsxWriter.Style c0 = (z++ % 2 == 1) ? cell.fill(ZEBRA) : cell;
            String ha = norm(p0.holzart);
            String crit = "(" + colL + ",\"" + (ha.isEmpty() ? "=" : ha.replace("\"", "\"\"")) + "\","
                    + colE + "," + (p0.breite == null ? "\"=\"" : num(p0.breite)) + ","
                    + colF + "," + (p0.hoehe == null ? "\"=\"" : num(p0.hoehe)) + ")";
            s.set(r, 0, ha.isEmpty() ? "(ohne Angabe)" : ha, c0.bold());
            s.set(r, 1, Fmt.querschnitt(p0.breite, p0.hoehe), c0.align("center"));
            s.formula(r, 2, "SUMIFS(" + colD + "," + crit.substring(1), stk, c0.align("center").fmt(FMT_STK));
            s.formula(r, 3, "SUMIFS(" + colH + "," + crit.substring(1), lfm, c0.align("right").fmt(FMT_LFM));
            s.formula(r, 4, "SUMIFS(" + colI + "," + crit.substring(1), m3, c0.align("right").fmt(FMT_M3).bold());
            r++;
        }
        if (r == start) { for (int c = 0; c < 5; c++) s.set(r, c, null, cell); r++; }
        int end = r - 1;
        XlsxWriter.Style g = base.bold().size(11).fill(GESAMT).border("thin").borderColor("FFFFB74D").topMedium().bottomMedium();
        s.set(r, 0, "GESAMT", g);
        s.set(r, 1, null, g);
        s.formula(r, 2, "SUM(C" + (start + 1) + ":C" + (end + 1) + ")", h.summeStueck(), g.align("center").fmt("#,##0"));
        s.formula(r, 3, "SUM(D" + (start + 1) + ":D" + (end + 1) + ")", h.summeLaufmeter(null), g.align("right").fmt(FMT_LFM));
        s.formula(r, 4, "SUM(E" + (start + 1) + ":E" + (end + 1) + ")", h.summeVolumen(null), g.align("right").fmt(FMT_M3));
        s.height(r, 22);
        s.headerFooter(null, "&8Holzliste – " + h.titel(), "&8Seite &P von &N");
    }

    private static String norm(String s) { return s == null ? "" : s.trim(); }

    private static String num(double d) {
        if (d == Math.rint(d)) return Long.toString((long) d);
        return Double.toString(d);
    }
}
