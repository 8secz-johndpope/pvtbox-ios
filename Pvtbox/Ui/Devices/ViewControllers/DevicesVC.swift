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
import JASON
import MaterialComponents.MDCBottomSheetController

class DevicesVC: UITableViewController {
    @IBOutlet weak var devicesCount: UILabel!
    
    private var detailsUpdateOperation: DispatchWorkItem!
    private weak var details: MDCAlertController?
    private var setupDetailsInfoTask: DispatchWorkItem?
    let controller = DevicesController()
    var manageDeviceMenu: ManageDeviceMenu?
    
    private let dataBaseService = DataBaseService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        controller.dataLoaded = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.devicesCount.text = String(
                format: "      %@: %d/%d",
                Strings.currentDevices,
                strongSelf.controller.onlineDevicesCount, strongSelf.controller.deviceCount)
            strongSelf.tableView.reloadData()
            strongSelf.setupDetailsInfo()
        }
        controller.dataChanged = { [weak self] deletions, insertions, modifications in
            guard let strongSelf = self else { return }
            strongSelf.devicesCount.text = String(
                format: "      %@: %d/%d",
                Strings.currentDevices,
                strongSelf.controller.onlineDevicesCount, strongSelf.controller.deviceCount)
            strongSelf.tableView.reloadData()
            strongSelf.setupDetailsInfo()
        }
    }

    func showDetails() {
        let detailsAlert = MDCAlertController()
        details = detailsAlert
        detailsAlert.cornerRadius = 4
        detailsAlert.messageFont = .systemFont(ofSize: 16)
        if #available(iOS 13.0, *) {
            detailsAlert.titleColor = .label
            detailsAlert.messageColor = .secondaryLabel
            detailsAlert.backgroundColor = .secondarySystemBackground
            detailsAlert.buttonTitleColor = .label
        } else {
            detailsAlert.messageColor = .darkGray
        }
        detailsAlert.titleColor = .lightGray
        detailsAlert.titleFont = .boldSystemFont(ofSize: 20)
        setupDetailsInfo()
        present(detailsAlert, animated: true, completion: nil)
    }
    
    func removeNode(_ id: String, _ name: String) {
        let alert = MDCAlertController(
            title: Strings.areYouSure,
            message: String(format: Strings.deviceRemoveAlertMessage, name))
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
                    self?.removeNode(id)
                }
        }))
        alert.addAction(MDCAlertAction(
            title: Strings.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func removeNode(_ id: String) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        SnackBarManager.showSnack(Strings.removingNode, showNew: true, showForever: true)
        HttpClient.shared.hideNode(
            id: id,
            onSuccess: { [weak self] response in
                DispatchQueue.main.async {
                    self?.controller.deleteNode(id)
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(Strings.removedNode, showNew: false, showForever: false)
        },
            onError: { error in
                SnackBarManager.showSnack(
                    error?["info"].string ?? Strings.operationError,
                    showNew: false, showForever: false)
                DispatchQueue.main.async {
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
        })
    }
    
    func logout(_ isOwn: Bool, _ id: String) {
        if isOwn {
            PvtboxService.logout(byUserAction: true)
        } else {
            UIApplication.shared.beginIgnoringInteractionEvents()
            SnackBarManager.showSnack(Strings.sendingRemoteAction, showNew: true, showForever: true)
            HttpClient.shared.logoutNode(
                id: id,
                onSuccess: { [weak self] response in
                    self?.dataBaseService.updateDeviceLogoutInProgress(id)
                    SnackBarManager.showSnack(Strings.remoteActionSent, showNew: false, showForever: false)
                    DispatchQueue.main.async {
                        UIApplication.shared.endIgnoringInteractionEvents()
                    }
            },
                onError: { [weak self] error in
                    self?.onError(id, error)
            })
        }
    }
    
    func logoutAndWipe(_ isOwn: Bool, _ id: String, _ name: String) {
        let alert = MDCAlertController(
            title: Strings.areYouSure,
            message: String(format: Strings.deviceWipeAlertMessage, name))
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
                    self?.wipe(isOwn, id)
                }
        }))
        alert.addAction(MDCAlertAction(
            title: Strings.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func wipe(_ isOwn: Bool, _ id: String) {
        if isOwn {
            PvtboxService.logout(byUserAction: true, wipe: true)
        } else {
            UIApplication.shared.beginIgnoringInteractionEvents()
            SnackBarManager.showSnack(Strings.sendingRemoteAction, showNew: true, showForever: true)
            HttpClient.shared.wipeNode(
                id: id,
                onSuccess: { [weak self] response in
                    self?.dataBaseService.updateDeviceWipeInProgress(id)
                    SnackBarManager.showSnack(Strings.remoteActionSent, showNew: false, showForever: false)
                    DispatchQueue.main.async {
                        UIApplication.shared.endIgnoringInteractionEvents()
                    }
            },
                onError: { [weak self] error in
                    self?.onError(id, error)
            })
        }
    }
    
    private func onError(_ id: String, _ error: JSON?) {
        SnackBarManager.showSnack(
            error?["info"].string ?? Strings.operationError,
            showNew: false, showForever: false)
        DispatchQueue.main.async {
            UIApplication.shared.endIgnoringInteractionEvents()
        }
        if let code = error?["errcode"].string {
            switch code {
            case "NODE_LOGOUT_EXIST":
                dataBaseService.updateDeviceLogoutInProgress(id)
            case "NODE_WIPED":
                dataBaseService.updateDeviceWipeInProgress(id)
            default:
                break
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller.enable()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller.disable()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        BFLog("DevicesVC::numberOfSections")
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        BFLog("DevicesVC::numberOfRowsInSection")
        return controller.deviceCount
    }

    override func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        BFLog("DevicesVC::cellForRowAt")
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "deviceCell", for: indexPath) as! DeviceCell
        cell.displayContent(
            controller.device(at: indexPath),
            indexPath,
            isOwnOnline: controller.ownDevice?.online ?? false,
            isOwn: indexPath.item == 0)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let menu = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "manageDeviceMenu") as! ManageDeviceMenu
        menu.isOwn = indexPath.item == 0
        menu.devicesVC = self
        let device = controller.device(at: indexPath)
        menu.id = device.id
        menu.name = device.name
        menu.isOnline = device.online
        menu.isWiped = device.status == 6
        menu.isLogoutInProgress = device.isLogoutInProgress
        menu.isWipeInProgress = device.isWipeInProgress
        let bottomSheet = MDCBottomSheetController(contentViewController: menu)
        present(bottomSheet, animated: true, completion: nil)
    }
    
    private func setupDetailsInfo() {
        guard let detailsAlert = details,
            let device = controller.ownDevice else { return }
        let status = device.paused ? 8 : device.status
        let (title, _) = DeviceStatusFormatter.stringAndColor(status)
        let remoteCount = PvtboxService.getRemoteProcessingCount()
        let downloadsCount = device.downloadsCount
        let downloadName = device.currentDownloadName
        detailsAlert.title = title
        detailsAlert.message = String(
            format: "%@:\n%@\n\n"
                + "%@ \\ %@:\n%@\n\n"
                + "%@:\n%@\n\n"
                + "%@:\n%@\n",
            Strings.network,
            device.online ? Strings.ok : Strings.connectingToServers,
            Strings.syncingLocal, Strings.indexing,
            device.importingCamera ? Strings.importingCamera :
                device.processingOperation ? Strings.processingOperations : device.processingShare ?
                    Strings.processingShare : Strings.done,
            Strings.syncingRemote,
            remoteCount != 0 ? String(format: "%d %@", remoteCount, Strings.eventsTotal) :
                device.fetchingChanges ? Strings.fetchingChanges : Strings.done,
            Strings.downloading,
            device.paused ? Strings.paused :
                device.fetchingChanges ? Strings.waitingInitialSyncStatus :
                downloadsCount != 0 && downloadName == nil ?
                    String(
                        format: "%@\n%d %@",
                        Strings.waitingNodesStatus,
                        downloadsCount,
                        Strings.filesTotal) :
                downloadsCount != 0 ? String(
                    format: "%@\n%d %@", downloadName!, downloadsCount, Strings.filesTotal) :
                String(format: "%@\n", Strings.done)
        )
        
        setupDetailsInfoTask?.cancel()
        setupDetailsInfoTask = DispatchWorkItem { [weak self] in self?.setupDetailsInfo() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: setupDetailsInfoTask!)
    }
}
