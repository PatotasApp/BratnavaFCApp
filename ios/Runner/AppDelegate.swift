import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
      case "instagramStory":
        result(shareToInstagramStory(data))
      case "copyImage":
        UIPasteboard.general.image = UIImage(data: data)
        result(UIPasteboard.general.hasImages)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Abre o Instagram direto no story com a imagem de fundo. false = Instagram não instalado.
  private static func shareToInstagramStory(_ data: Data) -> Bool {
    let appId = (Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String)
      ?? Bundle.main.bundleIdentifier ?? ""
    guard let url = URL(string: "instagram-stories://share?source_application=\(appId)"),
          UIApplication.shared.canOpenURL(url) else {
      return false
    }
    UIPasteboard.general.setItems(
      [["com.instagram.sharedSticker.backgroundImage": data]],
      options: [.expirationDate: Date().addingTimeInterval(5 * 60)])
    UIApplication.shared.open(url)
    return true
  }
}
