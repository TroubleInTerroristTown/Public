package de.zimmerei.holzliste;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;
import java.util.TreeMap;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Kleiner, abhängigkeitsfreier Writer für Office-Open-XML-Arbeitsmappen (.xlsx).
 * Unterstützt Formatvorlagen (Schrift, Füllung, Rahmen, Zahlenformat, Ausrichtung),
 * Formeln mit zwischengespeicherten Werten, verbundene Zellen, fixierte Bereiche,
 * AutoFilter, Spaltenbreiten, Zeilenhöhen und Seiteneinrichtung für den Druck.
 */
public class XlsxWriter {

    // ---------------------------------------------------------------- Styles

    public static final class Style {
        boolean bold, italic;
        double fontSize = 10;
        String fontColor = "FF000000";
        String fill;            // ARGB, null = keine
        String border;          // null, "thin", "medium"
        String borderColor = "FF9E9E9E";
        boolean borderTopMedium, borderBottomMedium;
        String numFmt;          // z. B. "0.000"
        String hAlign;          // left, center, right
        String vAlign = "center";
        boolean wrap;

        public Style copy() {
            Style s = new Style();
            s.bold = bold; s.italic = italic; s.fontSize = fontSize; s.fontColor = fontColor;
            s.fill = fill; s.border = border; s.borderColor = borderColor;
            s.borderTopMedium = borderTopMedium; s.borderBottomMedium = borderBottomMedium;
            s.numFmt = numFmt; s.hAlign = hAlign; s.vAlign = vAlign; s.wrap = wrap;
            return s;
        }
        public Style bold() { Style s = copy(); s.bold = true; return s; }
        public Style italic() { Style s = copy(); s.italic = true; return s; }
        public Style size(double pt) { Style s = copy(); s.fontSize = pt; return s; }
        public Style color(String argb) { Style s = copy(); s.fontColor = argb; return s; }
        public Style fill(String argb) { Style s = copy(); s.fill = argb; return s; }
        public Style border(String b) { Style s = copy(); s.border = b; return s; }
        public Style borderColor(String c) { Style s = copy(); s.borderColor = c; return s; }
        public Style topMedium() { Style s = copy(); s.borderTopMedium = true; return s; }
        public Style bottomMedium() { Style s = copy(); s.borderBottomMedium = true; return s; }
        public Style fmt(String f) { Style s = copy(); s.numFmt = f; return s; }
        public Style align(String a) { Style s = copy(); s.hAlign = a; return s; }
        public Style valign(String a) { Style s = copy(); s.vAlign = a; return s; }
        public Style wrap() { Style s = copy(); s.wrap = true; return s; }

        String fontKey() { return bold + "|" + italic + "|" + fontSize + "|" + fontColor; }
        String borderKey() { return border + "|" + borderColor + "|" + borderTopMedium + "|" + borderBottomMedium; }
    }

    public static Style style() { return new Style(); }

    // ---------------------------------------------------------------- Cells / Sheets

    static final class Cell {
        Object value;     // String, Double, null
        String formula;   // ohne führendes '='
        Style style;
    }

    public static final class Sheet {
        final String name;
        final TreeMap<Integer, TreeMap<Integer, Cell>> rows = new TreeMap<>();
        final Map<Integer, Double> colWidths = new TreeMap<>();
        final Map<Integer, Double> rowHeights = new TreeMap<>();
        final List<String> merges = new ArrayList<>();
        int freezeRow = -1, freezeCol = -1;
        String autoFilter;
        boolean landscape = true;
        boolean fitToWidth = true;
        int printTitleFirstRow = -1, printTitleLastRow = -1;
        String headerCenter, footerLeft, footerRight;
        String tabColor;
        boolean showGrid = true;

        Sheet(String name) { this.name = name; }

        Cell cell(int r, int c) {
            TreeMap<Integer, Cell> row = rows.get(r);
            if (row == null) { row = new TreeMap<>(); rows.put(r, row); }
            Cell cell = row.get(c);
            if (cell == null) { cell = new Cell(); row.put(c, cell); }
            return cell;
        }

        /** Zeile/Spalte 0-basiert. value: String, Number oder null (nur Format). */
        public Sheet set(int r, int c, Object value, Style st) {
            Cell cell = cell(r, c);
            if (value instanceof Number) cell.value = ((Number) value).doubleValue();
            else if (value != null) cell.value = value.toString();
            else cell.value = null;
            cell.formula = null;
            cell.style = st;
            return this;
        }

        public Sheet formula(int r, int c, String formula, Double cached, Style st) {
            Cell cell = cell(r, c);
            cell.formula = formula;
            cell.value = cached;
            cell.style = st;
            return this;
        }

        /** Füllt einen Bereich mit einer Formatvorlage (ohne Werte zu ändern). */
        public Sheet styleRange(int r1, int c1, int r2, int c2, Style st) {
            for (int r = r1; r <= r2; r++)
                for (int c = c1; c <= c2; c++) {
                    Cell cell = cell(r, c);
                    cell.style = st;
                }
            return this;
        }

        public Sheet merge(int r1, int c1, int r2, int c2) {
            merges.add(ref(r1, c1) + ":" + ref(r2, c2));
            return this;
        }

        public Sheet width(int c, double chars) { colWidths.put(c, chars); return this; }
        public Sheet height(int r, double pt) { rowHeights.put(r, pt); return this; }
        public Sheet freeze(int row, int col) { freezeRow = row; freezeCol = col; return this; }
        public Sheet autoFilter(int r1, int c1, int r2, int c2) { autoFilter = ref(r1, c1) + ":" + ref(r2, c2); return this; }
        public Sheet printTitles(int firstRow, int lastRow) { printTitleFirstRow = firstRow; printTitleLastRow = lastRow; return this; }
        public Sheet portrait() { landscape = false; return this; }
        public Sheet headerFooter(String center, String fLeft, String fRight) {
            headerCenter = center; footerLeft = fLeft; footerRight = fRight; return this;
        }
        public Sheet tabColor(String argb) { tabColor = argb; return this; }
        public Sheet hideGrid() { showGrid = false; return this; }
    }

    // ---------------------------------------------------------------- Workbook

    private final List<Sheet> sheets = new ArrayList<>();
    public String title = "", author = "";

    public Sheet addSheet(String name) {
        Sheet s = new Sheet(sanitizeSheetName(name));
        sheets.add(s);
        return s;
    }

    private static String sanitizeSheetName(String n) {
        n = n.replaceAll("[\\\\/?*\\[\\]:]", "_");
        if (n.length() > 31) n = n.substring(0, 31);
        return n.isEmpty() ? "Tabelle" : n;
    }

    public static String colName(int c) {
        StringBuilder sb = new StringBuilder();
        c++;
        while (c > 0) {
            int m = (c - 1) % 26;
            sb.insert(0, (char) ('A' + m));
            c = (c - 1) / 26;
        }
        return sb.toString();
    }

    public static String ref(int r, int c) { return colName(c) + (r + 1); }
    public static String absRef(int r, int c) { return "$" + colName(c) + "$" + (r + 1); }

    // ---------------------------------------------------------------- Serialisierung

    private final Map<String, Integer> sharedStrings = new LinkedHashMap<>();
    private int sharedStringCount = 0;

    private final List<String> fonts = new ArrayList<>();
    private final Map<String, Integer> fontIdx = new LinkedHashMap<>();
    private final List<String> fills = new ArrayList<>();
    private final Map<String, Integer> fillIdx = new LinkedHashMap<>();
    private final List<String> borders = new ArrayList<>();
    private final Map<String, Integer> borderIdx = new LinkedHashMap<>();
    private final Map<String, Integer> numFmtIdx = new LinkedHashMap<>();
    private final List<String> xfs = new ArrayList<>();
    private final Map<String, Integer> xfIdx = new LinkedHashMap<>();
    private final Map<Style, Integer> styleCache = new java.util.IdentityHashMap<>();

    private int sst(String s) {
        sharedStringCount++;
        Integer i = sharedStrings.get(s);
        if (i == null) { i = sharedStrings.size(); sharedStrings.put(s, i); }
        return i;
    }

    private void initStyles() {
        // Standard-Einträge, die Excel erwartet
        Style def = new Style();
        fontIdx.put(def.fontKey(), 0);
        fonts.add(fontXml(def));
        fills.add("<fill><patternFill patternType=\"none\"/></fill>");
        fills.add("<fill><patternFill patternType=\"gray125\"/></fill>");
        borders.add("<border><left/><right/><top/><bottom/><diagonal/></border>");
        borderIdx.put("null|FF9E9E9E|false|false", 0);
        xfs.add("<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>");
        xfIdx.put(xfs.get(0), 0);
    }

    private static String fontXml(Style s) {
        StringBuilder sb = new StringBuilder("<font>");
        if (s.bold) sb.append("<b/>");
        if (s.italic) sb.append("<i/>");
        sb.append("<sz val=\"").append(num(s.fontSize)).append("\"/>");
        sb.append("<color rgb=\"").append(s.fontColor).append("\"/>");
        sb.append("<name val=\"Calibri\"/><family val=\"2\"/></font>");
        return sb.toString();
    }

    private int styleId(Style s) {
        if (s == null) return 0;
        Integer cached = styleCache.get(s);
        if (cached != null) return cached;

        Integer f = fontIdx.get(s.fontKey());
        if (f == null) { f = fonts.size(); fonts.add(fontXml(s)); fontIdx.put(s.fontKey(), f); }

        int fillId = 0;
        if (s.fill != null) {
            Integer fi = fillIdx.get(s.fill);
            if (fi == null) {
                fi = fills.size();
                fills.add("<fill><patternFill patternType=\"solid\"><fgColor rgb=\"" + s.fill
                        + "\"/><bgColor indexed=\"64\"/></patternFill></fill>");
                fillIdx.put(s.fill, fi);
            }
            fillId = fi;
        }

        int borderId = 0;
        if (s.border != null || s.borderTopMedium || s.borderBottomMedium) {
            Integer bi = borderIdx.get(s.borderKey());
            if (bi == null) {
                bi = borders.size();
                String side = s.border == null ? null : s.border;
                StringBuilder b = new StringBuilder("<border>");
                b.append(side("left", side, s.borderColor));
                b.append(side("right", side, s.borderColor));
                b.append(side("top", s.borderTopMedium ? "medium" : side, s.borderTopMedium ? "FF000000" : s.borderColor));
                b.append(side("bottom", s.borderBottomMedium ? "medium" : side, s.borderBottomMedium ? "FF000000" : s.borderColor));
                b.append("<diagonal/></border>");
                borders.add(b.toString());
                borderIdx.put(s.borderKey(), bi);
            }
            borderId = bi;
        }

        int numFmtId = 0;
        if (s.numFmt != null) {
            Integer n = numFmtIdx.get(s.numFmt);
            if (n == null) { n = 164 + numFmtIdx.size(); numFmtIdx.put(s.numFmt, n); }
            numFmtId = n;
        }

        StringBuilder x = new StringBuilder("<xf numFmtId=\"").append(numFmtId)
                .append("\" fontId=\"").append(f)
                .append("\" fillId=\"").append(fillId)
                .append("\" borderId=\"").append(borderId).append("\" xfId=\"0\"");
        if (numFmtId != 0) x.append(" applyNumberFormat=\"1\"");
        if (f != 0) x.append(" applyFont=\"1\"");
        if (fillId != 0) x.append(" applyFill=\"1\"");
        if (borderId != 0) x.append(" applyBorder=\"1\"");
        x.append(" applyAlignment=\"1\"><alignment");
        if (s.hAlign != null) x.append(" horizontal=\"").append(s.hAlign).append('"');
        if (s.vAlign != null) x.append(" vertical=\"").append(s.vAlign).append('"');
        if (s.wrap) x.append(" wrapText=\"1\"");
        x.append("/></xf>");
        String key = x.toString();
        Integer id = xfIdx.get(key);
        if (id == null) { id = xfs.size(); xfs.add(key); xfIdx.put(key, id); }
        styleCache.put(s, id);
        return id;
    }

    private static String side(String name, String style, String color) {
        if (style == null) return "<" + name + "/>";
        return "<" + name + " style=\"" + style + "\"><color rgb=\"" + color + "\"/></" + name + ">";
    }

    public void write(OutputStream out) throws IOException {
        initStyles();
        // Blätter zuerst serialisieren (füllt Shared Strings und Styles)
        List<String> sheetXml = new ArrayList<>();
        for (Sheet s : sheets) sheetXml.add(sheetXml(s));

        ZipOutputStream zip = new ZipOutputStream(out);
        put(zip, "[Content_Types].xml", contentTypes());
        put(zip, "_rels/.rels",
                "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                        + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                        + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>"
                        + "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>"
                        + "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>"
                        + "</Relationships>");
        put(zip, "docProps/core.xml", coreXml());
        put(zip, "docProps/app.xml",
                "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                        + "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\">"
                        + "<Application>Holzliste</Application></Properties>");
        put(zip, "xl/workbook.xml", workbookXml());
        put(zip, "xl/_rels/workbook.xml.rels", workbookRels());
        put(zip, "xl/styles.xml", stylesXml());
        put(zip, "xl/sharedStrings.xml", sharedStringsXml());
        for (int i = 0; i < sheets.size(); i++) put(zip, "xl/worksheets/sheet" + (i + 1) + ".xml", sheetXml.get(i));
        zip.finish();
        zip.flush();
    }

    private static void put(ZipOutputStream zip, String name, String content) throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(content.getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }

    private String contentTypes() {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
                + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
                + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
                + "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
                + "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
                + "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>"
                + "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>"
                + "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>");
        for (int i = 0; i < sheets.size(); i++)
            sb.append("<Override PartName=\"/xl/worksheets/sheet").append(i + 1)
                    .append(".xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>");
        sb.append("</Types>");
        return sb.toString();
    }

    private String coreXml() {
        SimpleDateFormat iso = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
        iso.setTimeZone(TimeZone.getTimeZone("UTC"));
        String now = iso.format(new Date());
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" "
                + "xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" "
                + "xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"
                + "<dc:title>" + esc(title) + "</dc:title>"
                + "<dc:creator>" + esc(author) + "</dc:creator>"
                + "<dcterms:created xsi:type=\"dcterms:W3CDTF\">" + now + "</dcterms:created>"
                + "<dcterms:modified xsi:type=\"dcterms:W3CDTF\">" + now + "</dcterms:modified>"
                + "</cp:coreProperties>";
    }

    private String workbookXml() {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" "
                + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
                + "<bookViews><workbookView xWindow=\"0\" yWindow=\"0\" windowWidth=\"28800\" windowHeight=\"15000\" activeTab=\"0\"/></bookViews>"
                + "<sheets>");
        for (int i = 0; i < sheets.size(); i++)
            sb.append("<sheet name=\"").append(esc(sheets.get(i).name)).append("\" sheetId=\"").append(i + 1)
                    .append("\" r:id=\"rId").append(i + 1).append("\"/>");
        sb.append("</sheets>");
        StringBuilder dn = new StringBuilder();
        for (int i = 0; i < sheets.size(); i++) {
            Sheet s = sheets.get(i);
            String qn = "'" + s.name.replace("'", "''") + "'";
            if (s.autoFilter != null) {
                String[] p = s.autoFilter.split(":");
                dn.append("<definedName name=\"_xlnm._FilterDatabase\" localSheetId=\"").append(i)
                        .append("\" hidden=\"1\">").append(esc(qn + "!" + abs(p[0]) + ":" + abs(p[1]))).append("</definedName>");
            }
            if (s.printTitleFirstRow >= 0) {
                dn.append("<definedName name=\"_xlnm.Print_Titles\" localSheetId=\"").append(i).append("\">")
                        .append(esc(qn + "!$" + (s.printTitleFirstRow + 1) + ":$" + (s.printTitleLastRow + 1)))
                        .append("</definedName>");
            }
        }
        if (dn.length() > 0) sb.append("<definedNames>").append(dn).append("</definedNames>");
        sb.append("<calcPr calcId=\"191029\" fullCalcOnLoad=\"1\"/></workbook>");
        return sb.toString();
    }

    private static String abs(String ref) {
        int i = 0;
        while (i < ref.length() && Character.isLetter(ref.charAt(i))) i++;
        return "$" + ref.substring(0, i) + "$" + ref.substring(i);
    }

    private String workbookRels() {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">");
        int i;
        for (i = 0; i < sheets.size(); i++)
            sb.append("<Relationship Id=\"rId").append(i + 1)
                    .append("\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet")
                    .append(i + 1).append(".xml\"/>");
        sb.append("<Relationship Id=\"rId").append(++i)
                .append("\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>");
        sb.append("<Relationship Id=\"rId").append(++i)
                .append("\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings\" Target=\"sharedStrings.xml\"/>");
        sb.append("</Relationships>");
        return sb.toString();
    }

    private String stylesXml() {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">");
        if (!numFmtIdx.isEmpty()) {
            sb.append("<numFmts count=\"").append(numFmtIdx.size()).append("\">");
            for (Map.Entry<String, Integer> e : numFmtIdx.entrySet())
                sb.append("<numFmt numFmtId=\"").append(e.getValue()).append("\" formatCode=\"").append(esc(e.getKey())).append("\"/>");
            sb.append("</numFmts>");
        }
        sb.append("<fonts count=\"").append(fonts.size()).append("\">");
        for (String f : fonts) sb.append(f);
        sb.append("</fonts><fills count=\"").append(fills.size()).append("\">");
        for (String f : fills) sb.append(f);
        sb.append("</fills><borders count=\"").append(borders.size()).append("\">");
        for (String b : borders) sb.append(b);
        sb.append("</borders>");
        sb.append("<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>");
        sb.append("<cellXfs count=\"").append(xfs.size()).append("\">");
        for (String x : xfs) sb.append(x);
        sb.append("</cellXfs>");
        sb.append("<cellStyles count=\"1\"><cellStyle name=\"Standard\" xfId=\"0\" builtinId=\"0\"/></cellStyles>");
        sb.append("<dxfs count=\"0\"/><tableStyles count=\"0\"/></styleSheet>");
        return sb.toString();
    }

    private String sharedStringsXml() {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"")
                .append(sharedStringCount).append("\" uniqueCount=\"").append(sharedStrings.size()).append("\">");
        for (String s : sharedStrings.keySet()) sb.append("<si><t xml:space=\"preserve\">").append(esc(s)).append("</t></si>");
        sb.append("</sst>");
        return sb.toString();
    }

    private String sheetXml(Sheet s) {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" "
                + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">");
        sb.append("<sheetPr>");
        if (s.tabColor != null) sb.append("<tabColor rgb=\"").append(s.tabColor).append("\"/>");
        if (s.fitToWidth) sb.append("<pageSetUpPr fitToPage=\"1\"/>");
        sb.append("</sheetPr>");

        int maxRow = s.rows.isEmpty() ? 0 : s.rows.lastKey();
        int maxCol = 0;
        for (TreeMap<Integer, Cell> r : s.rows.values()) if (!r.isEmpty()) maxCol = Math.max(maxCol, r.lastKey());
        sb.append("<dimension ref=\"A1:").append(ref(maxRow, maxCol)).append("\"/>");

        sb.append("<sheetViews><sheetView workbookViewId=\"0\" zoomScale=\"100\"");
        if (!s.showGrid) sb.append(" showGridLines=\"0\"");
        if (s.freezeRow > 0 || s.freezeCol > 0) {
            sb.append(">");
            int fr = Math.max(0, s.freezeRow), fc = Math.max(0, s.freezeCol);
            String pane = fr > 0 && fc > 0 ? "bottomRight" : (fr > 0 ? "bottomLeft" : "topRight");
            sb.append("<pane");
            if (fc > 0) sb.append(" xSplit=\"").append(fc).append('"');
            if (fr > 0) sb.append(" ySplit=\"").append(fr).append('"');
            sb.append(" topLeftCell=\"").append(ref(fr, fc)).append("\" activePane=\"").append(pane)
                    .append("\" state=\"frozen\"/>");
            sb.append("<selection pane=\"").append(pane).append("\" activeCell=\"").append(ref(fr, fc))
                    .append("\" sqref=\"").append(ref(fr, fc)).append("\"/>");
            sb.append("</sheetView>");
        } else {
            sb.append("/>");
        }
        sb.append("</sheetViews>");
        sb.append("<sheetFormatPr defaultRowHeight=\"15\"/>");

        if (!s.colWidths.isEmpty()) {
            sb.append("<cols>");
            for (Map.Entry<Integer, Double> e : s.colWidths.entrySet())
                sb.append("<col min=\"").append(e.getKey() + 1).append("\" max=\"").append(e.getKey() + 1)
                        .append("\" width=\"").append(num(e.getValue())).append("\" customWidth=\"1\"/>");
            sb.append("</cols>");
        }

        sb.append("<sheetData>");
        for (Map.Entry<Integer, TreeMap<Integer, Cell>> re : s.rows.entrySet()) {
            int r = re.getKey();
            sb.append("<row r=\"").append(r + 1).append('"');
            Double h = s.rowHeights.get(r);
            if (h != null) sb.append(" ht=\"").append(num(h)).append("\" customHeight=\"1\"");
            sb.append('>');
            for (Map.Entry<Integer, Cell> ce : re.getValue().entrySet()) {
                Cell c = ce.getValue();
                String rf = ref(r, ce.getKey());
                int st = styleId(c.style);
                sb.append("<c r=\"").append(rf).append('"');
                if (st != 0) sb.append(" s=\"").append(st).append('"');
                if (c.formula != null) {
                    if (c.value instanceof String) sb.append(" t=\"str\"");
                    sb.append("><f>").append(esc(c.formula)).append("</f>");
                    if (c.value instanceof Double) sb.append("<v>").append(num((Double) c.value)).append("</v>");
                    else if (c.value instanceof String) sb.append("<v>").append(esc((String) c.value)).append("</v>");
                    sb.append("</c>");
                } else if (c.value instanceof Double) {
                    sb.append("><v>").append(num((Double) c.value)).append("</v></c>");
                } else if (c.value instanceof String && !((String) c.value).isEmpty()) {
                    sb.append(" t=\"s\"><v>").append(sst((String) c.value)).append("</v></c>");
                } else {
                    sb.append("/>");
                }
            }
            sb.append("</row>");
        }
        sb.append("</sheetData>");

        if (s.autoFilter != null) sb.append("<autoFilter ref=\"").append(s.autoFilter).append("\"/>");
        if (!s.merges.isEmpty()) {
            sb.append("<mergeCells count=\"").append(s.merges.size()).append("\">");
            for (String m : s.merges) sb.append("<mergeCell ref=\"").append(m).append("\"/>");
            sb.append("</mergeCells>");
        }
        sb.append("<printOptions horizontalCentered=\"1\"/>");
        sb.append("<pageMargins left=\"0.5\" right=\"0.5\" top=\"0.7\" bottom=\"0.7\" header=\"0.3\" footer=\"0.3\"/>");
        sb.append("<pageSetup paperSize=\"9\" orientation=\"").append(s.landscape ? "landscape" : "portrait").append('"');
        if (s.fitToWidth) sb.append(" fitToWidth=\"1\" fitToHeight=\"0\"");
        sb.append("/>");
        if (s.headerCenter != null || s.footerLeft != null || s.footerRight != null) {
            sb.append("<headerFooter>");
            if (s.headerCenter != null) sb.append("<oddHeader>").append(esc("&C" + s.headerCenter)).append("</oddHeader>");
            sb.append("<oddFooter>").append(esc((s.footerLeft != null ? "&L" + s.footerLeft : "")
                    + (s.footerRight != null ? "&R" + s.footerRight : ""))).append("</oddFooter>");
            sb.append("</headerFooter>");
        }
        sb.append("</worksheet>");
        return sb.toString();
    }

    private static String num(double d) {
        if (d == Math.rint(d) && Math.abs(d) < 1e15) return Long.toString((long) d);
        return Double.toString(d);
    }

    static String esc(String s) {
        if (s == null) return "";
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&': sb.append("&amp;"); break;
                case '<': sb.append("&lt;"); break;
                case '>': sb.append("&gt;"); break;
                case '"': sb.append("&quot;"); break;
                default:
                    if (c < 0x20 && c != '\t' && c != '\n' && c != '\r') continue; // ungültig in XML
                    sb.append(c);
            }
        }
        return sb.toString();
    }
}
