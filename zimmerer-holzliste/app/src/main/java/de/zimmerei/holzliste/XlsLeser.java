package de.zimmerei.holzliste;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Liest Zellwerte aus alten Excel-Dateien (.xls, BIFF8 / Excel 97–2003) ohne externe Bibliothek.
 * Unterstützt: Texte (SST/LABEL), Zahlen (NUMBER/RK/MULRK) und Formel-Ergebnisse. Formate werden ignoriert.
 */
public final class XlsLeser {

    private XlsLeser() {}

    static boolean istXls(byte[] d) {
        return d.length > 512 && (d[0] & 0xFF) == 0xD0 && (d[1] & 0xFF) == 0xCF && (d[2] & 0xFF) == 0x11 && (d[3] & 0xFF) == 0xE0;
    }

    /** Blattname → Zeilen (Zellen als Text, Lücken als ""). */
    public static LinkedHashMap<String, List<String[]>> lesen(byte[] datei) throws IOException {
        byte[] wb = workbookStream(datei);
        if (wb == null) throw new IOException("Keine Excel-Arbeitsmappe in der Datei gefunden");
        return biff(wb);
    }

    // ------------------------------------------------------------------ OLE2 (Compound File)

    private static final int FREE = -1, ENDOFCHAIN = -2;

    private static byte[] workbookStream(byte[] d) throws IOException {
        ByteBuffer b = ByteBuffer.wrap(d).order(ByteOrder.LITTLE_ENDIAN);
        int secShift = b.getShort(30) & 0xFFFF;
        int miniShift = b.getShort(32) & 0xFFFF;
        int secSize = 1 << secShift, miniSize = 1 << miniShift;
        int numFat = b.getInt(44);
        int firstDir = b.getInt(48);
        int miniCutoff = b.getInt(56);
        int firstMiniFat = b.getInt(60);
        int firstDifat = b.getInt(68);
        int numDifat = b.getInt(72);

        // FAT-Sektoren aus DIFAT
        List<Integer> fatSecs = new ArrayList<>();
        for (int i = 0; i < 109 && fatSecs.size() < numFat; i++) {
            int s = b.getInt(76 + i * 4);
            if (s >= 0) fatSecs.add(s);
        }
        int dif = firstDifat;
        for (int n = 0; n < numDifat && dif >= 0 && fatSecs.size() < numFat; n++) {
            int off = (dif + 1) * secSize;
            for (int i = 0; i < secSize / 4 - 1 && fatSecs.size() < numFat; i++) {
                int s = b.getInt(off + i * 4);
                if (s >= 0) fatSecs.add(s);
            }
            dif = b.getInt(off + secSize - 4);
        }
        int[] fat = new int[fatSecs.size() * secSize / 4];
        int k = 0;
        for (int s : fatSecs) {
            int off = (s + 1) * secSize;
            for (int i = 0; i < secSize / 4; i++) fat[k++] = off + i * 4 + 4 <= d.length ? b.getInt(off + i * 4) : FREE;
        }

        byte[] dir = kette(d, fat, firstDir, secSize, -1);
        ByteBuffer db = ByteBuffer.wrap(dir).order(ByteOrder.LITTLE_ENDIAN);
        int rootStart = -1;
        long rootSize = 0;
        int wbStart = -1;
        long wbSize = 0;
        for (int off = 0; off + 128 <= dir.length; off += 128) {
            int nameLen = db.getShort(off + 64) & 0xFFFF;
            int typ = dir[off + 66];
            if (nameLen < 2 || nameLen > 64) continue;
            String name = new String(dir, off, nameLen - 2, StandardCharsets.UTF_16LE);
            int start = db.getInt(off + 116);
            long size = db.getInt(off + 120) & 0xFFFFFFFFL;
            if (typ == 5) { rootStart = start; rootSize = size; }
            else if (typ == 2 && (name.equals("Workbook") || name.equals("Book")) && wbStart < 0) { wbStart = start; wbSize = size; }
        }
        if (wbStart < 0) return null;
        if (wbSize >= miniCutoff) return kette(d, fat, wbStart, secSize, wbSize);

        // kleine Datei: Mini-Stream
        byte[] miniStream = kette(d, fat, rootStart, secSize, rootSize);
        byte[] miniFatBytes = kette(d, fat, firstMiniFat, secSize, -1);
        ByteBuffer mf = ByteBuffer.wrap(miniFatBytes).order(ByteOrder.LITTLE_ENDIAN);
        int[] miniFat = new int[miniFatBytes.length / 4];
        for (int i = 0; i < miniFat.length; i++) miniFat[i] = mf.getInt(i * 4);
        byte[] out = new byte[(int) wbSize];
        int pos = 0, s = wbStart, guard = 0;
        while (s >= 0 && pos < out.length && guard++ < 10_000_000) {
            int n = Math.min(miniSize, out.length - pos);
            System.arraycopy(miniStream, s * miniSize, out, pos, n);
            pos += n;
            s = s < miniFat.length ? miniFat[s] : ENDOFCHAIN;
        }
        return out;
    }

    private static byte[] kette(byte[] d, int[] fat, int start, int secSize, long size) {
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        int s = start, guard = 0;
        while (s >= 0 && s < fat.length && guard++ < 10_000_000) {
            int off = (s + 1) * secSize;
            if (off + secSize > d.length) { out.write(d, off, Math.max(0, d.length - off)); break; }
            out.write(d, off, secSize);
            s = fat[s];
        }
        byte[] r = out.toByteArray();
        if (size >= 0 && size < r.length) {
            byte[] t = new byte[(int) size];
            System.arraycopy(r, 0, t, 0, t.length);
            return t;
        }
        return r;
    }

    // ------------------------------------------------------------------ BIFF8

    private static LinkedHashMap<String, List<String[]>> biff(byte[] w) {
        ByteBuffer b = ByteBuffer.wrap(w).order(ByteOrder.LITTLE_ENDIAN);
        Map<Integer, String> blattAnOffset = new LinkedHashMap<>();
        List<String> sst = new ArrayList<>();
        LinkedHashMap<String, List<String[]>> out = new LinkedHashMap<>();

        TreeMap<Integer, TreeMap<Integer, String>> zellen = null;
        String blatt = null;
        boolean imBlatt = false;
        int[] formelZelle = null;
        List<byte[]> sstTeile = null;

        int pos = 0;
        while (pos + 4 <= w.length) {
            int typ = b.getShort(pos) & 0xFFFF;
            int len = b.getShort(pos + 2) & 0xFFFF;
            int data = pos + 4;
            if (data + len > w.length) break;

            if (sstTeile != null && typ != 0x003C) { // SST fertig
                sst = sstLesen(sstTeile);
                sstTeile = null;
            }
            switch (typ) {
                case 0x0809: { // BOF
                    int art = b.getShort(data + 2) & 0xFFFF;
                    if (art == 0x0010) {
                        blatt = blattAnOffset.getOrDefault(pos, "Tabelle" + (out.size() + 1));
                        zellen = new TreeMap<>();
                        imBlatt = true;
                    }
                    break;
                }
                case 0x000A: // EOF
                    if (imBlatt && zellen != null) out.put(eindeutig(out, blatt), tabelle(zellen));
                    imBlatt = false;
                    zellen = null;
                    break;
                case 0x0085: { // BOUNDSHEET
                    int off = b.getInt(data);
                    int cch = w[data + 6] & 0xFF;
                    int flags = w[data + 7] & 0xFF;
                    String name = (flags & 1) != 0
                            ? new String(w, data + 8, Math.min(cch * 2, len - 8), StandardCharsets.UTF_16LE)
                            : new String(w, data + 8, Math.min(cch, len - 8), StandardCharsets.ISO_8859_1);
                    blattAnOffset.put(off, name);
                    break;
                }
                case 0x00FC: // SST
                    sstTeile = new ArrayList<>();
                    sstTeile.add(java.util.Arrays.copyOfRange(w, data + 8, data + len));
                    break;
                case 0x003C: // CONTINUE
                    if (sstTeile != null) sstTeile.add(java.util.Arrays.copyOfRange(w, data, data + len));
                    break;
                case 0x00FD: // LABELSST
                    if (zellen != null) {
                        int idx = b.getInt(data + 6);
                        setze(zellen, b.getShort(data) & 0xFFFF, b.getShort(data + 2) & 0xFFFF, idx >= 0 && idx < sst.size() ? sst.get(idx) : "");
                    }
                    break;
                case 0x0204: // LABEL
                    if (zellen != null) {
                        int cch = b.getShort(data + 6) & 0xFFFF;
                        boolean wide = (w[data + 8] & 1) != 0;
                        String s = wide ? new String(w, data + 9, Math.min(cch * 2, len - 9), StandardCharsets.UTF_16LE)
                                : new String(w, data + 9, Math.min(cch, len - 9), StandardCharsets.ISO_8859_1);
                        setze(zellen, b.getShort(data) & 0xFFFF, b.getShort(data + 2) & 0xFFFF, s);
                    }
                    break;
                case 0x0203: // NUMBER
                    if (zellen != null) setze(zellen, b.getShort(data) & 0xFFFF, b.getShort(data + 2) & 0xFFFF, zahl(b.getDouble(data + 6)));
                    break;
                case 0x027E: // RK
                    if (zellen != null) setze(zellen, b.getShort(data) & 0xFFFF, b.getShort(data + 2) & 0xFFFF, zahl(rk(b.getInt(data + 6))));
                    break;
                case 0x00BD: { // MULRK
                    if (zellen == null) break;
                    int row = b.getShort(data) & 0xFFFF, col = b.getShort(data + 2) & 0xFFFF;
                    int n = (len - 6) / 6;
                    for (int i = 0; i < n; i++) setze(zellen, row, col + i, zahl(rk(b.getInt(data + 4 + i * 6 + 2))));
                    break;
                }
                case 0x0006: { // FORMULA
                    if (zellen == null) break;
                    int row = b.getShort(data) & 0xFFFF, col = b.getShort(data + 2) & 0xFFFF;
                    if ((b.getShort(data + 12) & 0xFFFF) == 0xFFFF) {
                        int art = w[data + 6] & 0xFF;
                        if (art == 0) formelZelle = new int[]{row, col}; // Text folgt im STRING-Satz
                        else if (art == 1) setze(zellen, row, col, w[data + 8] != 0 ? "ja" : "nein");
                    } else {
                        setze(zellen, row, col, zahl(b.getDouble(data + 6)));
                    }
                    break;
                }
                case 0x0207: // STRING (Ergebnis einer Text-Formel)
                    if (zellen != null && formelZelle != null && len >= 3) {
                        int cch = b.getShort(data) & 0xFFFF;
                        boolean wide = (w[data + 2] & 1) != 0;
                        String s = wide ? new String(w, data + 3, Math.min(cch * 2, len - 3), StandardCharsets.UTF_16LE)
                                : new String(w, data + 3, Math.min(cch, len - 3), StandardCharsets.ISO_8859_1);
                        setze(zellen, formelZelle[0], formelZelle[1], s);
                    }
                    formelZelle = null;
                    break;
                default:
                    break;
            }
            pos = data + len;
        }
        return out;
    }

    private static String eindeutig(Map<String, ?> m, String name) {
        String n = name == null ? "Tabelle" : name;
        String r = n;
        for (int i = 2; m.containsKey(r); i++) r = n + " (" + i + ")";
        return r;
    }

    private static void setze(TreeMap<Integer, TreeMap<Integer, String>> z, int row, int col, String v) {
        z.computeIfAbsent(row, k -> new TreeMap<>()).put(col, v == null ? "" : v);
    }

    private static List<String[]> tabelle(TreeMap<Integer, TreeMap<Integer, String>> z) {
        List<String[]> out = new ArrayList<>();
        int letzte = -1;
        for (Map.Entry<Integer, TreeMap<Integer, String>> e : z.entrySet()) {
            while (letzte + 1 < e.getKey() && out.size() < 1_000_000) { out.add(new String[0]); letzte++; }
            int max = e.getValue().lastKey();
            String[] r = new String[max + 1];
            java.util.Arrays.fill(r, "");
            for (Map.Entry<Integer, String> c : e.getValue().entrySet()) r[c.getKey()] = c.getValue();
            out.add(r);
            letzte = e.getKey();
        }
        return out;
    }

    private static double rk(int rk) {
        double v;
        if ((rk & 2) != 0) v = rk >> 2;
        else v = Double.longBitsToDouble(((long) (rk & 0xFFFFFFFC)) << 32);
        return (rk & 1) != 0 ? v / 100.0 : v;
    }

    private static String zahl(double d) {
        if (Double.isNaN(d) || Double.isInfinite(d)) return "";
        double r = Math.round(d * 1e6) / 1e6;
        if (r == Math.rint(r) && Math.abs(r) < 1e15) return Long.toString((long) r);
        return Double.toString(r);
    }

    // ------------------------------------------------------------------ Shared Strings (über CONTINUE-Sätze verteilt)

    private static final class Leser {
        final List<byte[]> teile;
        int t = 0, p = 0;
        Leser(List<byte[]> teile) { this.teile = teile; }

        boolean ende() {
            while (t < teile.size() && p >= teile.get(t).length) { t++; p = 0; }
            return t >= teile.size();
        }

        int u8() {
            if (ende()) throw new IndexOutOfBoundsException();
            return teile.get(t)[p++] & 0xFF;
        }

        int u16() { return u8() | (u8() << 8); }

        int u32() { return u16() | (u16() << 16); }

        void skip(long n) { for (long i = 0; i < n; i++) u8(); }
    }

    private static List<String> sstLesen(List<byte[]> teile) {
        List<String> out = new ArrayList<>();
        Leser r = new Leser(teile);
        try {
            while (!r.ende()) {
                int cch = r.u16();
                int flags = r.u8();
                int runs = (flags & 0x08) != 0 ? r.u16() : 0;
                long ext = (flags & 0x04) != 0 ? (r.u32() & 0xFFFFFFFFL) : 0;
                boolean wide = (flags & 0x01) != 0;
                StringBuilder sb = new StringBuilder(cch);
                int rest = cch;
                while (rest > 0) {
                    if (r.t < teile.size() && r.p >= teile.get(r.t).length) {
                        // Zeichen gehen im nächsten CONTINUE weiter: neues Optionsbyte
                        r.t++;
                        r.p = 0;
                        if (r.t >= teile.size()) break;
                        wide = (r.u8() & 0x01) != 0;
                    }
                    byte[] seg = teile.get(r.t);
                    int verfuegbar = (seg.length - r.p) / (wide ? 2 : 1);
                    int n = Math.min(rest, Math.max(1, verfuegbar));
                    if (wide) {
                        sb.append(new String(seg, r.p, Math.min(n * 2, seg.length - r.p), StandardCharsets.UTF_16LE));
                        r.p += n * 2;
                    } else {
                        sb.append(new String(seg, r.p, Math.min(n, seg.length - r.p), StandardCharsets.ISO_8859_1));
                        r.p += n;
                    }
                    rest -= n;
                }
                r.skip(runs * 4L + ext);
                out.add(sb.toString());
            }
        } catch (IndexOutOfBoundsException ignored) {
        }
        return out;
    }
}
