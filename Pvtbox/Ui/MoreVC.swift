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

class MoreVC: UITableViewController, UIDocumentInteractionControllerDelegate {

    @IBOutlet weak var logo: UIBarButtonItem!
    @IBOutlet weak var notificationsCountBadge: UILabel!
    
    private var realm: Realm?
    private var ownDevice: DeviceRealm?
    private var ownDeviceSubscription: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = logo
        navigationItem.rightBarButtonItems = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        subscribeForNotificationsCount()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ownDeviceSubscription?.invalidate()
        ownDeviceSubscription = nil
        ownDevice = nil
        realm = nil
    }
    
    private func subscribeForNotificationsCount() {
        notificationsCountBadge.isHidden = true
        if self.realm == nil {
            guard let realm = try? Realm() else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    [weak self] in self?.subscribeForNotificationsCount()
                })
                return
            }
            self.realm = realm
        }
        ownDevice = realm?.object(ofType: DeviceRealm.self, forPrimaryKey: "own")
        if ownDevice == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                [weak self] in self?.subscribeForNotificationsCount()
            })
            return
        }
        ownDeviceSubscription = ownDevice!.observe { [weak self] change in
            switch change {
            case .change(let properties):
                for property in properties {
                    if property.name == "notificationsCount" {
                        let count = self?.ownDevice?.notificationsCount ?? 0
                        if count > 0 {
                            self?.notificationsCountBadge.text = count > 999 ?
                                "999+" : String(count)
                        }
                        self?.notificationsCountBadge.isHidden = count <= 0
                    }
                }
            case .error(let error):
                BFLogErr("An error occurred: %@", error)
            case .deleted:
                BFLogErr("The ownDevice object was deleted.")
            }
        }
        let count = ownDevice?.notificationsCount ?? 0
        if count > 0 {
            notificationsCountBadge.text = count > 999 ?
                "999+" : String(count)
        }
        notificationsCountBadge.isHidden = count <= 0
    }

    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.item {
        case 0:
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "notificationsvc") as! NotificationsVC
            navigationController?.pushViewController(vc, animated: true)
        case 1:
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "devicesvc")
            navigationController?.pushViewController(vc, animated: true)
        case 2:
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "settingsVC")
            navigationController?.pushViewController(vc, animated: true)
        case 3:
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "webvc") as! WebVC
            vc.header = Strings.faq
            vc.url = URL(string: Const.faqLink)
            navigationController?.pushViewController(vc, animated: true)
        case 4:
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "supportVC")
            navigationController?.pushViewController(vc, animated: true)
        default:
            BFLogErr("MoreVC::tableView didSelectRowAt: Unexpected case")
        }
    }
}
