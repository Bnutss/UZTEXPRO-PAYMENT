package com.example.uztexpro_payment

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Receives every Firebase push. The chat's own pushes are data-only and drawn
 * natively here (photo, name, grouping); anything else goes to the Flutter
 * plugin's service as usual.
 *
 * Runs on a background thread Firebase gives (about 20 seconds), so downloading
 * the sender's photo here is fine.
 */
class ChatFirebaseService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        when (data["type"]) {
            "chat" -> ChatNotifier.onPush(applicationContext, data)
            "test" -> ChatNotifier.showPlain(
                applicationContext,
                data["title"].orEmpty().ifEmpty { "UztexPro" },
                data["message"].orEmpty(),
            )
            else -> super.onMessageReceived(message)
        }
    }
}
