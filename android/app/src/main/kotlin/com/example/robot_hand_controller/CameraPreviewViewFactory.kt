package com.example.robot_hand_controller

import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class CameraPreviewViewFactory(
    private val context: Context,
    private val onGestureDetected: (String) -> Unit
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val lifecycleOwner = context as? LifecycleOwner
            ?: throw IllegalStateException("Context must be a LifecycleOwner")
        return CameraPreview(context, viewId, lifecycleOwner, onGestureDetected)
    }
}
