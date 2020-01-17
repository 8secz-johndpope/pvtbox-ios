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

class ShareMenu: UITableViewController {
    
    @IBOutlet weak var getLinkIcon: UIImageView!
    @IBOutlet weak var getLinkText: UILabel!
    @IBOutlet weak var collaborationIcon: UIImageView!
    @IBOutlet weak var collaborationText: UILabel!
    
    var file: FileRealm!
    var delegate: MenuDelegate!
    var viewPresenter: ViewPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        let isFree = PreferenceService.license == Const.freeLicense
        if isFree || file?.parentUuid != nil {
            if #available(iOS 13.0, *) {
                collaborationIcon.tintColor = .quaternaryLabel
                collaborationText.textColor = .quaternaryLabel
            } else {
                collaborationIcon.tintColor = .lightGray
                collaborationText.textColor = .lightGray
            }
            if isFree {
                if #available(iOS 13.0, *) {
                    getLinkIcon.tintColor = .quaternaryLabel
                    getLinkText.textColor = .quaternaryLabel
                } else {
                    getLinkIcon.tintColor = .lightGray
                    getLinkText.textColor = .lightGray
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        delegate.menuDelegateDismiss()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.dismiss(animated: true, completion: nil)
        switch indexPath.item {
        case 0:
            if PreferenceService.license == Const.freeLicense {
                view.window?.hideAllToasts()
                view.window?.makeToast(Strings.notAvailableForFreeLicense)
                return
            } else if file?.parentUuid != nil  {
                view.window?.hideAllToasts()
                view.window?.makeToast(Strings.onlyRootFoldersCanBeCollaborated)
                return
            }
            let collab = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(
                    withIdentifier: "collaborationvc") as! CollaborationVC
            collab.file = file
            self.viewPresenter.presentWithNavigation(collab)
        case 1:
            if PreferenceService.license == Const.freeLicense && file.isFolder {
                view.window?.hideAllToasts()
                view.window?.makeToast(Strings.notAvailableForFreeLicense)
                return
            }
            let getLink = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "getlinkvc") as! GetLinkVC
            getLink.file = file
            self.viewPresenter.presentWithNavigation(getLink)
        default:
            fatalError("Unsupported case")
        }
    }
}
