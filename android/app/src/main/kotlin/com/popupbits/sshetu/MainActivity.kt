package com.popupbits.sshetu

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity, not a plain FlutterActivity: local_auth shows Android's
// BiometricPrompt, which is a fragment and cannot attach to anything else.
// Without it the credential lock fails on every Android device.
// Guarded by test/android_manifest_test.dart.
class MainActivity : FlutterFragmentActivity() {
    private var keepAlive: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The keep-alive service's controls. Dart owns the decision of when
        // it runs; see lib/core/background/keep_alive_service.dart.
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.popupbits.sshetu/keep_alive",
        )
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> KeepAliveService.start(
                        this,
                        KeepAliveService.Notice.from(call.arguments as Map<*, *>),
                    )
                    "update" -> KeepAliveService.update(
                        this,
                        KeepAliveService.Notice.from(call.arguments as Map<*, *>),
                    )
                    "stop" -> KeepAliveService.stop(this)
                    "requestNotificationPermission" -> requestNotificationPermission()
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                result.success(null)
            } catch (error: Exception) {
                // Android 12+ throws ForegroundServiceStartNotAllowedException
                // when a service is started from the background.
                result.error("keep_alive", error.toString(), null)
            }
        }
        KeepAliveService.onDisconnectAll = { channel.invokeMethod("disconnectAll", null) }
        keepAlive = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The engine — and the isolate holding every socket — is going away.
        // A service kept running past it would keep nothing alive.
        KeepAliveService.onDisconnectAll = null
        keepAlive?.setMethodCallHandler(null)
        keepAlive = null
        KeepAliveService.stop(this)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * Asks for POST_NOTIFICATIONS (Android 13+) without waiting for the
     * answer: the service runs either way, and a denied permission only hides
     * its notification. Android itself stops showing the prompt once it has
     * been declined, so asking again is harmless.
     */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    @Deprecated("Still delivered; FlutterFragmentActivity forwards it to plugins via super.")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        @Suppress("DEPRECATION")
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST &&
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        ) {
            // The service started while the prompt was up, so its notification
            // was dropped. Show it now that it is allowed.
            KeepAliveService.repost(this)
        }
    }

    private companion object {
        const val NOTIFICATION_PERMISSION_REQUEST = 0x5354
    }
}
