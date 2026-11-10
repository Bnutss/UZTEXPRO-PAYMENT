package com.example.uztexpro_payment

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** The data of the chat push whose notification was tapped, until Dart takes it. */
    private var pendingPush: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingPush = intent?.getStringExtra(EXTRA_PUSH)
        // Android 13+: notifications are off until the user allows them, and a
        // push is shown by the app itself, so ask once on start.
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
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "uztexpro/notifications")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancelAll" -> {
                    (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
                    result.success(true)
                }
                // iOS has a number on the icon; here it is the notifications.
                "clearBadge" -> {
                    (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
                    result.success(true)
                }
                // The tap that launched the app.
                "initialPush" -> {
                    result.success(pendingPush)
                    pendingPush = null
                }
                else -> result.notImplemented()
            }
        }
    }

    /** A notification tapped while the app is already running. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val payload = intent.getStringExtra(EXTRA_PUSH) ?: return
        intent.removeExtra(EXTRA_PUSH)
        channel?.invokeMethod("pushTapped", payload)
    }

    companion object {
        /** The extra a notification's tap carries: the push data as JSON. */
        const val EXTRA_PUSH = "chat_push_payload"
    }
}
