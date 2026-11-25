/* Excel-Export: Materialliste (ausführlich) und Bestellliste (schlicht) – wie in der Android-App. */
(function (global) {
  'use strict';
  const { TYP, Fmt, Einheit, P, Liste, leer } = global.M;
  const st = global.Xlsx.style;

  const PRIMAER = 'FF1E4E79', HELL = 'FFC5D5E4', FLAECHE = 'FFE8F0F7', ZEBRA = 'FFF8FAFB', WEISS = 'FFFFFFFF',
    GRAU = 'FF66707A', SUMME = 'FFFFF3E0', GESAMT = 'FFFFE0B2', BLAU = 'FF1565C0', GRUEN = 'FF2E7D32';
  const FMT_L = '0.00', FMT_LFM = '#,##0.00', FMT_M2 = '#,##0.00', FMT_M3 = '#,##0.000', FMT_DIM = '0.##;-0.##;""',
    FMT_STK = '#,##0;-#,##0;""', FMT_MENGE = '#,##0.##;-#,##0.##;""', FMT_EUR = '#,##0.00 "€";-#,##0.00 "€";""';

  const C = { POS: 0, BEZ: 1, ART: 2, STK: 3, B: 4, H: 5, L: 6, LFM: 7, M2: 8, VS: 9, M3: 10, FB: 11, FH: 12, MAT: 13, MENGE: 14, EINH: 15, PREIS: 16, BETRAG: 17, BEM: 18 };
  const LAST = C.BEM;
  const nz = x => (x == null || x === '' ? null : x);

  function artKurz(p) { return { holz: 'Stk', lfm: 'lfm', platte: 'Platte', material: 'Mat' }[p.typ] || ''; }

  function materialliste(wb, h) {
    const s = wb.addSheet('Materialliste');
    s.tabColor = PRIMAER; s.showGrid = false;
    [[C.POS, 5.5], [C.BEZ, 30], [C.ART, 7], [C.STK, 7], [C.B, 8], [C.H, 11.5], [C.L, 9], [C.LFM, 11], [C.M2, 10], [C.VS, 10], [C.M3, 10],
      [C.FB, 8], [C.FH, 8], [C.MAT, 24], [C.MENGE, 9], [C.EINH, 9], [C.PREIS, 10], [C.BETRAG, 11], [C.BEM, 28]].forEach(([c, w]) => s.width(c, w));

    const base = st();
    const label = base.with({ color: GRAU, size: 9, align: 'right' });
    const wert = base.with({ bold: true, size: 11, bottomMedium: true, borderColor: HELL });
    s.set(0, 0, 'MATERIALLISTE', base.with({ bold: true, size: 20, color: PRIMAER })); s.merge(0, 0, 0, 4); s.height(0, 30);
    s.set(0, C.EINH, 'Erstellt mit Materialliste (Web)', base.with({ italic: true, size: 8, color: GRAU, align: 'right' })); s.merge(0, C.EINH, 0, C.BEM);
    const kopf = (r, cL, text, w, c1, c2) => {
      s.set(r, cL, text + '  ', label); s.set(r, c1, w || '', wert);
      for (let c = c1 + 1; c <= c2; c++) s.set(r, c, null, wert);
      if (c2 > c1) s.merge(r, c1, r, c2);
    };
    kopf(2, C.BEZ, 'Projekt / Bauvorhaben', h.projekt, C.ART, C.L); kopf(2, C.LFM, 'Datum', h.datum, C.M2, C.FH);
    kopf(3, C.BEZ, 'Kunde / Bauherr', h.kunde, C.ART, C.L); kopf(3, C.LFM, 'Bearbeiter', h.bearbeiter, C.M2, C.FH);
    kopf(4, C.BEZ, 'Bauteil', h.bauteil, C.ART, C.L); kopf(4, C.LFM, 'Notiz', (h.notiz || '').split('\n')[0], C.M2, C.BEM);
    for (let r = 2; r <= 4; r++) s.height(r, 20);

    const grp = base.with({ bold: true, size: 9, color: WEISS, fill: PRIMAER, align: 'center', border: 'thin', borderColor: 'FF3C6E99' });
    const gruppe = (c1, c2, t) => { s.set(6, c1, t, grp); for (let c = c1 + 1; c <= c2; c++) s.set(6, c, null, grp); if (c2 > c1) s.merge(6, c1, 6, c2); };
    gruppe(C.POS, C.STK, 'Position'); gruppe(C.B, C.L, 'Rohmaß'); gruppe(C.LFM, C.M3, 'Menge'); gruppe(C.FB, C.FH, 'Fertigmaß');
    gruppe(C.MAT, C.MAT, 'Material'); gruppe(C.MENGE, C.BEM, 'Bestellung & Preis'); s.height(6, 16);
    const head = base.with({ bold: true, fill: HELL, align: 'center', wrap: true, border: 'thin', borderColor: 'FF9AB3CB', bottomMedium: true });
    ['Pos.', 'Bezeichnung', 'Art', 'Stück', 'Breite\n[cm]', 'Höhe/Dicke\n[cm]', 'Länge\n[m]', 'Laufmeter\n[m]', 'Fläche\n[m²]', 'Verschnitt\n[%]',
      'Volumen\n[m³]', 'Breite\n[cm]', 'Höhe\n[cm]', 'Holzart / Material', 'Menge', 'Einheit', 'Preis\n[€/Einh.]', 'Betrag\n[€]', 'Bemerkung']
      .forEach((t, c) => s.set(7, c, t, c === C.BEZ || c === C.MAT || c === C.BEM ? head.with({ align: 'left' }) : head));
    s.height(7, 30); s.freeze(8, C.BEZ + 1); s.printTitles(6, 7);

    const zelle = base.with({ border: 'thin', borderColor: 'FFD0D0D0' });
    const titelSt = base.with({ bold: true, size: 11, color: PRIMAER, fill: FLAECHE, border: 'thin', borderColor: 'FFB0C4D8' });
    const first = 8; let r = first, z = 0;
    h.positionen.forEach((p, i) => {
      if (p.typ === TYP.TITEL) {
        for (let c = 0; c <= LAST; c++) s.set(r, c, null, titelSt);
        s.set(r, C.BEZ, p.bez || 'Abschnitt', titelSt); s.merge(r, C.BEZ, r, LAST); s.height(r, 20); r++; z = 0; return;
      }
      const c0 = z++ % 2 ? zelle.with({ fill: ZEBRA }) : zelle, ctr = c0.with({ align: 'center' }), num = c0.with({ align: 'right' });
      s.set(r, C.POS, Liste.posNummer(h, i), ctr.with({ color: GRAU }));
      s.set(r, C.BEZ, p.bez, c0.with({ bold: true }));
      s.set(r, C.ART, artKurz(p), ctr.with({ color: GRAU, size: 9 }));
      let stk = null, lfm = null, m2 = null, menge = null, einh = '';
      if (p.typ === TYP.HOLZ) { stk = nz(p.stk); lfm = P.laufmeter(p) || null; }
      else if (p.typ === TYP.LFM) lfm = nz(p.lfm);
      else if (p.typ === TYP.PLATTE) { stk = P.plattenAnzahl(p); m2 = P.flaeche(p) || null; }
      else if (p.typ === TYP.MATERIAL) {
        const pk = P.packungen(p);
        if (pk != null) { menge = pk; einh = P.packName(p); } else { menge = P.bedarf(p); einh = Einheit.norm(p.einh); }
      }
      s.set(r, C.STK, stk, ctr.with({ fmt: FMT_STK, bold: true, color: p.typ === TYP.PLATTE ? GRUEN : 'FF000000' }));
      s.set(r, C.B, p.typ === TYP.MATERIAL ? null : nz(p.b), num.with({ fmt: FMT_DIM }));
      s.set(r, C.H, p.typ === TYP.MATERIAL ? null : nz(p.h), num.with({ fmt: FMT_DIM }));
      s.set(r, C.L, p.typ === TYP.HOLZ || p.typ === TYP.PLATTE ? nz(p.l) : null, num.with({ fmt: FMT_L }));
      s.set(r, C.LFM, lfm, num.with({ fmt: FMT_LFM, bold: p.typ === TYP.LFM }));
      s.set(r, C.M2, m2, num.with({ fmt: FMT_M2, bold: true }));
      s.set(r, C.VS, p.typ === TYP.PLATTE || p.typ === TYP.MATERIAL ? nz(p.vs) : null, num.with({ fmt: FMT_DIM }));
      const vol = P.volumen(p);
      s.set(r, C.M3, vol || null, num.with({ fmt: FMT_M3, bold: true }));
      s.set(r, C.FB, nz(p.fb), num.with({ fmt: FMT_DIM, color: BLAU }));
      s.set(r, C.FH, nz(p.fh), num.with({ fmt: FMT_DIM, color: BLAU }));
      s.set(r, C.MAT, p.holzart, c0);
      s.set(r, C.MENGE, menge, num.with({ fmt: FMT_MENGE, bold: true }));
      s.set(r, C.EINH, einh, ctr);
      s.set(r, C.PREIS, nz(p.preis), num.with({ fmt: FMT_EUR }));
      const bt = P.betrag(p);
      s.set(r, C.BETRAG, bt, num.with({ fmt: FMT_EUR, bold: true }));
      let bem = p.bem || '';
      if (p.typ === TYP.PLATTE && p.flL != null && p.flB != null) bem = 'Fläche ' + Fmt.num(p.flL) + ' × ' + Fmt.num(p.flB) + ' m' + (bem ? '; ' + bem : '');
      if (p.typ === TYP.MATERIAL && P.hatPackung(p)) bem = P.packName(p) + ' à ' + Fmt.num(p.pack) + ' ' + Einheit.norm(p.einh) + (bem ? '; ' + bem : '');
      if (p.preis != null) bem = (bem ? bem + '; ' : '') + 'Preis je ' + P.preisEinheit(p);
      if (!leer(p.artNr)) bem = (bem ? bem + '; ' : '') + 'Art.-Nr. ' + p.artNr;
      s.set(r, C.BEM, bem, c0.with({ wrap: true, size: 9 }));
      s.height(r, 18); r++;
    });
    if (r === first) { for (let c = 0; c <= LAST; c++) s.set(r, c, null, zelle); r++; }
    const last = r - 1;
    s.filter(first - 1, 0, last, LAST);

    // Summen
    const rng = col => col + (first + 1) + ':' + col + (last + 1), art = '$C$' + (first + 1) + ':$C$' + (last + 1);
    const L = global.Xlsx.colName;
    const sumLbl = base.with({ bold: true, fill: SUMME, border: 'thin', borderColor: 'FFFFCC80' }), sumNum = sumLbl.with({ align: 'right' });
    const summe = (zeile, text, a, lbl, nm) => {
      for (let c = 0; c <= LAST; c++) s.set(zeile, c, null, lbl);
      s.set(zeile, C.BEZ, text, lbl);
      const f = (c, ftxt, val, fmt) => s.formula(zeile, c, ftxt, val, nm.with({ fmt }));
      const sum = (col, filt) => filt ? 'SUMIF(' + art + ',"' + filt + '",' + rng(L(col)) + ')' : 'SUM(' + rng(L(col)) + ')';
      const typen = { Stk: [TYP.HOLZ], lfm: [TYP.LFM], Platte: [TYP.PLATTE], Mat: [TYP.MATERIAL] };
      const pos = h.positionen.filter(p => !a || typen[a].includes(p.typ));
      if (a !== 'lfm' && a !== 'Mat') f(C.STK, sum(C.STK, a), pos.reduce((x, p) => x + (p.typ === TYP.PLATTE ? (P.plattenAnzahl(p) || 0) : p.typ === TYP.HOLZ ? (p.stk || 0) : 0), 0), '#,##0');
      if (a !== 'Platte' && a !== 'Mat') f(C.LFM, sum(C.LFM, a), pos.reduce((x, p) => x + P.laufmeter(p), 0), FMT_LFM);
      if (!a || a === 'Platte') f(C.M2, sum(C.M2, a), pos.reduce((x, p) => x + P.flaeche(p), 0), FMT_M2);
      f(C.M3, sum(C.M3, a), pos.reduce((x, p) => x + P.volumen(p), 0), FMT_M3);
      f(C.BETRAG, sum(C.BETRAG, a), pos.reduce((x, p) => x + (P.betrag(p) || 0), 0), FMT_EUR);
    };
    r++;
    const hat = t => h.positionen.some(p => p.typ === t);
    if (hat(TYP.HOLZ)) summe(r++, 'Summe Balken & Kanthölzer', 'Stk', sumLbl, sumNum);
    if (hat(TYP.LFM)) summe(r++, 'Summe Latten & Bretter', 'lfm', sumLbl, sumNum);
    if (hat(TYP.PLATTE)) summe(r++, 'Summe Platten', 'Platte', sumLbl, sumNum);
    if (hat(TYP.MATERIAL)) summe(r++, 'Summe Material', 'Mat', sumLbl, sumNum);
    const g = base.with({ bold: true, size: 11, fill: GESAMT, border: 'thin', borderColor: 'FFFFB74D', topMedium: true, bottomMedium: true });
    summe(r, 'GESAMT', null, g, g.with({ align: 'right' })); s.height(r, 22);
    r += 2;
    s.set(r, 0, 'Volumen nach Rohmaß; Platten: Anzahl = Fläche × (1 + Verschnitt) ÷ Plattenformat, aufgerundet. Fertigmaße in Blau.',
      base.with({ italic: true, size: 8, color: GRAU }));
    s.headerFooter('&"Calibri,Fett"Materialliste – ' + Liste.titel(h), '&8' + (h.kunde || '') + '  ' + (h.datum || ''), '&8Seite &P von &N');
  }

  /** Schlichte Bestellliste. was: 'alles' | 'holz' | 'material' */
  function bestellZeile(p) {
    let menge = null, einheit = '', quer = '', laenge = '', pack = '';
    let bez = (p.bez || '').trim();
    const mat = (p.holzart || '').trim();
    if (mat && !bez.toLowerCase().includes(mat.toLowerCase())) bez = bez ? bez + ' ' + mat : mat;
    if (p.typ === TYP.MATERIAL) {
      const pk = P.packungen(p);
      if (pk != null) { menge = pk; einheit = P.packName(p); pack = 'à ' + Fmt.num(p.pack) + ' ' + Einheit.norm(p.einh); }
      else { menge = P.bedarf(p); einheit = Einheit.norm(p.einh); }
    } else if (p.typ === TYP.PLATTE) {
      menge = P.plattenAnzahl(p); einheit = 'Platten';
      if (p.l != null || p.b != null) quer = (p.l == null ? '–' : Fmt.num(p.l * 100)) + ' × ' + (p.b == null ? '–' : Fmt.num(p.b));
      if (p.h != null) laenge = Fmt.num(p.h * 10) + ' mm stark';
    } else if (p.typ === TYP.LFM) { menge = nz(p.lfm); einheit = 'm'; quer = Fmt.querschnitt(p.b, p.h); }
    else { menge = nz(p.stk); einheit = 'Stk'; quer = Fmt.querschnitt(p.b, p.h); if (p.l != null) laenge = Fmt.fix(p.l, 2) + ' m'; }
    if (!bez) bez = P.typName(p.typ);
    let bem = (p.bem || '').trim();
    if (pack) bem = bem ? pack + ', ' + bem : pack;
    return [menge, einheit, bez, quer, laenge, p.artNr || '', bem];
  }

  function bestellliste(wb, h, was) {
    const titel = was === 'holz' ? 'Holzliste' : was === 'material' ? 'Materialliste' : 'Bestellliste';
    const s = wb.addSheet(titel);
    s.portrait();
    [[0, 5], [1, 9], [2, 9], [3, 40], [4, 14], [5, 13], [6, 14], [7, 26]].forEach(([c, w]) => s.width(c, w));
    const base = st({ size: 11 });
    s.set(0, 0, titel.toUpperCase(), base.with({ bold: true, size: 16 })); s.merge(0, 0, 0, 3); s.height(0, 24);
    let r = 2;
    for (const [lab, w] of [['Baustelle', Liste.titel(h)], ['Datum', h.datum], ['Besteller', h.bearbeiter]]) {
      if (leer(w)) continue;
      s.set(r, 0, lab + ':', base.with({ color: 'FF616161' })); s.merge(r, 0, r, 1);
      s.set(r, 2, w.trim(), base.with({ bold: true })); s.merge(r, 2, r, 5); r++;
    }
    r++;
    const head = base.with({ bold: true, fill: 'FFE0E0E0', border: 'thin', borderColor: 'FF9E9E9E' });
    ['Nr.', 'Menge', 'Einheit', 'Bezeichnung', 'Maß [cm]', 'Länge', 'Art.-Nr.', 'Bemerkung'].forEach((t, c) => s.set(r, c, t, c === 1 ? head.with({ align: 'right' }) : head));
    const kopfZeile = r++;
    const zelle = base.with({ border: 'thin', borderColor: 'FFBDBDBD', valign: 'top' });
    const liste = h.positionen.filter(p => p.typ !== TYP.TITEL && (was === 'alles' || (was === 'material' ? p.typ === TYP.MATERIAL : p.typ !== TYP.MATERIAL)));
    liste.forEach((p, i) => {
      const z = bestellZeile(p);
      s.set(r, 0, i + 1, zelle.with({ align: 'center' }));
      s.set(r, 1, z[0], zelle.with({ fmt: FMT_MENGE, align: 'right' }));
      s.set(r, 2, z[1], zelle.with({ align: 'center' }));
      s.set(r, 3, z[2], zelle.with({ wrap: true }));
      s.set(r, 4, z[3], zelle.with({ align: 'center' }));
      s.set(r, 5, z[4], zelle);
      s.set(r, 6, z[5], zelle);
      s.set(r, 7, z[6], zelle.with({ wrap: true }));
      r++;
    });
    if (!liste.length) s.set(r, 3, '(keine Positionen)', base.with({ italic: true, color: 'FF757575' }));
    s.freeze(kopfZeile + 1, 0); s.printTitles(kopfZeile, kopfZeile);
  }

  function dateiname(prefix, h) {
    let n = (h.projekt || '').trim().replace(/[^A-Za-z0-9ÄÖÜäöüß _-]/g, '').trim().replace(/[ _]+/g, "_").replace(/^_|_$/g, "").slice(0, 40);
    const d = new Date(), iso = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    return prefix + '_' + (n ? n + '_' : '') + iso + '.xlsx';
  }

  global.Export = {
    materialliste(h) {
      const wb = new global.Xlsx.Workbook();
      wb.title = 'Materialliste ' + Liste.titel(h); wb.author = h.bearbeiter || '';
      materialliste(wb, h);
      bestellliste(wb, h, 'alles');
      return { daten: wb.build(), name: dateiname('Materialliste', h) };
    },
    bestellliste(h, was) {
      const wb = new global.Xlsx.Workbook();
      const titel = was === 'holz' ? 'Holzliste' : was === 'material' ? 'Materialliste' : 'Bestellliste';
      wb.title = titel + ' ' + Liste.titel(h); wb.author = h.bearbeiter || '';
      bestellliste(wb, h, was);
      return { daten: wb.build(), name: dateiname(titel, h) };
    },
    bestellZeile
  };
})(typeof window !== 'undefined' ? window : globalThis);
