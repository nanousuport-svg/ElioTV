package com.eliotv.eliotv

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Android TV / Fire TV déclarent « leanback » : l'app passe en mode télécommande.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eliotv/device").setMethodCallHandler { call, result ->
            if (call.method == "isTv") {
                result.success(packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
            } else {
                result.notImplemented()
            }
        }
    }
}
