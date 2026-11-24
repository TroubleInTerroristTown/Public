package de.zimmerei.holzliste;

import java.util.Locale;

/** Mengeneinheiten für Material und Preise (Schreibweise vereinheitlichen). */
public final class Einheit {

    private Einheit() {}

    /** Vorschläge im Eingabedialog. */
    static final String[] ALLE = {"Stk", "m", "m²", "m³", "kg", "t", "l", "Sack", "Paket", "Rolle", "Eimer",
            "Karton", "Kartusche", "Palette", "Bund", "Satz", "Dose"};

    /** Vorschläge für die Verpackung (Gebinde). */
    static final String[] PACKUNGEN = {"Paket", "Sack", "Rolle", "Karton", "Eimer", "Palette", "Bund", "Dose", "Kartusche"};

    /** Vereinheitlicht Schreibweisen wie "QM", "M2", "ST", "Stck" → "m²", "Stk" … */
    public static String norm(String s) {
        if (s == null) return "";
        String t = s.trim();
        String u = t.toUpperCase(Locale.ROOT).replace(".", "");
        switch (u) {
            case "": return "";
            case "M2": case "QM": case "M²": case "QUADRATMETER": return "m²";
            case "M3": case "CBM": case "M³": case "KUBIKMETER": return "m³";
            case "M": case "LFM": case "LM": case "MTR": case "METER": return "m";
            case "STK": case "ST": case "STCK": case "STÜCK": case "STUECK": case "PCE": case "PCS": case "PLATTE": case "PLATTEN": return "Stk";
            case "KG": case "KILO": return "kg";
            case "T": case "TO": case "TONNE": return "t";
            case "L": case "LTR": case "LITER": return "l";
            case "SA": case "SCK": case "SACK": return "Sack";
            case "PAK": case "PAKET":  case "PA": case "PCK": case "PACK": return "Paket";
            case "RO": case "ROL": case "ROLLE": case "RLL": return "Rolle";
            case "EI": case "EIM": case "EIMER": return "Eimer";
            case "KAR": case "KRT": case "KTN": case "KARTON": return "Karton";
            case "PAL": case "PALETTE": return "Palette";
            case "BD": case "BUND": return "Bund";
            case "SAT": case "SATZ": case "SET": return "Satz";
            case "DS": case "DOSE": return "Dose";
            case "KARTUSCHE": case "KTS": return "Kartusche";
            default: return t;
        }
    }

    /** Einheiten, die nur ganzzahlig bestellt werden (aufrunden). */
    public static boolean ganzzahlig(String einheit) {
        String e = norm(einheit);
        return !(e.equals("m") || e.equals("m²") || e.equals("m³") || e.equals("kg") || e.equals("t") || e.equals("l") || e.isEmpty());
    }

    public static boolean gleich(String a, String b) {
        return norm(a).equalsIgnoreCase(norm(b));
    }
}
