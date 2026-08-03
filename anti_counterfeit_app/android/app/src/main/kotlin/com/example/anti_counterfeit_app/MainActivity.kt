package com.example.anti_counterfeit_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity // MUST be FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.concurrent.Executor

class MainActivity: FlutterFragmentActivity() {
    // We now have two separate channels for clean architecture
    private val GALLERY_CHANNEL = "com.example.anti_counterfeit_app/gallery"
    private val BIOMETRIC_CHANNEL = "com.example.anti_counterfeit_app/biometrics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 1. Setup Gallery Channel Handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GALLERY_CHANNEL).setMethodCallHandler { call, result ->
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

        // 2. Setup Biometric Channel Handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BIOMETRIC_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "authenticate") {
                authenticateUser(result)
            } else {
                result.notImplemented()
            }
        }
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
                    result.success(true) // Authentication successful!
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    // If the user clicks "Cancel" or hits the back button, we just return false
                    if (errorCode == BiometricPrompt.ERROR_USER_CANCELED || errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON) {
                        result.success(false)
                    } else {
                        result.error("AUTH_ERROR", errString.toString(), errorCode)
                    }
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    // Android handles the UI for a failed attempt automatically (e.g. shakes the prompt).
                    // We don't need to return anything here yet, the user can try again.
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
}
