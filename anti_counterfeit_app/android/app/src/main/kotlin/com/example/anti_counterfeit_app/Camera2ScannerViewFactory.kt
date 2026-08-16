package com.example.anti_counterfeit_app

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Camera2ScannerViewFactory
 *
 * Registered in MainActivity to create instances of Camera2ScannerView
 * whenever Flutter requests the 'com.blockguard.anticounterfeit/scanner_view' platform view.
 */
class Camera2ScannerViewFactory(
    private val activityContext: Context,
    private val onScannerViewCreated: (Camera2ScannerView) -> Unit,
    private var eventSink: EventChannel.EventSink?
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        // Use activityContext (not the Flutter wrapper context) so Camera2 works correctly
        val scannerView = Camera2ScannerView(activityContext, eventSink)
        onScannerViewCreated(scannerView)
        return scannerView
    }
}
