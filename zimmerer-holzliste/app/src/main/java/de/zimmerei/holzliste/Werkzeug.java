package de.zimmerei.holzliste;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Ein Werkzeug / Gerät für die Baustelle (Reiter „Werkzeug“ einer Liste) und die automatischen Vorschläge. */
public class Werkzeug {

    public String name = "";
    public Integer anzahl;          // null = 1 / nicht angegeben
    public String bemerkung = "";
    public boolean eingepackt;      // beim Laden abgehakt

    public Werkzeug() {}

    public Werkzeug(String name, String bemerkung) {
        this.name = name;
        this.bemerkung = bemerkung == null ? "" : bemerkung;
    }

    public Werkzeug copy() {
        Werkzeug w = new Werkzeug(name, bemerkung);
        w.anzahl = anzahl;
        w.eingepackt = eingepackt;
        return w;
    }

    public JSONObject toJson() throws JSONException {
        JSONObject o = new JSONObject();
        o.put("name", name);
        if (anzahl != null) o.put("anzahl", anzahl);
        o.put("bemerkung", bemerkung);
        o.put("eingepackt", eingepackt);
        return o;
    }

    public static Werkzeug fromJson(JSONObject o) {
        Werkzeug w = new Werkzeug(o.optString("name", ""), o.optString("bemerkung", ""));
        w.anzahl = o.has("anzahl") && !o.isNull("anzahl") ? o.optInt("anzahl") : null;
        w.eingepackt = o.optBoolean("eingepackt", false);
        return w;
    }

    // ================================================================ Vorschläge

    /** Ein vorgeschlagenes Werkzeug mit Begründung („wegen Dämmung 200 mm“). */
    public static final class Vorschlag {
        public final String name, grund;
        public boolean gewaehlt = true;

        Vorschlag(String name, String grund) { this.name = name; this.grund = grund; }
    }

    private static final class Regel {
        final Pattern muster;
        final String[] werkzeuge;

        Regel(String regex, String... werkzeuge) {
            this.muster = Pattern.compile(regex.replace("\\b", GRENZE));
            this.werkzeuge = werkzeuge;
        }
    }

    // Wortgrenze mit Umlauten (Android kennt UNICODE_CHARACTER_CLASS nicht)
    private static final String W = "[\\p{L}\\p{N}_]";
    private static final String GRENZE = "(?:(?<=" + W + ")(?!" + W + ")|(?<!" + W + ")(?=" + W + "))";

    public static final String[] GRUNDAUSSTATTUNG = {
            "Akkuschrauber + Akkus & Ladegerät", "Bit-Satz", "Zollstock / Maßband", "Wasserwaage", "Zimmermannsbleistift",
            "Hammer", "Cuttermesser", "Kabeltrommel", "Erste-Hilfe-Kasten"};

    // Material (Bezeichnung, Material, Kategorie) → Werkzeug
    private static final Regel[] MATERIAL = {
            new Regel("\\bkvh\\b|\\bbsh\\b|kantholz|balken|sparren|pfette|konstruktionsvollholz|brettschicht|stiel|schwelle",
                    "Handkreissäge", "Kappsäge", "Zimmermannswinkel", "Schraubzwingen"),
            new Regel("latte|lattung|brett|schalung|rauhspund|rauspund|diele|terrasse|balkonbrett",
                    "Kappsäge", "Handkreissäge", "Schlagschnur"),
            new Regel("\\bosb|dreischicht|sperrholz|multiplex|spanplatte|holzfaserplatte|unterdeckplatte|\\bdwd\\b|agepan",
                    "Handkreissäge mit Führungsschiene", "Stichsäge", "Plattenheber"),
            new Regel("gipskarton|\\bgk[bfi]?\\b|rigips|fermacell|gipsfaser|trockenbau|\\b(cw|uw|cd|ud)\\b|ständerwerk",
                    "Gipskartonmesser", "Gipsraspel", "Plattenheber", "Blechschere", "Spachtel & Glätter"),
            new Regel("dämm|daemm|mineralwolle|glaswolle|steinwolle|klemmfilz|zellulose|holzfaser(?!platte)",
                    "Dämmstoffmesser", "Dämmstoffsäge", "FFP2-Masken", "Schutzbrille"),
            new Regel("dampfbrems|dampfsperr|folie|unterdeckbahn|unterspann|\\budb\\b|\\busb\\b|intello|bahn\\b",
                    "Tacker + Klammern", "Andrückroller", "Cuttermesser"),
            new Regel("klebeband|tescon|anschlussband|dichtband|kompriband", "Andrückroller", "Schere"),
            new Regel("schraube|schrauben|\\bspax|tellerkopf|vollgewinde", "Akkuschrauber + Akkus & Ladegerät", "Bit-Satz"),
            new Regel("(1[6-9]\\d|[2-5]\\d\\d) ?mm.*schraub|schraub.*\\b(1[6-9]\\d|[2-5]\\d\\d)\\b|\\b[8-9] ?[x×] ?(1[6-9]\\d|[2-5]\\d\\d)\\b|\\b1[0-2] ?[x×] ?\\d{3}\\b",
                    "Schlagschrauber"),
            new Regel("nagel|nägel|klammer|rillennagel|ankernagel", "Druckluftnagler + Kompressor", "Hammer"),
            new Regel("winkelverbinder|balkenschuh|pfettenanker|lochband|schlitzband|holzverbinder|knagge",
                    "Ankernagelgerät oder Hammer", "Akkuschrauber + Akkus & Ladegerät"),
            new Regel("dübel|duebel|\\banker\\b|gewindestange|schwerlast|verankerung|bolzenanker",
                    "Bohrhammer", "Betonbohrer-Satz", "Ausblaspumpe", "Ratsche + Nüsse"),
            new Regel("injektion|verbundmörtel|vmz|\\bfis\\b", "Auspresspistole für Injektionsmörtel"),
            new Regel("silikon|acryl|dichtstoff|kartusche|kleber|kleb(?!eband)", "Kartuschenpistole"),
            new Regel("bauschaum|montageschaum|pu-schaum", "Schaumpistole", "Schaumreiniger"),
            new Regel("lasur|holzschutz|grundier|imprägnier|imprõgnier|anstrich|farbe|\\böl\\b|pullex",
                    "Pinsel & Farbroller", "Rührholz", "Abdeckfolie", "Exzenterschleifer + Schleifpapier"),
            new Regel("ziegel|dachstein|dachpfanne|eindeckung|first|grat",
                    "Ziegelschneider / Trennschleifer", "Dachdeckerhammer", "Dachleiter", "Absturzsicherung (PSA)"),
            new Regel("rinne|fallrohr|blech|verwahrung|attika|titanzink|\\bzink",
                    "Blechschere", "Falzzange", "Lötkolben", "Nieter"),
            new Regel("bitumen|schweißbahn|schweissbahn", "Gasbrenner", "Andrückroller", "Feuerlöscher"),
            new Regel("mörtel|moertel|beton|estrich|zement|putz", "Mörteleimer", "Kelle", "Rührwerk"),
            new Regel("dachfenster|velux|\\broto\\b|eindeckrahmen", "Keile & Unterlegplättchen", "Montageschaum + Schaumpistole"),
    };

    // Arbeitsschritte / Text aus der Arbeitsanweisung → Werkzeug
    private static final Regel[] ARBEIT = {
            new Regel("demontage|demontier|abbruch|abbrechen|rückbau|zurückbauen|ausbauen",
                    "Säbelsäge", "Kuhfuß / Brecheisen", "Schutzhandschuhe"),
            new Regel("entsorg", "Schuttsäcke", "Schubkarre"),
            new Regel("abfangen|abstützen|stützen", "Baustützen", "Kanthölzer zum Unterlegen"),
            new Regel("gerüst|deckenmontage|über kopf|überkopf", "Fahrgerüst / Arbeitsgerüst"),
            new Regel("dach|first|traufe|sparren|höhe|absturz", "Leiter", "Absturzsicherung (PSA)"),
            new Regel("balkon|geländer", "Leiter", "Absperrband"),
            new Regel("lagern|zwischenlager", "Abdeckplane"),
            new Regel("fenster|tür|tuer", "Keile & Unterlegplättchen", "Montageschaum + Schaumpistole"),
            new Regel("schleif", "Exzenterschleifer + Schleifpapier"),
            new Regel("bohr|dübel|verankern", "Bohrhammer", "Betonbohrer-Satz"),
            new Regel("sockel|beton|fundament", "Bohrhammer", "Mörteleimer", "Kelle"),
            new Regel("abbund|abbinden|zapfen|blatt|kerve|klaue", "Kettenstemmer", "Abbundsäge", "Stemmeisen"),
            new Regel("hobel", "Elektrohobel"),
            new Regel("prüfen|überprüfen|ertüchtig|feuchte", "Feuchtemessgerät", "Taschenlampe"),
    };

    /**
     * Werkzeug-Vorschläge für eine Liste: aus Material-Positionen, Überschriften, Notiz (Arbeitsschritte) und
     * optional weiterem Text (z. B. Arbeitsanweisung). Bereits vorhandenes Werkzeug wird weggelassen.
     */
    public static List<Vorschlag> vorschlagen(Holzliste h, List<String> zusatzText) {
        Map<String, Vorschlag> out = new LinkedHashMap<>();
        java.util.Set<String> vorhanden = new java.util.HashSet<>();
        for (Werkzeug w : h.werkzeug) vorhanden.add(schluessel(w.name));

        if (h.werkzeug.isEmpty())
            for (String g : GRUNDAUSSTATTUNG) add(out, vorhanden, g, "Grundausstattung");

        for (Position p : h.positionen) {
            if (p.isTitel()) continue;
            String text = (p.bezeichnung + " " + p.holzart + " " + p.typ).toLowerCase(Locale.GERMANY);
            if (p.isHolz() || p.isLfm()) text += " balken"; // jedes Holz → Säge
            String grund = "wegen " + kurz(p.bezeichnung.isEmpty() ? p.holzart : p.bezeichnung);
            for (Regel r : MATERIAL) if (r.muster.matcher(text).find()) for (String w : r.werkzeuge) add(out, vorhanden, w, grund);
        }

        List<String> texte = new ArrayList<>();
        for (Position p : h.positionen) if (p.isTitel()) texte.add(p.bezeichnung);
        if (h.notiz != null) for (String z : h.notiz.split("\n")) texte.add(z);
        if (h.bauteil != null) texte.add(h.bauteil);
        if (zusatzText != null) texte.addAll(zusatzText);
        for (String z : texte) {
            String t = z.replaceAll("^[\\s•\\-–*]+", "").trim();
            if (t.isEmpty()) continue;
            String k = t.toLowerCase(Locale.GERMANY);
            for (Regel r : ARBEIT) {
                Matcher m = r.muster.matcher(k);
                if (m.find()) for (String w : r.werkzeuge) add(out, vorhanden, w, "wegen „" + kurz(t) + "“");
            }
        }
        return new ArrayList<>(out.values());
    }

    /** Alle bekannten Werkzeugnamen (für die Eingabe-Vorschläge). */
    public static List<String> alleNamen() {
        java.util.TreeSet<String> s = new java.util.TreeSet<>(String.CASE_INSENSITIVE_ORDER);
        java.util.Collections.addAll(s, GRUNDAUSSTATTUNG);
        for (Regel r : MATERIAL) java.util.Collections.addAll(s, r.werkzeuge);
        for (Regel r : ARBEIT) java.util.Collections.addAll(s, r.werkzeuge);
        java.util.Collections.addAll(s, "Kettensäge", "Multifunktionswerkzeug", "Laser / Linienlaser", "Nivelliergerät",
                "Stromerzeuger", "Baustrahler", "Sackkarre", "Spanngurte", "Stichsäge", "Winkelschleifer", "Bandschleifer");
        return new ArrayList<>(s);
    }

    private static void add(Map<String, Vorschlag> out, java.util.Set<String> vorhanden, String name, String grund) {
        String k = schluessel(name);
        if (vorhanden.contains(k) || out.containsKey(k)) return;
        out.put(k, new Vorschlag(name, grund));
    }

    private static String schluessel(String name) {
        return name == null ? "" : name.toLowerCase(Locale.GERMANY).replaceAll("[^\\p{L}\\p{N}]", "");
    }

    private static String kurz(String s) {
        s = s == null ? "" : s.trim();
        return s.length() <= 40 ? s : s.substring(0, 38).trim() + "…";
    }
}
