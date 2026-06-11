package com.example.robot_hand_controller

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val GESTURE_CHANNEL = "com.example.robot_hand_controller/gesture"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Setup Event Channel for streaming gesture commands
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GESTURE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // 2. Register Camera Preview Platform View
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "camera_preview_view",
            CameraPreviewViewFactory(this) { gesture ->
                // Ensure we communicate gesture updates on the Android Main (UI) thread
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(gesture)
                }
            }
        )
    }
}
