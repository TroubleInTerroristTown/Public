package de.zimmerei.holzliste;

import java.util.ArrayList;
import java.util.List;

/**
 * Wandelt eingefügten Text (z. B. aus Excel kopiert) in Positionen um.
 * Spalten: Bezeichnung; Stück/Menge; Breite; Höhe; Länge; Material; Bemerkung; Einheit
 * Mit Einheit (z. B. "Sack", "kg") und ohne Querschnitt → sonstiges Material.
 */
public final class ClipboardImport {

    private ClipboardImport() {}

    public static List<Position> parse(String text) {
        List<Position> out = new ArrayList<>();
        for (String line : text.split("\\r?\\n")) {
            if (line.trim().isEmpty()) continue;
            String[] f = line.contains("\t") ? line.split("\t", -1) : line.split(";", -1);
            String bez = f[0].trim();
            Double stk = f.length > 1 ? Fmt.parse(f[1]) : null;
            Double b = f.length > 2 ? Fmt.parse(f[2]) : null;
            Double h = f.length > 3 ? Fmt.parse(f[3]) : null;
            Double l = f.length > 4 ? Fmt.parse(f[4]) : null;
            String holzart = f.length > 5 ? f[5].trim() : "";
            String bem = f.length > 6 ? f[6].trim() : "";
            String einh = f.length > 7 ? f[7].trim() : "";

            boolean keineZahlen = stk == null && b == null && h == null && l == null;
            if (keineZahlen) {
                // Kopfzeilen wie "Bezeichnung;Stück;..." überspringen
                if (f.length > 1 && !f[1].trim().isEmpty()) continue;
                if (bez.isEmpty()) continue;
                Position t = new Position();
                t.typ = Position.TITEL;
                t.bezeichnung = bez;
                out.add(t);
                continue;
            }
            Position p = new Position();
            p.bezeichnung = bez;
            p.breite = b;
            p.hoehe = h;
            p.holzart = holzart;
            p.bemerkung = bem;
            if (!einh.isEmpty() && b == null && h == null) {
                p.typ = Position.MATERIAL;
                p.menge = stk != null ? stk : l;
                p.einheit = Einheit.norm(einh);
            } else if (stk == null && l != null) {
                p.typ = Position.LFM;
                p.laufmeter = l;
            } else {
                p.typ = Position.HOLZ;
                p.stueck = stk;
                p.laenge = l;
            }
            out.add(p);
        }
        return out;
    }
}
