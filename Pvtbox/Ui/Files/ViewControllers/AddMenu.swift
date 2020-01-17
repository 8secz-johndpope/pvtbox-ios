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
import MobileCoreServices
import RealmSwift
import Photos
import MaterialComponents.MDCAlertController

class AddMenu: UITableViewController {

    @IBOutlet var icons: [UIImageView]!
    @IBOutlet var labels: [UILabel]!
    @IBOutlet weak var cameraSwitch: UISwitch!
    
    var delegate: MenuDelegate!
    var sendFileDelegate: SendFileDocumentPickerDelegate!
    var viewPresenter: ViewPresenter!
    var realm: Realm?
    weak var root: FileRealm?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        
        setActionsEnabled(!PvtboxService.isProcessingOperation())
        cameraSwitch.isOn = PreferenceService.importCameraEnabled
    }
    
    private func setActionsEnabled(_ enabled: Bool) {
        for icon in icons {
            if #available(iOS 13.0, *) {
                icon.tintColor = enabled ? .secondaryLabel : .quaternaryLabel
            } else {
                icon.tintColor = enabled ? .darkGray : .lightGray
            }
        }
        for label in labels {
            if #available(iOS 13.0, *) {
                label.textColor = enabled ? .label : .quaternaryLabel
            } else {
                label.textColor = enabled ? .darkText : .lightGray
            }
        }
        cameraSwitch.isEnabled = enabled
        
        Timer.scheduledTimer(
            withTimeInterval: 1.0, repeats: false, block: { [weak self] timer in
                timer.invalidate()
                self?.setActionsEnabled(!PvtboxService.isProcessingOperation())
        })
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let isProcessingOperation = PvtboxService.isProcessingOperation()
        if isProcessingOperation {
            self.view.window?.hideAllToasts()
            self.view.window?.makeToast(Strings.actionDisabled)
            return
        }
        
        var vc: UIViewController? = nil
        switch indexPath.item {
        case 0:
            let picker = UIDocumentPickerViewController(
                documentTypes: [kUTTypeItem as String], in: .import)
            picker.delegate = sendFileDelegate
            if #available(iOS 11.0, *) {
                picker.allowsMultipleSelection = true
            }
            vc = picker
        case 1:
            let picker = UIImagePickerController()
            picker.delegate = sendFileDelegate
            picker.mediaTypes = [kUTTypeVideo as String,
                                 kUTTypeMovie as String,
                                 kUTTypeImage as String]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = false
            picker.sourceType = .photoLibrary
            vc = picker
        case 2:
            return
        case 3:
            let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "inputDialog") as! InputDialog
            dialog.setup(
                type: .createFolder,
                text: nil,
                realm: realm, root: root,
                onConfirmedInput: delegate?.menuDelegateCreateFolder,
                onCancelled: delegate?.menuDelegateDismiss)
            vc = dialog
        case 4,5:
            let picker = UIImagePickerController()
            picker.delegate = delegate
            picker.mediaTypes = [kUTTypeVideo as String,
                                 kUTTypeMovie as String,
                                 kUTTypeImage as String]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = false
            picker.sourceType = indexPath.item == 4 ? .photoLibrary : .camera
            vc = picker
        case 6:
            let picker = UIDocumentPickerViewController(
                documentTypes: [kUTTypeItem as String], in: .import)
            picker.delegate = delegate
            if #available(iOS 11.0, *) {
                picker.allowsMultipleSelection = true
            }
            vc = picker
        case 7:
            importCameraSwitchChanged()
            return
        case 8:
            return
        case 9:
            let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "inputDialog") as! InputDialog
            dialog.setup(
                type: .insertLink,
                text: nil,
                realm: realm, root: root,
                onConfirmedInput: { link in
                    PvtboxService.setShareUrl(URL(string: link)!)
                },
                onCancelled: delegate?.menuDelegateDismiss)
            vc = dialog
        default:
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.notImplemented)
        }
        self.dismiss(animated: true, completion: nil)
        if vc != nil {
            self.viewPresenter.present(vc!)
        }
    }
    
    func importCameraSwitchChanged() {
        if PreferenceService.importCameraEnabled {
            PreferenceService.importCameraEnabled = false
            cameraSwitch.setOn(false, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }
        } else {
            checkAuthorization()
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
                self?.cameraSwitch.setOn(true, animated: true)
                PvtboxService.syncCamera()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
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
                    self?.cameraSwitch.setOn(true, animated: true)
                    PvtboxService.syncCamera()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.dismiss(animated: true, completion: nil)
                    }
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
}
