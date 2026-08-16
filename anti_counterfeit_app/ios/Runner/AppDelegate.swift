import Flutter
import UIKit
import LocalAuthentication
import Photos
import AVFoundation
import CoreLocation

// MARK: - AppDelegate

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let registrar = self.registrar(forPlugin: "AppChannels") else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let messenger = registrar.messenger()

      // ── 1. Gallery Channel ───────────────────────────────────────────────
      let galleryChannel = FlutterMethodChannel(
        name: "com.example.anti_counterfeit_app/gallery",
        binaryMessenger: messenger
      )
      galleryChannel.setMethodCallHandler({ (call, result) in
        if call.method == "saveImage" {
          guard let args = call.arguments as? [String: Any],
                let bytes = args["bytes"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "Image bytes are null", details: nil))
            return
          }
          if let image = UIImage(data: bytes.data) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            result(true)
          } else {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      })

      // ── 2. Biometric Channel ─────────────────────────────────────────────
      let biometricChannel = FlutterMethodChannel(
        name: "com.example.anti_counterfeit_app/biometrics",
        binaryMessenger: messenger
      )
      biometricChannel.setMethodCallHandler({ (call, result) in
        if call.method == "authenticate" {
          let context = LAContext()
          var error: NSError?
          if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
              .deviceOwnerAuthenticationWithBiometrics,
              localizedReason: "Authenticate to access your private key"
            ) { success, _ in
              DispatchQueue.main.async { result(success) }
            }
          } else {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      })

      // ── 3. Native QR Scanner — EventChannel (barcode stream) ────────────
      let scannerEventChannel = FlutterEventChannel(
        name: "com.blockguard.anticounterfeit/scanner_events",
        binaryMessenger: messenger
      )
      scannerEventChannel.setStreamHandler(ScannerStreamHandler.shared)

      // ── 4. Native QR Scanner — MethodChannel (controls) ─────────────────
      let scannerMethodChannel = FlutterMethodChannel(
        name: "com.blockguard.anticounterfeit/scanner_control",
        binaryMessenger: messenger
      )
      scannerMethodChannel.setMethodCallHandler({ (call, result) in
        switch call.method {
        case "requestCameraPermission":
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                result(true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async { result(granted) }
                }
            case .denied, .restricted:
                result(false)
            @unknown default:
                result(false)
            }
        case "start":
          ScannerManager.shared.startSession()
          result(nil)
        case "stop":
          ScannerManager.shared.stopSession()
          result(nil)
        case "pause":
          ScannerManager.shared.pause()
          result(nil)
        case "resume":
          ScannerManager.shared.resume()
          result(nil)
        case "toggleTorch":
          ScannerManager.shared.toggleTorch()
          result(nil)
        case "isTorchOn":
          result(ScannerManager.shared.isTorchOn)
        default:
          result(FlutterMethodNotImplemented)
        }
      })

      // ── 5. Register native camera preview as a Flutter platform view ─────
      if let registrar = self.registrar(forPlugin: "BlockGuardNativeScanner") {
        registrar.register(
          NativeScannerViewFactory(),
          withId: "com.blockguard.anticounterfeit/scanner_view"
        )
      }

      // ── 6. Storage Channel (replaces shared_preferences) ─────────────────
      //    Uses iOS UserDefaults — built-in since iOS 2, no CocoaPods needed.
      let storageChannel = FlutterMethodChannel(
        name: "com.blockguard.anticounterfeit/storage",
        binaryMessenger: messenger
      )
      storageChannel.setMethodCallHandler({ (call, result) in
        let defaults = UserDefaults.standard
        switch call.method {
        case "getString":
          guard let key = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Key required", details: nil))
            return
          }
          result(defaults.string(forKey: key))

        case "setString":
          guard let args = call.arguments as? [String: String],
                let key = args["key"], let value = args["value"] else {
            result(FlutterError(code: "INVALID_ARGS", message: "key+value required", details: nil))
            return
          }
          defaults.set(value, forKey: key)
          result(true)

        case "remove":
          guard let key = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Key required", details: nil))
            return
          }
          defaults.removeObject(forKey: key)
          result(true)

        default:
          result(FlutterMethodNotImplemented)
        }
      })

      // ── 7. URL Launcher Channel (replaces url_launcher) ──────────────────
      //    Uses UIApplication.open — built-in, no CocoaPods needed.
      let urlChannel = FlutterMethodChannel(
        name: "com.blockguard.anticounterfeit/url_launcher",
        binaryMessenger: messenger
      )
      urlChannel.setMethodCallHandler({ (call, result) in
        guard call.method == "launch",
              let urlString = call.arguments as? String,
              let url = URL(string: urlString) else {
          result(FlutterMethodNotImplemented)
          return
        }
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        } else {
          result(false)
        }
      })

      // ── 8. Location Channel (replaces geolocator) ────────────────────────
      //    Uses CLLocationManager — built-in, no CocoaPods needed.
      LocationManager.shared.setup(binaryMessenger: messenger)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - LocationManager

/// Wraps CLLocationManager to expose GPS coordinates via a Flutter MethodChannel.
/// Replaces the geolocator package entirely.
final class LocationManager: NSObject, CLLocationManagerDelegate {

  static let shared = LocationManager()

  private let clManager = CLLocationManager()
  private var pendingResult: FlutterResult?

  private override init() {
    super.init()
    clManager.delegate = self
    clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // low accuracy = fast + battery-friendly
  }

  func setup(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.blockguard.anticounterfeit/location",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "getCurrentLocation":
        self.fetchLocation(result: result)
      case "checkPermission":
        result(self.permissionStatus())
      case "requestPermission":
        self.clManager.requestWhenInUseAuthorization()
        // Return current status — Flutter polls again after the dialog
        result(self.permissionStatus())
      case "isLocationServiceEnabled":
        result(CLLocationManager.locationServicesEnabled())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func permissionStatus() -> String {
    switch clManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways: return "granted"
    case .denied:                                  return "denied"
    case .restricted:                              return "deniedForever"
    case .notDetermined:                           return "notDetermined"
    @unknown default:                              return "denied"
    }
  }

  private func fetchLocation(result: @escaping FlutterResult) {
    let status = clManager.authorizationStatus
    guard status == .authorizedWhenInUse || status == .authorizedAlways else {
      result(nil)
      return
    }
    guard CLLocationManager.locationServicesEnabled() else {
      result(nil)
      return
    }
    pendingResult = result
    clManager.requestLocation()
  }

  // MARK: CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    pendingResult?(["latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude])
    pendingResult = nil
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    pendingResult?(nil)
    pendingResult = nil
  }
}

// MARK: - ScannerManager

/// Singleton that owns a single AVCaptureSession for both
/// the live camera preview (via AVCaptureVideoPreviewLayer)
/// and QR detection (via AVCaptureMetadataOutput).
///
/// No third-party library is used — AVFoundation is built into iOS 7+.
final class ScannerManager: NSObject, AVCaptureMetadataOutputObjectsDelegate {

  static let shared = ScannerManager()

  let captureSession = AVCaptureSession()
  private(set) var previewLayer: AVCaptureVideoPreviewLayer?
  private let metadataOutput = AVCaptureMetadataOutput()

  /// Flutter event sink — set by ScannerStreamHandler when Flutter listens.
  var eventSink: FlutterEventSink?

  private var isPaused = false
  private var sessionSetUp = false

  private override init() {
    super.init()
    // NOTE: We do NOT call setUpSession() here.
    // Setup is deferred to startSession() which is only called
    // after camera permission has been granted by the user.
  }

  /// Sets up the AVCaptureSession. Called lazily on first startSession().
  /// Must be called on a background thread (or it will block the main thread).
  private func setUpSession() {
    guard !sessionSetUp else { return }
    sessionSetUp = true

    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device) else { return }

    captureSession.beginConfiguration()
    if captureSession.canAddInput(input)  { captureSession.addInput(input) }
    if captureSession.canAddOutput(metadataOutput) { captureSession.addOutput(metadataOutput) }
    metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
    if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
      metadataOutput.metadataObjectTypes = [.qr]
    }
    captureSession.commitConfiguration()

    // Create the preview layer on the main thread so it can be safely
    // added to UIView layer hierarchies.
    DispatchQueue.main.async {
      let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
      layer.videoGravity = .resizeAspectFill
      self.previewLayer = layer
      // Notify any waiting preview view that the layer is now available.
      NotificationCenter.default.post(name: .scannerPreviewLayerReady, object: nil)
    }
  }

  func startSession() {
    // Set up session lazily the first time startSession() is called.
    // This ensures the AVCaptureSession is only configured after permission.
    if !sessionSetUp {
      DispatchQueue.global(qos: .userInitiated).async {
        self.setUpSession()
        // Start running after setup completes.
        if !self.captureSession.isRunning {
          self.captureSession.startRunning()
        }
      }
      return
    }
    guard !captureSession.isRunning else { return }
    DispatchQueue.global(qos: .userInitiated).async { self.captureSession.startRunning() }
  }

  func stopSession() {
    guard captureSession.isRunning else { return }
    DispatchQueue.global(qos: .userInitiated).async { self.captureSession.stopRunning() }
  }

  func pause()  { isPaused = true  }
  func resume() { isPaused = false }

  func toggleTorch() {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      device.torchMode = device.torchMode == .on ? .off : .on
      device.unlockForConfiguration()
    } catch {}
  }

  var isTorchOn: Bool { AVCaptureDevice.default(for: .video)?.torchMode == .on }

  func metadataOutput(_ output: AVCaptureMetadataOutput,
                      didOutput metadataObjects: [AVMetadataObject],
                      from connection: AVCaptureConnection) {
    guard !isPaused,
          let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          let value = object.stringValue, !value.isEmpty else { return }
    eventSink?(value)
  }
}

// MARK: - Notification names

extension Notification.Name {
  static let scannerPreviewLayerReady = Notification.Name("scannerPreviewLayerReady")
}

// MARK: - ScannerStreamHandler

final class ScannerStreamHandler: NSObject, FlutterStreamHandler {
  static let shared = ScannerStreamHandler()
  private override init() { super.init() }

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    ScannerManager.shared.eventSink = events; return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    ScannerManager.shared.eventSink = nil; return nil
  }
}

// MARK: - NativeScannerViewFactory

final class NativeScannerViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect,
              viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    return NativeScannerView(frame: frame)
  }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

// MARK: - ScannerPreviewView

/// A UIView subclass that hosts the AVCaptureVideoPreviewLayer.
///
/// The critical fix for the blank camera preview:
///   UiKitView always provides CGRect.zero as the initial frame.
///   Flutter lays out the view after the fact and calls layoutSubviews.
///   We must override layoutSubviews to resize the preview layer to match
///   the view's real bounds — otherwise the camera stays invisible.
final class ScannerPreviewView: UIView {
  private weak var previewLayer: AVCaptureVideoPreviewLayer?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    clipsToBounds = true
    attachPreviewLayer()
    // If the layer isn't ready yet (session still setting up),
    // listen for the notification and attach it when ready.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onPreviewLayerReady),
      name: .scannerPreviewLayerReady,
      object: nil
    )
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func attachPreviewLayer() {
    guard let layer = ScannerManager.shared.previewLayer,
          previewLayer == nil else { return }
    previewLayer = layer
    // Remove from any previous superlayer to avoid duplicate parenting.
    layer.removeFromSuperlayer()
    layer.frame = bounds
    self.layer.insertSublayer(layer, at: 0)
  }

  @objc private func onPreviewLayerReady() {
    attachPreviewLayer()
    // Force a layout pass so the layer gets its correct frame.
    setNeedsLayout()
    layoutIfNeeded()
  }

  /// THIS IS THE KEY FIX: every time Flutter resizes the UiKitView,
  /// layoutSubviews is called. We keep the preview layer in sync here.
  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer?.frame = bounds
  }
}

// MARK: - NativeScannerView

final class NativeScannerView: NSObject, FlutterPlatformView {
  private let previewView: ScannerPreviewView

  init(frame: CGRect) {
    previewView = ScannerPreviewView(frame: frame)
    super.init()
    // startSession is idempotent — safe to call here.
    // setUpSession() is called lazily inside startSession()
    // only after camera permission has been granted.
    ScannerManager.shared.startSession()
  }

  func view() -> UIView { previewView }
}
