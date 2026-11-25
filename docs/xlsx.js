/*
 * Kleiner, abhängigkeitsfreier Writer für Excel-Arbeitsmappen (.xlsx) – Gegenstück zu XlsxWriter.java
 * der Android-App. Unterstützt Formatvorlagen, Formeln mit zwischengespeicherten Werten, verbundene
 * Zellen, fixierte Bereiche, AutoFilter, Spaltenbreiten, Zeilenhöhen und Druckeinrichtung.
 * Das ZIP wird ohne Kompression geschrieben (STORE) – Excel liest das problemlos.
 */
(function (global) {
  'use strict';

  // ------------------------------------------------------------------ Styles
  class Style {
    constructor(o) {
      Object.assign(this, {
        bold: false, italic: false, size: 10, color: 'FF000000', fill: null, border: null,
        borderColor: 'FF9E9E9E', topMedium: false, bottomMedium: false, fmt: null, align: null,
        valign: 'center', wrap: false
      }, o || {});
    }
    with(o) { return new Style(Object.assign({}, this, o)); }
    fontKey() { return [this.bold, this.italic, this.size, this.color].join('|'); }
    borderKey() { return [this.border, this.borderColor, this.topMedium, this.bottomMedium].join('|'); }
  }

  const esc = s => String(s == null ? '' : s)
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const num = d => (Number.isInteger(d) ? String(d) : String(+d.toPrecision(15)));

  function colName(c) {
    let s = ''; c++;
    while (c > 0) { const m = (c - 1) % 26; s = String.fromCharCode(65 + m) + s; c = Math.floor((c - 1) / 26); }
    return s;
  }
  const ref = (r, c) => colName(c) + (r + 1);

  // ------------------------------------------------------------------ Sheet
  class Sheet {
    constructor(name) {
      this.name = name.replace(/[\\/?*\[\]:]/g, '_').slice(0, 31) || 'Tabelle';
      this.rows = new Map(); this.colWidths = new Map(); this.rowHeights = new Map(); this.merges = [];
      this.freezeRow = 0; this.freezeCol = 0; this.autoFilter = null; this.landscape = true;
      this.printTitleFirst = -1; this.printTitleLast = -1; this.header = null; this.footerL = null;
      this.footerR = null; this.tabColor = null; this.showGrid = true;
    }
    cell(r, c) {
      if (!this.rows.has(r)) this.rows.set(r, new Map());
      const row = this.rows.get(r);
      if (!row.has(c)) row.set(c, {});
      return row.get(c);
    }
    set(r, c, v, st) {
      const x = this.cell(r, c);
      x.formula = null;
      x.value = (typeof v === 'number' && isFinite(v)) ? v : (v == null || v === '' ? null : String(v));
      x.style = st; return this;
    }
    formula(r, c, f, cached, st) {
      const x = this.cell(r, c);
      x.formula = f; x.value = (typeof cached === 'number' && isFinite(cached)) ? cached : null; x.style = st; return this;
    }
    styleRange(r1, c1, r2, c2, st) {
      for (let r = r1; r <= r2; r++) for (let c = c1; c <= c2; c++) this.cell(r, c).style = st;
      return this;
    }
    merge(r1, c1, r2, c2) { this.merges.push(ref(r1, c1) + ':' + ref(r2, c2)); return this; }
    width(c, w) { this.colWidths.set(c, w); return this; }
    height(r, h) { this.rowHeights.set(r, h); return this; }
    freeze(r, c) { this.freezeRow = r; this.freezeCol = c; return this; }
    filter(r1, c1, r2, c2) { this.autoFilter = ref(r1, c1) + ':' + ref(r2, c2); return this; }
    printTitles(a, b) { this.printTitleFirst = a; this.printTitleLast = b; return this; }
    portrait() { this.landscape = false; return this; }
    headerFooter(h, l, r) { this.header = h; this.footerL = l; this.footerR = r; return this; }
  }

  // ------------------------------------------------------------------ Workbook
  class Workbook {
    constructor() { this.sheets = []; this.title = ''; this.author = ''; }
    addSheet(name) { const s = new Sheet(name); this.sheets.push(s); return s; }

    /** @returns {Uint8Array} Inhalt der .xlsx-Datei */
    build() {
      // Shared Strings + Styles
      const sst = new Map(); let sstCount = 0;
      const sstIdx = s => { sstCount++; if (!sst.has(s)) sst.set(s, sst.size); return sst.get(s); };
      const fonts = [], fontIdx = new Map(), fills = ['<fill><patternFill patternType="none"/></fill>', '<fill><patternFill patternType="gray125"/></fill>'];
      const fillIdx = new Map(), borders = ['<border><left/><right/><top/><bottom/><diagonal/></border>'], borderIdx = new Map();
      const numFmts = new Map(), xfs = ['<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'], xfIdx = new Map([[xfs[0], 0]]);
      const cache = new Map();
      const fontXml = s => '<font>' + (s.bold ? '<b/>' : '') + (s.italic ? '<i/>' : '') + '<sz val="' + num(s.size) +
        '"/><color rgb="' + s.color + '"/><name val="Calibri"/><family val="2"/></font>';
      const def = new Style(); fonts.push(fontXml(def)); fontIdx.set(def.fontKey(), 0);
      const side = (n, st, col) => st ? '<' + n + ' style="' + st + '"><color rgb="' + col + '"/></' + n + '>' : '<' + n + '/>';

      const styleId = s => {
        if (!s) return 0;
        if (cache.has(s)) return cache.get(s);
        let f = fontIdx.get(s.fontKey());
        if (f === undefined) { f = fonts.length; fonts.push(fontXml(s)); fontIdx.set(s.fontKey(), f); }
        let fi = 0;
        if (s.fill) {
          fi = fillIdx.get(s.fill);
          if (fi === undefined) {
            fi = fills.length;
            fills.push('<fill><patternFill patternType="solid"><fgColor rgb="' + s.fill + '"/><bgColor indexed="64"/></patternFill></fill>');
            fillIdx.set(s.fill, fi);
          }
        }
        let bi = 0;
        if (s.border || s.topMedium || s.bottomMedium) {
          bi = borderIdx.get(s.borderKey());
          if (bi === undefined) {
            bi = borders.length;
            borders.push('<border>' + side('left', s.border, s.borderColor) + side('right', s.border, s.borderColor) +
              side('top', s.topMedium ? 'medium' : s.border, s.topMedium ? 'FF000000' : s.borderColor) +
              side('bottom', s.bottomMedium ? 'medium' : s.border, s.bottomMedium ? 'FF000000' : s.borderColor) +
              '<diagonal/></border>');
            borderIdx.set(s.borderKey(), bi);
          }
        }
        let nf = 0;
        if (s.fmt) { nf = numFmts.get(s.fmt); if (nf === undefined) { nf = 164 + numFmts.size; numFmts.set(s.fmt, nf); } }
        let x = '<xf numFmtId="' + nf + '" fontId="' + f + '" fillId="' + fi + '" borderId="' + bi + '" xfId="0"' +
          (nf ? ' applyNumberFormat="1"' : '') + (f ? ' applyFont="1"' : '') + (fi ? ' applyFill="1"' : '') +
          (bi ? ' applyBorder="1"' : '') + ' applyAlignment="1"><alignment' +
          (s.align ? ' horizontal="' + s.align + '"' : '') + (s.valign ? ' vertical="' + s.valign + '"' : '') +
          (s.wrap ? ' wrapText="1"' : '') + '/></xf>';
        let id = xfIdx.get(x);
        if (id === undefined) { id = xfs.length; xfs.push(x); xfIdx.set(x, id); }
        cache.set(s, id); return id;
      };

      const sheetXml = sh => {
        const rowKeys = [...sh.rows.keys()].sort((a, b) => a - b);
        let maxRow = rowKeys.length ? rowKeys[rowKeys.length - 1] : 0, maxCol = 0;
        for (const r of sh.rows.values()) for (const c of r.keys()) maxCol = Math.max(maxCol, c);
        let x = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">';
        x += '<sheetPr>' + (sh.tabColor ? '<tabColor rgb="' + sh.tabColor + '"/>' : '') + '<pageSetUpPr fitToPage="1"/></sheetPr>';
        x += '<dimension ref="A1:' + ref(maxRow, maxCol) + '"/>';
        x += '<sheetViews><sheetView workbookViewId="0"' + (sh.showGrid ? '' : ' showGridLines="0"');
        if (sh.freezeRow > 0 || sh.freezeCol > 0) {
          const fr = sh.freezeRow, fc = sh.freezeCol;
          const pane = fr > 0 && fc > 0 ? 'bottomRight' : fr > 0 ? 'bottomLeft' : 'topRight';
          x += '><pane' + (fc ? ' xSplit="' + fc + '"' : '') + (fr ? ' ySplit="' + fr + '"' : '') + ' topLeftCell="' + ref(fr, fc) +
            '" activePane="' + pane + '" state="frozen"/><selection pane="' + pane + '" activeCell="' + ref(fr, fc) +
            '" sqref="' + ref(fr, fc) + '"/></sheetView>';
        } else x += '/>';
        x += '</sheetViews><sheetFormatPr defaultRowHeight="15"/>';
        if (sh.colWidths.size) {
          x += '<cols>';
          [...sh.colWidths.keys()].sort((a, b) => a - b).forEach(c =>
            x += '<col min="' + (c + 1) + '" max="' + (c + 1) + '" width="' + num(sh.colWidths.get(c)) + '" customWidth="1"/>');
          x += '</cols>';
        }
        x += '<sheetData>';
        for (const r of rowKeys) {
          const row = sh.rows.get(r), h = sh.rowHeights.get(r);
          x += '<row r="' + (r + 1) + '"' + (h ? ' ht="' + num(h) + '" customHeight="1"' : '') + '>';
          for (const c of [...row.keys()].sort((a, b) => a - b)) {
            const cl = row.get(c), st = styleId(cl.style), rf = ref(r, c);
            x += '<c r="' + rf + '"' + (st ? ' s="' + st + '"' : '');
            if (cl.formula) {
              x += '><f>' + esc(cl.formula) + '</f>' + (typeof cl.value === 'number' ? '<v>' + num(cl.value) + '</v>' : '') + '</c>';
            } else if (typeof cl.value === 'number') {
              x += '><v>' + num(cl.value) + '</v></c>';
            } else if (cl.value) {
              x += ' t="s"><v>' + sstIdx(cl.value) + '</v></c>';
            } else x += '/>';
          }
          x += '</row>';
        }
        x += '</sheetData>';
        if (sh.autoFilter) x += '<autoFilter ref="' + sh.autoFilter + '"/>';
        if (sh.merges.length) x += '<mergeCells count="' + sh.merges.length + '">' + sh.merges.map(m => '<mergeCell ref="' + m + '"/>').join('') + '</mergeCells>';
        x += '<printOptions horizontalCentered="1"/><pageMargins left="0.5" right="0.5" top="0.7" bottom="0.7" header="0.3" footer="0.3"/>';
        x += '<pageSetup paperSize="9" orientation="' + (sh.landscape ? 'landscape' : 'portrait') + '" fitToWidth="1" fitToHeight="0"/>';
        if (sh.header || sh.footerL || sh.footerR) {
          x += '<headerFooter>' + (sh.header ? '<oddHeader>' + esc('&C' + sh.header) + '</oddHeader>' : '') +
            '<oddFooter>' + esc((sh.footerL ? '&L' + sh.footerL : '') + (sh.footerR ? '&R' + sh.footerR : '')) + '</oddFooter></headerFooter>';
        }
        return x + '</worksheet>';
      };

      const sheetsXml = this.sheets.map(sheetXml);
      const files = [];
      const add = (n, s) => files.push([n, s]);
      const X = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
      add('[Content_Types].xml', X + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
        '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>' +
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>' +
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>' +
        this.sheets.map((s, i) => '<Override PartName="/xl/worksheets/sheet' + (i + 1) + '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join('') +
        '</Types>');
      add('_rels/.rels', X + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>' +
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>');
      const now = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
      add('docProps/core.xml', X + '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
        '<dc:title>' + esc(this.title) + '</dc:title><dc:creator>' + esc(this.author) + '</dc:creator>' +
        '<dcterms:created xsi:type="dcterms:W3CDTF">' + now + '</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">' + now + '</dcterms:modified></cp:coreProperties>');
      add('docProps/app.xml', X + '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Materialliste</Application></Properties>');
      let dn = '';
      this.sheets.forEach((s, i) => {
        const q = "'" + s.name.replace(/'/g, "''") + "'";
        if (s.autoFilter) {
          const [a, b] = s.autoFilter.split(':').map(r => r.replace(/^([A-Z]+)(\d+)$/, '$$$1$$$2'));
          dn += '<definedName name="_xlnm._FilterDatabase" localSheetId="' + i + '" hidden="1">' + esc(q + '!' + a + ':' + b) + '</definedName>';
        }
        if (s.printTitleFirst >= 0)
          dn += '<definedName name="_xlnm.Print_Titles" localSheetId="' + i + '">' + esc(q + '!$' + (s.printTitleFirst + 1) + ':$' + (s.printTitleLast + 1)) + '</definedName>';
      });
      add('xl/workbook.xml', X + '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
        '<bookViews><workbookView xWindow="0" yWindow="0" windowWidth="28800" windowHeight="15000" activeTab="0"/></bookViews><sheets>' +
        this.sheets.map((s, i) => '<sheet name="' + esc(s.name) + '" sheetId="' + (i + 1) + '" r:id="rId' + (i + 1) + '"/>').join('') + '</sheets>' +
        (dn ? '<definedNames>' + dn + '</definedNames>' : '') + '<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>');
      const n = this.sheets.length;
      add('xl/_rels/workbook.xml.rels', X + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        this.sheets.map((s, i) => '<Relationship Id="rId' + (i + 1) + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' + (i + 1) + '.xml"/>').join('') +
        '<Relationship Id="rId' + (n + 1) + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
        '<Relationship Id="rId' + (n + 2) + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/></Relationships>');
      add('xl/styles.xml', X + '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
        (numFmts.size ? '<numFmts count="' + numFmts.size + '">' + [...numFmts].map(([f, id]) => '<numFmt numFmtId="' + id + '" formatCode="' + esc(f) + '"/>').join('') + '</numFmts>' : '') +
        '<fonts count="' + fonts.length + '">' + fonts.join('') + '</fonts><fills count="' + fills.length + '">' + fills.join('') + '</fills>' +
        '<borders count="' + borders.length + '">' + borders.join('') + '</borders>' +
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
        '<cellXfs count="' + xfs.length + '">' + xfs.join('') + '</cellXfs>' +
        '<cellStyles count="1"><cellStyle name="Standard" xfId="0" builtinId="0"/></cellStyles><dxfs count="0"/><tableStyles count="0"/></styleSheet>');
      add('xl/sharedStrings.xml', X + '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="' + sstCount + '" uniqueCount="' + sst.size + '">' +
        [...sst.keys()].map(s => '<si><t xml:space="preserve">' + esc(s) + '</t></si>').join('') + '</sst>');
      sheetsXml.forEach((s, i) => add('xl/worksheets/sheet' + (i + 1) + '.xml', s));
      return zip(files);
    }
  }

  // ------------------------------------------------------------------ ZIP (STORE)
  const CRC = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
    return t;
  })();
  function crc32(b) { let c = 0xFFFFFFFF; for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }

  function zip(files) {
    const enc = new TextEncoder(), parts = [], central = [];
    let offset = 0;
    const d = new Date();
    const dosTime = (d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1);
    const dosDate = ((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate();
    for (const [name, content] of files) {
      const nameB = enc.encode(name), data = typeof content === 'string' ? enc.encode(content) : content;
      const crc = crc32(data);
      const h = new DataView(new ArrayBuffer(30));
      h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint16(6, 0x0800, true); h.setUint16(8, 0, true);
      h.setUint16(10, dosTime, true); h.setUint16(12, dosDate, true); h.setUint32(14, crc, true);
      h.setUint32(18, data.length, true); h.setUint32(22, data.length, true); h.setUint16(26, nameB.length, true); h.setUint16(28, 0, true);
      parts.push(new Uint8Array(h.buffer), nameB, data);
      const c = new DataView(new ArrayBuffer(46));
      c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true); c.setUint16(8, 0x0800, true); c.setUint16(10, 0, true);
      c.setUint16(12, dosTime, true); c.setUint16(14, dosDate, true); c.setUint32(16, crc, true);
      c.setUint32(20, data.length, true); c.setUint32(24, data.length, true); c.setUint16(28, nameB.length, true);
      c.setUint32(42, offset, true);
      central.push(new Uint8Array(c.buffer), nameB);
      offset += 30 + nameB.length + data.length;
    }
    const cdSize = central.reduce((s, p) => s + p.length, 0);
    const e = new DataView(new ArrayBuffer(22));
    e.setUint32(0, 0x06054b50, true); e.setUint16(8, files.length, true); e.setUint16(10, files.length, true);
    e.setUint32(12, cdSize, true); e.setUint32(16, offset, true);
    const all = [...parts, ...central, new Uint8Array(e.buffer)];
    const out = new Uint8Array(all.reduce((s, p) => s + p.length, 0));
    let o = 0; for (const p of all) { out.set(p, o); o += p.length; }
    return out;
  }

  global.Xlsx = { Workbook, Style, style: o => new Style(o), colName, ref, zip, crc32 };
})(typeof window !== 'undefined' ? window : globalThis);
