package com.example.uztexpro_payment

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 13+: notifications are off until the user allows them, and a
        // push (Pushy) is shown by the app itself, so ask once on start.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The number on the Android icon is the count of notifications in the
        // shade: nothing unread any more means they must go.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "uztexpro/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "cancelAll") {
                    (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
