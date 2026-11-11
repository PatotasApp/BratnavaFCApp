import Flutter
import UIKit
import FirebaseMessaging

// Exposto para o Dart via canal de diagnóstico; limpado a cada inicialização.
@objc class PushRegistrationState: NSObject {
  static var apnsError: String? = nil
  static var apnsReceived: Bool = false
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    PushRegistrationState.apnsError = nil
    PushRegistrationState.apnsReceived = false
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Firebase não consegue sempre capturar o APNs token via swizzling (especialmente
  // em iOS 26+). Encaminhar explicitamente garante que getAPNSToken() funcione.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    PushRegistrationState.apnsReceived = true
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Chamado quando o iOS rejeita o registro — normalmente indica entitlement
  // ausente no provisioning profile (aps-environment não autorizado).
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    PushRegistrationState.apnsError = error.localizedDescription
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PatotasImageShare") {
      ImageShareChannel.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushDiagnostics") {
      PushDiagnosticsChannel.register(messenger: registrar.messenger())
    }
  }
}

/// Expõe o estado de registro APNs ao Dart para a tela de diagnóstico de push.
enum PushDiagnosticsChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "br.com.patotasapp/push_diagnostics",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getRegistrationState" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result([
        "apnsReceived": PushRegistrationState.apnsReceived,
        "apnsError": PushRegistrationState.apnsError as Any,
      ])
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
