/* Materialliste – Web-App (iPhone/Android/PC). Daten bleiben lokal auf dem Gerät. */
(function () {
  'use strict';
  const { TYP, PRIO, Fmt, Einheit, P, Liste, PLATTEN, BEZEICHNUNGEN, HOLZARTEN, Werkzeug, Aufgabe, leer } = window.M;

  // ================================================================== Speicher
  const KEY = 'materialliste.listen.v1', KEY_EINST = 'materialliste.einstellungen.v1';
  let listen = [];
  function laden() {
    try { listen = (JSON.parse(localStorage.getItem(KEY)) || []).map(Liste.reparieren); } catch (e) { listen = []; }
  }
  function speichernAlle() {
    try { localStorage.setItem(KEY, JSON.stringify(listen)); }
    catch (e) { toast('⚠️ Speichern fehlgeschlagen – Speicher voll?'); }
  }
  function speichern(h) { h.geaendert = Date.now(); speichernAlle(); }
  const finde = id => listen.find(h => h.id === id);
  const einst = () => { try { return JSON.parse(localStorage.getItem(KEY_EINST)) || {}; } catch (e) { return {}; } };
  const einstSetzen = (k, v) => { const e = einst(); e[k] = v; try { localStorage.setItem(KEY_EINST, JSON.stringify(e)); } catch (x) {} };
  if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});

  // ================================================================== DOM-Helfer
  function el(tag, attrs, ...kinder) {
    const e = document.createElement(tag);
    if (attrs) for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === 'class') e.className = v;
      else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
      else if (k === 'html') e.innerHTML = v;
      else e.setAttribute(k, v === true ? '' : v);
    }
    for (const k of kinder.flat()) if (k != null && k !== false) e.append(k instanceof Node ? k : String(k));
    return e;
  }
  let toastTimer;
  function toast(t) {
    const d = document.getElementById('toast');
    d.textContent = t; d.classList.add('zeigen');
    clearTimeout(toastTimer); toastTimer = setTimeout(() => d.classList.remove('zeigen'), 2400);
  }

  // ================================================================== Dialoge
  function dialog({ titel, inhalt, knoepfe = [], beimSchliessen }) {
    const box = document.getElementById('dialoge');
    const koerper = el('div', { class: 'koerper' }, inhalt || '');
    const kn = el('div', { class: 'knoepfe' });
    const d = el('div', { class: 'dialog', role: 'dialog', 'aria-modal': 'true', 'aria-label': titel || '' }, titel ? el('h2', null, titel) : null, koerper, knoepfe.length ? kn : null);
    const ov = el('div', { class: 'overlay' }, d);
    const zu = () => { ov.remove(); if (beimSchliessen) beimSchliessen(); };
    ov.addEventListener('click', e => { if (e.target === ov) zu(); });
    for (const k of knoepfe) {
      kn.append(el('button', {
        class: (k.haupt ? 'haupt ' : '') + (k.links ? 'links' : ''), type: 'button',
        onclick: () => { const r = k.klick ? k.klick() : undefined; if (r !== false) zu(); }
      }, k.text));
    }
    box.append(ov);
    return { zu, koerper, ov };
  }

  /** Auswahlliste. items: {ico, text, sub, klick, ueber (Zwischenüberschrift), gefahr} */
  function menue(titel, items) {
    const ul = el('ul', { class: 'menue' });
    let dl;
    for (const it of items) {
      if (it.ueber) { ul.append(el('li', { class: 'ueber' }, it.ueber)); continue; }
      ul.append(el('li', null, el('button', {
        type: 'button', class: it.gefahr ? 'gefahr' : null,
        onclick: () => { dl.zu(); it.klick(); }
      }, it.ico ? el('span', { class: 'ico' }, it.ico) : null, el('span', null, it.sub ? el('b', null, it.text) : it.text, it.sub ? el('small', null, it.sub) : null))));
    }
    dl = dialog({ titel, inhalt: ul, knoepfe: [{ text: 'Abbrechen' }] });
    return dl;
  }

  function frage(titel, text, jaText, ja, gefahr) {
    dialog({ titel, inhalt: el('p', null, text), knoepfe: [{ text: 'Abbrechen' }, { text: jaText, haupt: true, klick: ja }] });
  }

  // Formularfelder
  let dlZaehler = 0;
  function feld(label, wert, o = {}) {
    const id = 'f' + (++dlZaehler);
    let input;
    if (o.mehrzeilig) input = el('textarea', { id, placeholder: o.hinweis || '' });
    else input = el('input', {
      id, type: 'text', placeholder: o.hinweis || '', class: o.zahl ? 'zahl' : null,
      inputmode: o.zahl ? 'decimal' : null, autocapitalize: o.zahl ? 'off' : 'sentences', autocomplete: 'off', enterkeyhint: 'next'
    });
    input.value = wert == null ? '' : (o.zahl ? Fmt.num(wert) : wert);
    let liste = null;
    if (o.vorschlaege) {
      liste = el('datalist', { id: id + 'l' }, o.vorschlaege.map(v => el('option', { value: v })));
      input.setAttribute('list', id + 'l');
    }
    const box = el('div', { class: 'feld' }, el('label', { for: id }, label), input, liste);
    box.input = input;
    if (o.zahl) input.addEventListener('focus', () => setTimeout(() => input.select(), 0));
    return box;
  }
  const reihe = (...f) => el('div', { class: 'reihe' }, ...f);
  const zahl = f => Fmt.parse(f.input.value);
  const text = f => f.input.value.trim();
  function zahlenPruefen(felder) {
    let ok = true;
    for (const f of felder) {
      const s = f.input.value.trim();
      const bad = s !== '' && Fmt.parse(s) == null;
      f.input.classList.toggle('fehler', bad);
      if (bad && ok) { ok = false; f.input.focus(); }
    }
    if (!ok) toast('Bitte eine gültige Zahl eingeben');
    return ok;
  }

  // ================================================================== Datei teilen / speichern
  async function dateiTeilen(name, daten, mime) {
    const blob = new Blob([daten], { type: mime });
    try {
      const file = new File([blob], name, { type: mime });
      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({ files: [file], title: name });
        return;
      }
    } catch (e) {
      if (e && e.name === 'AbortError') return;
    }
    const url = URL.createObjectURL(blob);
    const a = el('a', { href: url, download: name });
    document.body.append(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
    toast('Datei gespeichert: ' + name);
  }
  const XLSX_MIME = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  // ================================================================== Routing
  function gehe(pfad) { location.hash = pfad; }
  window.addEventListener('hashchange', zeichnen);

  function zeichnen() {
    const teile = location.hash.replace(/^#\/?/, '').split('/').filter(Boolean);
    document.getElementById('dialoge').innerHTML = '';
    if (teile[0] === 'b' && finde(teile[1])) {
      const h = finde(teile[1]);
      if (teile[2] === 'material') return seiteMaterial(h);
      if (teile[2] === 'werkzeug') return seiteWerkzeug(h);
      if (teile[2] === 'aufgaben') return seiteAufgaben(h);
      return seiteBaustelle(h);
    }
    seiteStart();
  }

  function seite({ titel, zurueck, menuItems, inhalt, status, fuss }) {
    const app = document.getElementById('app');
    app.innerHTML = '';
    const leiste = el('header', { class: 'leiste' },
      zurueck ? el('button', { 'aria-label': 'Zurück', onclick: () => gehe(zurueck) }, '←') : el('span', { style: 'width:8px' }),
      el('h1', null, titel),
      menuItems ? el('button', { 'aria-label': 'Menü', onclick: () => menue(null, menuItems()) }, '⋮') : null);
    const main = el('main', { class: 'inhalt' }, inhalt);
    app.append(leiste, main);
    if (status) app.append(el('div', { class: 'status' }, status));
    if (fuss) app.append(el('footer', { class: 'fuss' }, fuss));
    return main;
  }

  // ================================================================== Startseite
  function istIOS() { return /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1); }
  function istInstalliert() { return window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches; }

  function seiteStart() {
    const sortiert = [...listen].sort((a, b) => b.geaendert - a.geaendert);
    const inhalt = [];
    if (istIOS() && !istInstalliert() && !einst().bannerWeg) {
      inhalt.push(el('div', { class: 'banner' },
        el('button', { 'aria-label': 'Hinweis schließen', onclick: () => { einstSetzen('bannerWeg', true); zeichnen(); } }, '✕'),
        el('b', null, '📲 Als App installieren: '),
        'in Safari unten auf ', el('b', null, 'Teilen'), ' tippen (Quadrat mit Pfeil nach oben) → „Zum Home-Bildschirm“. Dann startet die Materialliste wie eine App und funktioniert auch ohne Internet.'));
    }
    if (!sortiert.length) inhalt.push(el('div', { class: 'leerhinweis' }, 'Noch keine Baustelle angelegt.', el('br'), el('br'), 'Tippe unten auf „＋ Neue Baustelle“.'));
    for (const h of sortiert) {
      const wz = h.werkzeug.length, wzDa = h.werkzeug.filter(w => w.eingepackt).length;
      const au = h.aufgaben.length, auDa = h.aufgaben.filter(a => a.erledigt).length;
      const unter = [h.kunde, h.bauteil, h.datum].filter(x => !leer(x)).join(' · ');
      inhalt.push(el('div', { class: 'karte tippbar', onclick: () => gehe('/b/' + h.id) },
        el('div', { class: 'mitte' },
          el('div', { class: 'titel' }, Liste.titel(h)),
          unter ? el('div', { class: 'unter' }, unter) : null,
          el('div', { class: 'unter' }, '🔧 ' + wzDa + '/' + wz + ' dabei   ✅ ' + auDa + '/' + au + ' erledigt'),
          el('div', { class: 'klein' }, 'geändert ' + new Date(h.geaendert).toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' }))),
        el('div', { class: 'rechts' },
          el('div', { class: 'wert' }, Fmt.fix(Liste.summeVolumen(h), 2) + ' m³'),
          el('div', { class: 'klein' }, Liste.anzahlPositionen(h) + ' Positionen'))));
    }
    seite({
      titel: 'Meine Baustellen',
      menuItems: () => [
        { ico: '💾', text: 'Sicherung speichern', sub: 'Alle Baustellen als Datei (z. B. in iCloud Drive)', klick: sicherungSpeichern },
        { ico: '📂', text: 'Sicherung / Liste laden', sub: 'Datei aus der Web-App oder der Android-App', klick: sicherungLaden },
        { ico: 'ℹ️', text: 'Über die App', klick: ueber }
      ],
      inhalt,
      fuss: [el('button', { class: 'knopf voll', onclick: neueBaustelle }, '＋  Neue Baustelle')]
    });
  }

  function neueBaustelle() {
    const h = Liste.neu();
    h.bearbeiter = einst().bearbeiter || '';
    listen.push(h); speichern(h);
    gehe('/b/' + h.id);
    setTimeout(() => kopfdaten(h, true), 50);
  }

  function ueber() {
    dialog({
      titel: 'Materialliste (Web)', inhalt: el('div', null,
        el('p', null, 'Material, Werkzeug und Aufgaben für deine Baustellen – mit Excel-Export für den PC.'),
        el('p', null, 'Alle Daten bleiben auf diesem Gerät. Mach ab und zu eine Sicherung (Menü ⋮ → Sicherung speichern).'),
        el('p', { class: 'klein' }, 'Kommt später: Arbeitsanweisung (PDF) einlesen, Stunden, Artikellisten (DATANORM/Excel).')),
      knoepfe: [{ text: 'OK', haupt: true }]
    });
  }

  function sicherungSpeichern() {
    const daten = new TextEncoder().encode(JSON.stringify({ app: 'materialliste', version: 1, erstellt: new Date().toISOString(), listen }, null, 1));
    const d = new Date();
    dateiTeilen('Materialliste-Sicherung_' + d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0') + '.json',
      daten, 'application/json');
  }

  function sicherungLaden() {
    const inp = el('input', { type: 'file', accept: '.json,application/json,text/plain' });
    inp.addEventListener('change', async () => {
      const f = inp.files && inp.files[0];
      if (!f) return;
      try {
        const o = JSON.parse(await f.text());
        const neu = Array.isArray(o.listen) ? o.listen : Array.isArray(o) ? o : (o.positionen ? [o] : []);
        if (!neu.length) throw new Error('keine Baustellen gefunden');
        let ersetzt = 0, dazu = 0;
        for (const x of neu.map(Liste.reparieren)) {
          const i = listen.findIndex(h => h.id === x.id);
          if (i >= 0) { listen[i] = x; ersetzt++; } else { listen.push(x); dazu++; }
        }
        speichernAlle(); zeichnen();
        toast(dazu + ' neu, ' + ersetzt + ' aktualisiert');
      } catch (e) {
        dialog({ titel: 'Datei nicht lesbar', inhalt: el('p', null, 'Die Datei ist keine Sicherung der Materialliste (' + e.message + ').'), knoepfe: [{ text: 'OK' }] });
      }
    });
    inp.click();
  }

  // ================================================================== Baustelle
  function kopfKarte(h) {
    const unter = [h.kunde, h.bauteil, h.datum].filter(x => !leer(x)).join(' · ');
    return el('div', { class: 'kopfkarte', onclick: () => kopfdaten(h), role: 'button' },
      el('div', { class: 'titel' }, Liste.titel(h)),
      el('div', { class: 'unter' }, (unter || 'Antippen: Projekt, Kunde, Datum eintragen') + '  ✎'));
  }

  function seiteBaustelle(h) {
    const wz = h.werkzeug.length, wzDa = h.werkzeug.filter(w => w.eingepackt).length;
    const au = h.aufgaben.length, auDa = h.aufgaben.filter(a => a.erledigt).length;
    const notiz = (h.notiz || '').trim();
    const kachel = (cls, ico, titel, sub, klick, breit) =>
      el('button', { class: 'kachel ' + cls + (breit ? ' breit' : ''), onclick: klick }, el('span', { class: 'ico' }, ico), el('div', null, el('b', null, titel), el('span', null, sub)));
    seite({
      titel: 'Baustelle', zurueck: '/',
      menuItems: () => [
        { ico: '✎', text: 'Projekt, Kunde, Datum ändern', klick: () => kopfdaten(h) },
        { ico: '📊', text: 'Excel-Liste teilen / speichern', klick: () => excelMenue(h) },
        { ico: '⧉', text: 'Baustelle kopieren', sub: 'z. B. als Vorlage für die nächste', klick: () => kopieren(h) },
        { ico: '🗑', text: 'Baustelle löschen', gefahr: true, klick: () => frage('Baustelle löschen?', '„' + Liste.titel(h) + '“ mit allen Listen wirklich löschen?', 'Löschen', () => { listen = listen.filter(x => x !== h); speichernAlle(); gehe('/'); }) }
      ],
      inhalt: [
        kopfKarte(h),
        el('div', { class: 'kacheln' },
          kachel('k-material', '📦', 'Material', Liste.anzahlPositionen(h) + ' Positionen', () => gehe('/b/' + h.id + '/material')),
          kachel('k-werkzeug', '🔧', 'Werkzeug', wzDa + ' von ' + wz + ' dabei', () => gehe('/b/' + h.id + '/werkzeug')),
          kachel('k-aufgaben', '✅', 'Aufgaben', auDa + ' von ' + au + ' erledigt', () => gehe('/b/' + h.id + '/aufgaben')),
          kachel('k-notiz', '📝', 'Notiz', notiz ? notiz.slice(0, 60) + (notiz.length > 60 ? '…' : '') : 'Antippen zum Schreiben', () => notizDialog(h))),
        el('div', { class: 'spaeter' }, 'KOMMT SPÄTER'),
        el('div', { class: 'spaeter-liste' }, el('div', null, '📄', el('br'), 'Arbeitsanweisung'), el('div', null, '⏱', el('br'), 'Stunden'), el('div', null, '🔍', el('br'), 'Artikellisten'))
      ]
    });
  }

  function kopieren(h) {
    const k = Liste.reparieren(JSON.parse(JSON.stringify(h)));
    k.id = Liste.neu().id; k.projekt = (h.projekt || '') + ' (Kopie)';
    k.werkzeug.forEach(w => (w.eingepackt = false));
    k.aufgaben.forEach(a => { a.erledigt = false; a.heute = false; });
    k.awDatei = ''; k.awDatum = '';
    listen.push(k); speichern(k); gehe('/b/' + k.id); toast('Kopie angelegt');
  }

  function kopfdaten(h, neu) {
    const f = {
      projekt: feld('Projekt / Bauvorhaben', h.projekt, { hinweis: 'z. B. BV Mustermann Balkon' }),
      kunde: feld('Kunde / Bauherr', h.kunde),
      bauteil: feld('Bauteil', h.bauteil, { hinweis: 'z. B. Dachstuhl, Carport' }),
      datum: feld('Datum', h.datum),
      bearbeiter: feld('Bearbeiter', h.bearbeiter || einst().bearbeiter || '')
    };
    const d = dialog({
      titel: neu ? 'Neue Baustelle' : 'Projekt & Kunde', inhalt: Object.values(f),
      knoepfe: [{ text: 'Abbrechen' }, {
        text: 'Übernehmen', haupt: true, klick: () => {
          for (const k of Object.keys(f)) h[k] = text(f[k]);
          einstSetzen('bearbeiter', h.bearbeiter);
          speichern(h); zeichnen();
        }
      }]
    });
    setTimeout(() => f.projekt.input.focus(), 60);
    return d;
  }

  function notizDialog(h) {
    const f = feld('Notiz', h.notiz, { mehrzeilig: true, hinweis: 'z. B. Schlüssel beim Nachbarn (Hausnr. 3)' });
    dialog({ titel: '📝 Notiz', inhalt: f, knoepfe: [{ text: 'Abbrechen' }, { text: 'Speichern', haupt: true, klick: () => { h.notiz = f.input.value; speichern(h); zeichnen(); } }] });
    setTimeout(() => f.input.focus(), 60);
  }

  function excelMenue(h) {
    const anz = t => h.positionen.filter(p => p.typ !== TYP.TITEL && (t === 'alles' || (t === 'material' ? p.typ === TYP.MATERIAL : p.typ !== TYP.MATERIAL))).length;
    menue('Excel-Liste', [
      { ico: '📊', text: 'Materialliste (ausführlich)', sub: 'Alle Maße, Mengen, Summen und Preise + Bestellliste', klick: () => { const x = Export.materialliste(h); dateiTeilen(x.name, x.daten, XLSX_MIME); } },
      { ico: '🧾', text: 'Bestellliste – alles', sub: anz('alles') + ' Positionen, schlicht zum Bestellen', klick: () => { const x = Export.bestellliste(h, 'alles'); dateiTeilen(x.name, x.daten, XLSX_MIME); } },
      { ico: '🌲', text: 'Bestellliste – nur Holz & Platten', sub: anz('holz') + ' Positionen', klick: () => { const x = Export.bestellliste(h, 'holz'); dateiTeilen(x.name, x.daten, XLSX_MIME); } },
      { ico: '📦', text: 'Bestellliste – nur Material', sub: anz('material') + ' Positionen', klick: () => { const x = Export.bestellliste(h, 'material'); dateiTeilen(x.name, x.daten, XLSX_MIME); } }
    ]);
  }

  // ================================================================== Material
  function seiteMaterial(h) {
    const inhalt = [kopfKarte(h)];
    if (!h.positionen.length) inhalt.push(el('div', { class: 'leerhinweis' }, 'Noch kein Material.', el('br'), el('br'), 'Unten auf „＋ Hinzufügen“ tippen.'));
    h.positionen.forEach((p, i) => {
      const mehr = el('button', { class: 'mehr', 'aria-label': 'Aktionen', onclick: e => { e.stopPropagation(); positionAktionen(h, i); } }, '⋮');
      if (p.typ === TYP.TITEL) {
        inhalt.push(el('div', { class: 'abschnitt', onclick: () => bearbeiten(h, i) }, el('span', null, p.bez || 'Überschrift'), mehr));
        return;
      }
      const unter = [p.holzart, P.masse(p)].filter(x => !leer(x)).join(' · ');
      const vol = P.volumen(p), bt = P.betrag(p);
      const klein = [vol ? Fmt.fix(vol, 3) + ' m³' : '', bt != null ? Fmt.euro(bt) : ''].filter(Boolean).join(' · ');
      inhalt.push(el('div', { class: 'karte tippbar pos', style: 'border-left-color:' + P.farbe(p.typ), onclick: () => bearbeiten(h, i) },
        el('div', { class: 'sym' }, P.symbol(p.typ)),
        el('div', { class: 'mitte' },
          el('div', { class: 'titel' }, p.bez || P.typName(p.typ)),
          unter ? el('div', { class: 'unter' }, unter) : null,
          p.bem ? el('div', { class: 'klein' }, p.bem) : null),
        el('div', { class: 'rechts' }, el('div', { class: 'wert' }, P.bestellText(p) || '–'), klein ? el('div', { class: 'klein' }, klein) : null),
        mehr));
    });
    const holz = h.positionen.filter(p => p.typ === TYP.HOLZ || p.typ === TYP.LFM).reduce((s, p) => s + P.volumen(p), 0);
    const platten = h.positionen.filter(p => p.typ === TYP.PLATTE);
    const status = [];
    if (holz) status.push(el('span', null, 'Holz ', el('b', null, Fmt.fix(holz, 3) + ' m³')));
    if (platten.length) status.push(el('span', null, (status.length ? ' · ' : '') + 'Platten ', el('b', null, platten.reduce((s, p) => s + (P.plattenAnzahl(p) || 0), 0) + ' Stk'),
      ' (' + Fmt.menge(platten.reduce((s, p) => s + P.flaeche(p), 0)) + ' m²)'));
    const betrag = Liste.summeBetrag(h);
    if (betrag != null) status.push(el('span', null, (status.length ? ' · ' : '') + 'Summe ', el('b', null, Fmt.euro(betrag))));
    seite({
      titel: '📦 Material', zurueck: '/b/' + h.id,
      menuItems: () => [
        { ico: '📊', text: 'Excel-Liste teilen / speichern', klick: () => excelMenue(h) },
        { ico: '≡', text: 'Überschrift anfügen', sub: 'z. B. „Dachstuhl“ oder „Dämmung“', klick: () => neuePosition(h, Object.assign(P.neu(TYP.TITEL)), h.positionen.length) },
        { ico: '✎', text: 'Projekt, Kunde, Datum ändern', klick: () => kopfdaten(h) }
      ],
      inhalt,
      status: status.length ? status : null,
      fuss: [el('button', { class: 'knopf', onclick: () => excelMenue(h) }, '📊 Excel'),
        el('button', { class: 'knopf voll', style: 'flex:1.6', onclick: () => hinzufuegen(h, h.positionen.length) }, '＋  Hinzufügen')]
    });
  }

  function hinzufuegen(h, index) {
    const art = (t, text, sub) => ({ ico: P.symbol(t), text, sub, klick: () => neuePosition(h, P.neu(t), index) });
    menue('Was möchtest du hinzufügen?', [
      art(TYP.HOLZ, 'Balken & Kanthölzer', 'Sparren, Pfetten, Stiele … – Stückzahl × Länge'),
      art(TYP.LFM, 'Latten & Bretter', 'Dachlatten, Schalung, Bretter … – in Metern'),
      art(TYP.PLATTE, 'Platten', 'OSB, Gipskarton, Dreischicht … – Fläche eingeben, Anzahl wird berechnet'),
      art(TYP.MATERIAL, 'Sonstiges Material', 'Schrauben, Dämmung, Folie, Mörtel, Säcke …'),
      art(TYP.TITEL, 'Überschrift', 'z. B. „Dachstuhl“ oder „Dämmung“ – macht die Liste übersichtlicher')
    ]);
  }

  function neuePosition(h, p, index) {
    if (p.typ !== TYP.TITEL && leer(p.holzart)) {
      for (let i = Math.min(index, h.positionen.length) - 1; i >= 0; i--) {
        const v = h.positionen[i];
        if (v.typ !== p.typ) continue;
        p.holzart = v.holzart;
        if (p.typ === TYP.MATERIAL && leer(p.einh)) p.einh = v.einh;
        break;
      }
    }
    positionDialog(h, p, true, (pos, weitere) => {
      const at = Math.min(index, h.positionen.length);
      h.positionen.splice(at, 0, pos);
      speichern(h); zeichnen();
      if (weitere) neuePosition(h, P.neu(pos.typ), at + 1);
    });
  }

  function bearbeiten(h, i) {
    const kopie = JSON.parse(JSON.stringify(h.positionen[i]));
    positionDialog(h, kopie, false, pos => { h.positionen[i] = pos; speichern(h); zeichnen(); });
  }

  function positionAktionen(h, i) {
    const p = h.positionen[i];
    const ps = h.positionen;
    menue(p.bez || P.typName(p.typ), [
      { ico: '✎', text: 'Ändern', klick: () => bearbeiten(h, i) },
      { ico: '⧉', text: 'Kopieren (Kopie darunter)', klick: () => { ps.splice(i + 1, 0, JSON.parse(JSON.stringify(p))); speichern(h); zeichnen(); } },
      { ico: '↑', text: 'Nach oben schieben', klick: () => { if (i > 0) { ps.splice(i - 1, 0, ps.splice(i, 1)[0]); speichern(h); zeichnen(); } } },
      { ico: '↓', text: 'Nach unten schieben', klick: () => { if (i < ps.length - 1) { ps.splice(i + 1, 0, ps.splice(i, 1)[0]); speichern(h); zeichnen(); } } },
      { ico: '＋', text: 'Neue Zeile hier darüber', klick: () => hinzufuegen(h, i) },
      { ico: '＋', text: 'Neue Zeile hier darunter', klick: () => hinzufuegen(h, i + 1) },
      { ico: '🗑', text: 'Löschen', gefahr: true, klick: () => frage('Löschen?', '„' + (p.bez || P.typName(p.typ)) + '“ löschen?', 'Löschen', () => { ps.splice(i, 1); speichern(h); zeichnen(); }) }
    ]);
  }

  /** Eingabe einer Position. Neue Positionen: „Speichern“ schließt, „+ Nächste“ öffnet die nächste. */
  function positionDialog(h, p, neu, fertig) {
    let typ = p.typ;
    const bekannteMaterialien = [...new Set(h.positionen.map(x => (x.holzart || '').trim()).filter(Boolean).reverse())];
    const inhalt = el('div');
    let felder = {}, mehrOffen = false;

    function aufbauen() {
      inhalt.innerHTML = '';
      felder = {};
      const titel = typ === TYP.TITEL;
      if (!titel) inhalt.append(el('button', { type: 'button', class: 'art-chip', style: 'color:' + P.farbe(typ), onclick: artWaehlen },
        el('span', null, P.symbol(typ) + '  ' + P.typName(typ)), el('span', { class: 'aendern' }, 'ändern ▾')));
      felder.bez = feld(titel ? 'Überschrift' : 'Was? (Bezeichnung)', p.bez, {
        hinweis: titel ? 'z. B. Dachstuhl' : { holz: 'z. B. Sparren', lfm: 'z. B. Dachlatten', platte: 'z. B. Dachschalung', material: 'z. B. Holzbauschrauben' }[typ],
        vorschlaege: BEZEICHNUNGEN[typ]
      });
      inhalt.append(felder.bez);
      if (titel) return;

      const f = felder;
      if (typ === TYP.HOLZ) {
        f.stk = feld('Stück', p.stk, { zahl: true, hinweis: 'Stk' }); f.l = feld('Länge [m]', p.l, { zahl: true, hinweis: 'm' });
        f.b = feld('Breite [cm]', p.b, { zahl: true, hinweis: 'cm' }); f.h = feld('Höhe [cm]', p.h, { zahl: true, hinweis: 'cm' });
        inhalt.append(reihe(f.stk, f.l), el('div', { class: 'abschnitt-t' }, 'Querschnitt'), reihe(f.b, f.h));
      } else if (typ === TYP.LFM) {
        f.lfm = feld('Wie viele Meter insgesamt?', p.lfm, { zahl: true, hinweis: 'm' });
        f.b = feld('Breite [cm]', p.b, { zahl: true, hinweis: 'cm' }); f.h = feld('Höhe / Dicke [cm]', p.h, { zahl: true, hinweis: 'cm' });
        inhalt.append(f.lfm, el('div', { class: 'abschnitt-t' }, 'Querschnitt'), reihe(f.b, f.h));
      } else if (typ === TYP.PLATTE) {
        inhalt.append(el('button', { type: 'button', class: 'knopf gruen klein', style: 'width:100%;margin-top:12px', onclick: plattenAuswahl }, '▦  Platte auswählen (OSB, Gips …)'));
        f.flL = feld('Länge [m]', p.flL, { zahl: true, hinweis: 'm' }); f.flB = feld('Breite [m]', p.flB, { zahl: true, hinweis: 'm' });
        const alt = !P.hatFlaechenEingabe(p) && p.stk != null;
        f.fl = feld('oder gleich m²', alt ? P.flaeche(p) : p.fl, { zahl: true, hinweis: 'm²' });
        f.vs = feld('Verschnitt [%]', p.vs != null ? p.vs : (neu ? 10 : alt ? 0 : null), { zahl: true, hinweis: '%' });
        f.pl = feld('Länge [cm]', p.l != null ? p.l * 100 : null, { zahl: true, hinweis: 'cm' });
        f.pb = feld('Breite [cm]', p.b, { zahl: true, hinweis: 'cm' });
        f.dicke = feld('Dicke [mm]', p.h != null ? p.h * 10 : null, { zahl: true, hinweis: 'mm' });
        inhalt.append(el('div', { class: 'abschnitt-t' }, 'Welche Fläche wird belegt?'), reihe(f.flL, f.flB), reihe(f.fl, f.vs),
          el('div', { class: 'abschnitt-t' }, 'Plattengröße'), reihe(f.pl, f.pb, f.dicke));
      } else if (typ === TYP.MATERIAL) {
        f.menge = feld('Wie viel?', p.menge, { zahl: true, hinweis: 'Menge' });
        f.einh = feld('Einheit', p.einh, { hinweis: 'Stk', vorschlaege: Einheit.ALLE });
        f.vs = feld('Reserve / Verschnitt [%]', p.vs, { zahl: true, hinweis: '%' });
        f.pack = feld('Inhalt je Packung', p.pack, { zahl: true, hinweis: 'z. B. 5,2' });
        f.packName = feld('Packung', p.packName, { hinweis: 'Paket', vorschlaege: Einheit.PACKUNGEN });
        inhalt.append(reihe(f.menge, f.einh), f.vs, el('div', { class: 'abschnitt-t' }, 'Packung (optional) – z. B. Paket à 5,2 m²'), reihe(f.pack, f.packName));
      }
      f.holzart = feld(typ === TYP.PLATTE ? 'Plattenmaterial' : typ === TYP.MATERIAL ? 'Produkt / Material' : 'Holzart / Qualität', p.holzart, {
        hinweis: typ === TYP.PLATTE ? 'z. B. OSB/3' : typ === TYP.MATERIAL ? 'z. B. Mineralwolle 035' : 'z. B. KVH NSi C24',
        vorschlaege: bekannteMaterialien.concat(typ === TYP.PLATTE ? [...new Set(PLATTEN.filter(x => x[1]).map(x => x[0]))] : typ === TYP.MATERIAL ? [] : HOLZARTEN)
      });
      inhalt.append(f.holzart);
      f.ergebnis = el('div', { class: 'ergebnis' });
      inhalt.append(f.ergebnis);

      // Weitere Angaben
      const mehr = el('div', { style: mehrOffen ? '' : 'display:none' });
      if (typ === TYP.HOLZ) {
        f.fb = feld('Fertigmaß Breite [cm]', p.fb, { zahl: true, hinweis: 'cm' }); f.fh = feld('Fertigmaß Höhe [cm]', p.fh, { zahl: true, hinweis: 'cm' });
        mehr.append(reihe(f.fb, f.fh));
      }
      f.preis = feld('Preis [€]', p.preis, { zahl: true, hinweis: '€' });
      f.preisEinh = feld('je', p.preisEinh, { hinweis: P.preisEinheit(Object.assign({}, p, { typ, preisEinh: '' })) || 'Einheit', vorschlaege: Einheit.ALLE });
      f.artNr = feld('Artikel-Nr.', p.artNr);
      f.bem = feld('Bemerkung', p.bem, { hinweis: 'z. B. gehobelt, imprägniert' });
      mehr.append(reihe(f.preis, f.preisEinh), f.artNr, f.bem);
      const auf = el('button', { type: 'button', class: 'aufklapp', onclick: () => { mehrOffen = !mehrOffen; mehr.style.display = mehrOffen ? '' : 'none'; auf.textContent = (mehrOffen ? '▾' : '▸') + ' Weitere Angaben (Preis, Bemerkung)'; } },
        (mehrOffen ? '▾' : '▸') + ' Weitere Angaben (Preis, Bemerkung)');
      inhalt.append(auf, mehr);
      inhalt.querySelectorAll('input').forEach(i => i.addEventListener('input', ergebnis));
      ergebnis();
    }

    function zahlFelder() { return Object.entries(felder).filter(([k, f]) => f && f.input && f.input.classList.contains('zahl')).map(([, f]) => f); }

    /** Werte aus den Feldern in eine Position schreiben. */
    function lesen(x) {
      const f = felder;
      x.typ = typ;
      x.bez = text(f.bez);
      if (typ === TYP.TITEL) return x;
      for (const k of ['stk', 'b', 'h', 'l', 'lfm', 'fl', 'flL', 'flB', 'vs', 'fb', 'fh', 'menge', 'pack']) delete x[k];
      delete x.einh; delete x.packName;
      if (typ === TYP.HOLZ) { x.stk = zahl(f.stk); x.l = zahl(f.l); x.b = zahl(f.b); x.h = zahl(f.h); x.fb = zahl(f.fb); x.fh = zahl(f.fh); }
      if (typ === TYP.LFM) { x.lfm = zahl(f.lfm); x.b = zahl(f.b); x.h = zahl(f.h); }
      if (typ === TYP.PLATTE) {
        x.flL = zahl(f.flL); x.flB = zahl(f.flB); x.fl = zahl(f.fl); x.vs = zahl(f.vs);
        const cm = zahl(f.pl), mm = zahl(f.dicke);
        x.l = cm == null ? null : cm / 100; x.b = zahl(f.pb); x.h = mm == null ? null : mm / 10;
      }
      if (typ === TYP.MATERIAL) { x.menge = zahl(f.menge); x.einh = Einheit.norm(text(f.einh)); x.vs = zahl(f.vs); x.pack = zahl(f.pack); x.packName = text(f.packName); }
      x.holzart = text(f.holzart);
      x.preis = zahl(f.preis); x.preisEinh = text(f.preisEinh); x.artNr = text(f.artNr); x.bem = text(f.bem);
      for (const k of Object.keys(x)) if (x[k] == null || x[k] === '') { if (!['bez', 'holzart', 'bem', 'typ'].includes(k)) delete x[k]; }
      return x;
    }

    function ergebnis() {
      const f = felder;
      if (!f.ergebnis) return;
      const t = lesen({});
      let s = '';
      if (typ === TYP.HOLZ || typ === TYP.LFM) s = '= ' + Fmt.fix(P.laufmeter(t), 2) + ' m  ·  ' + Fmt.fix(P.volumen(t), 3) + ' m³';
      else if (typ === TYP.PLATTE) {
        const fl = P.flaeche(t), vs = t.vs || 0, n = P.plattenAnzahl(t);
        s = Fmt.fix(fl, 2) + ' m²' + (vs ? ' + ' + Fmt.num(vs) + ' % = ' + Fmt.fix(fl * (1 + vs / 100), 2) + ' m²' : '');
        if (n != null) s += '\n→ Du brauchst ' + Fmt.num(n) + (n === 1 ? ' Platte' : ' Platten') + ' à ' + Fmt.fix(P.plattenFlaecheEinzeln(t), 3) + ' m²';
        else if (fl > 0) s += '\nPlattengröße eingeben → Anzahl wird berechnet';
        else s += '\nFläche eingeben: Länge × Breite oder m²';
      } else if (typ === TYP.MATERIAL) {
        const b = P.bedarf(t), pk = P.packungen(t), e = Einheit.norm(t.einh);
        if (b == null) s = 'Menge eingeben';
        else {
          s = Fmt.menge(t.menge) + ' ' + e + (t.vs ? ' + ' + Fmt.num(t.vs) + ' % = ' + Fmt.menge(b) + ' ' + e : '');
          if (pk != null) s += '\n→ Du brauchst ' + Fmt.num(pk) + ' ' + P.packName(t) + ' à ' + Fmt.num(t.pack) + ' ' + e;
        }
      }
      const bt = P.betrag(t);
      if (bt != null) s += '\nPreis: ' + Fmt.euro(bt);
      f.ergebnis.textContent = s;
      f.ergebnis.style.display = s ? '' : 'none';
    }

    function artWaehlen() {
      lesen(p);
      menue('Art ändern', [TYP.HOLZ, TYP.LFM, TYP.PLATTE, TYP.MATERIAL].map(t => ({ ico: P.symbol(t), text: P.typName(t), klick: () => { typ = t; p.typ = t; aufbauen(); } })));
    }

    function plattenAuswahl() {
      const eigene = einst().plattenvorlagen || [];
      const items = [{ ico: '✎', text: 'Eigene Platte eintragen', sub: 'Felder frei ausfüllen', klick: () => felder.flL.input.focus() }];
      if (eigene.length) { items.push({ ueber: 'Eigene Platten' }); eigene.forEach(v => items.push(vorlageItem(v, true))); }
      for (const x of PLATTEN) {
        if (!x[1]) items.push({ ueber: x[0] });
        else items.push(vorlageItem({ m: x[0], bez: x[1], l: x[2], b: x[3], d: x[4] }));
      }
      items.push({ ueber: 'Eigene Platten verwalten' });
      items.push({
        ico: '＋', text: 'Aktuelle Eingabe als eigene Platte speichern', klick: () => {
          const t = lesen({});
          if (t.l == null && t.b == null && t.h == null) { toast('Erst Plattengröße eingeben'); return; }
          const l = einst().plattenvorlagen || [];
          l.unshift({ m: t.holzart || 'Eigene Platte', bez: t.bez, l: t.l, b: t.b, d: t.h != null ? t.h * 10 : null });
          einstSetzen('plattenvorlagen', l); toast('Gespeichert – steht jetzt oben in der Auswahl');
        }
      });
      if (eigene.length) items.push({ ico: '🗑', text: 'Eigene Platten löschen', gefahr: true, klick: () => frage('Eigene Platten löschen?', 'Alle ' + eigene.length + ' eigenen Plattenvorlagen löschen?', 'Löschen', () => einstSetzen('plattenvorlagen', [])) });
      menue('Platte auswählen', items);
    }
    function vorlageItem(v, eigen) {
      const fmt = (v.l != null ? Fmt.num(v.l * 100) : '–') + ' × ' + (v.b != null ? Fmt.num(v.b) : '–') + ' cm' + (v.d != null ? '  ·  ' + Fmt.num(v.d) + ' mm' : '');
      return {
        text: (eigen ? '★ ' : '') + v.m, sub: fmt, klick: () => {
          const f = felder;
          f.holzart.input.value = v.m || '';
          f.pl.input.value = v.l != null ? Fmt.num(v.l * 100) : '';
          f.pb.input.value = v.b != null ? Fmt.num(v.b) : '';
          f.dicke.input.value = v.d != null ? Fmt.num(v.d) : '';
          if (!text(f.bez) && v.bez) f.bez.input.value = v.bez;
          ergebnis();
          (text(f.flL) || text(f.fl) ? f.vs : f.flL).input.focus();
        }
      };
    }

    aufbauen();
    const uebernehmen = () => {
      if (typ === TYP.TITEL && !text(felder.bez)) { toast('Bitte eine Überschrift eingeben'); return false; }
      if (!zahlenPruefen(zahlFelder())) return false;
      lesen(p);
      return true;
    };
    const knoepfe = [];
    if (neu && typ !== TYP.TITEL) knoepfe.push({ text: '+ Nächste', links: true, klick: () => { if (!uebernehmen()) return false; setTimeout(() => fertig(p, true)); } });
    knoepfe.push({ text: 'Abbrechen' }, { text: 'Speichern', haupt: true, klick: () => { if (!uebernehmen()) return false; setTimeout(() => fertig(p, false)); } });
    dialog({ titel: typ === TYP.TITEL ? 'Überschrift' : neu ? 'Neu hinzufügen' : 'Ändern', inhalt, knoepfe });
    if (neu && typ === TYP.PLATTE && p.l == null && p.b == null) setTimeout(plattenAuswahl, 80);
    else setTimeout(() => felder.bez.input.focus(), 80);
  }

  // ================================================================== Werkzeug
  function seiteWerkzeug(h) {
    const inhalt = [kopfKarte(h)];
    if (!h.werkzeug.length) inhalt.push(el('div', { class: 'leerhinweis' }, 'Noch kein Werkzeug eingetragen.', el('br'), el('br'),
      '„💡 Vorschlagen“ schlägt passendes Werkzeug zu deinem Material vor.'));
    h.werkzeug.forEach((w, i) => {
      inhalt.push(el('div', { class: 'karte prio-' + (w.prio == null ? 1 : w.prio) + (w.eingepackt ? ' erledigt' : '') },
        el('button', { class: 'check' + (w.eingepackt ? ' an' : ''), 'aria-label': 'Eingepackt', onclick: () => { w.eingepackt = !w.eingepackt; speichern(h); zeichnen(); } }, w.eingepackt ? '✓' : ''),
        el('div', { class: 'mitte', onclick: () => werkzeugDialog(h, i) },
          el('div', { class: 'titel' }, (w.anzahl ? w.anzahl + ' × ' : '') + w.name),
          w.bemerkung ? el('div', { class: 'unter' }, w.bemerkung) : null),
        el('button', { class: 'mehr', 'aria-label': 'Aktionen', onclick: () => werkzeugAktionen(h, i) }, '⋮')));
    });
    const da = h.werkzeug.filter(w => w.eingepackt).length;
    seite({
      titel: '🔧 Werkzeug', zurueck: '/b/' + h.id,
      menuItems: () => [
        { ico: '☐', text: 'Alle Haken entfernen', sub: 'für die nächste Fahrt', klick: () => { h.werkzeug.forEach(w => (w.eingepackt = false)); speichern(h); zeichnen(); } },
        { ico: '🧰', text: 'Grundausstattung hinzufügen', sub: 'Akkuschrauber, Zollstock, Wasserwaage …', klick: () => { grundausstattung(h); } }
      ],
      inhalt,
      status: h.werkzeug.length ? el('span', null, el('b', null, da + ' von ' + h.werkzeug.length), ' eingepackt') : null,
      fuss: [el('button', { class: 'knopf', onclick: () => vorschlagen(h) }, '💡 Vorschlagen'),
        el('button', { class: 'knopf voll', onclick: () => werkzeugDialog(h, -1) }, '＋  Werkzeug')]
    });
  }

  function grundausstattung(h) {
    const vorh = new Set(h.werkzeug.map(w => Werkzeug.schluessel(w.name)));
    let n = 0;
    for (const g of window.M.GRUNDAUSSTATTUNG) if (!vorh.has(Werkzeug.schluessel(g))) { h.werkzeug.push({ name: g, bemerkung: '', eingepackt: false, prio: PRIO.GELB }); n++; }
    speichern(h); zeichnen(); toast(n + ' Teile hinzugefügt');
  }

  function prioWahl(name, wert, namen) {
    const box = el('div', { class: 'radios' });
    for (const p of [PRIO.ROT, PRIO.GELB, PRIO.GRUEN]) {
      box.append(el('label', null, el('input', { type: 'radio', name, value: p, checked: wert === p }), el('span', null, Werkzeug.prioSymbol(p) + ' ' + namen(p))));
    }
    box.wert = () => { const c = box.querySelector('input:checked'); return c ? +c.value : PRIO.GELB; };
    return box;
  }

  /** Werkzeug eingeben. Neu: nach „Hinzufügen“ öffnet sich sofort das nächste (beenden mit „Abbrechen“). */
  function werkzeugDialog(h, idx) {
    const w = idx < 0 ? { name: '', bemerkung: '', eingepackt: false, prio: PRIO.GELB } : Object.assign({}, h.werkzeug[idx]);
    const fName = feld('Werkzeug / Gerät', w.name, { vorschlaege: Werkzeug.alleNamen(), hinweis: 'z. B. Kettensäge' });
    const fAnz = feld('Anzahl (leer = 1)', w.anzahl, { zahl: true });
    const fBem = feld('Bemerkung', w.bemerkung, { hinweis: 'z. B. Akku laden, von Kollege holen' });
    const prio = prioWahl('wprio', w.prio == null ? PRIO.GELB : w.prio, Werkzeug.prioName);
    dialog({
      titel: idx < 0 ? '🔧 Werkzeug hinzufügen' : '🔧 Werkzeug ändern',
      inhalt: [fName, fAnz, fBem, el('div', { class: 'feld' }, el('label', null, 'Wie wichtig?'), prio)],
      knoepfe: [{ text: 'Abbrechen' }, {
        text: idx < 0 ? 'Hinzufügen' : 'Übernehmen', haupt: true, klick: () => {
          w.name = text(fName);
          if (!w.name) return;
          const a = Fmt.parse(fAnz.input.value); if (a != null) w.anzahl = Math.round(a); else delete w.anzahl;
          w.bemerkung = text(fBem); w.prio = prio.wert();
          if (idx < 0) h.werkzeug.push(w); else h.werkzeug[idx] = w;
          speichern(h); zeichnen();
          if (idx < 0) { toast('✓ ' + w.name + ' hinzugefügt – nächstes Werkzeug'); setTimeout(() => werkzeugDialog(h, -1)); }
        }
      }]
    });
    setTimeout(() => fName.input.focus(), 80);
  }

  function werkzeugAktionen(h, i) {
    const w = h.werkzeug[i];
    menue(w.name, [
      { ico: '✎', text: 'Ändern', klick: () => werkzeugDialog(h, i) },
      ...[PRIO.ROT, PRIO.GELB, PRIO.GRUEN].map(p => ({ ico: Werkzeug.prioSymbol(p), text: Werkzeug.prioName(p), klick: () => { w.prio = p; speichern(h); zeichnen(); } })),
      { ico: '🗑', text: 'Löschen', gefahr: true, klick: () => { h.werkzeug.splice(i, 1); speichern(h); zeichnen(); } }
    ]);
  }

  function vorschlagen(h) {
    const v = Werkzeug.vorschlagen(h);
    if (!v.length) {
      dialog({ titel: '💡 Vorschläge', inhalt: el('p', null, 'Keine neuen Vorschläge. Trag zuerst Material, Aufgaben oder eine Notiz ein – daraus schlägt die App passendes Werkzeug vor.'), knoepfe: [{ text: 'OK' }] });
      return;
    }
    const box = el('div');
    for (const x of v) {
      const cb = el('input', { type: 'checkbox', checked: true, onchange: () => (x.gewaehlt = cb.checked) });
      box.append(el('label', { class: 'vorschlag' }, cb, el('div', null, Werkzeug.prioSymbol(x.prio) + ' ' + x.name, el('small', null, x.grund))));
    }
    dialog({
      titel: '💡 ' + v.length + ' Vorschläge', inhalt: box, knoepfe: [{ text: 'Abbrechen' }, {
        text: 'Übernehmen', haupt: true, klick: () => {
          const neu = v.filter(x => x.gewaehlt);
          neu.forEach(x => h.werkzeug.push({ name: x.name, bemerkung: x.grund, eingepackt: false, prio: x.prio }));
          speichern(h); zeichnen(); toast(neu.length + ' Werkzeuge übernommen');
        }
      }]
    });
  }

  // ================================================================== Aufgaben
  let heuteModus = {};
  function seiteAufgaben(h) {
    const heute = !!heuteModus[h.id];
    const anzHeute = h.aufgaben.filter(a => a.heute).length, heuteDa = h.aufgaben.filter(a => a.heute && a.erledigt).length;
    const da = h.aufgaben.filter(a => a.erledigt).length;
    const inhalt = [kopfKarte(h), el('div', { class: 'umschalter' },
      el('button', { class: heute ? 'an' : null, onclick: () => { heuteModus[h.id] = true; zeichnen(); } }, '☀️ Heute', el('small', null, anzHeute ? heuteDa + '/' + anzHeute + ' erledigt' : 'nichts ausgewählt')),
      el('button', { class: heute ? null : 'an', onclick: () => { heuteModus[h.id] = false; zeichnen(); } }, '📋 Alle Aufgaben', el('small', null, da + '/' + h.aufgaben.length + ' erledigt')))];
    const sichtbar = h.aufgaben.map((a, i) => [a, i]).filter(([a]) => !heute || a.heute);
    if (!sichtbar.length) inhalt.push(el('div', { class: 'leerhinweis' }, heute ? 'Für heute ist nichts ausgewählt. Tippe bei einer Aufgabe auf ⋮ → „Heute erledigen“.' : 'Noch keine Aufgaben.', el('br'), el('br'), heute ? '' : 'Unten auf „＋ Aufgabe“ tippen.'));
    let abschn = null;
    for (const [a, i] of sichtbar) {
      const ab = (a.abschnitt || '').trim();
      if (ab !== abschn) {
        abschn = ab;
        const gruppe = h.aufgaben.filter(x => (x.abschnitt || '').trim() === ab && (!heute || x.heute));
        if (ab || sichtbar.some(([x]) => (x.abschnitt || '').trim())) inhalt.push(el('div', { class: 'abschnitt' }, el('span', null, (ab || 'Ohne Abschnitt') + '  (' + gruppe.filter(x => x.erledigt).length + '/' + gruppe.length + ')')));
      }
      inhalt.push(el('div', { class: 'karte prio-' + (a.prio == null ? 1 : a.prio) + (a.erledigt ? ' erledigt' : '') },
        el('button', { class: 'check' + (a.erledigt ? ' an' : ''), 'aria-label': 'Erledigt', onclick: () => { a.erledigt = !a.erledigt; speichern(h); zeichnen(); } }, a.erledigt ? '✓' : ''),
        el('div', { class: 'mitte', onclick: () => aufgabeDialog(h, i, -1) },
          el('div', { class: 'titel' }, (a.heute && !heute ? '☀️ ' : '') + a.text),
          a.info ? el('div', { class: 'unter' }, a.info) : null),
        el('button', { class: 'mehr', 'aria-label': 'Aktionen', onclick: () => aufgabeAktionen(h, i) }, '⋮')));
    }
    seite({
      titel: '✅ Aufgaben', zurueck: '/b/' + h.id,
      menuItems: () => [
        { ico: '☀️', text: 'Neuer Tag', sub: 'Erledigtes aus „Heute“ wegräumen', klick: () => { h.aufgaben.forEach(a => { if (a.erledigt) a.heute = false; }); speichern(h); zeichnen(); } },
        { ico: '🧹', text: 'Erledigte Aufgaben löschen', gefahr: true, klick: () => frage('Erledigte löschen?', da + ' erledigte Aufgaben löschen?', 'Löschen', () => { h.aufgaben = h.aufgaben.filter(a => !a.erledigt); speichern(h); zeichnen(); }) }
      ],
      inhalt,
      status: h.aufgaben.length ? el('span', null, el('b', null, da + ' von ' + h.aufgaben.length), ' erledigt') : null,
      fuss: [el('button', { class: 'knopf voll', onclick: () => aufgabeDialog(h, -1, -1) }, '＋  Aufgabe')]
    });
  }

  let letzteAufgabe = null;
  /** Aufgabe eingeben. Neu: nach „Hinzufügen“ öffnet sich sofort die nächste (beenden mit „Abbrechen“). */
  function aufgabeDialog(h, idx, einfuegenBei) {
    let a;
    if (idx >= 0) a = Object.assign({}, h.aufgaben[idx]);
    else {
      a = Aufgabe.neu();
      const vor = einfuegenBei < 0 ? h.aufgaben.length - 1 : einfuegenBei - 1;
      if (vor >= 0 && vor < h.aufgaben.length) a.abschnitt = h.aufgaben[vor].abschnitt;
      a.heute = !!heuteModus[h.id];
      if (letzteAufgabe) { a.abschnitt = letzteAufgabe.abschnitt; a.prio = letzteAufgabe.prio; a.heute = letzteAufgabe.heute; letzteAufgabe = null; }
    }
    const fText = feld('Was ist zu tun?', a.text);
    const fAb = feld('Abschnitt (z. B. Zimmererarbeiten)', a.abschnitt, { vorschlaege: [...new Set(h.aufgaben.map(x => x.abschnitt).filter(Boolean))] });
    const fInfo = feld('Info (z. B. Pos. 2.5, Menge, wer)', a.info);
    const prio = prioWahl('aprio', a.prio == null ? PRIO.GELB : a.prio, Aufgabe.prioName);
    const heute = el('input', { type: 'checkbox', checked: a.heute });
    dialog({
      titel: idx >= 0 ? '✅ Aufgabe ändern' : '✅ Neue Aufgabe',
      inhalt: [fText, fAb, fInfo, el('div', { class: 'feld' }, el('label', null, 'Wie dringend?'), prio), el('label', { class: 'haken' }, heute, '☀️ Heute erledigen')],
      knoepfe: [{ text: 'Abbrechen' }, {
        text: idx >= 0 ? 'Übernehmen' : 'Hinzufügen', haupt: true, klick: () => {
          a.text = text(fText);
          if (!a.text) return;
          a.abschnitt = text(fAb); a.info = text(fInfo); a.prio = prio.wert(); a.heute = heute.checked;
          let neuBei = -1;
          if (idx >= 0) h.aufgaben[idx] = a;
          else if (einfuegenBei < 0 || einfuegenBei > h.aufgaben.length) h.aufgaben.push(a);
          else { h.aufgaben.splice(einfuegenBei, 0, a); neuBei = einfuegenBei + 1; }
          speichern(h); zeichnen();
          if (idx < 0) { toast('✓ Aufgabe hinzugefügt – nächste Aufgabe'); letzteAufgabe = a; setTimeout(() => aufgabeDialog(h, -1, neuBei)); }
        }
      }]
    });
    setTimeout(() => fText.input.focus(), 80);
  }

  function aufgabeAktionen(h, i) {
    const a = h.aufgaben[i];
    menue(a.text, [
      { ico: '✎', text: 'Ändern', klick: () => aufgabeDialog(h, i, -1) },
      { ico: '☀️', text: a.heute ? 'Nicht mehr für heute' : 'Heute erledigen', klick: () => { a.heute = !a.heute; speichern(h); zeichnen(); } },
      ...[PRIO.ROT, PRIO.GELB, PRIO.GRUEN].map(p => ({ ico: Werkzeug.prioSymbol(p), text: Aufgabe.prioName(p), klick: () => { a.prio = p; speichern(h); zeichnen(); } })),
      { ico: '＋', text: 'Neue Aufgabe hier darunter', klick: () => aufgabeDialog(h, -1, i + 1) },
      { ico: '🗑', text: 'Löschen', gefahr: true, klick: () => { h.aufgaben.splice(i, 1); speichern(h); zeichnen(); } }
    ]);
  }

  // ================================================================== Start
  laden();
  zeichnen();
  if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {});
  window.MaterialApp = { listen: () => listen, laden, zeichnen };
})();
