package de.zimmerei.holzliste;

import java.util.Locale;
import java.util.regex.Pattern;

/** Ordnet Artikel anhand ihrer Bezeichnung einer Kategorie zu (wenn die Liste selbst keine hat). */
public final class Kategorien {

    private Kategorien() {}

    public static final String SONSTIGES = "Sonstiges";

    // Reihenfolge = Priorität (erste passende Kategorie gewinnt). Geprüft an einer Baustoffhändler-Liste (~9.600 Artikel).
    private static final Object[][] REGELN = {
            {"Montage & Dienstleistung", "lagerfracht|hochkran|lkw-stunde|^anlieferung|^aufpreis|^montage|^an- und abfahrt|^anfahrt|verlegung:|^aufmaß|arbeitszeit|stundenlohn|^mehrpreis|^lieferung|^fracht|^entsorgung|^demontage|zuschnittkosten|^kran "},
            {"Dachfenster", "^roto |\\bvelux|schwingfenster|klappschwing|eindeckrahmen|dachfenster|dachausstieg|ausstiegsfenster|lichtkuppel|anschlussschürze|anschlußschürze|dampfsperrschürze"},
            {"Verbindungsmittel", "winkelverbinder|schlitzband|mauerverbinder|balkenschuh|sparrenpfetten|lochband|lochblech|nagelplatte|stützenfuß|stuetzenfuss|pfostenträger|pfostenanker|pfostenschuh|kreuzverbinder|holzverbinder|flachverbinder|zuganker|knagge|balkenträger|schwerlastwinkel|\\bwinkel \\d"},
            {"Verankerungsmittel", "bohrlochreinig|anker|dübel|duebel|gewindestange|injektion|ankerhülse|hohlraum|bolzenanker|stockschraube|duopower|duotec|abdeckkappe"},
            {"Schrauben", "schraube|schrauben|\\bspax|bauschraube|sechskant|tellerkopf|power-fast|vollgewinde|teilgewinde"},
            {"Nägel & Klammern", "nagel|nägel|naegel|rillennä|drahtstift|klammer|stifte?\\b|coil"},
            {"Bolzen, Muttern & Scheiben", "mutter|unterlegscheibe|u-scheibe|scheiben\\b|\\bbolzen|gewindebolzen"},
            {"Dachziegel & Zubehör", "pfanne|ziegel|dachstein|\\bfirst|ortgang|giebelstein|schneestopper|schneefang|\\bbraas|creaton|\\berlus|koramic|nelskamp|lüfter|traufe|\\bgrat|venduct|flavent|klöber|dachhaken|laufrost|laufsteg|trauf|kamin|kehldicht|trittstufe|dachdurchgang|lüftungs|firstrolle|gratrolle"},
            {"Dachabdichtung & Bitumen", "schnittpappe|bitumen|\\bbauder|soprema|\\bsopra|schweißbahn|kaltselbstklebe|\\bksa\\b|liquitec|flachdach|dachbahn|asphalt|icopal|\\bepdm|\\bkskm?\\b|dachabdichtung"},
            {"Dachrinne & Spengler", "rinne|fallrohr|rinnenhaken|kehlblech|titanzink|\\bzink|standrohr|rohrschelle|wasserfangkasten|rinnenstutzen"},
            {"WDVS & Fassade", "\\bwdvs|armierung|fassadendämm|putzträger|anputzleiste|sockelprofil|fassadenplatte|fassadenprofil"},
            {"Brandschutz", "brandschutz|aestuver|promat|promaxon|flamox|\\bzz-|feuerschutz"},
            {"Folien, Bahnen & Klebebänder", "dörken|\\bdelta-|rieselschutz|trenn-fix|gitterstreifen|glasfaserstreifen|folie|bahn|dichtungsband|unterdeckbahn|unterspann|dampfbrems|dampfsperr|divoroll|\\budb|\\busb|vlies|klebeband|\\btape|pro ?clima|\\bsiga|illbruck|dichtband|kompriband|manschette|luftdicht|klebeset|anschlussband"},
            {"Trockenbau", "\\bowa|hohlwanddose|ecophon|\\brigips|\\bknauf|abhängedraht|bandraster|drahtrichtwinkel|trennwandband|seilabhängung|wandwinkel|steckwinkel|längsverbinder|glasroc|aquapanel|deckenanschlu|\\bua-?\\d|\\b(cw|uw|ua|cd|ud)\\b|(cw|uw|ua|cd|ud)-profil|abhänger|nonius|revisionsklappe|gipskarton|\\bgk[bfi]|fermacell|gipsfaser|rigidur|powerpanel|trockenestrich|fugenfüller|uniflott|\\bprotektor|ständerwand|lochpl|cleaneo|kantenschutz|eckschiene|spachtelmasse|fugenspachtel|trockenbau"},
            {"Dämmung", "dämm|daemm|mineralwolle|glaswolle|steinwolle|holzfaser|zellulose|\\beps|\\bxps|\\bpir\\b|\\bpur\\b|hanf|isover|rockwool|\\bsteico|\\bgutex|pavatex|styropor|styrodur|klemmfilz|\\bursa|redstone pura|redstone clima|x-foam|trittschall|isolair|perimeter|\\bwlg|\\bwls"},
            {"Fliesen, Fugen & Abdichtung", "dichtecke|ardatape|baudicht|fuge|fugen|nanofug|silcofug|fliesenkleber|fliese|\\bsopro|\\bpci\\b|abdichtung|dichtschlämme|\\bardex|ardaflex|\\bmapei|durapox|silcoferm|\\baeb\\b"},
            {"Kleber, Schaum & Dichtstoffe", "bindemittel|leimkonzentrat|holzkitt|pavaflash|kleber|klebstoff|leim\\b|schaum|silikon|silicon|acryl|dichtstoff|kartusche|primer|ottoseal|ottocoll|ampacoll|\\bsika|schlauchbeutel"},
            {"Mörtel, Beton & Putz", "redstone secco|horizontalsperre|spritzbewurf|zement|mörtel|moertel|beton|putz|estrich|\\bkalk|\\bbaumit|\\bsakret|\\bsand\\b|\\bkies|splitt|gips\\b|ausgleich|schüttung|vergussmasse|niverllier|nivellier|spachtel|grundierung|haftgrund|tiefgrund"},
            {"Bodenbeläge", "stellfuß|stellfuss|\\bunterlage|laminat|parkett|vinyl|designboden|sockelleiste|teppich|\\bkork|linoleum|\\bmeister |\\bprinz |objectflor|dekorpaneel|bodenbelag|übergangsprofil|abschlussprofil"},
            {"Fenster & Fensterbänke", "beck ?\\+ ?heun|gurtwickler|fensterbank|rohrmotor|bordstück|gleitabschluss|gleitabschluß|fenster|rollladen|rolladen|jalousie|raffstore|\\bbug alu|helopal|insektenschutz|fliegengitter"},
            {"Türen & Zargen", "vordach|sektionaltor|garagentor|tür|tuer|zarge|drücker|\\bgriff|schloss|schloß|beschlag|\\bhuga|\\btore?\\b|torantrieb|garnitur|rosette|türblatt|bänder\\b|türband|schließ"},
            {"Platten", "\\bosb|\\bdwd|agepan|platte|spanplatte|\\bmdf|sperrholz|multiplex|dreischicht|zementgeb|siebdruck"},
            {"Holz", "glattkant|\\bkvh|\\bbsh|kantholz|balken|latte|latten|brett|bohle|schalung|rauhspund|leiste|diele|lärche|fichte|douglasie|eiche|kiefer|konstruktionsvollholz|brettschicht|duobalken|triobalken|hobelware|terrasse"},
            {"Profile & Bleche", "profil|schiene|blech|\\bwinkel|\\balu-?|edelstahl|verzinkt"},
            {"Holzschutz, Farbe & Reinigung", "hartwachs|bodenmilch|fleckenentferner|schimmel|graffiti|clean & care|lasur|\\black|farbe|holzschutz|\\böl\\b|beize|reiniger|pflege|imprägnier|entfetter|verdünnung|seife|hartöl|öl\\b|oil|polish|refresher|aufbrennsperre"},
            {"Werkzeug & Zubehör", "besen|zugeisen|schlagklotz|bürste|ausbläser|verlegeklotz|holzkeile|mop\\b|\\bbits?\\b|bohrer|säge|klinge|handschuh|schleif|meißel|kreide|schnur|eimer|werkzeug|\\bpad\\b|kelle|pinsel|kabelbinder|messer|cutter|hammer|zange|wasserwaage|zollstock|leiter|gerüst|schutzbrille|gehörschutz"},
            // Nur Herstellername bekannt → Hauptsortiment des Herstellers (zuletzt geprüft)
            {"Trockenbau", "butler machts"},
            {"Verankerungsmittel", "\\bfischer "},
    };

    private static final Pattern[] MUSTER = new Pattern[REGELN.length];

    static {
        for (int i = 0; i < REGELN.length; i++)
            MUSTER[i] = Pattern.compile("(" + REGELN[i][1] + ")", Pattern.UNICODE_CHARACTER_CLASS);
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
        if (k.contains("montage") || k.contains("dienstleist")) return "👷";
        if (k.contains("dachfenster")) return "🔼";
        if (k.contains("verbind") || k.contains("winkel")) return "📐";
        if (k.contains("schraub")) return "🔩";
        if (k.contains("nagel") || k.contains("nägel") || k.contains("klammer")) return "📌";
        if (k.contains("bolzen") || k.contains("mutter")) return "🔩";
        if (k.contains("dämm")) return "🧱";
        if (k.contains("folie") || k.contains("bahn")) return "🎞";
        if (k.contains("brandschutz")) return "🔥";
        if (k.contains("kleber") || k.contains("schaum")) return "🧴";
        if (k.contains("kleb") || k.contains("dicht")) return "✂";
        if (k.contains("platte")) return "▦";
        if (k.contains("holz") && !k.contains("schutz")) return "🌲";
        if (k.contains("dach")) return "🏠";
        if (k.contains("wdvs") || k.contains("fassade")) return "🏢";
        if (k.contains("trockenbau")) return "▤";
        if (k.contains("fliese") || k.contains("fuge")) return "🔲";
        if (k.contains("boden")) return "▭";
        if (k.contains("fenster")) return "🖼";
        if (k.contains("tür")) return "🚪";
        if (k.contains("profil") || k.contains("blech")) return "📏";
        if (k.contains("mörtel") || k.contains("beton")) return "⛏";
        if (k.contains("farbe") || k.contains("schutz")) return "🖌";
        if (k.contains("werkzeug")) return "🔧";
        return "📦";
    }
}
