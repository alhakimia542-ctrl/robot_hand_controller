package com.example.robot_hand_controller

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.SystemClock
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.FlutterInjector
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class CameraPreview(
    private val context: Context,
    private val viewId: Int,
    private val lifecycleOwner: LifecycleOwner,
    private val onGestureDetected: (String) -> Unit
) : PlatformView {

    private val previewView: PreviewView = PreviewView(context)
    private var cameraProvider: ProcessCameraProvider? = null
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var handLandmarker: HandLandmarker? = null
    private var lastGesture = "HOLD"

    init {
        setupHandLandmarker()
        startCamera()
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        cameraExecutor.shutdown()
        cameraProvider?.unbindAll()
        handLandmarker?.close()
    }

    private fun setupHandLandmarker() {
        try {
            // Find Flutter asset key for the Hand Landmarker model
            val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/hand_landmarker.task")
            
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(assetKey)
                .build()

            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setMinHandDetectionConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setNumHands(1)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ ->
                    processResult(result)
                }
                .setErrorListener { _ ->
                    onGestureDetected("HOLD")
                }
                .build()

            handLandmarker = HandLandmarker.createFromOptions(context, options)
        } catch (e: Exception) {
            onGestureDetected("HOLD")
        }
    }

    private fun startCamera() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()

                // 1. Preview Config
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

                // 2. ImageAnalysis Config (latest frame only to prevent lagging)
                val imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                    .also { analysis ->
                        analysis.setAnalyzer(cameraExecutor) { imageProxy ->
                            try {
                                val landmarker = handLandmarker
                                if (landmarker != null) {
                                    val rotationDegrees = imageProxy.imageInfo.rotationDegrees
                                    val bitmap = imageProxy.toBitmap()

                                    if (bitmap != null) {
                                        val mpImage = BitmapImageBuilder(bitmap).build()
                                        val frameTime = SystemClock.uptimeMillis()
                                        
                                        val imageProcessingOptions = ImageProcessingOptions.builder()
                                            .setRotationDegrees(rotationDegrees)
                                            .build()

                                        landmarker.detectAsync(mpImage, imageProcessingOptions, frameTime)
                                    }
                                }
                            } catch (e: Exception) {
                                // Ignore analysis exception, keep camera running
                            } finally {
                                // CRITICAL: Always close the imageProxy to prevent memory leaks and CameraX freezes
                                imageProxy.close()
                            }
                        }
                    }

                // Use the Front Camera for intuitive user interaction
                val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    lifecycleOwner, cameraSelector, preview, imageAnalysis
                )
            } catch (exc: Exception) {
                // Camera initialization failed
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun processResult(result: HandLandmarkerResult) {
        val landmarksList = result.landmarks()
        if (landmarksList.isNullOrEmpty()) {
            sendGesture("HOLD")
            return
        }

        // We only track the primary hand detected (Index 0)
        val primaryHand = landmarksList[0]
        val gesture = HandGestureHelper.getGesture(primaryHand)
        sendGesture(gesture)
    }

    private fun sendGesture(gesture: String) {
        if (gesture != lastGesture) {
            lastGesture = gesture
            onGestureDetected(gesture)
        }
    }
}
