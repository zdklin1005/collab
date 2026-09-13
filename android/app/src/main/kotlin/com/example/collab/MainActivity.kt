package com.localquest.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val SPOTIFY_CHANNEL = "com.localquest.app/spotify_receiver"
    private val NOTIF_CHANNEL = "com.localquest.app/notifications"
    private val NOTIF_CHANNEL_ID = "localquest_social_channel"
    private var spotifyReceiver: BroadcastReceiver? = null

    companion object {
        private const val PREFS_NAME = "localquest_spotify_broadcast"
        private const val KEY_TRACK = "track"
        private const val KEY_ARTIST = "artist"
        private const val KEY_ALBUM = "album"
        private const val KEY_TRACK_ID = "track_id"
        private const val KEY_PLAYING = "playing"
        private const val KEY_TIMESTAMP = "timestamp"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerSpotifyReceiver()
        createNotificationChannel()
        requestNotificationPermission()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "LocalQuest Messages"
            val descriptionText = "Notifications for incoming messages and friend requests"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIF_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                enableLights(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    101
                )
            }
        }
    }

    private var spotifyMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Spotify Broadcast Receiver Channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPOTIFY_CHANNEL)
        spotifyMethodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLatestBroadcast" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val track = prefs.getString(KEY_TRACK, null)
                    if (track != null) {
                        val data = mapOf(
                            "track" to track,
                            "artist" to (prefs.getString(KEY_ARTIST, "") ?: ""),
                            "album" to (prefs.getString(KEY_ALBUM, "") ?: ""),
                            "trackId" to (prefs.getString(KEY_TRACK_ID, "") ?: ""),
                            "playing" to prefs.getBoolean(KEY_PLAYING, true),
                            "timestamp" to prefs.getLong(KEY_TIMESTAMP, 0L)
                        )
                        result.success(data)
                    } else {
                        result.success(null)
                    }
                }
                "clearBroadcast" -> {
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Native Notification Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val title = call.argument<String>("title") ?: "LocalQuest"
                    val body = call.argument<String>("body") ?: ""
                    showNativeNotification(id, title, body)
                    result.success(true)
                }
                "requestPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun showNativeNotification(id: Int, title: String, body: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val builder = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        try {
            with(NotificationManagerCompat.from(this)) {
                if (ActivityCompat.checkSelfPermission(
                        this@MainActivity,
                        android.Manifest.permission.POST_NOTIFICATIONS
                    ) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
                ) {
                    notify(id, builder.build())
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun registerSpotifyReceiver() {
        if (spotifyReceiver != null) return

        spotifyReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                val action = intent.action ?: return

                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val editor = prefs.edit()

                if (action == "com.spotify.music.metadatachanged" || action == "com.spotify.mobile.android.metadatachanged") {
                    val track = intent.getStringExtra("track")
                    val artist = intent.getStringExtra("artist")
                    val album = intent.getStringExtra("album")
                    val trackId = intent.getStringExtra("id")
                    val playing = intent.getBooleanExtra("playing", true)

                    if (!track.isNullOrEmpty()) {
                        editor.putString(KEY_TRACK, track)
                        editor.putString(KEY_ARTIST, artist ?: "")
                        editor.putString(KEY_ALBUM, album ?: "")
                        editor.putString(KEY_TRACK_ID, trackId ?: "")
                        editor.putBoolean(KEY_PLAYING, playing)
                        editor.putLong(KEY_TIMESTAMP, System.currentTimeMillis())
                        editor.apply()

                        runOnUiThread {
                            spotifyMethodChannel?.invokeMethod("onPlaybackChanged", mapOf(
                                "track" to track,
                                "artist" to (artist ?: ""),
                                "album" to (album ?: ""),
                                "trackId" to (trackId ?: ""),
                                "playing" to playing,
                                "timestamp" to System.currentTimeMillis()
                            ))
                        }
                    }
                } else if (action == "com.spotify.music.playbackstatechanged" || action == "com.spotify.mobile.android.playbackstatechanged") {
                    val playing = intent.getBooleanExtra("playing", false)
                    editor.putBoolean(KEY_PLAYING, playing)
                    editor.putLong(KEY_TIMESTAMP, System.currentTimeMillis())
                    editor.apply()

                    runOnUiThread {
                        spotifyMethodChannel?.invokeMethod("onPlaybackStateChanged", mapOf(
                            "playing" to playing,
                            "timestamp" to System.currentTimeMillis()
                        ))
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction("com.spotify.music.metadatachanged")
            addAction("com.spotify.music.playbackstatechanged")
            addAction("com.spotify.music.queuechanged")
            addAction("com.spotify.mobile.android.metadatachanged")
            addAction("com.spotify.mobile.android.playbackstatechanged")
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ContextCompat.registerReceiver(
                    this,
                    spotifyReceiver!!,
                    filter,
                    ContextCompat.RECEIVER_EXPORTED
                )
            } else {
                registerReceiver(spotifyReceiver, filter)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        spotifyReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            spotifyReceiver = null
        }
    }
}
