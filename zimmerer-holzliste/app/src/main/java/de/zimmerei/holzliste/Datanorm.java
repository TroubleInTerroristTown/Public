package de.zimmerei.holzliste;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Liest Artikelstammdaten im DATANORM-Format (Version 4, Semikolon-getrennt) von Holz- und
 * Baustoffhändlern. Unterstützt einzelne Dateien (DATANORM.001 …) und ZIP-Archive.
 *
 * A-Satz (Artikel): A;Kz;Artikelnr;Textkz;Kurztext1;Kurztext2;Preiskz;Preiseinheit;Mengeneinheit;Preis;Rabattgr;Warengruppe;…
 * Preis ohne Dezimaltrennzeichen mit 2 Nachkommastellen; Preiseinheit 0=1, 1=10, 2=100, 3=1000.
 */
public final class Datanorm {

    private Datanorm() {}

    /** Ein Artikel aus dem Händlerkatalog inkl. aus dem Text erkannter Maße. */
    public static final class Artikel {
        public String nr = "", text = "", einheit = "";
        public Double preis;        // € je Mengeneinheit
        public boolean netto;
        public boolean platte;      // als Plattenwerkstoff erkannt
        public Double b, h;         // cm (Querschnitt) – bei Platten: h = Dicke in cm
        public Double l;            // m (Länge; bei Platten Plattenlänge)
        public Double pb;           // cm (Plattenbreite)

        /** Kurze Maßangabe für die Anzeige. */
        public String masse() {
            StringBuilder sb = new StringBuilder();
            if (platte) {
                if (l != null && pb != null) sb.append(Fmt.num(l * 100)).append(" × ").append(Fmt.num(pb)).append(" cm");
                if (h != null) sb.append(sb.length() > 0 ? " · " : "").append(Fmt.num(h * 10)).append(" mm");
            } else {
                if (b != null && h != null) sb.append(Fmt.num(b)).append("/").append(Fmt.num(h)).append(" cm");
                if (l != null) sb.append(sb.length() > 0 ? " · " : "").append(Fmt.fix(l, 2)).append(" m");
            }
            return sb.toString();
        }

        public String preisText() {
            if (preis == null) return "";
            return Fmt.fix(preis, 2) + " €" + (einheit.isEmpty() ? "" : " / " + einheit) + (netto ? " netto" : "");
        }
    }

    public static final class Ergebnis {
        public String haendler = "";
        public final List<Artikel> artikel = new ArrayList<>();
        public int zeilen, aSaetze;
    }

    // ------------------------------------------------------------------ Einlesen

    public static Ergebnis lesen(InputStream in, String dateiname) throws IOException {
        byte[] daten = alles(in);
        Ergebnis e = new Ergebnis();
        Map<String, Artikel> map = new LinkedHashMap<>();
        if (istZip(daten)) {
            try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(daten))) {
                ZipEntry z;
                while ((z = zip.getNextEntry()) != null) {
                    if (z.isDirectory()) continue;
                    String n = z.getName().toUpperCase(Locale.ROOT);
                    // Artikeldateien: DATANORM.001 … (keine Warengruppen-/Rabattdateien)
                    if (n.contains("DATANORM.WRG") || n.contains("DATANORM.RAB")) continue;
                    leseText(dekodieren(alles(zip)), e, map);
                }
            }
        } else {
            leseText(dekodieren(daten), e, map);
        }
        e.artikel.addAll(map.values());
        if (e.haendler.isEmpty() && dateiname != null) e.haendler = dateiname.replaceAll("\\.[^.]*$", "");
        return e;
    }

    private static void leseText(String text, Ergebnis e, Map<String, Artikel> map) throws IOException {
        BufferedReader r = new BufferedReader(new java.io.StringReader(text));
        String line;
        while ((line = r.readLine()) != null) {
            e.zeilen++;
            if (line.length() < 2) continue;
            char typ = Character.toUpperCase(line.charAt(0));
            if (line.charAt(1) != ';') continue;
            String[] f = line.split(";", -1);
            if (typ == 'V' && e.haendler.isEmpty()) {
                e.haendler = haendlerAusVorlauf(f);
            } else if (typ == 'A' && f.length >= 10) {
                e.aSaetze++;
                String kz = f[1].trim().toUpperCase(Locale.ROOT);
                String nr = f[2].trim();
                if (nr.isEmpty()) continue;
                if (kz.equals("L")) { map.remove(nr); continue; }
                Artikel a = new Artikel();
                a.nr = nr;
                a.text = (f[4].trim() + " " + f[5].trim()).trim().replaceAll("\\s+", " ");
                a.netto = f[6].trim().equals("2");
                a.einheit = einheit(f[8]);
                a.preis = preis(f[9], f[7]);
                erkenneMasse(a);
                map.put(nr, a);
            }
        }
    }

    /** Im V-Satz steht der Firmenname als längstes Textfeld. */
    private static String haendlerAusVorlauf(String[] f) {
        String best = "";
        for (int i = 1; i < f.length; i++) {
            String s = f[i].trim();
            if (s.matches(".*[A-Za-zÄÖÜäöü]{3,}.*") && s.length() > best.length()) best = s;
        }
        return best;
    }

    static Double preis(String preis, String preiseinheit) {
        String p = preis.trim();
        if (p.isEmpty()) return null;
        try {
            double v;
            if (p.contains(",") || p.contains(".")) v = Double.parseDouble(p.replace(",", "."));
            else v = Long.parseLong(p) / 100.0;
            int pe = 0;
            try { pe = Integer.parseInt(preiseinheit.trim()); } catch (NumberFormatException ignored) {}
            double teiler = pe == 1 ? 10 : pe == 2 ? 100 : pe == 3 ? 1000 : 1;
            return v / teiler;
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    static String einheit(String s) {
        String u = s.trim().toUpperCase(Locale.ROOT);
        switch (u) {
            case "M2": case "QM": case "M²": return "m²";
            case "M3": case "CBM": case "M³": return "m³";
            case "M": case "LFM": case "LM": return "m";
            case "STK": case "ST": case "STCK": return "Stk";
            case "": return "";
            default: return s.trim();
        }
    }

    // ------------------------------------------------------------------ Maße erkennen

    private static final String ZAHL = "(\\d+(?:[.,]\\d+)?)";
    private static final Pattern DREI = Pattern.compile(ZAHL + "\\s*x\\s*" + ZAHL + "\\s*x\\s*" + ZAHL + "\\s*(mm|cm|m)?(?![a-z])");
    private static final Pattern ZWEI = Pattern.compile("(?<![\\w/.,])" + ZAHL + "\\s*[x/]\\s*" + ZAHL + "(?![\\d.,])\\s*(mm|cm)?(?![a-z0-9²])");
    private static final Pattern LAENGE = Pattern.compile("(?<![\\w.,])(?:l\\s*=?\\s*)?" + ZAHL + "\\s*(m|mm)(?![a-z0-9²³])");
    private static final Pattern DICKE = Pattern.compile("(?<![\\w.,x])" + ZAHL + "\\s*mm(?![a-z0-9²³])");
    private static final Pattern KLEINTEIL = Pattern.compile(
            "schraube|nagel|nägel|klammer|winkel|verbinder|anker|dübel|bolzen|mutter|scheibe|beschlag|band|folie|kleber|dichtband");
    private static final Pattern PLATTE = Pattern.compile(
            "osb|platte|gips|gk[bfi]|spanpl|dreischicht|3-?schicht|mdf|sperrholz|multiplex|fermacell|holzfaser|dwd|hdf|furnier|zementgeb");

    static void erkenneMasse(Artikel a) {
        String t = a.text.toLowerCase(Locale.GERMANY).replace('×', 'x').replace('*', 'x');
        a.platte = "m²".equals(a.einheit) || PLATTE.matcher(t).find();
        if (!a.platte && KLEINTEIL.matcher(t).find()) return; // Schrauben, Nägel … haben keinen Holzquerschnitt

        Matcher m3 = DREI.matcher(t);
        if (m3.find()) {
            double[] v = {zahl(m3.group(1)), zahl(m3.group(2)), zahl(m3.group(3))};
            String u = m3.group(4);
            double zuCm = "cm".equals(u) ? 1 : "m".equals(u) ? 100 : 0.1; // Standard: mm
            if (a.platte) {
                double[] s = v.clone();
                java.util.Arrays.sort(s);
                a.h = s[0] * zuCm;                 // Dicke (cm)
                a.pb = s[1] * zuCm;                // Plattenbreite (cm)
                a.l = s[2] * zuCm / 100.0;         // Plattenlänge (m)
            } else {
                int iMax = v[0] >= v[1] && v[0] >= v[2] ? 0 : v[1] >= v[2] ? 1 : 2;
                List<Double> rest = new ArrayList<>();
                for (int i = 0; i < 3; i++) if (i != iMax) rest.add(v[i]);
                a.b = rest.get(0) * zuCm;
                a.h = rest.get(1) * zuCm;
                a.l = v[iMax] * zuCm / 100.0;
            }
            runden(a);
            return;
        }

        Matcher m2 = ZWEI.matcher(t);
        if (m2.find()) {
            double x = zahl(m2.group(1)), y = zahl(m2.group(2));
            String u = m2.group(3);
            if (a.platte) {
                // Plattenformat, meist in mm (2500x1250) – kleine Werte als m / cm deuten
                double zuCm = "cm".equals(u) ? 1 : ("mm".equals(u) || Math.max(x, y) >= 400) ? 0.1 : (Math.max(x, y) <= 6 ? 100 : 1);
                a.l = Math.max(x, y) * zuCm / 100.0;
                a.pb = Math.min(x, y) * zuCm;
            } else {
                double zuCm = "cm".equals(u) ? 1 : "mm".equals(u) ? 0.1 : (Math.max(x, y) <= 40 ? 1 : 0.1);
                a.b = x * zuCm;
                a.h = y * zuCm;
            }
            t = t.substring(0, m2.start()) + " " + t.substring(m2.end());
        }

        if (a.platte && a.h == null) {
            Matcher d = DICKE.matcher(t);
            if (d.find()) a.h = zahl(d.group(1)) / 10.0;
        }
        if (a.l == null) {
            Matcher l = LAENGE.matcher(t);
            while (l.find()) {
                double v = zahl(l.group(1));
                double meter = "mm".equals(l.group(2)) ? v / 1000.0 : v;
                if (meter >= 0.5 && meter <= 30 && !(a.platte && "mm".equals(l.group(2)) && v < 100)) {
                    a.l = meter;
                    break;
                }
            }
        }
        runden(a);
    }

    private static void runden(Artikel a) {
        a.b = r(a.b); a.h = r(a.h); a.l = r(a.l); a.pb = r(a.pb);
    }

    private static Double r(Double d) {
        return d == null ? null : Math.round(d * 10000) / 10000.0;
    }

    private static double zahl(String s) {
        return Double.parseDouble(s.replace(',', '.'));
    }

    // ------------------------------------------------------------------ Hilfen

    private static boolean istZip(byte[] d) {
        return d.length > 4 && d[0] == 'P' && d[1] == 'K' && d[2] == 3 && d[3] == 4;
    }

    private static byte[] alles(InputStream in) throws IOException {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        byte[] buf = new byte[65536];
        int n;
        while ((n = in.read(buf)) > 0) bos.write(buf, 0, n);
        return bos.toByteArray();
    }

    /** DATANORM ist meist DOS-codiert (CP850); neuere Dateien teils UTF-8 oder Windows-1252. */
    static String dekodieren(byte[] d) {
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(d)).toString();
        } catch (CharacterCodingException ignored) {
        }
        // CP850 vs. Windows-1252: Umlaute in CP850 liegen bei 0x81/0x84/0x94/0x8E/0x99/0x9A/0xE1
        int dos = 0, win = 0;
        for (byte b : d) {
            int c = b & 0xFF;
            if (c == 0x81 || c == 0x84 || c == 0x94 || c == 0x8E || c == 0x99 || c == 0x9A || c == 0xE1) dos++;
            if (c == 0xFC || c == 0xE4 || c == 0xF6 || c == 0xC4 || c == 0xD6 || c == 0xDC || c == 0xDF) win++;
        }
        String cs = dos > win ? "IBM850" : "windows-1252";
        try {
            return new String(d, Charset.forName(cs));
        } catch (Exception ex) {
            return new String(d, StandardCharsets.ISO_8859_1);
        }
    }
}
