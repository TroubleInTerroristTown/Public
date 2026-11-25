/*
 * Datenmodell und Berechnungen – entspricht Position/Holzliste/Werkzeug/Aufgabe/Einheit der Android-App.
 * Das JSON-Format ist identisch, damit Listen zwischen Android und iPhone ausgetauscht werden können.
 */
(function (global) {
  'use strict';

  const TYP = { HOLZ: 'holz', LFM: 'lfm', PLATTE: 'platte', MATERIAL: 'material', TITEL: 'titel' };
  const PRIO = { GRUEN: 0, GELB: 1, ROT: 2 };

  // ------------------------------------------------------------------ Zahlen (deutsches Format)
  const Fmt = {
    fix(d, n) { return (d || 0).toLocaleString('de-DE', { minimumFractionDigits: n, maximumFractionDigits: n }); },
    num(d) { return d == null ? '' : (+d).toLocaleString('de-DE', { maximumFractionDigits: 3, useGrouping: false }); },
    menge(d) { return d == null ? '' : (+d).toLocaleString('de-DE', { maximumFractionDigits: 2 }); },
    euro(d) { return Fmt.fix(d, 2) + ' €'; },
    parse(s) {
      if (s == null) return null;
      s = String(s).trim().replace(/\s/g, '');
      if (!s) return null;
      if (s.includes(',')) s = s.replace(/\./g, '').replace(',', '.');
      const d = Number(s);
      return isFinite(d) ? d : null;
    },
    querschnitt(b, h) { return b == null && h == null ? '' : (b == null ? '–' : Fmt.num(b)) + '/' + (h == null ? '–' : Fmt.num(h)); }
  };

  // ------------------------------------------------------------------ Einheiten
  const Einheit = {
    ALLE: ['Stk', 'm', 'm²', 'm³', 'kg', 't', 'l', 'Sack', 'Paket', 'Rolle', 'Eimer', 'Karton', 'Kartusche', 'Palette', 'Bund', 'Satz', 'Dose'],
    PACKUNGEN: ['Paket', 'Sack', 'Rolle', 'Karton', 'Eimer', 'Palette', 'Bund', 'Dose', 'Kartusche'],
    norm(s) {
      if (s == null) return '';
      const t = String(s).trim(), u = t.toUpperCase().replace(/\./g, '');
      const m = {
        'M2': 'm²', 'QM': 'm²', 'M²': 'm²', 'QUADRATMETER': 'm²', 'M3': 'm³', 'CBM': 'm³', 'M³': 'm³', 'KUBIKMETER': 'm³',
        'M': 'm', 'LFM': 'm', 'LFDM': 'm', 'LM': 'm', 'MTR': 'm', 'METER': 'm',
        'STK': 'Stk', 'ST': 'Stk', 'STCK': 'Stk', 'STÜCK': 'Stk', 'STUECK': 'Stk', 'PCE': 'Stk', 'PCS': 'Stk', 'PLATTE': 'Stk', 'PLATTEN': 'Stk',
        'KG': 'kg', 'KILO': 'kg', 'T': 't', 'TO': 't', 'TONNE': 't', 'L': 'l', 'LTR': 'l', 'LITER': 'l',
        'SA': 'Sack', 'SAC': 'Sack', 'SCK': 'Sack', 'SACK': 'Sack', 'PAK': 'Paket', 'PAKET': 'Paket', 'PA': 'Paket', 'PCK': 'Paket', 'PACK': 'Paket',
        'RO': 'Rolle', 'ROL': 'Rolle', 'ROLLE': 'Rolle', 'RLL': 'Rolle', 'EI': 'Eimer', 'EIM': 'Eimer', 'EIMER': 'Eimer',
        'KAR': 'Karton', 'KRT': 'Karton', 'KTN': 'Karton', 'KARTON': 'Karton', 'PAL': 'Palette', 'PALETTE': 'Palette',
        'BD': 'Bund', 'BUND': 'Bund', 'SAT': 'Satz', 'SATZ': 'Satz', 'SET': 'Satz', 'DS': 'Dose', 'DOSE': 'Dose', 'KARTUSCHE': 'Kartusche', 'KTS': 'Kartusche'
      };
      return u === '' ? '' : (m[u] || t);
    },
    ganzzahlig(e) { e = Einheit.norm(e); return !['m', 'm²', 'm³', 'kg', 't', 'l', ''].includes(e); },
    gleich(a, b) { return Einheit.norm(a).toLowerCase() === Einheit.norm(b).toLowerCase(); }
  };

  const v = d => (d == null ? 0 : d);
  const leer = s => s == null || String(s).trim() === '';

  // ------------------------------------------------------------------ Position
  const P = {
    neu(typ) {
      return { typ: typ || TYP.HOLZ, bez: '', holzart: '', bem: '' };
    },
    typName(t) {
      return { lfm: 'Latten & Bretter', platte: 'Platten', material: 'Material', titel: 'Überschrift' }[t] || 'Balken & Kanthölzer';
    },
    symbol(t) { return { lfm: '📏', platte: '▦', material: '📦', titel: '≡' }[t] || '🌲'; },
    farbe(t) { return { lfm: '#E67E22', platte: '#2E7D32', material: '#6A4C93', titel: '#66707A' }[t] || '#8D5A2B'; },

    hatFlaechenEingabe(p) { return p.typ === TYP.PLATTE && ((p.flL != null && p.flB != null) || p.fl != null); },
    flaeche(p) {
      if (p.typ !== TYP.PLATTE) return 0;
      if (p.flL != null && p.flB != null) return p.flL * p.flB;
      if (p.fl != null) return p.fl;
      return v(p.stk) * v(p.l) * v(p.b) / 100;
    },
    plattenFlaecheEinzeln(p) { return p.typ === TYP.PLATTE && p.l != null && p.b != null ? p.l * p.b / 100 : 0; },
    plattenAnzahl(p) {
      if (p.typ !== TYP.PLATTE) return null;
      if (!P.hatFlaechenEingabe(p)) return p.stk == null ? null : p.stk;
      const pf = P.plattenFlaecheEinzeln(p);
      if (pf <= 0) return null;
      return Math.ceil(P.flaeche(p) * (1 + v(p.vs) / 100) / pf - 1e-9);
    },
    plattenFlaecheGesamt(p) { const n = P.plattenAnzahl(p); return n == null ? 0 : n * P.plattenFlaecheEinzeln(p); },

    bedarf(p) {
      if (p.typ !== TYP.MATERIAL || p.menge == null) return null;
      let b = Math.round(p.menge * (1 + v(p.vs) / 100) * 1e6) / 1e6;
      if (Einheit.ganzzahlig(p.einh) && p.pack == null) b = Math.ceil(b - 1e-9);
      return b;
    },
    hatPackung(p) { return p.typ === TYP.MATERIAL && p.pack != null && p.pack > 0; },
    packungen(p) { const b = P.bedarf(p); return b == null || !P.hatPackung(p) ? null : Math.ceil(b / p.pack - 1e-9); },
    packName(p) { return leer(p.packName) ? 'Packung' : p.packName.trim(); },

    laufmeter(p) { return p.typ === TYP.HOLZ ? v(p.stk) * v(p.l) : p.typ === TYP.LFM ? v(p.lfm) : 0; },
    volumen(p) {
      if (p.typ === TYP.TITEL) return 0;
      if (p.typ === TYP.MATERIAL) {
        if (Einheit.norm(p.einh) !== 'm³') return 0;
        const m = P.mengeIn(p, 'm³'); return m == null ? 0 : m;
      }
      if (p.typ === TYP.PLATTE) {
        const n = P.plattenAnzahl(p);
        if (n != null && P.plattenFlaecheEinzeln(p) > 0) return n * P.plattenFlaecheEinzeln(p) * v(p.h) / 100;
        return P.flaeche(p) * (1 + v(p.vs) / 100) * v(p.h) / 100;
      }
      return P.laufmeter(p) * v(p.b) * v(p.h) / 10000;
    },

    bestellText(p) {
      if (p.typ === TYP.MATERIAL) {
        const pk = P.packungen(p);
        if (pk != null) return Fmt.num(pk) + ' ' + P.packName(p);
        const b = P.bedarf(p); return b == null ? '' : Fmt.menge(b) + ' ' + Einheit.norm(p.einh);
      }
      if (p.typ === TYP.PLATTE) { const n = P.plattenAnzahl(p); return n == null ? '' : Fmt.num(n) + (n === 1 ? ' Platte' : ' Platten'); }
      if (p.typ === TYP.LFM) return p.lfm == null ? '' : Fmt.menge(p.lfm) + ' m';
      if (p.typ === TYP.HOLZ) return p.stk == null ? '' : Fmt.num(p.stk) + ' Stk';
      return '';
    },

    preisEinheit(p) {
      if (!leer(p.preisEinh)) return Einheit.norm(p.preisEinh);
      switch (p.typ) {
        case TYP.PLATTE: return 'm²';
        case TYP.MATERIAL: return P.hatPackung(p) ? P.packName(p) : Einheit.norm(p.einh);
        case TYP.HOLZ: case TYP.LFM: return 'm';
        default: return '';
      }
    },
    mengeIn(p, einh) {
      const u = Einheit.norm(einh);
      switch (p.typ) {
        case TYP.MATERIAL: {
          const pk = P.packungen(p);
          if (pk != null && u.toLowerCase() === P.packName(p).toLowerCase()) return pk;
          if (u.toLowerCase() === Einheit.norm(p.einh).toLowerCase() || u === '') return pk != null ? pk * p.pack : P.bedarf(p);
          if (pk != null && u === 'Stk') return pk;
          return null;
        }
        case TYP.PLATTE:
          if (u === 'Stk') return P.plattenAnzahl(p);
          if (u === 'm²') return P.plattenAnzahl(p) != null && P.plattenFlaecheEinzeln(p) > 0 ? P.plattenFlaecheGesamt(p) : P.flaeche(p) * (1 + v(p.vs) / 100);
          if (u === 'm³') return P.volumen(p);
          return null;
        case TYP.HOLZ: case TYP.LFM:
          if (u === 'm') return P.laufmeter(p);
          if (u === 'm³') return P.volumen(p);
          if (u === 'Stk') return p.typ === TYP.HOLZ ? (p.stk == null ? null : p.stk) : null;
          return null;
        default: return null;
      }
    },
    betrag(p) {
      if (p.preis == null || p.typ === TYP.TITEL) return null;
      const m = P.mengeIn(p, P.preisEinheit(p));
      return m == null ? null : m * p.preis;
    },

    /** Kurzbeschreibung der Maße für die Liste. */
    masse(p) {
      switch (p.typ) {
        case TYP.HOLZ: return [p.b != null || p.h != null ? Fmt.querschnitt(p.b, p.h) + ' cm' : '', p.l != null ? Fmt.fix(p.l, 2) + ' m' : ''].filter(Boolean).join(' · ');
        case TYP.LFM: return p.b != null || p.h != null ? Fmt.querschnitt(p.b, p.h) + ' cm' : '';
        case TYP.PLATTE: {
          const f = P.flaeche(p), parts = [];
          if (f > 0) parts.push(Fmt.menge(f) + ' m²' + (v(p.vs) ? ' + ' + Fmt.num(p.vs) + ' %' : ''));
          if (p.l != null && p.b != null) parts.push(Fmt.num(p.l * 100) + '×' + Fmt.num(p.b) + (p.h != null ? '×' + Fmt.num(p.h * 10) + ' mm' : ' cm'));
          return parts.join(' · ');
        }
        case TYP.MATERIAL: {
          const parts = [];
          if (p.menge != null) parts.push(Fmt.menge(p.menge) + ' ' + Einheit.norm(p.einh) + (v(p.vs) ? ' + ' + Fmt.num(p.vs) + ' %' : ''));
          if (P.hatPackung(p)) parts.push(P.packName(p) + ' à ' + Fmt.num(p.pack) + ' ' + Einheit.norm(p.einh));
          return parts.join(' · ');
        }
      }
      return '';
    }
  };

  // ------------------------------------------------------------------ Liste (Baustelle)
  const Liste = {
    neu() {
      const d = new Date();
      return {
        version: 1, id: 'w' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7),
        projekt: '', kunde: '', bauteil: '', datum: d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' }),
        bearbeiter: '', notiz: '', awDatei: '', awDatum: '', geaendert: Date.now(), positionen: [], werkzeug: [], aufgaben: []
      };
    },
    titel(h) { return leer(h.projekt) ? 'Baustelle ohne Namen' : h.projekt.trim(); },
    anzahlPositionen(h) { return h.positionen.filter(p => p.typ !== TYP.TITEL).length; },
    summeVolumen(h) { return h.positionen.reduce((s, p) => s + P.volumen(p), 0); },
    summeBetrag(h) { let s = 0, da = false; for (const p of h.positionen) { const b = P.betrag(p); if (b != null) { s += b; da = true; } } return da ? s : null; },
    posNummer(h, i) {
      if (h.positionen[i].typ === TYP.TITEL) return 0;
      let n = 0; for (let k = 0; k <= i; k++) if (h.positionen[k].typ !== TYP.TITEL) n++; return n;
    },
    /** Sicherstellen, dass alle Felder vorhanden sind (z. B. nach Import aus Android). */
    reparieren(h) {
      h.positionen = Array.isArray(h.positionen) ? h.positionen : [];
      h.werkzeug = Array.isArray(h.werkzeug) ? h.werkzeug : [];
      h.aufgaben = Array.isArray(h.aufgaben) ? h.aufgaben : [];
      for (const k of ['projekt', 'kunde', 'bauteil', 'datum', 'bearbeiter', 'notiz']) if (h[k] == null) h[k] = '';
      if (!h.id) h.id = Liste.neu().id;
      return h;
    }
  };

  // ------------------------------------------------------------------ Plattenvorlagen
  const PLATTEN = [
    ['OSB/3 – Typ 3'],
    ['OSB/3', 'OSB-Platten', 2.50, 125, 12], ['OSB/3', 'OSB-Platten', 2.50, 125, 15], ['OSB/3', 'OSB-Platten', 2.50, 125, 18], ['OSB/3', 'OSB-Platten', 2.50, 125, 22],
    ['OSB/3 N+F', 'OSB-Verlegeplatten N+F', 2.50, 67.5, 18], ['OSB/3 N+F', 'OSB-Verlegeplatten N+F', 2.50, 67.5, 22], ['OSB/3 N+F', 'OSB-Verlegeplatten N+F', 2.50, 67.5, 25],
    ['Gipsplatten'],
    ['Gipskarton GKB', 'Gipskartonplatten', 2.00, 125, 12.5], ['Gipskarton GKB', 'Gipskartonplatten', 2.50, 125, 12.5],
    ['Gipskarton GKF (Feuerschutz)', 'Gipskartonplatten GKF', 2.00, 125, 12.5], ['Gipskarton GKF (Feuerschutz)', 'Gipskartonplatten GKF', 2.00, 125, 15],
    ['Gipskarton GKBI (imprägniert)', 'Gipskartonplatten GKBI', 2.00, 125, 12.5],
    ['Gipsfaserplatte', 'Gipsfaserplatten', 1.50, 100, 12.5], ['Gipsfaserplatte', 'Gipsfaserplatten', 2.54, 124.5, 12.5],
    ['Dreischichtplatten'],
    ['Dreischichtplatte Fichte', 'Dreischichtplatten', 5.00, 205, 19], ['Dreischichtplatte Fichte', 'Dreischichtplatten', 5.00, 205, 27],
    ['Dreischichtplatte Fichte', 'Dreischichtplatten', 5.00, 205, 42], ['Dreischichtplatte Fichte', 'Dreischichtplatten', 2.50, 125, 19],
    ['Dreischicht-Schalungsplatte', 'Schalungsplatten', 2.00, 50, 27]
  ];

  const BEZEICHNUNGEN = {
    holz: ['Sparren', 'Firstpfette', 'Mittelpfette', 'Fußpfette', 'Pfette', 'Schwelle', 'Rähm', 'Stiel', 'Riegel', 'Strebe', 'Kopfband', 'Zange',
      'Kehlbalken', 'Deckenbalken', 'Wechsel', 'Gratsparren', 'Kehlsparren', 'Aufschiebling', 'Stichbalken', 'Bundbalken', 'Unterzug', 'Stützen', 'Kantholz'],
    lfm: ['Dachlatten', 'Konterlatten', 'Traglattung', 'Rauhspund', 'Schalung', 'Rhombusleisten', 'Bretter', 'Bohlen', 'Ortgangbrett', 'Traufbohle', 'Lattung'],
    platte: ['Dachschalung', 'Wandbeplankung', 'Bodenplatten', 'Deckenbekleidung', 'Unterdeckplatten'],
    material: ['Holzbauschrauben', 'Tellerkopfschrauben', 'Zwischensparrendämmung', 'Dampfbremse', 'Unterdeckbahn', 'Klebeband', 'Winkelverbinder',
      'Balkenschuhe', 'Montageschaum', 'Silikon', 'Lasur', 'Mörtel']
  };
  const HOLZARTEN = ['KVH NSi C24', 'KVH Si C24', 'BSH GL24h', 'BSH GL28h', 'Duobalken C24', 'Triobalken C24', 'Fichte/Tanne S10',
    'Fichte S10 imprägniert', 'Fichte', 'Lärche', 'Douglasie', 'Eiche', 'Kiefer'];

  // ------------------------------------------------------------------ Werkzeug
  const GRUNDAUSSTATTUNG = ['Akkuschrauber + Akkus & Ladegerät', 'Bit-Satz', 'Zollstock / Maßband', 'Wasserwaage', 'Zimmermannsbleistift',
    'Zimmermannswinkel', 'Hammer', 'Cuttermesser', 'Kabeltrommel', 'Erste-Hilfe-Kasten'];
  const R = (m, ...w) => ({ m: new RegExp(m, 'i'), w });
  const REGELN_MATERIAL = [
    R('\\bkvh\\b|\\bbsh\\b|kantholz|balken|sparren|pfette|konstruktionsvollholz|brettschicht|stiel|schwelle', 'Handkreissäge', 'Kappsäge', 'Zimmermannswinkel', 'Schraubzwingen'),
    R('latte|lattung|brett|schalung|rauhspund|rauspund|diele|terrasse|balkonbrett', 'Kappsäge', 'Handkreissäge', 'Schlagschnur'),
    R('\\bosb|dreischicht|sperrholz|multiplex|spanplatte|holzfaserplatte|unterdeckplatte|\\bdwd\\b|agepan', 'Handkreissäge mit Führungsschiene', 'Stichsäge', 'Plattenheber'),
    R('gipskarton|\\bgk[bfi]?\\b|rigips|fermacell|gipsfaser|trockenbau|\\b(cw|uw|cd|ud)\\b|ständerwerk', 'Gipskartonmesser', 'Gipsraspel', 'Plattenheber', 'Blechschere', 'Spachtel & Glätter'),
    R('dämm|daemm|mineralwolle|glaswolle|steinwolle|klemmfilz|zellulose|holzfaser(?!platte)', 'Dämmstoffmesser', 'Dämmstoffsäge', 'FFP2-Masken', 'Schutzbrille'),
    R('dampfbrems|dampfsperr|folie|unterdeckbahn|unterspann|\\budb\\b|\\busb\\b|intello|bahn\\b', 'Tacker + Klammern', 'Andrückroller', 'Cuttermesser'),
    R('klebeband|tescon|anschlussband|dichtband|kompriband', 'Andrückroller', 'Schere'),
    R('schraube|schrauben|\\bspax|tellerkopf|vollgewinde', 'Akkuschrauber + Akkus & Ladegerät', 'Bit-Satz'),
    R('(1[6-9]\\d|[2-5]\\d\\d) ?mm.*schraub|schraub.*\\b(1[6-9]\\d|[2-5]\\d\\d)\\b|\\b[8-9] ?[x×] ?(1[6-9]\\d|[2-5]\\d\\d)\\b|\\b1[0-2] ?[x×] ?\\d{3}\\b', 'Schlagschrauber'),
    R('nagel|nägel|klammer|rillennagel|ankernagel', 'Druckluftnagler + Kompressor', 'Hammer'),
    R('winkelverbinder|balkenschuh|pfettenanker|lochband|schlitzband|holzverbinder|knagge', 'Ankernagelgerät oder Hammer', 'Akkuschrauber + Akkus & Ladegerät'),
    R('dübel|duebel|\\banker\\b|gewindestange|schwerlast|verankerung|bolzenanker', 'Bohrhammer', 'Betonbohrer-Satz', 'Ausblaspumpe', 'Ratsche + Nüsse'),
    R('injektion|verbundmörtel|vmz|\\bfis\\b', 'Auspresspistole für Injektionsmörtel'),
    R('silikon|acryl|dichtstoff|kartusche|kleber|kleb(?!eband)', 'Kartuschenpistole'),
    R('bauschaum|montageschaum|pu-schaum', 'Schaumpistole', 'Schaumreiniger'),
    R('lasur|holzschutz|grundier|imprägnier|anstrich|farbe|\\böl\\b|pullex', 'Pinsel & Farbroller', 'Rührholz', 'Abdeckfolie', 'Exzenterschleifer + Schleifpapier'),
    R('ziegel|dachstein|dachpfanne|eindeckung|first|grat', 'Ziegelschneider / Trennschleifer', 'Dachdeckerhammer', 'Dachleiter', 'Absturzsicherung (PSA)'),
    R('rinne|fallrohr|blech|verwahrung|attika|titanzink|\\bzink', 'Blechschere', 'Falzzange', 'Lötkolben', 'Nieter'),
    R('bitumen|schweißbahn|schweissbahn', 'Gasbrenner', 'Andrückroller', 'Feuerlöscher'),
    R('mörtel|moertel|beton|estrich|zement|putz', 'Mörteleimer', 'Kelle', 'Rührwerk'),
    R('dachfenster|velux|\\broto\\b|eindeckrahmen', 'Keile & Unterlegplättchen', 'Montageschaum + Schaumpistole')
  ];
  const REGELN_ARBEIT = [
    R('demontage|demontier|abbruch|abbrechen|rückbau|zurückbauen|ausbauen', 'Säbelsäge', 'Kuhfuß / Brecheisen', 'Schutzhandschuhe'),
    R('entsorg', 'Schuttsäcke', 'Schubkarre'),
    R('abfangen|abstützen|stützen', 'Baustützen', 'Kanthölzer zum Unterlegen'),
    R('gerüst|deckenmontage|über kopf|überkopf', 'Fahrgerüst / Arbeitsgerüst'),
    R('dach|first|traufe|sparren|höhe|absturz', 'Leiter', 'Absturzsicherung (PSA)'),
    R('balkon|geländer', 'Leiter', 'Absperrband'),
    R('lagern|zwischenlager', 'Abdeckplane'),
    R('fenster|tür|tuer', 'Keile & Unterlegplättchen', 'Montageschaum + Schaumpistole'),
    R('schleif', 'Exzenterschleifer + Schleifpapier'),
    R('bohr|dübel|verankern', 'Bohrhammer', 'Betonbohrer-Satz'),
    R('sockel|beton|fundament', 'Bohrhammer', 'Mörteleimer', 'Kelle'),
    R('abbund|abbinden|zapfen|blatt|kerve|klaue', 'Kettenstemmer', 'Abbundsäge', 'Stemmeisen'),
    R('hobel', 'Elektrohobel'),
    R('prüfen|überprüfen|ertüchtig|feuchte', 'Feuchtemessgerät', 'Taschenlampe')
  ];
  const Werkzeug = {
    prioName: p => (p === PRIO.ROT ? 'Muss mit' : p === PRIO.GRUEN ? 'Optional' : 'Wichtig'),
    prioSymbol: p => (p === PRIO.ROT ? '🔴' : p === PRIO.GRUEN ? '🟢' : '🟡'),
    schluessel: s => String(s || '').toLowerCase().replace(/[^a-zäöüß0-9]/g, ''),
    alleNamen() {
      const s = new Set(GRUNDAUSSTATTUNG);
      for (const r of REGELN_MATERIAL.concat(REGELN_ARBEIT)) r.w.forEach(w => s.add(w));
      ['Kettensäge', 'Multifunktionswerkzeug', 'Laser / Linienlaser', 'Nivelliergerät', 'Stromerzeuger', 'Baustrahler', 'Sackkarre',
        'Spanngurte', 'Stichsäge', 'Winkelschleifer', 'Bandschleifer'].forEach(w => s.add(w));
      return [...s].sort((a, b) => a.localeCompare(b, 'de'));
    },
    /** Vorschläge wie in der Android-App: aus Material (🔴) und Arbeitsschritten/Notiz/Aufgaben (🟡). */
    vorschlagen(h) {
      const out = new Map(), vorhanden = new Set(h.werkzeug.map(w => Werkzeug.schluessel(w.name)));
      GRUNDAUSSTATTUNG.forEach(g => vorhanden.add(Werkzeug.schluessel(g)));
      const kurz = s => (s.length > 40 ? s.slice(0, 38) + '…' : s);
      const add = (name, grund, prio) => {
        const k = Werkzeug.schluessel(name);
        if (vorhanden.has(k) || out.has(k)) return;
        out.set(k, { name, grund, prio, gewaehlt: true });
      };
      for (const p of h.positionen) {
        if (p.typ === TYP.TITEL) continue;
        let t = (p.bez + ' ' + p.holzart + ' ' + p.typ).toLowerCase();
        if (p.typ === TYP.HOLZ || p.typ === TYP.LFM) t += ' balken';
        for (const r of REGELN_MATERIAL) if (r.m.test(t)) r.w.forEach(w => add(w, 'wegen ' + kurz(p.bez || p.holzart), PRIO.ROT));
      }
      const texte = h.positionen.filter(p => p.typ === TYP.TITEL).map(p => p.bez)
        .concat((h.notiz || '').split('\n'), h.aufgaben.map(a => a.text), [h.bauteil || '']);
      for (const z of texte) {
        const t = String(z || '').replace(/^[\s•\-–*]+/, '').trim();
        if (!t) continue;
        for (const r of REGELN_ARBEIT) if (r.m.test(t.toLowerCase())) r.w.forEach(w => add(w, 'wegen „' + kurz(t) + '“', PRIO.GELB));
      }
      return [...out.values()].sort((a, b) => b.prio - a.prio);
    }
  };

  const Aufgabe = {
    prioName: p => (p === PRIO.ROT ? 'Dringend' : p === PRIO.GRUEN ? 'Hat Zeit' : 'Normal'),
    neu: () => ({ text: '', abschnitt: '', info: '', erledigt: false, prio: PRIO.GELB, heute: false })
  };

  global.M = { TYP, PRIO, Fmt, Einheit, P, Liste, PLATTEN, BEZEICHNUNGEN, HOLZARTEN, GRUNDAUSSTATTUNG, Werkzeug, Aufgabe, leer };
})(typeof window !== 'undefined' ? window : globalThis);
