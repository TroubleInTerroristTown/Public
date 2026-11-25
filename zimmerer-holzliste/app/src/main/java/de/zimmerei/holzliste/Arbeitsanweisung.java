package de.zimmerei.holzliste;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Wertet den Text einer Arbeitsanweisung (z. B. aus einer PDF) ohne Internet aus:
 *  - erkennt Überschriften (Bauteile / Arbeitsschritte) → Abschnitte der Materialliste
 *  - sucht Stichworte (Dämmung, Lattung, Dampfbremse, Schrauben …) → Materialvorschläge
 *  - übernimmt Mengen und Maße aus derselben Zeile (m², lfm, Stk, 8/20, 200 mm)
 *  - sucht zu jedem Vorschlag den passendsten Artikel aus der Inventarliste
 * Das Ergebnis ist ausdrücklich ein Vorschlag, der vor dem Übernehmen geprüft wird.
 */
public final class Arbeitsanweisung {

    private Arbeitsanweisung() {}

    /** Ein Materialvorschlag. */
    public static final class Vorschlag {
        public String name;            // z. B. "Dämmung 200 mm"
        public String typ;             // Position.HOLZ / LFM / PLATTE / MATERIAL
        public String kategorie;       // Inventar-Kategorie
        public Double menge;           // aus dem Text, sonst null
        public String einheit = "";    // Einheit der Menge (m², m, Stk, m³)
        public Double b, h;            // Querschnitt cm
        public Double dickeMm;         // Dicke in mm (Dämmung, Platten)
        public Double laengeM;         // Stücklänge in m (Holz aus Maßangabe 120x120x5000)
        public String lvNr = "";       // Positionsnummer aus dem Leistungsverzeichnis
        List<String> suchwoerter = new ArrayList<>();
        public String quelle = "";     // Textstelle, aus der der Vorschlag stammt
        public Katalog.Eintrag artikel;
        public boolean gewaehlt = true;

        /** Kurztext für die Vorschau. */
        public String mengeText() {
            if (menge == null) return "Menge prüfen";
            return Fmt.mengeText(menge) + " " + einheit;
        }
    }

    public static final class Abschnitt {
        public String titel;
        public boolean gewaehlt = true;
        public final List<Vorschlag> vorschlaege = new ArrayList<>();
    }

    public static final class Ergebnis {
        public String projekt = "", kunde = "", bauteil = "";
        public final List<Abschnitt> abschnitte = new ArrayList<>();
        public boolean inventarGenutzt;
        /** Aufzählung allgemeiner Arbeitsschritte (z. B. „Demontage Dämmung“) – für die Notiz. */
        public final List<String> arbeitsschritte = new ArrayList<>();
        /** To-do-Liste: alle Positionen und Arbeitsschritte in der Reihenfolge der Arbeitsanweisung. */
        public final List<Aufgabe> aufgaben = new ArrayList<>();
        /** Positionen ohne Material (Stundenlohn, Pauschalen, Anfahrt …), die übersprungen wurden. */
        public int uebersprungen;

        public int anzahlVorschlaege() {
            int n = 0;
            for (Abschnitt a : abschnitte) n += a.vorschlaege.size();
            return n;
        }
    }

    // ------------------------------------------------------------------ Regeln

    private static final class Regel {
        final String name, typ, kategorie, einheit;
        final Pattern muster;
        final String[] suchwoerter;

        Regel(String name, String typ, String kategorie, String einheit, String regex, String... suchwoerter) {
            this.name = name; this.typ = typ; this.kategorie = kategorie; this.einheit = einheit;
            this.muster = Pattern.compile(regex.replace("\\b", GRENZE));
            this.suchwoerter = suchwoerter;
        }
    }

    // Wortgrenze, die Umlaute als Buchstaben zählt (Android kennt UNICODE_CHARACTER_CLASS nicht)
    private static final String W = "[\\p{L}\\p{N}_]";
    private static final String GRENZE = "(?:(?<=" + W + ")(?!" + W + ")|(?<!" + W + ")(?=" + W + "))";

    private static final String H = Position.HOLZ, L = Position.LFM, P = Position.PLATTE, M = Position.MATERIAL;

    // Reihenfolge = Priorität. Plattenwerkstoffe vor Dämmung (Holzfaserplatte ≠ Holzfaserdämmung).
    private static final Regel[] REGELN = {
            new Regel("Sparren", H, "Holz", "Stk", "(?<!zwischen|auf|unter|zwischen-)sparren(?!pfetten|nägel|nagel|anker|dämm|schraub|höhe|abstand|feld)", "sparren", "kvh"),
            new Regel("Pfetten", H, "Holz", "Stk", "pfette", "pfette", "bsh", "kvh"),
            new Regel("Kanthölzer / Balken", H, "Holz", "Stk", "\\bkvh\\b|\\bbsh\\b|kantholz|kanthölzer|deckenbalken|kehlbalken|\\bbalken\\b|schwelle|\\bstiele?\\b|rähm|wechsel\\b|ständer\\b|brettschicht|konstruktionsvollholz", "kvh", "bsh", "kantholz", "balken"),
            new Regel("Konterlatten", L, "Holz", "m", "konterlatt", "konterlatte", "latte"),
            new Regel("Dachlatten", L, "Holz", "m", "dachlatt|\\blattung|traglatt|\\blatten\\b", "dachlatte", "latte"),
            new Regel("Schalung", L, "Holz", "m", "schalung|rauhspund|rauspund|nut und feder|rhombus|deckelschalung|boden-deckel", "schalung", "rauhspund", "brett"),
            new Regel("OSB-Platten", P, "Platten", "m²", "\\bosb", "osb"),
            new Regel("Holzfaser-Unterdeckplatten", P, "Platten", "m²", "unterdeckplatte|holzfaserplatte|\\bdwd\\b|agepan|pavatex|steico special|steico universal|gutex multitherm|gutex ultratherm", "unterdeck", "dwd", "holzfaser"),
            new Regel("Gipskarton / Gipsfaser", P, "Trockenbau", "m²", "gipskarton|\\bgk[bfi]?\\b|gipsfaser|fermacell|rigips|\\brigidur|feuerschutzplatte", "gipskarton", "gk", "fermacell", "gipsfaser"),
            new Regel("Dreischicht- / Sperrholzplatten", P, "Platten", "m²", "dreischicht|3-schicht|sperrholz|multiplex|siebdruck", "dreischicht", "sperrholz", "multiplex"),
            new Regel("Spanplatten", P, "Platten", "m²", "spanplatte|\\bp5\\b|\\bp7\\b|verlegeplatte", "spanplatte", "verlegeplatte"),
            new Regel("Dämmung", M, "Dämmung", "m²", "dämm|daemm|mineralwolle|glaswolle|steinwolle|zellulose|klemmfilz|einblas|isolier", "dämm", "wolle", "klemmfilz", "holzfaser"),
            new Regel("Dampfbremse", M, "Folien, Bahnen & Klebebänder", "m²", "dampfbrems|dampfsperr|luftdichtheitsbahn|luftdichtungsbahn|intello|vario ?km|\\bdb\\+", "dampfbrems", "dampfsperr", "intello", "vario"),
            new Regel("Unterdeckbahn", M, "Folien, Bahnen & Klebebänder", "m²", "unterdeckbahn|unterspannbahn|\\budb\\b|\\busb\\b|diffusionsoffene bahn|unterdeckung", "unterdeck", "unterspann", "udb"),
            new Regel("Folie / Trennlage", M, "Folien, Bahnen & Klebebänder", "m²", "rieselschutz|trennlage|pe-folie|baufolie|abdeckfolie", "folie", "rieselschutz", "trenn"),
            new Regel("Klebeband (luftdicht)", M, "Folien, Bahnen & Klebebänder", "Rolle", "klebeband|abkleben|abgeklebt|verkleb(en|t) der (stöße|bahnen)|tescon|anschlussband|dichtungsband|kompriband", "klebeband", "tescon", "band"),
            new Regel("Anschlusskleber", M, "Folien, Bahnen & Klebebänder", "Stk", "anschlusskleber|orcon|kartuschenkleber|dichtkleber", "kleber", "orcon"),
            new Regel("Holzverbinder", M, "Verbindungsmittel", "Stk", "winkelverbinder|balkenschuh|sparrenpfettenanker|pfettenanker|lochband|lochblech|schlitzband|stützenfuß|stuetzenfuss|pfostenträger|pfostenanker|holzverbinder|knagge|nagelplatte|\\bwinkel\\b", "winkel", "balkenschuh", "pfettenanker", "lochband", "verbinder"),
            new Regel("Dübel / Anker", M, "Verankerungsmittel", "Stk", "dübel|duebel|\\banker\\b|gewindestange|verankert|verankerung|verdübel|schwerlastanker|injektion|bolzenanker", "dübel", "anker", "gewindestange"),
            new Regel("Schrauben", M, "Schrauben", "Stk", "schraube|schrauben|verschraub|\\bspax|tellerkopf|vollgewinde|teilgewinde", "schraube", "spax"),
            new Regel("Nägel / Klammern", M, "Nägel & Klammern", "Stk", "nagel|nägel|genagelt|nageln|klammer|tacker|getackert", "nagel", "klammer"),
            new Regel("Bolzen / Muttern / Scheiben", M, "Bolzen, Muttern & Scheiben", "Stk", "\\bbolzen|mutter\\b|muttern|unterlegscheibe|u-scheibe|stabdübel", "bolzen", "mutter", "scheibe"),
            new Regel("Bauschaum / Silikon / Acryl", M, "Kleber, Schaum & Dichtstoffe", "Stk", "bauschaum|pu-schaum|montageschaum|silikon|\\bacryl|dichtstoff|ausschäum|kartusche|leim\\b|verleim", "schaum", "silikon", "acryl", "leim"),
            new Regel("Dacheindeckung (Ziegel)", M, "Dachziegel & Zubehör", "m²", "ziegel|dachstein|dachpfanne|eindeckung|eindecken|einzudecken", "ziegel", "pfanne", "dachstein"),
            new Regel("First / Grat / Lüftung", M, "Dachziegel & Zubehör", "m", "firstrolle|gratrolle|firstband|gratband|lüfterelement|traufenkamm|traufkamm|vogelschutz|lüftungsgitter|firstlatte", "first", "grat", "lüft", "traufe"),
            new Regel("Dachrinne / Fallrohr", M, "Dachrinne & Spengler", "m", "dachrinne|rinne\\b|rinnen\\b|fallrohr|rinnenhaken|regenrohr", "rinne", "fallrohr", "rinnenhaken"),
            new Regel("Bleche / Verwahrung", M, "Profile & Bleche", "m", "blech|verwahrung|attika|traufblech|ortgangblech|kehlblech", "blech"),
            new Regel("Bitumen / Abdichtung", M, "Dachabdichtung & Bitumen", "m²", "bitumen|schweißbahn|schweissbahn|abdichtungsbahn|\\bepdm\\b|flachdachabdichtung|dachbahn", "bitumen", "bahn", "epdm"),
            new Regel("Trockenbauprofile", M, "Trockenbau", "m", "\\b(cw|uw|cd|ud|ua)-?profil|ständerwerk|metallständer|abhänger|direktabhänger|noniusabhänger", "profil", "abhänger"),
            new Regel("Spachtel / Fugenfüller", M, "Trockenbau", "Sack", "spachtel|verspachtel|fugenfüller|uniflott|bewehrungsstreifen|fugendeckstreifen", "spachtel", "fugenfüller", "uniflott"),
            new Regel("Dachfenster", M, "Dachfenster", "Stk", "dachfenster|wohndachfenster|\\bvelux|\\broto\\b|eindeckrahmen|ausstiegsfenster", "dachfenster", "velux", "roto", "eindeckrahmen"),
            new Regel("Brandschutz", M, "Brandschutz", "Stk", "brandschutz|feuerwiderstand|\\bf30\\b|\\bf60\\b|\\bf90\\b|\\brei ?\\d{2}|brandsperre", "brandschutz"),
            new Regel("Holzschutz / Anstrich", M, "Holzschutz, Farbe & Reinigung", "Stk", "holzschutz|lasur|grundier|imprägnier|anstrich|streichen|gestrichen", "holzschutz", "lasur", "grund"),
            new Regel("Mörtel / Beton", M, "Mörtel, Beton & Putz", "Sack", "mörtel|moertel|beton\\b|estrich|zement|unterstopf|vergussmörtel", "mörtel", "beton", "zement"),
    };

    // Bauteile: kurze Zeilen mit diesen Wörtern gelten als Überschrift
    private static final Pattern BAUTEIL = Pattern.compile(
            "dach|sparren|pfette|wand|decke|boden|fassade|gaube|carport|balkon|terrasse|treppe|vordach|anbau|"
                    + "dachstuhl|giebel|traufe|ortgang|kehle|flachdach|holzrahmen|ständerwerk|trockenbau|innenausbau|"
                    + "fenster|dämmung|unterkonstruktion|abbund|aufrichten|richten|geschoss|\\bog\\b|\\beg\\b|\\bdg\\b|\\bkg\\b");

    // Überschriften, die für die Materialliste keine Rolle spielen
    private static final Pattern UNWICHTIG = Pattern.compile(
            "^(inhalt|inhaltsverzeichnis|seite|anlage|anhang|allgemein|allgemeines|hinweis|hinweise|sicherheit|arbeitsschutz|"
                    + "unterschrift|verteiler|änderung|revision|freigabe|gefährdung|psa|persönliche schutz|ansprechpartner|termin|"
                    + "arbeitsanweisung|zweck|geltungsbereich|verantwortlich|mitgeltende|dokument|kontakt|bemerkung|notizen?|beschreibung|"
                    + "vorbemerkung|baustelleneinrichtung|leistungsbeschreibung)\\b");

    // Mengeneinheit direkt hinter einer Zahl (kein \b: m² endet auf ein Nicht-Wortzeichen)
    private static final Pattern MENGE = Pattern.compile(
            "(?<![\\d,./×x])(\\d{1,5}(?:[.,]\\d{1,3})?)\\s*(m²|m2|qm|m³|m3|cbm|lfm|lfdm|lfd\\.? ?m|stk\\.?|stück|st\\.|m)(?![\\p{L}\\d])",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern QUERSCHNITT = Pattern.compile(
            "(?<![\\d,.])(\\d{1,3}(?:,\\d)?)\\s*[/x×]\\s*(\\d{1,3}(?:,\\d)?)(?:\\s*(mm|cm))?(?![\\d,.]*\\s*(?:mm|cm)?\\s*[/x×]\\s*\\d)");
    private static final Pattern DICKE = Pattern.compile("(?<![\\d,./×x])(\\d{1,3})\\s*mm(?![\\p{L}])", Pattern.CASE_INSENSITIVE);
    private static final Pattern NUMMERIERT = Pattern.compile("^(?:(?:pos(?:ition)?\\.?|abschnitt|schritt|kapitel)\\s*)?(\\d{1,2}(?:\\.\\d{1,2}){0,3})[.):]?\\s+(.+)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern KOPF = Pattern.compile("^(bauvorhaben|bv|projekt|objekt|baustelle|kunde|bauherr|auftraggeber|bauteil|gewerk)\\s*[.:]\\s*(.+)$", Pattern.CASE_INSENSITIVE);

    // ------------------------------------------------------------------ Auswertung

    /** Text auswerten. inventar darf leer sein (dann ohne Artikelvorschläge). dateiname optional (für den Projektnamen). */
    public static Ergebnis auswerten(String text, List<Katalog.Eintrag> inventar, String dateiname) {
        Ergebnis erg = new Ergebnis();
        erg.inventarGenutzt = inventar != null && !inventar.isEmpty();
        List<String> zeilen = zeilen(text);
        kopfdaten(zeilen, erg);
        if (istLeistungsverzeichnis(zeilen)) leistungsverzeichnis(zeilen, erg);
        else freitext(zeilen, erg);
        String ausDatei = projektAusDateiname(dateiname);
        if (!ausDatei.isEmpty()) erg.projekt = ausDatei;

        // Leere Abschnitte weglassen, außer sie benennen ein Bauteil (Struktur bleibt erhalten)
        for (int i = erg.abschnitte.size() - 1; i >= 0; i--) {
            Abschnitt a = erg.abschnitte.get(i);
            String t = a.titel.toLowerCase(Locale.GERMANY);
            if (a.vorschlaege.isEmpty() && (!BAUTEIL.matcher(t).find() || UNWICHTIG.matcher(t).find()))
                erg.abschnitte.remove(i);
        }
        for (Abschnitt a : erg.abschnitte) {
            for (Vorschlag v : a.vorschlaege) {
                if (v.lvNr.isEmpty()) {
                    if (v.dickeMm != null && (M.equals(v.typ) || P.equals(v.typ))) v.name += " " + Fmt.num(v.dickeMm) + " mm";
                    else if (v.b != null && v.h != null) v.name += " " + Fmt.num(v.b) + "/" + Fmt.num(v.h);
                }
                if (erg.inventarGenutzt) v.artikel = besterArtikel(v, inventar);
            }
        }
        return erg;
    }

    /** Kopfdaten: „Bauvorhaben: …“, „Kunde: …“, Anschrift „Frau / Herrn …“. */
    private static void kopfdaten(List<String> zeilen, Ergebnis erg) {
        for (int i = 0; i < zeilen.size(); i++) {
            String z = zeilen.get(i);
            Matcher k = KOPF.matcher(z);
            if (k.matches()) {
                String feld = k.group(1).toLowerCase(Locale.GERMANY);
                String wert = k.group(2).replaceAll("\\s+(Seite|Datum|Zeichen|Kundennr|Mitarbeiter|Projektnummer)\\b.*$", "").trim();
                if (wert.isEmpty() || wert.length() > 80) continue;
                if (feld.equals("bauvorhaben") || feld.equals("bv") || feld.equals("projekt") || feld.equals("objekt") || feld.equals("baustelle")) {
                    if (erg.projekt.isEmpty()) erg.projekt = wert;
                } else if (feld.equals("bauteil") || feld.equals("gewerk")) {
                    if (erg.bauteil.isEmpty()) erg.bauteil = wert;
                } else if (erg.kunde.isEmpty()) erg.kunde = wert;
            } else if (erg.kunde.isEmpty() && z.matches("(?i)^(frau|herrn?|familie|eheleute|firma)$") && i + 1 < zeilen.size()) {
                String n = zeilen.get(i + 1);
                if (!n.matches(".*\\d.*") && woerter(n) <= 5) erg.kunde = n;
            }
        }
    }

    /** „26-00204-AW BV Schultheiss Wintergarten Balkon.pdf“ → „BV Schultheiss Wintergarten Balkon“. */
    static String projektAusDateiname(String name) {
        if (name == null) return "";
        String n = name.replaceAll("(?i)\\.pdf$", "").replace('_', ' ').trim();
        n = n.replaceAll("^[\\d\\s-]*(?i:aw|arbeitsanweisung)?[\\s-]+", "").trim();
        n = n.replaceAll("(?i)^(arbeitsanweisung|aw)\\b[\\s-]*", "").trim();
        if (n.replaceAll("[^\\p{L}]", "").length() < 4) return "";
        if (n.matches("(?i)^(scan|dokument|document|download|unbenannt|file|datei)\\b.*")) return "";
        return n.length() > 60 ? n.substring(0, 60).trim() : n;
    }

    /** Freier Text: Überschriften erkennen und Stichworte suchen. */
    private static void freitext(List<String> zeilen, Ergebnis erg) {

        Abschnitt akt = null;
        Map<String, Vorschlag> imAbschnitt = new LinkedHashMap<>();
        for (String z : zeilen) {
            String klein = z.toLowerCase(Locale.GERMANY);

            if (KOPF.matcher(z).matches()) continue;

            String titel = ueberschrift(z);
            if (titel != null) {
                akt = new Abschnitt();
                akt.titel = titel;
                erg.abschnitte.add(akt);
                imAbschnitt.clear();
                // Überschrift kann selbst schon ein Material nennen („3. Zwischensparrendämmung“) → unten weiter auswerten
            }

            // Jeder Satz unter einer Überschrift ist ein Arbeitsschritt für die To-do-Liste
            String abschn = akt == null ? "" : akt.titel;
            if (titel == null && woerter(z) >= 2 && Character.isLetter(z.charAt(0)) && z.length() <= 160
                    && !FUSS.matcher(z).find() && !UNWICHTIG.matcher(abschn.toLowerCase(Locale.GERMANY)).find())
                erg.aufgaben.add(new Aufgabe(abschn, z.replaceAll("[.;]+$", "").trim(), ""));

            // Treffer mit Fundstelle; die Zeile wird an den Fundstellen in Stücke geteilt, damit
            // „Konterlattung 40/60 und Dachlattung 30/50, 320 lfm“ die Maße dem richtigen Material zuordnet.
            List<Regel> treffer = new ArrayList<>();
            List<Integer> stellen = new ArrayList<>();
            boolean holzGenau = false;
            for (Regel r : REGELN) {
                Matcher m = r.muster.matcher(klein);
                if (!m.find()) continue;
                if (r == REGELN[2] && holzGenau) continue; // „Sparren … KVH“ → nicht zusätzlich „Kanthölzer“
                if (r == REGELN[0] || r == REGELN[1]) holzGenau = true;
                int pos = 0;
                while (pos < stellen.size() && stellen.get(pos) <= m.start()) pos++;
                treffer.add(pos, r);
                stellen.add(pos, m.start());
            }
            if (treffer.isEmpty()) continue;
            if (akt == null) {
                akt = new Abschnitt();
                akt.titel = erg.bauteil.isEmpty() ? "Material" : erg.bauteil;
                erg.abschnitte.add(akt);
            }
            for (int t = 0; t < treffer.size(); t++) {
                Regel r = treffer.get(t);
                String stueck = z.substring(t == 0 ? 0 : stellen.get(t), t + 1 < treffer.size() ? stellen.get(t + 1) : z.length());
                Vorschlag v = imAbschnitt.get(r.name);
                boolean neu = v == null;
                if (neu) {
                    v = new Vorschlag();
                    v.name = r.name; v.typ = r.typ; v.kategorie = r.kategorie; v.einheit = r.einheit;
                    v.quelle = kurz(z);
                    for (String w : r.suchwoerter) v.suchwoerter.add(w);
                    imAbschnitt.put(r.name, v);
                    akt.vorschlaege.add(v);
                } else if (v.quelle.equals(kurz(akt.titel)) || ueberschrift(v.quelle) != null) {
                    v.quelle = kurz(z); // Quelle aus der Überschrift durch die genauere Zeile ersetzen
                }
                masseUebernehmen(v, r, stueck);
            }
        }
    }

    /** Text in saubere Zeilen zerlegen (Silbentrennung zusammenfügen, Ligaturen ersetzen). */
    static List<String> zeilen(String text) {
        String t = text == null ? "" : text.replace('\u00A0', ' ').replace("\uFB01", "fi").replace("\uFB02", "fl")
                .replace("\u00AD", "").replace('\t', ' ').replace("\r", "")
                .replaceAll("[\uE000-\uF8FF]", " "); // Aufzählungszeichen aus Symbol-Schriften
        // Eigenheiten der Auftrags-Software: „õ“ statt „ä“, Textbaustein-Fehler in „Konstruktionsvollholz“
        t = t.replace('õ', 'ä').replace("KonstruktionsStarnbergAmmerseeHolz", "Konstruktionsvollholz");
        // „Dämm-\nung“ → „Dämmung“ (nur wenn klein weitergeht)
        t = t.replaceAll("(\\p{Ll})-\\s*\\n\\s*(\\p{Ll})", "$1$2");
        List<String> out = new ArrayList<>();
        for (String z : t.split("\n")) {
            z = z.replaceAll("^[\\s•·▪■●◦\\-–*]+", "").replaceAll("\\s{2,}", " ").trim();
            // Preisspalten aus Angebot / Auftragsbestätigung („12,47 € 62,35 €“, „E.P.“) gehören nicht zum Text
            z = z.replaceAll("(\\s+-?\\d{1,3}(?:\\.\\d{3})*,\\d{2}\\s*€)+(\\s+E\\.P\\.)?\\s*$", "").replaceAll("\\s+E\\.P\\.$", "").trim();
            // „Bedarf“ (Bedarfsposition) steht vor oder nach der Menge – nur ein Vermerk
            if (z.equalsIgnoreCase("Bedarf")) continue;
            z = z.replaceFirst("^(?i)bedarf\\s+(?=\\d)", "");
            if (!z.isEmpty()) out.add(z);
        }
        return out;
    }

    /** Liefert den Überschriften-Text oder null. */
    static String ueberschrift(String z) {
        if (z.length() > 70 || z.length() < 3) return null;
        if (z.endsWith(".") && !z.matches("^\\d+\\.$")) {
            // Satzende → kein Titel (außer nur Nummer + Wort mit Punkt, z. B. „3. Dämmung.“ ist unüblich)
            return null;
        }
        String text = null;
        Matcher m = NUMMERIERT.matcher(z);
        if (m.matches()) {
            String rest = m.group(2).trim();
            String rk = rest.toLowerCase(Locale.GERMANY);
            // „24 Stück Sparren“, „2,5 m …“ sind Mengen, keine Nummern
            if (rk.matches("^(m²|m2|m³|m3|m|mm|cm|lfm|stk|stück|st\\.|kg|sack|paket|rolle|x|×|/|%|°).*")) return null;
            if (!Character.isLetter(rest.charAt(0))) return null;
            if (woerter(rest) > 8) return null;
            text = rest;
        } else if (z.endsWith(":") && woerter(z) <= 6 && !z.matches(".*\\d.*")) {
            text = z.substring(0, z.length() - 1).trim();
        } else if (z.equals(z.toUpperCase(Locale.GERMANY)) && z.replaceAll("[^\\p{L}]", "").length() >= 4 && woerter(z) <= 6) {
            text = z.charAt(0) + z.substring(1).toLowerCase(Locale.GERMANY);
        } else if (woerter(z) <= 4 && !z.matches(".*\\d.*") && !z.contains(",")
                && BAUTEIL.matcher(z.toLowerCase(Locale.GERMANY)).find()) {
            text = z;
        }
        if (text == null) return null;
        text = text.replaceAll("[:.]+$", "").trim();
        if (text.isEmpty()) return null;
        return text;
    }

    private static int woerter(String s) {
        return s.trim().isEmpty() ? 0 : s.trim().split("\\s+").length;
    }

    private static void masseUebernehmen(Vorschlag v, Regel r, String zeile) {
        String z = zeile.replace("m^2", "m²");
        // Querschnitt (Holz)
        if ((H.equals(r.typ) || L.equals(r.typ)) && v.b == null) {
            Matcher q = QUERSCHNITT.matcher(z);
            if (q.find()) {
                Double b = Fmt.parse(q.group(1)), h = Fmt.parse(q.group(2));
                if (b != null && h != null) {
                    boolean mm = "mm".equalsIgnoreCase(q.group(3)) || (q.group(3) == null && (b > 40 || h > 40));
                    if (mm) { b /= 10; h /= 10; }
                    if (b > 0 && h > 0 && b <= 40 && h <= 60) { v.b = b; v.h = h; }
                }
            }
        }
        // Dicke (Dämmung, Platten)
        if ((M.equals(r.typ) || P.equals(r.typ)) && v.dickeMm == null && ("Dämmung".equals(r.kategorie) || P.equals(r.typ))) {
            Matcher d = DICKE.matcher(z);
            if (d.find()) {
                Double mm = Fmt.parse(d.group(1));
                if (mm != null && mm >= 6 && mm <= 400) v.dickeMm = mm;
            }
        }
        if (v.menge != null) return;
        Matcher m = MENGE.matcher(z);
        while (m.find()) {
            Double wert = Fmt.parse(m.group(1));
            String e = einheit(m.group(2));
            if (wert == null || wert <= 0) continue;
            if (e.equals("m") && "mm".equals(nachfolger(z, m))) continue;
            // Für Holz Stück: Meterangabe ist meist die Länge → nicht als Menge
            if (H.equals(r.typ) && e.equals("m")) continue;
            if (L.equals(r.typ) && !e.equals("m")) continue;
            if (P.equals(r.typ) && !(e.equals("m²") || e.equals("Stk"))) continue;
            v.menge = wert;
            v.einheit = e;
            return;
        }
    }

    private static String nachfolger(String z, Matcher m) {
        int e = m.end();
        return e < z.length() && z.charAt(e) == 'm' ? "mm" : "";
    }

    private static String einheit(String roh) {
        String e = roh.toLowerCase(Locale.GERMANY).replace(".", "").replace(" ", "");
        switch (e) {
            case "m²": case "m2": case "qm": return "m²";
            case "m³": case "m3": case "cbm": return "m³";
            case "stk": case "stück": case "st": return "Stk";
            default: return "m";
        }
    }

    private static String kurz(String z) {
        return z.length() <= 90 ? z : z.substring(0, 87) + "…";
    }

    // ------------------------------------------------------------------ Leistungsverzeichnis

    // „2.5“ oder „2.5 20,00 LFM Konstruktionsholz …“ (Positionsnummer aus Auftrag / Arbeitsanweisung)
    // auch einfache Nummern „1 1,00 Stück …“ (Arbeitsanweisungen ohne Titel-Gliederung) – zählt nur mit Menge dahinter
    private static final Pattern LV_POS = Pattern.compile("^(\\d{1,2}(?:\\.\\d{1,4}){0,3})(?=\\s|$)\\s*(.*)$");
    // „20,00 LFM …“, „1,00 psch“, „2,50 Liter …“, „1,00“
    private static final Pattern LV_MENGE = Pattern.compile("^(\\d{1,3}(?:\\.\\d{3})*,\\d{1,3})(?:\\s+([\\p{L}²³][\\p{L}²³.]{0,11}))?(?:\\s+(.*))?$");
    private static final Pattern LV_TITEL = Pattern.compile("^(\\d{1,2})(?:\\s+(\\p{L}.{2,60}))?$");
    // 120x120x5000 mm, 26x142x5100, 60/200 mm
    private static final Pattern MASSE3 = Pattern.compile("(?<![\\d,.])(\\d{1,4}(?:,\\d)?)\\s*[x×*/]\\s*(\\d{1,4}(?:,\\d)?)(?:\\s*[x×*/]\\s*(\\d{3,5}))?\\s*(mm|cm)?");
    // Einheiten / Texte, die kein Material sind
    private static final Pattern LOHN_EINHEIT = Pattern.compile("(?i)^(h|std|std\\.|stunden?|psch|pausch|pauschal|tag|tage|km|wo|woche|monat|ls)$");
    private static final Pattern LOHN_TEXT = Pattern.compile("stundensatz|stundenlohn|anfahrt|baustelleneinrichtung|gerüst|geruest|entsorg|demontage|"
            + "materialkostenschätzung|kostenschätzung|regie|zulage|psa\\b|schutzausrüstung|schützausrüstung|wartung|abbund|"
            + "dachdeckerlift|\\blift\\b|toilette|container|mulde|einsatz für pauschale|abbruch|rückbau|aufmaß|planung|statik|transport|kranstunde|hebebühne|vorhalte");

    /** Briefkopf, Fußzeile, Bankdaten, Unterschriftsfeld – nie Aufgabe oder Material. */
    static final Pattern FUSS = Pattern.compile("(?i)(\\biban\\b|\\bbic\\b|swift|\\bblz\\b|\\bkto\\b|ust-?id|steuer-?nr|\\bhrb\\b|registergericht|finanzamt|"
            + "\\bgmbh\\b|bank\\b|sparkasse|\\bseite\\s*\\d|übertrag|^tel\\b|^fax\\b|telefon|www\\.|@|auftrag erteilt|unterschrift|^ort,? datum|kundennr|^zeichen\\s*:|^datum\\s*:"
            + "|^pos\\.?\\s+menge|gesamtzeitbedarf|^(end)?summe\\b|mwst|grü(ss|ß)e|^(herr|frau)$|^(arbeitsanweisung|auftragsbestätigung|angebot\\w*)\\s*:|^\\d{5}\\s+\\p{L})");
    // Hinweise in einer Positionsbeschreibung, die keine Arbeit sind
    private static final Pattern HINWEIS = Pattern.compile("(?i)^(\\(?zeitbedarf|einheit\\s*:|abrechnung|zulage|verwendung von|hinweis|preis|inkl\\.|zzgl\\.)");

    // Beschreibungszeile ist ein Arbeitsschritt, wenn sie eine Tätigkeit nennt
    private static final Pattern TAETIGKEIT = Pattern.compile("(?i)(reinig|prüf|austausch|tausch|einbau|ausbau|erstell|demont|montier|montage|dokument|"
            + "abdicht|erneuer|befestig|kontroll|säuber|entfern|anbring|verleg|ausbesser|streich|schneid|abkleb|repar|aufbau|abbau|räum|ersetz|"
            + "ergänz|freischneid|schließ|beseitig|aufnehm|verschraub|nachziehen|lackier|ölen|imprägnier|spachtel|aufmaß nehmen)");

    private static final Pattern KEINE_AUFGABE = Pattern.compile("stundensatz|stundenlohn|anfahrt|kostenschätzung|regiestunde|regiearbeit");

    static boolean istLeistungsverzeichnis(List<String> zeilen) {
        int n = 0;
        for (int i = 0; i < zeilen.size(); i++) {
            Matcher m = LV_POS.matcher(zeilen.get(i));
            if (!m.matches()) continue;
            String rest = m.group(2).trim();
            if (LV_MENGE.matcher(rest).matches() || (rest.isEmpty() && i + 1 < zeilen.size() && LV_MENGE.matcher(zeilen.get(i + 1)).matches()))
                n++;
        }
        return n >= 2;
    }

    /**
     * Positionsliste wie aus einer Auftrags-Software: „Pos. Menge Einh. Beschreibung“.
     * Überschriften („2 Zimmererarbeiten“) werden zu Abschnitten, Materialpositionen zu Vorschlägen,
     * Stundenlohn/Pauschalen werden übersprungen. Die Aufzählung unter „Beschreibung“ wird zu Arbeitsschritten.
     */
    private static void leistungsverzeichnis(List<String> zeilen, Ergebnis erg) {
        Abschnitt akt = null;
        boolean inBeschreibung = false;
        int letzteTitelNr = 0;
        for (int i = 0; i < zeilen.size(); i++) {
            String z = zeilen.get(i);

            Matcher t = LV_TITEL.matcher(z);
            if (t.matches()) {
                String titel = t.group(2);
                if (titel == null && i + 1 < zeilen.size() && Character.isLetter(zeilen.get(i + 1).charAt(0))
                        && zeilen.get(i + 1).length() <= 100 && !LV_POS.matcher(zeilen.get(i + 1)).matches()) {
                    titel = zeilen.get(++i);
                }
                int nrTitel = Integer.parseInt(t.group(1));
                // „3 x gekantet …“ oder „6 bar“ in einer Beschreibung sind keine Kapitel: Kapitel zählen hoch
                if (titel != null && (nrTitel < letzteTitelNr || (nrTitel == letzteTitelNr && !inBeschreibung) || nrTitel > letzteTitelNr + 2 || !Character.isUpperCase(titel.charAt(0)))) {
                    if (t.group(2) == null) i--; // nächste Zeile normal weiter auswerten
                    titel = null;
                }
                if (titel != null) {
                    letzteTitelNr = nrTitel;
                    titel = titel.replaceAll("[:.,]+$", "").trim();
                    inBeschreibung = titel.toLowerCase(Locale.GERMANY).matches("(vor)?beschreibung|allgemein(es)?|vorbemerkungen?|leistungsbeschreibung");
                    akt = new Abschnitt();
                    akt.titel = titel;
                    erg.abschnitte.add(akt);
                    continue;
                }
            }

            Matcher p = LV_POS.matcher(z);
            if (p.matches()) {
                String nr = p.group(1), rest = p.group(2).trim();
                if (rest.isEmpty() && i + 1 < zeilen.size() && LV_MENGE.matcher(zeilen.get(i + 1)).matches()) rest = zeilen.get(++i);
                Matcher m = LV_MENGE.matcher(rest);
                if (m.matches()) {
                    inBeschreibung = false;
                    i = lvPosition(nr, m, zeilen, i, erg, akt);
                    if (akt == null && !erg.abschnitte.isEmpty()) akt = erg.abschnitte.get(erg.abschnitte.size() - 1);
                    continue;
                }
            }

            if (inBeschreibung && z.length() <= 90 && woerter(z) >= 2 && Character.isLetter(z.charAt(0))
                    && !z.matches("(?i)^(frau|herrn?|seite|pos\\.|menge|übertrag|arbeitsanweisung).*")) {
                erg.arbeitsschritte.add(z);
                if (!KEINE_AUFGABE.matcher(z.toLowerCase(Locale.GERMANY)).find()) erg.aufgaben.add(new Aufgabe("Arbeitsschritte", z, ""));
            }
        }
    }

    /** Eine LV-Position auswerten; liefert den Index der letzten dazugehörigen Zeile. */
    private static int lvPosition(String nr, Matcher m, List<String> zeilen, int i, Ergebnis erg, Abschnitt akt) {
        Double menge = Fmt.parse(m.group(1));
        String einheit = m.group(2) == null ? "" : m.group(2);
        String text = m.group(3) == null ? "" : m.group(3).trim();
        // Keine Einheit, sondern gleich Text („1,00 Materialkostenschätzung“)
        if (einheit.length() > 6 && Einheit.norm(einheit).equals(einheit) && !Character.isDigit(einheit.charAt(0))) {
            text = (einheit + " " + text).trim();
            einheit = "";
        }
        if (text.isEmpty() && i + 1 < zeilen.size() && !LV_POS.matcher(zeilen.get(i + 1)).matches()) text = zeilen.get(++i);
        // Maße stehen oft in der nächsten Zeile („120x120x5000 mm“)
        if (i + 1 < zeilen.size() && zeilen.get(i + 1).length() <= 40 && zeilen.get(i + 1).matches("^\\d{1,4}\\s*[x×*/]\\s*\\d.*"))
            text = text + " " + zeilen.get(++i);
        // Umbrochene Bezeichnung („Konstruktionsvollholz, nicht / keilgezinkt …“, „Brettschichtholz GL24, Fichte/ …“)
        for (int k = 0; k < 2 && i + 1 < zeilen.size(); k++) {
            String n = zeilen.get(i + 1);
            if (LV_POS.matcher(n).matches() || FUSS.matcher(n).find() || HINWEIS.matcher(n).find() || n.length() > 60) break;
            if (!(text.matches(".*[,/\\-]$") || text.matches("(?i).*\\b(nicht|und|mit|aus|für)$") || Character.isLowerCase(n.charAt(0)))) break;
            text = text + (text.endsWith("/") || text.endsWith("-") ? "" : " ") + n;
            i++;
        }
        text = text.replaceAll("(?i),\\s*standard$", "").replaceAll("[,;]+$", "").trim();
        String tk = text.toLowerCase(Locale.GERMANY);
        // To-do: jede Position außer Stundensätzen, Anfahrt und Kostenschätzungen
        if (text.length() >= 3 && !KEINE_AUFGABE.matcher(tk).find()) {
            String e = Einheit.norm(einheit);
            if (e.equalsIgnoreCase("psch") || e.equalsIgnoreCase("pausch") || e.equalsIgnoreCase("pauschal")) e = "pauschal";
            String info = "Pos. " + nr + (menge == null ? "" : " · " + ("pauschal".equals(e) ? e : Fmt.mengeText(menge) + (e.isEmpty() ? "" : " " + e)));
            erg.aufgaben.add(new Aufgabe(akt == null ? "" : akt.titel, text, info));
        }
        if (LOHN_EINHEIT.matcher(einheit).matches() || LOHN_TEXT.matcher(tk).find() || text.length() < 3) {
            erg.uebersprungen++;
            // Bei Arbeitspositionen ist die Beschreibung darunter die eigentliche Checkliste („Reinigen der Dachrinnen …“)
            if (!KEINE_AUFGABE.matcher(tk).find()) i = beschreibungAlsAufgaben(nr, zeilen, i, erg, akt);
            return i;
        }
        if (akt == null) {
            akt = new Abschnitt();
            akt.titel = "Material";
            erg.abschnitte.add(akt);
        }
        akt.vorschlaege.add(lvVorschlag(nr, menge, einheit, text));
        return i;
    }

    /** Zeilen unter einer Arbeitsposition als einzelne Aufgaben; Folgezeilen in Kleinschrift hängen am vorigen Punkt. */
    private static int beschreibungAlsAufgaben(String nr, List<String> zeilen, int i, Ergebnis erg, Abschnitt akt) {
        String abschnitt = akt == null ? "" : akt.titel;
        Aufgabe letzte = null;
        boolean hinweisLaeuft = false; // mehrzeiliger Hinweis („Verwendung von PSA nach / eigenem Ermessen …“)
        while (i + 1 < zeilen.size()) {
            String z = zeilen.get(i + 1);
            Matcher p = LV_POS.matcher(z);
            if (p.matches() && (LV_MENGE.matcher(p.group(2).trim()).matches() || p.group(2).trim().isEmpty())) break;
            if (LV_TITEL.matcher(z).matches() || FUSS.matcher(z).find()) break;
            i++;
            boolean endetMitPunkt = z.trim().endsWith(".");
            if (hinweisLaeuft || HINWEIS.matcher(z).find() || z.length() > 120) { letzte = null; hinweisLaeuft = !endetMitPunkt; continue; }
            String t = z.replaceAll("[.;,]+$", "").trim();
            if (t.length() < 3) continue;
            if (Character.isLowerCase(t.charAt(0))) { if (letzte != null) letzte.text = letzte.text + " " + t; continue; }
            if (!Character.isLetter(t.charAt(0)) || woerter(t) < 2 || !TAETIGKEIT.matcher(t).find()) { letzte = null; continue; }
            letzte = new Aufgabe(abschnitt, t, "zu Pos. " + nr);
            erg.aufgaben.add(letzte);
        }
        return i;
    }

    private static Vorschlag lvVorschlag(String nr, Double menge, String einheitRoh, String text) {
        Vorschlag v = new Vorschlag();
        v.lvNr = nr;
        v.quelle = kurz("Pos. " + nr + ": " + text);
        String tk = text.toLowerCase(Locale.GERMANY);
        String einheit = Einheit.norm(einheitRoh);
        v.menge = menge;
        v.einheit = einheit;

        // Maße: 120x120x5000 mm → 12/12 cm, Länge 5,00 m
        Matcher mm = MASSE3.matcher(text);
        if (mm.find()) {
            Double a = Fmt.parse(mm.group(1)), b = Fmt.parse(mm.group(2)), l = mm.group(3) == null ? null : Fmt.parse(mm.group(3));
            if (a != null && b != null) {
                boolean inMm = !"cm".equalsIgnoreCase(mm.group(4)) && (l != null || "mm".equalsIgnoreCase(mm.group(4)) || a > 40 || b > 40);
                double fa = inMm ? a / 10 : a, fb = inMm ? b / 10 : b;
                if (fa > 0 && fb > 0 && fa <= 60 && fb <= 130) { v.b = fa; v.h = fb; }
                if (l != null) v.laengeM = inMm ? l / 1000 : l / 100;
            }
        }

        Regel r = null;
        for (Regel x : REGELN) if (x.muster.matcher(tk).find()) { r = x; break; }
        v.kategorie = r != null ? r.kategorie : Kategorien.zuordnen(text);
        if (r != null) for (String w : r.suchwoerter) v.suchwoerter.add(w);

        boolean holzMasse = v.b != null && v.h != null;
        if (r != null && P.equals(r.typ)) {
            v.typ = P;
            if (holzMasse && v.b < 6) { v.dickeMm = v.b * 10; v.b = null; v.h = null; }
        } else if (holzMasse && einheit.equals("m")) {
            v.typ = L;
        } else if (holzMasse && einheit.equals("Stk")) {
            v.typ = H;
        } else {
            v.typ = M;
            if ("Dämmung".equals(v.kategorie)) {
                Matcher d = DICKE.matcher(text);
                if (d.find()) v.dickeMm = Fmt.parse(d.group(1));
            }
        }
        if (L.equals(v.typ) || H.equals(v.typ)) v.kategorie = "Holz";

        String name = text.replaceAll("\\s{2,}", " ").trim();
        if (name.length() > 60) name = name.substring(0, 57).trim() + "…";
        v.name = name;
        for (String w : tk.split("[^\\p{L}]+")) if (w.length() >= 4 && !STOPP.contains(w) && !v.suchwoerter.contains(w)) v.suchwoerter.add(w);
        return v;
    }

    private static final java.util.Set<String> STOPP = new java.util.HashSet<>(java.util.Arrays.asList(
            "nord", "standard", "liter", "farblos", "stück", "meter", "inkl", "liefern", "lieferung", "montieren", "einbauen",
            "gemäß", "nach", "oder", "gleichwertig", "sowie", "einschl", "einschließlich", "aller", "über", "unter", "für", "mit"));

    // ------------------------------------------------------------------ Inventar

    /** Bester Artikel zum Vorschlag oder null, wenn nichts überzeugend passt. */
    static Katalog.Eintrag besterArtikel(Vorschlag v, List<Katalog.Eintrag> inventar) {
        String quelle = v.quelle.toLowerCase(Locale.GERMANY);
        List<String> textWoerter = new ArrayList<>();
        for (String w : quelle.split("[^\\p{L}\\p{N}]+"))
            if (w.length() >= 5 && !v.suchwoerter.contains(w) && !STOPP.contains(w)) textWoerter.add(w);

        Katalog.Eintrag best = null;
        int bestScore = 0;
        for (Katalog.Eintrag e : inventar) {
            String kat = e.a.kategorie == null || e.a.kategorie.isEmpty() ? Kategorien.zuordnen(e.a.text) : e.a.kategorie;
            boolean katPasst = v.kategorie != null && kat.equalsIgnoreCase(v.kategorie);
            int score = katPasst ? 2 : 0;
            // nur im Artikeltext suchen – nicht im Kategorienamen („Holzschutz, Farbe …“ passt sonst auf alles)
            String atext = (e.a.text + " " + e.a.nr).toLowerCase(Locale.GERMANY);
            int wortTreffer = 0;
            for (String s : v.suchwoerter) if (atext.contains(s)) wortTreffer++;
            if (wortTreffer == 0 && !katPasst) continue;
            score += wortTreffer * 3;
            for (String w : textWoerter) if (atext.contains(w)) score += 2;
            if (H.equals(v.typ) || L.equals(v.typ)) {
                // Holz nur mit passendem Querschnitt vorschlagen – sonst wäre es geraten
                if (v.b == null || v.h == null || e.a.b == null || e.a.h == null) continue;
                boolean gleich = (eq(e.a.b, v.b) && eq(e.a.h, v.h)) || (eq(e.a.b, v.h) && eq(e.a.h, v.b));
                if (!gleich) continue;
                score += 6;
            }
            if (v.dickeMm != null) {
                String mm = Fmt.num(v.dickeMm);
                if (atext.matches(".*(?<![\\d,])" + Pattern.quote(mm) + "\\s*mm.*")) score += 5;
                else if (e.a.h != null && Math.abs(e.a.h * 10 - v.dickeMm) < 0.1) score += 5;
            }
            if (e.a.bestand != null && e.a.bestand > 0) score += 1;
            if (score > bestScore) { bestScore = score; best = e; }
        }
        // Mindestens ein Stichwort-Treffer in passender Kategorie oder mehrere Treffer
        return bestScore >= 5 ? best : null;
    }

    private static boolean eq(double a, double b) { return Math.abs(a - b) < 0.01; }

    // ------------------------------------------------------------------ Übernahme

    /** Gewählte Abschnitte/Vorschläge als Positionen (Überschrift + Material). */
    public static List<Position> positionen(Ergebnis erg) {
        List<Position> out = new ArrayList<>();
        for (Abschnitt a : erg.abschnitte) {
            if (!a.gewaehlt) continue;
            Position t = new Position();
            t.typ = Position.TITEL;
            t.bezeichnung = a.titel;
            out.add(t);
            for (Vorschlag v : a.vorschlaege) if (v.gewaehlt) out.add(position(v));
        }
        return out;
    }

    static Position position(Vorschlag v) {
        Position p = new Position();
        p.typ = v.typ;
        p.bezeichnung = v.name;
        if (v.artikel != null) {
            PositionDialog.anwenden(p, v.artikel.a);
            p.bezeichnung = v.name;
            // Menge aus der Arbeitsanweisung passt zur erkannten Art (z. B. LFM) → diese Art behalten
            if (v.menge != null && !v.typ.equals(p.typ)) p.typ = v.typ;
        }
        p.bemerkung = v.lvNr.isEmpty() ? "Vorschlag aus AW: " + v.quelle : "aus AW Pos. " + v.lvNr;
        switch (p.typ) {
            case Position.HOLZ:
                if (p.breite == null && v.b != null) { p.breite = v.b; p.hoehe = v.h; }
                if (v.menge != null && "Stk".equals(v.einheit)) p.stueck = v.menge;
                if (p.laenge == null && v.laengeM != null) p.laenge = v.laengeM;
                break;
            case Position.LFM:
                if (p.breite == null && v.b != null) { p.breite = v.b; p.hoehe = v.h; }
                if (v.menge != null && "m".equals(v.einheit)) p.laufmeter = v.menge;
                break;
            case Position.PLATTE:
                if (p.hoehe == null && v.dickeMm != null) p.hoehe = v.dickeMm / 10.0;
                if (v.menge != null && "m²".equals(v.einheit)) p.flaeche = v.menge;
                else if (v.menge != null) p.stueck = v.menge;
                if (p.verschnitt == null) p.verschnitt = 10.0;
                break;
            default:
                p.typ = Position.MATERIAL;
                if (v.menge != null) {
                    p.menge = v.menge;
                    p.einheit = v.einheit;
                } else if (p.einheit == null || p.einheit.isEmpty()) {
                    p.einheit = v.einheit;
                }
                if (v.artikel == null && v.dickeMm != null && p.holzart.isEmpty()) p.holzart = Fmt.num(v.dickeMm) + " mm";
        }
        return p;
    }
}
