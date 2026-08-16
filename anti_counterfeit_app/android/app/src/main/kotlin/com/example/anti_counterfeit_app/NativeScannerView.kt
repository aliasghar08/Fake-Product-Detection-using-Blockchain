package com.example.anti_counterfeit_app

import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import android.view.View
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class NativeScannerView(
    private val context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
    private val lifecycleOwner: LifecycleOwner,
    private var eventSink: EventChannel.EventSink?
) : PlatformView {

    private val previewView: PreviewView = PreviewView(context)
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var isPaused = false

    init {
        startCamera()
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        cameraExecutor.shutdown()
        cameraProvider?.unbindAll()
    }

    fun pauseDetection() {
        isPaused = true
    }

    fun resumeDetection() {
        isPaused = false
        if (camera == null) {
            startCamera()
        }
    }

    fun toggleTorch() {
        val hasFlash = camera?.cameraInfo?.hasFlashUnit() == true
        if (hasFlash) {
            val isOn = camera?.cameraInfo?.torchState?.value == androidx.camera.core.TorchState.ON
            camera?.cameraControl?.enableTorch(!isOn)
        }
    }

    fun isTorchOn(): Boolean {
        return camera?.cameraInfo?.torchState?.value == androidx.camera.core.TorchState.ON
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalyzer = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also {
                    it.setAnalyzer(cameraExecutor, BarcodeAnalyzer { barcode ->
                        if (!isPaused && barcode.isNotEmpty()) {
                            // Send barcode to Flutter on the main thread
                            ContextCompat.getMainExecutor(context).execute {
                                eventSink?.success(barcode)
                            }
                        }
                    })
                }

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    cameraProvider?.unbindAll()
                    camera = cameraProvider?.bindToLifecycle(
                        lifecycleOwner, cameraSelector, preview, imageAnalyzer
                    )
                } else {
                    Log.w("NativeScannerView", "Camera permission not granted yet")
                }
            } catch (exc: Exception) {
                Log.e("NativeScannerView", "Use case binding failed", exc)
            }

        }, ContextCompat.getMainExecutor(context))
    }

    private class BarcodeAnalyzer(private val onBarcodeDetected: (String) -> Unit) : ImageAnalysis.Analyzer {
        private val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE, Barcode.FORMAT_ALL_FORMATS)
            .build()
        private val scanner = BarcodeScanning.getClient(options)

        @SuppressLint("UnsafeOptInUsageError")
        override fun analyze(imageProxy: ImageProxy) {
            val mediaImage = imageProxy.image
            if (mediaImage != null) {
                val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                scanner.process(image)
                    .addOnSuccessListener { barcodes ->
                        for (barcode in barcodes) {
                            barcode.rawValue?.let {
                                onBarcodeDetected(it)
                            }
                        }
                    }
                    .addOnFailureListener {
                        // Task failed with an exception
                    }
                    .addOnCompleteListener {
                        imageProxy.close()
                    }
            } else {
                imageProxy.close()
            }
        }
    }
}
