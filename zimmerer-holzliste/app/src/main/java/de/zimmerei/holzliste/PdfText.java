package de.zimmerei.holzliste;

import android.content.Context;
import android.net.Uri;

import com.tom_roush.pdfbox.android.PDFBoxResourceLoader;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException;
import com.tom_roush.pdfbox.text.PDFTextStripper;

import java.io.IOException;
import java.io.InputStream;

/** Liest den Text einer PDF-Datei (ohne Internet, mit PdfBox). */
public final class PdfText {

    private PdfText() {}

    /** Höchstens so viele Seiten lesen (Arbeitsanweisungen sind kurz, schützt vor riesigen Plänen). */
    private static final int MAX_SEITEN = 40;

    public static String lesen(Context c, Uri uri) throws IOException {
        PDFBoxResourceLoader.init(c.getApplicationContext());
        try (InputStream in = c.getContentResolver().openInputStream(uri)) {
            if (in == null) throw new IOException("Datei kann nicht geöffnet werden");
            try (PDDocument doc = PDDocument.load(in)) {
                doc.setAllSecurityToBeRemoved(true);
                PDFTextStripper s = new PDFTextStripper();
                s.setSortByPosition(true); // Spalten „Pos. Menge Einh. Beschreibung“ bleiben in einer Zeile
                s.setStartPage(1);
                s.setEndPage(Math.min(doc.getNumberOfPages(), MAX_SEITEN));
                return s.getText(doc);
            }
        } catch (InvalidPasswordException e) {
            throw new IOException("Die PDF ist mit einem Passwort geschützt.");
        }
    }
}
