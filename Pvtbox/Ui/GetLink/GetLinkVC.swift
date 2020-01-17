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
import RealmSwift

class GetLinkVC: UIViewController {
    @IBOutlet weak var shareInfo: UIView!
    @IBOutlet weak var shareLink: UITextView!
    @IBOutlet weak var createLink: UIButton!
    @IBOutlet weak var expireSwitch: UISwitch!
    @IBOutlet weak var passwordSwitch: UISwitch!
    @IBOutlet weak var expireToTopConstrait: NSLayoutConstraint!
    @IBOutlet weak var expireToShareInfoConstrait: NSLayoutConstraint!
    
    var file: FileRealm!
    
    private var subscription: NotificationToken?
    
    override func viewDidLoad() {
        BFLog("GetLinkVC::viewDidLoad")
        super.viewDidLoad()
        autoreleasepool {
            let realm = try? Realm()
            file = realm?.object(ofType: FileRealm.self, forPrimaryKey: file.uuid!)
        }
        subscription = file.observe({ [weak self] _ in
            self?.update()
        })
        update()
    }
    
    deinit {
        subscription?.invalidate()
        subscription = nil
    }
    
    override func viewDidLayoutSubviews() {
        BFLog("GetLinkVC::viewDidLayoutSubviews")
        super.viewDidLayoutSubviews()
        updateLayout()
    }
    
    private func update() {
        BFLog("GetLinkVC::update")
        createLink.setTitle(Strings.createLink, for: .normal)
        shareLink.text = file.shareLink
        passwordSwitch.isOn = file.shareSecured
        expireSwitch.isOn = file.shareExpire != 0
        updateLayout()
    }
    
    private func updateLayout() {
        shareInfo.isHidden = !file.isShared
        createLink.isHidden = file.isShared
        expireToTopConstrait.isActive = !file.isShared
        expireToShareInfoConstrait.isActive = file.isShared
    }

    @IBAction func createLinkClicked(_ sender: Any) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        createLink.setTitle(Strings.pleaseWait, for: .normal)
        SnackBarManager.showSnack(
            Strings.creatingLink, showNew: true, showForever: true)
        HttpClient.shared.shareEnable(
            uuid: file.uuid!, ttl: nil, password: nil,
            onSuccess: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    self?.update()
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(
                    Strings.createdLink, showNew: false, showForever: false)
            },
            onError: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    self?.update()
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(
                    String(format: "%@:\n%@",
                           Strings.operationError,
                           json?["info"].string ?? Strings.networkError),
                    showNew: false, showForever: false)
        })
    }
    
    @IBAction func expireSwitchChanged(_ sender: UISwitch) {
        if file.isShared {
            if sender.isOn && file.shareExpire == 0 {
                if PreferenceService.license == Const.freeLicense {
                    view.window?.hideAllToasts()
                    view.window?.makeToast(Strings.notAvailableForFreeLicense)
                    sender.isOn = false
                } else {
                    showExpireDialog()
                }
            } else if file.shareExpire != 0 {
                UIApplication.shared.beginIgnoringInteractionEvents()
                SnackBarManager.showSnack(
                    Strings.updatingShare, showNew: true, showForever: true)
                HttpClient.shared.shareEnable(
                    uuid: file.uuid!, ttl: nil, password: nil,
                    onSuccess: { [weak self] json in
                        DispatchQueue.main.async { [weak self] in
                            self?.update()
                            UIApplication.shared.endIgnoringInteractionEvents()
                        }
                        SnackBarManager.showSnack(
                            Strings.updatedShare, showNew: false, showForever: false)
                    },
                    onError: { [weak self] json in
                        DispatchQueue.main.async { [weak self] in
                            self?.update()
                            UIApplication.shared.endIgnoringInteractionEvents()
                        }
                        SnackBarManager.showSnack(
                            String(format: "%@:\n%@",
                                   Strings.operationError,
                                   json?["info"].string ?? Strings.networkError),
                            showNew: false, showForever: false)
                })
            }
        } else {
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.createLinkFirstly)
            sender.isOn = false
        }
    }
    
    private func showExpireDialog() {
        let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "shareexpiredialog") as! ShareExpireDialog
        dialog.switchView = expireSwitch
        dialog.file = file
        dialog.modalPresentationStyle = .popover
        let controller = dialog.popoverPresentationController!
        controller.permittedArrowDirections = .any
        controller.sourceView = expireSwitch
        controller.delegate = dialog
        self.present(dialog, animated: true, completion: nil)
    }
    
    @IBAction func passwordSwitchChanged(_ sender: UISwitch) {
        if file.isShared {
            if sender.isOn && !file.shareSecured {
                if PreferenceService.license == Const.freeLicense {
                    view.window?.hideAllToasts()
                    view.window?.makeToast(Strings.notAvailableForFreeLicense)
                    sender.isOn = false
                } else {
                    showPasswordDialog()
                }
            } else if file.shareSecured {
                UIApplication.shared.beginIgnoringInteractionEvents()
                SnackBarManager.showSnack(
                    Strings.updatingShare, showNew: true, showForever: true)
                HttpClient.shared.shareEnable(
                    uuid: file.uuid!, ttl: file.shareExpire, password: nil, keepPassword: false,
                    onSuccess: { [weak self] json in
                        DispatchQueue.main.async { [weak self] in
                            self?.update()
                            UIApplication.shared.endIgnoringInteractionEvents()
                        }
                        SnackBarManager.showSnack(
                            Strings.updatedShare, showNew: false, showForever: false)
                    },
                    onError: { [weak self] json in
                        DispatchQueue.main.async { [weak self] in
                            self?.update()
                            UIApplication.shared.endIgnoringInteractionEvents()
                        }
                        SnackBarManager.showSnack(
                            String(format: "%@:\n%@",
                                   Strings.operationError,
                                   json?["info"].string ?? Strings.networkError),
                            showNew: false, showForever: false)
                })
            }
        } else {
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.createLinkFirstly)
            sender.isOn = false
        }
    }
    
    private func showPasswordDialog() {
        let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "sharepassworddialog") as! SharePasswordDialog
        dialog.switchView = passwordSwitch
        dialog.file = file
        dialog.modalPresentationStyle = .popover
        let controller = dialog.popoverPresentationController!
        controller.permittedArrowDirections = .any
        controller.sourceView = passwordSwitch
        controller.delegate = dialog
        self.present(dialog, animated: true, completion: nil)
    }
    
    @IBAction func shareLinkClicked(_ sender: Any) {
        let activityViewController = UIActivityViewController(
            activityItems: [file.shareLink!], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    @IBAction func copyLinkClicked(_ sender: Any) {
        UIPasteboard.general.string = file.shareLink
        SnackBarManager.showSnack(Strings.linkCopied)
    }
    
    @IBAction func removeLinkClicked(_ sender: Any) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        SnackBarManager.showSnack(
            Strings.cancellingShare, showNew: true, showForever: true)
        HttpClient.shared.shareDisable(
            uuid: file.uuid!,
            onSuccess: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    self?.update()
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(
                    Strings.cancelledShare, showNew: false, showForever: false)
            },
            onError: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    self?.update()
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(
                    String(format: "%@:\n%@",
                           Strings.operationError,
                           json?["info"].string ?? Strings.networkError),
                    showNew: false, showForever: false)
        })
    }
    
}
