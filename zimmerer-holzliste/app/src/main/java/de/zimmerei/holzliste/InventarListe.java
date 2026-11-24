package de.zimmerei.holzliste;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Liest eine eigene Inventar-/Artikelliste aus Excel (.xlsx) oder CSV.
 *
 * Spalten werden über die Überschriften erkannt (Bezeichnung, Artikelnummer, Einheit, Preis, Kategorie, Bestand …).
 * Kategorie: aus einer Kategorie-Spalte, sonst aus Zwischenüberschriften (Zeile nur mit Text), sonst aus dem
 * Blattnamen (bei mehreren Blättern), sonst automatisch aus der Bezeichnung.
 */
public final class InventarListe {

    private InventarListe() {}

    static final int NAME = 0, NR = 1, EINHEIT = 2, PREIS = 3, KATEGORIE = 4, BESTAND = 5, ZUSATZ = 6;

    // normierte Überschriften (klein, ohne Leer-/Satzzeichen) je Spaltenart, genaue Treffer zuerst
    private static final String[][] KOPF = {
            {"bezeichnung", "artikelbezeichnung", "artikel", "beschreibung", "material", "produkt", "produktname", "text",
                    "benennung", "name", "artikelname", "kurztext", "position", "materialbezeichnung"},
            {"artikelnummer", "artnr", "artikelnr", "nr", "nummer", "sku", "bestellnummer", "bestellnr", "materialnummer", "id"},
            {"einheit", "me", "mengeneinheit", "eh", "verkaufseinheit", "ve"},
            {"preis", "ek", "vk", "einzelpreis", "ekpreis", "vkpreis", "nettopreis", "preisnetto", "preis€", "€", "eurostk", "preisje"},
            {"kategorie", "gruppe", "warengruppe", "artikelgruppe", "bereich", "kat", "materialgruppe", "rubrik", "sparte"},
            {"bestand", "lagerbestand", "anzahl", "menge", "stück", "stk", "vorrat", "lager", "istbestand"},
            {"abmessung", "abmessungen", "maße", "masse", "größe", "groesse", "dimension", "typ", "ausführung", "ausfuehrung", "länge", "durchmesser"},
    };

    // ------------------------------------------------------------------ Einlesen

    static boolean istXlsx(byte[] d) {
        if (!Datanorm.istZip(d)) return false;
        String s = new String(d, 0, Math.min(d.length, 200000), StandardCharsets.ISO_8859_1);
        return s.contains("xl/workbook.xml") || s.contains("xl/worksheets/");
    }

    public static Datanorm.Ergebnis lesenXlsx(byte[] daten, String dateiname) throws IOException {
        Map<String, byte[]> dateien = new HashMap<>();
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(daten))) {
            ZipEntry z;
            while ((z = zip.getNextEntry()) != null) {
                String n = z.getName();
                if (n.startsWith("/")) n = n.substring(1);
                if (n.startsWith("xl/") && n.endsWith(".xml") || n.endsWith(".rels")) dateien.put(n, Datanorm.alles(zip));
            }
        }
        List<String> shared = sharedStrings(text(dateien.get("xl/sharedStrings.xml")));

        // Blätter in Reihenfolge der Arbeitsmappe
        Map<String, String> rels = new HashMap<>();
        Matcher mr = Pattern.compile("<Relationship\\b[^>]*>").matcher(text(dateien.get("xl/_rels/workbook.xml.rels")));
        while (mr.find()) {
            String id = attr(mr.group(), "Id"), target = attr(mr.group(), "Target");
            if (id != null && target != null) {
                if (target.startsWith("/")) target = target.substring(1);
                else if (!target.startsWith("xl/")) target = "xl/" + target;
                rels.put(id, target);
            }
        }
        LinkedHashMap<String, String> blaetter = new LinkedHashMap<>();
        Matcher ms = Pattern.compile("<sheet\\b[^>]*>").matcher(text(dateien.get("xl/workbook.xml")));
        while (ms.find()) {
            String name = unescape(attr(ms.group(), "name"));
            String rid = attr(ms.group(), "r:id");
            String pfad = rid == null ? null : rels.get(rid);
            if (pfad != null && dateien.containsKey(pfad)) blaetter.put(pfad, name == null ? "" : name);
        }
        if (blaetter.isEmpty()) { // Fallback ohne Beziehungen
            for (String n : new TreeMap<>(dateien).keySet())
                if (n.startsWith("xl/worksheets/sheet")) blaetter.put(n, n.replaceAll(".*/|\\.xml", ""));
        }

        Datanorm.Ergebnis e = new Datanorm.Ergebnis();
        Map<String, Datanorm.Artikel> map = new LinkedHashMap<>();
        boolean mehrere = blaetter.size() > 1;
        for (Map.Entry<String, String> b : blaetter.entrySet()) {
            List<String[]> zeilen = blatt(text(dateien.get(b.getKey())), shared);
            e.zeilen += zeilen.size();
            ausTabelle(zeilen, b.getValue(), mehrere, map);
        }
        e.artikel.addAll(map.values());
        e.aSaetze = e.artikel.size();
        e.haendler = name(dateiname);
        return e;
    }

    /** Altes Excel-Format (.xls, BIFF8). */
    public static Datanorm.Ergebnis lesenXls(byte[] daten, String dateiname) throws IOException {
        LinkedHashMap<String, List<String[]>> blaetter = XlsLeser.lesen(daten);
        Datanorm.Ergebnis e = new Datanorm.Ergebnis();
        Map<String, Datanorm.Artikel> map = new LinkedHashMap<>();
        boolean mehrere = blaetter.size() > 1;
        for (Map.Entry<String, List<String[]>> b : blaetter.entrySet()) {
            e.zeilen += b.getValue().size();
            ausTabelle(b.getValue(), b.getKey(), mehrere, map);
        }
        e.artikel.addAll(map.values());
        e.aSaetze = e.artikel.size();
        e.haendler = name(dateiname);
        return e;
    }

    public static Datanorm.Ergebnis lesenCsv(String text, String dateiname) {
        List<String[]> zeilen = new ArrayList<>();
        String[] lines = text.split("\\r?\\n");
        char sep = ';';
        if (lines.length > 0) {
            String l0 = lines[0];
            int semi = l0.split(";", -1).length, tab = l0.split("\t", -1).length, komma = l0.split(",", -1).length;
            sep = tab > semi && tab >= komma ? '\t' : (komma > semi && komma > tab ? ',' : ';');
        }
        for (String l : lines) zeilen.add(csvZeile(l, sep));
        Datanorm.Ergebnis e = new Datanorm.Ergebnis();
        Map<String, Datanorm.Artikel> map = new LinkedHashMap<>();
        ausTabelle(zeilen, "", false, map);
        e.zeilen = zeilen.size();
        e.artikel.addAll(map.values());
        e.aSaetze = e.artikel.size();
        e.haendler = name(dateiname);
        return e;
    }

    // ------------------------------------------------------------------ Tabelle → Artikel

    static void ausTabelle(List<String[]> zeilen, String blatt, boolean mehrereBlaetter, Map<String, Datanorm.Artikel> map) {
        // Kopfzeile suchen (erste Zeile mit Bezeichnungs-Spalte + mind. einer weiteren bekannten Spalte)
        int kopf = -1;
        int[] spalte = null;
        for (int r = 0; r < Math.min(zeilen.size(), 25) && kopf < 0; r++) {
            int[] s = spalten(zeilen.get(r));
            int treffer = 0;
            for (int v : s) if (v >= 0) treffer++;
            if (s[NAME] >= 0 && treffer >= 2) { kopf = r; spalte = s; }
        }
        if (spalte == null) { // ohne Überschriften: Spalte A = Bezeichnung
            spalte = new int[]{0, -1, -1, -1, -1, -1, -1};
            kopf = -1;
        }
        String abschnitt = "";
        String blattKat = mehrereBlaetter && !blatt.trim().isEmpty() && !blatt.matches("(?i)(tabelle|sheet|blatt)\\s*\\d*")
                ? blatt.trim() : "";
        for (int r = kopf + 1; r < zeilen.size(); r++) {
            String[] z = zeilen.get(r);
            String name = zelle(z, spalte[NAME]);
            int gefuellt = 0;
            String einzig = "";
            for (String c : z) if (!c.trim().isEmpty()) { gefuellt++; einzig = c.trim(); }
            if (gefuellt == 0) continue;
            // Zwischenüberschrift: nur eine Zelle mit Text (keine Zahl)
            if (gefuellt == 1 && Fmt.parse(einzig) == null && (name.isEmpty() || name.equals(einzig))
                    && zelle(z, spalte[NR]).isEmpty() && zelle(z, spalte[PREIS]).isEmpty()) {
                if (spalte[KATEGORIE] < 0) abschnitt = einzig;
                continue;
            }
            if (name.isEmpty()) continue;
            if (name.toLowerCase(Locale.GERMANY).matches("(summe|gesamt|total).*")) continue;

            Datanorm.Artikel a = new Datanorm.Artikel();
            String zusatz = zelle(z, spalte[ZUSATZ]);
            a.text = (name + (zusatz.isEmpty() || name.contains(zusatz) ? "" : " " + zusatz)).replaceAll("\\s+", " ").trim();
            a.nr = zelle(z, spalte[NR]);
            if (a.nr.isEmpty()) a.nr = "INV-" + (blatt.isEmpty() ? "" : blatt + "-") + (r + 1);
            a.nr = a.nr.replaceAll("\\.0$", "");
            a.einheit = Einheit.norm(zelle(z, spalte[EINHEIT]));
            a.preis = zahl(zelle(z, spalte[PREIS]));
            a.bestand = zahl(zelle(z, spalte[BESTAND]));
            Datanorm.erkenneMasse(a);
            String kat = zelle(z, spalte[KATEGORIE]);
            if (kat.isEmpty()) kat = abschnitt;
            if (kat.isEmpty() && spalte[KATEGORIE] < 0) kat = blattKat;
            if (kat.isEmpty()) kat = Kategorien.zuordnen(a.text);
            a.kategorie = kat;
            // Kategorie wie „Schrauben“ oder „Verbindungsmittel“: kein Holz/keine Platte, auch wenn Maße im Text stehen
            String art = Kategorien.zuordnen(kat);
            if (!art.equals("Holz") && !art.equals("Platten") && !art.equals(Kategorien.SONSTIGES)) {
                a.platte = false; a.b = null; a.h = null; a.l = null; a.pb = null;
            }
            map.put(a.nr, a);
        }
    }

    /** Spaltenindex je Art aus einer Kopfzeile (-1 = nicht vorhanden). */
    static int[] spalten(String[] kopf) {
        int[] s = {-1, -1, -1, -1, -1, -1, -1};
        String[] n = new String[kopf.length];
        for (int i = 0; i < kopf.length; i++) n[i] = norm(kopf[i]);
        // 1. genaue Treffer
        for (int art = 0; art < KOPF.length; art++)
            for (String k : KOPF[art])
                for (int i = 0; i < n.length && s[art] < 0; i++)
                    if (n[i].equals(k) && !vergeben(s, i)) s[art] = i;
        // 2. enthält-Treffer (z. B. "Preis netto €/Stk", "Artikel-Nr.")
        for (int art = 0; art < KOPF.length; art++) {
            if (s[art] >= 0) continue;
            for (String k : KOPF[art]) {
                if (k.length() < 3) continue;
                for (int i = 0; i < n.length && s[art] < 0; i++)
                    if (!n[i].isEmpty() && n[i].contains(k) && !vergeben(s, i)) s[art] = i;
            }
        }
        return s;
    }

    private static boolean vergeben(int[] s, int i) {
        for (int v : s) if (v == i) return true;
        return false;
    }

    static String norm(String s) {
        return s == null ? "" : s.toLowerCase(Locale.GERMANY).replaceAll("[\\s.\\-_:/()\\[\\]]", "");
    }

    private static String zelle(String[] z, int i) {
        return i < 0 || i >= z.length || z[i] == null ? "" : z[i].trim();
    }

    static Double zahl(String s) {
        if (s == null) return null;
        String t = s.replace("€", "").replace("EUR", "").replace(" ", "").trim();
        if (t.isEmpty()) return null;
        // Excel-Zahl "12.5" oder deutsch "12,50" / "1.234,50"
        return Fmt.parse(t);
    }

    private static String name(String dateiname) {
        if (dateiname == null || dateiname.isEmpty()) return "Inventarliste";
        return dateiname.replaceAll("\\.[^.]*$", "");
    }

    // ------------------------------------------------------------------ XLSX-XML

    private static String text(byte[] b) {
        return b == null ? "" : new String(b, StandardCharsets.UTF_8);
    }

    static List<String> sharedStrings(String xml) {
        List<String> out = new ArrayList<>();
        Matcher si = Pattern.compile("<si>(.*?)</si>|<si/>", Pattern.DOTALL).matcher(xml);
        Pattern t = Pattern.compile("<t(?:\\s[^>]*)?>(.*?)</t>", Pattern.DOTALL);
        while (si.find()) {
            StringBuilder sb = new StringBuilder();
            if (si.group(1) != null) {
                // Lautschrift (rPh) nicht mitnehmen
                Matcher m = t.matcher(si.group(1).replaceAll("(?s)<rPh\\b.*?</rPh>", ""));
                while (m.find()) sb.append(m.group(1));
            }
            out.add(unescape(sb.toString()));
        }
        return out;
    }

    private static final Pattern ROW = Pattern.compile("<row\\b[^>]*?(?:/>|>(.*?)</row>)", Pattern.DOTALL);
    private static final Pattern CELL = Pattern.compile("<c\\b([^>]*?)(?:/>|>(.*?)</c>)", Pattern.DOTALL);
    private static final Pattern V = Pattern.compile("<v>(.*?)</v>", Pattern.DOTALL);
    private static final Pattern IS_T = Pattern.compile("<t(?:\\s[^>]*)?>(.*?)</t>", Pattern.DOTALL);

    static List<String[]> blatt(String xml, List<String> shared) {
        List<String[]> out = new ArrayList<>();
        Matcher rm = ROW.matcher(xml);
        while (rm.find()) {
            String inhalt = rm.group(1);
            List<String> zeile = new ArrayList<>();
            if (inhalt != null) {
                Matcher cm = CELL.matcher(inhalt);
                int naechste = 0;
                while (cm.find()) {
                    String attrs = cm.group(1), body = cm.group(2) == null ? "" : cm.group(2);
                    String ref = attr(attrs, "r");
                    int col = ref == null ? naechste : spalteAus(ref);
                    while (zeile.size() < col) zeile.add("");
                    String typ = attr(attrs, "t");
                    String wert = "";
                    if ("inlineStr".equals(typ)) {
                        Matcher m = IS_T.matcher(body);
                        StringBuilder sb = new StringBuilder();
                        while (m.find()) sb.append(m.group(1));
                        wert = unescape(sb.toString());
                    } else {
                        Matcher v = V.matcher(body);
                        if (v.find()) {
                            wert = unescape(v.group(1));
                            if ("s".equals(typ)) {
                                try { wert = shared.get(Integer.parseInt(wert.trim())); } catch (Exception ex) { wert = ""; }
                            } else if ("b".equals(typ)) {
                                wert = "1".equals(wert) ? "ja" : "nein";
                            } else if (typ == null || "n".equals(typ)) {
                                wert = zahlText(wert);
                            }
                        }
                    }
                    if (zeile.size() == col) zeile.add(wert); else zeile.set(col, wert);
                    naechste = col + 1;
                }
            }
            out.add(zeile.toArray(new String[0]));
        }
        return out;
    }

    /** "12.5" / "1E-3" / "3.0000000000000004" → gut lesbarer Wert ohne Rundungsrauschen. */
    private static String zahlText(String v) {
        try {
            double d = Double.parseDouble(v.trim());
            double r = Math.round(d * 1e6) / 1e6;
            if (r == Math.rint(r) && Math.abs(r) < 1e15) return Long.toString((long) r);
            return Double.toString(r);
        } catch (NumberFormatException e) {
            return v;
        }
    }

    static int spalteAus(String ref) {
        int c = 0;
        for (int i = 0; i < ref.length(); i++) {
            char ch = ref.charAt(i);
            if (ch < 'A' || ch > 'Z') break;
            c = c * 26 + (ch - 'A' + 1);
        }
        return Math.max(0, c - 1);
    }

    static String attr(String tag, String name) {
        Matcher m = Pattern.compile("(?:^|\\s)" + Pattern.quote(name) + "=\"([^\"]*)\"").matcher(tag);
        return m.find() ? m.group(1) : null;
    }

    static String unescape(String s) {
        if (s == null) return null;
        if (s.indexOf('&') < 0 && s.indexOf("_x") < 0) return s;
        StringBuilder sb = new StringBuilder();
        Matcher m = Pattern.compile("&(amp|lt|gt|quot|apos|#\\d+|#x[0-9a-fA-F]+);").matcher(s);
        int last = 0;
        while (m.find()) {
            sb.append(s, last, m.start());
            String e = m.group(1);
            switch (e) {
                case "amp": sb.append('&'); break;
                case "lt": sb.append('<'); break;
                case "gt": sb.append('>'); break;
                case "quot": sb.append('"'); break;
                case "apos": sb.append('\''); break;
                default:
                    int cp = e.startsWith("#x") ? Integer.parseInt(e.substring(2), 16) : Integer.parseInt(e.substring(1));
                    sb.appendCodePoint(cp);
            }
            last = m.end();
        }
        sb.append(s.substring(last));
        // Excel-Steuerzeichen wie _x000D_
        return sb.toString().replaceAll("_x000[dDaA]_", " ");
    }

    private static String[] csvZeile(String l, char sep) {
        List<String> out = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        boolean q = false;
        for (int i = 0; i < l.length(); i++) {
            char c = l.charAt(i);
            if (c == '"') {
                if (q && i + 1 < l.length() && l.charAt(i + 1) == '"') { cur.append('"'); i++; }
                else q = !q;
            } else if (c == sep && !q) {
                out.add(cur.toString());
                cur.setLength(0);
            } else cur.append(c);
        }
        out.add(cur.toString());
        return out.toArray(new String[0]);
    }
}
