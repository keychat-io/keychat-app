package com.keychat.io

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.keychat.io/system"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getNavigationMode") {
                try {
                    val resourceId = resources.getIdentifier("config_navBarInteractionMode", "integer", "android")
                    if (resourceId > 0) {
                        result.success(resources.getInteger(resourceId))
                    } else {
                        result.success(-1)
                    }
                } catch (e: Exception) {
                    result.success(-1)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
