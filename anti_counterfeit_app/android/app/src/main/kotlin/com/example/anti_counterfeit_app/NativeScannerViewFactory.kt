package com.example.anti_counterfeit_app

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import androidx.lifecycle.LifecycleOwner

class NativeScannerViewFactory(
    private val lifecycleOwner: LifecycleOwner,
    private val onScannerViewCreated: (NativeScannerView) -> Unit,
    private var eventSink: EventChannel.EventSink?
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        val scannerView = NativeScannerView(context, viewId, creationParams, lifecycleOwner, eventSink)
        onScannerViewCreated(scannerView)
        return scannerView
    }
}
