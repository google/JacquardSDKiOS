// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import CoreBluetooth
import JacquardSDK
import MaterialComponents
import SVProgressHUD
import UIKit

/// The shared `JacquardManager` instance.
///
/// In most apps you will want to use the state-restoration capable initialization method.
var sharedJacquardManager: JacquardManager = {
  // If we want to set the global logger, it must be done before instantiating
  // JacquardManagerImplementation.
  let logger = PrintLogger(
    logLevels: [.info, .warning, .error, .assertion, .preconditionFailure],
    includeSourceDetails: true,
    includeFileLogs: true
  )
  setGlobalJacquardSDKLogger(logger)

  let options = [CBCentralManagerOptionRestoreIdentifierKey: "JacquardSDKRestoreIdentifier"]

  // Instructions on how to obtain an API Key are at
  // https://google.github.io/JacquardSDKiOS/cloud-api-terms
  let config = SDKConfig(apiKey: "REPLACE_WITH_API_KEY")
  let jacquardManager = JacquardManagerImplementation(
    options: options, config: config
  ) { peripheralIdentifiers in
    print(
      "The application can take any actions required to restore connections for peripheral identifiers \(peripheralIdentifiers)"
    )
  }
  return jacquardManager
}()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let rootViewController: UIViewController
    // Check if we already have a tag paired & onboarded, else start onboarding.
    if Preferences.knownTags.isEmpty {
      rootViewController = ScanningViewController()
    } else {
      rootViewController = DashboardViewController()
    }
    let navigationController = UINavigationController(rootViewController: rootViewController)

    // Customize navigation appearance.
    UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
    UINavigationBar.appearance().backgroundColor = .clear
    UINavigationBar.appearance().isTranslucent = true
    let backButtonImage = UIImage(named: "back")
    UINavigationBar.appearance().backIndicatorImage = backButtonImage
    UINavigationBar.appearance().backIndicatorTransitionMaskImage = backButtonImage
    UINavigationBar.appearance().tintColor = .black
    UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(
      UIOffset(horizontal: -1000.0, vertical: 0.0), for: .default)

    window = UIWindow(frame: UIScreen.main.bounds)
    MDCSnackbarManager.default.setPresentationHostView(window)
    window?.rootViewController = navigationController
    window?.makeKeyAndVisible()

    let buildInfoGestureRecognizer = UITapGestureRecognizer(
      target: self,
      action: #selector(showBuildInfo(_:)))
    buildInfoGestureRecognizer.numberOfTapsRequired = 2
    buildInfoGestureRecognizer.numberOfTouchesRequired = 2
    window?.addGestureRecognizer(buildInfoGestureRecognizer)

    SVProgressHUD.setDefaultMaskType(.black)

    return true
  }

  @objc func showBuildInfo(_ sender: UIGestureRecognizer) {

    let message = "SDK Version: \(JacquardSDKVersion.versionString)"
    let alert = UIAlertController(title: "Build Info", message: message, preferredStyle: .alert)

    if let url = Bundle.main.url(forResource: "BuildHash", withExtension: "json"),
      let json = try? JSONSerialization.jsonObject(with: Data(contentsOf: url), options: [])
        as? [String: String],
      let buildHash = json["buildHash"],
      let buildDate = json["buildDate"]
    {
      alert.message?.append("\nBuild: \(buildHash)\n\(buildDate)")
    }

    let copyMessage = alert.message

    alert.addAction(
      UIAlertAction(
        title: "Copy", style: .default,
        handler: { _ in
          UIPasteboard.general.string = copyMessage
        }))
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

    let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
    keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
  }

  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }

}

extension AppDelegate {

  // Top most view controller in window hirarchy.
  class var topViewController: UIViewController? {
    let keyWindow = UIApplication.shared.windows.filter { $0.isKeyWindow }.first
    var topController = keyWindow?.rootViewController
    while let presentedViewController = topController?.presentedViewController {
      topController = presentedViewController
    }
    return topController
  }
}
