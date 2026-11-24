package de.zimmerei.holzliste;

import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.Locale;

/** Zahlenformatierung im deutschen Format (Komma als Dezimaltrennzeichen). */
public final class Fmt {

    private Fmt() {}

    private static final DecimalFormatSymbols DE = DecimalFormatSymbols.getInstance(Locale.GERMANY);

    /** Zahl mit fester Anzahl Nachkommastellen, z. B. 1,234 */
    public static String fix(double d, int nachkomma) {
        StringBuilder p = new StringBuilder("#,##0");
        if (nachkomma > 0) {
            p.append('.');
            for (int i = 0; i < nachkomma; i++) p.append('0');
        }
        return new DecimalFormat(p.toString(), DE).format(d);
    }

    /** Zahl ohne überflüssige Nullen, z. B. 12 / 7,5 / 4,25 */
    public static String num(Double d) {
        if (d == null) return "";
        return new DecimalFormat("0.###", DE).format(d);
    }

    /** Eingabe-Text -> Zahl. Akzeptiert Komma und Punkt. Leer/ungültig -> null. */
    public static Double parse(String s) {
        if (s == null) return null;
        s = s.trim().replace(" ", "");
        if (s.isEmpty()) return null;
        // "1.234,5" -> "1234.5"; "7,5" -> "7.5"; "7.5" -> "7.5"
        if (s.contains(",")) s = s.replace(".", "").replace(',', '.');
        try {
            double d = Double.parseDouble(s);
            if (Double.isNaN(d) || Double.isInfinite(d)) return null;
            return d;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** "8/16" für Querschnitte. */
    public static String querschnitt(Double b, Double h) {
        if (b == null && h == null) return "";
        return (b == null ? "–" : num(b)) + "/" + (h == null ? "–" : num(h));
    }
}
