import Flutter
import UIKit
import LocalAuthentication
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    if let controller = window?.rootViewController as? FlutterViewController {
      // 1. Setup Gallery Channel
      let galleryChannel = FlutterMethodChannel(name: "com.example.anti_counterfeit_app/gallery",
                                                binaryMessenger: controller.binaryMessenger)
      galleryChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "saveImage" {
          guard let args = call.arguments as? [String: Any],
                let bytes = args["bytes"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "Image bytes are null", details: nil))
            return
          }
          
          let image = UIImage(data: bytes.data)
          if let image = image {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            result(true)
          } else {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
      
      // 2. Setup Biometric Channel
      let biometricChannel = FlutterMethodChannel(name: "com.example.anti_counterfeit_app/biometrics",
                                                  binaryMessenger: controller.binaryMessenger)
      biometricChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "authenticate" {
          let context = LAContext()
          var error: NSError?
          
          if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access your private key"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
              DispatchQueue.main.async {
                if success {
                  result(true)
                } else {
                  result(false)
                }
              }
            }
          } else {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
