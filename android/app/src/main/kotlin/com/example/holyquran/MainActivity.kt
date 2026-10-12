package com.example.holyquran

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity shares its Flutter engine with the media service, so
// playback outlives the activity (S3). The channel asks for the notification
// permission of Android 13 and later at first playback (D-126).
class MainActivity : AudioServiceActivity() {
    private var pendingRequest: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == REQUEST) request(result) else result.notImplemented()
            }
    }

    // The engine outlives this activity, so its channel must not keep it.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(null)
        pendingRequest = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun request(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingRequest != null) {
            result.success(false)
            return
        }
        pendingRequest = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        pendingRequest?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        pendingRequest = null
    }

    private companion object {
        const val CHANNEL = "holyquran/notification_permission"
        const val REQUEST = "request"
        const val REQUEST_CODE = 4713
    }
}
