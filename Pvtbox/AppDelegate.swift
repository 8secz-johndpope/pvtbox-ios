/**
*  
*  Pvtbox. Fast and secure file transfer & sync directly across your devices. 
*  Copyright © 2020  Pb Private Cloud Solutions Ltd. 
*  
*  Licensed under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License.
*  You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*  
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
*  
**/

import UIKit
import Toast_Swift
@_exported import BugfenderSDK
import UserNotifications
import AppLocker
import BackgroundTasks
import MaterialComponents.MaterialDialogs

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var wasInactive = true
    var orientations: UIInterfaceOrientationMask = .allButUpsideDown
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BFLog("AppDelegate::didFinishLaunchingWithOptions")
        if PreferenceService.sendStatisticEnabled {
            Bugfender.activateLogger(Bugfender.key)
            //Bugfender.enableUIEventLogging()
            Bugfender.enableCrashReporting()
        }
        signal(SIGPIPE, SIG_IGN)
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge], completionHandler: { _,_ in })
        
        PvtboxService.registerBackgroundTask13()
        
        if PreferenceService.isLoggedIn ?? false && !(PreferenceService.userHash?.isEmpty ?? true) {
            PvtboxService.start()
        } else {
            if PreferenceService.firstLaunch {
                BFLog("first launch, show intro screen")
                let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "introVC") as! IntroVC
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.window?.rootViewController = vc
                PreferenceService.firstLaunch = false
            } else {
                BFLog("not logged in, show login screen")
                let loginVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "loginvc") as! LoginVC
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.window?.rootViewController = loginVC
            }
        }
        if #available(iOS 13.0, *) {
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor : UIColor.label,
            ]
        } else {
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor : UIColor.darkGray,
            ]
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        BFLog("AppDelegate::applicationWillResignActive")
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BFLog("AppDelegate::applicationDidEnterBackground")
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        wasInactive = true
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
        PvtboxService.scheduleBackgroundTask()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        BFLog("AppDelegate::applicationWillEnterForeground")
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        if PreferenceService.isLoggedIn ?? false
                && !(PreferenceService.userHash?.isEmpty ?? true)
                && !PvtboxService.isRunning() {
            PvtboxService.start()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        BFLog("AppDelegate::applicationDidBecomeActive")
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if wasInactive && AppLocker.hasPinCode() &&
            PreferenceService.isLoggedIn ?? false &&
            !(PreferenceService.userHash?.isEmpty ?? true) {
            var appearance = ALAppearance()
            appearance.image = UIImage(named: "logo")!
            if #available(iOS 13.0, *) {
                appearance.backgroundColor = .systemBackground
            } else {
                appearance.backgroundColor = .white
            }
            appearance.foregroundColor = .orange
            appearance.hightlightColor = .orange
            appearance.pincodeType = .numeric
            appearance.isSensorsEnabled = true
            orientations = .portrait
            BFLog("AppDelegate::applicationDidBecomeActive present AppLocker")
            AppLocker.present(with: .validate, and: appearance, completion: { [weak self] in
                    self?.orientations = .allButUpsideDown
                }, topMostViewControllerShouldBeDismissedCheck: { topMost in
                    return topMost.isKind(of: MDCAlertController.self) ||
                        topMost.transitioningDelegate?.isKind(
                            of: MDCDialogTransitionController.self) ?? false
            })
        }
        if wasInactive {
            wasInactive = false
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        BFLog("AppDelegate::applicationWillTerminate")
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        PvtboxService.stop()
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
        PvtboxService.scheduleBackgroundTask()
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return orientations
    }
    
    func application(
        _ app: UIApplication, open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        BFLog("AppDelegate::open url: %@", url.path)
        if url.host == "share_extension" {
            PvtboxService.setNeedCheckGroup()
        } else {
            if wasInactive && AppLocker.hasPinCode() &&
                PreferenceService.isLoggedIn ?? false &&
                !(PreferenceService.userHash?.isEmpty ?? true) {
                var appearance = ALAppearance()
                appearance.image = UIImage(named: "logo")!
                if #available(iOS 13.0, *) {
                    appearance.backgroundColor = .systemBackground
                } else {
                    appearance.backgroundColor = .white
                }
                appearance.foregroundColor = .orange
                appearance.hightlightColor = .orange
                appearance.pincodeType = .numeric
                appearance.isSensorsEnabled = true
                orientations = .portrait
                BFLog("AppDelegate::applicationDidBecomeActive present AppLocker")
                AppLocker.present(with: .validate, and: appearance, completion: { [weak self] in
                        self?.orientations = .allButUpsideDown
                        PvtboxService.setShareUrl(url)
                    }, topMostViewControllerShouldBeDismissedCheck: { topMost in
                        return topMost.isKind(of: MDCAlertController.self) ||
                            topMost.transitioningDelegate?.isKind(
                                of: MDCDialogTransitionController.self) ?? false
                })
            } else {
                PvtboxService.setShareUrl(url)
            }
            wasInactive = false
        }
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent
        notification: UNNotification, withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // show alert while app is running in foreground
        return completionHandler(UNNotificationPresentationOptions.alert)
    }
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            BFLog("Device shaken")
            guard let topMost = rootViewController?.topMostViewController(),
                !topMost.isKind(of: SupportVC.self) else {
                    return
            }
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "supportVC") as! SupportVC
            vc.enableIQKeyboard = false
            vc.modalPresentationStyle = .popover
            let controller = vc.popoverPresentationController!
            controller.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
            controller.sourceView = topMost.view
            controller.sourceRect = CGRect(
                x: topMost.view.bounds.midX, y: topMost.view.bounds.maxY,
                width: 0, height: 0)
            controller.delegate = (vc as UIPopoverPresentationControllerDelegate)
            topMost.present(vc, animated: true, completion: nil)
        }
    }
}
