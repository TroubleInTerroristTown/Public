package de.zimmerei.holzliste;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.graphics.drawable.Drawable;
import android.text.InputType;
import android.text.TextUtils;
import android.text.method.DigitsKeyListener;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Kleine Helfer für den programmatischen Aufbau der Oberfläche. */
public final class Ui {

    private Ui() {}

    public static final int BRAUN = Color.parseColor("#5D4037");
    public static final int BRAUN_DUNKEL = Color.parseColor("#3E2723");
    public static final int BRAUN_HELL = Color.parseColor("#D7CCC8");
    public static final int BEIGE = Color.parseColor("#EFEBE9");
    public static final int HINTERGRUND = Color.parseColor("#F5F1EE");
    public static final int ZEBRA = Color.parseColor("#FAF7F5");
    public static final int WEISS = Color.WHITE;
    public static final int TEXT = Color.parseColor("#212121");
    public static final int GRAU = Color.parseColor("#757575");
    public static final int LINIE = Color.parseColor("#E0D7D3");
    public static final int AKZENT = Color.parseColor("#EF8F00");
    public static final int BLAU = Color.parseColor("#1565C0");
    public static final int SUMME = Color.parseColor("#FFF3E0");

    public static int dp(Context c, float dp) {
        return Math.round(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, c.getResources().getDisplayMetrics()));
    }

    public static TextView text(Context c, String s, float sp, int color, boolean bold) {
        TextView t = new TextView(c);
        t.setText(s);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        t.setTextColor(color);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

    public static TextView cell(Context c, String s, int widthDp, int gravity, boolean bold, int color) {
        TextView t = text(c, s, 14, color, bold);
        t.setGravity(gravity | Gravity.CENTER_VERTICAL);
        t.setSingleLine(true);
        t.setEllipsize(TextUtils.TruncateAt.END);
        int p = dp(c, 6);
        t.setPadding(p, 0, p, 0);
        t.setLayoutParams(new LinearLayout.LayoutParams(dp(c, widthDp), LinearLayout.LayoutParams.MATCH_PARENT));
        return t;
    }

    /** Hintergrund mit Berührungs-Effekt. */
    public static Drawable touchBg(int color) {
        return new RippleDrawable(ColorStateList.valueOf(Color.parseColor("#33795548")),
                new ColorDrawable(color), new ColorDrawable(Color.WHITE));
    }

    public static GradientDrawable rounded(int fill, int stroke, float radiusPx, int strokePx) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(radiusPx);
        if (stroke != 0) g.setStroke(strokePx, stroke);
        return g;
    }

    public static View divider(Context c, boolean vertical) {
        View v = new View(c);
        v.setBackgroundColor(LINIE);
        v.setLayoutParams(vertical
                ? new LinearLayout.LayoutParams(1, LinearLayout.LayoutParams.MATCH_PARENT)
                : new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1));
        return v;
    }

    /** Zahlenfeld, das Komma UND Punkt akzeptiert und die Ziffern-Tastatur zeigt. */
    public static void decimalInput(EditText e) {
        e.setKeyListener(DigitsKeyListener.getInstance("0123456789.,"));
        e.setRawInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL);
        e.setSelectAllOnFocus(true);
    }
}
