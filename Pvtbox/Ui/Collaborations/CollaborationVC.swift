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
import IQKeyboardManagerSwift
import JASON

class CollaborationVC: UIViewController,
    ColleagueCardDelegate, ColleagueMenuDelegate,
    UIPickerViewDataSource, UIPickerViewDelegate,
    UITableViewDataSource, UITableViewDelegate {
    static let displayPermissions = [Strings.canView, Strings.canEdit]
    static let permissions = ["view", "edit"]
    
    @IBOutlet weak var addColleagueButton: UIButton!
    @IBOutlet weak var addColleagueInput: UIView!
    @IBOutlet weak var addColleagueInputEmail: MDCTextField!
    @IBOutlet weak var addColleagueInputPemission: UIPickerView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableToBottom: NSLayoutConstraint!
    @IBOutlet weak var tableToButton: NSLayoutConstraint!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var inputController: MDCTextInputControllerLegacyDefault!
    private let refreshControl = UIRefreshControl()
    
    var file: FileRealm!
    
    private var colleagues = [JSON]()
    private var isOwner = true
    private var collaborationId: Int? = nil
    private var ownerId: Int? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        inputController = MDCTextInputControllerLegacyDefault(
            textInput: addColleagueInputEmail)
        inputController.activeColor = .orange
        inputController.floatingPlaceholderActiveColor = .orange
        inputController.textInputFont = .systemFont(ofSize: 20)
        inputController.inlinePlaceholderFont = .systemFont(ofSize: 20)
        if #available(iOS 13.0, *) {
            inputController.inlinePlaceholderColor = .quaternaryLabel
            addColleagueInputEmail.textColor = .label
        }
        refreshControl.tintColor = .orange
        refreshControl.addTarget(
            self, action: #selector(refreshInfo), for: .valueChanged)
        tableView.addSubview(refreshControl)
        tableView.alwaysBounceVertical = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enable = true
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = false
        activityIndicator.stopAnimating()
        refreshControl.endRefreshing()
    }

    @IBAction func closeAddColleagueInputClicked(_ sender: Any) {
        addColleagueInput.isHidden = true
        addColleagueButton.backgroundColor = .lightGray
    }
    
    @IBAction func addColleagueClicked(_ sender: Any) {
        inputController.setErrorText(nil, errorAccessibilityValue: nil)
        if addColleagueInput.isHidden {
            addColleagueInputEmail.text = nil
            addColleagueButton.backgroundColor = .orange
            addColleagueInput.isHidden = false
        } else {
            addColleague()
        }
    }
    
    private func refresh() {
        activityIndicator.startAnimating()
        refreshControl.sendActions(for: .valueChanged)
    }
    
    @objc private func refreshInfo() {
        BFLog("CollaborationVC::refreshInfo")
        HttpClient.shared.collaborationInfo(
            uuid: file.uuid!,
            onSuccess: { [weak self] json in
                let data = json["data"].json
                let isOwner = data["collaboration_is_owner"].bool ?? true
                self?.isOwner = isOwner
                self?.colleagues = data["colleagues"].jsonArrayValue
                self?.ownerId = data["collaboration_owner"].int
                DispatchQueue.main.async { [weak self] in
                    self?.addColleagueButton.isHidden = !isOwner
                    self?.tableToBottom.isActive = !isOwner
                    self?.tableToButton.isActive = isOwner
                    self?.tableView.reloadData()
                    self?.refreshControl.endRefreshing()
                    self?.activityIndicator.stopAnimating()
                }
            },
            onError: { [weak self] json in
            DispatchQueue.main.async { [weak self] in
                self?.refreshControl.endRefreshing()
            }
        })
    }
    
    private func addColleague() {
        guard let emailText = addColleagueInputEmail.text?.trimmingCharacters(in: .whitespaces),
            !emailText.isEmpty else {
                inputController?.setErrorText(Strings.emailEmpty, errorAccessibilityValue: nil)
                return
        }
        if !EmailValidator.isValid(emailText) {
            inputController?.setErrorText(Strings.emailWrong, errorAccessibilityValue: nil)
            return
        }
        let permission = CollaborationVC.permissions[
            addColleagueInputPemission.selectedRow(inComponent: 0)]
        
        UIApplication.shared.beginIgnoringInteractionEvents()
        SnackBarManager.showSnack(
            Strings.addingCollabColleague, showNew: true, showForever: true)
        HttpClient.shared.colleagueAdd(
            uuid: file.uuid!, email: emailText, permission: permission,
            onSuccess: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    UIApplication.shared.endIgnoringInteractionEvents()
                    self?.refresh()
                    self?.addColleagueButton.backgroundColor = .lightGray
                    self?.addColleagueInput.isHidden = true
                }
                SnackBarManager.showSnack(
                    Strings.addedCollabColleague, showNew: false, showForever: false)
            },
            onError: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    UIApplication.shared.endIgnoringInteractionEvents()
                    self?.refresh()
                    self?.addColleagueButton.backgroundColor = .lightGray
                    self?.addColleagueInput.isHidden = true
                }
                SnackBarManager.showSnack(
                    String(format: "%@:\n%@",
                           Strings.operationError,
                           json?["info"].string ?? Strings.networkError),
                    showNew: false, showForever: false)
        })
    }
    
    func numberOfComponents(in: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_: UIPickerView, numberOfRowsInComponent: Int) -> Int {
        return CollaborationVC.displayPermissions.count
    }
    
    func pickerView(
        _: UIPickerView, viewForRow row: Int, forComponent: Int,
        reusing view: UIView?) -> UIView {
        var pickerLabel: UILabel? = (view as? UILabel)
        if pickerLabel == nil {
            pickerLabel = UILabel()
            pickerLabel?.font = .systemFont(ofSize: 16)
            pickerLabel?.textAlignment = .center
            pickerLabel?.textColor = UIColor.orange
        }
        pickerLabel?.text = CollaborationVC.displayPermissions[row]
        
        return pickerLabel!
    }
        
    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return colleagues.count
    }
    
    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let card = tableView.dequeueReusableCell(
            withIdentifier: "colleagueCard", for: indexPath) as! ColleagueCard
        card.displayContent(
            colleagues[indexPath.item], collaborationOwner: ownerId!,
            index: indexPath.item, delegate: self)
        return card
    }
    
    func colleagueCard(_ card: ColleagueCard, permissionClicked: Any) {
        if !isOwner && !card.isSelf { return }
        let menu = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "colleagueMenu") as! ColleagueMenu
        menu.isOwner = isOwner
        menu.colleague = card.colleague
        menu.delegate = self
        let bottomSheet = MDCBottomSheetController(contentViewController: menu)
        present(bottomSheet, animated: true, completion: nil)
    }
    
    func colleagueMenu(_ colleague: ColleagueMenu, changeEditPermission canEditAfterChange: Bool) {
        let info = colleague.colleague
        UIApplication.shared.beginIgnoringInteractionEvents()
        SnackBarManager.showSnack(
            Strings.updatingCollabColleaguePermission,
            showNew: true, showForever: true)
        HttpClient.shared.colleagueEdit(
            uuid: file.uuid!, id: info!["colleague_id"].int!,
            permission: canEditAfterChange ? "edit" : "view",
            onSuccess: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    UIApplication.shared.endIgnoringInteractionEvents()
                    self?.refresh()
                }
                SnackBarManager.showSnack(
                    Strings.updatedCollabColleaguePermission,
                    showNew: false, showForever: false)
            },
            onError: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    UIApplication.shared.endIgnoringInteractionEvents()
                    self?.refresh()
                }
                SnackBarManager.showSnack(
                    String(format: "%@:\n%@",
                           Strings.operationError,
                           json?["info"].string ?? Strings.networkError),
                    showNew: false, showForever: false)
        })
    }
    
    func colleagueMenu(_ colleague: ColleagueMenu, remove isSelf: Bool) {
        let info = colleague.colleague!
        let alert = MDCAlertController(
            title: Strings.areYouSure,
            message: isSelf && isOwner ? Strings.deleteCollaborationAlertMessage : isSelf ? Strings.quitCollaborationAlertMessage : String(format: Strings.colleagueRemoveAlertMessage, info["email"].stringValue))
        alert.cornerRadius = 4
        alert.messageFont = .systemFont(ofSize: 16)
        if #available(iOS 13.0, *) {
            alert.titleColor = .label
            alert.messageColor = .secondaryLabel
            alert.backgroundColor = .secondarySystemBackground
            alert.buttonTitleColor = .label
        } else {
            alert.messageColor = .darkGray
        }
        alert.addAction(MDCAlertAction(
            title: Strings.yes, handler: { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.removeFromCollaboration(info, isSelf)
                }
        }))
        alert.addAction(MDCAlertAction(
            title: Strings.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func removeFromCollaboration(_ info: JSON, _ isSelf: Bool) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        SnackBarManager.showSnack(
            isSelf ? Strings.quittingCollaboration : Strings.removingCollabColleague,
            showNew: true, showForever: true)
        if isSelf {
            if isOwner {
                HttpClient.shared.collaborationCancel(
                    uuid: file.uuid!,
                    onSuccess: { [weak self] json in
                        DispatchQueue.main.async { [weak self] in
                            UIApplication.shared.endIgnoringInteractionEvents()
                            self?.navigationController?.popViewController(animated: true)

                        }
                        SnackBarManager.showSnack(
                            Strings.quittedCollaboration, showNew: false, showForever: false)
                    },
                    onError: { [weak self] json in
                        DispatchQueue.main.async { [weak self] in
                            UIApplication.shared.endIgnoringInteractionEvents()
                            self?.refresh()
                        }
                        SnackBarManager.showSnack(
                            String(format: "%@:\n%@",
                                   Strings.operationError,
                                   json?["info"].string ?? Strings.networkError),
                            showNew: false, showForever: false)
                })
            } else {
                HttpClient.shared.deleteFolder(
                    eventUuid: md5(fromString: UUID().uuidString),
                    uuid: file.uuid!,
                    lastEventId: file.eventId,
                    onSuccess: { [weak self] json in
                        if let uuid = self?.file?.uuid {
                            DataBaseService().deleteFile(byUuid: uuid)
                        }
                        DispatchQueue.main.async { [weak self] in
                            UIApplication.shared.endIgnoringInteractionEvents()
                            self?.navigationController?.popViewController(animated: true)
                        }
                        SnackBarManager.showSnack(
                            Strings.quittedCollaboration, showNew: false, showForever: false)
                    },
                    onError: { [weak self] json in
                        if json?["errcode"].string == "FS_SYNC_NOT_FOUND" ||
                            json?["errcode"].string == "FS_SYNC_PARENT_NOT_FOUND" {
                            DispatchQueue.main.async { [weak self] in
                                self?.navigationController?.popViewController(animated: true)
                            }
                            SnackBarManager.showSnack(
                                Strings.quittedCollaboration, showNew: false, showForever: false)
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                self?.refresh()
                            }
                            SnackBarManager.showSnack(
                                String(format: "%@:\n%@",
                                       Strings.operationError,
                                       json?["info"].string ?? Strings.networkError),
                                showNew: false, showForever: false)
                        }
                        DispatchQueue.main.async {
                            UIApplication.shared.endIgnoringInteractionEvents()
                        }
                })
            }
        } else {
            HttpClient.shared.colleagueDelete(
                uuid: file.uuid!, id: info["colleague_id"].int!,
                onSuccess: { [weak self] json in
                    DispatchQueue.main.async { [weak self] in
                        UIApplication.shared.endIgnoringInteractionEvents()
                        self?.refresh()
                    }
                    SnackBarManager.showSnack(
                        Strings.removedCollabColleague, showNew: false, showForever: false)
                },
                onError: { [weak self] json in
                    DispatchQueue.main.async { [weak self] in
                        UIApplication.shared.endIgnoringInteractionEvents()
                        self?.refresh()
                    }
                    SnackBarManager.showSnack(
                        String(format: "%@:\n%@",
                               Strings.operationError,
                               json?["info"].string ?? Strings.networkError),
                        showNew: false, showForever: false)
            })
        }
    }
}
