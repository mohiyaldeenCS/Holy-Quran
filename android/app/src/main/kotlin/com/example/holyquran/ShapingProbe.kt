package com.example.holyquran

import android.content.Context
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import kotlin.math.roundToInt

// Spike S4 (D-068, D-094): approach B, measured only. A TextView lays out the
// synthetic text Dart sends with the app's Quran font file, and the layout
// goes back in logical pixels. Names mirror spike/s4/native_shaping_probe.dart.
class ShapingProbe(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private var font: Pair<Typeface, String>? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != MEASURE) {
            result.notImplemented()
            return
        }
        val text = call.argument<String>(TEXT)
        val fontSize = call.argument<Double>(FONT_SIZE)
        val maxWidth = call.argument<Double>(MAX_WIDTH)
        if (text == null || fontSize == null || maxWidth == null) {
            result.error("arguments", "measure needs text, fontSize and maxWidth", null)
            return
        }
        try {
            result.success(measure(text, fontSize, maxWidth))
        } catch (failure: Exception) {
            result.error("measure", failure.toString(), null)
        }
    }

    private fun measure(text: String, fontSize: Double, maxWidth: Double): Map<String, Any> {
        val (typeface, sha256) = loadFont()
        val density = context.resources.displayMetrics.density
        val view = TextView(context).apply {
            setTypeface(typeface)
            // Logical pixels times density, as Flutter sizes text: not sp, so
            // the system font scale does not apply.
            setTextSize(TypedValue.COMPLEX_UNIT_PX, (fontSize * density).toFloat())
            includeFontPadding = false
            // Fallback line spacing grows a line to a fallback font's extent;
            // off, a height delta reflects shaping, not fallback line spacing.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) setFallbackLineSpacing(false)
            breakStrategy = Layout.BREAK_STRATEGY_SIMPLE
            hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NONE
            textLocale = Locale("ar")
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            textDirection = View.TEXT_DIRECTION_RTL
            setText(text)
        }
        view.measure(
            View.MeasureSpec.makeMeasureSpec((maxWidth * density).roundToInt(), View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val layout = view.layout
        val lineWidths = List(layout.lineCount) { layout.getLineWidth(it).toDouble() / density }
        return mapOf(
            WIDTH to (lineWidths.maxOrNull() ?: 0.0),
            HEIGHT to layout.height.toDouble() / density,
            LINE_COUNT to layout.lineCount,
            LINE_STARTS to List(layout.lineCount) { layout.getLineStart(it) },
            LINE_WIDTHS to lineWidths,
            FONT_SHA256 to sha256,
        )
    }

    // The bundled asset, copied out once so that Typeface reads the very bytes
    // that were hashed.
    private fun loadFont(): Pair<Typeface, String> {
        font?.let { return it }
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(FONT_ASSET)
        val bytes = context.assets.open(key).use { it.readBytes() }
        val copy = File(context.cacheDir, "shaping_probe_font.ttf")
        copy.writeBytes(bytes)
        val sha256 = MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }
        return Pair(Typeface.createFromFile(copy), sha256).also { font = it }
    }

    private companion object {
        const val CHANNEL = "holyquran.spike/shaping_probe"
        const val MEASURE = "measure"
        const val TEXT = "text"
        const val FONT_SIZE = "fontSize"
        const val MAX_WIDTH = "maxWidth"
        const val WIDTH = "width"
        const val HEIGHT = "height"
        const val LINE_COUNT = "lineCount"
        const val LINE_STARTS = "lineStarts"
        const val LINE_WIDTHS = "lineWidths"
        const val FONT_SHA256 = "fontSha256"
        const val FONT_ASSET = "assets/fonts/AmiriQuran-Regular.ttf"
    }
}
