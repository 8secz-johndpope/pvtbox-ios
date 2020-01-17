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
import Photos
import DLRadioButton
import MaterialComponents.MDCAlertController
import BugfenderSDK
import AppLocker

class SettingsTableVC: UITableViewController {
    @IBOutlet weak var email: UILabel!
    @IBOutlet weak var license: UILabel!
    @IBOutlet weak var convertHeicSwitch: UISwitch!
    @IBOutlet weak var importCameraSwitch: UISwitch!
    @IBOutlet weak var downloadSwitch: UISwitch!
    @IBOutlet weak var statisticSwitch: UISwitch!
    @IBOutlet weak var passcodeSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        email.text = PreferenceService.email!
        license.text = Strings.licenseStrings[PreferenceService.license]
        convertHeicSwitch.isOn = PreferenceService.convertHeicEnabled
        importCameraSwitch.isOn = PreferenceService.importCameraEnabled
        downloadSwitch.isOn = PreferenceService.mediaDownloadEnabled
        statisticSwitch.isOn = PreferenceService.sendStatisticEnabled
        passcodeSwitch.isOn = AppLocker.hasPinCode()
    }
    
    private func setSelected(_ button: DLRadioButton, selected: Bool) {
        button.isSelected = selected
        button.iconColor = selected ? .orange : .lightGray
    }
    
    @IBAction func convertHeicSwitchChanged(_ sender: UISwitch) {
        PreferenceService.convertHeicEnabled = sender.isOn
    }
    
    @IBAction func importCameraSwitchChanged(_ sender: UISwitch) {
        let enabled = sender.isOn
        if enabled && !PreferenceService.importCameraEnabled {
            sender.isOn = false
            checkAuthorization()
        } else if !enabled {
            PreferenceService.importCameraEnabled = false
        }
    }
    
    private func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            cameraSync()
        case .denied:
            cameraAuthorizationDenied()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ [weak self] status in
                DispatchQueue.main.async { [weak self] in
                    if status == PHAuthorizationStatus.authorized {
                        self?.cameraSync()
                    } else {
                        self?.cameraAuthorizationDenied()
                    }
                }
            })
        case .restricted:
            cameraAuthorizationDenied()
        default:
            break
        }
    }
    
    private func cameraSync() {
        if PvtboxService.onlineDevicesCount > 1 {
            DispatchQueue.main.async { [weak self] in
                PreferenceService.importCameraEnabled = true
                self?.importCameraSwitch.setOn(true, animated: true)
                PvtboxService.syncCamera()
            }
        } else {
            allNodesOfflineAlert()
        }
    }
    
    private func allNodesOfflineAlert() {
        let controller = MDCAlertController(
            title: Strings.cameraSyncAlertTitle,
            message: Strings.cameraSyncAlertMessage)
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
            title: Strings.ok, handler: { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    PreferenceService.importCameraEnabled = true
                    self?.importCameraSwitch.setOn(true, animated: true)
                    PvtboxService.syncCamera()
                }
        }))
        controller.addAction(MDCAlertAction(
            title: Strings.cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    private func cameraAuthorizationDenied() {
        let controller = MDCAlertController(
            title: Strings.cameraAuthorizationDeniedAlertTitle,
            message: Strings.cameraAuthorizationDeniedAlertMessage)
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
            title: Strings.settings, handler: { _ in
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(
                        settingsUrl, options: [:], completionHandler: nil)
                }
        }))
        controller.addAction(MDCAlertAction(
            title: Strings.cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    @IBAction func downloadSwitchChanged(_ sender: UISwitch) {
        PreferenceService.mediaDownloadEnabled = sender.isOn
    }
    
    @IBAction func statisticSwitchChanged(_ sender: UISwitch) {
        let enabled = sender.isOn
        PreferenceService.sendStatisticEnabled = enabled
        if enabled {
            Bugfender.activateLogger(Bugfender.key)
            //Bugfender.enableUIEventLogging()
            Bugfender.enableCrashReporting()
        } else {
            Bugfender.setForceEnabled(false)
        }
    }
    @IBAction func passcodeSwitchChanged(_ sender: Any) {
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
        
        let almode: ALMode = AppLocker.hasPinCode() ? .deactive : .create
        AppLocker.present(
            with: almode, and: appearance, completion: { [weak self] in
                (UIApplication.shared.delegate as? AppDelegate)?.orientations = .allButUpsideDown
                self?.passcodeSwitch.isOn = AppLocker.hasPinCode()
            }, topMostViewControllerShouldBeDismissedCheck: { topMost in
            return topMost.isKind(of: MDCAlertController.self) ||
                topMost.transitioningDelegate?.isKind(
                    of: MDCDialogTransitionController.self) ?? false
        })
    }
}
