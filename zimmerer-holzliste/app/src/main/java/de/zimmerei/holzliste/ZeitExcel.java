package de.zimmerei.holzliste;

import java.io.IOException;
import java.io.OutputStream;
import java.util.List;
import java.util.Map;

import static de.zimmerei.holzliste.XlsxWriter.style;

/** Stundenzettel als Excel: Blatt „Stunden“ (jede Buchung) und „Summen“ (je Tag, Baustelle, Tätigkeit). */
public final class ZeitExcel {

    private ZeitExcel() {}

    private static final String BLAU = "FF1E4E79";
    private static final String HELL = "FFE8F0F7";
    private static final String ZEBRA = "FFF8FAFB";
    private static final String SUMME = "FFFFF3E0";
    private static final String FMT_H = "0.00";

    public static void write(List<Zeiteintrag> eintraege, String zeitraum, String mitarbeiter, long jetzt,
                             OutputStream out) throws IOException {
        XlsxWriter wb = new XlsxWriter();
        wb.title = "Stundenzettel " + zeitraum;
        wb.author = mitarbeiter == null ? "" : mitarbeiter;
        stunden(wb, eintraege, zeitraum, mitarbeiter, jetzt);
        summen(wb, eintraege, zeitraum, mitarbeiter, jetzt);
        wb.write(out);
    }

    private static void stunden(XlsxWriter wb, List<Zeiteintrag> l, String zeitraum, String ma, long jetzt) {
        XlsxWriter.Sheet s = wb.addSheet("Stunden");
        s.portrait().tabColor(BLAU);
        String[] kopf = {"Datum", "Tag", "Baustelle", "Tätigkeit", "Kommen", "Gehen", "Pause (min)", "Stunden", "Regie", "Notiz"};
        double[] breite = {11, 5, 30, 18, 8, 8, 9, 9, 7, 28};
        for (int c = 0; c < breite.length; c++) s.width(c, breite[c]);

        XlsxWriter.Style base = style();
        s.set(0, 0, "Stundenzettel " + (ma == null || ma.isEmpty() ? "" : ma), base.bold().size(14).color(BLAU));
        s.set(1, 0, zeitraum, base.size(11));
        XlsxWriter.Style head = base.bold().color("FFFFFFFF").fill(BLAU).border("thin").borderColor(BLAU).align("center");
        int r = 3;
        for (int c = 0; c < kopf.length; c++) s.set(r, c, kopf[c], head);
        s.freeze(r + 1, 0).printTitles(r, r);

        XlsxWriter.Style cell = base.border("thin").borderColor("FFD0D0D0");
        int erste = r + 1;
        int i = 0;
        for (Zeiteintrag z : l) {
            r++;
            XlsxWriter.Style c0 = (i++ % 2 == 1) ? cell.fill(ZEBRA) : cell;
            s.set(r, 0, Zeiten.datum(z.start), c0.align("center"));
            s.set(r, 1, new java.text.SimpleDateFormat("EE", java.util.Locale.GERMANY).format(new java.util.Date(z.start)), c0.align("center"));
            s.set(r, 2, z.baustelle, c0);
            s.set(r, 3, z.istAbwesenheit() ? z.abwesenheit : z.taetigkeit, c0);
            s.set(r, 4, z.istAbwesenheit() ? "" : Zeiten.uhr(z.start), c0.align("center"));
            s.set(r, 5, z.istAbwesenheit() ? "" : z.laeuft() ? "läuft" : Zeiten.uhr(z.ende), c0.align("center"));
            s.set(r, 6, (double) z.pauseMin(jetzt), c0.align("right").fmt("0"));
            s.set(r, 7, Zeiten.dezimal(z.nettoMin(jetzt)), c0.align("right").fmt(FMT_H));
            s.set(r, 8, z.regie ? "R" : "", c0.align("center"));
            s.set(r, 9, z.notiz, c0);
        }
        r++;
        XlsxWriter.Style sum = base.bold().fill(SUMME).border("thin").borderColor("FFFFCC80");
        s.styleRange(r, 0, r, kopf.length - 1, sum);
        s.set(r, 0, "Summe", sum);
        double gesamt = Zeiten.dezimal(Zeiten.summeMin(l, jetzt));
        if (l.isEmpty()) s.set(r, 7, 0.0, sum.align("right").fmt(FMT_H));
        else s.formula(r, 7, "SUM(" + XlsxWriter.ref(erste, 7) + ":" + XlsxWriter.ref(r - 1, 7) + ")", gesamt, sum.align("right").fmt(FMT_H));
        s.headerFooter("Stundenzettel " + (ma == null ? "" : ma), zeitraum, "Seite &P von &N");
    }

    private static void summen(XlsxWriter wb, List<Zeiteintrag> l, String zeitraum, String ma, long jetzt) {
        XlsxWriter.Sheet s = wb.addSheet("Summen");
        s.portrait();
        s.width(0, 34).width(1, 12);
        XlsxWriter.Style base = style();
        s.set(0, 0, "Summen " + zeitraum + (ma == null || ma.isEmpty() ? "" : " – " + ma), base.bold().size(13).color(BLAU));
        int r = 2;
        r = block(s, r, "Je Tag", tage(l, jetzt), base);
        r = block(s, r, "Je Baustelle", Zeiten.summeNach(l, true, jetzt), base);
        r = block(s, r, "Je Tätigkeit / Abwesenheit", Zeiten.summeNach(l, false, jetzt), base);
        int regie = 0;
        for (Zeiteintrag z : l) if (z.regie) regie += z.nettoMin(jetzt);
        if (regie > 0) {
            s.set(r, 0, "davon Regiestunden", base.bold());
            s.set(r, 1, Zeiten.dezimal(regie), base.bold().align("right").fmt(FMT_H));
            r += 2;
        }
        XlsxWriter.Style sum = base.bold().fill(SUMME).border("thin").borderColor("FFFFCC80");
        s.set(r, 0, "Gesamt", sum);
        s.set(r, 1, Zeiten.dezimal(Zeiten.summeMin(l, jetzt)), sum.align("right").fmt(FMT_H));
    }

    private static List<Map.Entry<String, Integer>> tage(List<Zeiteintrag> l, long jetzt) {
        List<Map.Entry<String, Integer>> out = new java.util.ArrayList<>();
        for (List<Zeiteintrag> tag : Zeiten.nachTag(l).values()) {
            String k = new java.text.SimpleDateFormat("EE dd.MM.yyyy", java.util.Locale.GERMANY).format(new java.util.Date(tag.get(0).start));
            out.add(new java.util.AbstractMap.SimpleEntry<>(k, Zeiten.summeMin(tag, jetzt)));
        }
        return out;
    }

    private static int block(XlsxWriter.Sheet s, int r, String titel, List<Map.Entry<String, Integer>> zeilen, XlsxWriter.Style base) {
        XlsxWriter.Style head = base.bold().fill(HELL).border("thin").borderColor("FFC5D5E4");
        s.set(r, 0, titel, head);
        s.set(r, 1, "Stunden", head.align("right"));
        r++;
        XlsxWriter.Style cell = base.border("thin").borderColor("FFD0D0D0");
        for (Map.Entry<String, Integer> e : zeilen) {
            s.set(r, 0, e.getKey(), cell);
            s.set(r, 1, Zeiten.dezimal(e.getValue()), cell.align("right").fmt(FMT_H));
            r++;
        }
        return r + 1;
    }
}
