package com.example.anti_counterfeit_app

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.concurrent.Executor

class MainActivity: FlutterFragmentActivity() {
    private val GALLERY_CHANNEL = "com.example.anti_counterfeit_app/gallery"
    private val BIOMETRIC_CHANNEL = "com.example.anti_counterfeit_app/biometrics"
    
    private val SCANNER_CONTROL_CHANNEL = "com.blockguard.anticounterfeit/scanner_control"
    private val SCANNER_EVENTS_CHANNEL = "com.blockguard.anticounterfeit/scanner_events"
    private val SCANNER_VIEW_TYPE = "com.blockguard.anticounterfeit/scanner_view"
    
    private val STORAGE_CHANNEL = "com.blockguard.anticounterfeit/storage"
    private val URL_LAUNCHER_CHANNEL = "com.blockguard.anticounterfeit/url_launcher"
    private val LOCATION_CHANNEL = "com.blockguard.anticounterfeit/location"

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private var scannerEventSink: EventChannel.EventSink? = null
    private var scannerView: Camera2ScannerView? = null
    private var cameraPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 1. Gallery Channel
        MethodChannel(messenger, GALLERY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveImage") {
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename") ?: "image_${System.currentTimeMillis()}.png"
                if (bytes != null) {
                    val success = saveImageToGallery(bytes, filename)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGS", "Image bytes are null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Biometric Channel
        MethodChannel(messenger, BIOMETRIC_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "authenticate") {
                authenticateUser(result)
            } else {
                result.notImplemented()
            }
        }

        // 3. Storage Channel
        MethodChannel(messenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("BlockGuardStorage", Context.MODE_PRIVATE)
            when (call.method) {
                "getString" -> {
                    val key = call.arguments as? String
                    if (key != null) result.success(prefs.getString(key, null))
                    else result.error("INVALID_ARGS", "Key required", null)
                }
                "setString" -> {
                    val args = call.arguments as? Map<*, *>
                    val key = args?.get("key") as? String
                    val value = args?.get("value") as? String
                    if (key != null && value != null) {
                        prefs.edit().putString(key, value).apply()
                        result.success(true)
                    } else result.error("INVALID_ARGS", "key+value required", null)
                }
                "remove" -> {
                    val key = call.arguments as? String
                    if (key != null) {
                        prefs.edit().remove(key).apply()
                        result.success(true)
                    } else result.error("INVALID_ARGS", "Key required", null)
                }
                else -> result.notImplemented()
            }
        }

        // 4. URL Launcher Channel
        MethodChannel(messenger, URL_LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launch") {
                val urlString = call.arguments as? String
                if (urlString != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(urlString))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else result.notImplemented()
            } else result.notImplemented()
        }

        // 5. Location Channel
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        MethodChannel(messenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentLocation" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
                            if (location != null) {
                                result.success(mapOf("latitude" to location.latitude, "longitude" to location.longitude))
                            } else {
                                result.success(null)
                            }
                        }.addOnFailureListener { result.success(null) }
                    } else {
                        result.success(null)
                    }
                }
                "checkPermission" -> {
                    val status = if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) "always" else "denied"
                    result.success(status)
                }
                "requestPermission" -> {
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 1001)
                    result.success("always")
                }
                "isLocationServiceEnabled" -> {
                    val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    val isEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) || locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                    result.success(isEnabled)
                }
                else -> result.notImplemented()
            }
        }

        // 6. Scanner Events Channel
        EventChannel(messenger, SCANNER_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scannerEventSink = events
                    scannerView?.setEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    scannerEventSink = null
                    scannerView?.setEventSink(null)
                }
            }
        )

        // 7. Scanner Control Channel
        MethodChannel(messenger, SCANNER_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestCameraPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        cameraPermissionResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 1002)
                    }
                }
                "start" -> { scannerView?.resumeDetection(); result.success(null) }
                "stop" -> { scannerView?.pauseDetection(); result.success(null) }
                "pause" -> { scannerView?.pauseDetection(); result.success(null) }
                "resume" -> { scannerView?.resumeDetection(); result.success(null) }
                "toggleTorch" -> { scannerView?.toggleTorch(); result.success(null) }
                "isTorchOn" -> { result.success(scannerView?.isTorchOn() ?: false) }
                else -> result.notImplemented()
            }
        }

        // 8. Register Camera2 Scanner View
        flutterEngine.platformViewsController.registry.registerViewFactory(
            SCANNER_VIEW_TYPE,
            Camera2ScannerViewFactory(this, { view ->
                scannerView = view
                view.setEventSink(scannerEventSink)
            }, scannerEventSink)
        )
    }

    // ==========================================
    // BIOMETRIC IMPLEMENTATION
    // ==========================================
    private fun authenticateUser(result: MethodChannel.Result) {
        val executor: Executor = ContextCompat.getMainExecutor(this)
        
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(authResult)
                    result.success(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    if (errorCode == BiometricPrompt.ERROR_USER_CANCELED || errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON) {
                        result.success(false)
                    } else {
                        result.error("AUTH_ERROR", errString.toString(), errorCode)
                    }
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                }
            })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Secure Retailer Checkout")
            .setSubtitle("Authenticate to access your private key")
            .setNegativeButtonText("Cancel")
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    // ==========================================
    // GALLERY IMPLEMENTATION 
    // ==========================================
    private fun saveImageToGallery(bytes: ByteArray, filename: String): Boolean {
        return try {
            val resolver = contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }

            val imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            if (imageUri != null) {
                resolver.openOutputStream(imageUri)?.use { outputStream: OutputStream ->
                    outputStream.write(bytes)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(imageUri, contentValues, null, null)
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1002) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            cameraPermissionResult?.success(granted)
            cameraPermissionResult = null
        }
    }
}