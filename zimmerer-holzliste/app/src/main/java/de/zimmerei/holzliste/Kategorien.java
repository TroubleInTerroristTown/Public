package de.zimmerei.holzliste;

import java.util.Locale;
import java.util.regex.Pattern;

/** Ordnet Artikel anhand ihrer Bezeichnung einer Kategorie zu (wenn die Liste selbst keine hat). */
public final class Kategorien {

    private Kategorien() {}

    public static final String SONSTIGES = "Sonstiges";

    // Reihenfolge = Priorität (erste passende Kategorie gewinnt)
    private static final Object[][] REGELN = {
            {"Verankerungsmittel", "anker|dübel|duebel|gewindestange|ankerstange|bolzenanker|schwerlast|injektion|mörtelpatrone|einschlaganker|stockschraube|rahmendübel"},
            {"Verbindungsmittel", "winkel|balkenschuh|sparrenpfetten|lochband|lochblech|nagelplatte|stützenfuß|stuetzenfuss|verbinder|knagge|zuganker|pfostenträger|pfostentraeger|kreuzverbinder"},
            {"Schrauben", "schraube|schrauben|spax|tellerkopf|senkkopf|bauschraube|vollgewinde|teilgewinde|torx|bohrschraube"},
            {"Nägel & Klammern", "nagel|nägel|naegel|klammer|stift|rillennagel|ankernagel|kammnagel|coil"},
            {"Bolzen, Muttern & Scheiben", "bolzen|mutter|scheibe|unterlegscheibe|gewinde|m8|m10|m12|m16|m20"},
            {"Dämmung", "dämm|daemm|mineralwolle|glaswolle|steinwolle|holzfaser|zellulose|eps|xps|pir|pur|hanf|isover|rockwool|steico|gutex"},
            {"Folien & Bahnen", "folie|bahn|dampfbrems|dampfsperr|unterdeck|unterspann|vlies|luftdicht|sd-wert|sd "},
            {"Klebebänder & Dichtung", "klebeband|tape|dichtband|kleber|kompriband|manschette|dichtstoff|silikon|acryl|kartusche|montageschaum|schaum"},
            {"Platten", "osb|platte|gipskarton|gipsfaser|fermacell|dreischicht|spanplatte|mdf|sperrholz|multiplex|zementgeb"},
            {"Holz", "kvh|bsh|kantholz|balken|latte|brett|bohle|schalung|rauhspund|leiste|duo|trio|konstruktionsvollholz|brettschicht"},
            {"Dach & Spengler", "ziegel|pfanne|dachstein|first|ortgang|rinne|fallrohr|traufe|kehlblech|blech|schneefang|dachfenster"},
            {"Mörtel, Beton & Putz", "mörtel|moertel|zement|beton|putz|estrich|kalk|sand|kies|splitt|fliesenkleber"},
            {"Holzschutz & Farbe", "lasur|lack|farbe|holzschutz|öl|grundierung|beize|imprägnier"},
            {"Werkzeug & Verbrauch", "bit|bohrer|sägeblatt|saegeblatt|klinge|handschuh|schleif|meißel|kreide|schnur|stift"},
    };

    private static final Pattern[] MUSTER = new Pattern[REGELN.length];

    static {
        for (int i = 0; i < REGELN.length; i++) MUSTER[i] = Pattern.compile("(" + REGELN[i][1] + ")");
    }

    /** Kategorie für einen Artikeltext, "Sonstiges" wenn nichts passt. */
    public static String zuordnen(String text) {
        if (text == null) return SONSTIGES;
        String t = text.toLowerCase(Locale.GERMANY);
        for (int i = 0; i < REGELN.length; i++) if (MUSTER[i].matcher(t).find()) return (String) REGELN[i][0];
        return SONSTIGES;
    }

    /** Symbol für eine Kategorie (für die Auswahl-Knöpfe). */
    public static String symbol(String kat) {
        String k = kat == null ? "" : kat.toLowerCase(Locale.GERMANY);
        if (k.contains("anker") || k.contains("verankerung") || k.contains("dübel")) return "⚓";
        if (k.contains("verbind") || k.contains("winkel")) return "📐";
        if (k.contains("schraub")) return "🔩";
        if (k.contains("nagel") || k.contains("nägel") || k.contains("klammer")) return "📌";
        if (k.contains("bolzen") || k.contains("mutter")) return "🔩";
        if (k.contains("dämm")) return "🧱";
        if (k.contains("folie") || k.contains("bahn")) return "🎞";
        if (k.contains("kleb") || k.contains("dicht")) return "✂";
        if (k.contains("platte")) return "▦";
        if (k.contains("holz") && !k.contains("schutz")) return "🌲";
        if (k.contains("dach")) return "🏠";
        if (k.contains("mörtel") || k.contains("beton")) return "⛏";
        if (k.contains("farbe") || k.contains("schutz")) return "🖌";
        if (k.contains("werkzeug")) return "🔧";
        return "📦";
    }
}
