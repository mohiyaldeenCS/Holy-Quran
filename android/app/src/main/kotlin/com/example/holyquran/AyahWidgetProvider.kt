package com.example.holyquran

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

// Spike S4 (D-068, D-094): the ayah widget shows an image Flutter rendered;
// it draws no text of its own and holds no Quran text. Every key, field and
// link part mirrors spike/s4/widget_slots.dart.
class AyahWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) draw(context, appWidgetManager, id, widgetData)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        draw(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private class Slot(
        val address: String,
        val slotStartMs: Long,
        val lightPath: String,
        val darkPath: String,
        val lightBytes: Long,
        val darkBytes: Long,
    )

    private fun draw(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.ayah_widget)
        val slot = slotAt(readSlots(data.getString(SLOTS_PREFIX + faceSize(manager, id), null)))
        val light = slot?.let { image(it.lightPath, it.lightBytes) }
        val dark = slot?.let { image(it.darkPath, it.darkBytes) }
        if (slot == null || light == null || dark == null) {
            views.setViewVisibility(R.id.ayah_widget_image, View.GONE)
            views.setContentDescription(R.id.ayah_widget_image, null)
            views.setOnClickPendingIntent(
                android.R.id.background,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
        } else {
            showImages(context, views, light, dark)
            views.setViewVisibility(R.id.ayah_widget_image, View.VISIBLE)
            views.setContentDescription(
                R.id.ayah_widget_image,
                label(data.getString(LABELS_KEY, null), slot.address),
            )
            views.setOnClickPendingIntent(
                android.R.id.background,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, link(slot.address)),
            )
        }
        manager.updateAppWidget(id, views)
    }

    // From API 31 the host picks the image by the system's night mode, so a
    // dark switch needs no update; before it, the mode at the update decides.
    private fun showImages(context: Context, views: RemoteViews, light: Bitmap, dark: Bitmap) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setIcon(
                R.id.ayah_widget_image,
                "setImageIcon",
                Icon.createWithBitmap(light),
                Icon.createWithBitmap(dark),
            )
        } else {
            val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            views.setImageViewBitmap(R.id.ayah_widget_image, if (night) dark else light)
        }
    }

    private fun faceSize(manager: AppWidgetManager, id: Int): String {
        val options = manager.getAppWidgetOptions(id)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return if (minWidth * 2 >= maxHeight * 3) MEDIUM else SMALL
    }

    private fun readSlots(json: String?): List<Slot> {
        if (json == null) return emptyList()
        return try {
            val array = JSONArray(json)
            List(array.length()) { index ->
                val entry = array.getJSONObject(index)
                if (FIELDS.any { !entry.has(it) }) throw JSONException("incomplete slot")
                Slot(
                    entry.getString(ADDRESS),
                    entry.getLong(SLOT_START_MS),
                    entry.getString(LIGHT_PATH),
                    entry.getString(DARK_PATH),
                    entry.getLong(LIGHT_BYTES),
                    entry.getLong(DARK_BYTES),
                )
            }
        } catch (unreadable: JSONException) {
            emptyList()
        }
    }

    // A publish that failed after saving images may have replaced the file a
    // slot names; a length other than the slot's means another image.
    private fun image(path: String, bytes: Long): Bitmap? {
        val file = File(path)
        if (file.length() != bytes) return null
        return BitmapFactory.decodeFile(file.path)
    }

    // The last slot whose day has started, else the first.
    private fun slotAt(slots: List<Slot>): Slot? {
        val now = System.currentTimeMillis()
        return slots.lastOrNull { it.slotStartMs <= now } ?: slots.firstOrNull()
    }

    private fun label(json: String?, address: String): String? {
        if (json == null) return null
        return try {
            JSONObject(json).optString(address).ifEmpty { null }
        } catch (unreadable: JSONException) {
            null
        }
    }

    private fun link(address: String): Uri =
        Uri.Builder()
            .scheme(LINK_SCHEME)
            .authority(LINK_HOST)
            .appendQueryParameter(LINK_ADDRESS, address)
            .build()

    private companion object {
        const val SLOTS_PREFIX = "ayah_widget_slots_"
        const val MEDIUM = "medium"
        const val SMALL = "small"
        const val LABELS_KEY = "ayah_widget_labels"
        const val ADDRESS = "address"
        const val SLOT_START_MS = "slotStartMs"
        const val LIGHT_PATH = "lightPath"
        const val DARK_PATH = "darkPath"
        const val LIGHT_BYTES = "lightBytes"
        const val DARK_BYTES = "darkBytes"
        val FIELDS = listOf(
            ADDRESS, SLOT_START_MS, LIGHT_PATH, DARK_PATH,
            "packTextSha256", LIGHT_BYTES, DARK_BYTES, "renderMs",
        )
        const val LINK_SCHEME = "holyquranspike"
        const val LINK_HOST = "ayah"
        const val LINK_ADDRESS = "address"
    }
}
