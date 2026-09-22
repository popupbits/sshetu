package com.popupbits.sshetu

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Keeps the process alive, and in the foreground, while SSH sessions or
 * tunnels are open.
 *
 * It does no networking. The sockets live in the Dart isolate; Android would
 * otherwise freeze or kill a backgrounded app within minutes and take every
 * connection with it. Started, updated and stopped from Dart over the
 * `com.popupbits.sshetu/keep_alive` channel (see MainActivity), which follows
 * the open session and tunnel counts — so it never runs with nothing behind it.
 *
 * Type `specialUse`: an interactive remote shell is not a data sync (and
 * Android 15 caps `dataSync` at six hours a day). The subtype is declared in
 * the manifest and justified to Play in PROJECT.md.
 *
 * Holds a PARTIAL_WAKE_LOCK so the CPU keeps running the isolate — keepalive
 * timers, reads, a command's output — with the screen off. No Wi-Fi lock:
 * WIFI_MODE_FULL_HIGH_PERF is non-functional on current Android and silently
 * becomes WIFI_MODE_FULL_LOW_LATENCY, which is only active with the screen on
 * and the app in the foreground — exactly when it is not needed. Wi-Fi stays
 * associated in power-save mode, which costs latency, not the connection.
 */
class KeepAliveService : Service() {

    data class Notice(
        val title: String,
        val text: String,
        val disconnectAllLabel: String,
        val channelName: String,
    ) {
        fun into(intent: Intent): Intent = intent
            .putExtra(EXTRA_TITLE, title)
            .putExtra(EXTRA_TEXT, text)
            .putExtra(EXTRA_ACTION, disconnectAllLabel)
            .putExtra(EXTRA_CHANNEL, channelName)

        companion object {
            fun from(intent: Intent) = Notice(
                title = intent.getStringExtra(EXTRA_TITLE) ?: "",
                text = intent.getStringExtra(EXTRA_TEXT) ?: "",
                disconnectAllLabel = intent.getStringExtra(EXTRA_ACTION) ?: "",
                channelName = intent.getStringExtra(EXTRA_CHANNEL) ?: "",
            )

            fun from(arguments: Map<*, *>) = Notice(
                title = arguments["title"] as? String ?: "",
                text = arguments["text"] as? String ?: "",
                disconnectAllLabel = arguments["disconnectAllLabel"] as? String ?: "",
                channelName = arguments["channelName"] as? String ?: "",
            )
        }
    }

    companion object {
        private const val CHANNEL_ID = "active_connections"
        private const val NOTIFICATION_ID = 0x5354
        private const val ACTION_START = "com.popupbits.sshetu.keepalive.START"
        private const val ACTION_DISCONNECT_ALL =
            "com.popupbits.sshetu.keepalive.DISCONNECT_ALL"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_ACTION = "disconnectAllLabel"
        private const val EXTRA_CHANNEL = "channelName"
        private const val WAKE_LOCK_TAG = "sshetu:keep-alive"

        /** Set by MainActivity while its Flutter engine is alive. Main thread only. */
        var onDisconnectAll: (() -> Unit)? = null

        /** Whether the service is running. Main thread only. */
        var running = false
            private set

        fun start(context: Context, notice: Notice) {
            val intent = notice.into(
                Intent(context, KeepAliveService::class.java).setAction(ACTION_START),
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** What the notification says now. Main thread only. */
        private var current: Notice? = null

        /** Replaces the notification's text. Does nothing unless running. */
        fun update(context: Context, notice: Notice) {
            current = notice
            if (!running) return
            val manager = context.getSystemService(NotificationManager::class.java)
            ensureChannel(context, manager, notice.channelName)
            manager.notify(NOTIFICATION_ID, build(context, notice))
        }

        /**
         * Posts the notification again. Needed once POST_NOTIFICATIONS is
         * granted: the permission is asked for at the first connection, which
         * is also when the service starts, so its notification was posted — and
         * silently dropped — before the user had answered. Android does not
         * re-show it on grant.
         */
        fun repost(context: Context) {
            current?.let { update(context, it) }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, KeepAliveService::class.java))
        }

        private fun ensureChannel(
            context: Context,
            manager: NotificationManager,
            name: String,
        ) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            // Low importance: in the shade, never a sound, a vibration or a
            // heads-up. Recreating an existing channel only renames it, so a
            // language change reaches system settings too.
            val channel = NotificationChannel(
                CHANNEL_ID,
                name.ifEmpty { context.applicationInfo.loadLabel(context.packageManager) },
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        private fun build(context: Context, notice: Notice): Notification {
            val open = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.let {
                    PendingIntent.getActivity(
                        context,
                        0,
                        it,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                }
            val disconnect = PendingIntent.getService(
                context,
                1,
                Intent(context, KeepAliveService::class.java)
                    .setAction(ACTION_DISCONNECT_ALL),
                PendingIntent.FLAG_IMMUTABLE,
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
            }
            builder
                .setSmallIcon(R.drawable.ic_stat_connections)
                .setContentTitle(notice.title)
                .setContentText(notice.text)
                .setContentIntent(open)
                .setCategory(Notification.CATEGORY_SERVICE)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .addAction(
                    Notification.Action.Builder(
                        Icon.createWithResource(context, R.drawable.ic_stat_connections),
                        notice.disconnectAllLabel,
                        disconnect,
                    ).build(),
                )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Shown at once rather than after Android's ten-second grace:
                // "Disconnect all" should be reachable from the moment it runs.
                builder.setForegroundServiceBehavior(
                    Notification.FOREGROUND_SERVICE_IMMEDIATE,
                )
            }
            return builder.build()
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT_ALL) {
            // Dart closes every session and tunnel, the counts reach zero and
            // Dart stops this service. With no engine to ask, nothing is left
            // to keep alive, so stop here.
            val listener = onDisconnectAll
            if (listener != null) listener() else stopSelf()
            return START_NOT_STICKY
        }

        val notice = Notice.from(intent ?: Intent())
        current = notice
        val manager = getSystemService(NotificationManager::class.java)
        ensureChannel(this, manager, notice.channelName)
        val notification = build(this, notice)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true

        if (wakeLock == null) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
                .apply {
                    setReferenceCounted(false)
                    // No timeout on purpose: it is held exactly as long as a
                    // connection is open, and released in onDestroy.
                    acquire()
                }
        }
        // Not sticky: if Android kills the process anyway, the sockets died
        // with it, and a restarted service would advertise connections that
        // no longer exist.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Swiping the app out of recents destroys the activity and its Flutter
        // engine, and every session with it. Nothing is left to keep alive.
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        current = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }
}
