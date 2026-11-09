package com.example.uztexpro_payment

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import me.pushy.sdk.flutter.util.PushyNotification
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * The chat's notifications on Android, drawn by the app (like Telegram's): the
 * sender's round photo, the name, the text, the messages of one chat in one
 * notification, and a quiet channel when "Sound" is off.
 *
 * Pushy hands every push to every receiver that listens for the `pushy.me`
 * action. This one answers the chat's own pushes right here, with no wait for
 * the Dart isolate (which made them late); anything else is left to Pushy's.
 */
class ChatPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras ?: return
        if (extras.get("type")?.toString() != "chat") return
        // The app is open on the screen: it shows the message itself.
        if (appIsOpen(context)) return

        val values = HashMap<String, String>()
        val payload = JSONObject()
        for (key in extras.keySet()) {
            val v = extras.get(key)
            payload.put(key, v)
            values[key] = v?.toString() ?: ""
        }

        val pending = goAsync()
        thread(name = "chat-push") {
            try {
                show(context.applicationContext, values, payload.toString())
            } catch (_: Throwable) {
                // A notification that cannot be drawn must never crash the app.
            } finally {
                pending.finish()
            }
        }
    }

    /** The app writes a heartbeat while it is the foreground one (see
     *  `PushForeground` in chat_push.dart); an old one means it is not. */
    private fun appIsOpen(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val beat = try {
            prefs.getLong("flutter.chat_fg_beat", 0L)
        } catch (_: ClassCastException) {
            0L
        }
        if (beat == 0L) return false
        val age = System.currentTimeMillis() - beat
        return age >= -5000 && age < 45000
    }

    private fun show(context: Context, v: Map<String, String>, payload: String) {
        val convId = v["conversation"]?.toDoubleOrNull()?.toLong() ?: return
        val group = v["group"] == "true" || v["group"] == "1"
        val silent = v["silent"] == "1"
        val title = v["title"].orEmpty().ifEmpty { "UztexPro" }
        val senderName = v["sender_name"].orEmpty()
        val senderShort = senderName.trim().split(Regex("\\s+")).take(2).joinToString(" ")
        var text = v["message"].orEmpty()
        // In a group the push text starts with who wrote it; the notification
        // shows the name of the person above the text, so take it off here.
        if (group && senderShort.isNotEmpty() && text.startsWith("$senderShort: ")) {
            text = text.removePrefix("$senderShort: ")
        }

        val photo = downloadRound(v["sender_photo"].orEmpty(), 128)
        val person = Person.Builder()
            .setName(senderShort.ifEmpty { title })
            .setKey("u${v["sender"].orEmpty()}")
            .apply { if (photo != null) setIcon(IconCompat.createWithBitmap(photo)) }
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannels(context, manager)
        val notificationId = convId.toInt()

        // The messages already in this chat's notification stay, the new one
        // is added to them.
        val existing = manager.activeNotifications.firstOrNull { it.id == notificationId }
        val style = existing?.notification?.let {
            NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(it)
        } ?: NotificationCompat.MessagingStyle(Person.Builder().setName("me").build())
        if (group) {
            style.setConversationTitle(title)
            style.isGroupConversation = true
        }
        style.addMessage(text, System.currentTimeMillis(), person)

        val builder = NotificationCompat.Builder(context, channelId(silent))
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setColor(Color.parseColor("#FF8C00"))
            .setStyle(style)
            .setContentTitle(title)
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(
                if (silent) NotificationCompat.PRIORITY_DEFAULT else NotificationCompat.PRIORITY_HIGH
            )
            .setAutoCancel(true)
            .setWhen(System.currentTimeMillis())
            .setGroup(GROUP_KEY)
            .setContentIntent(PushyNotification.getMainActivityPendingIntent(context, payload))
            // A new message in a chat that already has a notification should
            // not make a sound again unless it is the first one.
            .setOnlyAlertOnce(false)
        if (photo != null) builder.setLargeIcon(photo)
        if (silent) builder.setSilent(true)

        val compat = NotificationManagerCompat.from(context)
        try {
            compat.notify(notificationId, builder.build())
            // The summary keeps the chats together in the shade.
            val summary = NotificationCompat.Builder(context, channelId(true))
                .setSmallIcon(R.drawable.ic_stat_notification)
                .setColor(Color.parseColor("#FF8C00"))
                .setGroup(GROUP_KEY)
                .setGroupSummary(true)
                .setAutoCancel(true)
                .setSilent(true)
                .build()
            compat.notify(SUMMARY_ID, summary)
        } catch (_: SecurityException) {
            // The notification permission (Android 13+) was refused.
        }
    }

    private fun channelId(silent: Boolean) = if (silent) CHANNEL_QUIET else CHANNEL_MESSAGES

    private fun ensureChannels(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_MESSAGES) == null) {
            val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val ch = NotificationChannel(
                CHANNEL_MESSAGES, "Сообщения", NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                setSound(sound, attrs)
                enableVibration(true)
                setShowBadge(true)
            }
            manager.createNotificationChannel(ch)
        }
        if (manager.getNotificationChannel(CHANNEL_QUIET) == null) {
            val ch = NotificationChannel(
                CHANNEL_QUIET, "Сообщения без звука", NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(true)
            }
            manager.createNotificationChannel(ch)
        }
    }

    /** The picture at [url] cut to a circle of [size] px; null when there is
     *  none or it cannot be fetched in a few seconds. */
    private fun downloadRound(url: String, size: Int): Bitmap? {
        if (!url.startsWith("http")) return null
        return try {
            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 3000
                readTimeout = 4000
                instanceFollowRedirects = true
            }
            val source = conn.inputStream.use { BitmapFactory.decodeStream(it) } ?: return null
            round(source, size)
        } catch (_: Throwable) {
            null
        }
    }

    private fun round(source: Bitmap, size: Int): Bitmap {
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        // Cut the middle square of the photo, then scale it to the circle.
        val side = minOf(source.width, source.height)
        val src = Rect(
            (source.width - side) / 2, (source.height - side) / 2,
            (source.width + side) / 2, (source.height + side) / 2,
        )
        canvas.drawBitmap(source, src, Rect(0, 0, size, size), paint)
        return out
    }

    companion object {
        private const val CHANNEL_MESSAGES = "chat_messages"
        private const val CHANNEL_QUIET = "chat_messages_quiet"
        private const val GROUP_KEY = "uztexpro_chat_messages"
        private const val SUMMARY_ID = 0
    }
}
