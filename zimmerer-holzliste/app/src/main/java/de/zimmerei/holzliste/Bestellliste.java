package de.zimmerei.holzliste;

import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

import static de.zimmerei.holzliste.XlsxWriter.style;

/**
 * Schlichte Bestellliste zum Verschicken an den Händler: nur was bestellt wird –
 * keine Überschriften aus der Arbeitsanweisung, keine Kundendaten, keine Preise, keine Formeln.
 * Holz (Balken, Latten, Platten) und sonstiges Material getrennt, weil sie an verschiedene Händler gehen.
 */
public final class Bestellliste {

    private Bestellliste() {}

    public static final int HOLZ = 0, MATERIAL = 1, ALLES = 2;

    static boolean gehoertDazu(Position p, int was) {
        if (p.isTitel()) return false;
        if (was == ALLES) return true;
        return was == MATERIAL ? p.isMaterial() : !p.isMaterial();
    }

    public static int anzahl(Holzliste h, int was) {
        int n = 0;
        for (Position p : h.positionen) if (gehoertDazu(p, was)) n++;
        return n;
    }

    public static String titel(int was) {
        return was == HOLZ ? "Holzliste" : was == MATERIAL ? "Materialliste" : "Bestellliste";
    }

    /** Eine Zeile der Bestellung: Menge, Einheit, Bezeichnung, Querschnitt, Länge, Art.-Nr., Bemerkung. */
    static Object[] zeile(Position p) {
        Double menge = null;
        String einheit = "";
        String quer = "", laenge = "", pack = "";
        String bez = p.bezeichnung == null ? "" : p.bezeichnung.trim();
        String mat = p.holzart == null ? "" : p.holzart.trim();
        if (!mat.isEmpty() && !bez.toLowerCase().contains(mat.toLowerCase())) bez = bez.isEmpty() ? mat : bez + " " + mat;
        if (p.isMaterial()) {
            Double pk = p.getPackungen();
            if (pk != null) {
                menge = pk;
                einheit = p.packNameOderStandard();
                pack = "à " + Fmt.num(p.packInhalt) + " " + Einheit.norm(p.einheit);
            }
            else { menge = p.getBedarf(); einheit = Einheit.norm(p.einheit); }
        } else if (p.isPlatte()) {
            menge = p.getPlattenAnzahl();
            einheit = "Platten";
            if (p.laenge != null || p.breite != null)
                quer = (p.laenge == null ? "–" : Fmt.num(p.laenge * 100)) + " × " + (p.breite == null ? "–" : Fmt.num(p.breite));
            if (p.hoehe != null) laenge = Fmt.num(p.hoehe * 10) + " mm stark";
        } else if (p.isLfm()) {
            menge = p.laufmeter;
            einheit = "m";
            quer = Fmt.querschnitt(p.breite, p.hoehe);
        } else {
            menge = p.stueck;
            einheit = "Stk";
            quer = Fmt.querschnitt(p.breite, p.hoehe);
            if (p.laenge != null) laenge = Fmt.fix(p.laenge, 2) + " m";
        }
        if (bez.isEmpty()) bez = Position.typName(p.typ);
        String bem = p.bemerkung == null ? "" : p.bemerkung.trim();
        if (!pack.isEmpty()) bem = bem.isEmpty() ? pack : pack + ", " + bem;
        return new Object[]{menge, einheit, bez, quer, laenge, p.artikelNr == null ? "" : p.artikelNr, bem};
    }

    public static void write(Holzliste h, int was, OutputStream out) throws IOException {
        XlsxWriter wb = new XlsxWriter();
        wb.title = titel(was) + " " + h.titel();
        wb.author = h.bearbeiter == null ? "" : h.bearbeiter;
        XlsxWriter.Sheet s = wb.addSheet(titel(was));
        s.portrait();
        s.width(0, 5).width(1, 9).width(2, 9).width(3, 40).width(4, 14).width(5, 13).width(6, 14).width(7, 26);

        XlsxWriter.Style base = style().size(11);
        s.set(0, 0, titel(was).toUpperCase(), base.bold().size(16));
        s.merge(0, 0, 0, 3);
        s.height(0, 24);
        int r = 2;
        r = kopf(s, r, "Baustelle", h.titel(), base);
        r = kopf(s, r, "Datum", h.datum, base);
        r = kopf(s, r, "Besteller", h.bearbeiter, base);
        r++;

        XlsxWriter.Style head = base.bold().fill("FFE0E0E0").border("thin").borderColor("FF9E9E9E");
        String[] heads = {"Nr.", "Menge", "Einheit", "Bezeichnung", "Maß [cm]", "Länge", "Art.-Nr.", "Bemerkung"};
        for (int c = 0; c < heads.length; c++) s.set(r, c, heads[c], c == 1 ? head.align("right") : head);
        int kopfZeile = r;
        r++;

        XlsxWriter.Style zelle = base.border("thin").borderColor("FFBDBDBD").valign("top");
        XlsxWriter.Style text = zelle.wrap();
        XlsxWriter.Style zahl = zelle.fmt(HolzlisteExcel.FMT_MENGE).align("right");
        List<Position> liste = new ArrayList<>();
        for (Position p : h.positionen) if (gehoertDazu(p, was)) liste.add(p);
        int nr = 1;
        for (Position p : liste) {
            Object[] z = zeile(p);
            s.set(r, 0, nr++, zelle.align("center"));
            s.set(r, 1, z[0], zahl);
            s.set(r, 2, z[1], zelle.align("center"));
            s.set(r, 3, z[2], text);
            s.set(r, 4, z[3], zelle.align("center"));
            s.set(r, 5, z[4], zelle);
            s.set(r, 6, z[5], zelle);
            s.set(r, 7, z[6], text);
            r++;
        }
        if (liste.isEmpty()) s.set(r, 3, "(keine Positionen)", base.italic().color("FF757575"));
        s.freeze(kopfZeile + 1, 0);
        s.printTitles(kopfZeile, kopfZeile);
        wb.write(out);
    }

    private static int kopf(XlsxWriter.Sheet s, int r, String label, String wert, XlsxWriter.Style base) {
        if (wert == null || wert.trim().isEmpty()) return r;
        s.set(r, 0, label + ":", base.color("FF616161"));
        s.merge(r, 0, r, 1);
        s.set(r, 2, wert.trim(), base.bold());
        s.merge(r, 2, r, 5);
        return r + 1;
    }
}
