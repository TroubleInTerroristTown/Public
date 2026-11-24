package de.zimmerei.holzliste;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/**
 * „Aus Arbeitsanweisung (PDF)“: PDF wählen → Text lesen → Struktur + Materialvorschläge anzeigen →
 * gewählte Zeilen in die Liste übernehmen. Läuft komplett ohne Internet.
 */
public final class AwImport {

    private AwImport() {}

    public static final int REQ_PDF = 78;
    private static int einfuegenBei = -1;

    public interface Fertig { void geaendert(); }

    public static void starten(Activity act, int index) {
        einfuegenBei = index;
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("application/pdf");
        try {
            act.startActivityForResult(i, REQ_PDF);
        } catch (ActivityNotFoundException e) {
            Toast.makeText(act, "Kein Datei-Dialog verfügbar", Toast.LENGTH_LONG).show();
        }
    }

    /** Aus Activity.onActivityResult aufrufen. @return true wenn behandelt */
    public static boolean onActivityResult(Activity act, int req, int res, Intent data, Holzliste liste, Fertig fertig) {
        if (req != REQ_PDF) return false;
        if (res != Activity.RESULT_OK || data == null || data.getData() == null) return true;
        Uri uri = data.getData();
        String name = KatalogAuswahl.dateiname(act, uri);

        LinearLayout l = new LinearLayout(act);
        int p = Ui.dp(act, 24);
        l.setPadding(p, p, p, p);
        l.addView(new ProgressBar(act));
        TextView t = Ui.text(act, "  Arbeitsanweisung wird gelesen …", 15, Ui.TEXT, false);
        t.setGravity(Gravity.CENTER_VERTICAL);
        l.addView(t, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT));
        AlertDialog warte = new AlertDialog.Builder(act).setView(l).setCancelable(false).create();
        warte.show();

        Handler ui = new Handler(Looper.getMainLooper());
        new Thread(() -> {
            Arbeitsanweisung.Ergebnis erg = null;
            String fehler = null;
            try {
                String text = PdfText.lesen(act, uri);
                if (text.replaceAll("\\s", "").length() < 20) {
                    fehler = "In der PDF steht kein lesbarer Text – vermutlich ist sie eingescannt (nur ein Bild).\n\n"
                            + "Tipp: Die Arbeitsanweisung direkt aus dem Programm als PDF speichern oder drucken, nicht scannen.";
                } else {
                    erg = Arbeitsanweisung.auswerten(text, Katalog.alle(act), name);
                }
            } catch (Throwable ex) { // auch OutOfMemoryError: die App soll nie abstürzen
                fehler = "Die PDF konnte nicht gelesen werden: " + (ex.getMessage() == null ? ex.toString() : ex.getMessage());
            }
            Arbeitsanweisung.Ergebnis e = erg;
            String f = fehler;
            ui.post(() -> {
                warte.dismiss();
                if (act.isFinishing()) return;
                if (f != null) {
                    new AlertDialog.Builder(act).setTitle("Arbeitsanweisung").setMessage(f).setPositiveButton("OK", null).show();
                } else {
                    vorschau(act, e, liste, fertig);
                }
            });
        }).start();
        return true;
    }

    /** Vorschau mit Häkchen: Überschriften, Material, Kopfdaten, Arbeitsschritte. */
    static void vorschau(Activity act, Arbeitsanweisung.Ergebnis erg, Holzliste liste, Fertig fertig) {
        ScrollView sv = new ScrollView(act);
        LinearLayout box = new LinearLayout(act);
        box.setOrientation(LinearLayout.VERTICAL);
        int pad = Ui.dp(act, 18);
        box.setPadding(pad, Ui.dp(act, 6), pad, Ui.dp(act, 6));
        sv.addView(box);

        StringBuilder info = new StringBuilder();
        if (erg.anzahlVorschlaege() == 0) {
            info.append("Es wurde kein Material erkannt. Du kannst trotzdem die Überschriften übernehmen und das Material selbst eintragen.");
        } else {
            info.append(erg.anzahlVorschlaege()).append(erg.anzahlVorschlaege() == 1 ? " Vorschlag" : " Vorschläge")
                    .append(" gefunden. Bitte prüfen – Mengen sind nur übernommen, wenn sie in der Arbeitsanweisung stehen.");
        }
        if (erg.uebersprungen > 0)
            info.append("\n").append(erg.uebersprungen).append(" Positionen ohne Material (Stunden, Pauschalen, Anfahrt …) wurden weggelassen.");
        if (!erg.inventarGenutzt)
            info.append("\n\nTipp: Lade deine Inventarliste (Menü ⋮ → Artikellisten), dann sucht die App passende Artikel dazu.");
        TextView ti = Ui.text(act, info.toString(), 14, Ui.GRAU, false);
        ti.setPadding(0, 0, 0, Ui.dp(act, 8));
        box.addView(ti);

        // Kopfdaten nur anbieten, wenn in der Liste noch leer
        CheckBox kopf = null;
        StringBuilder kt = new StringBuilder();
        if (leer(liste.projekt) && !erg.projekt.isEmpty()) kt.append("Projekt: ").append(erg.projekt);
        if (leer(liste.kunde) && !erg.kunde.isEmpty()) kt.append(kt.length() > 0 ? "\n" : "").append("Kunde: ").append(erg.kunde);
        if (leer(liste.bauteil) && !erg.bauteil.isEmpty()) kt.append(kt.length() > 0 ? "\n" : "").append("Bauteil: ").append(erg.bauteil);
        if (kt.length() > 0) {
            kopf = checkbox(act, "Kopfdaten übernehmen", kt.toString(), true, false);
            box.addView(kopf);
        }

        List<CheckBox> abschnittBoxen = new ArrayList<>();
        List<List<CheckBox>> vorschlagBoxen = new ArrayList<>();
        for (Arbeitsanweisung.Abschnitt a : erg.abschnitte) {
            CheckBox ca = checkbox(act, "▸ " + a.titel, a.vorschlaege.isEmpty() ? "nur Überschrift" : null, true, true);
            box.addView(ca);
            abschnittBoxen.add(ca);
            List<CheckBox> vs = new ArrayList<>();
            for (Arbeitsanweisung.Vorschlag v : a.vorschlaege) {
                String sym = Kategorien.symbol(v.kategorie);
                StringBuilder sub = new StringBuilder(v.mengeText());
                if (v.artikel != null) sub.append("\nArtikel: ").append(v.artikel.a.text)
                        .append(v.artikel.a.nr.isEmpty() ? "" : " (" + v.artikel.a.nr + ")");
                else if (erg.inventarGenutzt) sub.append("\nkein passender Artikel im Inventar");
                CheckBox cv = checkbox(act, sym + "  " + v.name, sub.toString(), true, false);
                ((LinearLayout.LayoutParams) cv.getLayoutParams()).leftMargin = Ui.dp(act, 22);
                box.addView(cv);
                vs.add(cv);
            }
            vorschlagBoxen.add(vs);
            ca.setOnCheckedChangeListener((b, an) -> { for (CheckBox c : vs) c.setChecked(an); });
        }

        CheckBox schritte = null;
        if (!erg.arbeitsschritte.isEmpty()) {
            StringBuilder s = new StringBuilder();
            for (int i = 0; i < erg.arbeitsschritte.size() && i < 4; i++) s.append(i > 0 ? "\n" : "").append("• ").append(erg.arbeitsschritte.get(i));
            if (erg.arbeitsschritte.size() > 4) s.append("\n… und ").append(erg.arbeitsschritte.size() - 4).append(" weitere");
            schritte = checkbox(act, "Arbeitsschritte in die Notiz (" + erg.arbeitsschritte.size() + ")", s.toString(), true, false);
            box.addView(schritte);
        }

        // Werkzeug passend zu allen Vorschlägen und Arbeitsschritten
        Holzliste probe = new Holzliste();
        probe.positionen.addAll(Arbeitsanweisung.positionen(erg));
        probe.werkzeug.addAll(liste.werkzeug);
        probe.positionen.addAll(liste.positionen);
        List<Werkzeug.Vorschlag> wz = Werkzeug.vorschlagen(probe, erg.arbeitsschritte);
        CheckBox werkzeug = null;
        if (!wz.isEmpty()) {
            StringBuilder s = new StringBuilder();
            for (int i = 0; i < wz.size() && i < 5; i++) s.append(i > 0 ? ", " : "").append(wz.get(i).name);
            if (wz.size() > 5) s.append(" … und ").append(wz.size() - 5).append(" weitere");
            werkzeug = checkbox(act, "🔧 Werkzeug-Liste vorschlagen (" + wz.size() + ")", s.toString(), true, false);
            box.addView(werkzeug);
        }

        CheckBox kopfF = kopf, schritteF = schritte, werkzeugF = werkzeug;
        new AlertDialog.Builder(act).setTitle("📄 Aus der Arbeitsanweisung")
                .setView(sv)
                .setPositiveButton("Übernehmen", (d, w) -> {
                    for (int i = 0; i < erg.abschnitte.size(); i++) {
                        Arbeitsanweisung.Abschnitt a = erg.abschnitte.get(i);
                        boolean irgendwas = abschnittBoxen.get(i).isChecked();
                        List<CheckBox> vs = vorschlagBoxen.get(i);
                        for (int j = 0; j < a.vorschlaege.size(); j++) {
                            a.vorschlaege.get(j).gewaehlt = vs.get(j).isChecked();
                            irgendwas |= vs.get(j).isChecked();
                        }
                        a.gewaehlt = irgendwas;
                    }
                    List<Position> neu = Arbeitsanweisung.positionen(erg);
                    int at = einfuegenBei < 0 || einfuegenBei > liste.positionen.size() ? liste.positionen.size() : einfuegenBei;
                    liste.positionen.addAll(at, neu);
                    if (kopfF != null && kopfF.isChecked()) {
                        if (leer(liste.projekt)) liste.projekt = erg.projekt;
                        if (leer(liste.kunde)) liste.kunde = erg.kunde;
                        if (leer(liste.bauteil)) liste.bauteil = erg.bauteil;
                    }
                    if (schritteF != null && schritteF.isChecked()) {
                        StringBuilder n = new StringBuilder(leer(liste.notiz) ? "" : liste.notiz.trim() + "\n");
                        n.append("Arbeitsschritte:");
                        for (String s : erg.arbeitsschritte) n.append("\n• ").append(s);
                        liste.notiz = n.toString();
                    }
                    int wzAnz = 0;
                    if (werkzeugF != null && werkzeugF.isChecked()) {
                        for (Werkzeug.Vorschlag v : Werkzeug.vorschlagen(liste, erg.arbeitsschritte)) {
                            liste.werkzeug.add(new Werkzeug(v.name, ""));
                            wzAnz++;
                        }
                    }
                    fertig.geaendert();
                    int anz = 0;
                    for (Position x : neu) if (!x.isTitel()) anz++;
                    Toast.makeText(act, anz + " Positionen" + (wzAnz > 0 ? " und " + wzAnz + " Werkzeuge" : "")
                            + " übernommen – bitte Mengen prüfen", Toast.LENGTH_LONG).show();
                })
                .setNegativeButton("Abbrechen", null).show();
    }

    static CheckBox checkbox(Activity act, String titel, String unter, boolean an, boolean fett) {
        CheckBox c = new CheckBox(act);
        CharSequence text = titel;
        if (unter != null && !unter.isEmpty()) {
            android.text.SpannableStringBuilder sb = new android.text.SpannableStringBuilder(titel + "\n" + unter);
            int s = titel.length() + 1;
            sb.setSpan(new android.text.style.ForegroundColorSpan(Ui.GRAU), s, sb.length(), 0);
            sb.setSpan(new android.text.style.RelativeSizeSpan(0.85f), s, sb.length(), 0);
            text = sb;
        }
        c.setText(text);
        c.setTextSize(fett ? 17 : 15);
        c.setTextColor(Ui.TEXT);
        if (fett) c.setTypeface(Typeface.DEFAULT_BOLD);
        c.setChecked(an);
        c.setPadding(Ui.dp(act, 4), Ui.dp(act, 6), 0, Ui.dp(act, 6));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = Ui.dp(act, fett ? 8 : 0);
        c.setLayoutParams(lp);
        return c;
    }

    private static boolean leer(String s) { return s == null || s.trim().isEmpty(); }
}
