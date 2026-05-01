import Flutter
import UIKit
import yandex_login_sdk

class SceneDelegate: FlutterSceneDelegate {

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    var handled = false
    for ctx in URLContexts {
      if YandexLoginSdkPlugin.handle(openURL: ctx.url) { handled = true }
    }
    if !handled {
      super.scene(scene, openURLContexts: URLContexts)
    }
  }
}
