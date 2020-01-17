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

class SettingsVC: UIViewController {
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var version: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        version.text = String(
            format: "%@ %@.%@",
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        )
    }
    
    @IBAction func logout(_ sender: Any) {
        let alert = MDCAlertController(title: nil, message: Strings.keepLocalFiles)
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
        let keep = MDCAlertAction(
            title: Strings.keep,
            handler: {_ in PvtboxService.logout(byUserAction: true) })
        alert.addAction(keep)
        let clear = MDCAlertAction(
            title: Strings.clear,
            handler: {_ in PvtboxService.logout(byUserAction: true, wipe: true) })
        alert.addAction(clear)
        present(alert, animated: true, completion: nil)
    }
}
