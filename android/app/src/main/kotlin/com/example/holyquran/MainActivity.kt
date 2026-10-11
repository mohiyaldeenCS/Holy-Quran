package com.example.holyquran

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    // Spike S4 (D-068): the shaping probe's channel.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ShapingProbe(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
