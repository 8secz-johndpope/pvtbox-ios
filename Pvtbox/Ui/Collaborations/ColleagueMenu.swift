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
import DLRadioButton
import JASON

class ColleagueMenu: UITableViewController {
    @IBOutlet weak var email: UILabel!
    @IBOutlet weak var youLabel: UILabel!
    @IBOutlet weak var canView: DLRadioButton!
    @IBOutlet weak var canEdit: DLRadioButton!
    @IBOutlet weak var removeIcon: UIImageView!
    @IBOutlet weak var removeLabel: UILabel!
    
    var isOwner: Bool!
    var colleague: JSON!
    weak var delegate: ColleagueMenuDelegate?
    
    private var isSelf = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let mail = colleague["email"].string
        email.text = mail
        isSelf = mail == PreferenceService.email
        youLabel.isHidden = !isSelf
        
        canView.isSelected = true
        let accessType = colleague["access_type"].string
        if  accessType != "view" {
            canEdit.isSelected = true
            canEdit.iconColor = .orange
        }
        if isSelf {
            if #available(iOS 13.0, *) {
                canEdit.setTitleColor(.secondaryLabel, for: .normal)
            } else {
                canEdit.setTitleColor(.lightGray, for: .normal)
            }
            canEdit.iconColor = .lightOrange
            canEdit.indicatorColor = .lightOrange
            removeIcon.image = UIImage(named: "exit")
            removeLabel.text = Strings.quitCollaboration
        } else {
            removeIcon.image = UIImage(named: "delete")
            removeLabel.text = Strings.removeUser
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        BFLog("ColleagueMenu::tableView didSelectRow")
        view.window?.hideAllToasts()
        switch indexPath.item {
        case 0:
            break
        case 1:
            if isSelf {
                view.window?.makeToast(Strings.cantRemovePermissionFromSelf)
            } else {
                view.window?.makeToast(Strings.cantRemovePermissionFromColleague)
            }
        case 2:
            if isSelf {
                view.window?.makeToast(Strings.cantRemovePermissionFromSelf)
            } else {
                self.dismiss(animated: true, completion: { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.delegate?.colleagueMenu(strongSelf, changeEditPermission: !strongSelf.canEdit.isSelected)
                })
            }
        case 3:
            self.dismiss(animated: true, completion: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.colleagueMenu(strongSelf, remove: strongSelf.isSelf)
            })
        default:
            fatalError("unexpected case")
        }
    }
    
    override func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !isOwner && (indexPath.item == 1 || indexPath.item == 2) {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
}
