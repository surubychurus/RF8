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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIconPlugin") {
      AppIconPlugin.register(with: registrar)
    }
  }
}

/// Cambia el ícono de la app (íconos alternativos definidos en Assets.xcassets
/// y en ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES).
final class AppIconPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ar.rf8.app/app_icon", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AppIconPlugin(), channel: channel)
  }

  // Mapea el nombre de iOS al id de la variante de Flutter (AppIconVariant.id).
  private func variantId(for iconName: String?) -> String {
    guard let name = iconName, name.hasPrefix("AppIcon-") else { return "Default" }
    return String(name.dropFirst("AppIcon-".count))
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getIcon":
      result(variantId(for: UIApplication.shared.alternateIconName))
    case "setIcon":
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "unsupported", message: "Íconos alternativos no soportados", details: nil))
        return
      }
      let args = call.arguments as? [String: Any]
      let iosName = args?["iosName"] as? String
      UIApplication.shared.setAlternateIconName(iosName) { error in
        if let error = error {
          result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
