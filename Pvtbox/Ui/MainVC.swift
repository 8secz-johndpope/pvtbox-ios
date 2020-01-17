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
import MaterialComponents
import HS_Google_Material_Design_Icons
import AppLocker
import RealmSwift

class MainVC: UIViewController, UITabBarDelegate {
    @IBOutlet weak var tabBar: UITabBar!
    @IBOutlet weak var allFiles: UIView!
    @IBOutlet weak var recentFiles: UIView!
    @IBOutlet weak var offlineFiles: UIView!
    @IBOutlet weak var dowloads: UIView!
    @IBOutlet weak var more: UIView!
    @IBOutlet weak var allFilesButton: UITabBarItem!
    @IBOutlet weak var recentFilesButton: UITabBarItem!
    @IBOutlet weak var offlineFilesButton: UITabBarItem!
    @IBOutlet weak var downloadsButton: UITabBarItem!
    @IBOutlet weak var moreButton: UITabBarItem!
    
    var selectedView: UIView!
    var views: [UIView]!
    var navigationControllers: [FilesNC] = []
    var selectedNC: FilesNC?
    
    private var realm: Realm?
    private var ownDevice: DeviceRealm?
    private var ownDeviceSubscription: NotificationToken?
    
    override func viewDidLoad() {
        BFLog("MainVC::viewDidLoad")
        super.viewDidLoad()
        views = [allFiles, recentFiles, offlineFiles, dowloads, more]
        tabBar.selectedItem = allFilesButton
        tabBar.items?.last?.badgeValue = nil
        selectedView = allFiles
        selectedView!.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if PreferenceService.askSetPasscode {
            PreferenceService.askSetPasscode = false
            let controller = MDCAlertController(
                title: Strings.protectYourPrivacyWithPasscodeTitle,
                message: Strings.protectYourPrivacyWithPasscodeMessage)
            controller.cornerRadius = 4
            controller.messageFont = .systemFont(ofSize: 16)
            if #available(iOS 13.0, *) {
                controller.titleColor = .label
                controller.messageColor = .secondaryLabel
                controller.backgroundColor = .secondarySystemBackground
                controller.buttonTitleColor = .label
            } else {
                controller.messageColor = .darkGray
            }

            controller.addAction(MDCAlertAction(
                title: Strings.setPasscode, handler: {_ in
                    DispatchQueue.main.async {
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
                        (UIApplication.shared.delegate as? AppDelegate)?.orientations = .portrait
                        AppLocker.present(with: .create, and: appearance, completion: {
                                (UIApplication.shared.delegate as? AppDelegate)?
                                    .orientations = .allButUpsideDown
                            }, topMostViewControllerShouldBeDismissedCheck: { topMost in
                                return topMost.isKind(of: MDCAlertController.self) ||
                                    topMost.transitioningDelegate?.isKind(
                                        of: MDCDialogTransitionController.self) ?? false
                        })
                    }
            }))
            controller.addAction(MDCAlertAction(
                title: Strings.noThanks, handler: nil))
            present(controller, animated: true, completion: nil)
        }
        subscribeForNotificationsCount()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ownDeviceSubscription?.invalidate()
        ownDeviceSubscription = nil
        ownDevice = nil
        realm = nil
    }
    
    private func subscribeForNotificationsCount() {
        tabBar.items?.last?.badgeValue = nil
        if self.realm == nil {
            guard let realm = try? Realm() else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    [weak self] in self?.subscribeForNotificationsCount()
                })
                return
            }
            self.realm = realm
        }
        ownDevice = realm?.object(ofType: DeviceRealm.self, forPrimaryKey: "own")
        if ownDevice == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                [weak self] in self?.subscribeForNotificationsCount()
            })
            return
        }
        ownDeviceSubscription = ownDevice!.observe { [weak self] change in
            switch change {
            case .change(let properties):
                for property in properties {
                    if property.name == "notificationsCount" {
                        let count = self?.ownDevice?.notificationsCount ?? 0
                        self?.tabBar.items?.last?.badgeValue = count > 99 ?
                            "99+" : count > 0 ? String(count) : nil
                    }
                }
            case .error(let error):
                BFLogErr("An error occurred: %@", error)
            case .deleted:
                BFLogErr("The ownDevice object was deleted.")
            }
        }
        let count = ownDevice?.notificationsCount ?? 0
        tabBar.items?.last?.badgeValue = count > 99 ?
            "99+" : count > 0 ? String(count) : nil
    }
    
    public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        let tag = item.tag
        switchTo(tag)
    }
    
    public func openAllFiles(folder: String) {
        switchTo(0)
        tabBar.selectedItem = allFilesButton
        selectedNC?.popToRootViewController(animated: false)
        var newPresenter: FilesPresenter? = nil
        if let selectedNC = selectedNC,
            let file = realm?.objects(FileRealm.self)
                .filter("parentUuid = nil")
                .filter("name = %@", folder)
                .filter("isFolder = true")
                .first {
            newPresenter = FilesPresenter(
                rootFile: file, presenter: selectedNC.presenter)
        }
        let newVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "filesvc") as! FilesVC
        newVC.presenter = newPresenter
        newVC.tag = "AllFiles"
        selectedNC?.pushViewController(newVC, animated: false)
    }
    
    private func switchTo(_ tag: Int) {
        selectedView!.isHidden = true
        selectedNC?.disable()
        selectedView = views![tag]
        selectedNC = navigationControllers.count > tag ? navigationControllers[tag] : nil
        selectedNC?.enable()
        selectedView!.isHidden = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let controller = segue.destination as? FilesNC else { return }
        
        BFLog("MainVC::prepare for segue")
        
        let actionsController = ActionsController()
        let mode = ViewMode.values[navigationControllers.count]
        let presenter = FilesPresenter(
            mode: mode,
            actionsDelegate: actionsController,
            actionsProvider: actionsController)
        
        navigationControllers.append(controller)

        controller.presenter = presenter
        switch mode {
        case .all:
            controller.tag = "AllFiles"
            controller.enabled = true
            selectedNC = controller
        case .recent:
            controller.tag = "RecentFiles"
        case .offline:
            controller.tag = "OfflineFiles"
        case .downloads:
            controller.tag = "Downloads"
        }
    }

    override func viewDidLayoutSubviews() {
        BFLog("MainVC::viewDidLayoutSubviews")
        super.viewDidLayoutSubviews()
        tabBar.invalidateIntrinsicContentSize()
        tabBar.updateConstraintsIfNeeded()
    }
}
