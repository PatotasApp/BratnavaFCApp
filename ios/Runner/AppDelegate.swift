import Flutter
import UIKit
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Firebase não consegue sempre capturar o APNs token via swizzling (especialmente
  // em iOS 26+). Encaminhar explicitamente garante que getAPNSToken() funcione.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PatotasImageShare") {
      ImageShareChannel.register(messenger: registrar.messenger())
    }
  }
}

/// Compartilhar imagem gerada no app (lib/core/share/image_share.dart).
/// O Dart grava o PNG no cache e manda o caminho.
enum ImageShareChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "br.com.patotasapp/image_share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let data = FileManager.default.contents(atPath: path) else {
        result(FlutterError(code: "args", message: "Imagem não encontrada.", details: nil))
        return
      }
      switch call.method {
      case "copyImage":
        UIPasteboard.general.image = UIImage(data: data)
        result(UIPasteboard.general.hasImages)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
