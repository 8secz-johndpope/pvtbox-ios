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

class ColleagueCard: UITableViewCell {
    @IBOutlet weak var email: UILabel!
    @IBOutlet weak var youLabel: UILabel!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var permission: UIButton!
    
    var colleague: JSON!
    var isSelf: Bool!
    
    private weak var delegate: ColleagueCardDelegate?
    
    public func displayContent(
        _ info: JSON, collaborationOwner: Int, index: Int,
        delegate: ColleagueCardDelegate) {
        colleague = info
        let mail = info["email"].string
        isSelf = mail == PreferenceService.email
        self.delegate = delegate
        if index % 2 == 0 {
            if #available(iOS 13.0, *) {
                backgroundColor = .systemBackground
            } else {
                backgroundColor = .white
            }
        } else {
            if #available(iOS 13.0, *) {
                backgroundColor = UIColor.secondarySystemBackground
            } else {
                backgroundColor = UIColor.graySelection
            }
        }
        
        email.text = mail
        youLabel.isHidden = !isSelf
        status.text = info["status"].string
        switch info["access_type"].string {
        case "owner":
            permission.setTitle(Strings.owner, for: .normal)
        case "edit":
            let title = NSMutableAttributedString(string: Strings.canEdit)
            title.addAttribute(.foregroundColor, value: UIColor.lightGray, range: NSRange(0...3))
            permission.setAttributedTitle(title, for: .normal)
        case "view":
            let title = NSMutableAttributedString(string: Strings.canView)
            title.addAttribute(.foregroundColor, value: UIColor.lightGray, range: NSRange(0...3))
            permission.setAttributedTitle(title, for: .normal)
        default:
            BFLogErr("Unexpected colleague access type: '%@'", info["access_type"].stringValue)
            break
        }
    }
    @IBAction func permissionClicked(_ sender: Any) {
        delegate?.colleagueCard(self, permissionClicked: self)
    }
}
