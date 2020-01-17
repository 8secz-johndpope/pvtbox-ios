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

class ShareExpireDialog: UITableViewController, UIPopoverPresentationControllerDelegate {
    @IBOutlet weak var expireInstantly: UITableViewCell!
    @IBOutlet weak var expire1Day: UITableViewCell!
    @IBOutlet weak var expire3Days: UITableViewCell!
    
    weak var switchView: UISwitch!
    var file: FileRealm!
    private var actionConfirmed = false
    private var selectedTtl = 0
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.sizeToFit()
        var size = self.tableView.contentSize
        size.height = 260
        self.preferredContentSize = size
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super .viewWillDisappear(animated)
        if !actionConfirmed {
            switchView.isOn = false
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.item {
        case 1:
            expireInstantly.accessoryType = .checkmark
            expire1Day.accessoryType = .none
            expire3Days.accessoryType = .none
            selectedTtl = -1
        case 2:
            expireInstantly.accessoryType = .none
            expire1Day.accessoryType = .checkmark
            expire3Days.accessoryType = .none
            selectedTtl = 60 * 60 * 24
        case 3:
            expireInstantly.accessoryType = .none
            expire1Day.accessoryType = .none
            expire3Days.accessoryType = .checkmark
            selectedTtl = 60 * 60 * 24 * 3
        default:
            break
        }
    }
    
    @IBAction func cancelClicked(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func okClick(_ sender: Any) {
        actionConfirmed = true
        dismiss(animated: true, completion: nil)
        UIApplication.shared.beginIgnoringInteractionEvents()
        SnackBarManager.showSnack(
            Strings.updatingShare, showNew: true, showForever: true)
        HttpClient.shared.shareEnable(
            uuid: file.uuid!, ttl: selectedTtl, password: nil,
            onSuccess: { _ in
                DispatchQueue.main.async {
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(
                    Strings.updatedShare, showNew: false, showForever: false)
            },
            onError: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    self?.switchView.isOn = false
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
