package com.pianomisspass.pianomisspass_fe

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativeMicrophonePitchPlugin: NativeMicrophonePitchPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeMicrophonePitchPlugin = NativeMicrophonePitchPlugin.register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }
}
