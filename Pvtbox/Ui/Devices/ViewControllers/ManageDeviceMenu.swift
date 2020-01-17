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
import MaterialComponents.MDCAlertController

class ManageDeviceMenu: UITableViewController {
    var id: String!
    var name: String!
    var isOwn: Bool!
    var isOnline: Bool!
    var isWiped: Bool!
    var isLogoutInProgress: Bool!
    var isWipeInProgress: Bool!
    var devicesVC: DevicesVC!

    @IBOutlet weak var logoutLabel: UILabel!
    @IBOutlet weak var wipeLabel: UILabel!
    @IBOutlet weak var logoutIcon: UIImageView!
    @IBOutlet weak var wipeIcon: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let isFree = PreferenceService.license == Const.freeLicense
        if isLogoutInProgress || (!isOwn && isFree){
            if !isOwn && isFree {
                logoutLabel.text = Strings.logout
            } else {
                logoutLabel.text = Strings.logoutInProgress
            }
            if #available(iOS 13.0, *) {
                logoutLabel.textColor = .quaternaryLabel
                logoutIcon.tintColor = .quaternaryLabel
            } else {
                logoutLabel.textColor = .lightGray
                logoutIcon.tintColor = .lightGray
            }
        } else {
            logoutLabel.text = Strings.logout
            if #available(iOS 13.0, *) {
                logoutLabel.textColor = .label
                logoutIcon.tintColor = .secondaryLabel
            } else {
                logoutLabel.textColor = .darkText
                logoutIcon.tintColor = .darkGray
            }
        }
        if isWipeInProgress || (!isOwn && isFree) {
            if !isOwn && isFree {
                wipeLabel.text = Strings.wipe
            } else {
                wipeLabel.text = Strings.wipeInProgress
            }
            if #available(iOS 13.0, *) {
                wipeLabel.textColor = .quaternaryLabel
                wipeIcon.tintColor = .quaternaryLabel
            } else {
                wipeLabel.textColor = .lightGray
                wipeIcon.tintColor = .lightGray
            }
        } else {
            wipeLabel.text = Strings.wipe
            if #available(iOS 13.0, *) {
                wipeLabel.textColor = .label
                wipeIcon.tintColor = .secondaryLabel
            } else {
                wipeLabel.textColor = .darkText
                wipeIcon.tintColor = .darkGray
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: true, completion: { [weak self] in
            self?.performAction(indexPath.item)
        })
    }
    
    private func performAction(_ index: Int) {
        switch index {
        case 0:
            devicesVC.showDetails()
        case 1:
            devicesVC.removeNode(id, name)
        case 2:
            let isFree = PreferenceService.license == Const.freeLicense
            if !isOwn && isFree {
                devicesVC.view.window?.hideAllToasts()
                devicesVC.view.window?.makeToast(Strings.notAvailableForFreeLicense)
                return
            } else if !isLogoutInProgress {
                devicesVC.logout(isOwn, id)
            }
        case 3:
            let isFree = PreferenceService.license == Const.freeLicense
            if !isOwn && isFree {
                devicesVC.view.window?.hideAllToasts()
                devicesVC.view.window?.makeToast(Strings.notAvailableForFreeLicense)
                return
            } else if !isWipeInProgress {
                devicesVC.logoutAndWipe(isOwn, id, name)
            }
        default:
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.notImplemented)
        }
    }
    
    override func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath.item == 0 && !isOwn) || (indexPath.item == 1 && (isOwn || isOnline)) || (((indexPath.item == 2) || (indexPath.item == 3)) && isWiped) ||
            (indexPath.item == 2 && isWipeInProgress) {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
}
